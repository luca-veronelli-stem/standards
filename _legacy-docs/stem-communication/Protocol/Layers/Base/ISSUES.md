# Base Layer - ISSUES

> **Scopo:** Questo documento traccia bug, code smells, performance issues, opportunità di refactoring e violazioni di best practice per il componente **Base** (Interfacce, Enumerazioni, Modelli e Classe Base fondamentali dello stack protocollare).

> **Ultimo aggiornamento:** 2026-02-18

---

## Riepilogo

| Priorità | Aperte | Risolte |
|----------|--------|---------|
| **Critica** | 0 | 0 |
| **Alta** | 0 | 0 |
| **Media** | 0 | 1 |
| **Bassa** | 0 | 1 |

**Totale aperte:** 0  
**Totale risolte:** 2

---

## Issue Risolte

### BASE-001 - IProtocolLayer Non Eredita da IDisposable ✅

**Categoria:** Design  
**Priorità:** Bassa → ✅ Risolto  
**Data Apertura:** 2026-01-15  
**Data Risoluzione:** 2026-02-18  
**Issue Correlata:** T-006

#### Descrizione Originale

L'interfaccia `IProtocolLayer` non ereditava da `IDisposable`, anche se tutti i layer implementavano dispose.

#### Soluzione Implementata

- `IProtocolLayer` ora eredita da `IDisposable, IAsyncDisposable`
- Rimosso metodo `Shutdown()` ridondante
- Aggiunto `UninitializeAsync()` per de-inizializzazione senza dispose
- Aggiunto `ResetStateAsync()` in `ProtocolLayerBase` per reset stato helper
- Pattern Dispose semplificato: `DisposeCore()` privato, `DisposeResources()` per subclass

---

### BASE-002 - LayerContext.Metadata Non Thread-Safe

**Categoria:** Thread Safety  
**Priorità:** Bassa  
**Status:** Aperto  
**Data Apertura:** 2026-01-20

#### Descrizione

`LayerContext.Metadata` usa `Dictionary<string, object>` standard non thread-safe.
Potenziale race condition se multipli layer accedono contemporaneamente al metadata.

#### Soluzione Proposta

Usare `ConcurrentDictionary` o rendere il contesto immutabile dopo la creazione.
