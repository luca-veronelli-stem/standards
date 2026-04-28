# Dual-remote workflow (GitHub primary, Bitbucket mirror)

Every STEM work repo has two remotes.

- **`github`** — Luca's private GitHub. Active remote: PRs, Actions CI, issues, Artifacts, project board. This is where development actually happens.
- **`bitbucket`** — STEM's team Bitbucket. Mirror only. Colleagues and work admin read from here.

**Exception:** `llm-settings` itself is GitHub-only. No Bitbucket mirror.

## How the mirror is kept in sync

`main` is mirrored to Bitbucket by a **GitHub Actions workflow** (`.github/workflows/mirror-bitbucket.yml`) that runs on every push to `main`. This is the source of truth — it covers both local pushes and server-side merges via `gh pr merge`, which a local pushurl cannot reach.

For day-to-day pushes from feature branches you can also use a compound pushurl as a belt-and-braces optimization (push hits both hosts immediately, without waiting for Actions), but the workflow is what guarantees `bitbucket/main` is never stale:

```powershell
# Optional: compound pushurl on the 'github' remote
git remote set-url --add --push github git@github.com:<luca-user>/<repo>.git
git remote set-url --add --push github git@bitbucket.org:stem-fw/<repo>.git
git remote -v   # verify
```

## Remote setup for a new repo

```powershell
# After git init (or after cloning from wherever the team keeps the seed)
git remote add github    git@github.com:<luca-user>/<repo>.git
git remote add bitbucket git@bitbucket.org:stem-fw/<repo>.git

# Make 'github' the default push target
git config --global push.default current
git push -u github main
```

Then add the mirror workflow (see below) and provision the Bitbucket deploy key.

## Mirror workflow setup (one-time per repo)

The workflow uses an SSH **deploy key** scoped only to the Bitbucket mirror — keeps CI's blast radius isolated from Luca's personal SSH key.

1. **Generate a dedicated keypair** (PowerShell):
   ```powershell
   ssh-keygen -t ed25519 -C "github-actions-mirror@<repo>" -f $HOME\.ssh\bb_mirror -N '""'
   ```

2. **Register the public key on Bitbucket**: Repository settings → Security → **Access keys** → Add key. Paste `~/.ssh/bb_mirror.pub`, **enable "Has write access"**, label it `github-actions-mirror`.

3. **Register the private key as a GitHub Actions secret** named `BITBUCKET_SSH_KEY`. Use bash `cat` (not PowerShell pipe — line-ending conversion mangles the key and produces `error in libcrypto` at runtime):
   ```bash
   cat ~/.ssh/bb_mirror | gh secret set BITBUCKET_SSH_KEY --repo <luca-user>/<repo>
   ```

4. **Drop in the workflow** at `.github/workflows/mirror-bitbucket.yml`:
   ```yaml
   name: Mirror to Bitbucket
   on:
     push:
       branches: [main]
   concurrency:
     group: mirror-bitbucket-${{ github.ref }}
     cancel-in-progress: true
   permissions:
     contents: read
   jobs:
     mirror:
       name: Push main to Bitbucket
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v6
           with:
             fetch-depth: 0
         - name: Configure SSH for Bitbucket
           env:
             BITBUCKET_SSH_KEY: ${{ secrets.BITBUCKET_SSH_KEY }}
           run: |
             install -d -m 700 ~/.ssh
             printf '%s\n' "$BITBUCKET_SSH_KEY" > ~/.ssh/id_ed25519
             chmod 600 ~/.ssh/id_ed25519
             ssh-keyscan -t rsa,ed25519 bitbucket.org >> ~/.ssh/known_hosts
         - name: Fast-forward bitbucket/main
           run: |
             git remote add bitbucket git@bitbucket.org:stem-fw/<repo>.git
             git push bitbucket HEAD:refs/heads/main
   ```

5. **Verify** after the first push to `main`: `git fetch github && git fetch bitbucket && git rev-parse github/main bitbucket/main` — both SHAs must match.

## PR / CI rules

- Open PRs on **GitHub** (via `gh pr create`). Never on Bitbucket.
- CI of record runs on **GitHub Actions**. Keep `.github/workflows/*.yml` green.
- `bitbucket-pipelines.yml` should exist (the team expects it) but can be a minimal build-only stub. Sync it whenever .NET versions or major dependencies change.
- Issues live on **GitHub**. The `new-ticket` skill targets GitHub only.

## When things drift

With the mirror workflow in place, drift should only happen if Actions is down or someone pushes directly to Bitbucket. Recovery:

```powershell
git fetch github
git fetch bitbucket
git log github/main..bitbucket/main  # inspect differences
# Usually: rebase GitHub branch onto Bitbucket, then push to both.
# Or, if Bitbucket is genuinely behind: git push bitbucket github/main:main
```

**Why this setup:** GitHub-only tooling (Actions marketplace, Copilot, Projects v2, gh CLI, this llm-settings workflow) is the productive side. Bitbucket visibility is a team requirement, not a development need. A push-triggered Actions mirror keeps both honest, including for `gh pr merge` server-side merges that bypass any local pushurl.
