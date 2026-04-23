#!/usr/bin/env bash
# snapshot-guard.sh — PreToolUse hook: prevents direct edits to snapshot.md
# Snapshot should only be modified through /evolve compilation.

set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

case "$TOOL_NAME" in
  Edit|Write|WriteFile|NotebookEdit)
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // .tool_input.notebook_path // empty' 2>/dev/null || echo "")
    if echo "$FILE_PATH" | grep -q '\.ai-context/snapshot\.md'; then
      echo "BLOCKED: .ai-context/snapshot.md should only be modified through /evolve compilation, not directly. Use /evolve to recompile the snapshot from increments. If you need to correct an error, fix it in the source increment file or /init-context data, then re-run /evolve."
      exit 2
    fi
    ;;
esac

exit 0
