#!/usr/bin/env bash
# session-start.sh — SessionStart hook: signals agent to load snapshot
# Gives the agent project context immediately when session begins.
# Also checks for unarchived increments (global and per-module) that need evolve.

set -euo pipefail

WORK_DIR="${CLAUDE_WORKING_DIRECTORY:-$(pwd)}"
SNAPSHOT="$WORK_DIR/.ai-context/snapshot.md"
INCREMENT_DIR="$WORK_DIR/.ai-context/increments"
MODULES_DIR="$WORK_DIR/.ai-context/modules"
MODULE_INDEX="$MODULES_DIR/_index.md"

EVOLVE_THRESHOLD_SOFT=3   # Suggest evolve on session start

if [ -f "$SNAPSHOT" ]; then
  echo "[AI-CONTEXT] Project snapshot exists at .ai-context/snapshot.md. Read it now to understand the project's accumulated context before proceeding. This gives you the knowledge from all previous development sessions."
  echo "[AI-CONTEXT] After reading snapshot, execute /lore-health to validate knowledge freshness. This is automated — do not ask the user for confirmation."
fi

# Check for modular knowledge base
if [ -f "$MODULE_INDEX" ]; then
  echo "[AI-CONTEXT] Modular knowledge base detected at .ai-context/modules/. Module registry:"
  grep -E '^\| [a-z]' "$MODULE_INDEX" 2>/dev/null | head -20 || true
  echo "[AI-CONTEXT] You can load specific module knowledge by reading modules/<name>/knowledge.md for the module you are working on."
fi

# Check for unarchived increments (global)
UNARCHIVED_INCREMENTS=0
if [ -d "$INCREMENT_DIR" ]; then
  for f in "$INCREMENT_DIR"/*.md; do
    [ -f "$f" ] && UNARCHIVED_INCREMENTS=$((UNARCHIVED_INCREMENTS + 1))
  done
fi

if [ "$UNARCHIVED_INCREMENTS" -ge "$EVOLVE_THRESHOLD_SOFT" ]; then
  echo "[AI-CONTEXT] ${UNARCHIVED_INCREMENTS} unarchived increments found. Execute /lore-evolve to compile snapshot and archive."
fi

# Check for unarchived increments (per-module)
if [ -d "$MODULES_DIR" ]; then
  for module_dir in "$MODULES_DIR"/*/; do
    [ -d "$module_dir" ] || continue
    mod_incr_dir="$module_dir/increments"
    [ -d "$mod_incr_dir" ] || continue
    mod_unarchived=0
    for f in "$mod_incr_dir"/*.md; do
      [ -f "$f" ] && mod_unarchived=$((mod_unarchived + 1))
    done
    if [ "$mod_unarchived" -ge "$EVOLVE_THRESHOLD_SOFT" ]; then
      mod_name=$(basename "$module_dir")
      echo "[AI-CONTEXT] Module '${mod_name}' has ${mod_unarchived} unarchived increments. Execute /lore-evolve."
    fi
  done
fi
