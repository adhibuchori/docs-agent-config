#!/usr/bin/env bash
# Blocks dangerous commands before execution.

COMMAND="${CLAUDE_TOOL_INPUT_COMMAND:-}"

# Block rm -rf on protected paths
if echo "$COMMAND" | grep -qE 'rm\s+-rf'; then
  if echo "$COMMAND" | grep -qE '(content/|app/|components/|\.claude/|CLAUDE\.md|/\s*$|\.\s*$|\.\.\s*$|\*)'; then
    echo "[safety] BLOCKED: rm -rf on protected path: $COMMAND" >&2
    exit 1
  fi
fi

# Block git push to main/master
if echo "$COMMAND" | grep -qE 'git\s+push\s+origin\s+(main|master)'; then
  echo "[safety] BLOCKED: git push to main/master is not allowed. Use a feature branch." >&2
  exit 1
fi

# Block shell redirection writes to .env files
if echo "$COMMAND" | grep -qE '>\s*\.env'; then
  echo "[safety] BLOCKED: writing to .env files via shell redirection." >&2
  exit 1
fi

exit 0
