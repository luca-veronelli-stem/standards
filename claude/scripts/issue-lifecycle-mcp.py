#!/usr/bin/env python3
"""
MCP server for GitHub issue lifecycle automation.

Tools:
  start-issue     Move issue to WIP + create worktree
  create-issue-pr Create PR with "Closes #N", label, assign
  add-to-backlog  Add issue to Planning board in Backlog
"""

import json
import re
import subprocess

from mcp.server.fastmcp import FastMCP

mcp = FastMCP("issue-lifecycle")

GITHUB_USER = "paolino"

# Planning board field IDs (paolino/Planning project #2)
PROJECT_ID = "PVT_kwHN3B7OAT-p6g"
STATUS_FIELD_ID = "PVTSSF_lAHN3B7OAT-p6s4Pi-QN"
STATUS_BACKLOG = "2846e282"
STATUS_WIP = "f443c69c"
STATUS_DONE = "cf213123"
OWNERSHIP_FIELD_ID = "PVTSSF_lAHN3B7OAT-p6s4Pi_R1"
OWNERSHIP_WORK = "d51e4986"
OWNERSHIP_PERSONAL = "37551c80"
CATEGORY_FIELD_ID = "PVTSSF_lAHN3B7OAT-p6s4Pi_SL"
CATEGORIES = {
    "Wallet": "71f7e091",
    "CSMT/UTxO": "5590a718",
    "MPFS": "a9af9574",
    "KERI": "13a20af6",
    "Infra": "fb663fb8",
    "Tooling": "282dfcf7",
    "Antithesis": "40fa3978",
    "Legacy": "a89bef8e",
    "Other": "80ce6937",
}

# Repo name → category mapping
REPO_CATEGORY = {
    "cardano-wallet": "Wallet",
    "cardano-deposit-wallet": "Wallet",
    "cardano-utxo-csmt": "CSMT/UTxO",
    "cardano-mpfs-onchain": "MPFS",
    "cardano-mpfs-offchain": "MPFS",
    "keri-hs": "KERI",
    "agent-daemon": "Tooling",
    "kanbanned": "Tooling",
    "gh-dashboard": "Tooling",
    "spec-kit": "Tooling",
    "libvterm-haskell": "Tooling",
    "haskell-mts": "Tooling",
    "cardano-node-antithesis": "Antithesis",
}


def gh(*args):
    """Run gh CLI, return stdout."""
    result = subprocess.run(
        ["gh", *args], capture_output=True, text=True
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip())
    return result.stdout.strip()


def gh_json(*args):
    """Run gh CLI, parse JSON output."""
    return json.loads(gh(*args))


def gh_graphql(query, **fields):
    """Run GraphQL query via gh api graphql."""
    cmd = ["gh", "api", "graphql", "-f", f"query={query}"]
    for k, v in fields.items():
        flag = "-F" if isinstance(v, int) else "-f"
        cmd.extend([flag, f"{k}={v}"])
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip())
    return json.loads(result.stdout)


def add_issue_to_project(issue_url):
    """Add issue to Planning project, return item ID."""
    result = gh(
        "project", "item-add", "2",
        "--owner", GITHUB_USER,
        "--url", issue_url,
        "--format", "json",
    )
    return json.loads(result)["id"]


def set_project_field(item_id, field_id, option_id):
    """Set a single-select field on a project item."""
    gh(
        "project", "item-edit",
        "--project-id", PROJECT_ID,
        "--id", item_id,
        "--field-id", field_id,
        "--single-select-option-id", option_id,
    )


def get_project_item_id(owner, repo, issue_number):
    """Get the project item ID for an issue on Planning."""
    data = gh_graphql(
        """query($owner: String!, $repo: String!, $number: Int!) {
          repository(owner: $owner, name: $repo) {
            issue(number: $number) {
              projectItems(first: 10) {
                nodes { id project { title } }
              }
            }
          }
        }""",
        owner=owner,
        repo=repo,
        number=issue_number,
    )
    for node in data["data"]["repository"]["issue"]["projectItems"]["nodes"]:
        if node["project"]["title"] == "General Planning":
            return node["id"]
    return None


def infer_category(repo):
    """Infer category from repo name."""
    return REPO_CATEGORY.get(repo, "Other")


def slugify(text, max_len=50):
    """Convert title to branch-friendly slug."""
    s = re.sub(r"[^a-z0-9\s-]", "", text.lower())
    s = re.sub(r"[\s]+", "-", s).strip("-")
    return s[:max_len]


@mcp.tool()
def add_to_backlog(
    owner: str,
    repo: str,
    issue_number: int,
    ownership: str = "Personal",
    category: str | None = None,
) -> str:
    """Add a GitHub issue to the Planning board in Backlog.

    Args:
        owner: Repository owner (e.g. 'lambdasistemi')
        repo: Repository name (e.g. 'agent-daemon')
        issue_number: Issue number
        ownership: 'Work' or 'Personal' (default: Personal)
        category: Category name or None to auto-detect from repo
    """
    lines = []
    issue_url = f"https://github.com/{owner}/{repo}/issues/{issue_number}"

    # Add to project
    item_id = add_issue_to_project(issue_url)
    lines.append(f"Added to Planning: {issue_url}")

    # Set Status = Backlog
    set_project_field(item_id, STATUS_FIELD_ID, STATUS_BACKLOG)
    lines.append("Status: Backlog")

    # Set Ownership
    own_id = OWNERSHIP_WORK if ownership == "Work" else OWNERSHIP_PERSONAL
    set_project_field(item_id, OWNERSHIP_FIELD_ID, own_id)
    lines.append(f"Ownership: {ownership}")

    # Set Category
    cat = category or infer_category(repo)
    cat_id = CATEGORIES.get(cat, CATEGORIES["Other"])
    set_project_field(item_id, CATEGORY_FIELD_ID, cat_id)
    lines.append(f"Category: {cat}")

    return "\n".join(lines)


@mcp.tool()
def start_issue(
    owner: str,
    repo: str,
    issue_number: int,
    repo_path: str,
    branch_prefix: str = "feat",
) -> str:
    """Move a GitHub issue to WIP and create a worktree.

    Args:
        owner: Repository owner (e.g. 'paolino')
        repo: Repository name (e.g. 'kel-circle')
        issue_number: Issue number
        repo_path: Path to main repo (e.g. '/code/kel-circle')
        branch_prefix: Branch prefix (default: 'feat')
    """
    lines = []

    # 1. Get issue title
    issue = gh_json(
        "issue", "view", str(issue_number),
        "--repo", f"{owner}/{repo}",
        "--json", "title",
    )
    title = issue["title"]
    lines.append(f"Issue #{issue_number}: {title}")

    # 2. Ensure on project board
    item_id = get_project_item_id(owner, repo, issue_number)
    if not item_id:
        # Add to project first
        issue_url = f"https://github.com/{owner}/{repo}/issues/{issue_number}"
        item_id = add_issue_to_project(issue_url)
        lines.append("Added to Planning board")

    # 3. Move to WIP
    set_project_field(item_id, STATUS_FIELD_ID, STATUS_WIP)
    lines.append("Status: WIP")

    # 4. Create worktree
    slug = slugify(title)
    branch = f"{branch_prefix}/{slug}"
    worktree_path = f"{repo_path}-issue-{issue_number}"

    subprocess.run(
        ["git", "-C", repo_path, "fetch", "origin", "main"],
        capture_output=True, text=True,
    )
    result = subprocess.run(
        ["git", "-C", repo_path, "worktree", "add",
         worktree_path, "-b", branch, "origin/main"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        result = subprocess.run(
            ["git", "-C", repo_path, "worktree", "add",
             worktree_path, branch],
            capture_output=True, text=True,
        )
        if result.returncode != 0:
            lines.append(f"Worktree: {result.stderr.strip()}")
            return "\n".join(lines)

    lines.append(f"Worktree: {worktree_path}")
    lines.append(f"Branch: {branch}")
    return "\n".join(lines)


@mcp.tool()
def create_issue_pr(
    owner: str,
    repo: str,
    issue_number: int,
    title: str,
    body: str,
    labels: list[str] | None = None,
) -> str:
    """Create a PR that closes a GitHub issue.

    Prepends 'Closes #N' to the body, assigns to paolino.

    Args:
        owner: Repository owner
        repo: Repository name
        issue_number: Issue number this PR closes
        title: PR title
        body: PR body (Closes #N added automatically)
        labels: Labels to add (e.g. ['enhancement'])
    """
    labels = labels or []
    full_body = f"Closes #{issue_number}\n\n{body}"

    cmd = [
        "gh", "pr", "create",
        "--repo", f"{owner}/{repo}",
        "--title", title,
        "--body", full_body,
        "--assignee", GITHUB_USER,
    ]
    for label in labels:
        cmd.extend(["--label", label])

    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        return f"PR creation failed: {result.stderr.strip()}"
    return f"PR created: {result.stdout.strip()}"


if __name__ == "__main__":
    mcp.run()
