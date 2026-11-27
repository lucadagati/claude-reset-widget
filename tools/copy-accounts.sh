#!/bin/bash
# Copies the Claude logins of all accounts from the main (Buongiorno) server to another machine,
# so every account can be used there (e.g. via VS Code Remote-SSH + claude-switch-remote) without logging in again.
#
#   tools/copy-accounts.sh MAIN TARGET [DEST_HOME] [SKIP]
#   SKIP = comma-separated account names already logged in as the default (~/.claude) on TARGET: not copied, mapped to "default"
#   e.g. tools/copy-accounts.sh root@100.64.0.10 ops@100.64.0.11
#
# - Reads the account list from /opt/buongiorno/accounts.conf on MAIN (needs root there).
# - Only the OAuth credentials and the minimal account info are copied (not history or caches).
# - Secrets travel through the SSH pipe only: they are never written to this machine or to a repository.
# - On TARGET it creates ~/.claude-<name>/ (mode 700/600) and ~/.claude-accounts.conf for claude-switch-remote.
# Caveat: using the same login from several machines at once may invalidate one copy (token refresh); re-login if that happens.
set -euo pipefail
MAIN=${1:?usage: $0 MAIN TARGET [DEST_HOME]}; TARGET=${2:?usage: $0 MAIN TARGET [DEST_HOME]}; DEST=${3:-}; SKIP=${4:-}

read -r -d '' SRC <<'PY' || true
import json, os
out = {}
for l in open("/opt/buongiorno/accounts.conf"):
    l = l.strip()
    if not l or l.startswith("#"): continue
    name, d, off = (l.split("|") + ["0"])[:3]
    d = os.path.expanduser("~/.claude") if d == "default" else d
    cj = os.path.expanduser("~/.claude.json") if d == os.path.expanduser("~/.claude") else d + "/.claude.json"
    try:
        cred = json.load(open(d + "/.credentials.json")); info = json.load(open(cj))
    except Exception as e:
        continue
    out[name] = {"offset": off, "credentials": cred,
                 "claude_json": {k: info[k] for k in ("oauthAccount", "userID") if k in info} | {"hasCompletedOnboarding": True}}
print(json.dumps(out))
PY

read -r -d '' DST <<'PY' || true
import json, os, sys
dest = sys.argv[1] or os.path.expanduser("~"); skip = [x for x in (sys.argv[2] if len(sys.argv) > 2 else "").split(",") if x]
data = json.load(sys.stdin); lines = ["# name|config_dir|offset  (written by copy-accounts.sh)"]
for name, a in data.items():
    if name in skip:
        lines.append(f"{name}|default|{a['offset']}"); continue
    d = os.path.join(dest, ".claude-" + name); os.makedirs(d, mode=0o700, exist_ok=True)
    for fn, obj in ((".credentials.json", a["credentials"]), (".claude.json", a["claude_json"])):
        p = os.path.join(d, fn); fd = os.open(p, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w") as f: json.dump(obj, f)
    lines.append(f"{name}|{d}|{a['offset']}")
open(os.path.join(dest, ".claude-accounts.conf"), "w").write("\n".join(lines) + "\n")
print("copied accounts:", ", ".join(n for n in data if n not in skip), "| default:", ", ".join(skip) or "-")
PY

ssh -o BatchMode=yes "$MAIN" "python3 -c $(printf %q "$SRC")" | ssh -o BatchMode=yes "$TARGET" "python3 -c $(printf %q "$DST") '$DEST' '$SKIP'"
