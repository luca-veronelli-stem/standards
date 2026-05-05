================================================================================
                         SPARK LOG ANALYZER v0.6.0
                              STEM E.m.s.
================================================================================

DESCRIZIONE
-----------
Applicazione per l'analisi dei log delle macchine SPARK.
Permette di visualizzare, filtrare ed esportare i dati di funzionamento.


REQUISITI
---------
- Windows 10/11 (64-bit)
- Nessuna installazione richiesta


AVVIO
-----
Doppio click su: SparkLogAnalyzer.exe


================================================================================
						 CONFIGURAZIONE AZURE
================================================================================

Per scaricare automaticamente i log da Azure Table Storage, configurare le
variabili d'ambiente seguenti.

VARIABILI RICHIESTE:
--------------------
1. SPARK_LOGS_TABLE_SAS_URL (obbligatoria per sync automatico)
   Permette di scaricare i log delle macchine.

2. SPARK_CUSTOMERS_TABLE_SAS_URL (opzionale)
   Permette di includere i dati utilizzatore nell'export Riepilogo.
   Se non configurata, le colonne "Data installazione", "Utilizzatore" e 
   "Città utilizzatore" mostreranno "N/A".

PROCEDURA:
1. Richiedi gli URL SAS al contatto di supporto
2. Avvia l'app Windows PowerShell ed esegui i comandi:
	[Environment]::SetEnvironmentVariable("SPARK_LOGS_TABLE_SAS_URL", "<LOGS_SAS_URL>", "User")
	[Environment]::SetEnvironmentVariable("SPARK_CUSTOMERS_TABLE_SAS_URL", "<CUSTOMERS_SAS_URL>", "User")
   O in alternativa da Prompt dei comandi:
	setx SPARK_LOGS_TABLE_SAS_URL "<LOGS_SAS_URL>"
	setx SPARK_CUSTOMERS_TABLE_SAS_URL "<CUSTOMERS_SAS_URL>"
3. Chiudi e riapri l'applicazione per applicare le modifiche

Nota: Sostituisci <LOGS_SAS_URL> e <CUSTOMERS_SAS_URL> con gli URL forniti


================================================================================
                         USO OFFLINE
================================================================================

Se le variabili d'ambiente non sono configurate, o manca accesso ad internet, 
l'app funziona in modalità offline:

- L'indicatore di connessione sarà grigio ("Non connesso")
- Connettersi al portale: https://calm-plant-000dd4903.2.azurestaticapps.net/
- Loggarsi con le proprie credenziali
- Selezionare il periodo per il quale si vogliono i logs
- Scaricare il report dal portale
- Usare il bottone "📁 File" per caricare manualmente il report scaricato

Nota: Le colonne "Data installazione", "Utilizzatore" e "Città utilizzatore" mostrano "N/A" in modalità offline.


================================================================================
                              FUNZIONALITÀ
================================================================================

- Dashboard KPI con statistiche fault in tempo reale
- Filtro per periodo: settimana, mese, da Gennaio 2025, tutto
- Filtro multi-selezione per Numero Seriale
- Tre modalità di esportazione Excel:
  * Completa: tutti i dati + statistiche
  * Semplice: solo colonne essenziali
  * Riepilogo: statistiche aggregate per seriale <- QUESTA L'OPZIONE PER IL REPORT SETTIMANALE
- Evidenziazione automatica dei fault attivi


================================================================================
                               SUPPORTO
================================================================================

Per problemi o richieste: l.veronelli@stem.it


================================================================================
                         © 2026 STEM E.m.s.
                      Tutti i diritti riservati
================================================================================
