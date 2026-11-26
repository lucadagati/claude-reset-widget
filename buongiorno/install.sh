#!/bin/bash
# Installa (o aggiorna) script, configurazione account e timer systemd. Eseguire come root.
set -e
cd "$(dirname "$0")"
install -D -m 755 buongiorno.sh /opt/buongiorno/buongiorno.sh
install -m 755 parse_usage.py /opt/buongiorno/parse_usage.py
mkdir -p /var/lib/buongiorno/usage
# accounts.conf: usa quello locale se c'e', altrimenti l'esempio (solo se non esiste gia' sul sistema)
if [ -f accounts.conf ]; then install -m 644 accounts.conf /opt/buongiorno/accounts.conf
elif [ ! -f /opt/buongiorno/accounts.conf ]; then install -m 644 accounts.example.conf /opt/buongiorno/accounts.conf
  echo "Creato /opt/buongiorno/accounts.conf dall'esempio: modificalo con i tuoi account."; fi
install -m 644 systemd/buongiorno.service systemd/buongiorno.timer /etc/systemd/system/
mkdir -p /var/log/buongiorno
systemctl daemon-reload
systemctl enable --now buongiorno.timer
systemctl list-timers buongiorno.timer --no-pager
