#!/usr/bin/env python3
# Alerta cuando un departamento pasa el 80 por ciento de su cuota
import datetime, os, subprocess
UMBRAL = 80
salida = subprocess.run(["repquota", "-g", "-p", "/srv/compartido"], capture_output=True, text=True).stdout
for linea in salida.splitlines():
    c = linea.split()
    if len(c) < 5 or not c[2].isdigit():
        continue
    depto, usado, limite = c[0], int(c[2]), int(c[4])
    if limite == 0:
        continue
    pct = usado * 100 / limite
    aviso = "/srv/compartido/" + depto + "/AVISO_ESPACIO.txt"
    if pct >= UMBRAL:
        msg = "ALERTA: " + depto + " usa el " + str(round(pct)) + "% de su cuota (" + str(usado // 1024) + " MB de " + str(limite // 1024) + " MB)"
        subprocess.run(["logger", "-t", "alerta_cuotas", msg])
        with open("/var/log/alertas_cuotas.log", "a") as f:
            f.write(datetime.datetime.now().strftime("%Y-%m-%d %H:%M") + " " + msg + "\n")
        with open(aviso, "w") as f:
            f.write(msg + "\r\nPor favor liberen espacio o avisen a sistemas.\r\n")
    elif os.path.exists(aviso):
        os.remove(aviso)
    print(depto.ljust(14), str(round(pct, 1)).rjust(5), "%")
