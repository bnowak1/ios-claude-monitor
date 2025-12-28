import { Hono } from "hono";
import { cors } from "hono/cors";
import { logger } from "hono/logger";
import { nanoid } from "nanoid";

// Types
interface Session {
  sessionId: string;
  machineId: string;
  machineName: string;
  projectPath: string;
  projectName: string;
  status: "active" | "idle" | "ended";
  model?: string;
  startedAt: string;
  lastActivityAt: string;
  messageCount: number;
  toolCallCount: number;
  tokenUsage: {
    input: number;
    output: number;
    cacheRead: number;
  };
}

interface SessionEvent {
  eventId: string;
  sessionId: string;
  eventType: string;
  timestamp: string;
  data: Record<string, unknown>;
}

interface HookPayload {
  event_type: string;
  machine_id: string;
  machine_name?: string;
  timestamp: string;
  data: {
    session_id: string;
    cwd?: string;
    transcript_path?: string;
    permission_mode?: string;
    hook_event_name?: string;
    prompt?: string;
    tool_name?: string;
    tool_input?: unknown;
    tool_response?: string;
    source?: string;
    reason?: string;
    message?: string;
  };
}

// In-memory store (persisted to file for durability)
const DATA_FILE = "./data/sessions.json";

let sessions: Map<string, Session> = new Map();
let events: SessionEvent[] = [];
let lastEventId = 0;

// Load data from file
async function loadData() {
  try {
    const file = Bun.file(DATA_FILE);
    if (await file.exists()) {
      const data = await file.json();
      sessions = new Map(Object.entries(data.sessions || {}));
      events = data.events || [];
      lastEventId = data.lastEventId || 0;
      console.log(`Loaded ${sessions.size} sessions and ${events.length} events`);
    }
  } catch (e) {
    console.log("No existing data file, starting fresh");
  }
}

// Save data to file
async function saveData() {
  try {
    await Bun.write(
      DATA_FILE,
      JSON.stringify(
        {
          sessions: Object.fromEntries(sessions),
          events: events.slice(-1000), // Keep last 1000 events
          lastEventId,
        },
        null,
        2
      )
    );
  } catch (e) {
    console.error("Failed to save data:", e);
  }
}

// Debounced save
let saveTimeout: Timer | null = null;
function scheduleSave() {
  if (saveTimeout) clearTimeout(saveTimeout);
  saveTimeout = setTimeout(saveData, 1000);
}

// Extract project name from path
function extractProjectName(cwd: string): string {
  const parts = cwd.split("/");
  return parts[parts.length - 1] || cwd;
}

// Process incoming hook event
function processHookEvent(payload: HookPayload): SessionEvent {
  const { event_type, machine_id, machine_name, data } = payload;
  const sessionId = data.session_id;
  const now = new Date().toISOString();

  // Create event record
  const event: SessionEvent = {
    eventId: `evt_${++lastEventId}`,
    sessionId,
    eventType: event_type,
    timestamp: now,
    data: data as Record<string, unknown>,
  };

  events.push(event);

  // Keep only last 1000 events in memory
  if (events.length > 1000) {
    events = events.slice(-1000);
  }

  // Update or create session
  let session = sessions.get(sessionId);

  if (event_type === "session_start" || !session) {
    session = {
      sessionId,
      machineId: machine_id,
      machineName: machine_name || machine_id,
      projectPath: data.cwd || "",
      projectName: extractProjectName(data.cwd || ""),
      status: "active",
      startedAt: now,
      lastActivityAt: now,
      messageCount: 0,
      toolCallCount: 0,
      tokenUsage: { input: 0, output: 0, cacheRead: 0 },
    };
    sessions.set(sessionId, session);
  }

  // Update session based on event type
  session.lastActivityAt = now;

  switch (event_type) {
    case "session_start":
      session.status = "active";
      break;

    case "session_end":
      session.status = "ended";
      break;

    case "prompt":
      session.messageCount++;
      session.status = "active";
      break;

    case "tool":
      session.toolCallCount++;
      session.status = "active";
      break;

    case "stop":
      // Mark as idle after response completes
      session.status = "idle";
      break;
  }

  scheduleSave();
  return event;
}

// Mark stale sessions as idle
function markStaleSessions() {
  const fiveMinutesAgo = Date.now() - 5 * 60 * 1000;

  for (const session of sessions.values()) {
    if (session.status === "active") {
      const lastActivity = new Date(session.lastActivityAt).getTime();
      if (lastActivity < fiveMinutesAgo) {
        session.status = "idle";
      }
    }
  }
}

// Initialize
await loadData();

// Periodic stale check
setInterval(markStaleSessions, 60000);

// Create Hono app
const app = new Hono();

// Middleware
app.use("*", logger());
app.use(
  "*",
  cors({
    origin: "*",
    allowMethods: ["GET", "POST", "OPTIONS"],
    allowHeaders: ["Content-Type", "Authorization", "X-API-Key"],
  })
);

// API Key validation middleware
const API_KEY = process.env.CLAUDE_MONITOR_API_KEY || "dev-key-change-me";

app.use("/api/*", async (c, next) => {
  const apiKey = c.req.header("X-API-Key") || c.req.header("Authorization")?.replace("Bearer ", "");

  if (apiKey !== API_KEY) {
    return c.json({ error: "Unauthorized" }, 401);
  }

  await next();
});

// Health check
app.get("/", (c) => {
  return c.json({
    service: "claude-monitor",
    status: "ok",
    sessions: sessions.size,
    events: events.length,
  });
});

app.get("/health", (c) => {
  return c.json({ status: "ok" });
});

// Receive events from Mac hooks
app.post("/api/events", async (c) => {
  try {
    const payload = await c.req.json<HookPayload>();

    if (!payload.event_type || !payload.data?.session_id) {
      return c.json({ error: "Invalid payload" }, 400);
    }

    const event = processHookEvent(payload);

    return c.json({
      success: true,
      eventId: event.eventId,
    });
  } catch (e) {
    console.error("Error processing event:", e);
    return c.json({ error: "Internal error" }, 500);
  }
});

// Get all sessions
app.get("/api/sessions", (c) => {
  markStaleSessions();

  const sessionList = Array.from(sessions.values())
    .sort((a, b) => new Date(b.lastActivityAt).getTime() - new Date(a.lastActivityAt).getTime())
    .slice(0, 50);

  return c.json({
    sessions: sessionList,
    activeSessions: sessionList.filter((s) => s.status === "active").length,
    totalSessions: sessions.size,
  });
});

// Get single session
app.get("/api/sessions/:sessionId", (c) => {
  const sessionId = c.req.param("sessionId");
  const session = sessions.get(sessionId);

  if (!session) {
    return c.json({ error: "Session not found" }, 404);
  }

  return c.json({ session });
});

// Get events for a session
app.get("/api/sessions/:sessionId/events", (c) => {
  const sessionId = c.req.param("sessionId");
  const since = c.req.query("since");
  const limit = parseInt(c.req.query("limit") || "50");

  let sessionEvents = events.filter((e) => e.sessionId === sessionId);

  if (since) {
    sessionEvents = sessionEvents.filter((e) => e.eventId > since);
  }

  sessionEvents = sessionEvents.slice(-limit);

  return c.json({
    events: sessionEvents,
    hasMore: sessionEvents.length === limit,
  });
});

// Get recent events across all sessions (for polling)
app.get("/api/events", (c) => {
  const since = c.req.query("since");
  const limit = parseInt(c.req.query("limit") || "100");

  markStaleSessions();

  let recentEvents = events;

  if (since) {
    recentEvents = recentEvents.filter((e) => e.eventId > since);
  }

  recentEvents = recentEvents.slice(-limit);

  return c.json({
    events: recentEvents,
    lastEventId: events.length > 0 ? events[events.length - 1].eventId : null,
  });
});

// Get stats summary
app.get("/api/stats", (c) => {
  const now = new Date();
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString();

  const todaySessions = Array.from(sessions.values()).filter((s) => s.startedAt >= todayStart);

  const todayMessages = todaySessions.reduce((sum, s) => sum + s.messageCount, 0);
  const todayTools = todaySessions.reduce((sum, s) => sum + s.toolCallCount, 0);

  return c.json({
    today: {
      sessions: todaySessions.length,
      messages: todayMessages,
      toolCalls: todayTools,
    },
    total: {
      sessions: sessions.size,
      events: events.length,
    },
    activeSessions: Array.from(sessions.values()).filter((s) => s.status === "active").length,
  });
});

// Start server
const port = parseInt(process.env.PORT || "3000");
console.log(`Claude Monitor API running on port ${port}`);

export default {
  port,
  fetch: app.fetch,
};
