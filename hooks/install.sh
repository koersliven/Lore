#!/usr/bin/env bash
# install.sh — Installs Lore hooks and injects global CLAUDE.md rules
# Usage:
#   bash install.sh                    # Install to current project
#   bash install.sh --global           # Also inject to ~/.claude/CLAUDE.md
#   bash install.sh --uninstall-global # Remove from ~/.claude/CLAUDE.md
#   bash install.sh [path-to-project]  # Install to specific project

set -euo pipefail

# Determine framework directory
FRAMEWORK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC_HOOKS_DIR="$FRAMEWORK_DIR/hooks"
SRC_SKILLS_DIR="$FRAMEWORK_DIR/skills"
GLOBAL_INJECT_TEMPLATE="$FRAMEWORK_DIR/templates/global-claude-md-inject.md"

# Parse arguments
INSTALL_GLOBAL=false
UNINSTALL_GLOBAL=false
PROJECT_ROOT=""

for arg in "$@"; do
  case "$arg" in
    --global) INSTALL_GLOBAL=true ;;
    --uninstall-global) UNINSTALL_GLOBAL=true ;;
    *) PROJECT_ROOT="$arg" ;;
  esac
done

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"

# ============================================
# Function: Register Lore skills globally in ~/.claude/skills/
# ============================================
install_global_skills() {
  GLOBAL_SKILLS_DIR="$HOME/.claude/skills"
  mkdir -p "$GLOBAL_SKILLS_DIR"

  echo "Registering Lore skills globally..."

  LORE_SKILLS=("lore-init" "lore-digest" "lore-compact" "lore-evolve" "lore-health" "lore-sync" "lore-constraint" "lore-import")
  INSTALLED=0
  UPDATED=0

  for skill in "${LORE_SKILLS[@]}"; do
    SRC_SKILL="$SRC_SKILLS_DIR/$skill"
    DST_SKILL="$GLOBAL_SKILLS_DIR/$skill"

    if [ ! -d "$SRC_SKILL" ]; then
      echo "  WARNING: Source skill directory not found: $SRC_SKILL"
      continue
    fi

    if [ -d "$DST_SKILL" ]; then
      # Skill already exists, update it
      cp -r "$SRC_SKILL"/* "$DST_SKILL/"
      UPDATED=$((UPDATED + 1))
    else
      # New skill, copy it
      cp -r "$SRC_SKILL" "$DST_SKILL"
      INSTALLED=$((INSTALLED + 1))
    fi
  done

  echo "✓ Skills registered: $INSTALLED new, $UPDATED updated"
}

# ============================================
# Function: Inject Lore rules to global CLAUDE.md
# ============================================
inject_global_claude_md() {
  GLOBAL_CLAUDE_MD="$HOME/.claude/CLAUDE.md"

  echo "Injecting Lore rules to global CLAUDE.md..."

  # Create ~/.claude directory if not exists
  mkdir -p "$HOME/.claude"

  # Read the inject template
  INJECT_CONTENT=$(cat "$GLOBAL_INJECT_TEMPLATE")

  # Check if file exists
  if [ ! -f "$GLOBAL_CLAUDE_MD" ]; then
    # File doesn't exist, create it with Lore content
    echo "$INJECT_CONTENT" > "$GLOBAL_CLAUDE_MD"
    echo "✓ Created $GLOBAL_CLAUDE_MD with Lore rules"
    return 0
  fi

  # File exists, check if Lore is already injected
  if grep -q "<!-- LORE_INJECT_START -->" "$GLOBAL_CLAUDE_MD"; then
    # Lore already injected, update it
    # Use awk to replace content between markers
    awk -v new="$INJECT_CONTENT" '
      /<!-- LORE_INJECT_START -->/ { print new; in_block=1; next }
      /<!-- LORE_INJECT_END -->/ { in_block=0; next }
      !in_block { print }
    ' "$GLOBAL_CLAUDE_MD" > "$GLOBAL_CLAUDE_MD.tmp" && mv "$GLOBAL_CLAUDE_MD.tmp" "$GLOBAL_CLAUDE_MD"
    echo "✓ Updated Lore rules in $GLOBAL_CLAUDE_MD"
  else
    # Lore not injected, append to existing file
    echo "" >> "$GLOBAL_CLAUDE_MD"
    echo "$INJECT_CONTENT" >> "$GLOBAL_CLAUDE_MD"
    echo "✓ Appended Lore rules to $GLOBAL_CLAUDE_MD"
  fi

  echo "  Your existing CLAUDE.md content is preserved."
}

# ============================================
# Function: Uninstall Lore from global CLAUDE.md
# ============================================
uninstall_global_claude_md() {
  GLOBAL_CLAUDE_MD="$HOME/.claude/CLAUDE.md"
  GLOBAL_SKILLS_DIR="$HOME/.claude/skills"

  if [ ! -f "$GLOBAL_CLAUDE_MD" ]; then
    echo "Global CLAUDE.md not found. Nothing to uninstall."
    return 0
  fi

  if ! grep -q "<!-- LORE_INJECT_START -->" "$GLOBAL_CLAUDE_MD"; then
    echo "Lore rules not found in global CLAUDE.md. Nothing to uninstall."
    return 0
  fi

  # Remove content between markers (including markers)
  awk '
    /<!-- LORE_INJECT_START -->/ { in_block=1; next }
    /<!-- LORE_INJECT_END -->/ { in_block=0; next }
    !in_block { print }
  ' "$GLOBAL_CLAUDE_MD" > "$GLOBAL_CLAUDE_MD.tmp" && mv "$GLOBAL_CLAUDE_MD.tmp" "$GLOBAL_CLAUDE_MD"

  # Remove trailing empty lines
  sed -i '' -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$GLOBAL_CLAUDE_MD" 2>/dev/null || \
  sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$GLOBAL_CLAUDE_MD" 2>/dev/null || true

  echo "✓ Removed Lore rules from $GLOBAL_CLAUDE_MD"
  echo "  Your other CLAUDE.md content is preserved."

  # Remove global skills
  LORE_SKILLS=("lore-init" "lore-digest" "lore-compact" "lore-evolve" "lore-health" "lore-sync" "lore-constraint" "lore-import")
  REMOVED=0
  for skill in "${LORE_SKILLS[@]}"; do
    DST_SKILL="$GLOBAL_SKILLS_DIR/$skill"
    if [ -d "$DST_SKILL" ]; then
      rm -rf "$DST_SKILL"
      REMOVED=$((REMOVED + 1))
    fi
  done
  if [ "$REMOVED" -gt 0 ]; then
    echo "✓ Removed $REMOVED Lore skills from $GLOBAL_SKILLS_DIR"
  fi
}

# ============================================
# Handle --uninstall-global
# ============================================
if [ "$UNINSTALL_GLOBAL" = true ]; then
  uninstall_global_claude_md
  exit 0
fi

# ============================================
# Install hooks to project
# ============================================
CLAUDE_DIR="$PROJECT_ROOT/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
LORE_HOOKS_DIR="$PROJECT_ROOT/.lore-hooks"

echo "Installing Lore hooks into: $PROJECT_ROOT"

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
    echo "Existing hooks found. Merging new Lore hooks..."

    NEW_SETTINGS=$(echo "$EXISTING" | jq '
      def dedup_lore: [.[] | select([.hooks[].command] | any(contains("lore-hooks")) | not)];
      .hooks = .hooks // {}
      | .hooks.Stop = ((.hooks.Stop // []) | dedup_lore) + [{"matcher":"","hooks":[{"type":"command","command":"bash .lore-hooks/stop-flush.sh","timeout":10}]}]
      | .hooks.PostToolUse = ((.hooks.PostToolUse // []) | dedup_lore) + [{"matcher":"","hooks":[{"type":"command","command":"bash .lore-hooks/post-commit-digest.sh","timeout":30}]}]
      | .hooks.SessionStart = ((.hooks.SessionStart // []) | dedup_lore) + [{"matcher":"","hooks":[{"type":"command","command":"bash .lore-hooks/session-start.sh","timeout":5}]}]
      | .hooks.SessionEnd = ((.hooks.SessionEnd // []) | dedup_lore) + [{"matcher":"","hooks":[{"type":"command","command":"bash .lore-hooks/session-end-flush.sh","timeout":15}]}]
      | .hooks.PreToolUse = ((.hooks.PreToolUse // []) | dedup_lore) + [
          {"matcher":"","hooks":[{"type":"command","command":"bash .lore-hooks/snapshot-guard.sh","timeout":5}]},
          {"matcher":"","hooks":[{"type":"command","command":"bash .lore-hooks/pre-edit-guard.sh","timeout":5}]}
        ]
    ')
    echo "$NEW_SETTINGS" | jq '.' > "$SETTINGS_FILE"
    echo "✓ Hooks merged successfully."
  else
    # Has settings but no hooks section
    NEW_SETTINGS=$(echo "$EXISTING" | jq '
      .hooks = {
        "Stop": [{"matcher":"","hooks":[{"type":"command","command":"bash .lore-hooks/stop-flush.sh","timeout":10}]}],
        "PostToolUse": [{"matcher":"","hooks":[{"type":"command","command":"bash .lore-hooks/post-commit-digest.sh","timeout":30}]}],
        "SessionStart": [{"matcher":"","hooks":[{"type":"command","command":"bash .lore-hooks/session-start.sh","timeout":5}]}],
        "SessionEnd": [{"matcher":"","hooks":[{"type":"command","command":"bash .lore-hooks/session-end-flush.sh","timeout":15}]}],
        "PreToolUse": [
          {"matcher":"","hooks":[{"type":"command","command":"bash .lore-hooks/snapshot-guard.sh","timeout":5}]},
          {"matcher":"","hooks":[{"type":"command","command":"bash .lore-hooks/pre-edit-guard.sh","timeout":5}]}
        ]
      }
    ')
    echo "$NEW_SETTINGS" | jq '.' > "$SETTINGS_FILE"
    echo "✓ Hooks added to existing settings."
  fi
else
  # No existing settings — create fresh
  cat > "$SETTINGS_FILE" <<SETTINGS
{
  "hooks": {
    "Stop": [
      {"matcher": "", "hooks": [{"type": "command", "command": "bash .lore-hooks/stop-flush.sh", "timeout": 10}]}
    ],
    "PostToolUse": [
      {"matcher": "", "hooks": [{"type": "command", "command": "bash .lore-hooks/post-commit-digest.sh", "timeout": 30}]}
    ],
    "SessionStart": [
      {"matcher": "", "hooks": [{"type": "command", "command": "bash .lore-hooks/session-start.sh", "timeout": 5}]}
    ],
    "SessionEnd": [
      {"matcher": "", "hooks": [{"type": "command", "command": "bash .lore-hooks/session-end-flush.sh", "timeout": 15}]}
    ],
    "PreToolUse": [
      {"matcher": "", "hooks": [{"type": "command", "command": "bash .lore-hooks/snapshot-guard.sh", "timeout": 5}]},
      {"matcher": "", "hooks": [{"type": "command", "command": "bash .lore-hooks/pre-edit-guard.sh", "timeout": 5}]}
    ]
  }
}
SETTINGS
  echo "✓ Created .claude/settings.json with Lore hooks."
fi

echo ""
echo "Installed hooks:"
echo "  Stop          → stop-flush.sh (buffer flush detection)"
echo "  PostToolUse   → post-commit-digest.sh (post-commit knowledge extraction)"
echo "  SessionStart  → session-start.sh (snapshot loading)"
echo "  SessionEnd    → session-end-flush.sh (emergency flush)"
echo "  PreToolUse    → snapshot-guard.sh (protect snapshot from direct edits)"
echo "  PreToolUse    → pre-edit-guard.sh (warn when editing files with knowledge)"

# ============================================
# Handle --global
# ============================================
if [ "$INSTALL_GLOBAL" = true ]; then
  echo ""
  inject_global_claude_md
  echo ""
  install_global_skills
fi

echo ""
echo "============================================"
echo "Lore installation complete!"
echo ""
echo "Next steps:"
echo "  1. Run /lore-init to initialize knowledge base"
echo "  2. Start developing — knowledge accumulates automatically"
if [ "$INSTALL_GLOBAL" = false ]; then
  echo ""
  echo "Tip: Run with --global to also inject rules to ~/.claude/CLAUDE.md"
  echo "     This helps Claude Code understand and use Lore framework."
fi
echo "============================================"
