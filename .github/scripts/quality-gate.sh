#!/usr/bin/env bash
# Runs every check quality-gate.yaml runs, so a promotion without CI runs the same gate by hand.
# Usage: quality-gate.sh [base-ref] [--strict]   base defaults to origin/dev; --strict fails a skip.
set -uo pipefail

cd "$(dirname "$0")/../.." || exit 2

BASE="origin/dev"
failed=0
skipped=""

# On a runner a skipped check is a hole in the gate, so it fails instead.
STRICT=0
[ "${CI:-}" = "true" ] && STRICT=1
for arg in "$@"; do
  case "$arg" in
  --strict) STRICT=1 ;;
  -*) echo "quality-gate: unknown option $arg" >&2 && exit 2 ;;
  *) BASE="$arg" ;;
  esac
done

step() {
  printf '\n\033[1m── %s\033[0m\n' "$1"
}

run() {
  local name="$1"
  shift
  step "$name"
  if ! "$@"; then
    echo "::error::$name failed"
    failed=$((failed + 1))
  fi
}

# A check that cannot run here is recorded, never silently passed — the summary
# at the end is what tells you the gate was partial.
skip() {
  skipped="${skipped}"$'\n'"  $1 — $2"
}

git rev-parse --verify "$BASE" >/dev/null 2>&1 || {
  echo "::error::base ref '$BASE' not found; run: git fetch origin"
  exit 1
}

# ── The same checks scripts/check/gates.list runs before each commit ──
run "Install Dependencies" bun install --frozen-lockfile
run "Format & Lint" bun run fl:ci
run "Type Check" bun run type-check
run "Dead Code Check" bun run check:dead-code
run "No Double Assertion" bash scripts/check/double-assertion.sh
run "Folder Shape Check" node scripts/check/folder-shape.mjs
run "Comment Style Check" bun run .github/scripts/check-comment-style.ts
run "Comment Block Length Check" bash .github/scripts/check-comment-blocks.sh
# A stale copy under .claude/commands/ still reads as valid, and INDEX.md is how an agent finds the
# commands at all. The script skips itself on prod, where the strip removed the source.
run "Workflow Mirror Drift Check" bash scripts/sync/workflows.sh --check
# Rule citations, the always-loaded budget, hook wiring and MCP pins; skips without .claude/.
run "AI Config Check" bash scripts/check/ai-config.sh
# Proves the MCP pin rule above both ways, in temp repos; it never reads this one.
run "AI Config Probes" bash scripts/check/ai-config-probes.sh
# What each Claude Code hook must block and let through; skips on a branch without .claude/.
run "Hook Probes" bash scripts/check/hook-probes.sh

# ── Checks only CI runs ──
run "Security Audit" bun run scripts/check/audit.ts

# docs:generate inserts _TODO_ / "TODO: Add usage example" when source JSDoc is incomplete.
step "Check Generated Doc TODOs"
TODOS=$(git diff --name-only "$BASE"...HEAD -- 'content/technical/**/*.mdx' |
  xargs -r grep -lE '_TODO_|TODO: Add usage example' 2>/dev/null)
if [ -n "$TODOS" ]; then
  printf '%s\n' "$TODOS"
  echo "::warning::These generated pages still hold TODO placeholders; fill them in before merging."
else
  echo "Clean"
fi

# ── Security scans over the diff against BASE ──
# scan <name> <pattern> <pathspec>...: fails when the branch's diff of those paths matches.
scan() {
  local name="$1" pattern="$2"
  shift 2
  step "$name"
  if git diff "$BASE"...HEAD -- "$@" | grep -Eq "$pattern"; then
    echo "::error::$name found a match"
    git diff "$BASE"...HEAD -- "$@" | grep -En "$pattern" | head -20
    failed=$((failed + 1))
  else
    echo "Clean"
  fi
}

# Every hand-written JavaScript and TypeScript file: app/, components/, scripts/ and the root
# configs. content/ is prose that may quote these patterns; the review checklist reads its MDX.
CODE=('*.js' '*.jsx' '*.mjs' '*.cjs' '*.ts' '*.tsx' '*.mts' '*.cts' ':(exclude)content/')

step "Check .env Not Committed"
if git diff "$BASE"...HEAD --name-only | grep -E "^\.env(\.|$)" | grep -qvE "^\.env(\.[a-z]+)?\.example$"; then
  echo "::error::.env file committed"
  failed=$((failed + 1))
else
  echo "Clean"
fi

scan "Dangerous JS APIs Check" '\beval\s*\(|new\s+Function\s*\(' "${CODE[@]}"
scan "Unsafe React Patterns Check" 'dangerouslySetInnerHTML|__html' "${CODE[@]}"
scan "URL Scheme Injection Check" '(javascript:|data:text/html|data:application/)' "${CODE[@]}"

step "Secret Scan (gitleaks)"
GITLEAKS_VERSION=8.30.1
GITLEAKS_SHA256=551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb
GL=""

# The pinned build and checksum, exactly as CI fetches them. Any other binary is
# a different scan, so elsewhere it falls back to whatever is installed.
if [ "$(uname -s)" = "Linux" ] && [ "$(uname -m)" = "x86_64" ]; then
  GL_URL="https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz"
  if curl -sSfL -o gitleaks.tar.gz "$GL_URL" &&
    echo "${GITLEAKS_SHA256}  gitleaks.tar.gz" | sha256sum -c - &&
    tar xzf gitleaks.tar.gz gitleaks; then
    GL=./gitleaks
  else
    echo "::error::could not fetch or verify the pinned gitleaks build"
    failed=$((failed + 1))
  fi
elif command -v gitleaks >/dev/null 2>&1; then
  GL=gitleaks
fi

if [ -n "$GL" ]; then
  if ! "$GL" git . --no-banner --redact --config .gitleaks.toml; then
    echo "::error::gitleaks found findings"
    failed=$((failed + 1))
  fi
elif [ "$failed" -eq 0 ]; then
  echo "gitleaks not installed — brew install gitleaks"
  skip "Secret Scan (gitleaks)" "no pinned build for $(uname -sm), none on PATH"
fi
rm -f gitleaks gitleaks.tar.gz

# SkillSpector scans skills, commands, subagents and hooks, and runs only when one of them changed.
step "Skill Security Scan"
SKILL_PATHS=(.agents/skills .claude/skills .claude/commands .claude/agents .claude/hooks
  _workflow-source .skillspector-baseline.yaml scripts/check/skills.sh)
if [ ! -d .claude ]; then
  echo ".claude/ not present on this branch - skipping"
elif git diff --quiet "$BASE"...HEAD -- "${SKILL_PATHS[@]}"; then
  echo "No skill, command, subagent or hook changed - skipping"
else
  # A runner installs the commit skills.sh pins; on a laptop that stays your call.
  ref=$(sed -n 's/^PINNED_REF="\([0-9a-f]\{40\}\)"$/\1/p' scripts/check/skills.sh)
  if ! command -v skillspector >/dev/null 2>&1 && [ "${CI:-}" = "true" ] && [ -n "$ref" ]; then
    uv tool install --quiet --python 3.12 "git+https://github.com/NVIDIA/skillspector.git@${ref}" &&
      PATH="$(uv tool dir --bin):$PATH"
  fi
  if command -v skillspector >/dev/null 2>&1; then
    bash scripts/check/skills.sh --changed "$BASE" || failed=$((failed + 1))
  else
    echo "SkillSpector is not installed; bash scripts/check/skills.sh prints the install command"
    skip "Skill Security Scan" "SkillSpector not installed"
  fi
fi

run "Production Build" bun run build

# Both dirs: out/ is what ships, and .next/ is what it is copied from.
step "Check Source Maps Leak"
MAPS=$(find .next/static out/_next/static -name "*.map" 2>/dev/null | head -5)
if [ -n "$MAPS" ]; then
  echo "::error::Source maps leaked in client bundle"
  echo "$MAPS"
  failed=$((failed + 1))
else
  echo "Clean"
fi

# ── Summary ──
printf '\n\033[1m── Summary\033[0m\n'
if [ -n "$skipped" ]; then
  printf 'Checks that did NOT run:%s\n\n' "$skipped"
fi

if [ "$failed" -gt 0 ]; then
  printf '::error::%d check(s) failed.\n' "$failed"
  exit 1
fi

if [ -n "$skipped" ]; then
  if [ "$STRICT" -eq 1 ]; then
    echo "::error::gate was partial and strict mode is on."
    exit 1
  fi
  echo "All checks that ran passed, but the gate was PARTIAL — see the list above."
  exit 0
fi

echo "Full gate passed."
