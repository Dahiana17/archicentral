# ArchiCentral — Servidor de archivos corporativo para Windows y Linux

Proyecto integrador de Sistemas Operativos · Proyecto 05

## El problema

Una pyme comparte documentos por memorias USB y correo. Se pierden versiones, nadie sabe cuál es el archivo bueno y **todos ven todo** (por ejemplo, la nómina). Si se daña un computador o se pierde una USB, se pierde el trabajo.

## La solución

ArchiCentral es un servidor Linux que funciona como una **bodega digital con llave por área**. Cada departamento tiene su carpeta en la red, solo entra su gente, lo borrado se puede recuperar, todo se respalda cada noche y queda registro de quién hizo qué.

## Funcionalidades y cómo se verifican

| # | Funcionalidad | Cómo se comprueba | Tecnología |
|---|---|---|---|
| 1 | Carpetas compartidas accesibles desde Windows y Linux | `\\192.168.56.10\ventas` abre en el Explorador de Windows con usuario y clave | Samba |
| 2 | Carpetas por departamento (Contabilidad, Ventas, Gerencia, Desarrollo) con permisos por grupo | Luis (Ventas) recibe "Acceso denegado" en Contabilidad; Gerencia puede leer las demás áreas | Grupos Linux, permisos `2770`, ACL |
| 3 | Carpeta NFS para los equipos Linux de desarrollo | `mount -t nfs4 192.168.56.10:/srv/compartido/desarrollo /mnt/desarrollo` y guardar un archivo | NFSv4 |
| 4 | Papelera en red: lo borrado se recupera durante 15 días | Al borrar un archivo aparece en `Papelera/<usuario>`; un archivo de 16 días se elimina solo | Samba `vfs recycle` + `limpiar_papelera.sh` + cron |
| 5 | Cuotas de espacio por departamento y alerta al acercarse al límite | Al pasar el 80 % aparece `AVISO_ESPACIO.txt` y una línea en el log; al 100 % el servidor responde `NT_STATUS_DISK_FULL` | quota + `alerta_cuotas.py` + cron |
| 6 | Respaldo nocturno automático | Cron a las 2:00 a. m.; carpeta con fecha en `/srv/respaldos`; se restaura un archivo borrado | rsync + `respaldo_nocturno.sh` + cron |
| 7 | Registro de accesos: quién abrió, creó o borró y desde qué IP | `/var/log/samba/auditoria.log` muestra `luis\|192.168.56.1\|...\|unlinkat\|...factura.txt` | Samba `vfs full_audit` + rsyslog |

**Automatización:** `sudo crear_departamento.sh marketing 1` crea con un solo comando el grupo, la carpeta, los permisos, la papelera, el recurso Samba y una cuota de 1 GB.

**Seguridad:** firewall UFW que solo deja entrar a la red de la oficina (192.168.56.0/24) por los puertos de Samba (445, 139, 137-138) y NFS (2049), más SSH (22) para administrar.

**Pruebas:** `sudo ./pruebas/verificar.sh` revisa todo en segundos. Último resultado: **15 pasan, 0 fallan** (ver `evidencias/`).

## Arquitectura

```
  PC Windows (192.168.56.1)                 Equipo Linux de desarrollo
  \\192.168.56.10\ventas  (SMB 445)         mount -t nfs4 ...  (NFS 2049)
              \                                   /
               v                                 v
  +-------------------- Firewall UFW --------------------+
  |  solo 192.168.56.0/24 -> 445,139,137-138 · 2049 · 22   |
  +--------------------------------------------------------+
  |  VM Ubuntu 24.04 LTS  "ejercicio07"  192.168.56.10     |
  |  Samba (recycle, full_audit) · NFS · rsyslog · cron    |
  |                                                        |
  |  Disco 2 (20 GB) -> LVM vg_datos                       |
  |    lv_compartido (ext4 + cuotas) -> /srv/compartido    |
  |       contabilidad/ ventas/ gerencia/ desarrollo/      |
  |    lv_respaldos (ext4)            -> /srv/respaldos    |
  +--------------------------------------------------------+
```

## Estructura del repositorio

```
archicentral/
├── README.md                    este archivo
├── MANUAL_INSTALACION.md        cómo instalarlo desde cero
├── config/
│   ├── smb.conf                 configuración de Samba (va en /etc/samba/)
│   ├── archicentral.exports     carpeta compartida por NFS (va en /etc/exports.d/)
│   ├── cron_archicentral        tareas automáticas (va en /etc/cron.d/archicentral)
│   ├── 30-auditoria.conf        registro de accesos (va en /etc/rsyslog.d/)
│   └── auditoria                rotación del registro (va en /etc/logrotate.d/)
├── scripts/                     (van en /usr/local/sbin/)
│   ├── crear_departamento.sh    automatización: crea un departamento completo
│   ├── limpiar_papelera.sh      vacía lo de la papelera con más de 15 días
│   ├── alerta_cuotas.py         alerta cuando un departamento pasa el 80 %
│   └── respaldo_nocturno.sh     copia de seguridad diaria con rsync
├── pruebas/
│   └── verificar.sh             pruebas automáticas de todas las funcionalidades
└── evidencias/                  resultados de pruebas, capturas y video
```

## Tareas programadas (cron)

| Hora | Tarea |
|---|---|
| Todos los días 2:00 a. m. | Respaldo de todas las carpetas |
| Todos los días 3:30 a. m. | Limpieza de la papelera (más de 15 días) |
| Cada 30 minutos | Revisión de cuotas y alertas |

## Conocimientos de Sistemas Operativos aplicados

| Tema | Dónde se usa |
|---|---|
| Usuarios, grupos y permisos | Un grupo por departamento, carpetas `2770` con setgid, ACL con `setfacl`, empleados sin acceso a la consola (`nologin`) |
| Sistemas de archivos y discos | LVM, ext4 con cuotas por grupo, montaje automático con `/etc/fstab` |
| Procesos y servicios | `smbd`, `nmbd`, `nfs-server` y `rsyslog` administrados con `systemctl` |
| Planificación de tareas | cron para el respaldo, la papelera y las alertas |
| Redes | SMB y NFSv4, puertos, IP fija con NetworkManager (`nmcli`), firewall UFW |
| Registros y seguridad | Auditoría con syslog, rotación con logrotate |
| Programación de sistemas | Scripts en Bash y Python |

## Usuarios de demostración

Clave de todos: `Demo2026!` (solo para la presentación).

| Usuario | Departamento |
|---|---|
| ana | Contabilidad |
| luis | Ventas |
| marta | Gerencia (lee todas las áreas) |
| diego | Desarrollo |
| sofia | Marketing (creado con el script de automatización) |

## Equipo

| Integrante | Responsabilidad |
|---|---|
| [Dahiana Marin] | Samba, permisos por área, NFS y papelera (F1, F2, F3, F4) |
| [Angel Moncada] | Cuotas y alertas, respaldo, registro de accesos, firewall y script de departamentos (F5, F6, F7) |

## Limitaciones conocidas

- El respaldo está en otro volumen del mismo disco; en una empresa real debe ir a otro disco, un NAS o la nube.
- Por NFS el servidor conoce la IP del equipo, no la persona; la auditoría detallada se hace por Samba.
- El registro anota también cuando Windows abre carpetas para mostrarlas, por eso tiene muchas líneas `openat`.
