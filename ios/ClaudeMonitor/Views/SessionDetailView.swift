import SwiftUI

struct SessionDetailView: View {
    let session: Session
    @Environment(SessionsManager.self) private var sessionsManager
    @State private var events: [SessionEvent] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var selectedTab = 0

    private let tabs = ["Events", "Tools", "Prompts"]

    var body: some View {
        VStack(spacing: 0) {
            // Session Info Header
            sessionHeader

            // Tab Selector
            tabSelector

            // Content
            TabView(selection: $selectedTab) {
                eventsListView(events: events)
                    .tag(0)

                eventsListView(events: events.filter { $0.eventType == "tool" })
                    .tag(1)

                eventsListView(events: events.filter { $0.eventType == "prompt" })
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(Color.backgroundPrimary)
        .navigationTitle(session.projectName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(session.status.color))
                        .frame(width: 8, height: 8)
                        .modifier(PulseAnimation(isActive: session.status == .active))

                    Text(session.status == .active ? "Live" : session.status.label)
                        .font(.caption)
                        .foregroundColor(Color(session.status.color))
                }
            }
        }
        .task {
            await loadEvents()
        }
        .refreshable {
            await loadEvents()
        }
    }

    // MARK: - Session Header

    private var sessionHeader: some View {
        VStack(spacing: 12) {
            // Machine & Path
            VStack(alignment: .leading, spacing: 4) {
                Text(session.machineName)
                    .font(.subheadline)
                    .foregroundColor(.textPrimary)

                Text(session.projectPath)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)

                HStack {
                    Text("Started \(session.timeSinceActivity)")
                    if let model = session.model {
                        Text("•")
                        Text(model)
                    }
                }
                .font(.caption)
                .foregroundColor(.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Stats Row
            HStack(spacing: 0) {
                statCell(value: "\(session.messageCount)", label: "msgs")
                Divider().frame(height: 30)
                statCell(value: "\(session.toolCallCount)", label: "tools")
                Divider().frame(height: 30)
                statCell(value: session.tokenUsage.formatted, label: "tokens")
                Divider().frame(height: 30)
                statCell(value: session.duration, label: "duration")
            }
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .foregroundColor(.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: 8) {
                        Text(tab)
                            .font(.subheadline)
                            .fontWeight(selectedTab == index ? .semibold : .regular)
                            .foregroundColor(selectedTab == index ? .accentOrange : .textSecondary)

                        Rectangle()
                            .fill(selectedTab == index ? Color.accentOrange : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .background(Color.surface)
    }

    // MARK: - Events List

    private func eventsListView(events: [SessionEvent]) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if isLoading && events.isEmpty {
                    ProgressView()
                        .padding(.top, 40)
                } else if events.isEmpty {
                    Text("No events")
                        .foregroundColor(.textTertiary)
                        .padding(.top, 40)
                } else {
                    ForEach(groupEventsByTime(events), id: \.0) { group in
                        EventGroupView(title: group.0, events: group.1)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Helpers

    private func loadEvents() async {
        isLoading = true
        do {
            let fetchedEvents = try await sessionsManager.fetchEvents(for: session.sessionId)
            withAnimation {
                self.events = fetchedEvents.reversed() // Newest first
                self.isLoading = false
            }
        } catch {
            self.error = error
            self.isLoading = false
        }
    }

    private func groupEventsByTime(_ events: [SessionEvent]) -> [(String, [SessionEvent])] {
        let grouped = Dictionary(grouping: events) { event -> String in
            let date = event.timestampDate
            let now = Date()
            let interval = now.timeIntervalSince(date)

            if interval < 60 {
                return "NOW"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "h:mm a"
                return formatter.string(from: date)
            }
        }

        return grouped.sorted { $0.key == "NOW" || ($1.key != "NOW" && $0.key > $1.key) }
    }
}

// MARK: - Event Group View

struct EventGroupView: View {
    let title: String
    let events: [SessionEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Group Header
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(title == "NOW" ? .accentOrange : .textSecondary)

                Rectangle()
                    .fill(Color.surfaceElevated)
                    .frame(height: 1)
            }
            .padding(.top, 16)

            // Events
            ForEach(events) { event in
                EventRowView(event: event)
            }
        }
    }
}

// MARK: - Event Row View

struct EventRowView: View {
    let event: SessionEvent
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main Row
            HStack(alignment: .top, spacing: 12) {
                // Icon
                Image(systemName: event.icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
                    .frame(width: 24, height: 24)
                    .background(iconColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.displayTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.textPrimary)

                    if let subtitle = event.displaySubtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                            .lineLimit(isExpanded ? nil : 2)
                    }
                }

                Spacer()

                // Time
                Text(formatTime(event.timestampDate))
                    .font(.caption)
                    .foregroundColor(.textTertiary)
            }

            // Expanded Content
            if isExpanded, let toolInput = event.data.toolInput {
                Text(String(describing: toolInput.value))
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .foregroundColor(.textSecondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(12)
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
            if event.eventType == "tool" {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
        }
    }

    private var iconColor: Color {
        switch event.eventType {
        case "session_start": return .statusActive
        case "session_end": return .statusEnded
        case "prompt": return .accentOrange
        case "tool": return .blue
        case "stop": return .statusActive
        default: return .textSecondary
        }
    }

    private func formatTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "\(Int(interval))s"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        SessionDetailView(session: Session(
            sessionId: "test",
            machineId: "mac",
            machineName: "MacBook Pro",
            projectPath: "/Users/test/project",
            projectName: "test-project",
            status: .active,
            model: "claude-opus-4.5",
            startedAt: ISO8601DateFormatter().string(from: Date()),
            lastActivityAt: ISO8601DateFormatter().string(from: Date()),
            messageCount: 42,
            toolCallCount: 12,
            tokenUsage: TokenUsage(input: 1000, output: 500, cacheRead: 5000)
        ))
    }
    .environment(SessionsManager())
}
