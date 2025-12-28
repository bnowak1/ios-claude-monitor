import SwiftUI

struct DashboardView: View {
    @Environment(SessionsManager.self) private var sessionsManager
    @State private var isRefreshing = false

    var body: some View {
        Group {
            if !sessionsManager.isConfigured {
                ConfigurationPromptView()
            } else {
                sessionsList
            }
        }
        .navigationTitle("Claude Monitor")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if sessionsManager.isLoading {
                    ProgressView()
                        .tint(.accentOrange)
                }
            }
        }
        .onAppear {
            sessionsManager.startPolling()
        }
        .onDisappear {
            sessionsManager.stopPolling()
        }
    }

    private var sessionsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Summary Card
                if let stats = sessionsManager.stats {
                    SummaryCard(
                        activeSessions: stats.activeSessions,
                        todayMessages: stats.today.messages,
                        todayToolCalls: stats.today.toolCalls
                    )
                    .padding(.horizontal)
                }

                // Error Banner
                if let error = sessionsManager.error {
                    ErrorBanner(message: error.localizedDescription)
                        .padding(.horizontal)
                }

                // Active Sessions
                if !sessionsManager.activeSessions.isEmpty {
                    SessionSection(
                        title: "ACTIVE",
                        sessions: sessionsManager.activeSessions
                    )
                }

                // Idle Sessions
                if !sessionsManager.idleSessions.isEmpty {
                    SessionSection(
                        title: "IDLE",
                        sessions: sessionsManager.idleSessions
                    )
                }

                // Recent/Ended Sessions
                if !sessionsManager.endedSessions.isEmpty {
                    SessionSection(
                        title: "RECENT",
                        sessions: Array(sessionsManager.endedSessions.prefix(5))
                    )
                }

                // Empty State
                if sessionsManager.sessions.isEmpty && sessionsManager.error == nil {
                    EmptyStateView()
                        .padding(.top, 40)
                }
            }
            .padding(.vertical)
        }
        .refreshable {
            await sessionsManager.refresh()
        }
        .background(Color.backgroundPrimary)
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let activeSessions: Int
    let todayMessages: Int
    let todayToolCalls: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(activeSessions > 0 ? Color.statusActive : Color.statusEnded)
                    .frame(width: 10, height: 10)
                    .modifier(PulseAnimation(isActive: activeSessions > 0))

                Text("\(activeSessions) Active Session\(activeSessions == 1 ? "" : "s")")
                    .font(.headline)
                    .foregroundColor(.textPrimary)

                Spacer()
            }

            Divider()
                .background(Color.surfaceElevated)

            HStack {
                Text("Today:")
                    .foregroundColor(.textSecondary)
                Text("\(todayMessages) messages")
                    .foregroundColor(.textPrimary)
                Text("•")
                    .foregroundColor(.textTertiary)
                Text("\(todayToolCalls) tools")
                    .foregroundColor(.textPrimary)
            }
            .font(.subheadline)
        }
        .padding()
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Session Section

struct SessionSection: View {
    let title: String
    let sessions: [Session]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.textSecondary)
                .padding(.horizontal)

            ForEach(sessions) { session in
                NavigationLink(value: session) {
                    SessionCard(session: session)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
        }
        .navigationDestination(for: Session.self) { session in
            SessionDetailView(session: session)
        }
    }
}

// MARK: - Session Card

struct SessionCard: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: session.status.icon)
                    .foregroundColor(Color(session.status.color))
                    .modifier(PulseAnimation(isActive: session.status == .active))

                Text(session.projectName)
                    .font(.headline)
                    .foregroundColor(.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.textTertiary)
            }

            // Machine info
            HStack {
                Text(session.machineName)
                    .foregroundColor(.textSecondary)
                Text("•")
                    .foregroundColor(.textTertiary)
                Text(session.status.label)
                    .foregroundColor(Color(session.status.color))
                if session.status == .idle {
                    Text("(\(session.timeSinceActivity))")
                        .foregroundColor(.textTertiary)
                }
            }
            .font(.subheadline)

            // Stats
            HStack(spacing: 16) {
                StatBadge(value: "\(session.messageCount)", label: "msgs")
                StatBadge(value: "\(session.toolCallCount)", label: "tools")
                StatBadge(value: session.timeSinceActivity, label: "")

                Spacer()
            }
        }
        .padding()
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct StatBadge: View {
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.textPrimary)
            if !label.isEmpty {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
        }
    }
}

// MARK: - Supporting Views

struct ConfigurationPromptView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gear.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.accentOrange)

            Text("Setup Required")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Configure your API URL and key in Settings to start monitoring Claude sessions.")
                .font(.body)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "terminal")
                .font(.system(size: 50))
                .foregroundColor(.textTertiary)

            Text("No Sessions")
                .font(.title3)
                .foregroundColor(.textSecondary)

            Text("Start a Claude Code session to see it here")
                .font(.subheadline)
                .foregroundColor(.textTertiary)
        }
    }
}

struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.statusError)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.textPrimary)

            Spacer()
        }
        .padding()
        .background(Color.statusError.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Animations

struct PulseAnimation: ViewModifier {
    let isActive: Bool
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isActive && isPulsing ? 0.6 : 1.0)
            .animation(
                isActive ?
                    Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true) :
                    .default,
                value: isPulsing
            )
            .onAppear {
                if isActive {
                    isPulsing = true
                }
            }
            .onChange(of: isActive) { _, newValue in
                isPulsing = newValue
            }
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
    .environment(SessionsManager())
}
