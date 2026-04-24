#!/usr/bin/env bash
# install.sh — Installs AI Context hooks into a project's .claude/settings.json
# Usage: bash install.sh [path-to-project-root]
# If no path given, uses current directory.

set -euo pipefail

PROJECT_ROOT="${1:-$(pwd)}"
CLAUDE_DIR="$PROJECT_ROOT/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
LORE_HOOKS_DIR="$PROJECT_ROOT/.lore-hooks"

# Determine where the hooks scripts live in the framework
FRAMEWORK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC_HOOKS_DIR="$FRAMEWORK_DIR/hooks"

echo "Installing AI Context hooks into: $PROJECT_ROOT"

# Create directories if needed
mkdir -p "$CLAUDE_DIR" "$LORE_HOOKS_DIR"

# Copy hook scripts into the project
for script in "$SRC_HOOKS_DIR"/*.sh; do
  cp "$script" "$LORE_HOOKS_DIR/"
  chmod +x "$LORE_HOOKS_DIR/$(basename "$script")"
done

# Check if settings.json already exists and has hooks config
if [ -f "$SETTINGS_FILE" ]; then
  EXISTING=$(cat "$SETTINGS_FILE")
  if echo "$EXISTING" | jq -e '.hooks' >/dev/null 2>&1; then
    echo "Existing hooks found. Merging new AI Context hooks..."

    NEW_SETTINGS=$(echo "$EXISTING" | jq '
      .hooks = .hooks // {}
      | .hooks.Stop = (.hooks.Stop // []) + [{"type":"command","command":"bash .lore-hooks/stop-flush.sh","timeout":10}]
      | .hooks.PostToolUse = (.hooks.PostToolUse // []) + [{"type":"command","command":"bash .lore-hooks/post-commit-digest.sh","timeout":30}]
      | .hooks.SessionStart = (.hooks.SessionStart // []) + [{"type":"command","command":"bash .lore-hooks/session-start.sh","timeout":5}]
      | .hooks.SessionEnd = (.hooks.SessionEnd // []) + [{"type":"command","command":"bash .lore-hooks/session-end-flush.sh","timeout":15}]
      | .hooks.PreToolUse = (.hooks.PreToolUse // []) + [
          {"type":"command","command":"bash .lore-hooks/snapshot-guard.sh","timeout":5},
          {"type":"command","command":"bash .lore-hooks/pre-edit-guard.sh","timeout":5}
        ]
    ')
    echo "$NEW_SETTINGS" | jq '.' > "$SETTINGS_FILE"
    echo "Hooks merged successfully."
    echo ""
    echo "Installed hooks:"
    echo "  Stop          → stop-flush.sh (buffer flush detection)"
    echo "  PostToolUse   → post-commit-digest.sh (post-commit knowledge extraction)"
    echo "  SessionStart  → session-start.sh (snapshot loading)"
    echo "  SessionEnd    → session-end-flush.sh (emergency flush)"
    echo "  PreToolUse    → snapshot-guard.sh (protect snapshot from direct edits)"
    echo "  PreToolUse    → pre-edit-guard.sh (warn when editing files with known knowledge)"
    exit 0
  fi
fi

# No existing hooks — create fresh settings
cat > "$SETTINGS_FILE" <<SETTINGS
{
  "hooks": {
    "Stop": [
      {"type": "command", "command": "bash .lore-hooks/stop-flush.sh", "timeout": 10}
    ],
    "PostToolUse": [
      {"type": "command", "command": "bash .lore-hooks/post-commit-digest.sh", "timeout": 30}
    ],
    "SessionStart": [
      {"type": "command", "command": "bash .lore-hooks/session-start.sh", "timeout": 5}
    ],
    "SessionEnd": [
      {"type": "command", "command": "bash .lore-hooks/session-end-flush.sh", "timeout": 15}
    ],
    "PreToolUse": [
      {"type": "command", "command": "bash .lore-hooks/snapshot-guard.sh", "timeout": 5},
      {"type": "command", "command": "bash .lore-hooks/pre-edit-guard.sh", "timeout": 5}
    ]
  }
}
SETTINGS

echo "Created .claude/settings.json with AI Context hooks."
echo ""
echo "Installed hooks:"
echo "  Stop          → stop-flush.sh (buffer flush detection)"
echo "  PostToolUse   → post-commit-digest.sh (post-commit knowledge extraction)"
echo "  SessionStart  → session-start.sh (snapshot loading)"
echo "  SessionEnd    → session-end-flush.sh (emergency flush)"
echo "  PreToolUse    → snapshot-guard.sh (protect snapshot from direct edits)"
echo "  PreToolUse    → pre-edit-guard.sh (warn when editing files with known knowledge)"
