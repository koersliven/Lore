#!/usr/bin/env bash
# snapshot-guard.sh — PreToolUse hook: prevents direct edits to snapshot and module knowledge files
# These files should only be modified through /lore-evolve compilation.

set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

case "$TOOL_NAME" in
  Edit|Write|WriteFile|NotebookEdit)
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // .tool_input.notebook_path // empty' 2>/dev/null || echo "")
    if echo "$FILE_PATH" | grep -q '\.ai-context/snapshot\.md'; then
      echo "BLOCKED: .ai-context/snapshot.md should only be modified through /lore-evolve compilation, not directly. Use /lore-evolve to recompile the snapshot from increments. If you need to correct an error, fix it in the source increment file or /lore-init data, then re-run /lore-evolve."
      exit 2
    fi
    if echo "$FILE_PATH" | grep -qE '\.ai-context/modules/[^/]+/knowledge\.md'; then
      MODULE_NAME=$(echo "$FILE_PATH" | sed 's|.*/modules/\([^/]*\)/knowledge.*|\1|')
      echo "BLOCKED: .ai-context/modules/${MODULE_NAME}/knowledge.md should only be modified through /lore-evolve compilation, not directly. Use /lore-evolve to recompile module knowledge from increments."
      exit 2
    fi
    ;;
esac

exit 0
