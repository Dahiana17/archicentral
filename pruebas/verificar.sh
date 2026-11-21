#!/bin/bash
# Pruebas automaticas de ArchiCentral. Uso: sudo ./verificar.sh
CLAVE=Demo2026!
OK=0; FALLA=0
prueba() { if eval "$2" > /dev/null 2>&1; then echo "PASA   $1"; OK=$((OK+1)); else echo "FALLA  $1"; FALLA=$((FALLA+1)); fi; }
echo "Pruebas de ArchiCentral - $(date)"
echo "----------------------------------------------"
prueba "F1 Samba esta encendido" "systemctl is-active --quiet smbd"
prueba "F1 Luis entra a Ventas" "smbclient //localhost/ventas -U luis%$CLAVE -c ls"
prueba "F2 Luis NO entra a Contabilidad" "! smbclient //localhost/contabilidad -U luis%$CLAVE -c ls"
prueba "F2 Ana entra a Contabilidad" "smbclient //localhost/contabilidad -U ana%$CLAVE -c ls"
prueba "F2 Marta (Gerencia) puede leer Ventas" "smbclient //localhost/ventas -U marta%$CLAVE -c ls"
prueba "F3 Carpeta desarrollo compartida por NFS" "exportfs -v | grep -q desarrollo"
prueba "F4 La papelera guarda lo borrado" "test -d /srv/compartido/ventas/Papelera/luis"
prueba "F4 Limpieza de papelera programada" "grep -q limpiar_papelera /etc/cron.d/archicentral"
prueba "F5 Cuotas activas por departamento" "repquota -g /srv/compartido | grep -q ventas"
prueba "F5 Alerta de cuotas programada" "grep -q alerta_cuotas /etc/cron.d/archicentral"
prueba "F6 Existe un respaldo" "test -L /srv/respaldos/ultimo"
prueba "F6 Respaldo nocturno programado" "grep -q respaldo_nocturno /etc/cron.d/archicentral"
prueba "F7 El registro anota los accesos de Luis" "grep -q luis /var/log/samba/auditoria.log"
prueba "Automatizacion: script de departamentos" "test -x /usr/local/sbin/crear_departamento.sh"
prueba "Seguridad: firewall activo" "ufw status | grep -q active"
echo "----------------------------------------------"
echo "Resultado: $OK pasan, $FALLA fallan"
