#!/usr/bin/env python3
"""Aggiorna <usage_dir>/<nome>.json per ogni account di accounts.conf leggendo l'utilizzo reale
(5h e settimanale) dall'endpoint OAuth usato da /usage di Claude Code. Non invia messaggi e non
consuma quota. Usa il token gia' salvato dal CLI: se e' scaduto salta l'account (il CLI lo rinnova
al prossimo utilizzo) e il file precedente resta com'e'.
Uso: poll_usage.py <accounts.conf> <usage_dir>"""
import json, os, sys, time, urllib.request
from datetime import datetime

conf, usage_dir = sys.argv[1], sys.argv[2]
URL = "https://api.anthropic.com/api/oauth/usage"

def epoch(s):
    try: return int(datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp())
    except Exception: return None

def poll(name, cdir):
    cdir = os.path.expanduser("~/.claude") if cdir == "default" else cdir
    try:
        c = json.load(open(os.path.join(cdir, ".credentials.json")))["claudeAiOauth"]
    except Exception:
        return
    if c.get("expiresAt", 0) / 1000 < time.time() + 60:
        return
    req = urllib.request.Request(URL, headers={"Authorization": "Bearer " + c["accessToken"],
                                               "anthropic-beta": "oauth-2025-04-20",
                                               "User-Agent": "buongiorno-usage"})
    try:
        d = json.loads(urllib.request.urlopen(req, timeout=10).read())
    except Exception as e:
        print(f"[{name}] usage: {e}", file=sys.stderr); return
    out = {"updated": int(time.time()), "source": "oauth"}
    for k in ("five_hour", "seven_day"):
        w = d.get(k)
        if isinstance(w, dict) and w.get("utilization") is not None:
            # l'endpoint restituisce percentuali (0-100), il widget si aspetta frazioni (0-1)
            out[k] = {"utilization": w["utilization"] / 100, "resetsAt": epoch(w.get("resets_at") or "")}
    if len(out) == 2:
        return
    tmp = os.path.join(usage_dir, name + ".json.tmp")
    with open(tmp, "w") as f: json.dump(out, f)
    os.replace(tmp, os.path.join(usage_dir, name + ".json"))

os.makedirs(usage_dir, exist_ok=True)
for line in open(conf):
    line = line.strip()
    if not line or line.startswith("#"): continue
    parts = line.split("|")
    if len(parts) >= 2: poll(parts[0], parts[1])
