#!/usr/bin/env python3
"""Legge l'output stream-json di `claude -p`, salva l'utilizzo (5h e settimanale) in <usage_dir>/<nome>.json
e stampa il testo della risposta. Uscita 1 se la risposta e' un errore."""
import json, sys, time, os
name, usage_dir = sys.argv[1], sys.argv[2]
win = None; text = ""; err = True   # errore finche' non arriva un risultato valido
for line in sys.stdin:
    try: e = json.loads(line)
    except Exception: continue
    if e.get("type") == "rate_limit_event":
        w = e.get("rate_limit_info", {}).get("unifiedWindows")
        if w: win = w
    elif e.get("type") == "result":
        text = e.get("result") or ""; err = bool(e.get("is_error"))
if win:
    os.makedirs(usage_dir, exist_ok=True)
    out = {"updated": int(time.time())}
    for k in ("five_hour", "seven_day"):
        if k in win: out[k] = {"utilization": win[k].get("utilization"), "resetsAt": win[k].get("resetsAt")}
    tmp = os.path.join(usage_dir, name + ".json.tmp")
    json.dump(out, open(tmp, "w")); os.replace(tmp, os.path.join(usage_dir, name + ".json"))
print(text)
sys.exit(1 if err else 0)
