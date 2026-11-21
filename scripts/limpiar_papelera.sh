#!/bin/bash
# Elimina de las papeleras lo que lleva mas de 15 dias
DIAS=15
for p in /srv/compartido/*/Papelera; do
  find "$p" -type f -mtime +$((DIAS - 1)) -print -delete
  find "$p" -mindepth 2 -type d -empty -delete
done | logger -t limpiar_papelera
