/-!
# Task Specification: T-006 + BASE-001 + T-013

## Metadata
- **Date:** 2026-02-18
- **Branch:** fix/t-006
- **Status:** Confirmed ✅
- **Related Issues:** T-006, BASE-001, T-013

## Summary
Refactoring del lifecycle dei layer del protocollo:
1. Rimuovere `Shutdown()` (alias inutile di Dispose)
2. Introdurre `UninitializeAsync()` (de-inizializza senza disporre)
3. Aggiungere `IDisposable` e `IAsyncDisposable` a `IProtocolLayer`
4. Standardizzare helper lifecycle con ownership rule
5. Rimuovere costruttore DI da NetworkLayer
-/

namespace Stem.Spec.T006

-- ============================================
-- SECTION 1: Domain Types
-- ============================================

/-- Stati possibili di un layer nel nuovo lifecycle -/
inductive LayerState where
  | Constructed    -- Creato ma non inizializzato
  | Initialized    -- Attivo, può processare messaggi
  | Uninitialized  -- De-inizializzato, può essere re-inizializzato
  | Disposed       -- Risorse rilasciate, non riutilizzabile
  deriving Repr, DecidableEq

/-- Tipo di ownership per un helper -/
inductive HelperOwnership where
  | Owned     -- Creato internamente dal layer
  | Borrowed  -- Iniettato via DI, non posseduto
  deriving Repr, DecidableEq

/-- Risultato di un'operazione di lifecycle -/
inductive LifecycleResult where
  | Success
  | AlreadyInState
  | InvalidTransition
  | Failed (reason : String)
  deriving Repr, DecidableEq

/-- Rappresentazione di un helper -/
structure Helper where
  name : String
  ownership : HelperOwnership
  isDisposable : Bool
  requiresConfig : Bool
  deriving Repr

/-- Rappresentazione di un layer -/
structure ProtocolLayer where
  name : String
  level : Nat
  state : LayerState
  helpers : List Helper
  deriving Repr

-- ============================================
-- SECTION 2: Preconditions (da Step 2)
-- ============================================

/-- Precondizioni concordate con l'utente -/
structure Preconditions where
  /-- Tutti i layer hanno Shutdown() che è alias di Dispose() -/
  allLayersHaveShutdown : Bool := true
  
  /-- IProtocolLayer NON eredita da IDisposable attualmente -/
  iProtocolLayerNotDisposable : Bool := true
  
  /-- ProtocolLayerBase implementa IDisposable -/
  baseImplementsDisposable : Bool := true
  
  /-- NetworkLayer ha costruttore DI con 5 helper (poco usato) -/
  networkLayerHasDIConstructor : Bool := true
  
  /-- Solo 1 test usa il costruttore DI di NetworkLayer -/
  networkLayerDITestCount : Nat := 1
  
  /-- CommandHandlerRegistry NON implementa IDisposable -/
  registryNotDisposable : Bool := true
  
  /-- Helper interni creati nel costruttore ignorano config -/
  helpersIgnoreConfig : Bool := true

-- ============================================
-- SECTION 3: Postconditions (da Step 2)
-- ============================================

/-- Postcondizioni che devono valere dopo il task -/
structure Postconditions where
  /-- Nessun layer ha Shutdown() -/
  noShutdownMethod : Bool := true
  
  /-- Tutti i layer hanno UninitializeAsync() : Task<bool> -/
  allLayersHaveUninitialize : Bool := true
  
  /-- IProtocolLayer : IDisposable, IAsyncDisposable -/
  iProtocolLayerIsDisposable : Bool := true
  
  /-- NetworkLayer NON ha costruttore DI -/
  networkLayerNoDIConstructor : Bool := true
  
  /-- Helper owned: resettati in UninitializeAsync, disposti in Dispose -/
  ownedHelpersCorrectLifecycle : Bool := true
  
  /-- Helper borrowed: NON toccati in UninitializeAsync/Dispose -/
  borrowedHelpersUntouched : Bool := true
  
  /-- Build compila senza errori -/
  buildSucceeds : Bool := true
  
  /-- Tutti i test passano -/
  allTestsPass : Bool := true

-- ============================================
-- SECTION 4: Invariants
-- ============================================

/-- Invarianti che NON devono cambiare -/
structure Invariants where
  /-- Le risorse vengono rilasciate correttamente -/
  resourcesReleased : Bool := true
  
  /-- L'ordine di cleanup è corretto (helper prima, poi base) -/
  cleanupOrderCorrect : Bool := true
  
  /-- I test esistenti continuano a funzionare -/
  existingTestsWork : Bool := true
  
  /-- CommandHandlerRegistry DI in ApplicationLayer funziona -/
  appLayerDIWorks : Bool := true
  
  /-- Il pattern Pattern 2 (helper resettabili) è applicato -/
  helpersAreResettable : Bool := true

-- ============================================
-- SECTION 5: Transformation Plan (da Step 3)
-- ============================================

/-- Piano di trasformazione formalizzato -/
structure TransformationPlan where
  filesToModify : List String
  filesToCreate : List String
  filesToDelete : List String
  testsToUpdate : Nat
  testsToAdd : Nat
  testsToRemove : Nat
  breakingChanges : Bool
  estimatedEffort : String

/-- Piano concreto per T-006 + BASE-001 + T-013 -/
def plan : TransformationPlan := {
  filesToModify := [
    -- Interfacce base
    "Protocol/Layers/Base/Interfaces/IProtocolLayer.cs",
    "Protocol/Layers/Base/ProtocolLayerBase.cs",
    
    -- Tutti i 7 layer
    "Protocol/Layers/PhysicalLayer/PhysicalLayer.cs",
    "Protocol/Layers/DataLinkLayer/DataLinkLayer.cs",
    "Protocol/Layers/NetworkLayer/NetworkLayer.cs",
    "Protocol/Layers/TransportLayer/TransportLayer.cs",
    "Protocol/Layers/SessionLayer/SessionLayer.cs",
    "Protocol/Layers/PresentationLayer/PresentationLayer.cs",
    "Protocol/Layers/ApplicationLayer/ApplicationLayer.cs",
    
    -- Stack
    "Protocol/Layers/Stack/ProtocolStack.cs",
    
    -- Helper che devono supportare Reset()
    "Protocol/Layers/NetworkLayer/Helpers/RoutingTableManager.cs",
    "Protocol/Layers/NetworkLayer/Helpers/BroadcastManager.cs",
    "Protocol/Layers/NetworkLayer/Helpers/DeviceDiscoveryService.cs",
    "Protocol/Layers/TransportLayer/Helpers/ChunkReassembler.cs",
    "Protocol/Layers/SessionLayer/Helpers/SessionManager.cs",
    
    -- Standard da aggiornare
    "Docs/Standards/LIFECYCLE_STANDARD.md",
    
    -- ISSUES da aggiornare
    "Protocol/ISSUES.md",
    "Protocol/Layers/Base/ISSUES.md",
    "Protocol/Layers/Stack/ISSUES.md"
  ],
  filesToCreate := [],
  filesToDelete := [],
  testsToUpdate := 50,   -- Test che usano Shutdown() → DisposeAsync()
  testsToAdd := 10,      -- Test per UninitializeAsync + re-init
  testsToRemove := 1,    -- Test costruttore DI NetworkLayer
  breakingChanges := true,  -- Rimozione Shutdown() è breaking
  estimatedEffort := "M (4-8 ore)"
}

-- ============================================
-- SECTION 6: State Transitions
-- ============================================

/-- Transizioni di stato valide nel nuovo lifecycle -/
def validTransition (from to : LayerState) : Bool :=
  match from, to with
  | .Constructed, .Initialized => true      -- InitializeAsync()
  | .Initialized, .Uninitialized => true    -- UninitializeAsync()
  | .Uninitialized, .Initialized => true    -- Re-InitializeAsync()
  | .Initialized, .Disposed => true         -- Dispose() da stato attivo
  | .Uninitialized, .Disposed => true       -- Dispose() da stato inattivo
  | .Constructed, .Disposed => true         -- Dispose() senza init
  | _, _ => false

/-- Azioni per helper owned in ogni transizione -/
def ownedHelperAction (transition : LayerState × LayerState) : String :=
  match transition with
  | (.Constructed, .Initialized) => "Create with config"
  | (.Initialized, .Uninitialized) => "Reset state"
  | (.Uninitialized, .Initialized) => "Reconfigure"
  | (_, .Disposed) => "Dispose"
  | _ => "None"

/-- Azioni per helper borrowed in ogni transizione -/
def borrowedHelperAction (transition : LayerState × LayerState) : String :=
  match transition with
  | _ => "None"  -- Mai toccare helper borrowed

-- ============================================
-- SECTION 7: Theorems (Garanzie)
-- ============================================

/-- 
Teorema: Uno stato Disposed non può transizionare ad altro.
-/
theorem disposed_is_terminal : 
    ∀ s : LayerState, s ≠ LayerState.Disposed → ¬validTransition LayerState.Disposed s = true := by
  intro s _
  cases s <;> simp [validTransition]

/-- 
Teorema: Un layer può sempre essere disposto (da qualsiasi stato non-disposed).
-/
theorem can_always_dispose :
    ∀ s : LayerState, s ≠ LayerState.Disposed → 
    validTransition s LayerState.Disposed = true := by
  intro s h
  cases s <;> simp [validTransition]
  · contradiction

/--
Teorema: La reinizializzazione è possibile solo dopo UninitializeAsync.
-/
theorem reinit_requires_uninit :
    validTransition LayerState.Initialized LayerState.Initialized = false := by
  simp [validTransition]

/--
Teorema: Helper borrowed non vengono mai toccati.
-/
theorem borrowed_helper_untouched :
    ∀ t : LayerState × LayerState, borrowedHelperAction t = "None" := by
  intro t
  simp [borrowedHelperAction]

-- ============================================
-- SECTION 8: API Signatures (Contratto)
-- ============================================

/-- Nuova API di IProtocolLayer -/
structure IProtocolLayerAPI where
  /-- Nome del layer -/
  layerName : String
  /-- Livello OSI (1-7) -/
  layerLevel : Nat
  /-- Stato inizializzazione -/
  isInitialized : Bool
  
  /-- Inizializza il layer con config opzionale -/
  initializeAsync : Unit → Bool  -- Task<bool>
  /-- De-inizializza il layer (può essere re-inizializzato) -/
  uninitializeAsync : Unit → Bool  -- Task<bool> ← NUOVO
  /-- Processa dati upstream -/
  processUpstreamAsync : Unit → Unit
  /-- Processa dati downstream -/
  processDownstreamAsync : Unit → Unit
  
  /-- Da IDisposable -/
  dispose : Unit → Unit
  /-- Da IAsyncDisposable -/
  disposeAsync : Unit → Unit  -- ValueTask

/-- Verifica che Shutdown NON sia presente -/
def noShutdownInAPI (api : IProtocolLayerAPI) : Prop :=
  True  -- Shutdown non è nel tipo, quindi garantito

-- ============================================
-- SECTION 9: Migration Checklist
-- ============================================

/-- Checklist per ogni layer -/
structure LayerMigrationChecklist where
  layerName : String
  /-- Shutdown() rimosso -/
  shutdownRemoved : Bool := false
  /-- UninitializeAsync() aggiunto -/
  uninitializeAdded : Bool := false
  /-- Helper owned hanno Reset() -/
  helpersHaveReset : Bool := false
  /-- Test aggiornati -/
  testsUpdated : Bool := false

/-- Checklist completa del progetto -/
def migrationChecklist : List LayerMigrationChecklist := [
  { layerName := "PhysicalLayer" },
  { layerName := "DataLinkLayer" },
  { layerName := "NetworkLayer" },
  { layerName := "TransportLayer" },
  { layerName := "SessionLayer" },
  { layerName := "PresentationLayer" },
  { layerName := "ApplicationLayer" },
  { layerName := "ProtocolStack" }
]

-- ============================================
-- SECTION 10: Test Requirements
-- ============================================

/-- Test da aggiungere per ogni layer -/
structure RequiredTests where
  /-- Test: InitializeAsync → UninitializeAsync → Re-InitializeAsync funziona -/
  reinitializationWorks : Bool := false
  /-- Test: UninitializeAsync da stato non-init ritorna false -/
  uninitNotInitReturnsFalse : Bool := false
  /-- Test: Dispose dopo Uninitialize funziona -/
  disposeAfterUninitWorks : Bool := false
  /-- Test: Helper owned resettati dopo Uninitialize -/
  helpersResetAfterUninit : Bool := false
  /-- Test: Helper borrowed intatti dopo Uninitialize -/
  borrowedHelpersIntact : Bool := false

end Stem.Spec.T006
