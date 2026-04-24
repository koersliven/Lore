#!/usr/bin/env bash
# stop-flush.sh — Stop hook: detects if buffer needs flushing
# Triggered after every agent turn completion.
# Threshold is based on knowledge entry count, not dialogue rounds.

set -euo pipefail

WORK_DIR="${CLAUDE_WORKING_DIRECTORY:-$(pwd)}"
BUFFER_FILE="$WORK_DIR/.ai-context/buffer.md"
FLUSH_THRESHOLD_SOFT=3    # Suggest flush — enough entries for meaningful context
FLUSH_THRESHOLD_HARD=10   # Force flush — risk of knowledge loss

if [ ! -f "$BUFFER_FILE" ]; then
  exit 0
fi

# Count knowledge entries in buffer (each [round: N] line is one entry)
ENTRIES=$(grep -c '^\[round:' "$BUFFER_FILE" || true)
ENTRIES=${ENTRIES:-0}
ENTRIES=$(echo "$ENTRIES" | tr -d '[:space:]')

# Check if buffer is locked by another process (commit hook)
if grep -q '^\[LOCKED:' "$BUFFER_FILE" 2>/dev/null; then
  exit 0
fi

if [ "$ENTRIES" -ge "$FLUSH_THRESHOLD_HARD" ]; then
  echo "[AI-CONTEXT] Buffer has ${ENTRIES} knowledge entries (hard limit: ${FLUSH_THRESHOLD_HARD}). Execute /digest NOW to flush buffer into increments. This is urgent — knowledge will be lost if session ends. Do not ask the user for confirmation, just execute /digest."
  exit 0
fi

if [ "$ENTRIES" -ge "$FLUSH_THRESHOLD_SOFT" ]; then
  echo "[AI-CONTEXT] Buffer has ${ENTRIES} knowledge entries accumulated. Execute /digest to flush into increments and clear the buffer. This is automated — do not ask the user for confirmation."
  exit 0
fi
