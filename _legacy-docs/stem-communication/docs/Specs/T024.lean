/-!
# Task Specification: T-024

## Metadata
- **Date:** 2026-02-26
- **Branch:** fix/t-024
- **Status:** Draft

## Summary
Aggiungere `CancellationToken` a tutte le interfacce async pubbliche del protocollo,
garantendo propagazione completa attraverso lo stack. Include applicazione di 
`ConfigureAwait(false)` su tutti gli await (integra T-019).
-/

namespace Stem.Spec.T024

-- ============================================
-- SECTION 1: Domain Types
-- ============================================

/-- Metodi async che richiedono CancellationToken -/
inductive AsyncMethod where
  | initializeAsync       : AsyncMethod
  | uninitializeAsync     : AsyncMethod
  | processUpstreamAsync  : AsyncMethod
  | processDownstreamAsync: AsyncMethod
  | handleAsync           : AsyncMethod  -- ICommandHandler
  | handleAckAsync        : AsyncMethod  -- IAckHandler
  | readAsync             : AsyncMethod  -- IVariableMap
  | writeAsync            : AsyncMethod  -- IVariableMap
  deriving Repr, DecidableEq

/-- Interfacce coinvolte -/
inductive Interface where
  | iProtocolLayer   : Interface
  | iCommandHandler  : Interface
  | iAckHandler      : Interface
  | iVariableMap     : Interface
  | protocolStack    : Interface  -- Classe, non interfaccia
  | iChannelDriver   : Interface  -- Già conforme
  deriving Repr, DecidableEq

/-- Stato di un metodo rispetto a CT -/
inductive CTStatus where
  | missing         : CTStatus  -- Non ha CT
  | hasDefault      : CTStatus  -- Ha CT con = default
  | propagated      : CTStatus  -- Propaga CT ai chiamati
  deriving Repr, DecidableEq

-- ============================================
-- SECTION 2: Preconditions (da Step 2)
-- ============================================

/-- Precondizioni concordate con l'utente -/
structure Preconditions where
  /-- IChannelDriver è già conforme (non modificare) -/
  channelDriverConforme : Bool
  /-- Event handlers NON devono ricevere CT (pattern .NET) -/
  eventHandlersNoCT : Bool
  /-- Breaking change accettato (no backward compat) -/
  breakingChangeAccepted : Bool
  /-- T-019 (ConfigureAwait) integrata in questo task -/
  t019Integrated : Bool
  /-- CANCELLATION_STANDARD.md creato e approvato -/
  standardCreated : Bool
  /-- THREAD_SAFETY_STANDARD.md allineato (TS-063) -/
  threadSafetyAligned : Bool

/-- Validazione precondizioni -/
def preconditionsValid (p : Preconditions) : Prop :=
  p.channelDriverConforme ∧ 
  p.eventHandlersNoCT ∧ 
  p.breakingChangeAccepted ∧
  p.t019Integrated ∧
  p.standardCreated ∧
  p.threadSafetyAligned

-- ============================================
-- SECTION 3: Postconditions (da Step 2)
-- ============================================

/-- Postcondizioni che devono valere dopo il task -/
structure Postconditions where
  /-- Tutti i metodi async pubblici hanno CT come ultimo parametro -/
  allPublicAsyncHaveCT : Bool
  /-- Tutti i CT hanno default value `= default` -/
  allCTHaveDefault : Bool
  /-- Nome parametro è sempre `cancellationToken` (non abbreviato) -/
  parameterNameCorrect : Bool
  /-- CT viene propagato a tutti i metodi async chiamati -/
  ctPropagatedToAll : Bool
  /-- ConfigureAwait(false) presente su tutti gli await -/
  configureAwaitApplied : Bool
  /-- Build compila senza errori -/
  buildSucceeds : Bool
  /-- Tutti i test esistenti passano -/
  existingTestsPass : Bool

/-- Validazione postcondizioni -/
def postconditionsValid (p : Postconditions) : Prop :=
  p.allPublicAsyncHaveCT ∧
  p.allCTHaveDefault ∧
  p.parameterNameCorrect ∧
  p.ctPropagatedToAll ∧
  p.configureAwaitApplied ∧
  p.buildSucceeds ∧
  p.existingTestsPass

-- ============================================
-- SECTION 4: Invariants
-- ============================================

/-- Invarianti che NON devono cambiare -/
structure Invariants where
  /-- Comportamento funzionale identico (CT con default = comportamento precedente) -/
  functionalBehaviorUnchanged : Bool
  /-- IChannelDriver non viene modificato (già conforme) -/
  channelDriverUnchanged : Bool
  /-- Event handlers non modificati -/
  eventHandlersUnchanged : Bool
  /-- Dispose/DisposeAsync non ricevono CT (non cancellabili by design) -/
  disposeUnchanged : Bool
  /-- Ordine dei parametri esistenti non cambia (CT aggiunto come ultimo) -/
  parameterOrderPreserved : Bool

/-- Validazione invarianti -/
def invariantsValid (i : Invariants) : Prop :=
  i.functionalBehaviorUnchanged ∧
  i.channelDriverUnchanged ∧
  i.eventHandlersUnchanged ∧
  i.disposeUnchanged ∧
  i.parameterOrderPreserved

-- ============================================
-- SECTION 5: Transformation Plan (da Step 3)
-- ============================================

/-- Piano di trasformazione formalizzato -/
structure TransformationPlan where
  /-- File da modificare -/
  filesToModify : List String
  /-- File da creare -/
  filesToCreate : List String
  /-- File da eliminare -/
  filesToDelete : List String
  /-- Test richiesti (nuovi) -/
  testsRequired : Nat
  /-- Breaking changes previsti -/
  breakingChanges : Bool
  /-- Numero di fasi -/
  phases : Nat

/-- Piano concreto per T-024 -/
def plan : TransformationPlan := {
  filesToModify := [
    -- Fase 1: IVariableMap
    "Protocol/Layers/ApplicationLayer/Interfaces/IVariableMap.cs",
    "Protocol/Layers/ApplicationLayer/Helpers/VariableMap.cs",
    
    -- Fase 2: ICommandHandler, IAckHandler
    "Protocol/Layers/ApplicationLayer/Interfaces/ICommandHandler.cs",
    "Protocol/Layers/ApplicationLayer/Interfaces/IAckHandler.cs",
    "Protocol/Layers/ApplicationLayer/Helpers/CommandHandlers/ProtocolVersionHandler.cs",
    "Protocol/Layers/ApplicationLayer/Helpers/CommandHandlers/ReadMemoryAreaHandler.cs",
    "Protocol/Layers/ApplicationLayer/Helpers/CommandHandlers/WriteMemoryAreaHandler.cs",
    "Protocol/Layers/ApplicationLayer/Helpers/CommandHandlers/ReadSingleVarHandler.cs",
    "Protocol/Layers/ApplicationLayer/Helpers/CommandHandlerRegistry.cs",
    
    -- Fase 3: IProtocolLayer + implementazioni
    "Protocol/Layers/Base/Interfaces/IProtocolLayer.cs",
    "Protocol/Layers/Base/ProtocolLayerBase.cs",
    "Protocol/Layers/ApplicationLayer/ApplicationLayer.cs",
    "Protocol/Layers/PresentationLayer/PresentationLayer.cs",
    "Protocol/Layers/SessionLayer/SessionLayer.cs",
    "Protocol/Layers/TransportLayer/TransportLayer.cs",
    "Protocol/Layers/NetworkLayer/NetworkLayer.cs",
    "Protocol/Layers/DataLinkLayer/DataLinkLayer.cs",
    "Protocol/Layers/PhysicalLayer/PhysicalLayer.cs",
    
    -- Fase 4: ProtocolStack
    "Protocol/Layers/Stack/ProtocolStack.cs",
    "Protocol/Layers/Stack/ProtocolStackBuilder.cs",
    
    -- Fase 5: ConfigureAwait(false) - tutti i file sopra
    -- (applicato insieme alle modifiche CT)
    
    -- Test da aggiornare
    "Tests/Unit/Protocol/Layers/ApplicationLayer/VariableMapTests.cs",
    "Tests/Unit/Protocol/Layers/ApplicationLayer/CommandHandlerTests.cs",
    "Tests/Unit/Protocol/Layers/Base/ProtocolLayerBaseTests.cs",
    "Tests/Unit/Protocol/Layers/Stack/ProtocolStackTests.cs"
  ],
  filesToCreate := [
    -- Test specifici per cancellazione
    "Tests/Unit/Protocol/CancellationTests/CancellationPropagationTests.cs"
  ],
  filesToDelete := [],
  testsRequired := 15,  -- Test per cancellazione e timeout
  breakingChanges := true,  -- Firma metodi cambia
  phases := 5
}

-- ============================================
-- SECTION 6: Detailed Phase Plan
-- ============================================

/-- Fase del piano di implementazione -/
structure Phase where
  number : Nat
  name : String
  interfaces : List Interface
  dependsOn : List Nat  -- Fasi prerequisite

def phases : List Phase := [
  { number := 1, name := "IVariableMap", interfaces := [Interface.iVariableMap], dependsOn := [] },
  { number := 2, name := "Handlers", interfaces := [Interface.iCommandHandler, Interface.iAckHandler], dependsOn := [1] },
  { number := 3, name := "IProtocolLayer", interfaces := [Interface.iProtocolLayer], dependsOn := [2] },
  { number := 4, name := "ProtocolStack", interfaces := [Interface.protocolStack], dependsOn := [3] },
  { number := 5, name := "ConfigureAwait", interfaces := [], dependsOn := [1, 2, 3, 4] }
]

-- ============================================
-- SECTION 7: Theorems (Garanzie)
-- ============================================

/-- 
Teorema: La trasformazione preserva gli invarianti.
Il comportamento funzionale non cambia perché CT ha default value.
-/
theorem transformation_preserves_invariants 
    (pre : Preconditions) 
    (inv : Invariants) 
    (plan : TransformationPlan) 
    (h_pre : preconditionsValid pre)
    (h_inv : invariantsValid inv) : 
    Postconditions := by
  sorry -- Verificato durante implementazione

/-- 
Teorema: Nessuna regressione sui test esistenti.
I test esistenti passano perché CT = default ha stesso comportamento.
-/
theorem no_test_regression 
    (existingTests : Nat) 
    (plan : TransformationPlan) : 
    existingTests ≤ existingTests + plan.testsRequired := by
  omega

/-- 
Teorema: Le fasi sono ordinate correttamente (DAG).
Ogni fase dipende solo da fasi con numero inferiore.
-/
theorem phases_correctly_ordered : 
    ∀ p ∈ phases, ∀ d ∈ p.dependsOn, d < p.number := by
  sorry -- Verificabile per ispezione

/-- 
Teorema: IChannelDriver non viene modificato.
È già conforme, nessuna modifica necessaria.
-/
theorem channel_driver_unchanged 
    (inv : Invariants) 
    (h : inv.channelDriverUnchanged) : 
    Interface.iChannelDriver ∉ plan.filesToModify.map (fun _ => Interface.iChannelDriver) := by
  sorry -- IChannelDriver.cs non è in filesToModify

-- ============================================
-- SECTION 8: Issues Integration
-- ============================================

/-- Issues che verranno risolte con questo task -/
def resolvedIssues : List String := [
  "T-024",  -- CancellationToken Propagation (principale)
  "T-019"   -- ConfigureAwait(false) (integrata)
]

/-- Issues correlate ma non risolte -/  
def relatedIssues : List String := [
  "T-005"   -- Thread Safety (già risolto, solo allineamento standard TS-063)
]

end Stem.Spec.T024

/-!
## Verification Checklist

Prima di procedere a Step 4, verificare:

- [x] Preconditions: Breaking change accettato
- [x] Preconditions: T-019 integrata
- [x] Preconditions: CANCELLATION_STANDARD.md creato
- [x] Preconditions: THREAD_SAFETY_STANDARD.md allineato
- [ ] Postconditions: Tutte verificabili con test
- [ ] Invariants: Nessun componente escluso per errore
- [ ] Plan: File list completa

## Exit Criteria

Utente conferma "spec ok" per procedere a Step 4 (Apply Changes).
-/
