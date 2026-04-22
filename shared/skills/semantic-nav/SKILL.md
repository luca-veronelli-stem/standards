---
name: "semantic-nav"
description: "Create a NAVIGATION.md codebase map organized by concepts rather than files."
---

# Semantic Navigation Skill

Create a human-readable navigation map of a codebase. The output is a `NAVIGATION.md` file that helps developers understand *what* the code does and *why*, organized by concepts rather than files.

## When to Use

- When starting work on an unfamiliar codebase
- When the user asks for a "semantic map", "navigation guide", or "codebase overview"
- When onboarding documentation is needed

## Output Format

Create a `NAVIGATION.md` file in the project root with this structure:

```markdown
# 🗺️ [Project Name] — Semantic Navigation

A human-readable map of the codebase. Each section explains *what* the code does and *why*, with links to the source.

---

## Table of Contents

1. [Section Name](#section-name)
2. [Another Section](#another-section)
   - [Subsection](#subsection)

---

## Section Name

Brief explanation of this domain/concept.

- **Feature/Function name**: What it does and why it exists.
  → [File.ext:L1-L50](https://github.com/owner/repo/blob/<SHA>/path/File.ext#L1-L50)

### Subsection

| Field | Purpose |
|-------|---------|
| `field1` | Description |
| `field2` | Description |

→ [File.ext:L75-L98](https://github.com/owner/repo/blob/<SHA>/path/File.ext#L75-L98)
```

## Process

1. **Identify domains** — Read the codebase and identify logical domains (e.g., authentication, API client, state management, UI, persistence, utilities). Think in terms of *concepts*, not files.

2. **Map code to domains** — For each domain, find the relevant files and line ranges. A single file may span multiple domains; a domain may span multiple files.

3. **Write explanations** — For each piece of code:
   - Explain *what* it does in plain language
   - Explain *why* it exists (its role in the system)
   - Link to the exact line range in the source

4. **Add summary tables** — Use tables for:
   - State fields and their purposes
   - Configuration keys
   - API endpoints
   - Any enumerable list that benefits from quick scanning

5. **Create the TOC** — Build a navigable table of contents with anchor links.

6. **Include project structure** — End with a directory tree showing the physical layout.

## Link Format

**CRITICAL: Use commit SHAs, not branch names.**

Links must point to a specific commit SHA on main, not `blob/main/`.
Branch-based links break when branches are deleted. SHA-based links
are permanent — they always resolve, even if the code later changes.

**Workflow:**
1. Merge the code changes to main first
2. Get the merge commit SHA: `git rev-parse HEAD` (on main)
3. Generate NAVIGATION.md with SHA-based links
4. Commit NAVIGATION.md to main

```
[File.ext:L10-L50](https://github.com/owner/repo/blob/<SHA>/path/File.ext#L10-L50)
```

Example with a real SHA:
```
[GitHub/Rest.purs:L88-L124](https://github.com/owner/repo/blob/e129771/src/GitHub/Rest.purs#L88-L124)
```

The links will reflect the code at that snapshot. When NAVIGATION.md
is updated in the future, use the new HEAD SHA.

For local-only projects without a remote, use relative paths:

```
[File.ext:L10-L50](./path/File.ext)
```

## Search-Link Littering

Make existing documentation navigable by adding GitHub code search
links to module names, type names, and key functions.

### When to Use

- After writing or updating architecture/design docs
- When the user says "litter", "add links", or "make navigable"
- When docs reference code identifiers without links

### Link Patterns

Use GitHub **code search** links (resilient to line-number changes):

| Target | URL pattern |
|--------|-------------|
| Module | `https://github.com/OWNER/REPO/search?q=%22module+Fully.Qualified.Name%22&type=code` |
| Function/type | `https://github.com/OWNER/REPO/search?q=IDENTIFIER&type=code` |
| Function in specific dir | `...&q=IDENTIFIER+path%3Asubdir&type=code` |

### Process

1. **Scan the doc** for bare code references — module names, function
   names, type names (anything in backticks that maps to source).

2. **Generate search links** using the patterns above. Prefer
   `"module X.Y.Z"` searches for modules (exact match) and plain
   identifier searches for functions/types.

3. **Use markdown reference links** to keep the prose clean:

   ```markdown
   The [`Provider`][s-provider] queries UTxOs...

   [s-provider]: https://github.com/owner/repo/search?q=%22module+X.Y.Provider%22&type=code
   ```

4. **Group link definitions** at the end of each section or file for
   readability.

5. **Disambiguate** when a name appears in multiple contexts. Add
   `path%3A` filters to narrow the search:

   ```
   ...search?q=%22module+X.Y.Real%22+path%3AReal.hs&type=code
   ```

### What to Link

- Module names mentioned in text or tables
- Constructor/smart-constructor functions (`mkFoo`, `withFoo`)
- Key data types (`CageEvent`, `AllColumns`, `TokenState`)
- Important functions referenced in explanations

### What NOT to Link

- Standard library / external package identifiers
- Code inside fenced code blocks (already readable)
- Identifiers mentioned only once in passing

## Maintenance

The navigation file needs updates when:
- New features are added (new sections/subsections)
- Code is refactored (line numbers shift)
- Files are renamed or moved

When updating:
1. Merge the code changes to main first
2. Get the new HEAD SHA from main
3. Re-read the affected files, adjust line ranges
4. Update all links to use the new SHA
5. Commit NAVIGATION.md to main

Old SHA-based links remain valid forever — they just point to an
older snapshot. The update ensures links reflect the current code.

## Example Domains

Common domains to look for (adapt to the specific project):

- **Authentication** — Login, tokens, sessions
- **API Client** — External service calls, request/response handling
- **Domain Types** — Core data models
- **Application State** — State management, initialization
- **User Actions** — Event handlers, user interactions
- **View Layer** — UI rendering, components
- **Persistence** — Storage, caching, database
- **FFI/Interop** — Foreign function interfaces, native bindings
- **Utilities** — Helper functions, shared logic
- **Configuration** — Settings, environment, constants
