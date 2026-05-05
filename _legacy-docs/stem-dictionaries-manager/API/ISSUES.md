# API - ISSUES

> **Scopo:** Questo documento traccia problemi, miglioramenti e code smells per il progetto **API** di Stem.Dictionaries.Manager.

> **Ultimo aggiornamento:** 2026-04-13

---

## Riepilogo

| Priorità | Aperte | Risolte |
|----------|--------|---------|
| **Critica** | 0 | 0 |
| **Alta** | 0 | 0 |
| **Media** | 0 | 0 |
| **Bassa** | 3 | 1 |

**Totale aperte:** 3  
**Totale risolte:** 1

---

## Indice Issue Aperte

- [API-001 - Swagger UI non supporta API Key authentication](#api-001--swagger-ui-non-supporta-api-key-authentication)
- [API-002 - Endpoint non hanno response type annotations](#api-002--endpoint-non-hanno-response-type-annotations)
- [API-003 - Manca rate limiting](#api-003--manca-rate-limiting)

## Indice Issue Risolte

- [API-004 - Gestione errore DB con 503 Service Unavailable](#api-004--gestione-errore-db-con-503-service-unavailable)

---

## Issue Aperte

### API-001 — Swagger UI non supporta API Key authentication

| Campo | Valore |
|-------|--------|
| **ID** | API-001 |
| **Categoria** | UX |
| **Priorità** | Bassa |
| **Status** | Aperto |
| **Data Apertura** | 2026-04-10 |

**Descrizione:**  
La Swagger UI (`/swagger`) non mostra il bottone "Authorize" per inserire l'API Key. Gli endpoint restituiscono 401 quando provati da Swagger. L'API di `Microsoft.OpenApi` v2 in .NET 10 ha cambiato le interfacce e la configurazione del SecurityScheme non è compatibile col vecchio pattern.

**Workaround:**  
Usare il file `API.http` integrato in Visual Studio o curl con header `X-Api-Key`.

**Soluzione proposta:**  
Aggiornare la configurazione OpenAPI quando la documentazione di `Microsoft.OpenApi` v2 sarà stabile, oppure usare un `IDocumentFilter` custom.

---

### API-002 — Endpoint non hanno response type annotations

| Campo | Valore |
|-------|--------|
| **ID** | API-002 |
| **Categoria** | API |
| **Priorità** | Bassa |
| **Status** | Aperto |
| **Data Apertura** | 2026-04-10 |

**Descrizione:**  
Gli endpoint Minimal API non hanno `.Produces<T>()` / `.ProducesNotFound()` annotations. La specifica OpenAPI generata non include i tipi di risposta, il che rende la documentazione Swagger meno informativa.

**Soluzione proposta:**  
Aggiungere `.Produces<DeviceSummaryDto[]>(200)` e simili a ogni endpoint mapping.

---

### API-003 — Manca rate limiting

| Campo | Valore |
|-------|--------|
| **ID** | API-003 |
| **Categoria** | Security |
| **Priorità** | Bassa |
| **Status** | Aperto |
| **Data Apertura** | 2026-04-10 |

**Descrizione:**  
Non c'è rate limiting sugli endpoint. Un consumer con API Key valida potrebbe sovraccaricare il server con richieste eccessive.

**Soluzione proposta:**  
Aggiungere `Microsoft.AspNetCore.RateLimiting` con policy per API Key quando l'API sarà in produzione.

---

## Issue Risolte

### API-004 — Gestione errore DB con 503 Service Unavailable

| Campo | Valore |
|-------|--------|
| **ID** | API-004 |
| **Categoria** | Robustezza |
| **Priorità** | Bassa |
| **Status** | ✅Risolto |
| **Data Apertura** | 2026-04-13 |
| **Data Risoluzione** | 2026-04-13 |
| **Branch** | fix/gui-010-api-004 |
| **Correlata** | [GUI-010](../GUI.Windows/ISSUES.md#gui-010--gestione-errore-connessione-db-allavvio) |

**Soluzione Implementata:**

1. **`DatabaseExceptionMiddleware.cs`** CREATO — global exception handler:
   - Cattura `TimeoutException`, `SqlException` (by name, no direct dependency) e wrapper EF Core (InnerException ricorsivo)
   - Ritorna `503 Service Unavailable` con JSON `{ "error": "..." }`
   - In Development: aggiunge campo `detail` con `ex.Message`
   - In Production: solo messaggio generico (no stacktrace leak)
2. **`Program.cs`**: middleware registrato **prima** di `ApiKeyMiddleware`
3. **8 unit test** in `DatabaseExceptionMiddlewareTests.cs`

**File Creati:**
- `API/Middleware/DatabaseExceptionMiddleware.cs`
- `Tests/Unit/API/DatabaseExceptionMiddlewareTests.cs`

**File Modificati:**
- `API/Program.cs` (registrazione middleware)

**Benefici Ottenuti:**
- Consumer ricevono JSON strutturato 503 invece di 500 con stacktrace ✅
- Nessun leak di informazioni interne in produzione ✅
- Health check `/health` + middleware complementari ✅

---
