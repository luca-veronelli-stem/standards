================================================================================
                    STEM DICTIONARIES MANAGER v0.6.0
                              STEM E.m.s.
================================================================================

DESCRIZIONE
-----------
Applicazione per la gestione centralizzata dei dizionari dispositivi STEM
(comandi + variabili). Sostituisce i file Excel con un database SQL
centralizzato, con audit trail completo, interfaccia desktop moderna
e API REST per consumer esterni.


REQUISITI
---------
- Windows 10/11 (64-bit)
- .NET 10.0 Desktop Runtime
- Nessuna installazione richiesta


AVVIO
-----
Doppio click su: Stem.Dictionaries.Manager.exe


================================================================================
                         CONFIGURAZIONE DATABASE
================================================================================

L'applicazione supporta due modalita' di database, selezionabili tramite
il campo "DatabaseProvider" nel file appsettings.json:

  "DatabaseProvider": "SqlServer"   -> Azure SQL (produzione)
  "DatabaseProvider": "Sqlite"      -> SQLite locale (sviluppo)


1. SQLite (SVILUPPO)
   - Impostare "DatabaseProvider": "Sqlite" in appsettings.json
   - Il database viene creato automaticamente al primo avvio
   - Posizione: %AppData%\STEM\DictionariesManager\
   - Nessuna altra configurazione richiesta

2. Azure SQL (PRODUZIONE)
   - Impostare "DatabaseProvider": "SqlServer" in appsettings.json
   - Le migrations vengono applicate automaticamente all'avvio
   - Richiede la variabile d'ambiente con la connection string (vedi sotto)

CONFIGURAZIONE AZURE SQL:
-------------------------
1. Richiedere la connection string al contatto di supporto
2. Impostare la variabile d'ambiente:

   Da PowerShell:
   [Environment]::SetEnvironmentVariable("ConnectionStrings__SqlServer", "<CONNECTION_STRING>", "User")

   O da Prompt dei comandi:
   setx ConnectionStrings__SqlServer "<CONNECTION_STRING>"

3. Chiudere e riaprire l'applicazione per applicare le modifiche

Nota: Sostituire <CONNECTION_STRING> con il valore fornito dal supporto.
      Non modificare direttamente appsettings.json per la connection string.


================================================================================
                         PRIMO AVVIO
================================================================================

1. Avviare l'applicazione
2. Il database viene inizializzato automaticamente con i dati di base:
   - 14 dizionari dispositivi + Standard
   - 5 utenti di sistema
   - Variabili, comandi e schede per tutti i device STEM
3. Selezionare il proprio utente nella schermata di login
4. Premere ACCEDI


================================================================================
                              FUNZIONALITA'
================================================================================

- Gestione dizionari: CRUD completo per dizionari dispositivi
- Gestione variabili: creazione, modifica, indirizzamento, Bitmapped
- Variabili standard: ereditate automaticamente, override per-dizionario
- Gestione comandi: comandi protocollo con parametri e stato per device
- Gestione dispositivi: CRUD dispositivi, dettaglio schede associate
- Gestione schede: FirmwareType, dizionario associato, IsPrimary
- Audit trail: traccia ogni modifica con utente, data e valori JSON
- Filtro e ricerca: ricerca istantanea in tutte le liste
- Dark theme: interfaccia STEM con palette corporate
- API REST: 12 endpoint per consumer esterni (Production.Tracker, etc.)
- Auto-fill: MachineCode e FirmwareType pre-compilati in creazione


================================================================================
                               SUPPORTO
================================================================================

Per problemi o richieste: l.veronelli@stem.it


================================================================================
                         (c) 2026 STEM E.m.s.
                      Tutti i diritti riservati
================================================================================