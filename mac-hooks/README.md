# Claude Monitor - Mac Hooks

Shell scripts that integrate with Claude Code's hook system to send session events to the monitoring backend.

## Quick Install

```bash
cd mac-hooks
./install.sh
```

## Configuration

After installation, add these environment variables to your `~/.zshrc` or `~/.bashrc`:

```bash
# Claude Monitor Configuration
export CLAUDE_MONITOR_API_URL="https://claude-monitor-api.fly.dev"
export CLAUDE_MONITOR_API_KEY="your-secret-api-key"

# Optional: Custom machine identifier
export CLAUDE_MONITOR_MACHINE_ID="my-macbook"
export CLAUDE_MONITOR_MACHINE_NAME="MacBook Pro"
```

Then reload your shell:

```bash
source ~/.zshrc
```

## Events Captured

| Event | When | Data Sent |
|-------|------|-----------|
| `session_start` | Session begins | session_id, cwd, source |
| `session_end` | Session ends | session_id, reason |
| `prompt` | User sends message | session_id, prompt (truncated) |
| `tool` | Tool completes | session_id, tool_name, tool_input |
| `stop` | Claude finishes | session_id |

## How It Works

1. Claude Code triggers hooks defined in `~/.claude/settings.json`
2. Hook scripts receive event data via stdin (JSON)
3. Scripts POST to your backend API asynchronously
4. Events are stored and available to iOS app

## Uninstall

```bash
./uninstall.sh
```

## Troubleshooting

### Events not sending?

1. Check API URL is correct: `echo $CLAUDE_MONITOR_API_URL`
2. Test manually:
   ```bash
   echo '{"session_id":"test"}' | ./session-monitor.sh test
   ```
3. Check backend logs on Fly.io

### jq not found?

Install with Homebrew:
```bash
brew install jq
```
