#!/usr/bin/env bash
# Regenerate shared speckit-<cmd> skills from /code/spec-kit templates.
#
# Mirrors spec-kit's `install_ai_skills()` (src/specify_cli/__init__.py) so the
# global skills match what `specify init --ai claude --ai-skills` would install
# per-project. Running this once populates ~/.claude/skills/speckit-* so
# `specify init --here` only needs to scaffold .specify/ in the repo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_SKILLS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SPECKIT_DIR="${SPECKIT_DIR:-/code/spec-kit}"
COMMANDS_DIR="$SPECKIT_DIR/templates/commands"

if [ ! -d "$COMMANDS_DIR" ]; then
  echo "spec-kit templates not found at $COMMANDS_DIR" >&2
  echo "Set SPECKIT_DIR to override." >&2
  exit 1
fi

declare -A DESCRIPTIONS=(
  [specify]="Create or update feature specifications from natural language descriptions. Use when starting new features or refining requirements. Generates spec.md with user stories, functional requirements, and acceptance criteria following spec-driven development methodology."
  [plan]="Generate technical implementation plans from feature specifications. Use after creating a spec to define architecture, tech stack, and implementation phases. Creates plan.md with detailed technical design."
  [tasks]="Break down implementation plans into actionable task lists. Use after planning to create a structured task breakdown. Generates tasks.md with ordered, dependency-aware tasks."
  [implement]="Execute all tasks from the task breakdown to build the feature. Use after task generation to systematically implement the planned solution following TDD approach where applicable."
  [analyze]="Perform cross-artifact consistency analysis across spec.md, plan.md, and tasks.md. Use after task generation to identify gaps, duplications, and inconsistencies before implementation."
  [clarify]="Structured clarification workflow for underspecified requirements. Use before planning to resolve ambiguities through coverage-based questioning. Records answers in spec clarifications section."
  [constitution]="Create or update project governing principles and development guidelines. Use at project start to establish code quality, testing standards, and architectural constraints that guide all development."
  [checklist]="Generate custom quality checklists for validating requirements completeness and clarity. Use to create unit tests for English that ensure spec quality before implementation."
  [taskstoissues]="Convert tasks from tasks.md into GitHub issues. Use after task breakdown to track work items in GitHub project management."
)

# Remove any existing speckit-* skill directories so renames/removals propagate.
for existing in "$SHARED_SKILLS_DIR"/speckit-*/; do
  [ -d "$existing" ] || continue
  rm -rf "$existing"
done

count=0
for template in "$COMMANDS_DIR"/*.md; do
  [ -f "$template" ] || continue
  cmd="$(basename "$template" .md)"
  skill_name="speckit-$cmd"
  skill_dir="$SHARED_SKILLS_DIR/$skill_name"
  mkdir -p "$skill_dir"

  # Strip YAML frontmatter from the template body.
  body="$(awk '
    BEGIN { in_fm=0; started=0 }
    /^---$/ {
      if (!started) { in_fm=1; started=1; next }
      else if (in_fm) { in_fm=0; next }
    }
    !in_fm && started { print }
  ' "$template")"

  desc="${DESCRIPTIONS[$cmd]:-Spec-kit workflow command: $cmd}"
  title="$(echo "$cmd" | sed 's/./\U&/')"

  {
    echo "---"
    echo "name: $skill_name"
    echo "description: $desc"
    echo "compatibility: Requires spec-kit project structure with .specify/ directory"
    echo "metadata:"
    echo "  author: github-spec-kit"
    echo "  source: templates/commands/$cmd.md"
    echo "---"
    echo
    echo "# Speckit $title Skill"
    echo
    echo "$body"
  } > "$skill_dir/SKILL.md"

  count=$((count + 1))
done

echo "Generated $count speckit-* skills in $SHARED_SKILLS_DIR"
