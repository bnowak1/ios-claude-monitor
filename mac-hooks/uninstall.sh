#!/bin/bash
#
# Claude Monitor Hook Uninstaller
# Removes Claude Code hooks for the monitor
#

set -e

CLAUDE_SETTINGS="$HOME/.claude/settings.json"

echo ""
echo "Uninstalling Claude Monitor hooks..."
echo ""

if [ ! -f "$CLAUDE_SETTINGS" ]; then
    echo "No Claude settings file found. Nothing to uninstall."
    exit 0
fi

if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for uninstall. Please install it: brew install jq"
    exit 1
fi

# Remove monitor hooks (keep other hooks)
CURRENT_SETTINGS=$(cat "$CLAUDE_SETTINGS")

# Check if hooks contain our script
if echo "$CURRENT_SETTINGS" | grep -q "session-monitor.sh"; then
    # Remove hooks that contain our script
    NEW_SETTINGS=$(echo "$CURRENT_SETTINGS" | jq '
        .hooks |= (
            if . then
                with_entries(
                    select(
                        .value |
                        if type == "array" then
                            .[0].hooks[0].command |
                            if type == "string" then
                                contains("session-monitor.sh") | not
                            else
                                true
                            end
                        else
                            true
                        end
                    )
                )
            else
                .
            end
        )
    ')

    # Backup and write
    cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.backup.$(date +%Y%m%d%H%M%S)"
    echo "$NEW_SETTINGS" > "$CLAUDE_SETTINGS"

    echo "✓ Removed Claude Monitor hooks"
    echo "✓ Backup saved to $CLAUDE_SETTINGS.backup.*"
else
    echo "Claude Monitor hooks not found in settings."
fi

echo ""
echo "Uninstall complete."
echo ""
