---
name: "repo-report"
description: "Report repository state: PRs, issues, branches, CI runs, protection settings."
---

# Repo Report

Summarize the current state of one or more GitHub repositories. Uses `gh` directly — no helper scripts.

## Trigger

User invokes `/repo-report` or asks "what's the state of <repo>".

## Workflow

### Step 1: Determine target repos

If the user named them, use those. Otherwise detect from the current working directory:

```powershell
gh repo view --json nameWithOwner -q '.nameWithOwner'
```

If that fails and the user didn't specify, ask.

### Step 2: Gather sections

Run these per repo. Present each section as a linkable, scannable block.

**Header:**
```powershell
gh repo view <owner>/<repo> --json name,description,defaultBranchRef,stargazerCount,forkCount,isArchived,visibility
```

**Branch protection / rulesets:**
```powershell
gh api repos/<owner>/<repo>/rulesets --jq '.[] | {name, target, enforcement}'
gh api repos/<owner>/<repo>/rulesets/<id> --jq '.rules'
```

**Open PRs:**
```powershell
gh pr list --repo <owner>/<repo> --state open --json number,title,author,labels,assignees,isDraft,createdAt,updatedAt,headRefName,statusCheckRollup
```

**Open issues (exclude PRs):**
```powershell
gh issue list --repo <owner>/<repo> --state open --json number,title,author,labels,assignees,createdAt,updatedAt
```

**Branches:**
```powershell
gh api repos/<owner>/<repo>/branches --jq '.[] | {name, protected}'
```

**Recent CI runs (last 5):**
```powershell
gh run list --repo <owner>/<repo> --limit 5 --json databaseId,name,headBranch,event,status,conclusion,displayTitle,createdAt
```

### Step 3: Present

For each section, a compact table with clickable links to each PR / issue / run / branch / commit. Don't summarize — Luca will read.

Example layout:

```markdown
## <owner>/<repo>

Default: main · Private · <description>

### Protected branches
- main (PR required, Build Gate required)

### Open PRs (3)
| # | Title | Author | Labels | Draft | Created | Status |
| — | ————— | —————— | —————— | ————— | ——————— | —————— |
| [#42](url) | feat: BLE discovery | luca | feat | ✗ | 2 days ago | ✅ |

### Open issues (7)
| # | Title | Labels | Created |
| — | ————— | —————— | ——————— |

### Recent CI runs
| # | Workflow | Branch | Event | Status | When |
```

### Step 4: Cross-repo roll-up (optional)

If multiple repos queried, add a final "Attention needed" section flagging:
- PRs with failing checks
- PRs open >7 days with no activity
- Branches behind `main` by >20 commits
- CI runs that failed in the last 24h

## Notes

- `gh` must be authenticated (`gh auth status`).
- Works across both Luca's personal GitHub and any org he's a collaborator on.
- Use the repo format `<owner>/<repo>` everywhere.
