#!/usr/bin/env bash
# stop-flush.sh — Stop hook: detects if buffer needs flushing or evolve needed
# Triggered after every agent turn completion.
# Checks both buffer entries and unarchived increments.

set -euo pipefail

WORK_DIR="${CLAUDE_WORKING_DIRECTORY:-$(pwd)}"
BUFFER_FILE="$WORK_DIR/.ai-context/buffer.md"
INCREMENT_DIR="$WORK_DIR/.ai-context/increments"

# Buffer thresholds
FLUSH_THRESHOLD_SOFT=5    # Suggest flush
FLUSH_THRESHOLD_HARD=15   # Force flush
COMPACT_THRESHOLD=8       # Trigger /compact

# Evolve thresholds (unarchived increments)
EVOLVE_THRESHOLD_SOFT=3   # Suggest evolve
EVOLVE_THRESHOLD_HARD=5   # Force evolve

# Check buffer lock first
if [ -f "$BUFFER_FILE" ] && grep -q '^\[LOCKED:' "$BUFFER_FILE" 2>/dev/null; then
  exit 0
fi

# Count unarchived increments (exclude archive/ and .gitkeep)
UNARCHIVED_INCREMENTS=0
if [ -d "$INCREMENT_DIR" ]; then
  for f in "$INCREMENT_DIR"/*.md; do
    [ -f "$f" ] && UNARCHIVED_INCREMENTS=$((UNARCHIVED_INCREMENTS + 1))
  done
fi

# Check evolve threshold (higher priority than buffer)
if [ "$UNARCHIVED_INCREMENTS" -ge "$EVOLVE_THRESHOLD_HARD" ]; then
  echo "[AI-CONTEXT] ${UNARCHIVED_INCREMENTS} unarchived increments detected (hard limit: ${EVOLVE_THRESHOLD_HARD}). Execute /evolve NOW to compile snapshot and archive old increments. This is urgent — snapshot is stale. Do not ask the user for confirmation."
  exit 0
fi

if [ "$UNARCHIVED_INCREMENTS" -ge "$EVOLVE_THRESHOLD_SOFT" ]; then
  echo "[AI-CONTEXT] ${UNARCHIVED_INCREMENTS} unarchived increments accumulated. Execute /evolve to compile snapshot and archive. This is automated — do not ask the user for confirmation."
  exit 0
fi

# Check buffer (if no evolve needed)
if [ ! -f "$BUFFER_FILE" ]; then
  exit 0
fi

ENTRIES=$(grep -c '^\[round:' "$BUFFER_FILE" 2>/dev/null || echo "0")
ENTRIES=$(echo "$ENTRIES" | head -1 | tr -d '[:space:]')

if [ "$ENTRIES" -ge "$FLUSH_THRESHOLD_HARD" ]; then
  echo "[AI-CONTEXT] Buffer has ${ENTRIES} knowledge entries (hard limit: ${FLUSH_THRESHOLD_HARD}). Execute /compact to compress and /digest to flush buffer into increments. This is urgent — knowledge will be lost if session ends. Do not ask the user for confirmation, just execute /compact and /digest."
  exit 0
fi

if [ "$ENTRIES" -ge "$COMPACT_THRESHOLD" ]; then
  echo "[AI-CONTEXT] Buffer has ${ENTRIES} knowledge entries accumulated. Execute /compact to compress knowledge, then /digest to flush. This is automated — do not ask the user for confirmation."
  exit 0
fi

if [ "$ENTRIES" -ge "$FLUSH_THRESHOLD_SOFT" ]; then
  echo "[AI-CONTEXT] Buffer has ${ENTRIES} knowledge entries accumulated. Execute /digest to flush into increments and clear the buffer. This is automated — do not ask the user for confirmation."
  exit 0
fi
