#!/usr/bin/env bash
# session-end-flush.sh — SessionEnd hook: emergency flush on session close
# Ensures no knowledge is lost when the user ends the session.

set -euo pipefail

WORK_DIR="${CLAUDE_WORKING_DIRECTORY:-$(pwd)}"
BUFFER_FILE="$WORK_DIR/.ai-context/buffer.md"

if [ ! -f "$BUFFER_FILE" ]; then
  exit 0
fi

# Check if buffer has content beyond lock markers
CONTENT_LINES=$(grep -cv '^\[LOCKED:\|^\[round:\|^$' "$BUFFER_FILE" 2>/dev/null || echo "0")

if [ "$CONTENT_LINES" -gt 0 ]; then
  echo "[AI-CONTEXT] Session is ending with ${CONTENT_LINES} lines of unbaked knowledge in buffer. Before ending, execute /digest to flush the buffer into increments. If you cannot flush, write the raw buffer to .ai-context/increments/emergency-$(date '+%Y%m%d-%H%M%S').md. Do not let this knowledge be lost."
fi
