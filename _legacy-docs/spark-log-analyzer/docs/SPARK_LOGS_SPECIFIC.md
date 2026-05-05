# Specifiche logs SPARK - Documentazione Tecnica

Documentazione tecnica per l'interpretazione dei log della barella motorizzata SPARK.

## Descrizione Dispositivo

SPARK è una barella/lettino motorizzato per uso medico con:
- **4 ruote motorizzate** (Testa DX/SX, Piedi DX/SX)
- **Gambe retrattili** con sensori angolo/pressione
- **Attuatori verticali** (regolazione altezza)
- **Attuatori orizzontali** (slitta)
- **ECU multiple**: Motore Destro, Motore Sinistro, Rostro
- **IMU** per orientamento
- **Comunicazione CAN bus**

---

## Tipi di Equipaggiamento

| Codice | Tipo |
|--------|------|
| 0 | STRETCHER (Barella standard) |
| 1 | SALLY_CAB |
| 2 | BARIATRIC (Bariatrica) |
| 255 | UNKNOWN |

---

## Operazioni (WriteWorkInfo / COMMAND_ID)

| Codice | Operazione | Descrizione |
|--------|------------|-------------|
| 1 | LOAD | Caricamento paziente su ambulanza |
| 2 | UNLOAD | Scaricamento paziente |
| 3 | FREE_WORK_OCCUPIED | Movimento libero con paziente |
| 4 | FREE_WORK_NOT_OCCUPIED | Movimento libero senza paziente |

---

## Struttura Fault Code (16-bit)

I codici di fault sono valori a 16 bit composti da due parti:

```
Fault Code = [MSB: Fault Status] [LSB: Error Code (DTC)]

Esempio: 3956 = 0x0F74
├── MSB: 0x0F (15) = Fault Status
└── LSB: 0x74 (116) = DTC_WHEELS_FAULT_POS
```

### Fault Status (MSB) - Bit Flags

| Bit | Flag | Significato (se bit = 1) |
|-----|------|--------------------------|
| 0 | testFailed | Fault attivo ORA |
| 1 | testFailedThisMonitoringCycle | Fault occorso in questo ciclo |
| 2 | pendingDTC | Fault in ciclo corrente/precedente |
| 3 | confirmedDTC | Fault confermato |
| 4 | testNotCompletedSinceLastClear | Test non completato da ultimo clear |
| 5 | testFailedSinceLastClear | Fault occorso da ultimo clear |
| 6 | testNotCompletedThisMonitoringCycle | Test non completato in questo ciclo |
| 7 | reserved | Riservato |

### Valori Status Comuni

| Valore | Hex | Binario | Significato |
|--------|-----|---------|-------------|
| 8 | 0x08 | 0000 1000 | Confermato ma non attivo |
| 12 | 0x0C | 0000 1100 | Pending + Confermato |
| 14 | 0x0E | 0000 1110 | ThisCycle + Pending + Confermato |
| **15** | **0x0F** | **0000 1111** | **⚠️ FAULT ATTIVO** |

---

## Codici Errore (LSB - DTC)

### Errori Comunicazione (10-20)

| Codice | Nome | Descrizione |
|--------|------|-------------|
| 10 | DTC_COMM_LOST_ECU_MT_R | Comunicazione persa ECU Motore Destro |
| 11 | DTC_COMM_LOST_ECU_MT_L | Comunicazione persa ECU Motore Sinistro |
| 12 | DTC_COMM_LOST_ECU_RTR | Comunicazione persa ECU Rostro |
| 20 | IMU_INIT_FAILED | Inizializzazione IMU fallita |

### Errori Sovracorrente (100-107)

| Codice | Nome | Componente |
|--------|------|------------|
| 100 | OVERCURRENT_MT_HEAD_LEG_L | Gamba Testa Sinistra |
| 101 | OVERCURRENT_MT_WHEEL_HEAD_L | Ruota Testa Sinistra |
| 102 | OVERCURRENT_MT_WHEEL_FOOT_L | Ruota Piedi Sinistra |
| 103 | OVERCURRENT_MT_FEET_LEG_R | Gamba Piedi Destra |
| 104 | OVERCURRENT_MT_WHEEL_HEAD_R | Ruota Testa Destra |
| 105 | OVERCURRENT_MT_WHEEL_FOOT_R | Ruota Piedi Destra |
| 106 | OVERCURRENT_ACT_VERTICAL | Attuatori Verticali |
| 107 | OVERCURRENT_ACT_HORIZONTAL | Attuatori Orizzontali |

### Errori Sovratemperatura (108-115)

| Codice | Nome | Componente |
|--------|------|------------|
| 108 | OVERTEMP_MT_HEAD_LEG_L | Gamba Testa Sinistra |
| 109 | OVERTEMP_MT_WHEEL_HEAD_L | Ruota Testa Sinistra |
| 110 | OVERTEMP_MT_WHEEL_FOOT_L | Ruota Piedi Sinistra |
| 111 | OVERTEMP_MT_FEET_LEG_R | Gamba Piedi Destra |
| 112 | OVERTEMP_MT_WHEEL_HEAD_R | Ruota Testa Destra |
| 113 | OVERTEMP_MT_WHEEL_FOOT_R | Ruota Piedi Destra |
| 114 | OVERTEMP_ACT_VERTICAL | Attuatori Verticali |
| 115 | OVERTEMP_ACT_HORIZONTAL | Attuatori Orizzontali |

### Errori Posizione (116, 200, 400)

| Codice | Nome | Descrizione |
|--------|------|-------------|
| 116 | DTC_WHEELS_FAULT_POS | Incongruenza posizione ruote |
| 200 | HEAD_SIDE_WHEELS_TOO_FAR | Ruote lato testa troppo lontane |
| 400 | WRONG_WHEEL_POSITION | Posizione ruota errata |

### Errori Sensori (300-316)

| Codice | Nome | Descrizione |
|--------|------|-------------|
| 300 | PRESSURE_SENSOR_HEAD | Sensore pressione gambe testa non funzionante |
| 301 | PRESSURE_SENSOR_FEET | Sensore pressione gambe piedi non funzionante |
| 302-303 | ANGLE_SENSOR_HEAD | Sensore angolo gambe testa (< 0.5V o > 4.5V) |
| 304-305 | ANGLE_SENSOR_FEET | Sensore angolo gambe piedi (< 0.5V o > 4.5V) |
| 306-314 | POTENTIOMETER_* | Potenziometri ruote scollegati |
| 315 | BUTTON_DAMAGED | Pulsante IN/OUT danneggiato |
| 316 | THUMBWHEEL_DAMAGED | Rotella danneggiata |

---

## Ciclo Operativo

- **Inizio**: all'accensione (power-on)
- **Fine**: allo spegnimento OPPURE quando si verifica un fault
- **Riavvio**: quando l'utente conferma (acknowledge) il fault
- **Aging**: il fault si auto-cancella dopo **40 cicli** senza occorrenze

---

## Formato Protocollo Log (85 bytes)

Il protocollo usa formato **Little-endian** (Intel).

| Campo | Dimensione | Note |
|-------|------------|------|
| COMMAND ID | 16 bit | Tipo operazione (1-4) |
| TIMESTAMP | 72 bit | Anno, Mese, Giorno, Ora, Minuti, Secondi, UTC, Status |
| Dati sensori | variabile | Pressione, corrente, temperatura, accelerazione |
| FAULT_NR | 8 bit | Numero totale fault |
| FAULT_CODE_1-5 | 5 × 16 bit | 5 fault simultanei attivi/recenti |
| EQUIPMENT_TYPE | 8 bit | Tipo equipaggiamento (0-255) |
| WORK_TIME | 16 bit | Tempo lavoro in secondi |
| CRC | 16 bit | CRC-CCITT (poly 0x1021, init 0xFFFF) |

---

## Esempi Decodifica

### Esempio 1: Fault Attivo
```
Fault Code: 3956
Hex: 0x0F74
Status: 0x0F (15) = FAULT ATTIVO
Error: 0x74 (116) = DTC_WHEELS_FAULT_POS

→ Incongruenza posizione ruote - ATTIVO ORA
```

### Esempio 2: Fault Confermato (non attivo)
```
Fault Code: 2164
Hex: 0x0874
Status: 0x08 (8) = Confermato
Error: 0x74 (116) = DTC_WHEELS_FAULT_POS

→ Incongruenza posizione ruote - confermato ma non attivo
```

### Esempio 3: Fault Pending
```
Fault Code: 3178
Hex: 0x0C6A
Status: 0x0C (12) = Pending + Confermato
Error: 0x6A (106) = OVERCURRENT_ACT_VERTICAL

→ Sovracorrente attuatori verticali - in attesa di conferma
```
