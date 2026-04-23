#!/usr/bin/env bash
# post-commit-digest.sh — PostToolUse hook: triggered after git commit
# Injects knowledge extraction instruction into the current conversation.

set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")

if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

if ! echo "$COMMAND" | grep -q "git commit"; then
  exit 0
fi

# Check if it was successful (heuristic: look for success indicators in result)
TOOL_RESULT=$(echo "$INPUT" | jq -r '.tool_result // empty' 2>/dev/null || echo "")
if echo "$TOOL_RESULT" | grep -qi "error\|failed\|nothing to commit"; then
  exit 0
fi

# Lock the buffer to prevent double-flush from stop hook
WORK_DIR="${CLAUDE_WORKING_DIRECTORY:-$(pwd)}"
BUFFER_FILE="$WORK_DIR/.ai-context/buffer.md"
if [ -f "$BUFFER_FILE" ]; then
  # Insert lock marker at the top if not already locked
  if ! grep -q '^\[LOCKED:' "$BUFFER_FILE" 2>/dev/null; then
    LOCK_LINE="[LOCKED:commit at $(date '+%Y-%m-%d %H:%M:%S')]"
    sed -i '' "1s/^/${LOCK_LINE}\n/" "$BUFFER_FILE" 2>/dev/null || true
  fi
fi

cat <<'INJECT'
[AI-CONTEXT] Git commit completed. Execute post-commit knowledge extraction:

1. Review this session's discussion — what decisions were made, what WHYs were revealed, what constraints emerged?
2. If there is knowledge not yet in .ai-context/buffer.md, append it first
3. Execute /digest to flush all buffered knowledge into .ai-context/increments/
4. Add the new increment file(s) and amend the current commit:
   git add .ai-context/increments/
   git commit --amend --no-edit
5. If .ai-context/buffer.md has a [LOCKED:commit] marker, remove it after flush
6. This is automated — do not ask the user for confirmation.
INJECT
