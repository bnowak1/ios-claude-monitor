import SwiftUI

struct SettingsView: View {
    @Environment(SessionsManager.self) private var sessionsManager
    @AppStorage("apiURL") private var apiURL = ""
    @AppStorage("apiKey") private var apiKey = ""
    @State private var isTestingConnection = false
    @State private var connectionStatus: ConnectionStatus?

    enum ConnectionStatus {
        case success
        case failure(String)
    }

    var body: some View {
        Form {
            // Server Configuration
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("API URL")
                        .font(.caption)
                        .foregroundColor(.textSecondary)

                    TextField("https://your-app.fly.dev", text: $apiURL)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                .listRowBackground(Color.surface)

                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key")
                        .font(.caption)
                        .foregroundColor(.textSecondary)

                    SecureField("Your secret API key", text: $apiKey)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                .listRowBackground(Color.surface)

                Button {
                    testConnection()
                } label: {
                    HStack {
                        if isTestingConnection {
                            ProgressView()
                                .tint(.accentOrange)
                        } else {
                            Image(systemName: "network")
                        }
                        Text("Test Connection")
                    }
                }
                .disabled(apiURL.isEmpty || apiKey.isEmpty || isTestingConnection)
                .listRowBackground(Color.surface)

                // Connection Status
                if let status = connectionStatus {
                    HStack {
                        switch status {
                        case .success:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.statusActive)
                            Text("Connected successfully")
                                .foregroundColor(.statusActive)
                        case .failure(let message):
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.statusError)
                            Text(message)
                                .foregroundColor(.statusError)
                        }
                    }
                    .font(.subheadline)
                    .listRowBackground(Color.surface)
                }
            } header: {
                Text("Server")
            } footer: {
                Text("Enter the URL of your Claude Monitor backend and the API key you configured.")
            }

            // Quick Setup
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("If you deployed to Fly.io, your URL is:")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)

                    Text("https://claude-monitor-api.fly.dev")
                        .font(.subheadline)
                        .fontDesign(.monospaced)
                        .foregroundColor(.accentOrange)

                    Button("Use This URL") {
                        apiURL = "https://claude-monitor-api.fly.dev"
                    }
                    .font(.subheadline)
                }
                .listRowBackground(Color.surface)
            } header: {
                Text("Quick Setup")
            }

            // Polling Settings
            Section {
                HStack {
                    Text("Refresh Interval")
                    Spacer()
                    Text("3 seconds")
                        .foregroundColor(.textSecondary)
                }
                .listRowBackground(Color.surface)
            } header: {
                Text("Sync")
            } footer: {
                Text("The app polls the server every 3 seconds for updates when active.")
            }

            // About
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.textSecondary)
                }
                .listRowBackground(Color.surface)

                Link(destination: URL(string: "https://github.com/bnowak1/ios-claude-monitor")!) {
                    HStack {
                        Text("GitHub Repository")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.textTertiary)
                    }
                }
                .listRowBackground(Color.surface)
            } header: {
                Text("About")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.backgroundPrimary)
        .navigationTitle("Settings")
    }

    private func testConnection() {
        isTestingConnection = true
        connectionStatus = nil

        Task {
            let success = await sessionsManager.checkConnection()
            await MainActor.run {
                isTestingConnection = false
                if success {
                    connectionStatus = .success
                } else if let error = sessionsManager.error {
                    connectionStatus = .failure(error.localizedDescription)
                } else {
                    connectionStatus = .failure("Connection failed")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(SessionsManager())
}
