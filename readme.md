# Guía rápida para dejar una Raspberry nueva lista con tu kiosko

> Esta guía asume **Raspberry Pi OS con escritorio** (la que ofrece el Imager), **Pi 5**, y que vas a correr **Ansible en la misma Raspberry** (más simple). Si prefieres correr Ansible desde tu laptop, te dejo notas al final.

---

## 0) Primer arranque de la Raspberry

1. Flashea la SD con Raspberry Pi Imager (activa **usuario/contraseña**, **SSH** y **Wi-Fi** si aplica).
2. Enciende la Pi y actualiza rápido:

   ```bash
   sudo apt update && sudo apt -y full-upgrade
   ```

---

## 1) Instala herramientas base en la Pi

```bash
sudo apt update
sudo apt install -y git ansible python3-venv python3-pip nodejs npm
```

> `avahi-daemon` solo es necesario si luego quieres acceder por `hostname.local`. Como aquí correrás Ansible **en la misma Pi**, puedes ignorarlo.

---

## 2) Instala AnyDesk y TeamViewer

* Descarga e instala sus `.deb` oficiales (o usa su repo apt si ya lo tienes).

   ```bash
   cd Downloads
   sudo dpkg -i nombre_del_paquete.deb
   ```

* Habilita servicios:

  ```bash
  sudo systemctl enable --now anydesk.service teamviewerd.service || true
  ```

> Si no están instalados, el comando anterior no rompe nada.

---

## 3) Clona tu repo **deploy** (es público)

```bash
cd ~
git clone https://github.com/ElCorderito/deploy.git
```


---

## 4) Crea **deploy keys** para tus repos privados de **app** (electron\_rasp y signage)

> **Una llave por repo**. Las guardaremos **en esta Pi** para que Ansible las distribuya a donde haga falta.

```bash
mkdir -p deploy/secrets

# 1) para electron_rasp
ssh-keygen -t ed25519 -C "deploy-electron" -f deploy/secrets/id_ed25519_electron -N ""
# 2) para signage
ssh-keygen -t ed25519 -C "deploy-signage"  -f deploy/secrets/id_ed25519_signage  -N ""

# muestra las públicas para copiarlas a GitHub
cat deploy/secrets/id_ed25519_electron.pub
cat deploy/secrets/id_ed25519_signage.pub
```

Ahora ve a GitHub y pega **cada .pub** en **Deploy keys** del repo correspondiente (read-only):

* `ElCorderito/electron_rasp` → Settings → **Deploy keys** → Add deploy key → pega `id_ed25519_electron.pub`
* `ElCorderito/signage`       → Settings → **Deploy keys** → Add deploy key → pega `id_ed25519_signage.pub`

**(Recomendado)** Cifra las privadas con Ansible Vault para guardarlas en el repo sin riesgo:

```bash
ansible-vault encrypt deploy/secrets/id_ed25519_electron
ansible-vault encrypt deploy/secrets/id_ed25519_signage
```

---

## 5) Rellena el inventario y variables mínimas

### 5.1 `deploy/inventory.ini` (como correrás en la propia Pi)

```ini
[raspis]
rasp_trolley ansible_host=127.0.0.1 ansible_connection=local ansible_user=rasp-trolley
```

> Cambia `rasp-trolley` por tu usuario real si es distinto.

### 5.2 `deploy/host_vars/rasp_trolley.yml` (por host)

```yaml
SCREEN_ID: rasp_trolley
BRANCH_ID: 3
KIOSK_URL: "http://localhost:3000"
```

> Para más Pis (p. ej. `rasp_otay`), duplica este archivo cambiando `SCREEN_ID`/`BRANCH_ID` y agrega el host al inventario.

---

## 6) Ejecuta Ansible

Prueba ping (debería decir “pong”):

```bash
ansible -i inventory.ini raspis -m ping
```

Corre el playbook (pedirá sudo y, si cifraste, la clave de Vault):

```bash
ansible-playbook -i inventory.ini site.yml -l rasp_trolley --ask-vault-pass -K
```

## 7) Malo de audio

Checar con "id -u" que numero te lanz y ponerlo en este archivo:
   ```bash
   sudo nano /etc/systemd/system/electron_rasp-electron.service
   ```

Y poner esto abajo de las otras Environment:
   ```bash
   # ---- Audio: forzar PipeWire/Pulse (evita ALSA directo) ----
   Environment=XDG_RUNTIME_DIR=/run/user/1000
   Environment=PULSE_SERVER=unix:/run/user/1000/pulse/native
   Environment=PIPEWIRE_LATENCY=128/48000
   ```

Edita el override de Electron (flags)
   ```bash
   sudo nano /etc/systemd/system/electron_rasp-electron.service.d/override.conf
   ```

Y hasta abajo se debe de ver asi:
   ```bash
   --autoplay-policy=no-user-gesture-required \
   --disable-features=AudioServiceOutOfProcess"
   ```

Y recargar:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart electron_rasp-flask.service
   sudo systemctl restart electron_rasp-electron.service
   ```

## 8) Dejar ip statica


# PASO 1 — Ver qué conexión está usando

Primero identifica la conexión activa:

```bash
nmcli connection show --active
```

Te debe salir algo como:

```
NAME                UUID                                  DEVICE
Wired connection 1  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  eth0
```

Qué cambia aquí:

* El nombre puede ser distinto ("Wired connection 1", "ethernet", etc.).

Guarda:

* El **UUID**
* O el **NAME exacto**

---

# PASO 2 — Ver tu red actual

Necesitas saber:

```bash
ip a
ip route
```

De aquí sacas:

* Tu red (ej: 192.168.1.X o 192.168.7.X)
* Tu gateway (ej: 192.168.1.1)

Ejemplo típico:

Si ves:

```
inet 192.168.1.23/24
default via 192.168.1.1
```

Entonces:

* Red → 192.168.1.X
* Gateway → 192.168.1.1
* Máscara → /24

---

# PASO 3 — Forzar estática correctamente

Usando el UUID:

```bash
sudo nmcli connection modify TU_UUID \
ipv4.method manual \
ipv4.addresses 192.168.1.50/24 \
ipv4.gateway 192.168.1.1 \
ipv4.dns "8.8.8.8 1.1.1.1" \
ipv4.ignore-auto-routes yes \
ipv4.ignore-auto-dns yes
```

Cambia:

* `TU_UUID`
* `192.168.1.50`
* `192.168.1.1`

---

# PASO 4 — Reiniciar NetworkManager

En Bookworm esto es clave:

```bash
sudo systemctl restart NetworkManager
```

---

# PASO 5 — Verificar

```bash
ip a
```

Debe decir:

```
inet 192.168.1.50/24
```

Luego:

```bash
ip route
```

Debe decir:

```
default via 192.168.1.1
```

---

# Lo que cambia dependiendo de cada Raspberry

Cambia esto en cada una:

| Elemento          | Cambia según   |
| ----------------- | -------------- |
| UUID              | Cada Raspberry |
| Nombre conexión   | Puede variar   |
| Red (192.168.X.X) | Según router   |
| Gateway           | Según router   |
| IP fija elegida   | Debe ser única |
---