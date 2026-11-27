# Buongiorno (server timer)

Sends a tiny message ("Buongiorno") to every Claude account listed in `accounts.conf` every **5 h 05 min** (305 min), with per-account **offsets**, so each account's 5-hour window opens as soon as the previous one ends and the resets of different accounts are spread evenly. Each run also stores the account's real **5-hour and weekly utilization** in `/var/lib/buongiorno/usage/<name>.json`.

See the [main README](../README.md) for the architecture, the data flow and how the widget consumes the usage files.

## How it works
- `buongiorno.timer` fires every minute (second :10); `buongiorno.sh` sends only in the minute where `(now − (ANCHOR + offset))` is a multiple of 305 min.
- Each request uses a minimal Claude Code configuration (Haiku, no tools/MCP/plugins, one-character system prompt): ~530 tokens instead of ~21,000.
- Accounts run in parallel; up to 3 attempts (2 min apart); non-authenticated accounts are skipped.
- `parse_usage.py` reads the `rate_limit_event` from `--output-format stream-json` and writes the usage file atomically.

## Files
| File | Purpose |
|---|---|
| `buongiorno.sh` | Main script (installed to `/opt/buongiorno/`) |
| `parse_usage.py` | Extracts utilization from the stream output |
| `poll_usage.py` | Refreshes utilization every 2 min from the OAuth usage endpoint (no message, no quota) |
| `accounts.example.conf` | Template for `accounts.conf` (`name|config_dir|offset_min`) |
| `systemd/` | Service and timer units |
| `install.sh` / `uninstall.sh` | Install/update or remove everything |
| `next_runs.sh` | Prints the next scheduled base-cycle times |

## Usage (as root)
```bash
cp accounts.example.conf accounts.conf && $EDITOR accounts.conf
CLAUDE_CONFIG_DIR=/root/.claude-account-b claude auth login   # once per non-default account (use a private browser window)
./install.sh
/opt/buongiorno/buongiorno.sh --force account-b               # test one account now
tail -f /var/log/buongiorno/buongiorno.log
systemctl stop buongiorno.timer                               # pause
./uninstall.sh
```

To move the schedule, change `ANCHOR` in `buongiorno.sh` and re-run `./install.sh`. Requirements: Claude Code CLI at `/root/.local/bin/claude`, `python3`, systemd. Every ping is a real (tiny) request and counts against your usage.
