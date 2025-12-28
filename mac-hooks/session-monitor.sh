#!/bin/bash
#
# Claude Code Session Monitor Hook
# Sends session events to the Claude Monitor backend
#
# Installation:
#   1. Run: ./install.sh
#   2. Set environment variables:
#      export CLAUDE_MONITOR_API_URL="https://your-backend.fly.dev"
#      export CLAUDE_MONITOR_API_KEY="your-api-key"
#

set -e

# Configuration
API_URL="${CLAUDE_MONITOR_API_URL:-http://localhost:3000}"
API_KEY="${CLAUDE_MONITOR_API_KEY:-dev-key-change-me}"
MACHINE_ID="${CLAUDE_MONITOR_MACHINE_ID:-$(hostname -s)}"
MACHINE_NAME="${CLAUDE_MONITOR_MACHINE_NAME:-$(hostname -s)}"

# Event type from argument
EVENT_TYPE="$1"

# Read hook data from stdin
HOOK_DATA=$(cat)

# Extract key fields with jq (falls back to empty if not available)
if command -v jq &> /dev/null; then
    SESSION_ID=$(echo "$HOOK_DATA" | jq -r '.session_id // empty')
else
    # Basic extraction without jq
    SESSION_ID=$(echo "$HOOK_DATA" | grep -o '"session_id":"[^"]*"' | cut -d'"' -f4)
fi

# Skip if no session ID
if [ -z "$SESSION_ID" ]; then
    exit 0
fi

# Construct payload
if command -v jq &> /dev/null; then
    PAYLOAD=$(jq -n \
        --arg event "$EVENT_TYPE" \
        --arg machine_id "$MACHINE_ID" \
        --arg machine_name "$MACHINE_NAME" \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --argjson data "$HOOK_DATA" \
        '{
            event_type: $event,
            machine_id: $machine_id,
            machine_name: $machine_name,
            timestamp: $timestamp,
            data: $data
        }')
else
    # Basic payload without jq
    PAYLOAD="{\"event_type\":\"$EVENT_TYPE\",\"machine_id\":\"$MACHINE_ID\",\"machine_name\":\"$MACHINE_NAME\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"data\":$HOOK_DATA}"
fi

# Send to backend (async, don't block Claude Code)
curl -s -X POST "${API_URL}/api/events" \
    -H "Content-Type: application/json" \
    -H "X-API-Key: ${API_KEY}" \
    -d "$PAYLOAD" \
    --connect-timeout 2 \
    --max-time 5 \
    > /dev/null 2>&1 &

# Always exit successfully to not block Claude Code
exit 0
