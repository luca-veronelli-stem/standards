# Application Layer (Layer 7)

## Panoramica

L'**Application Layer** è il settimo e ultimo livello dello stack protocollare STEM, corrispondente al Layer 7 del modello OSI. Si occupa della gestione dei comandi applicativi, della serializzazione/deserializzazione dei messaggi, del routing verso gli handler specifici e della gestione delle variabili logiche del sistema.

> **Ultimo aggiornamento:** 2026-02-11

---

## Responsabilità

- **Gestione 43 tipi di comandi** applicativi predefiniti
- **Serializzazione/deserializzazione** messaggi con CommandId e payload
- **Routing comandi** a handler specifici tramite registry pattern
- **Gestione ACK automatici** per risposte a comandi
- **Gestione variabili logiche** (lettura/scrittura singola e area memoria)
- **Dispatch eventi** per monitoring e logging
- **Validazione payload** per ogni tipo di comando
- **Raccolta statistiche** su comandi, handler, errori e performance

---

## Architettura

```
ApplicationLayer/
├── ApplicationLayer.cs                     # Implementazione principale del layer
├── Helpers/
│   ├── CommandHandlers/                    # Handler per comandi specifici
│   │   ├── ReadLogicalVariableHandler.cs   # Lettura singola variabile
│   │   ├── WriteLogicalVariableHandler.cs  # Scrittura singola variabile
│   │   ├── ReadMemoryAreaHandler.cs        # Lettura area memoria
│   │   ├── WriteMemoryAreaHandler.cs       # Scrittura area memoria
│   │   └── ProtocolVersionHandler.cs       # Versione protocollo
│   ├── CommandHandlerRegistry.cs           # Registry per dispatch comandi/ACK
│   ├── ApplicationMessageSerializer.cs    # Serializzazione messaggi
│   └── VariableMap.cs                      # Mappa variabili logiche
├── Models/
│   ├── ApplicationLayerConfiguration.cs   # Configurazione runtime
│   ├── ApplicationLayerConstants.cs       # Costanti del layer
│   ├── ApplicationLayerStatistics.cs      # Statistiche aggregate
│   ├── ApplicationMessage.cs              # Struttura messaggio applicativo
│   ├── VariableDefinition.cs              # Definizione variabile logica
│   ├── VariableDataTypeExtensions.cs      # Estensioni per tipi di dato
│   └── EventArgs.cs                       # Event arguments personalizzati
├── Enums/
│   ├── CommandId.cs                       # 43 comandi del protocollo
│   └── VariableDataType.cs                # Tipi di dato variabili
└── Interfaces/
    ├── ICommandHandler.cs                 # Interfaccia handler comandi
    ├── IAckHandler.cs                     # Interfaccia handler ACK
    └── IVariableMap.cs                    # Interfaccia mappa variabili
```

---

## Formato Dati

### Struttura del Messaggio Applicativo

```
┌───────────────┬────────────────────────────┐
│   CommandId   │           Data             │
│    2 bytes    │         N bytes            │
└───────────────┴────────────────────────────┘
```

| Campo | Offset | Size | Endianness | Descrizione |
|-------|--------|------|------------|-------------|
| `CommandId` | 0 | 2 bytes | Big-Endian | ID comando (0-42) + flag ACK bit 15 |
| `Data` | 2 | N bytes | - | Payload specifico del comando |

### CommandId con Flag ACK

```
Bit:  15  14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
      │ACK│──────────── Command ID (0-42) ────────────│
```

| Bit | Valore | Significato |
|-----|--------|-------------|
| 15 = 0 | `0x0001` | Comando/Richiesta (es. `PROTOCOL_VERSION`) |
| 15 = 1 | `0x8001` | Risposta/ACK (es. `PROTOCOL_VERSION` ACK) |

La costante `COMMAND_ACK_FLAG = 0x8000` viene usata per impostare/verificare il bit 15.

---

## Componenti Principali

### ApplicationLayer

Classe principale che eredita da `ProtocolLayerBase`. Orchestra la deserializzazione messaggi e il dispatch agli handler.

```csharp
public class ApplicationLayer : ProtocolLayerBase
{
    public override string LayerName => "Application";
    public override int LayerLevel => 7;
    
    public event EventHandler<MessageReceivedEventArgs>? MessageReceived;
    public event EventHandler<AckReceivedEventArgs>? AckReceived;
}
```

#### Modalità di Funzionamento

| Costruttore | Modalità | Comportamento |
|-------------|----------|---------------|
| `ApplicationLayer()` | **Passiva** | Solo eventi, nessun dispatch automatico |
| `ApplicationLayer(CommandHandlerRegistry)` | **Attiva** | Dispatch automatico + invio ACK |

### Helper: CommandHandlerRegistry

Registry pattern per la gestione dei command handler. Permette di registrare handler per comandi specifici e dispatch automatico.

**Metodi principali:**
- `RegisterCommandHandler(CommandId, ICommandHandler)` - Registra handler per comando
- `RegisterAckHandler(CommandId, IAckHandler)` - Registra handler per ACK
- `TryGetCommandHandler(CommandId)` - Ottiene handler registrato
- `TryGetAckHandler(CommandId)` - Ottiene ACK handler registrato

### Helper: ApplicationMessageSerializer

Serializza e deserializza messaggi applicativi in formato binario.

**Metodi principali:**
- `Serialize(ApplicationMessage)` - Messaggio → byte[]
- `Deserialize(byte[])` - byte[] → ApplicationMessage

---

## Configurazione

Classe: `ApplicationLayerConfiguration`

| Proprietà | Tipo | Default | Min | Max | Descrizione |
|-----------|------|---------|-----|-----|-------------|
| `LocalDeviceId` | `uint` | - | 1 | - | SRID del dispositivo locale (obbligatorio) |
| `HandlerTimeout` | `TimeSpan` | `5s` | `1s` | `60s` | Timeout esecuzione handler |

### Validazione

Il metodo `Validate()` verifica:
- `LocalDeviceId` deve essere ≠ 0 (SRID valido)
- `HandlerTimeout` deve essere tra 1 e 60 secondi

### Esempio

```csharp
var config = new ApplicationLayerConfiguration
{
    LocalDeviceId = DeviceIdCalculator.CalculateId(network: 1, machine: 2, boardType: 100, boardNumber: 1),
    HandlerTimeout = TimeSpan.FromSeconds(10)
};
config.Validate(); // Lancia ArgumentException se LocalDeviceId = 0
```

---

## Costanti

Classe: `ApplicationLayerConstants`

### Costanti Protocollo

| Costante | Valore | Descrizione |
|----------|--------|-------------|
| `COMMAND_ACK_FLAG` | `0x8000` | Flag ACK nel bit 15 del CommandId |
| `USER_ADDRESS_OFFSET` | `0x8000` | Offset per indirizzi utente |
| `MAX_COMMAND_ID` | `43` | Numero massimo di comandi supportati |

### Valori Default

| Costante | Valore | Usato da |
|----------|--------|----------|
| `DEFAULT_HANDLER_TIMEOUT_SECONDS` | `5` | `Configuration.HandlerTimeout` |

### Limiti Validazione

| Costante | Valore | Descrizione |
|----------|--------|-------------|
| `MIN_HANDLER_TIMEOUT_SECONDS` | `1` | Timeout minimo handler |
| `MAX_HANDLER_TIMEOUT_SECONDS` | `60` | Timeout massimo handler |
| `MAX_APPLICATION_PAYLOAD_SIZE` | `1024` | Dimensione massima payload |

---

## Flusso Dati

### Downstream (Trasmissione)

```
Applicazione
      │
      ▼
┌─────────────────────────────┐
│   ProcessDownstreamAsync    │
│   ───────────────────────── │
│   1. Crea ApplicationMessage│
│   2. Serializza (CommandId) │
│   3. Aggiorna statistiche   │
└─────────────────────────────┘
      │
      ▼
PresentationLayer (Layer 6)
```

### Upstream (Ricezione)

```
PresentationLayer (Layer 6)
      │
      ▼
┌───────────────────────────────┐
│   ProcessUpstreamAsync        │
│   ─────────────────────────   │
│   1. Deserializza messaggio   │
│   2. Verifica flag ACK        │
│   3. [ACK] → AckReceived      │
│   3. [CMD] → MessageReceived  │
│   4. [Attiva] Dispatch handler│
└───────────────────────────────┘
      │
      ▼
Handler / Eventi
```

---

## Statistiche

Classe: `ApplicationLayerStatistics`

| Metrica | Tipo | Descrizione |
|---------|------|-------------|
| `MessagesReceived` | `long` | Totale messaggi ricevuti (upstream) |
| `MessagesSent` | `long` | Totale messaggi inviati (downstream) |
| `CommandsProcessed` | `long` | Comandi processati da handler |
| `AcksReceived` | `long` | ACK ricevuti da altri dispositivi |
| `NacksSent` | `long` | NACK inviati a causa di errori |
| `HandlerErrors` | `long` | Errori durante esecuzione handler |
| `DeserializationErrors` | `long` | Errori di deserializzazione |
| `SerializationErrors` | `long` | Errori di serializzazione |
| `TotalHandlerExecutionMs` | `long` | Tempo totale esecuzione handler (ms) |
| `AverageHandlerExecutionMs` | `double` | Tempo medio esecuzione handler (ms) |
| `LastMessageReceivedAt` | `DateTime?` | Timestamp ultimo messaggio ricevuto |
| `LastMessageSentAt` | `DateTime?` | Timestamp ultimo messaggio inviato |

### Accesso

```csharp
var stats = (ApplicationLayerStatistics)layer.Statistics;
Console.WriteLine($"Comandi processati: {stats.CommandsProcessed}");
Console.WriteLine($"Tempo medio handler: {stats.AverageHandlerExecutionMs:F2} ms");
```

---

## Eventi

L'ApplicationLayer espone i seguenti eventi (conformi a [EVENTARGS_STANDARD.md](../../../Docs/Standards/EVENTARGS_STANDARD.md)):

| Evento | EventArgs | Descrizione |
|--------|-----------|-------------|
| `MessageReceived` | `MessageReceivedEventArgs` | Messaggio applicativo ricevuto |
| `AckReceived` | `AckReceivedEventArgs` | Acknowledgment ricevuto |

### EventArgs

Tutti gli EventArgs includono `Timestamp` (UTC) per tracciamento temporale.

| EventArgs | Proprietà |
|-----------|-----------|
| `MessageReceivedEventArgs` | `Message` (ApplicationMessage), `Context` (LayerContext), `Timestamp` |
| `AckReceivedEventArgs` | `Message` (ApplicationMessage), `Context` (LayerContext), `Timestamp` |

---

## Esempi di Utilizzo

### Inizializzazione Base (Modalità Passiva)

```csharp
var layer = new ApplicationLayer();
await layer.InitializeAsync(new ApplicationLayerConfiguration
{
    LocalDeviceId = 0x12345678
});

// Sottoscrivi eventi
layer.MessageReceived += (s, e) => 
    Console.WriteLine($"Comando: {e.Message.Command} at {e.Timestamp}");
layer.AckReceived += (s, e) => 
    Console.WriteLine($"ACK ricevuto at {e.Timestamp}");
```

### Con Handler Registry (Modalità Attiva)

```csharp
// Configura registry con handler
var registry = new CommandHandlerRegistry();
registry.RegisterCommandHandler(CommandId.PROTOCOL_VERSION, new ProtocolVersionHandler());
registry.RegisterCommandHandler(CommandId.READ_LOGICAL_VARIABLE, new ReadLogicalVariableHandler(variableMap));

// Crea layer con registry
var layer = new ApplicationLayer(registry);
await layer.InitializeAsync(new ApplicationLayerConfiguration
{
    LocalDeviceId = 0x12345678,
    HandlerTimeout = TimeSpan.FromSeconds(10)
});

// I comandi ricevuti vengono automaticamente dispatchati agli handler
```

### Invio Comando

```csharp
var message = new ApplicationMessage
{
    CommandId = CommandId.READ_LOGICAL_VARIABLE,
    Data = BitConverter.GetBytes(variableAddress)
};

var context = new LayerContext { Direction = FlowDirection.Downstream };
var result = await layer.ProcessDownstreamAsync(
    ApplicationMessageSerializer.Serialize(message),
    context
);
```

---

## Tabella Comandi

L'enum `CommandId` definisce 43 comandi:

| ID | Nome | Descrizione |
|----|------|-------------|
| 0 | `PROTOCOL_VERSION` | Richiesta versione firmware |
| 1 | `READ_LOGICAL_VARIABLE` | Lettura singola variabile |
| 2 | `WRITE_LOGICAL_VARIABLE` | Scrittura singola variabile |
| 3 | `READ_MEMORY_AREA` | Lettura blocco di memoria |
| 4 | `WRITE_MEMORY_AREA` | Scrittura blocco di memoria |
| 5 | `START_BOOTLOADER` | Inizializza bootloader |
| 6 | `STOP_BOOTLOADER` | Termina bootloader |
| 7 | `UPDATE_BOOTLOADER_PAGE` | Invia pagina bootloader |
| 8-10 | `START/STOP/RESTART_DEVICE` | Controllo dispositivo |
| 11-12 | `UNLOCK/LOCK_BLE` | Gestione BLE |
| 13-14 | `BUTTON_PANEL_UP/DOWN` | Movimento pulsantiera |
| 15-17 | `*_AUTO_LEARNING` | Auto-apprendimento |
| 18 | `MOVE_DECK` | Movimento piano |
| 19-20 | `*_BLE_PAIRING` | Pairing BLE |
| 21-24 | `*_TELEMETRY` | Gestione telemetria |
| 25-28 | `*_LOGGING` | Gestione logging |
| 29-34 | `*_BLE/GATEWAY` | Sessioni BLE/Gateway |
| 35-42 | `AUTO_ADDRESSING_*` | Auto-addressing rete |

---

## Issue Correlate

→ [ApplicationLayer/ISSUES.md](./ISSUES.md)

| Priorità | Aperte | Risolte |
|----------|--------|---------|
| Alta | 1 | 2 |
| Media | 4 | 4 |
| Bassa | 5 | 2 |
| **Totale** | **10** | **8** |

### Issue Aperte Principali

| ID | Titolo | Priorità |
|----|--------|----------|
| AL-003 | Multi-Device Support Limitato | Alta |
| AL-005 | WriteMemoryArea Non Traccia Successi/Fallimenti Parziali | Media |
| AL-006 | Callback Post-Scrittura Invocato Prima Risposta | Media |
| AL-007 | ReadMemoryArea Ignora Errori Silenziosamente | Media |

### Issue Risolte Recenti

| ID | Titolo | Data |
|----|--------|------|
| AL-017 | ProcessDownstreamAsync Non Valida Data/Context | 2026-02-08 |
| AL-016 | ApplicationLayerStatistics Timestamp Non Thread-Safe | 2026-02-07 |

---

## Riferimenti Firmware C

| Componente C# | File C | Struttura/Funzione |
|---------------|--------|-------------------|
| `ApplicationLayer` | `SP_Application.c` | `SP_APP_ProcessMessage()` |
| `CommandId` | `SP_Application.h` | `sp_app_cmd_id_e` |
| `ApplicationMessage` | `SP_Application.h` | `SP_APP_MSG_t` |
| `COMMAND_ACK_FLAG` | `SP_Application.h` | `CMD_ACK_FLAG` |
| `USER_ADDRESS_OFFSET` | `SP_Application.h` | `SP_APP_USER_ADDR_OFFS` |

**Repository:** `stem-fw-protocollo-seriale-stem/`

---

## Links

- [Stack README](../Stack/README.md) - Orchestrazione layer
- [Base README](../Base/README.md) - Interfacce e classi base
