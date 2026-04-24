#!/usr/bin/env bash
# post-commit-digest.sh — PostToolUse hook: triggered after git commit
# Forces agent to extract and flush knowledge after commit.

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
if echo "$TOOL_RESULT" | grep -qi "error\\|failed\\|nothing to commit"; then
  exit 0
fi

# Lock the buffer to prevent double-flush from stop hook
WORK_DIR="${CLAUDE_WORKING_DIRECTORY:-$(pwd)}"
BUFFER_FILE="$WORK_DIR/.ai-context/buffer.md"
INCREMENT_DIR="$WORK_DIR/.ai-context/increments"

if [ -f "$BUFFER_FILE" ]; then
  # Insert lock marker at the top if not already locked
  if ! grep -q '^\[LOCKED:' "$BUFFER_FILE" 2>/dev/null; then
    LOCK_LINE="[LOCKED:commit at $(date '+%Y-%m-%d %H:%M:%S')]"
    sed -i '' "1s/^/${LOCK_LINE}\n/" "$BUFFER_FILE" 2>/dev/null || true
  fi
fi

# Count knowledge entries in buffer
ENTRIES=$(grep -c '^\[round:' "$BUFFER_FILE" 2>/dev/null || echo "0")

if [ "$ENTRIES" -gt 0 ]; then
  # Output as a user-like message that agent must act on
  # Using special format that signals mandatory action
  cat <<INJECT
[HOOK:POST-COMMIT] Knowledge extraction required. Buffer has ${ENTRIES} entries.

IMMEDIATE ACTION REQUIRED (do not ask for confirmation):

1. Read .ai-context/buffer.md to see all knowledge entries
2. Create increment file: .ai-context/increments/$(date '+%Y-%m-%d')_commit-$(date '+%H%M%S').md
3. Write structured knowledge to increment (use /digest format)
4. Clear buffer.md (remove all [round:] entries and LOCKED marker)
5. Run: git add .ai-context/increments/ .ai-context/buffer.md
6. Run: git commit --amend --no-edit

This is mandatory. Execute now.
INJECT
fi
