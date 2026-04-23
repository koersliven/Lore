#!/usr/bin/env bash
# pre-edit-guard.sh — PreToolUse hook: warns when editing files with known knowledge
# If the file being edited has knowledge associations in .ai-context/, shows them.

set -euo pipefail

WORK_DIR="${CLAUDE_WORKING_DIRECTORY:-$(pwd)}"
CONTEXT_DIR="$WORK_DIR/.ai-context"
SNAPSHOT="$CONTEXT_DIR/snapshot.md"

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
    # Match by both relative path and basename (knowledge may reference just the filename)
    BASENAME=$(basename "$FILE_PATH")
    FOUND=""

    if [ -f "$SNAPSHOT" ]; then
      FOUND=$(grep -B2 -A5 -E "(${REL_PATH}|${BASENAME})" "$SNAPSHOT" 2>/dev/null || true)
    fi

    # Also search increments (not archived)
    if [ -d "$CONTEXT_DIR/increments" ]; then
      for f in "$CONTEXT_DIR/increments"/*.md; do
        [ -f "$f" ] || continue
        if grep -q -E "(${REL_PATH}|${BASENAME})" "$f" 2>/dev/null; then
          INC_CONTEXT=$(grep -B2 -A5 -E "(${REL_PATH}|${BASENAME})" "$f" 2>/dev/null || true)
          FOUND="$FOUND
--- from $(basename "$f"):
$INC_CONTEXT"
        fi
      done
    fi

    # If knowledge found, inject warning
    if [ -n "$FOUND" ]; then
      cat <<INJECT
[AI-CONTEXT ⚠️ PRE-EDIT GUARD] You are about to edit \`${REL_PATH}\`.

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
