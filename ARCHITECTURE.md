# Claude Code iOS Monitor - Architecture Design

## Executive Summary

This document outlines the architecture for an iOS app that monitors active Claude Code CLI sessions remotely. The solution uses Claude Code's **hooks system** to push events to a cloud backend, which then syncs to iOS devices via push notifications and real-time updates.

---

## Data Sources Available in Claude Code

### 1. Hooks System (Primary - Real-time Events)

Claude Code provides event-driven hooks that execute shell commands at key lifecycle points:

| Hook Event | Trigger | Data Available |
|------------|---------|----------------|
| `SessionStart` | Session begins/resumes | `session_id`, `cwd`, `source` (startup/resume/clear/compact) |
| `SessionEnd` | Session ends | `session_id`, `reason` (clear/logout/exit/other) |
| `UserPromptSubmit` | User sends message | `session_id`, `prompt` |
| `PreToolUse` | Before tool execution | `tool_name`, `tool_input`, `tool_use_id` |
| `PostToolUse` | After tool completes | `tool_name`, `tool_input`, `tool_response` |
| `Notification` | Claude sends notification | `message`, `notification_type` |
| `Stop` | Agent finishes response | `session_id`, `stop_hook_active` |

**Hook Input Data** (received via stdin as JSON):
```json
{
  "session_id": "uuid",
  "transcript_path": "/path/to/conversation.jsonl",
  "cwd": "/working/directory",
  "permission_mode": "default|plan|acceptEdits|bypassPermissions",
  "hook_event_name": "EventName",
  // ... event-specific fields
}
```

### 2. Session Transcripts (Historical Data)

**Location**: `~/.claude/projects/{project-hash}/{session-id}.jsonl`

**Format**: JSON Lines - one JSON object per line

```json
{
  "type": "user|assistant",
  "message": {
    "role": "user|assistant",
    "content": "...",
    "model": "claude-opus-4-5-20251101"
  },
  "timestamp": "2025-12-28T12:30:00.799Z",
  "sessionId": "uuid",
  "cwd": "/path",
  "uuid": "message-uuid",
  "usage": {
    "input_tokens": 1234,
    "output_tokens": 567
  }
}
```

### 3. Stats Cache (Aggregate Metrics)

**Location**: `~/.claude/stats-cache.json`

Contains daily activity, token usage by model, session counts, and historical data.

### 4. OpenTelemetry (Enterprise Observability)

Claude Code can export metrics/events via OTLP:
- `claude_code.session.count`
- `claude_code.token.usage`
- `claude_code.cost.usage`
- `claude_code.tool_result` events

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           YOUR MAC (Claude Code)                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────┐    ┌──────────────────┐    ┌───────────────────────┐  │
│  │ Claude Code  │───▶│   Hook Scripts   │───▶│  Local State Daemon   │  │
│  │    CLI       │    │ (~/.claude/hooks)│    │  (optional, for       │  │
│  └──────────────┘    └──────────────────┘    │   batching/offline)   │  │
│         │                    │                └───────────┬───────────┘  │
│         │                    │                            │              │
│         ▼                    ▼                            │              │
│  ┌──────────────┐    ┌──────────────────┐                │              │
│  │   Session    │    │   HTTPS POST     │◀───────────────┘              │
│  │  Transcripts │    │   to Backend     │                               │
│  │   (.jsonl)   │    └────────┬─────────┘                               │
│  └──────────────┘             │                                          │
│                               │                                          │
└───────────────────────────────┼──────────────────────────────────────────┘
                                │
                                │ HTTPS (TLS 1.3)
                                │
┌───────────────────────────────▼──────────────────────────────────────────┐
│                          CLOUD BACKEND                                    │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────────┐   │
│  │   API Gateway   │───▶│  Event Handler  │───▶│   Session Store     │   │
│  │  (Auth + Rate   │    │  (Process &     │    │  (Redis/Firestore)  │   │
│  │   Limiting)     │    │   Normalize)    │    │                     │   │
│  └─────────────────┘    └────────┬────────┘    └──────────┬──────────┘   │
│                                  │                        │               │
│                                  ▼                        ▼               │
│                         ┌────────────────┐    ┌─────────────────────┐    │
│                         │ Push Service   │    │   WebSocket Server  │    │
│                         │ (APNs/FCM)     │    │   (Real-time sync)  │    │
│                         └───────┬────────┘    └──────────┬──────────┘    │
│                                 │                        │               │
└─────────────────────────────────┼────────────────────────┼───────────────┘
                                  │                        │
                    Push Notification              WebSocket
                                  │                        │
┌─────────────────────────────────▼────────────────────────▼───────────────┐
│                         iOS APP (iPhone/iPad)                             │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────────┐   │
│  │   Session List  │    │  Session Detail │    │   Notifications     │   │
│  │   Dashboard     │    │  Live Feed      │    │   & Alerts          │   │
│  └─────────────────┘    └─────────────────┘    └─────────────────────┘   │
│                                                                           │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────────┐   │
│  │  Token Usage    │    │   Tool Call     │    │   Settings &        │   │
│  │   & Costs       │    │   History       │    │   Authentication    │   │
│  └─────────────────┘    └─────────────────┘    └─────────────────────┘   │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘
```

---

## Component Design

### 1. Hook Scripts (Mac-side)

**Location**: `~/.claude/settings.json` or `.claude/settings.json`

```json
{
  "hooks": {
    "SessionStart": [{
      "matcher": {},
      "hooks": [{
        "type": "command",
        "command": "~/.claude/hooks/session-monitor.sh start"
      }]
    }],
    "SessionEnd": [{
      "matcher": {},
      "hooks": [{
        "type": "command",
        "command": "~/.claude/hooks/session-monitor.sh end"
      }]
    }],
    "UserPromptSubmit": [{
      "matcher": {},
      "hooks": [{
        "type": "command",
        "command": "~/.claude/hooks/session-monitor.sh prompt"
      }]
    }],
    "PostToolUse": [{
      "matcher": {},
      "hooks": [{
        "type": "command",
        "command": "~/.claude/hooks/session-monitor.sh tool"
      }]
    }],
    "Stop": [{
      "matcher": {},
      "hooks": [{
        "type": "command",
        "command": "~/.claude/hooks/session-monitor.sh stop"
      }]
    }]
  }
}
```

**Hook Script** (`~/.claude/hooks/session-monitor.sh`):

```bash
#!/bin/bash

# Read hook data from stdin
HOOK_DATA=$(cat)

# Configuration
API_ENDPOINT="https://your-backend.com/api/events"
API_KEY="${CLAUDE_MONITOR_API_KEY}"
MACHINE_ID="${CLAUDE_MONITOR_MACHINE_ID:-$(hostname)}"

# Extract event type from argument
EVENT_TYPE="$1"

# Construct payload
PAYLOAD=$(echo "$HOOK_DATA" | jq -c --arg event "$EVENT_TYPE" --arg machine "$MACHINE_ID" '{
  event_type: $event,
  machine_id: $machine,
  timestamp: now | todate,
  data: .
}')

# Send to backend (async, don't block Claude)
curl -s -X POST "$API_ENDPOINT" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d "$PAYLOAD" \
  --max-time 5 \
  > /dev/null 2>&1 &

# Exit successfully (don't block Claude Code)
exit 0
```

### 2. Cloud Backend Options

#### Option A: Firebase (Recommended for Simplicity)

**Pros**: Minimal setup, built-in push notifications, real-time sync, free tier
**Cons**: Vendor lock-in, limited customization

**Stack**:
- Firebase Cloud Functions (event handlers)
- Firestore (session state storage)
- Firebase Cloud Messaging (push notifications)
- Firebase Auth (device authentication)

**Cost**: Free tier supports ~50K reads/day, ~20K writes/day

#### Option B: Self-Hosted (Full Control)

**Stack**:
- **API**: Node.js/Bun + Hono/Express
- **Database**: Redis (ephemeral state) + PostgreSQL (history)
- **WebSockets**: Socket.io or native WS
- **Push**: APNs direct integration
- **Hosting**: Railway, Fly.io, or VPS

#### Option C: Supabase (Middle Ground)

**Pros**: Open-source Firebase alternative, PostgreSQL, real-time subscriptions
**Cons**: Push notifications need separate setup

### 3. iOS App Architecture

**Framework**: SwiftUI + Swift Concurrency

```
┌─────────────────────────────────────────────────────────────┐
│                      iOS App Structure                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                    App Layer                          │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │   │
│  │  │Dashboard │  │ Session  │  │ Notifications    │   │   │
│  │  │  View    │  │ Detail   │  │    View          │   │   │
│  │  └──────────┘  └──────────┘  └──────────────────┘   │   │
│  └──────────────────────────────────────────────────────┘   │
│                            │                                 │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                  ViewModel Layer                      │   │
│  │  ┌──────────────────┐  ┌────────────────────────┐   │   │
│  │  │ SessionsManager  │  │ NotificationsManager   │   │   │
│  │  │ @Observable      │  │ @Observable            │   │   │
│  │  └──────────────────┘  └────────────────────────┘   │   │
│  └──────────────────────────────────────────────────────┘   │
│                            │                                 │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                   Service Layer                       │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌────────────┐ │   │
│  │  │ APIClient    │  │ WebSocket    │  │ PushNotif  │ │   │
│  │  │ (REST)       │  │ Client       │  │ Handler    │ │   │
│  │  └──────────────┘  └──────────────┘  └────────────┘ │   │
│  └──────────────────────────────────────────────────────┘   │
│                            │                                 │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                    Data Layer                         │   │
│  │  ┌──────────────────┐  ┌────────────────────────┐   │   │
│  │  │ Session Model    │  │ SwiftData Persistence  │   │   │
│  │  │ Event Model      │  │ (offline cache)        │   │   │
│  │  └──────────────────┘  └────────────────────────┘   │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Data Models

### Session Model

```swift
import Foundation
import SwiftData

@Model
class MonitoredSession {
    @Attribute(.unique) var sessionId: String
    var machineId: String
    var machineName: String
    var projectPath: String
    var status: SessionStatus
    var startedAt: Date
    var lastActivityAt: Date
    var messageCount: Int
    var toolCallCount: Int
    var tokenUsage: TokenUsage?
    var currentModel: String?

    @Relationship(deleteRule: .cascade)
    var events: [SessionEvent] = []
}

enum SessionStatus: String, Codable {
    case active
    case idle
    case ended
}

struct TokenUsage: Codable {
    var inputTokens: Int
    var outputTokens: Int
    var cacheReadTokens: Int
}

@Model
class SessionEvent {
    var eventId: String
    var eventType: EventType
    var timestamp: Date
    var data: EventData

    var session: MonitoredSession?
}

enum EventType: String, Codable {
    case sessionStart
    case sessionEnd
    case userPrompt
    case toolUse
    case assistantResponse
    case notification
}
```

### API Event Schema

```typescript
// Backend event schema
interface ClaudeMonitorEvent {
  event_type: 'session_start' | 'session_end' | 'prompt' | 'tool' | 'stop';
  machine_id: string;
  timestamp: string;
  data: {
    session_id: string;
    transcript_path?: string;
    cwd?: string;
    permission_mode?: string;

    // Event-specific
    prompt?: string;           // UserPromptSubmit
    tool_name?: string;        // PostToolUse
    tool_input?: object;       // PostToolUse
    tool_response?: string;    // PostToolUse
    source?: string;           // SessionStart
    reason?: string;           // SessionEnd
  };
}
```

---

## iOS App Features

### Core Features

1. **Dashboard View**
   - List of all active sessions across machines
   - Quick status indicators (active/idle/ended)
   - Token usage summary
   - Cost tracking (if available)

2. **Session Detail View**
   - Live event feed (newest first)
   - Conversation snippets
   - Tool call history with expand/collapse
   - Session metadata (project, machine, duration)

3. **Push Notifications**
   - Session started/ended
   - Long-running tool completion
   - Error notifications
   - Configurable per-session

4. **Widgets (iOS 17+)**
   - Active session count
   - Current session status
   - Quick glance at latest activity

### Nice-to-Have Features

- Apple Watch complication
- Siri Shortcuts ("Hey Siri, what's Claude working on?")
- Share sheet for session summaries
- Export session history

---

## Security Considerations

### Authentication Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Mac       │     │   Backend   │     │   iOS App   │
│  (Hooks)    │     │             │     │             │
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                   │                   │
       │ 1. API Key Auth   │                   │
       │──────────────────▶│                   │
       │                   │                   │
       │                   │ 2. Device Auth    │
       │                   │◀──────────────────│
       │                   │   (Sign in with   │
       │                   │    Apple/custom)  │
       │                   │                   │
       │                   │ 3. Device Token   │
       │                   │──────────────────▶│
       │                   │   (JWT + APNs)    │
       │                   │                   │
```

### Security Measures

1. **API Key per Machine**: Each Mac has a unique API key
2. **Device Authentication**: iOS app authenticates via Sign in with Apple or custom auth
3. **TLS Everywhere**: All communication over HTTPS
4. **Data Minimization**: Don't send full prompts/responses by default (configurable)
5. **Token Expiry**: Short-lived tokens with refresh
6. **Rate Limiting**: Prevent abuse

---

## Implementation Phases

### Phase 1: Minimum Viable Product

1. **Mac Side**
   - Hook scripts for SessionStart, SessionEnd, UserPromptSubmit, Stop
   - Simple curl-based event posting

2. **Backend**
   - Firebase Cloud Functions
   - Firestore for session state
   - Basic authentication

3. **iOS App**
   - Session list view
   - Session detail with event feed
   - Basic push notifications

### Phase 2: Enhanced Features

1. **Mac Side**
   - PostToolUse hooks
   - Token usage extraction from transcripts
   - Offline queue with retry

2. **Backend**
   - WebSocket for real-time updates
   - Historical data storage
   - Analytics endpoints

3. **iOS App**
   - Real-time event streaming
   - Cost tracking
   - Widgets

### Phase 3: Polish

1. **Mac Side**
   - Native daemon for better reliability
   - Multi-machine coordination

2. **iOS App**
   - Apple Watch app
   - Siri Shortcuts
   - iPad-optimized layouts

---

## Alternative Approaches Considered

### OpenTelemetry-based Monitoring

**Approach**: Use Claude Code's OTLP export to send metrics to a collector

**Pros**:
- Enterprise-grade observability
- No custom hooks needed
- Rich metrics

**Cons**:
- More complex setup
- Requires OTLP collector infrastructure
- Event data is aggregated, not real-time

**Verdict**: Good for enterprise, overkill for personal use

### SSH + File Watching

**Approach**: iOS app connects via SSH, watches transcript files

**Pros**:
- No backend needed
- Direct access to all data

**Cons**:
- Requires SSH setup
- Battery-intensive polling
- Network exposure

**Verdict**: Works for local network, not ideal for remote

---

## Recommended Stack

| Component | Technology | Rationale |
|-----------|------------|-----------|
| **Mac Hooks** | Bash + curl | Simple, reliable, no dependencies |
| **Backend** | Firebase | Free tier, built-in push, real-time DB |
| **iOS App** | SwiftUI + SwiftData | Modern, native performance |
| **Push** | FCM (via Firebase) | Integrated with backend |
| **Auth** | Sign in with Apple | Privacy-focused, no password |

---

## Next Steps

1. **Set up Firebase project**
2. **Create hook scripts**
3. **Build iOS app skeleton**
4. **Implement event pipeline**
5. **Add push notifications**
6. **Test end-to-end**

---

## File Structure (Proposed)

```
ios-claude-monitor/
├── ARCHITECTURE.md          # This document
├── mac-hooks/
│   ├── session-monitor.sh   # Main hook script
│   ├── install.sh           # Installation script
│   └── README.md
├── backend/
│   ├── functions/           # Firebase Cloud Functions
│   │   ├── src/
│   │   │   ├── index.ts
│   │   │   ├── events.ts
│   │   │   └── push.ts
│   │   └── package.json
│   └── firestore.rules
├── ios/
│   └── ClaudeMonitor/
│       ├── App/
│       ├── Views/
│       ├── ViewModels/
│       ├── Services/
│       ├── Models/
│       └── ClaudeMonitor.xcodeproj
└── README.md
```
