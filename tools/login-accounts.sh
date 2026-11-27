#!/bin/bash
# Independent Claude logins for one server (no credential copying between machines).
#
#   DEFAULT_NAME=main-account tools/login-accounts.sh TARGET extra-account...
#   e.g. DEFAULT_NAME=account-a tools/login-accounts.sh dev@100.64.0.11 account-b account-c
#
# Convention: DEFAULT_NAME (required) is always the default login (~/.claude) on every server. The extra
# accounts get their own config dir ~/.claude-<name>, selected through CLAUDE_CONFIG_DIR by claude-switch-remote.
# Offsets written to the accounts file follow the order given (0, 102, 203 ... minutes) like buongiorno/accounts.conf.
#
# Interactive: for every login open the link in a PRIVATE browser window and sign in with that account.
#   SKIP_DEFAULT=1   leave the existing default login untouched (when it is already the right account)
# Safety: the previous default credentials are saved as ~/.claude/.credentials.json.bak-<date>; an existing
# ~/.claude-<name> is moved to ~/.claude-<name>.old. `auth logout` is never used (logging out a copied login
# can revoke the original on another machine). At the end ~/.claude-accounts.conf is written and every
# account is checked with a real (tiny) request.
set -euo pipefail
TARGET=${1:?usage: DEFAULT_NAME=... $0 TARGET extra-account...}; shift; EXTRA=("$@")
DEFAULT_NAME=${DEFAULT_NAME:?set DEFAULT_NAME to the account that must be the default login}
BIN='setopt nonomatch 2>/dev/null; B=$(ls -d ~/.local/bin/claude ~/.vscode-server/extensions/anthropic.claude-code-*/resources/native-binary/claude ~/.vscode/extensions/anthropic.claude-code-*/resources/native-binary/claude 2>/dev/null | tail -1)'
OFFSETS=(0 102 203 305)

if [ -z "${SKIP_DEFAULT:-}" ]; then
  echo; echo "=== default login ($DEFAULT_NAME) ==="
  ssh -t "$TARGET" "$BIN; mkdir -p ~/.claude; [ -f ~/.claude/.credentials.json ] && cp -p ~/.claude/.credentials.json ~/.claude/.credentials.json.bak-\$(date +%F-%H%M); unset CLAUDE_CONFIG_DIR; \$B auth login"
fi
CONF="# name|config_dir|offset\n$DEFAULT_NAME|default|0"
i=1
for n in "${EXTRA[@]}"; do
  echo; echo "=== $n ==="
  ssh -t "$TARGET" "$BIN; d=\$HOME/.claude-$n; [ -e \$d ] && mv \$d \$d.old; mkdir -p \$d; CLAUDE_CONFIG_DIR=\$d \$B auth login"
  CONF+="\n$n|\$HOME/.claude-$n|${OFFSETS[$i]:-0}"; i=$((i+1))
done
ssh "$TARGET" "$BIN; T=\$(command -v timeout || command -v gtimeout || true); printf '$CONF\n' | sed \"s#\\\$HOME#\$HOME#\" > ~/.claude-accounts.conf; cd /tmp
for n in default ${EXTRA[*]:-}; do if [ \$n = default ]; then unset CLAUDE_CONFIG_DIR; else export CLAUDE_CONFIG_DIR=\$HOME/.claude-\$n; fi
  echo -n \"\$n: \$(\$B auth status 2>&1 | grep -o '\\\"email\\\": \\\"[^\\\"]*\\\"') -> \"; \$T 60 \$B -p ok --model haiku --system-prompt 'Reply with one character.' --tools '' --setting-sources '' </dev/null 2>&1 | head -1; done"
