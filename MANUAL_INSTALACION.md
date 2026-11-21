# Manual de instalación — ArchiCentral

Este manual permite repetir la instalación desde cero. Los archivos de configuración y los scripts están en este repositorio; los comandos se ejecutan en la terminal de Ubuntu.

## 1. Máquina virtual (VirtualBox)

| Parámetro | Valor |
|---|---|
| Sistema | Ubuntu 24.04 LTS |
| Memoria | 4 GB o más |
| Disco 1 | 25 GB (sistema) |
| Disco 2 | 20 GB (datos), agregado en *Configuración → Almacenamiento → Controlador SATA* (subir *Port Count* a 2) |
| Adaptador 1 | NAT (internet) |
| Adaptador 2 | Adaptador solo anfitrión, *VirtualBox Host-Only Ethernet Adapter*, con *Cable conectado* |

Antes, en VirtualBox: *Archivo → Herramientas → Administrador de red → Redes solo-anfitrión* debe existir un adaptador con `192.168.56.1/24`. Si al crearlo sale *"Could not find Host Interface Networking driver"*, desinstalar VirtualBox, reiniciar Windows e instalarlo de nuevo como administrador, aceptando la instalación de los controladores de Oracle.

## 2. Red: IP fija 192.168.56.10

```bash
sudo nmcli con add type ethernet ifname enp0s8 con-name oficina ipv4.method manual ipv4.addresses 192.168.56.10/24
sudo nmcli con up oficina
ip a show enp0s8          # debe decir state UP e inet 192.168.56.10/24
```

Desde Windows: `ping 192.168.56.10` debe responder.

## 3. Paquetes y hora local

```bash
sudo apt update
sudo apt install -y samba smbclient cifs-utils nfs-kernel-server quota rsync ufw acl lvm2 python3 openssh-server git
sudo timedatectl set-timezone America/Bogota
```

## 4. Disco de datos (LVM + cuotas)

Revisar con `lsblk` que el disco de 20 GB sea `sdb` (se borra todo su contenido).

```bash
sudo pvcreate /dev/sdb
sudo vgcreate vg_datos /dev/sdb
sudo lvcreate -L 8G -n lv_compartido vg_datos
sudo lvcreate -L 8G -n lv_respaldos vg_datos
sudo mkfs.ext4 -O quota -E quotatype=usrquota:grpquota /dev/vg_datos/lv_compartido
sudo mkfs.ext4 /dev/vg_datos/lv_respaldos
sudo mkdir -p /srv/compartido /srv/respaldos

U1=$(sudo blkid -s UUID -o value /dev/vg_datos/lv_compartido)
U2=$(sudo blkid -s UUID -o value /dev/vg_datos/lv_respaldos)
echo "UUID=$U1 /srv/compartido ext4 defaults,usrquota,grpquota 0 2" | sudo tee -a /etc/fstab
echo "UUID=$U2 /srv/respaldos ext4 defaults,nosuid,nodev 0 2" | sudo tee -a /etc/fstab
sudo systemctl daemon-reload
sudo mount -a
sudo quotaon -ug /srv/compartido    # "File exists" significa que ya estaban activas
sudo chmod 700 /srv/respaldos
df -h | grep srv
```

## 5. Departamentos y empleados

```bash
for g in gerencia contabilidad ventas desarrollo; do sudo groupadd $g; done
sudo useradd -M -s /usr/sbin/nologin -G contabilidad ana
sudo useradd -M -s /usr/sbin/nologin -G ventas luis
sudo useradd -M -s /usr/sbin/nologin -G gerencia marta
sudo useradd -M -s /usr/sbin/nologin -G desarrollo diego
for u in ana luis marta diego; do echo "Clave para $u:"; sudo smbpasswd -a $u; done
```

## 6. Carpetas y permisos

```bash
for g in gerencia contabilidad ventas desarrollo; do
  sudo mkdir -p /srv/compartido/$g/Papelera
  sudo chown -R root:$g /srv/compartido/$g
  sudo chmod 2770 /srv/compartido/$g /srv/compartido/$g/Papelera
  sudo setfacl -m g:$g:rwx -m d:g:$g:rwx -m d:o::--- /srv/compartido/$g
done
for g in contabilidad ventas desarrollo; do
  sudo setfacl -m g:gerencia:rx -m d:g:gerencia:rx /srv/compartido/$g
done
```

## 7. Copiar configuración y scripts del repositorio

Desde la carpeta del repositorio:

```bash
sudo cp config/smb.conf /etc/samba/smb.conf
sudo cp scripts/* /usr/local/sbin/ && sudo chmod +x /usr/local/sbin/*.sh /usr/local/sbin/*.py
sudo cp config/cron_archicentral /etc/cron.d/archicentral
sudo cp config/30-auditoria.conf /etc/rsyslog.d/
sudo cp config/auditoria /etc/logrotate.d/
sudo mkdir -p /etc/exports.d && sudo cp config/archicentral.exports /etc/exports.d/
```

**Importante (NFS):** el archivo `archicentral.exports` tiene `anongid=1004`, que es el número del grupo `desarrollo` en el equipo original. Revisar el número en el equipo nuevo con `getent group desarrollo` y cambiarlo si es distinto.

## 8. Encender los servicios

```bash
sudo touch /var/log/samba/auditoria.log && sudo chown syslog:adm /var/log/samba/auditoria.log
sudo systemctl restart rsyslog
testparm -s > /dev/null && echo "CONFIGURACION OK"
sudo systemctl restart smbd nmbd
sudo systemctl enable --now nfs-server && sudo exportfs -ra
```

## 9. Cuotas (2 GB por departamento)

```bash
for g in gerencia contabilidad ventas desarrollo; do sudo setquota -g $g 1887436 2097152 0 0 /srv/compartido; done
sudo repquota -g -s /srv/compartido
```

## 10. Firewall

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow from 192.168.56.0/24 to any port 445 proto tcp
sudo ufw allow from 192.168.56.0/24 to any port 139 proto tcp
sudo ufw allow from 192.168.56.0/24 to any port 137,138 proto udp
sudo ufw allow from 192.168.56.0/24 to any port 2049 proto tcp
sudo ufw --force enable
sudo ufw status numbered
```

## 11. Primer respaldo y pruebas

```bash
sudo /usr/local/sbin/respaldo_nocturno.sh
sudo ./pruebas/verificar.sh
```

Para que pasen todas las pruebas, Luis debe haber entrado y borrado algo al menos una vez (eso crea `Papelera/luis` y deja registro en la auditoría).

## 12. Conectarse

| Desde | Cómo |
|---|---|
| Windows | Explorador → `\\192.168.56.10\ventas` → usuario `luis`, clave `Demo2026!` |
| Linux (escritorio) | Archivos → Otras ubicaciones → `smb://192.168.56.10/ventas` |
| Linux de desarrollo | `sudo mount -t nfs4 192.168.56.10:/srv/compartido/desarrollo /mnt/desarrollo` |
| Administración | `ssh dahiana@192.168.56.10` |

## 13. Uso diario

```bash
sudo crear_departamento.sh marketing 1                     # nuevo departamento con 1 GB
sudo useradd -M -s /usr/sbin/nologin -G marketing sofia && sudo smbpasswd -a sofia
sudo alerta_cuotas.py                                      # uso de espacio por área
sudo tail -n 20 /var/log/samba/auditoria.log               # últimos accesos
sudo ls /srv/respaldos                                     # respaldos disponibles
sudo cp -a /srv/respaldos/ultimo/ventas/ARCHIVO /srv/compartido/ventas/   # restaurar
```

## 14. Problemas frecuentes

| Síntoma | Solución |
|---|---|
| `enp0s8` no existe | El Adaptador 2 no está habilitado en VirtualBox (máquina apagada → Configuración → Red → Adaptador 2) |
| `NO-CARRIER` / `state DOWN` | En la ventana de la VM: Dispositivos → Red → Adaptador de red 2 → Conectar cable de red |
| Windows: "Host de destino inaccesible" | El Adaptador 2 quedó en NAT; cambiarlo a "Adaptador solo anfitrión" |
| Windows: "conexiones múltiples ... no están permitidas" | Windows ya está conectado con otro usuario: en PowerShell `net use * /delete` |
| Bloques largos se pegan cortados en PowerShell | Pegar en la terminal de Ubuntu (`Ctrl + Shift + V`) o en comandos más cortos |
| `smb.conf` con errores | `testparm` muestra la línea con el problema |
| El registro de auditoría está vacío | `sudo systemctl restart rsyslog smbd` y volver a entrar desde Windows |
