---
name: "new-ticket"
description: "Interactive Q&A to gather requirements and create a GitHub issue."
---

# New Ticket

Create a GitHub issue from a short description, via a quick Q&A.

## Trigger

User invokes `/new-ticket` or asks for a new issue / ticket.

## Workflow

### Step 1: Detect repository

Check if the CWD is a git repo with a GitHub remote:

```powershell
gh repo view --json nameWithOwner -q '.nameWithOwner'
```

If it returns, that's the target repo. If not — or the user names a different repo — search across Luca's GitHub:

```powershell
gh repo list <luca-user> --limit 100 --json nameWithOwner,description | ConvertFrom-Json | Where-Object { $_.nameWithOwner -like "*<keyword>*" -or $_.description -like "*<keyword>*" }
```

Confirm the target before proceeding.

### Step 2: Interview

Ask one question at a time, using AskUserQuestion. Skip any the user already answered upfront.

1. **What's the ticket about?** — Short description of the feature, bug, or task.
2. **Type?** — Suggest `feat`, `fix`, `chore`, `docs`, `refactor`, `test`. Default `feat`.
3. **Acceptance criteria** — Concrete conditions for "done".
4. **Context** — Related issues, code paths, external dependencies, constraints.
5. **Labels** — Based on type, confirm or add.

If the initial message already contains everything, collapse the interview into one follow-up confirmation.

### Step 3: Draft

Present the draft to the user:

```
Title: <concise title, conventional-style without the prefix>
Labels: <labels>

<body>
```

Body structure:
- 1–3 sentence description
- **Acceptance criteria** as a checklist
- **Context** section if relevant
- Links to related issues, files (using `path/File.cs:L42`), or external docs

Ask for confirmation or edits.

### Step 4: Create

```powershell
gh issue create `
    --repo <owner>/<repo> `
    --title "<title>" `
    --body "<body>" `
    --label "<label1>,<label2>"
```

Show the resulting issue URL as a clickable link.

### Step 5: Add to Planning board (pending access)

> **Status:** Luca does not yet have write access to `paolino/Planning` (project #2, `PVT_kwHN3B7OAT-p6g`). Until access is granted, **skip this step** and leave the issue unlinked on the board.
>
> Once he has access, the `issue-lifecycle` MCP wraps the GraphQL calls:
> ```
> mcp__issue-lifecycle__add_to_backlog(
>     owner="<owner>", repo="<repo>", issue_number=<N>,
>     ownership="Work" | "Personal"
> )
> ```
> The MCP's `REPO_CATEGORY` map needs entries for Luca's repos (Stem.*, Spark.*, llm-settings) — those categories probably need to be added to the board by paolino first. Ask before auto-categorizing.

### Step 6: Start work (optional)

Offer to start working on the ticket immediately. If yes:

```powershell
git fetch github
git switch -c <type>/<slug> github/main
```

Slug convention: `<type>/<short-description>` (e.g. `feat/ble-scan-timeout`).

## Label mapping

| Type     | Label    |
|----------|----------|
| feat     | feat     |
| fix      | fix      |
| chore    | chore    |
| docs     | docs     |
| refactor | refactor |
| test     | test     |

(Labels match the convention from the `new-repository` skill. The `enhancement` / `bug` GitHub defaults are not used — we use the conventional-commits style directly.)

## Validation links

After each answer, show relevant links so Luca can verify you understood:

- Repo confirmed → link to GitHub.
- Feature described → links to related existing issues/PRs/code:
    ```powershell
    gh issue list --repo <owner>/<repo> --search "<keyword>" --limit 5
    gh pr list    --repo <owner>/<repo> --search "<keyword>" --limit 5
    ```
- Context mentioned → link the referenced issues, PRs, or files.

## Notes

- Keep the interview fast. Don't over-ask.
- Title in English (conventional-commits style); body can be Italian if the rest of the repo uses Italian.
- Body should be scannable, not verbose.
