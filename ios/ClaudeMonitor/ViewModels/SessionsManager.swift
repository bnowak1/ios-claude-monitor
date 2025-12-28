import Foundation
import SwiftUI

@Observable
class SessionsManager {
    var sessions: [Session] = []
    var stats: StatsResponse?
    var isLoading = false
    var error: Error?
    var lastEventId: String?

    private var pollingTask: Task<Void, Never>?
    private let pollInterval: TimeInterval = 3.0

    var activeSessions: [Session] {
        sessions.filter { $0.status == .active }
    }

    var idleSessions: [Session] {
        sessions.filter { $0.status == .idle }
    }

    var endedSessions: [Session] {
        sessions.filter { $0.status == .ended }
    }

    var isConfigured: Bool {
        let url = UserDefaults.standard.string(forKey: "apiURL")
        return url != nil && !url!.isEmpty
    }

    // MARK: - Public Methods

    func startPolling() {
        guard pollingTask == nil else { return }

        pollingTask = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(pollInterval))
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    @MainActor
    func refresh() async {
        guard isConfigured else { return }

        do {
            async let sessionsTask = APIClient.shared.fetchSessions()
            async let statsTask = APIClient.shared.fetchStats()

            let (sessionsResponse, statsResponse) = try await (sessionsTask, statsTask)

            withAnimation(.easeInOut(duration: 0.2)) {
                self.sessions = sessionsResponse.sessions
                self.stats = statsResponse
                self.error = nil
            }
        } catch {
            self.error = error
        }
    }

    @MainActor
    func fetchEvents(for sessionId: String, since: String? = nil) async throws -> [SessionEvent] {
        let response = try await APIClient.shared.fetchEvents(for: sessionId, since: since)
        return response.events
    }

    @MainActor
    func checkConnection() async -> Bool {
        do {
            return try await APIClient.shared.checkHealth()
        } catch {
            self.error = error
            return false
        }
    }
}
