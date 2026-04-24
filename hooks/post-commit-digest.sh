#!/usr/bin/env bash
# post-commit-digest.sh — PostToolUse hook: triggered after git commit
# Directly extracts knowledge from buffer and writes increment.
# Does NOT rely on agent to execute instructions.

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

# Check if it was successful
TOOL_RESULT=$(echo "$INPUT" | jq -r '.tool_result // empty' 2>/dev/null || echo "")
if echo "$TOOL_RESULT" | grep -qi "error\\|failed\\|nothing to commit"; then
  exit 0
fi

WORK_DIR="${CLAUDE_WORKING_DIRECTORY:-$(pwd)}"
BUFFER_FILE="$WORK_DIR/.ai-context/buffer.md"
INCREMENT_DIR="$WORK_DIR/.ai-context/increments"

if [ ! -f "$BUFFER_FILE" ]; then
  exit 0
fi

# Count knowledge entries in buffer
ENTRIES=$(grep -c '^\[round:' "$BUFFER_FILE" 2>/dev/null || echo "0")
ENTRIES=$(echo "$ENTRIES" | head -1 | tr -d '[:space:]')

if [ "$ENTRIES" -eq 0 ]; then
  exit 0
fi

# Lock the buffer
if ! grep -q '^\[LOCKED:' "$BUFFER_FILE" 2>/dev/null; then
  LOCK_LINE="[LOCKED:commit at $(date '+%Y-%m-%d %H:%M:%S')]"
  sed -i '' "1s/^/${LOCK_LINE}\n/" "$BUFFER_FILE" 2>/dev/null || true
fi

# Generate increment file
INCREMENT_FILE="$INCREMENT_DIR/$(date '+%Y-%m-%d')_commit-$(date '+%H%M%S').md"

# Extract commit message from the command
COMMIT_MSG=$(echo "$COMMAND" | sed -n 's/.*-m["'"'"']*\([^"'"'"']*\).*/\1/p' | head -1)
COMMIT_MSG="${COMMIT_MSG:-commit}"

# Write increment file
cat > "$INCREMENT_FILE" << INCREMENT
# $(date '+%Y-%m-%d') commit-knowledge

## Meta
- author: auto-extracted
- timestamp: $(date '+%Y-%m-%d %H:%M:%S')
- trigger: post-commit-hook
- confidence: medium

## Affected Files
- See buffer entries for affected files

## Changes
- Commit: ${COMMIT_MSG}

## Knowledge Extracted from Buffer

$(grep -A3 '^\[round:' "$BUFFER_FILE")

## Evidence
- 来源: 开发对话，commit 时自动提取
- 验证状态: unverified
INCREMENT

# Clear buffer (keep header, remove entries and lock)
cat > "$BUFFER_FILE" << 'BUFFER'
# Buffer — AI Context knowledge accumulator

> This file is managed automatically by the AI Context framework.
> Do not edit manually. Cleared after each /lore-digest flush.
BUFFER

# Stage increment
cd "$WORK_DIR"
git add "$INCREMENT_FILE" "$BUFFER_FILE" 2>/dev/null || true

# Output summary for agent to see
echo "[AI-CONTEXT] Post-commit knowledge extraction complete:"
echo "  - Extracted ${ENTRIES} knowledge entries"
echo "  - Increment: $(basename "$INCREMENT_FILE")"
echo "  - Run: git commit --amend --no-edit  (to include increment in commit)"
