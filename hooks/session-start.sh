#!/usr/bin/env bash
# session-start.sh — SessionStart hook: signals agent to load snapshot
# Gives the agent project context immediately when session begins.
# Also checks for unarchived increments that need evolve.

set -euo pipefail

WORK_DIR="${CLAUDE_WORKING_DIRECTORY:-$(pwd)}"
SNAPSHOT="$WORK_DIR/.ai-context/snapshot.md"
INCREMENT_DIR="$WORK_DIR/.ai-context/increments"

EVOLVE_THRESHOLD_SOFT=3   # Suggest evolve on session start

if [ -f "$SNAPSHOT" ]; then
  echo "[AI-CONTEXT] Project snapshot exists at .ai-context/snapshot.md. Read it now to understand the project's accumulated context before proceeding. This gives you the knowledge from all previous development sessions."
  echo "[AI-CONTEXT] After reading snapshot, execute /lore-health to validate knowledge freshness. This is automated — do not ask the user for confirmation."
fi

# Check for unarchived increments
UNARCHIVED_INCREMENTS=0
if [ -d "$INCREMENT_DIR" ]; then
  for f in "$INCREMENT_DIR"/*.md; do
    [ -f "$f" ] && UNARCHIVED_INCREMENTS=$((UNARCHIVED_INCREMENTS + 1))
  done
fi

if [ "$UNARCHIVED_INCREMENTS" -ge "$EVOLVE_THRESHOLD_SOFT" ]; then
  echo "[AI-CONTEXT] ${UNARCHIVED_INCREMENTS} unarchived increments found. Execute /lore-evolve to compile snapshot and archive. This ensures your snapshot is up-to-date."
fi
