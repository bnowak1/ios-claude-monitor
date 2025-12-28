#!/bin/bash
#
# Claude Monitor Hook Installer
# Sets up Claude Code hooks to send events to the monitor backend
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_SCRIPT="$SCRIPT_DIR/session-monitor.sh"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo ""
echo "╔════════════════════════════════════════╗"
echo "║   Claude Monitor Hook Installer        ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Check for jq
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Warning: jq is not installed. Installing via Homebrew...${NC}"
    if command -v brew &> /dev/null; then
        brew install jq
    else
        echo -e "${RED}Error: Please install jq manually: brew install jq${NC}"
        exit 1
    fi
fi

# Make hook script executable
chmod +x "$HOOK_SCRIPT"
echo -e "${GREEN}✓${NC} Hook script is executable"

# Check for existing settings
if [ -f "$CLAUDE_SETTINGS" ]; then
    echo -e "${GREEN}✓${NC} Found existing Claude settings"
    EXISTING_SETTINGS=$(cat "$CLAUDE_SETTINGS")
else
    echo -e "${YELLOW}!${NC} No existing settings, creating new file"
    mkdir -p "$HOME/.claude"
    EXISTING_SETTINGS="{}"
fi

# Create hooks configuration
HOOKS_CONFIG=$(cat <<EOF
{
  "SessionStart": [{
    "matcher": {},
    "hooks": [{
      "type": "command",
      "command": "$HOOK_SCRIPT session_start"
    }]
  }],
  "SessionEnd": [{
    "matcher": {},
    "hooks": [{
      "type": "command",
      "command": "$HOOK_SCRIPT session_end"
    }]
  }],
  "UserPromptSubmit": [{
    "matcher": {},
    "hooks": [{
      "type": "command",
      "command": "$HOOK_SCRIPT prompt"
    }]
  }],
  "PostToolUse": [{
    "matcher": {},
    "hooks": [{
      "type": "command",
      "command": "$HOOK_SCRIPT tool"
    }]
  }],
  "Stop": [{
    "matcher": {},
    "hooks": [{
      "type": "command",
      "command": "$HOOK_SCRIPT stop"
    }]
  }]
}
EOF
)

# Merge with existing settings
NEW_SETTINGS=$(echo "$EXISTING_SETTINGS" | jq --argjson hooks "$HOOKS_CONFIG" '.hooks = (.hooks // {}) + $hooks')

# Backup existing settings
if [ -f "$CLAUDE_SETTINGS" ]; then
    cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.backup.$(date +%Y%m%d%H%M%S)"
    echo -e "${GREEN}✓${NC} Backed up existing settings"
fi

# Write new settings
echo "$NEW_SETTINGS" > "$CLAUDE_SETTINGS"
echo -e "${GREEN}✓${NC} Updated Claude settings with hooks"

echo ""
echo "═══════════════════════════════════════════"
echo ""
echo "Installation complete! Next steps:"
echo ""
echo "1. Set your environment variables in ~/.zshrc or ~/.bashrc:"
echo ""
echo "   export CLAUDE_MONITOR_API_URL=\"https://your-app.fly.dev\""
echo "   export CLAUDE_MONITOR_API_KEY=\"your-secret-key\""
echo ""
echo "2. Restart your terminal or run: source ~/.zshrc"
echo ""
echo "3. Start a new Claude Code session - events will be sent!"
echo ""
echo "═══════════════════════════════════════════"
echo ""
