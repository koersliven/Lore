#!/usr/bin/env bash
# install.sh — Installs AI Context hooks into a project's .claude/settings.json
# Usage: bash install.sh [path-to-project-root]
# If no path given, uses current directory.

set -euo pipefail

PROJECT_ROOT="${1:-$(pwd)}"
CLAUDE_DIR="$PROJECT_ROOT/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

# Determine where the hooks scripts live (absolute path)
FRAMEWORK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_DIR="$FRAMEWORK_DIR/hooks"

echo "Installing AI Context hooks into: $PROJECT_ROOT"

# Create .claude directory if needed
mkdir -p "$CLAUDE_DIR"

# Build hooks JSON configuration
# Uses absolute paths to framework hooks so they auto-upgrade when framework updates

build_hook_entry() {
  local script="$1"
  local timeout="${2:-5}"
  echo "{\"type\": \"command\", \"command\": \"bash $HOOKS_DIR/$script\", \"timeout\": $timeout}"
}

# Check if settings.json already exists and has hooks config
if [ -f "$SETTINGS_FILE" ]; then
  EXISTING=$(cat "$SETTINGS_FILE")
  if echo "$EXISTING" | jq -e '.hooks' >/dev/null 2>&1; then
    echo "Existing hooks found. Merging new AI Context hooks..."

    NEW_SETTINGS=$(echo "$EXISTING" | jq \
      --arg stop "$(build_hook_entry 'stop-flush.sh' 10)" \
      --arg commit "$(build_hook_entry 'post-commit-digest.sh' 30)" \
      --arg session_start "$(build_hook_entry 'session-start.sh' 5)" \
      --arg session_end "$(build_hook_entry 'session-end-flush.sh' 15)" \
      --arg guard_snapshot "$(build_hook_entry 'snapshot-guard.sh' 5)" \
      --arg guard_edit "$(build_hook_entry 'pre-edit-guard.sh' 5)" \
      '
      .hooks = .hooks // {}
      | .hooks.Stop = (.hooks.Stop // []) + [($stop | fromjson)]
      | .hooks.PostToolUse = (.hooks.PostToolUse // []) + [($commit | fromjson)]
      | .hooks.SessionStart = (.hooks.SessionStart // []) + [($session_start | fromjson)]
      | .hooks.SessionEnd = (.hooks.SessionEnd // []) + [($session_end | fromjson)]
      | .hooks.PreToolUse = (.hooks.PreToolUse // []) + [($guard_snapshot | fromjson), ($guard_edit | fromjson)]
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
      $(build_hook_entry 'stop-flush.sh' 10)
    ],
    "PostToolUse": [
      $(build_hook_entry 'post-commit-digest.sh' 30)
    ],
    "SessionStart": [
      $(build_hook_entry 'session-start.sh' 5)
    ],
    "SessionEnd": [
      $(build_hook_entry 'session-end-flush.sh' 15)
    ],
    "PreToolUse": [
      $(build_hook_entry 'snapshot-guard.sh' 5),
      $(build_hook_entry 'pre-edit-guard.sh' 5)
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
