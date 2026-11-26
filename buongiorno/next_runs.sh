#!/bin/bash
# Mostra i prossimi N invii (default 10) calcolati dall'ancora dello script installato.
N=${1:-10}
S=/opt/buongiorno/buongiorno.sh
ANCHOR=$(date -d "$(grep -oP "date -d '\K[^']+" "$S" | head -1)" +%s)
INT=$(grep -oP '^INTERVAL_MIN=\K[0-9]+' "$S")
NOW=$(date +%s)
K=$(( NOW <= ANCHOR ? 0 : (NOW - ANCHOR + INT*60 - 1) / (INT*60) ))
for i in $(seq 0 $((N-1))); do date -d @$((ANCHOR + (K+i)*INT*60)) '+%a %d/%m/%Y %H:%M'; done
