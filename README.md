# Claude Reset Widget

Widget per la barra dei menu di macOS che mostra, per più account Claude, il countdown al reset settimanale e lo stato della finestra da 5 ore. Include un selettore per cambiare account nell'estensione VS Code senza rifare il login.

## Installazione
```sh
cp accounts.example.json accounts.json   # poi modifica nomi e date
swiftc -O main.swift -o ClaudeResetWidget
./ClaudeResetWidget &
```
Posizione prevista: `~/ClaudeResetWidget`. Per l'avvio al login crea un LaunchAgent che punti al binario.

## accounts.json
- `name`: etichetta dell'account
- `anchor`: una qualsiasi data/ora di reset settimanale (ISO 8601); il widget ripete +7 giorni
- `offset`: minuti di sfasamento del ciclo "Buongiorno" da 5h05m (opzionale)
- `configDir`: cartella credenziali Claude dell'account; omessa = `~/.claude`

## Cambio account in VS Code
```sh
./claude-switch login account-b   # una tantum, per ogni account
./claude-switch account-b         # imposta CLAUDE_CONFIG_DIR per l'estensione
```
I login e le credenziali restano nelle cartelle `configDir` e nel Keychain: non fanno parte del repo.

## Buongiorno (server)
Nella cartella [`buongiorno/`](buongiorno/) c'e' il timer systemd che apre in anticipo le finestre da 5 ore su piu' account.
