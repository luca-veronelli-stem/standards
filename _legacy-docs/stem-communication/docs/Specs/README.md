# Docs/Specs

Questa cartella contiene le **specifiche formali Lean 4** generate durante lo step 3.5 del workflow.

## Scopo

Le specifiche Lean 4 servono a:
1. **Cristallizzare** i requisiti concordati prima dell'implementazione
2. **Documentare** precondizioni, postcondizioni e invarianti
3. **Verificare** che il piano di trasformazione sia completo

## Struttura File

Ogni file segue la convenzione `{IssueId}.lean`:
- `T006.lean` - Spec per issue T-006
- `DL002.lean` - Spec per issue DL-002
- etc.

## Template

Vedi `.github/formal-spec-agent.md` per il template standard.

## Note

- I file `.lean` sono **documentazione formale**, non richiedono Lean 4 installato
- Servono come contratto tra umano e AI
- Possono guidare la creazione dei test
