#!/bin/bash
# Respaldo nocturno de las carpetas compartidas
ORIGEN=/srv/compartido/
DESTINO=/srv/respaldos
HOY=$(date +%F_%H%M)
ULTIMO=$DESTINO/ultimo
if rsync -aAX --delete --link-dest="$ULTIMO" --exclude=lost+found "$ORIGEN" "$DESTINO/$HOY/"; then
  touch "$DESTINO/$HOY"
  ln -sfn "$DESTINO/$HOY" "$ULTIMO"
  logger -t respaldo "Respaldo $HOY OK"
else
  logger -t respaldo "ERROR en el respaldo $HOY"
  exit 1
fi
# Borrar respaldos de mas de 14 dias
find "$DESTINO" -maxdepth 1 -type d -name "20*" -mtime +14 -exec rm -rf {} +
