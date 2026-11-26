#!/bin/bash
# Invia "Buongiorno" a Claude ogni 5h05m (305 min) per OGNI account in accounts.conf,
# con le fasi sfalsate (offset in minuti) cosi' i reset delle finestre da 5h
# cadono a distanza regolare (~102 min) tra i 3 account.
# Il timer gira ogni minuto; per ogni account si invia solo nel minuto in cui
# (ora - (ANCHOR + offset)) e' multiplo di 305 min. Account non loggati: saltati.
ANCHOR=$(date -d '2026-10-07 01:04' +%s)
INTERVAL_MIN=305
CONF=/opt/buongiorno/accounts.conf   # righe: nome|config_dir|offset_min   (config_dir "default" = ~/.claude)
LOG=/var/log/buongiorno/buongiorno.log
USAGE_DIR=/var/lib/buongiorno/usage   # utilizzo 5h/settimana per account, letto dal widget
PROMPT="${BUONGIORNO_PROMPT:-Buongiorno}"
mkdir -p "$(dirname "$LOG")"

send() {  # $1=nome $2=config_dir
  local name="$1" dir="$2" env=() out rc
  [ "$dir" != "default" ] && env=(CLAUDE_CONFIG_DIR="$dir")
  if ! (cd /tmp && env "${env[@]}" /root/.local/bin/claude auth status 2>/dev/null | grep -q '"loggedIn": true'); then
    echo "[$(date '+%F %T')] [$name] non autenticato, salto" >> "$LOG"; return 1
  fi
  for try in 1 2 3; do
    echo "[$(date '+%F %T')] [$name] invio Buongiorno (tentativo $try)" >> "$LOG"
    out=$(cd /tmp && env "${env[@]}" timeout 90 /root/.local/bin/claude -p "$PROMPT" --output-format stream-json --verbose 2>&1 | python3 /opt/buongiorno/parse_usage.py "$name" "$USAGE_DIR"); rc=$?
    echo "[$name] $out" >> "$LOG"
    if [ $rc -eq 0 ] && ! grep -q "API Error" <<<"$out"; then
      echo "[$(date '+%F %T')] [$name] ok" >> "$LOG"; return 0
    fi
    echo "[$(date '+%F %T')] [$name] errore (rc=$rc)" >> "$LOG"
    [ $try -lt 3 ] && sleep 120
  done
  return 1
}

FORCE=0; [ "$1" = "--force" ] && { FORCE=1; shift; }   # --force [nome]
ONLY="$1"
while IFS='|' read -r name dir offset; do
  [[ -z "$name" || "$name" == \#* ]] && continue
  [ -n "$ONLY" ] && [ "$ONLY" != "$name" ] && continue
  if [ $FORCE -eq 0 ]; then
    ELAPSED=$(( $(date +%s) - ANCHOR - offset*60 ))
    [ "$ELAPSED" -lt 0 ] && continue
    [ $(( ELAPSED % (INTERVAL_MIN * 60) )) -ge 60 ] && continue
  fi
  send "$name" "$dir" &     # in parallelo: i retry di un account non bloccano gli altri
done < "$CONF"
wait
