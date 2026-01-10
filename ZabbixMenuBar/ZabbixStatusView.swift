import SwiftUI

struct ZabbixStatusView: View {
    @EnvironmentObject var client: ZabbixAPIClient
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView()
                .environmentObject(client)

            Divider()

            if client.isAuthenticated {
                // Tab selector
                Picker("View", selection: $selectedTab) {
                    Text("Problems").tag(0)
                    Text("Hosts").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Content
                if client.isLoading && client.problems.isEmpty {
                    Spacer()
                    ProgressView("Loading...")
                    Spacer()
                } else if let error = client.error {
                    ErrorView(message: error) {
                        Task { await client.refreshData() }
                    }
                } else {
                    TabView(selection: $selectedTab) {
                        ProblemsListView()
                            .environmentObject(client)
                            .tag(0)

                        HostsListView()
                            .environmentObject(client)
                            .tag(1)
                    }
                    .tabViewStyle(.automatic)
                }

                // Footer
                FooterView()
                    .environmentObject(client)
            } else {
                LoginView()
                    .environmentObject(client)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Header View

struct HeaderView: View {
    @EnvironmentObject var client: ZabbixAPIClient

    var body: some View {
        HStack {
            Image(systemName: "z.square.fill")
                .foregroundColor(.red)
            Text("Zabbix Monitor")
                .font(.headline)

            Spacer()

            if client.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }

            Button(action: { NSApp.terminate(nil) }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
}

// MARK: - Login View

struct LoginView: View {
    @EnvironmentObject var client: ZabbixAPIClient
    @State private var password = ""
    @State private var showPassword = false
    @State private var testResult: String?
    @State private var testSuccess = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Connect to Zabbix")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Server URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("http://192.168.1.100/api_jsonrpc.php", text: $client.serverURL)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Username")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Admin", text: $client.username)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Password")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        if showPassword {
                            TextField("Password", text: $password)
                        } else {
                            SecureField("Password", text: $password)
                        }
                        Button(action: { showPassword.toggle() }) {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .textFieldStyle(.roundedBorder)
                }
            }
            .padding(.horizontal)

            if let result = testResult {
                HStack {
                    Image(systemName: testSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(testSuccess ? .green : .red)
                    Text(result)
                        .font(.caption)
                        .foregroundColor(testSuccess ? .green : .red)
                }
            }

            if let error = client.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            HStack(spacing: 12) {
                Button("Test Connection") {
                    Task {
                        let result = await client.testConnection()
                        testSuccess = result.success
                        testResult = result.message
                    }
                }
                .buttonStyle(.bordered)

                Button("Login") {
                    Task {
                        await client.authenticate(password: password)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(client.username.isEmpty || password.isEmpty || client.serverURL.isEmpty)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Problems List View

struct ProblemsListView: View {
    @EnvironmentObject var client: ZabbixAPIClient

    var body: some View {
        if client.problems.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                Text("No active problems")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(client.problems) { problem in
                ProblemRowView(problem: problem)
                    .environmentObject(client)
            }
            .listStyle(.plain)
        }
    }
}

struct ProblemRowView: View {
    let problem: ZabbixProblem
    @EnvironmentObject var client: ZabbixAPIClient
    @State private var showAcknowledge = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(severityColor)
                    .frame(width: 8, height: 8)

                Text(problem.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)

                Spacer()

                if problem.isAcknowledged {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }

            HStack {
                Text(problem.severityLevel.name)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Text(problem.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            if !problem.isAcknowledged {
                Button("Acknowledge") {
                    showAcknowledge = true
                }
            }
            Button("Copy Name") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(problem.name, forType: .string)
            }
        }
        .sheet(isPresented: $showAcknowledge) {
            AcknowledgeSheet(problem: problem)
                .environmentObject(client)
        }
    }

    var severityColor: Color {
        switch problem.severityLevel {
        case .notClassified: return .gray
        case .information: return .blue
        case .warning: return .yellow
        case .average: return .orange
        case .high: return .red
        case .disaster: return .purple
        }
    }
}

struct AcknowledgeSheet: View {
    let problem: ZabbixProblem
    @EnvironmentObject var client: ZabbixAPIClient
    @Environment(\.dismiss) var dismiss
    @State private var message = ""
    @State private var isSubmitting = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Acknowledge Problem")
                .font(.headline)

            Text(problem.name)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            TextField("Message (optional)", text: $message)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Acknowledge") {
                    isSubmitting = true
                    Task {
                        try? await client.acknowledgeProblem(
                            eventId: problem.eventid,
                            message: message.isEmpty ? "Acknowledged via ZabbixMenuBar" : message
                        )
                        isSubmitting = false
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSubmitting)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

// MARK: - Hosts List View

struct HostsListView: View {
    @EnvironmentObject var client: ZabbixAPIClient
    @State private var searchText = ""

    var filteredHosts: [ZabbixHost] {
        if searchText.isEmpty {
            return client.hosts
        }
        return client.hosts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.host.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search hosts...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.bottom, 8)

            if filteredHosts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No hosts found")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredHosts) { host in
                    HostRowView(host: host)
                }
                .listStyle(.plain)
            }
        }
    }
}

struct HostRowView: View {
    let host: ZabbixHost

    var body: some View {
        HStack {
            Circle()
                .fill(host.isEnabled ? .green : .gray)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(host.name)
                    .font(.caption)
                    .fontWeight(.medium)

                Text(host.host)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(host.isEnabled ? "Enabled" : "Disabled")
                .font(.caption2)
                .foregroundColor(host.isEnabled ? .green : .secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Footer View

struct FooterView: View {
    @EnvironmentObject var client: ZabbixAPIClient

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack {
                if let lastRefresh = client.lastRefresh {
                    Text("Updated \(lastRefresh, style: .relative) ago")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    Task { await client.refreshData() }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .disabled(client.isLoading)

                Menu {
                    SettingsLink {
                        Text("Settings...")
                    }
                    .keyboardShortcut(",", modifiers: .command)
                    Divider()
                    Button("Logout") {
                        client.logout()
                    }
                    Divider()
                    Button("Quit") {
                        NSApp.terminate(nil)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Error View

struct ErrorView: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Error")
                .font(.headline)

            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Retry") {
                retryAction()
            }
            .buttonStyle(.bordered)

            Spacer()
        }
    }
}

#Preview {
    ZabbixStatusView()
        .environmentObject(ZabbixAPIClient())
        .frame(width: 400, height: 500)
}
