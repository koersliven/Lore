#!/usr/bin/env bash
# pre-edit-guard.sh — PreToolUse hook: warns when editing files with known knowledge
# If the file being edited has knowledge associations in .ai-context/ (global or per-module), shows them.

set -euo pipefail

WORK_DIR="${CLAUDE_WORKING_DIRECTORY:-$(pwd)}"
CONTEXT_DIR="$WORK_DIR/.ai-context"
SNAPSHOT="$CONTEXT_DIR/snapshot.md"
MODULES_DIR="$CONTEXT_DIR/modules"

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

case "$TOOL_NAME" in
  Edit|Write|WriteFile|NotebookEdit)
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // .tool_input.notebook_path // empty' 2>/dev/null || echo "")

    # Skip if no file path or not editing real files
    if [ -z "$FILE_PATH" ]; then
      exit 0
    fi

    # Get relative path from project root for matching (macOS compatible)
    REL_PATH="${FILE_PATH#$WORK_DIR/}"

    # Skip .ai-context/ internal files (they have their own guard)
    if echo "$FILE_PATH" | grep -q '.ai-context/'; then
      exit 0
    fi

    # Search snapshot and increments for mentions of this file
    BASENAME=$(basename "$FILE_PATH")
    FOUND=""

    # Search global snapshot
    if [ -f "$SNAPSHOT" ]; then
      FOUND=$(grep -B2 -A5 -E "(${REL_PATH}|${BASENAME})" "$SNAPSHOT" 2>/dev/null || true)
    fi

    # Search global increments (not archived)
    if [ -d "$CONTEXT_DIR/increments" ]; then
      for f in "$CONTEXT_DIR/increments"/*.md; do
        [ -f "$f" ] || continue
        if grep -q -E "(${REL_PATH}|${BASENAME})" "$f" 2>/dev/null; then
          INC_CONTEXT=$(grep -B2 -A5 -E "(${REL_PATH}|${BASENAME})" "$f" 2>/dev/null || true)
          FOUND="$FOUND
--- from increments/$(basename "$f"):
$INC_CONTEXT"
        fi
      done
    fi

    # Search per-module knowledge files
    if [ -d "$MODULES_DIR" ]; then
      for module_dir in "$MODULES_DIR"/*/; do
        [ -d "$module_dir" ] || continue
        knowledge_file="$module_dir/knowledge.md"
        [ -f "$knowledge_file" ] || continue
        mod_name=$(basename "$module_dir")
        if grep -q -E "(${REL_PATH}|${BASENAME})" "$knowledge_file" 2>/dev/null; then
          MOD_CONTEXT=$(grep -B2 -A5 -E "(${REL_PATH}|${BASENAME})" "$knowledge_file" 2>/dev/null || true)
          FOUND="$FOUND
--- from modules/${mod_name}/knowledge.md:
$MOD_CONTEXT"
        fi
        # Also search module increments
        if [ -d "$module_dir/increments" ]; then
          for f in "$module_dir/increments"/*.md; do
            [ -f "$f" ] || continue
            if grep -q -E "(${REL_PATH}|${BASENAME})" "$f" 2>/dev/null; then
              MOD_INC=$(grep -B2 -A5 -E "(${REL_PATH}|${BASENAME})" "$f" 2>/dev/null || true)
              FOUND="$FOUND
--- from modules/${mod_name}/increments/$(basename "$f"):
$MOD_INC"
            fi
          done
        fi
      done
    fi

    # If knowledge found, inject warning
    if [ -n "$FOUND" ]; then
      cat <<INJECT
[AI-CONTEXT PRE-EDIT GUARD] You are about to edit \`${REL_PATH}\`.

This file has associated knowledge in .ai-context/:

$FOUND

Before proceeding:
1. Review the existing knowledge — understand WHY these decisions/constraints exist
2. If your change contradicts any of them, explain why in your response
3. Your explanation will be automatically recorded as a new DECISION

If you are modifying a known constraint, the system will record your reasoning.
INJECT
    fi
    ;;
esac

exit 0
