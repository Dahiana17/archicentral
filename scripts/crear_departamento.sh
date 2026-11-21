#!/bin/bash
# Crea un departamento completo con un solo comando
# Uso: sudo crear_departamento.sh <nombre> [cuota_en_GB]
DEPTO="$1"
CUOTA_GB="${2:-2}"
BASE=/srv/compartido
if [ -z "$DEPTO" ]; then echo "Uso: $0 <nombre> [cuota_GB]"; exit 1; fi
if [ "$EUID" -ne 0 ]; then echo "Ejecuta con sudo"; exit 1; fi
if ! [[ "$DEPTO" =~ ^[a-z][a-z0-9_]+$ ]]; then echo "Nombre invalido: solo minusculas, sin espacios ni tildes"; exit 1; fi
if getent group "$DEPTO" > /dev/null; then echo "El departamento $DEPTO ya existe"; exit 1; fi
set -e
echo "1. Creando el grupo $DEPTO"
groupadd "$DEPTO"
echo "2. Creando la carpeta, los permisos y la papelera"
mkdir -p "$BASE/$DEPTO/Papelera"
chown -R root:"$DEPTO" "$BASE/$DEPTO"
chmod 2770 "$BASE/$DEPTO" "$BASE/$DEPTO/Papelera"
setfacl -m g:$DEPTO:rwx -m d:g:$DEPTO:rwx -m d:o::--- "$BASE/$DEPTO"
setfacl -m g:gerencia:rx -m d:g:gerencia:rx "$BASE/$DEPTO"
echo "3. Publicando la carpeta en la red (Samba)"
printf "\n[%s]\n   path = %s\n   valid users = @%s @gerencia\n   read list = @gerencia\n   write list = @%s\n   read only = no\n   force group = %s\n   create mask = 0660\n   directory mask = 2770\n   vfs objects = full_audit recycle\n" "$DEPTO" "$BASE/$DEPTO" "$DEPTO" "$DEPTO" "$DEPTO" >> /etc/samba/smb.conf
testparm -s > /dev/null 2>&1
smbcontrol all reload-config
echo "4. Aplicando una cuota de $CUOTA_GB GB"
HARD=$((CUOTA_GB * 1024 * 1024))
setquota -g "$DEPTO" $((HARD * 90 / 100)) $HARD 0 0 $BASE
logger -t crear_departamento "Departamento $DEPTO creado con cuota de $CUOTA_GB GB"
echo "Listo: \\\\192.168.56.10\\$DEPTO"
echo "Agrega personas con: sudo useradd -M -s /usr/sbin/nologin -G $DEPTO USUARIO && sudo smbpasswd -a USUARIO"
