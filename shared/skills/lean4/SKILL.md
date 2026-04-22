---
name: "lean4"
description: "Lean 4 theorem proving: edit .lean files, fill sorry, search mathlib, debug lake builds."
---

# Lean 4

Use this skill whenever editing Lean 4 proofs or debugging Lean builds. The `lean-lsp` MCP (wired up in `servers.json`) provides goal inspection, hover info, local search, and multi-attempt proof checks when available.

## Environment

- `lake`, `lean`, `elan` installed via `elan` (install.ps1 handles this).
- `lean-lsp` MCP available in Claude Code (via `uvx lean-lsp-mcp`).
- Lean projects live under `Specs/PhaseN/` in STEM repos.

Verify your environment:

```powershell
elan --version
lean --version
lake --version
```

## Core rules

- **Search before proving.** Check mathlib and project-local theorems before writing a new proof from scratch.
- **Build incrementally.** Don't chase a proof while earlier definitions are broken. Fix red first.
- **Respect the scope.** If the user asked to fill one `sorry`, don't refactor surrounding definitions.
- **Never change statements or add axioms without explicit permission.** Those are invariant boundaries, not implementation details.

## Workflow

1. **Analyze sorries / errors.** `lake build` or use the `lean-lsp` MCP to list diagnostics.
2. **Search mathlib first.** `exact?`, `apply?`, `refine?` tactics or MCP-driven theorem search.
3. **Fill proofs one at a time.** Don't batch.
4. **Check axioms.** `#print axioms <name>` — only `propext`, `Classical.choice`, `Quot.sound` are acceptable by default. Anything else needs sign-off.
5. **Optimize only after correct.** Tactics like `simp only` vs `simp all` are performance tweaks, not correctness fixes.

## Verification gate

A proof is complete when:
- `lake build` passes with no warnings.
- Zero sorries in scope.
- Only standard axioms remain (`#print axioms` is clean).
- No theorem statement changed without permission.

## Style preferences

- `simp`, `exact`, `omega` are fine. Avoid `sorry`, `native_decide` on large terms, `Decidable` hacks.
- Keep predicate definitions in one file, proofs in another (e.g. `Invariants.lean` + `InvariantsProofs.lean`).
- State machines (state → actions → predicates → preservation theorems) map directly to xUnit property tests — see the `workflow` skill's "From Lean to tests" section.

## Typical STEM usage

STEM repos use Lean 4 to formalize domain invariants (e.g., `Stem.Device.Manager/Specs/Phase1/`). The Lean spec drives the xUnit test suite, which drives the C# implementation. When touching any of these three, honor that order:

1. Update the Lean predicate / theorem.
2. Update the xUnit property test that mirrors the preservation theorem.
3. Update the C# implementation to match.

If a change surfaces a gap in the Lean layer, go back to step 1 before continuing.
