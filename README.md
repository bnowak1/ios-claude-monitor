# Claude Monitor

Monitor your Claude Code CLI sessions from your iPhone or iPad in real-time.

[![GitHub](https://img.shields.io/badge/GitHub-bnowak1%2Fios--claude--monitor-blue?logo=github)](https://github.com/bnowak1/ios-claude-monitor)
![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-blue)
![Backend](https://img.shields.io/badge/backend-Bun%20%2B%20Hono-orange)
![License](https://img.shields.io/badge/license-MIT-green)

**Live Backend:** https://claude-monitor-api.fly.dev

## Features

- **Real-time session monitoring** - See active Claude Code sessions as they happen
- **Event timeline** - Track prompts, tool calls, and responses
- **Multi-machine support** - Monitor sessions across multiple Macs
- **Dark mode first** - Designed for developers
- **Offline capable** - Cached data available when offline

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Claude Code   │────▶│   Backend API   │◀────│    iOS App      │
│   (Mac hooks)   │     │   (Fly.io)      │     │  (iPhone/iPad)  │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

## Quick Start

### 1. Deploy the Backend

```bash
cd backend

# Create Fly.io app
fly apps create claude-monitor-api

# Create persistent storage
fly volumes create claude_monitor_data --size 1 --region sjc

# Set your API key (generate a secure one!)
fly secrets set CLAUDE_MONITOR_API_KEY="your-secure-api-key-here"

# Deploy
fly deploy
```

Your backend will be available at: `https://claude-monitor-api.fly.dev`

### 2. Install Mac Hooks

```bash
cd mac-hooks

# Run the installer
chmod +x install.sh
./install.sh

# Add to your shell profile (~/.zshrc or ~/.bashrc)
export CLAUDE_MONITOR_API_URL="https://claude-monitor-api.fly.dev"
export CLAUDE_MONITOR_API_KEY="your-secure-api-key-here"

# Reload shell
source ~/.zshrc
```

### 3. Build the iOS App

1. Open `ios/ClaudeMonitor.xcodeproj` in Xcode
2. Select your development team
3. Build and run on your device or simulator
4. Go to **Settings** in the app
5. Enter your API URL and API key
6. Tap **Test Connection** to verify

## Project Structure

```
ios-claude-monitor/
├── backend/              # Bun + Hono API server
│   ├── src/index.ts     # Main server code
│   ├── Dockerfile       # Container config
│   └── fly.toml         # Fly.io config
├── mac-hooks/           # Claude Code hook scripts
│   ├── session-monitor.sh
│   ├── install.sh
│   └── uninstall.sh
├── ios/                 # SwiftUI iOS app
│   └── ClaudeMonitor/
│       ├── App/
│       ├── Models/
│       ├── Views/
│       ├── ViewModels/
│       └── Services/
├── ARCHITECTURE.md      # Detailed architecture docs
└── UI_DESIGN.md         # UI specifications
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/api/sessions` | GET | List all sessions |
| `/api/sessions/:id` | GET | Get session details |
| `/api/sessions/:id/events` | GET | Get session events |
| `/api/events` | GET | Get recent events (polling) |
| `/api/events` | POST | Receive hook events |
| `/api/stats` | GET | Get usage statistics |

All `/api/*` endpoints require the `X-API-Key` header.

## Events Captured

| Event | When | Data |
|-------|------|------|
| `session_start` | Session begins | session_id, cwd, source |
| `session_end` | Session ends | session_id, reason |
| `prompt` | User sends message | session_id, prompt |
| `tool` | Tool completes | session_id, tool_name, tool_input |
| `stop` | Claude finishes responding | session_id |

## Configuration

### Backend Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | Server port | 3000 |
| `CLAUDE_MONITOR_API_KEY` | API authentication key | `dev-key-change-me` |

### Mac Hook Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `CLAUDE_MONITOR_API_URL` | Backend URL | `http://localhost:3000` |
| `CLAUDE_MONITOR_API_KEY` | API key | `dev-key-change-me` |
| `CLAUDE_MONITOR_MACHINE_ID` | Machine identifier | hostname |
| `CLAUDE_MONITOR_MACHINE_NAME` | Display name | hostname |

## Security

- All communication uses HTTPS (TLS 1.3)
- API key authentication for all endpoints
- Prompts are truncated to avoid sending sensitive data
- Data is stored locally on Fly.io volume (not shared)

## Development

### Run Backend Locally

```bash
cd backend
bun install
bun run dev
```

### Test Hook Manually

```bash
echo '{"session_id":"test-123","cwd":"/test"}' | ./mac-hooks/session-monitor.sh session_start
```

### iOS Development

Open `ios/ClaudeMonitor.xcodeproj` in Xcode 15+.

Requirements:
- iOS 17.0+
- Xcode 15+
- Swift 5.9+

## Troubleshooting

### Events not appearing?

1. Check environment variables: `echo $CLAUDE_MONITOR_API_URL`
2. Test the hook: `echo '{"session_id":"test"}' | ~/.claude/hooks/session-monitor.sh test`
3. Check backend logs: `fly logs -a claude-monitor-api`

### iOS app can't connect?

1. Verify the URL in Settings
2. Check the API key matches
3. Ensure the backend is running: `curl https://your-app.fly.dev/health`

### Hook blocking Claude Code?

The hook script runs asynchronously and always exits 0. If you experience issues, check:
```bash
cat ~/.claude/settings.json | jq '.hooks'
```

## License

MIT License - feel free to modify and use as you wish.

## Credits

Built for monitoring [Claude Code](https://claude.ai/claude-code) sessions.
