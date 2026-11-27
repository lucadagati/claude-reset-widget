#!/bin/bash
# Independent Claude logins for one server (no credential copying between machines).
#
#   tools/login-accounts.sh TARGET name1 name2 ...            # e.g. dev@100.64.0.11 account-a account-b
#   DEFAULT=account-c tools/login-accounts.sh TARGET account-a account-b
#
# For every name it creates ~/.claude-<name> on TARGET and runs `claude auth login` there (interactive:
# open the link in a PRIVATE browser window and sign in with that account). DEFAULT = account already
# logged in as the default ~/.claude on TARGET (not touched). At the end it writes ~/.claude-accounts.conf
# for claude-switch-remote and checks each login with a real (tiny) request.
# An existing ~/.claude-<name> is moved aside to ~/.claude-<name>.old (never `auth logout`: logging out a
# *copied* login can revoke the original one on another machine).
set -euo pipefail
TARGET=${1:?usage: $0 TARGET name...}; shift; NAMES=("$@"); [ ${#NAMES[@]} -gt 0 ] || { echo "no account names"; exit 1; }
CLAUDE='B=$(ls -d ~/.local/bin/claude ~/.vscode-server/extensions/anthropic.claude-code-*/resources/native-binary/claude 2>/dev/null | head -1)'
OFFSETS=(0 102 203)
i=0; CONF="# name|config_dir|offset"
for n in "${NAMES[@]}"; do
  echo; echo "=== $n ==="
  ssh -t "$TARGET" "$CLAUDE; d=\$HOME/.claude-$n; [ -e \$d ] && mv \$d \$d.old; mkdir -p \$d; CLAUDE_CONFIG_DIR=\$d \$B auth login"
  CONF+="\n$n|\$HOME/.claude-$n|${OFFSETS[$i]:-0}"; i=$((i+1))
done
[ -n "${DEFAULT:-}" ] && CONF+="\n$DEFAULT|default|${OFFSETS[$i]:-0}"
ssh "$TARGET" "$CLAUDE; printf '$CONF\n' | sed \"s#\\\$HOME#\$HOME#\" > ~/.claude-accounts.conf; cd /tmp
for n in ${NAMES[*]} ; do export CLAUDE_CONFIG_DIR=\$HOME/.claude-\$n; echo -n \"\$n: \$(\$B auth status 2>&1 | grep -o '\\\"email\\\": \\\"[^\\\"]*\\\"') -> \"; timeout 60 \$B -p ok --model haiku --system-prompt 'Reply with one character.' --tools '' --setting-sources '' </dev/null 2>&1 | head -1; done"
