#!/usr/bin/env bash
# stop-flush.sh — Stop hook: detects if buffer needs flushing or evolve needed
# Triggered after every agent turn completion.
# Checks: buffer entries, unarchived increments, and time elapsed.

set -euo pipefail

WORK_DIR="${CLAUDE_WORKING_DIRECTORY:-$(pwd)}"
BUFFER_FILE="$WORK_DIR/.ai-context/buffer.md"
INCREMENT_DIR="$WORK_DIR/.ai-context/increments"
LAST_FLUSH_FILE="$WORK_DIR/.ai-context/.last-flush-time"

# Buffer thresholds
FLUSH_THRESHOLD_SOFT=5    # Suggest flush
FLUSH_THRESHOLD_HARD=15   # Force flush
COMPACT_THRESHOLD=8       # Trigger /lore-compact

# Evolve thresholds (unarchived increments)
EVOLVE_THRESHOLD_SOFT=3   # Suggest evolve
EVOLVE_THRESHOLD_HARD=5   # Force evolve

# Time threshold (minutes)
TIME_THRESHOLD_MINUTES=20 # Auto flush after 20 minutes

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
  echo "[AI-CONTEXT] ${UNARCHIVED_INCREMENTS} unarchived increments detected (hard limit: ${EVOLVE_THRESHOLD_HARD}). Execute /lore-evolve NOW to compile snapshot and archive old increments. This is urgent — snapshot is stale. Do not ask the user for confirmation."
  exit 0
fi

if [ "$UNARCHIVED_INCREMENTS" -ge "$EVOLVE_THRESHOLD_SOFT" ]; then
  echo "[AI-CONTEXT] ${UNARCHIVED_INCREMENTS} unarchived increments accumulated. Execute /lore-evolve to compile snapshot and archive. This is automated — do not ask the user for confirmation."
  exit 0
fi

# Check buffer (if no evolve needed)
if [ ! -f "$BUFFER_FILE" ]; then
  exit 0
fi

ENTRIES=$(grep -c '^\[round:' "$BUFFER_FILE" 2>/dev/null || echo "0")
ENTRIES=$(echo "$ENTRIES" | head -1 | tr -d '[:space:]')

# Check time elapsed since last flush
TIME_TRIGGERED=false
if [ "$ENTRIES" -gt 0 ]; then
  CURRENT_TIME=$(date +%s)

  if [ -f "$LAST_FLUSH_FILE" ]; then
    LAST_FLUSH=$(cat "$LAST_FLUSH_FILE" 2>/dev/null || echo "0")
    ELAPSED_SECONDS=$((CURRENT_TIME - LAST_FLUSH))
    ELAPSED_MINUTES=$((ELAPSED_SECONDS / 60))

    if [ "$ELAPSED_MINUTES" -ge "$TIME_THRESHOLD_MINUTES" ]; then
      TIME_TRIGGERED=true
    fi
  else
    # No last flush record, create one
    echo "$CURRENT_TIME" > "$LAST_FLUSH_FILE"
  fi
fi

# Priority: hard > compact > time > soft
if [ "$ENTRIES" -ge "$FLUSH_THRESHOLD_HARD" ]; then
  echo "[AI-CONTEXT] Buffer has ${ENTRIES} knowledge entries (hard limit: ${FLUSH_THRESHOLD_HARD}). Execute /lore-compact to compress and /lore-digest to flush buffer into increments. This is urgent — knowledge will be lost if session ends. Do not ask the user for confirmation, just execute /lore-compact and /lore-digest."
  exit 0
fi

if [ "$ENTRIES" -ge "$COMPACT_THRESHOLD" ]; then
  echo "[AI-CONTEXT] Buffer has ${ENTRIES} knowledge entries accumulated. Execute /lore-compact to compress knowledge, then /lore-digest to flush. This is automated — do not ask the user for confirmation."
  exit 0
fi

if [ "$TIME_TRIGGERED" = true ]; then
  echo "[AI-CONTEXT] ${TIME_THRESHOLD_MINUTES} minutes elapsed since last flush. Buffer has ${ENTRIES} entries. Execute /lore-digest to flush into increments. This is automated — do not ask the user for confirmation."
  exit 0
fi

if [ "$ENTRIES" -ge "$FLUSH_THRESHOLD_SOFT" ]; then
  echo "[AI-CONTEXT] Buffer has ${ENTRIES} knowledge entries accumulated. Execute /lore-digest to flush into increments and clear the buffer. This is automated — do not ask the user for confirmation."
  exit 0
fi
