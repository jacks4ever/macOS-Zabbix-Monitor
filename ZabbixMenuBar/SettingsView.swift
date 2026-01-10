import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var client: ZabbixAPIClient

    var body: some View {
        TabView {
            ConnectionSettingsView()
                .environmentObject(client)
                .tabItem {
                    Label("Connection", systemImage: "network")
                }

            SecuritySettingsView()
                .environmentObject(client)
                .tabItem {
                    Label("Security", systemImage: "lock.shield")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 300)
    }
}

// MARK: - Connection Settings

struct ConnectionSettingsView: View {
    @EnvironmentObject var client: ZabbixAPIClient
    @State private var testResult: String?
    @State private var testSuccess = false
    @State private var isTesting = false

    var body: some View {
        Form {
            Section {
                TextField("Server URL", text: $client.serverURL)
                    .textFieldStyle(.roundedBorder)

                TextField("Username", text: $client.username)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Text("Refresh Interval")
                    Spacer()
                    Picker("", selection: $client.refreshInterval) {
                        Text("15 seconds").tag(15.0)
                        Text("30 seconds").tag(30.0)
                        Text("1 minute").tag(60.0)
                        Text("5 minutes").tag(300.0)
                        Text("Manual only").tag(0.0)
                    }
                    .frame(width: 150)
                }
            }

            Section {
                HStack {
                    if let result = testResult {
                        Image(systemName: testSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(testSuccess ? .green : .red)
                        Text(result)
                            .font(.caption)
                    }

                    Spacer()

                    Button("Test Connection") {
                        isTesting = true
                        Task {
                            let result = await client.testConnection()
                            testSuccess = result.success
                            testResult = result.message
                            isTesting = false
                        }
                    }
                    .disabled(isTesting)
                }
            }
        }
        .padding()
    }
}

// MARK: - Security Settings

struct SecuritySettingsView: View {
    @EnvironmentObject var client: ZabbixAPIClient

    var body: some View {
        Form {
            Section {
                Toggle("Allow self-signed certificates", isOn: $client.allowSelfSignedCerts)

                Text("Enable this for local network servers with self-signed SSL certificates. For production environments, use properly signed certificates.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Authentication Token")
                        .font(.headline)

                    if client.isAuthenticated {
                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(.green)
                            Text("Authenticated")
                                .foregroundColor(.green)
                        }

                        Button("Clear Saved Credentials") {
                            client.logout()
                        }
                        .foregroundColor(.red)
                    } else {
                        HStack {
                            Image(systemName: "xmark.shield.fill")
                                .foregroundColor(.secondary)
                            Text("Not authenticated")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "z.square.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)

            Text("Zabbix Menu Bar")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 1.0")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("A lightweight macOS menu bar app for monitoring your Zabbix server.")
                    .multilineTextAlignment(.center)

                Text("Features:")
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 4) {
                    FeatureRow(icon: "bell.fill", text: "Real-time problem monitoring")
                    FeatureRow(icon: "server.rack", text: "Host status overview")
                    FeatureRow(icon: "checkmark.circle", text: "Acknowledge problems")
                    FeatureRow(icon: "lock.shield", text: "Secure credential storage")
                }
            }
            .font(.caption)

            Spacer()
        }
        .padding()
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 16)
            Text(text)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(ZabbixAPIClient())
}
