import Foundation
import SwiftData

// MARK: - API Models

struct Session: Codable, Identifiable, Hashable {
    let sessionId: String
    let machineId: String
    let machineName: String
    let projectPath: String
    let projectName: String
    let status: SessionStatus
    let model: String?
    let startedAt: String
    let lastActivityAt: String
    let messageCount: Int
    let toolCallCount: Int
    let tokenUsage: TokenUsage

    var id: String { sessionId }

    var startedAtDate: Date {
        ISO8601DateFormatter().date(from: startedAt) ?? Date()
    }

    var lastActivityDate: Date {
        ISO8601DateFormatter().date(from: lastActivityAt) ?? Date()
    }

    var timeSinceActivity: String {
        let interval = Date().timeIntervalSince(lastActivityDate)
        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            let mins = Int(interval / 60)
            return "\(mins)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }

    var duration: String {
        let interval = lastActivityDate.timeIntervalSince(startedAtDate)
        if interval < 60 {
            return "<1m"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m"
        } else {
            let hours = Int(interval / 3600)
            let mins = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(mins)m"
        }
    }
}

enum SessionStatus: String, Codable {
    case active
    case idle
    case ended

    var color: String {
        switch self {
        case .active: return "statusActive"
        case .idle: return "statusIdle"
        case .ended: return "statusEnded"
        }
    }

    var icon: String {
        switch self {
        case .active: return "circle.fill"
        case .idle: return "circle.fill"
        case .ended: return "circle"
        }
    }

    var label: String {
        switch self {
        case .active: return "Active"
        case .idle: return "Idle"
        case .ended: return "Ended"
        }
    }
}

struct TokenUsage: Codable, Hashable {
    let input: Int
    let output: Int
    let cacheRead: Int

    var total: Int { input + output }

    var formatted: String {
        if total >= 1_000_000 {
            return String(format: "%.1fM", Double(total) / 1_000_000)
        } else if total >= 1_000 {
            return String(format: "%.1fK", Double(total) / 1_000)
        }
        return "\(total)"
    }
}

// MARK: - Event Models

struct SessionEvent: Codable, Identifiable, Hashable {
    let eventId: String
    let sessionId: String
    let eventType: String
    let timestamp: String
    let data: EventData

    var id: String { eventId }

    var timestampDate: Date {
        ISO8601DateFormatter().date(from: timestamp) ?? Date()
    }

    var icon: String {
        switch eventType {
        case "session_start": return "play.circle.fill"
        case "session_end": return "stop.circle.fill"
        case "prompt": return "bubble.left.fill"
        case "tool": return toolIcon
        case "stop": return "checkmark.circle.fill"
        default: return "circle.fill"
        }
    }

    var toolIcon: String {
        guard let toolName = data.toolName?.lowercased() else { return "wrench.fill" }

        if toolName.contains("write") || toolName.contains("edit") {
            return "pencil"
        } else if toolName.contains("read") {
            return "doc.text"
        } else if toolName.contains("glob") || toolName.contains("grep") {
            return "magnifyingglass"
        } else if toolName.contains("bash") {
            return "terminal"
        } else if toolName.contains("web") {
            return "globe"
        }
        return "wrench.fill"
    }

    var displayTitle: String {
        switch eventType {
        case "session_start": return "Session Started"
        case "session_end": return "Session Ended"
        case "prompt": return "User Prompt"
        case "tool": return data.toolName ?? "Tool"
        case "stop": return "Response Complete"
        default: return eventType
        }
    }

    var displaySubtitle: String? {
        switch eventType {
        case "prompt":
            if let prompt = data.prompt {
                return String(prompt.prefix(100))
            }
        case "tool":
            if let input = data.toolInput {
                // Try to extract useful info from tool input
                if let filePathString = extractFilePath(from: input) {
                    return filePathString
                }
            }
        case "session_start":
            return data.cwd
        case "session_end":
            return data.reason
        default:
            break
        }
        return nil
    }

    private func extractFilePath(from input: AnyCodable) -> String? {
        if let dict = input.value as? [String: Any] {
            if let path = dict["file_path"] as? String {
                return path.split(separator: "/").last.map(String.init)
            }
            if let pattern = dict["pattern"] as? String {
                return pattern
            }
            if let command = dict["command"] as? String {
                return String(command.prefix(50))
            }
        }
        return nil
    }
}

struct EventData: Codable, Hashable {
    let sessionId: String?
    let cwd: String?
    let prompt: String?
    let toolName: String?
    let toolInput: AnyCodable?
    let toolResponse: String?
    let source: String?
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case cwd
        case prompt
        case toolName = "tool_name"
        case toolInput = "tool_input"
        case toolResponse = "tool_response"
        case source
        case reason
    }
}

// MARK: - API Responses

struct SessionsResponse: Codable {
    let sessions: [Session]
    let activeSessions: Int
    let totalSessions: Int
}

struct EventsResponse: Codable {
    let events: [SessionEvent]
    let lastEventId: String?
    let hasMore: Bool?
}

struct StatsResponse: Codable {
    let today: TodayStats
    let total: TotalStats
    let activeSessions: Int
}

struct TodayStats: Codable {
    let sessions: Int
    let messages: Int
    let toolCalls: Int
}

struct TotalStats: Codable {
    let sessions: Int
    let events: Int
}

// MARK: - SwiftData Cache Models

@Model
class CachedSession {
    @Attribute(.unique) var sessionId: String
    var machineId: String
    var machineName: String
    var projectName: String
    var status: String
    var lastActivityAt: Date
    var messageCount: Int
    var toolCallCount: Int

    init(from session: Session) {
        self.sessionId = session.sessionId
        self.machineId = session.machineId
        self.machineName = session.machineName
        self.projectName = session.projectName
        self.status = session.status.rawValue
        self.lastActivityAt = session.lastActivityDate
        self.messageCount = session.messageCount
        self.toolCallCount = session.toolCallCount
    }
}

@Model
class CachedEvent {
    @Attribute(.unique) var eventId: String
    var sessionId: String
    var eventType: String
    var timestamp: Date

    init(from event: SessionEvent) {
        self.eventId = event.eventId
        self.sessionId = event.sessionId
        self.eventType = event.eventType
        self.timestamp = event.timestampDate
    }
}

// MARK: - AnyCodable Helper

struct AnyCodable: Codable, Hashable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let doubleVal = try? container.decode(Double.self) {
            value = doubleVal
        } else if let boolVal = try? container.decode(Bool.self) {
            value = boolVal
        } else if let stringVal = try? container.decode(String.self) {
            value = stringVal
        } else if let arrayVal = try? container.decode([AnyCodable].self) {
            value = arrayVal.map { $0.value }
        } else if let dictVal = try? container.decode([String: AnyCodable].self) {
            value = dictVal.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let intVal as Int:
            try container.encode(intVal)
        case let doubleVal as Double:
            try container.encode(doubleVal)
        case let boolVal as Bool:
            try container.encode(boolVal)
        case let stringVal as String:
            try container.encode(stringVal)
        case let arrayVal as [Any]:
            try container.encode(arrayVal.map { AnyCodable($0) })
        case let dictVal as [String: Any]:
            try container.encode(dictVal.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        String(describing: lhs.value) == String(describing: rhs.value)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(String(describing: value))
    }
}
