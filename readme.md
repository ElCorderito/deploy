# Guía rápida para dejar una Raspberry nueva lista con tu kiosko

> Esta guía asume **Raspberry Pi OS con escritorio** (la que ofrece el Imager), **Pi 5**, y que vas a correr **Ansible en la misma Raspberry** (más simple). Si prefieres correr Ansible desde tu laptop, te dejo notas al final.

---

## 0) Primer arranque de la Raspberry

1. Flashea la SD con Raspberry Pi Imager (activa **usuario/contraseña**, **SSH** y **Wi-Fi** si aplica).
2. Enciende la Pi y actualiza rápido:

   ```bash
   sudo apt update && sudo apt -y full-upgrade && sudo reboot
   ```

---

## 1) Instala herramientas base en la Pi

```bash
sudo apt update
sudo apt install -y git ansible python3-venv python3-pip nodejs npm libnss-mdns
```

> `avahi-daemon` solo es necesario si luego quieres acceder por `hostname.local`. Como aquí correrás Ansible **en la misma Pi**, puedes ignorarlo.

---

## 2) Instala AnyDesk y TeamViewer

* Descarga e instala sus `.deb` oficiales (o usa su repo apt si ya lo tienes).

   ```bash
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
cd deploy
```

> Si prefieres SSH: `git clone git@github.com:ElCorderito/deploy.git`

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

### 5.2 `deploy/group_vars/raspis.yml` (comunes)

Crea/edita y deja así (ajusta ramas según tu GitHub; si dudaste, usa `master` para electron y `main` para signage):

```yaml
# Rutas base
electron_root: /opt/electron_rasp
signage_root:  /opt/signage

# Repos
electron_repo: "git@github.com:ElCorderito/electron_rasp.git"
signage_repo:  "git@github.com:ElCorderito/signage.git"

# Ramas por defecto del remoto
electron_branch: master
signage_branch:  master

# Usuario que ejecuta los servicios (normalmente tu ansible_user)
kiosk_user: "{{ ansible_user }}"

# Python / Electron
python_bin:       /usr/bin/python3.11
venv_dir:         "{{ electron_root }}/venv"
flask_app_dir:    "{{ electron_root }}/electron_rasp/flask_app"
requirements_file:"{{ electron_root }}/electron_rasp/requirements.txt"
electron_app_dir: "{{ electron_root }}/electron_rasp/electron"

# Timers
electron_update_every: "2min"
signage_update_every:  "10min"
maintenance_hour:      "03:00:00"

# Paquetes base (kiosko + X)
apt_base_packages:
  - git
  - python3.11
  - python3.11-venv
  - python3-pip
  - nodejs
  - npm
  - lxde
  - lightdm
  - xserver-xorg

# Autologin (opcional; útil si tu imagen aún no lo tenía)
manage_lightdm: true
lightdm_autologin_user: "{{ kiosk_user }}"
lightdm_session: "LXDE-pi-x"

# Remotos (solo habilitar si ya están instalados)
enable_remote_services: true
remote_services:
  - anydesk.service
  - teamviewerd.service
```

### 5.3 `deploy/host_vars/rasp_trolley.yml` (por host)

```yaml
SCREEN_ID: rasp_trolley
BRANCH_ID: 3
KIOSK_URL: "http://localhost:3000"
```

> Para más Pis (p. ej. `rasp_otay`), duplica este archivo cambiando `SCREEN_ID`/`BRANCH_ID` y agrega el host al inventario.

---

## 6) Verifica que el role **apps** tenga activadas las claves

Revisa `deploy/roles/apps/tasks/main.yml` y confirma que:

* Está el **bloque SSH** que copia las llaves a `~/.ssh` del `kiosk_user`.
* En **cada tarea `git`** está activo `key_file:`. Debe verse así:

```yaml
- name: Clonar/actualizar electron_rasp
  git:
    repo: "{{ electron_repo }}"
    dest: "{{ electron_root }}/electron_rasp"
    version: "{{ electron_branch }}"
    force: yes
    accept_hostkey: yes
    key_file: "/home/{{ kiosk_user }}/.ssh/id_ed25519_electron"
  become: yes
  become_user: "{{ kiosk_user }}"

- name: Clonar/actualizar signage
  git:
    repo: "{{ signage_repo }}"
    dest: "{{ signage_root }}/signage"
    version: "{{ signage_branch }}"
    force: yes
    accept_hostkey: yes
    key_file: "/home/{{ kiosk_user }}/.ssh/id_ed25519_signage"
  become: yes
  become_user: "{{ kiosk_user }}"
```

> Si dejaste `signage_repo` con `github.com`, **no necesitas** alias `github-signage` (puedes ignorar esa tarea).

---

## 7) Ejecuta Ansible

Prueba ping (debería decir “pong”):

```bash
ansible -i inventory.ini raspis -m ping
```

Corre el playbook (pedirá sudo y, si cifraste, la clave de Vault):

```bash
ansible-playbook -i inventory.ini site.yml -l rasp_trolley --ask-vault-pass -K
```

Qué hará:

* Instala paquetes base
* Copia deploy keys al usuario
* Clona/actualiza `electron_rasp` y `signage` (ramas definidas)
* Crea venv + `pip install -r`
* `npm ci` en `electron/`
* Copia `update_repo.sh` y `signage/update.sh`
* Instala services/timers (`electron_rasp-*`, `signage-*`, `rpi-maintenance.timer`)
* Configura LightDM autologin (si está activado en vars)
* Habilita AnyDesk/TeamViewer si existen

---

## 8) Verificación rápida

```bash
systemctl status electron_rasp-flask.service
systemctl status electron_rasp-electron.service
systemctl list-timers | grep -E 'electron_rasp|signage|rpi-maintenance'
journalctl -u electron_rasp-electron -f
journalctl -u electron_rasp-flask -f
```

Si todo ok, reinicia para probar arranque limpio:

```bash
sudo reboot
```

---

## 9) ¿Y si la IP cambia?

Como corres Ansible en la misma Pi, usas `127.0.0.1` y te olvidas.
Si algún día corres Ansible desde otra máquina, usa:

```ini
[raspis]
rasp_trolley ansible_host=rasp_trolley.local ansible_user=pi
```

y asegúrate de tener `avahi-daemon` en la Pi y `libnss-mdns` en la máquina de control.

---

## 10) Añadir otra Raspberry (ej. `rasp_otay`) en 1 minuto

1. En `inventory.ini`, agrega:

   ```ini
   rasp_otay ansible_host=IP.O.TU.RASP ansible_user=pi
   ```

   (o `127.0.0.1` + `ansible_connection=local` si corres ahí mismo).

2. Crea `host_vars/rasp_otay.yml`:

   ```yaml
   SCREEN_ID: rasp_otay
   BRANCH_ID: 5   # lo que toque
   KIOSK_URL: "http://localhost:3000"
   ```

3. Corre:

   ```bash
   ansible -i inventory.ini rasp_otay -m ping
   ansible-playbook -i inventory.ini site.yml -l rasp_otay --ask-vault-pass -K
   ```

---

## 11) Troubleshooting express

* **`Permission denied (publickey)` al clonar** → deploy keys mal cargadas o mal `key_file:`. Revisa que las **.pub** estén en GitHub (Deploy keys) y que Ansible copió las privadas a `~/.ssh` del `kiosk_user`.
* **`pathspec 'main' did not match`** → cambia `electron_branch`/`signage_branch` a la rama real (`master`/`main`).
* **No arranca el kiosko al login** → verifica `lightdm.service` y `autologin-user` en `/etc/lightdm/lightdm.conf`.
* **signage no se actualiza** → mira `systemctl status signage-update.timer` y el log del service `signage-update`.

---

### Listo. Con esto, prendes, sigues los pasos y quedas con la Pi lista (remoto, auto-pull, servicios/timers y kiosko).

Si algo te truena al correr el playbook, copia el error tal cual y te digo la línea exacta a corregir.
