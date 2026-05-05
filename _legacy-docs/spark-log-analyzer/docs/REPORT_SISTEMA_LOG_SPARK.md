# Sistema di Logging SPARK

## Documentazione Tecnica

**Versione:** 1.1  
**Ultimo aggiornamento:** 2026-02-20
**Autore:** Luca Veronelli (l.veronelli@stem.it)  
**Riferimento:** DisplayMessageCodes_R04, PropostaProtocollo_Spark_R9

---

## 1. Introduzione

Il sistema SPARK e' dotato di un sistema di logging automatico che registra i dati operativi e diagnostici durante ogni ciclo di lavoro. I log vengono trasmessi al cloud Azure per l'analisi remota e la manutenzione predittiva.

Questo documento descrive:
- La struttura dei log e il protocollo di trasmissione
- Il sistema di codifica dei fault
- Il catalogo completo dei codici errore
- Come interpretare i dati registrati

---

## 2. Protocollo Log

### 2.1 Trigger di Invio

Il sistema genera e invia un log al cloud **al termine di ogni operazione**:
- Fine operazione LOAD (carico completato)
- Fine operazione UNLOAD (scarico completato)
- Fine operazione FREE_WORK (movimento libero terminato)

### 2.2 Buffer e Limitazioni

Quando la connettivita' non e' disponibile (es. assenza copertura di rete), il sistema memorizza i log in un **buffer interno con capacita' massima di 5 log**.

| Situazione | Comportamento |
|------------|---------------|
| Connettivita' presente | Log inviato immediatamente |
| Connettivita' assente, buffer < 5 | Log memorizzato nel buffer |
| Connettivita' assente, buffer = 5 | **Log perso** (buffer pieno) |
| Connettivita' ripristinata | Buffer svuotato verso il cloud |

> **IMPORTANTE:** A causa di questa limitazione, le statistiche calcolate sui dati nel cloud potrebbero non essere complete. In caso di prolungata assenza di copertura con piu' di 5 operazioni, alcuni log vengono persi irreversibilmente.

### 2.3 Tipi di Operazione

| Codice | Operazione | Descrizione | Dimensione Log |
|--------|------------|-------------|----------------|
| 1 | LOAD | Carico spark su ambulanza | 77 bytes |
| 2 | UNLOAD | Scarico spark da ambulanza | 77 bytes |
| 3 | FREE_WORK_OCCUPIED | Movimento libero con paziente | 85 bytes |
| 4 | FREE_WORK_NOT_OCCUPIED | Movimento libero senza paziente | 85 bytes |

> **Nota:** Ai bytes indicati va aggiunto il CRC-16 (2 bytes) per la verifica integrita'.

### 2.4 Tipi di Equipaggiamento

| Codice | Tipo | Descrizione |
|--------|------|-------------|
| 0 | STRETCHER | Barella standard |
| 1 | SALLY_CAB | Sally-CAB |
| 2 | BARIATRIC | Barella bariatrica |
| 255 | UNKNOWN | Tipo non definito |

### 2.5 Struttura del Log

Ogni log contiene le seguenti informazioni:

| Campo | Unita | Note |
|-------|-------|------|
| Timestamp | - | Data/ora operazione |
| Pressione gambe (max/media) | Bar | Lato testa e piedi |
| Corrente motori gambe (max/media) | A | Lato testa e piedi |
| Corrente ruote (max/media) | A | 4 ruote singolarmente |
| Temperatura ECU | C | M1 (testa) e M2 (piedi) |
| Cicli completati | - | Carico e scarico separati |
| Fault attivi | - | Fino a 5 simultanei |
| Tipo equipaggiamento | - | Vedi tabella 2.4 |
| Tempo operazione | s | Solo per Free Work |

---

## 3. Sistema di Gestione Fault

### 3.1 Struttura del Codice Fault

Ogni fault e' codificato in un valore a **16 bit** composto da:

```
Fault Code (16 bit) = [MSB: Fault Status] [LSB: Error Code]

Esempio: 3956 (decimale) = 0x0F74 (esadecimale)
         MSB = 0x0F (15) = Status
         LSB = 0x74 (116) = Error Code
```

### 3.2 Fault Status (MSB)

Il byte di stato indica la condizione del fault. Ogni bit a **1** indica che la condizione e' presente:

| Bit | Nome | Significato (quando bit = 1) |
|-----|------|------------------------------|
| 0 | testFailed | DTC attivo al momento della richiesta |
| 1 | testFailedThisMonitoringCycle | DTC occorso nel ciclo operativo corrente |
| 2 | pendingDTC | DTC in attesa (ciclo corrente o precedente) |
| 3 | confirmedDTC | DTC confermato |
| 4 | testNotCompletedSinceLastClear | Test non completato dall'ultimo clear |
| 5 | testFailedSinceLastClear | DTC occorso dall'ultimo clear |
| 6 | testNotCompletedThisMonitoringCycle | Test non completato nel ciclo corrente |
| 7 | (riservato) | - |

### 3.3 Valori Status Comuni

| Valore | Hex | Binario | Significato | Attivo? |
|--------|-----|---------|-------------|---------|
| **15** | **0x0F** | 00001111 | Fault nel MC corrente, test completato, fault presente | **SI** |
| **77** | **0x4D** | 01001101 | Fault nel MC precedente, test non completato | **SI** |
| 76 | 0x4C | 01001100 | Fault non presente nel MC precedente, test non completato | NO |
| 12 | 0x0C | 00001100 | Fault nel MC precedente, test completato, fault non presente | NO |
| 72 | 0x48 | 01001000 | Fault non presente nel MC precedente, test non completato | NO |
| 8 | 0x08 | 00001000 | Fault non presente nel MC precedente, test completato | NO |
| 0 | 0x00 | 00000000 | Nessun fault | NO |

> **Nota:** Un fault e' considerato **ATTIVO** se il bit 0 (testFailed) = 1.

### 3.4 Diagramma Stati del Fault

```
                                Clear DTC
                    ┌────────────────────────────────────────────────────────┐
                    │                                                        │
                    ▼                                                        │
 ┌────────────────────────────────────────────────────────────────────────┐  │
 │                            0x00 (Nessun fault)                         │  │
 └────────────────────────────────────────────────────────────────────────┘  │
       │                              ▲                                      │
       │ Fault Occurred               │ aging == 0                           │
       │ (aging = 40)                 │                                      │
       ▼                              │                                      │
 ┌────────────────────────────────────────────────────────────────────────┐  │
 │  0x0F - FAULT ATTIVO (test completato, fault presente, validato)       │◄─┼──┐
 └────────────────────────────────────────────────────────────────────────┘  │  │
       │                              ▲                                      │  │
       │ User ACK / Power On          │ Fault Occurred                       │  │
       │ → Nuovo MC                   │ (aging = 40)                         │  │
       ▼                              │                                      │  │
 ┌────────────────────────────────────────────────────────────────────────┐  │  │
 │  0x4D - FAULT ATTIVO (test non completato nel nuovo MC)                │──┘  │
 └────────────────────────────────────────────────────────────────────────┘     │
       │                              ▲                                         │
       │ Test OK                      │ Fault Occurred                          │
       │ (aging--)                    │ (aging = 40)                            │
       ▼                              │                                         │
 ┌────────────────────────────────────────────────────────────────────────┐     │
 │  0x0C - Pending + Confermato (test completato, fault non presente)     │─────┤
 └────────────────────────────────────────────────────────────────────────┘     │
       │                              ▲                                         │
       │ User ACK / Power On          │ Fault Occurred                          │
       │ → Nuovo MC                   │ (aging = 40)                            │
       ▼                              │                                         │
 ┌────────────────────────────────────────────────────────────────────────┐     │
 │  0x48 - Confermato (test non completato, in aging)                     │─────┤
 └────────────────────────────────────────────────────────────────────────┘     │
       │                              ▲                                         │
       │ Test OK                      │ Fault Occurred                          │
       │ (aging--)                    │ (aging = 40)                            │
       ▼                              │                                         │
 ┌────────────────────────────────────────────────────────────────────────┐     │
 │  0x08 - Solo Confermato (in aging, aging counter decrementa)           │─────┘
 └────────────────────────────────────────────────────────────────────────┘
       │
       │ User ACK / Power On → 0x48 (torna su per nuovo test)
       │
       └──► aging == 0 → 0x00 (fault cancellato)
```

### 3.5 Ciclo di Monitoring (MC) e Aging

**Inizio Monitoring Cycle (MC):**
- Accensione macchina (Power On)
- Acknowledge fault da parte dell'operatore

**Fine Monitoring Cycle:**
- Spegnimento macchina (non rimozione batteria)
- Occorrenza di un fault (system fault stop)

**Comportamento dei bit all'inizio di un nuovo MC:**
- bit 0 (testFailed): mantiene il valore dell'ultimo test del MC precedente
- bit 1 (testFailedThisMonitoringCycle): resettato a 0
- bit 2 (pendingDTC): se bit 0 e 1 erano 0, viene resettato a 0
- bit 6 (testNotCompletedThisMonitoringCycle): settato a 1

**Aging automatico:**
- Ogni test completato senza fault decrementa il contatore di aging
- Contatore iniziale: 40 cicli
- Quando aging = 0 → fault cancellato (0x08 → 0x00)

---

## 4. Catalogo Codici Errore

### 4.1 Errori di Comunicazione (10-20)

| Codice | Nome | Descrizione | Azione |
|--------|------|-------------|--------|
| E010 | DTC_COMM_LOST_ECU_MT_R | ECU Motore Destro assente | Blocco movimenti |
| E011 | DTC_COMM_LOST_ECU_MT_L | ECU Motore Sinistro assente | Blocco movimenti |
| E012 | DTC_COMM_LOST_ECU_RTR | ECU Rostro assente | Solo segnalazione |
| E020 | DTC_IMU_INIT_FAULT | Inizializzazione IMU fallita | Blocco movimenti |

### 4.2 Errori di Sovracorrente (100-107)

| Codice | Nome | Descrizione | Azione |
|--------|------|-------------|--------|
| E100 | DTC_OVER_CURR_MT_LEGS_HEAD | Sovracorrente motore gambe testa | Blocco movimenti |
| E101 | DTC_OVER_CURR_MT_WHEEL_HEAD_L | Sovracorrente ruota testa SX | Blocco movimenti |
| E102 | DTC_OVER_CURR_MT_WHEEL_FOOT_L | Sovracorrente ruota piedi SX | Blocco movimenti |
| E103 | DTC_OVER_CURR_MT_LEGS_FEET | Sovracorrente motore gambe piedi | Blocco movimenti |
| E104 | DTC_OVER_CURR_MT_WHEEL_HEAD_R | Sovracorrente ruota testa DX | Blocco movimenti |
| E105 | DTC_OVER_CURR_MT_WHEEL_FOOT_R | Sovracorrente ruota piedi DX | Blocco movimenti |
| E106 | DTC_OVER_CURR_ACT_VERTICAL | Sovracorrente attuatore verticale | 3 tentativi auto-ripristino |
| E107 | DTC_OVER_CURR_ACT_HORIZONTAL | Sovracorrente attuatore orizzontale | Segnalazione |

### 4.3 Errori di Sovratemperatura (108-115)

| Codice | Nome | Descrizione | Azione |
|--------|------|-------------|--------|
| E108 | DTC_OVER_TEMP_MT_LEGS_HEAD | Sovratemperatura motore gambe testa | Blocco + attesa |
| E109 | DTC_OVER_TEMP_MT_WHEEL_HEAD_L | Sovratemperatura ruota testa SX | Blocco + attesa |
| E110 | DTC_OVER_TEMP_MT_WHEEL_FOOT_L | Sovratemperatura ruota piedi SX | Blocco + attesa |
| E111 | DTC_OVER_TEMP_MT_LEGS_FEET | Sovratemperatura motore gambe piedi | Blocco + attesa |
| E112 | DTC_OVER_TEMP_MT_WHEEL_HEAD_R | Sovratemperatura ruota testa DX | Blocco + attesa |
| E113 | DTC_OVER_TEMP_MT_WHEEL_FOOT_R | Sovratemperatura ruota piedi DX | Blocco + attesa |
| E114 | DTC_OVER_TEMP_ACT_VERTICAL | Sovratemperatura attuatore verticale | Blocco + attesa |
| E115 | DTC_OVER_TEMP_ACT_HORIZONTAL | Sovratemperatura attuatore orizzontale | Blocco + attesa |

### 4.4 Errori di Posizione (116, 200, 400)

| Codice | Nome | Descrizione | Azione |
|--------|------|-------------|--------|
| E116 | DTC_WHEELS_FAULT_POS | Incongruenza posizione ruote | Blocco movimenti |
| E200 | HEAD_SIDE_WHEELS_TOO_FAR | Ruote testa troppo lontane dal pavimento | Blocco scarico |
| E400 | WRONG_WHEEL_POSITION | Scostamento potenziometri DX/SX | Blocco + richiesta mov. automatico |

### 4.5 Errori Fase Scarico (1-2)

| Codice | Nome | Descrizione | Azione |
|--------|------|-------------|--------|
| E001 | UNLOAD_REED1_CHECK_FAIL | Sensore Reed invalido durante avvio scarico | Verifica sensore |
| E002 | UNLOAD_SLED_REED1_FAIL | Reed slitta disattivato durante scarico | Verifica slitta |

### 4.6 Errori Sensori (300-316)

| Codice | Nome | Descrizione | Azione |
|--------|------|-------------|--------|
| E300 | PRESSURE_SENSOR_HEAD | Sensore pressione gambe testa guasto | Solo segnalazione |
| E301 | PRESSURE_SENSOR_FEET | Sensore pressione gambe piedi guasto | Solo segnalazione |
| E302 | ANGLE_SENSOR_HEAD_LOW | Angolo gambe testa: tensione < 0.5V | Blocco movimenti |
| E303 | ANGLE_SENSOR_HEAD_HIGH | Angolo gambe testa: tensione > 4.5V | Blocco movimenti |
| E304 | ANGLE_SENSOR_FEET_LOW | Angolo gambe piedi: tensione < 0.5V | Blocco movimenti |
| E305 | ANGLE_SENSOR_FEET_HIGH | Angolo gambe piedi: tensione > 4.5V | Blocco movimenti |
| E306 | POTENTIOMETER_HEAD_R | Potenziometro DX testa scollegato | Copia da SX |
| E307 | POTENTIOMETER_HEAD_L | Potenziometro SX testa scollegato | Copia da DX |
| E308 | POTENTIOMETER_FEET_R | Potenziometro DX piedi scollegato | Copia da SX |
| E309 | POTENTIOMETER_FEET_L | Potenziometro SX piedi scollegato | Copia da DX |
| E310 | POTENTIOMETER_SAME_SIDE | Due potenziometri stesso lato guasti | Blocco movimenti |
| E311 | POTENTIOMETER_HEAD_R_ENDSTOP | Finecorsa pot. DX testa non corretto | Blocco + segnalazione |
| E312 | POTENTIOMETER_HEAD_L_ENDSTOP | Finecorsa pot. SX testa non corretto | Blocco + segnalazione |
| E313 | POTENTIOMETER_FEET_R_ENDSTOP | Finecorsa pot. DX piedi non corretto | Blocco + segnalazione |
| E314 | POTENTIOMETER_FEET_L_ENDSTOP | Finecorsa pot. SX piedi non corretto | Blocco + segnalazione |
| E315 | BUTTON_DAMAGED | Pulsante IN/OUT danneggiato | Carico disabilitato |
| E316 | THUMBWHEEL_DAMAGED | Rotella danneggiata | Altezza carico fissa |

---

## 5. Come Leggere un Log

### 5.1 Esempio Pratico di Decodifica Fault

```
Fault Code registrato: 3956

1. Convertire in esadecimale: 3956 = 0x0F74
2. Separare MSB e LSB:
   - MSB (Status) = 0x0F = 15 (decimale)
   - LSB (Error)  = 0x74 = 116 (decimale)
3. Interpretare:
   - Status 15 = FAULT ATTIVO (tutti i bit 0-3 attivi)
   - Error 116 = DTC_WHEELS_FAULT_POS (Incongruenza posizione ruote)
4. Conclusione: Fault attivo per incongruenza posizione ruote
```

### 5.2 Guida Rapida Interpretazione Status

| Condizione | Significato | Priorita |
|------------|-------------|----------|
| Status = 15 (0x0F) | Fault ATTIVO ora | **ALTA** - Intervento richiesto |
| Status = 8-14 | Fault storico o pending | MEDIA - Monitorare |
| Status = 0 | Nessun fault | - |

### 5.3 Numero Fault nel Log

Il campo **FAULT_NR** indica quanti fault sono presenti nel log (0-5).
I campi **FAULT_CODE_1** fino a **FAULT_CODE_5** contengono i codici dei singoli fault.

---

## 6. Statistiche e Limitazioni

### 6.1 Disclaimer sulle Statistiche

> **IMPORTANTE:** Tutte le statistiche calcolate sui log sono **INDICATIVE** e rappresentano una stima al ribasso. Il numero reale di fault potrebbe essere superiore a causa di:
> - Buffer limitato a 5 log (overflow in assenza di copertura)
> - Aging automatico dei fault dopo 40 cicli
> - Possibile perdita del log con fault attivo

### 6.2 Definizione di Operazione Riuscita/Fallita

| Stato | Definizione | Esempio |
|-------|-------------|---------|
| **Riuscita** | Log senza fault ATTIVO (status 15) | Anche se ha fault storici (status 8, 12, 14) |
| **Fallita** | Log con almeno un fault ATTIVO | Status con bit 0 = 1 |

> **Nota:** I fault storici/confermati (status 8, 12, 14) indicano problemi passati gia' risolti o in aging, NON sono considerati fallimenti dell'operazione corrente.

### 6.3 Metriche Calcolate per Serial Number

| Metrica | Descrizione | Calcolo | Affidabilita |
|---------|-------------|---------|--------------|
| Log ricevuti | Numero totale di log nel cloud | Conteggio log per S/N | Certa (ma incompleta) |
| Op. Riuscite | Log senza fault ATTIVO | Log dove nessun fault ha bit 0 = 1 | Certa |
| Op. Fallite | Log con almeno un fault ATTIVO | Log dove almeno un fault ha bit 0 = 1 | Certa |
| Fault Storici | Log con fault non attivi | LogsWithAnyFault - LogsWithActiveFault | Certa |
| Fault CERTI | Fault con status ATTIVO | Somma fault con bit 0 = 1 nei log ricevuti | Alta |
| Fault STIMATI | Incremento FaultNumber | Somma delta FaultNumber tra log consecutivi | Media |
| Fault PERSI | FaultNumber aumentato senza fault attivo | Delta > 0 ma nessun fault attivo visibile | Indicativa |

### 6.4 Calcolo del Range Fault

Il campo **Range** stima il numero di fault reali che si sono verificati, tenendo conto che alcuni potrebbero essere stati persi per overflow del buffer.

#### Formula

```
Range = "CERTI - MASSIMO"

Dove:
  CERTI   = Fault con status ATTIVO (bit 0 = 1) nei log ricevuti
  MASSIMO = CERTI + STIMATI_DA_DELTA + POSSIBILI_PERSI
```

#### Algoritmo di Calcolo

Per ogni Serial Number, i log vengono ordinati per timestamp e analizzati sequenzialmente:

1. **CertainFaults (Certi)**
   - Incrementato per ogni fault con `status bit 0 = 1` (IsActive = true)
   - Rappresenta i fault che abbiamo VISTO attivi

2. **EstimatedFaultsFromDelta (Stimati)**
   - Se `FaultNumber[log N] > FaultNumber[log N-1]`
   - Il delta viene sommato ai fault stimati
   - Indica che sono avvenuti nuovi fault tra i due log

3. **PossibleLostFaults (Possibili Persi)**
   - Se il delta FaultNumber > 0 MA non vediamo fault attivi nel log
   - Probabilmente il log con il fault attivo e' stato perso per overflow buffer
   - Oppure: se FaultNumber e' uguale ma i fault sono diversi (aging + nuovo fault)

#### Esempio Pratico

```
Log 1: FaultNumber=5, FaultCode1=0x0F74 (attivo)     -> +1 certo
Log 2: FaultNumber=5, nessun fault                   -> niente
Log 3: FaultNumber=8, FaultCode1=0x0874 (confermato) -> +3 stimati, +3 possibili persi
Log 4: FaultNumber=9, FaultCode1=0x4D6A (attivo)     -> +1 certo, +1 stimato

Risultato:
- CertainFaults = 2
- EstimatedFaultsFromDelta = 4 (0 + 3 + 1)
- PossibleLostFaults = 3

Range = "2 - 9" (2 certi, fino a 2+4+3=9 massimo)
```

#### Interpretazione del Range

| Range | Significato | Affidabilita |
|-------|-------------|--------------|
| **3 - 4** | Quasi tutti i fault sono stati visti attivi | Alta |
| **3 - 10** | Alcuni log probabilmente persi | Media |
| **3 - 20** | Molti log persi per assenza copertura prolungata | Bassa |

### 6.5 Percentuale di Successo

```
% Successo = (Op. Riuscite / Log Totali) * 100
```

Dove:
- **Op. Riuscite** = Log SENZA fault con status ATTIVO (bit 0 = 1)
- I fault storici/confermati (status 0x08, 0x0C, 0x48, etc.) NON sono considerati fallimenti

> **Nota:** Un'operazione e' considerata FALLITA solo se il log contiene almeno un fault con il bit 0 settato (testFailed = true).

**Esempio:**
| S/N | Log | Op. Riuscite | Op. Fallite | Fault Storici | Certi | Range | % Successo* |
|-----|-----|--------------|-------------|---------------|-------|-------|-------------|
| 34469 | 150 | 142 | 8 | 4 | 8 | 8 - 15 | ~94.7% |
| 34470 | 200 | 197 | 3 | 2 | 3 | 3 - 7 | ~98.5% |

*Percentuale calcolata come: Op. Riuscite / Log totali

### 6.6 Interpretazione dei Dati

1. **Se Range e' stretto (es. 3-4):** Alta affidabilita', pochi fault persi
2. **Se Range e' ampio (es. 5-15):** Possibile perdita log per assenza copertura
3. **Se Certi << Stimati:** Molti log con fault attivo probabilmente persi

---

## 7. Codici e Status Non Mappati

### 7.1 Disclaimer

Alcuni codici errore e valori di status potrebbero non essere documentati in questo catalogo. Questi fanno parte di specifiche protocollo precedenti o versioni firmware a cui non ho attualmente accesso.

### 7.2 Status Documentati (DisplayMessageCodes R04)

Tutti i valori di status sono ora documentati nella specifica R04:

| Status | Hex | Binario | Descrizione | Attivo? |
|--------|-----|---------|-------------|---------|
| **15** | **0x0F** | 00001111 | Fault nel MC corrente, test completato e fault presente (validato) | **SI** |
| **77** | **0x4D** | 01001101 | Fault nel MC precedente, test non completato | **SI** |
| 76 | 0x4C | 01001100 | Fault non presente nel MC precedente, test non completato | NO |
| 12 | 0x0C | 00001100 | Fault nel MC precedente, test completato e fault non presente (devalidato) | NO |
| 72 | 0x48 | 01001000 | Fault non presente nel MC precedente, test non completato | NO |
| 8 | 0x08 | 00001000 | Fault non presente nel MC precedente, test completato e fault non presente | NO |
| 0 | 0x00 | 00000000 | Nessun fault | NO |

> **Nota:** Il sistema interpreta correttamente tutti questi status usando il bit 0 per determinare se il fault e' attivo.

### 7.3 Codici Errore Non Mappati

I seguenti codici errore sono stati osservati ma non sono presenti nella documentazione:

| Codice | Descrizione | Note |
|--------|-------------|------|
| E006 | Sconosciuto | Possibile errore legacy o di versione firmware diversa |

Quando un codice errore non e' mappato, il sistema mostra:
- Nome: `Errore {codice}`
- Descrizione: `Codice errore sconosciuto ({codice})`
- Categoria: `Altro`

### 7.4 Segnalazione Nuovi Codici

Se vengono identificati nuovi codici errore o status, e' necessario:
1. Verificare la versione firmware della macchina
2. Consultare la documentazione della versione specifica
3. Aggiornare il catalogo `ErrorCodeDefinitions.cs` nel software

---

## 8. Riferimenti

| Documento | Revisione | Contenuto |
|-----------|-----------|-----------|
| DisplayMessageCodes | **R04** | Codifica errori, messaggi display, diagramma stati fault |
| PropostaProtocollo_Spark | R9 | Struttura protocollo log |
| Codifica_Errori | - | Mappatura codici fault |
| Condizioni_Allarmi | - | Condizioni di attivazione e azioni |

---

## Storico Revisioni

| Versione | Data | Autore | Modifiche |
|----------|------|--------|-----------|
| 1.0 | Feb 2026 | L. Veronelli | Prima versione |
| 1.1 | Feb 2026 | L. Veronelli | Aggiornato a DisplayMessageCodes R04, aggiunto diagramma stati, documentati tutti gli status (0x0F, 0x4D, 0x4C, 0x0C, 0x48, 0x08) |

