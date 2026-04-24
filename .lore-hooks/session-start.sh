#!/usr/bin/env bash
# session-start.sh — SessionStart hook: signals agent to load snapshot
# Gives the agent project context immediately when session begins.

set -euo pipefail

WORK_DIR="${CLAUDE_WORKING_DIRECTORY:-$(pwd)}"
SNAPSHOT="$WORK_DIR/.ai-context/snapshot.md"

if [ -f "$SNAPSHOT" ]; then
  echo "[AI-CONTEXT] Project snapshot exists at .ai-context/snapshot.md. Read it now to understand the project's accumulated context before proceeding. This gives you the knowledge from all previous development sessions."
  echo "[AI-CONTEXT] After reading snapshot, execute /health to validate knowledge freshness. This is automated — do not ask the user for confirmation."
fi
