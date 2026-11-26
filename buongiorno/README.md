# Buongiorno multi-account

Invia il messaggio **"Buongiorno"** a Claude (`claude -p`, con modello Haiku e configurazione minima: ~500 token per invio) ogni **5h05m (305 min)** per ciascun
account elencato in `accounts.conf`, con le fasi **sfalsate** (offset) in modo che i reset delle
finestre da 5 ore cadano a distanza regolare tra gli account (con 3 account: ~102 min).
Gira come timer systemd: funziona con Claude Code chiuso e dopo un riavvio.

## Come funziona
Il timer scatta ogni minuto. Per ogni account lo script invia solo nel minuto in cui
`(ora - (ANCHOR + offset))` e' multiplo di 305 min. Gli account non autenticati vengono saltati;
se l'API non risponde ritenta fino a 3 volte (pausa 2 min). Gli account girano in parallelo.

## Configurazione account
Copia `accounts.example.conf` in `accounts.conf` (non versionato) e modifica le righe `nome|config_dir|offset_min`.
Ogni account ha una propria cartella di credenziali, scelta con `CLAUDE_CONFIG_DIR`. Login una tantum:

```bash
CLAUDE_CONFIG_DIR=/root/.claude-account-b claude auth login
```
Apri il link in una finestra in incognito, altrimenti il browser puo' riusare un'altra sessione e
collegare l'account sbagliato. Verifica con `CLAUDE_CONFIG_DIR=... claude auth status`.
Le credenziali restano sul server e **non fanno parte del repo**.

## Uso (come root)
```bash
./install.sh                                  # installa/aggiorna
./next_runs.sh 10                             # prossimi invii del ciclo base
/opt/buongiorno/buongiorno.sh --force nome    # invio di prova per un account
tail -f /var/log/buongiorno/buongiorno.log    # log, con prefisso [nome]
systemctl stop buongiorno.timer               # sospendi
./uninstall.sh                                # rimuove tutto
```
Per cambiare l'orario di partenza modifica `ANCHOR` in `buongiorno.sh` e rilancia `./install.sh`.

## Requisiti
Claude Code CLI in `/root/.local/bin/claude`, systemd. Ogni invio e' una vera richiesta e conta sul tuo utilizzo.
