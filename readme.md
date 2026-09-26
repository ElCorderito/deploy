# Guía rápida para dejar una Raspberry nueva lista con tu kiosko

> Esta guía asume **Raspberry Pi OS con escritorio** (la que ofrece el Imager), **Pi 5**, y que vas a correr **Ansible en la misma Raspberry** (más simple).

---

## 0) Primer arranque de la Raspberry

1. Flashea la SD con Raspberry Pi Imager.
2. En el Imager configura:
   - **usuario/contraseña**
   - **SSH**
   - **Wi-Fi** si aplica
3. Enciende la Pi y actualiza el sistema:

   ```bash
   sudo apt update && sudo apt -y full-upgrade
   ```

---

## 1) Instala herramientas base y aprovecha el tiempo de instalación

Instala las herramientas necesarias:

```bash
sudo apt update
sudo apt install -y git ansible python3-venv python3-pip nodejs npm
```

> `avahi-daemon` solo es necesario si luego quieres acceder por `hostname.local`. Como aquí correrás Ansible **en la misma Pi**, puedes ignorarlo.

### Mientras se instalan las herramientas

Mientras termina el comando anterior, abre en el navegador estas páginas y déjalas listas:

1. **Repo deploy**  
   https://github.com/ElCorderito/deploy

2. **Deploy Keys de electron_rasp**  
   https://github.com/ElCorderito/electron_rasp/settings/keys

3. **Deploy Keys de signage**  
   https://github.com/ElCorderito/signage/settings/keys

También aprovecha para descargar:

- **AnyDesk para Linux / Raspberry Pi**
- **TeamViewer / TeamViewer Host para Linux**

La idea es dejar preparadas desde aquí las páginas que vas a necesitar después para no perder tiempo entre pasos.

> Si la Raspberry usa Raspberry Pi OS de 64 bits, descarga el paquete correspondiente a **ARM64** cuando el sitio te dé varias arquitecturas.

---

## 2) Define primero qué Raspberry vas a preparar en GitHub

Antes de hacer `git clone`, entra al repo:

https://github.com/ElCorderito/deploy

y prepara ahí la configuración correspondiente a la Raspberry que estás instalando.

De esta manera, cuando después hagas `git clone`, la Pi ya descargará el `inventory.ini` y el `host_vars` correctos.

### 2.1 Edita `inventory.ini`

Abre:

```text
inventory.ini
```

La línea activa debajo de `[raspis]` debe corresponder a la Raspberry que estás preparando.

Ejemplo normal:

```ini
[raspis]
rasp_nueva ansible_host=127.0.0.1 ansible_connection=local ansible_user=rasp-nueva

[raspis:vars]
ansible_ssh_private_key_file=~/.ssh/id_ed25519
```

Aquí hay dos nombres distintos:

```text
rasp_nueva
```

Es el **nombre del host dentro de Ansible**.

```text
rasp-nueva
```

Es el **usuario real de Linux** de esa Raspberry.

El valor de `ansible_user` debe coincidir con el usuario que creaste al instalar Raspberry Pi OS.

### Si la pantalla es vertical

Agrega:

```ini
display_orientation=portrait
```

Ejemplo:

```ini
rasp_nueva ansible_host=127.0.0.1 ansible_connection=local ansible_user=rasp-nueva display_orientation=portrait
```

### Si quieres HDMI persistente

Para una TV donde quieras protegerte del problema de **No Signal** después de apagar/encender la pantalla:

```ini
force_kiosk_hdmi=true
```

Ejemplo:

```ini
rasp_nueva ansible_host=127.0.0.1 ansible_connection=local ansible_user=rasp-nueva force_kiosk_hdmi=true
```

Si es vertical y además quieres HDMI persistente:

```ini
rasp_nueva ansible_host=127.0.0.1 ansible_connection=local ansible_user=rasp-nueva display_orientation=portrait force_kiosk_hdmi=true
```

> Si tu forma de trabajar es instalar una Raspberry a la vez localmente, deja activa la Raspberry que estás preparando y conserva las demás comentadas como referencia.

---

### 2.2 Crea o revisa su archivo en `host_vars`

El archivo debe tener exactamente el mismo nombre que el host de Ansible.

Si en `inventory.ini` pusiste:

```text
rasp_nueva
```

el archivo debe ser:

```text
host_vars/rasp_nueva.yml
```

Contenido mínimo:

```yaml
SCREEN_ID: rasp_nueva
BRANCH_ID: 3
```

Cambia `BRANCH_ID` por la sucursal que realmente debe mostrar esa Raspberry.

Antes de continuar, revisa que todo concuerde:

```text
inventory.ini:
    rasp_nueva

ansible_user:
    rasp-nueva

host_vars:
    host_vars/rasp_nueva.yml
```

> Para instalaciones nuevas ya no hace falta agregar `KIOSK_URL: "http://localhost:3000"` al ejemplo. El servicio actual de Electron usa el backend local de Flask.

---

## 3) Instala AnyDesk y TeamViewer

Como ya descargaste los paquetes mientras se instalaban las herramientas base, ve a Descargas:

```bash
cd ~/Downloads
ls -lh *.deb
```

Instala AnyDesk:

```bash
sudo apt install ./NOMBRE_DEL_PAQUETE_ANYDESK.deb
```

Instala TeamViewer o TeamViewer Host:

```bash
sudo apt install ./NOMBRE_DEL_PAQUETE_TEAMVIEWER.deb
```

Habilita los servicios:

```bash
sudo systemctl enable --now anydesk.service teamviewerd.service || true
```

Puedes confirmar:

```bash
systemctl status anydesk.service --no-pager
systemctl status teamviewerd.service --no-pager
```

> Para una Raspberry de kiosko con acceso remoto desatendido, normalmente conviene **TeamViewer Host**.

---

## 4) Clona el repo `deploy`

Como ya preparaste `inventory.ini` y `host_vars` en GitHub, ahora sí clona el repo:

```bash
cd ~
git clone https://github.com/ElCorderito/deploy.git
cd deploy
```

Confirma que descargaste la configuración correcta:

```bash
cat inventory.ini
ls host_vars
```

Revisa también el archivo de esta Raspberry:

```bash
cat host_vars/rasp_nueva.yml
```

Cambia `rasp_nueva` por el nombre real.

### Si `deploy` ya existe

No vuelvas a clonarlo:

```bash
cd ~/deploy
git pull
```

---

## 5) Crea las Deploy Keys de `electron_rasp` y `signage`

Se usa **una llave distinta por repo**.

Desde tu carpeta personal:

```bash
cd ~
mkdir -p deploy/secrets
```

### 5.1 Llave para `electron_rasp`

```bash
ssh-keygen -t ed25519 -C "deploy-electron" -f deploy/secrets/id_ed25519_electron -N ""
```

Muestra la llave pública:

```bash
cat deploy/secrets/id_ed25519_electron.pub
```

Pégala en la página que dejaste abierta:

https://github.com/ElCorderito/electron_rasp/settings/keys

Haz:

```text
Add deploy key
→ pega la llave pública
→ acceso de solo lectura
```

### 5.2 Llave para `signage`

```bash
ssh-keygen -t ed25519 -C "deploy-signage" -f deploy/secrets/id_ed25519_signage -N ""
```

Muestra la llave pública:

```bash
cat deploy/secrets/id_ed25519_signage.pub
```

Pégala en:

https://github.com/ElCorderito/signage/settings/keys

Haz:

```text
Add deploy key
→ pega la llave pública
→ acceso de solo lectura
```

> En GitHub solo se pega el contenido del archivo `.pub`. Nunca la llave privada.

### 5.3 Opcional: cifrar las llaves privadas con Ansible Vault

Si las privadas se van a guardar dentro del repo:

```bash
ansible-vault encrypt deploy/secrets/id_ed25519_electron
ansible-vault encrypt deploy/secrets/id_ed25519_signage
```

---

## 6) Revisa todo y ejecuta Ansible

Entra al repo:

```bash
cd ~/deploy
```

### 6.1 Revisa `inventory.ini`

```bash
cat inventory.ini
```

Confirma:

- nombre correcto de la Raspberry;
- `ansible_user` correcto;
- `display_orientation=portrait` solo si aplica;
- `force_kiosk_hdmi=true` solo si aplica.

### 6.2 Revisa `host_vars`

```bash
cat host_vars/rasp_nueva.yml
```

Confirma que `SCREEN_ID` y especialmente `BRANCH_ID` sean correctos.

### 6.3 Prueba Ansible específicamente contra esa Raspberry

```bash
ansible -i inventory.ini rasp_nueva -m ping
```

Debe responder:

```text
pong
```

Cambia `rasp_nueva` por el host real definido en `inventory.ini`.

### 6.4 Ejecuta el playbook

Si usas Ansible Vault:

```bash
ansible-playbook -i inventory.ini site.yml -l rasp_nueva --ask-vault-pass -K
```

Si no usas Vault:

```bash
ansible-playbook -i inventory.ini site.yml -l rasp_nueva -K
```

Cambia `rasp_nueva` por el host real.

- `-l rasp_nueva` limita el playbook únicamente a esa Raspberry.
- `-K` pide la contraseña de sudo.
- `--ask-vault-pass` pide la contraseña de Vault si cifraste archivos.

---

## 7) Audio HDMI

El audio del kiosk ya se configura **automaticamente desde Ansible**. No edites a mano
`electron_rasp-electron.service` ni agregues `/run/user/1000`.

El deploy hace lo siguiente al arrancar Electron:

1. Detecta el UID real del usuario del kiosk.
2. Espera a que PipeWire/Pulse este disponible.
3. Activa `output:hdmi-stereo` en el HDMI usado por el kiosk.
4. Quita mute y deja el volumen configurado.
5. Fuerza `PULSE_SINK` para que Electron use ese HDMI aunque WirePlumber elija otro sink por defecto.

Por defecto usa el mismo conector del video:

```yaml
kiosk_hdmi_connector: "HDMI-A-1"
kiosk_audio_enabled: true
kiosk_audio_volume: "100"
```

Si la Raspberry usa el segundo puerto HDMI:

```yaml
kiosk_hdmi_connector: "HDMI-A-2"
```

Si una instalacion no debe usar audio HDMI, se puede poner por host:

```yaml
kiosk_audio_enabled: false
```

### Diagnostico rapido si no se escucha

Primero revisa que exista el sink HDMI:

```bash
pactl list short sinks
```

Debe aparecer un nombre que contenga `hdmi` y `hdmi-stereo`.

Para ver lo que hizo el arranque de Electron:

```bash
journalctl -b -u electron_rasp-electron.service --no-pager | grep -E '\[audio\]|PULSE_SINK'
```

Para probar el HDMI directamente por ALSA en el primer puerto:

```bash
speaker-test -D hdmi:CARD=vc4hdmi0,DEV=0 -c 2 -t wav -l 1
```

En el segundo puerto usa `vc4hdmi1`.

Si el deploy se acaba de actualizar, vuelve a aplicarlo y reinicia:

```bash
ansible-playbook -i inventory.ini site.yml -l NOMBRE_DE_LA_RASP -K
sudo reboot
```

No hace falta correr manualmente `daemon-reload` ni editar los archivos de systemd para el audio.

## 8) Dejar IP estática

Raspberry Pi OS Bookworm usa **NetworkManager** para administrar la red.

Hay dos casos posibles:

1. **La Raspberry ya tiene la IP que quieres y solo quieres dejar esa misma IP fija.**
2. **Quieres cambiar la Raspberry a otra IP específica.**

> Si estás conectado remotamente a la Raspberry, al aplicar el cambio la conexión puede cortarse durante unos segundos.  
> Si cambias la IP, tendrás que volver a conectarte usando la nueva dirección.

---

### PASO 1 — Ver qué conexión está usando

Primero identifica la conexión activa:

```bash
nmcli -t -f NAME,DEVICE connection show --active
```

Ejemplo:

```text
Wired connection 1:eth0
```

En este ejemplo:

```text
Nombre de conexión: Wired connection 1
Dispositivo: eth0
```

El nombre puede ser diferente en cada Raspberry, así que usa exactamente el que aparezca.

Si quieres ver también el UUID:

```bash
nmcli connection show --active
```

Ejemplo:

```text
NAME                UUID                                  DEVICE
Wired connection 1  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  eth0
```

---

### PASO 2 — Ver la IP, máscara y gateway actuales

Si la Raspberry está conectada por Ethernet:

```bash
ip -4 addr show eth0
ip route | grep default
```

Ejemplo:

```text
inet 192.168.7.106/24
default via 192.168.7.1 dev eth0
```

Eso significa:

```text
IP actual: 192.168.7.106
Máscara: /24
Gateway: 192.168.7.1
Red: 192.168.7.X
```

> Si en el PASO 1 el dispositivo no aparece como `eth0`, usa el dispositivo que realmente aparezca.

---

## OPCIÓN A — Dejar fija la IP que ya tiene actualmente

Usa esta opción cuando la Raspberry **ya tiene la IP que quieres conservar**, pero actualmente la recibió automáticamente por DHCP.

Por ejemplo, actualmente tiene:

```text
IP: 192.168.7.106/24
Gateway: 192.168.7.1
```

y quieres que siga siendo siempre:

```text
192.168.7.106
```

Si la conexión se llama:

```text
Wired connection 1
```

ejecuta:

```bash
sudo nmcli con mod "Wired connection 1" \
  ipv4.method manual \
  ipv4.addresses 192.168.7.106/24 \
  ipv4.gateway 192.168.7.1 \
  ipv4.dns "1.1.1.1 8.8.8.8" \
  ipv4.ignore-auto-routes yes \
  ipv4.ignore-auto-dns yes
```

Después aplica la configuración:

```bash
sudo nmcli con up "Wired connection 1"
```

La Raspberry debe continuar usando:

```text
192.168.7.106
```

pero ahora NetworkManager tendrá esa dirección configurada como **manual/estática**.

---

## OPCIÓN B — Cambiarla a una IP fija específica

Usa esta opción cuando quieres que la Raspberry tenga **una IP diferente a la que tiene actualmente**.

Primero confirma:

- que la IP pertenece a la misma red;
- que la máscara es correcta;
- que el gateway corresponde a esa red;
- que la IP que quieres usar no está ocupada por otro dispositivo.

Por ejemplo, supongamos que actualmente sabes que la red es:

```text
Red: 192.168.7.X
Máscara: /24
Gateway: 192.168.7.1
```

y quieres que esa Raspberry use específicamente:

```text
192.168.7.106
```

Entonces ejecuta:

```bash
sudo nmcli con mod "Wired connection 1" \
  ipv4.method manual \
  ipv4.addresses 192.168.7.106/24 \
  ipv4.gateway 192.168.7.1 \
  ipv4.dns "1.1.1.1 8.8.8.8" \
  ipv4.ignore-auto-routes yes \
  ipv4.ignore-auto-dns yes
```

Después aplica:

```bash
sudo nmcli con up "Wired connection 1"
```

Si estabas conectado remotamente usando la IP anterior, probablemente perderás esa conexión.

Después vuelve a conectarte usando:

```text
192.168.7.106
```

> No uses `192.168.7.106` en todas las Raspberry. Cada dispositivo debe tener una IP única.

---

## PASO 3 — Verificar que quedó correctamente

Después de usar la **Opción A o la Opción B**, revisa la dirección:

```bash
ip -4 addr show eth0
```

Si configuraste:

```text
192.168.7.106
```

debe aparecer:

```text
inet 192.168.7.106/24
```

Después confirma el gateway:

```bash
ip route | grep default
```

Debe aparecer algo similar a:

```text
default via 192.168.7.1 dev eth0
```

Finalmente confirma que NetworkManager ya tiene la configuración como manual:

```bash
nmcli con show "Wired connection 1" | grep -E 'ipv4.method|ipv4.addresses|ipv4.gateway|ipv4.dns'
```

Debe salir aproximadamente:

```text
ipv4.method: manual
ipv4.addresses: 192.168.7.106/24
ipv4.gateway: 192.168.7.1
ipv4.dns: 1.1.1.1,8.8.8.8
```

---

## Usar UUID en lugar del nombre de conexión

Si prefieres usar el UUID, también funciona.

Primero obténlo con:

```bash
nmcli connection show --active
```

Después puedes hacer:

```bash
sudo nmcli con mod TU_UUID \
  ipv4.method manual \
  ipv4.addresses 192.168.7.106/24 \
  ipv4.gateway 192.168.7.1 \
  ipv4.dns "1.1.1.1 8.8.8.8" \
  ipv4.ignore-auto-routes yes \
  ipv4.ignore-auto-dns yes
```

Y aplicar:

```bash
sudo nmcli con up TU_UUID
```

---

## Lo que cambia dependiendo de cada Raspberry

| Elemento | Cambia según |
| --- | --- |
| Nombre de conexión | Puede variar |
| UUID | Es diferente en cada Raspberry |
| Dispositivo | Normalmente `eth0`, pero debe confirmarse |
| Red | Depende de la sucursal/router |
| Máscara | Normalmente `/24`, pero debe confirmarse |
| Gateway | Depende de la sucursal/router |
| IP fija | Debe ser única para cada Raspberry |

### Resumen rápido

Si la Raspberry **ya tiene la IP que quieres conservar**:

```text
→ Usa OPCIÓN A
```

Si quieres **cambiarla a otra IP específica**:

```text
→ Usa OPCIÓN B
```

En ambos casos:

```text
1. Confirmar conexión
2. Confirmar IP/red/gateway
3. Aplicar configuración
4. nmcli con up
5. Verificar IP + gateway + ipv4.method manual
```