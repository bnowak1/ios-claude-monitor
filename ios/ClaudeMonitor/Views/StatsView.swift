import SwiftUI

struct StatsView: View {
    @Environment(SessionsManager.self) private var sessionsManager
    @State private var timeRange = TimeRange.week

    enum TimeRange: String, CaseIterable {
        case today = "Today"
        case week = "This Week"
        case month = "This Month"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Time Range Picker
                Picker("Time Range", selection: $timeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if let stats = sessionsManager.stats {
                    // Activity Summary
                    VStack(alignment: .leading, spacing: 16) {
                        Text("ACTIVITY")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.textSecondary)

                        HStack(spacing: 0) {
                            statBox(
                                value: "\(stats.today.sessions)",
                                label: "Sessions",
                                icon: "terminal"
                            )
                            Divider().frame(height: 60)
                            statBox(
                                value: "\(stats.today.messages)",
                                label: "Messages",
                                icon: "bubble.left"
                            )
                            Divider().frame(height: 60)
                            statBox(
                                value: "\(stats.today.toolCalls)",
                                label: "Tool Calls",
                                icon: "wrench"
                            )
                        }
                        .background(Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)

                    // Active Sessions
                    VStack(alignment: .leading, spacing: 16) {
                        Text("CURRENT STATUS")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.textSecondary)

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Circle()
                                        .fill(Color.statusActive)
                                        .frame(width: 10, height: 10)
                                    Text("\(stats.activeSessions) Active")
                                        .font(.headline)
                                        .foregroundColor(.textPrimary)
                                }

                                Text("Sessions currently running")
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                            }

                            Spacer()

                            Text("\(stats.total.sessions)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.accentOrange)

                            Text("total")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                        .padding()
                        .background(Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)

                    // Events Count
                    VStack(alignment: .leading, spacing: 16) {
                        Text("EVENTS")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.textSecondary)

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(stats.total.events)")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.textPrimary)

                                Text("Total events tracked")
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 40))
                                .foregroundColor(.accentOrange.opacity(0.5))
                        }
                        .padding()
                        .background(Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)

                } else {
                    // Loading or No Data
                    VStack(spacing: 16) {
                        if sessionsManager.isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "chart.bar")
                                .font(.system(size: 50))
                                .foregroundColor(.textTertiary)

                            Text("No Stats Available")
                                .font(.title3)
                                .foregroundColor(.textSecondary)

                            Text("Start using Claude Code to see statistics")
                                .font(.subheadline)
                                .foregroundColor(.textTertiary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                }

                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .background(Color.backgroundPrimary)
        .navigationTitle("Statistics")
        .refreshable {
            await sessionsManager.refresh()
        }
    }

    private func statBox(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentOrange)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)

            Text(label)
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

#Preview {
    NavigationStack {
        StatsView()
    }
    .environment(SessionsManager())
}
