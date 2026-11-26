#!/bin/bash
# Ferma e rimuove il timer e lo script installati (il log resta in /var/log/buongiorno).
set -e
systemctl disable --now buongiorno.timer || true
rm -f /etc/systemd/system/buongiorno.service /etc/systemd/system/buongiorno.timer
rm -rf /opt/buongiorno
systemctl daemon-reload
echo "Buongiorno rimosso."
