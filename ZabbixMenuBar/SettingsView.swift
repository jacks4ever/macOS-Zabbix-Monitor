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

            FiltersSettingsView()
                .environmentObject(client)
                .tabItem {
                    Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                }

            SecuritySettingsView()
                .environmentObject(client)
                .tabItem {
                    Label("Security", systemImage: "lock.shield")
                }

            AISettingsView()
                .environmentObject(client)
                .tabItem {
                    Label("AI", systemImage: "brain")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 520)
    }
}

// MARK: - Glass Card Container

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
            )
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
    }
}

// MARK: - Connection Settings

struct ConnectionSettingsView: View {
    @EnvironmentObject var client: ZabbixAPIClient
    @State private var testResult: String?
    @State private var testSuccess = false
    @State private var isTesting = false

    var body: some View {
        VStack(spacing: 16) {
            // Server Configuration
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Server", icon: "server.rack")

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Server URL")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("https://your-zabbix-server/api_jsonrpc.php", text: $client.serverURL)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(.quaternary, lineWidth: 1)
                            )
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Username")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("Username", text: $client.username)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(.quaternary, lineWidth: 1)
                            )
                    }
                }
            }

            // Preferences
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Preferences", icon: "gearshape")

                    HStack {
                        Text("Refresh Interval")
                        Spacer()
                        Picker("", selection: $client.refreshInterval) {
                            Text("5 seconds").tag(5.0)
                            Text("10 seconds").tag(10.0)
                            Text("15 seconds").tag(15.0)
                            Text("30 seconds").tag(30.0)
                            Text("1 minute").tag(60.0)
                            Text("5 minutes").tag(300.0)
                            Text("Manual only").tag(0.0)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 140)
                    }

                    Divider().opacity(0.5)

                    HStack {
                        Text("Sort Problems By")
                        Spacer()
                        Picker("", selection: $client.problemSortOrder) {
                            ForEach(ProblemSortOrder.allCases, id: \.self) { order in
                                Text(order.displayName).tag(order)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 140)
                    }
                }
            }

            // Test Connection
            GlassCard {
                HStack {
                    if let result = testResult {
                        HStack(spacing: 6) {
                            Image(systemName: testSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(testSuccess ? .green : .red)
                            Text(result)
                                .font(.subheadline)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }

                    Spacer()

                    Button {
                        isTesting = true
                        Task {
                            let result = await client.testConnection()
                            withAnimation(.easeInOut(duration: 0.2)) {
                                testSuccess = result.success
                                testResult = result.message
                            }
                            isTesting = false
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if isTesting {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 14, height: 14)
                            } else {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                            }
                            Text("Test Connection")
                        }
                        .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(isTesting)
                }
            }

            Spacer()
        }
        .padding(20)
    }
}

// MARK: - Filters Settings

struct FiltersSettingsView: View {
    @EnvironmentObject var client: ZabbixAPIClient

    var body: some View {
        VStack(spacing: 16) {
            // Menu Bar Severity Filters
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Menu Bar Severity", icon: "menubar.rectangle")

                    HStack(spacing: 8) {
                        SeverityToggle(label: "Disaster", color: .purple, isOn: $client.severityFilter.disaster)
                        SeverityToggle(label: "High", color: .red, isOn: $client.severityFilter.high)
                        SeverityToggle(label: "Average", color: .orange, isOn: $client.severityFilter.average)
                    }
                    HStack(spacing: 8) {
                        SeverityToggle(label: "Warning", color: .yellow, isOn: $client.severityFilter.warning)
                        SeverityToggle(label: "Info", color: .blue, isOn: $client.severityFilter.information)
                        SeverityToggle(label: "N/C", color: .gray, isOn: $client.severityFilter.notClassified)
                    }
                }
            }

            // Widget Severity Filters
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Widget Severity", icon: "widget.small")

                    HStack(spacing: 8) {
                        SeverityToggle(label: "Disaster", color: .purple, isOn: $client.widgetSeverityFilter.disaster)
                        SeverityToggle(label: "High", color: .red, isOn: $client.widgetSeverityFilter.high)
                        SeverityToggle(label: "Average", color: .orange, isOn: $client.widgetSeverityFilter.average)
                    }
                    HStack(spacing: 8) {
                        SeverityToggle(label: "Warning", color: .yellow, isOn: $client.widgetSeverityFilter.warning)
                        SeverityToggle(label: "Info", color: .blue, isOn: $client.widgetSeverityFilter.information)
                        SeverityToggle(label: "N/C", color: .gray, isOn: $client.widgetSeverityFilter.notClassified)
                    }
                }
            }

            Spacer()
        }
        .padding(20)
    }
}

// MARK: - Severity Toggle

struct SeverityToggle: View {
    let label: String
    let color: Color
    @Binding var isOn: Bool
    @State private var isHovering = false

    var body: some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.15)) { isOn.toggle() } }) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color.gradient)
                    .frame(width: 10, height: 10)
                    .shadow(color: color.opacity(0.4), radius: isOn ? 4 : 0)
                Text(label)
                    .font(.subheadline)
                Spacer()
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 14))
                    .foregroundColor(isOn ? .accentColor : .secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovering ? .white.opacity(0.08) : .clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Security Settings

struct SecuritySettingsView: View {
    @EnvironmentObject var client: ZabbixAPIClient

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // SSL Settings
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "SSL Certificate", icon: "lock")

                        Toggle(isOn: $client.allowSelfSignedCerts) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Allow self-signed certificates")
                                    .font(.body)
                                Text("Enable for local network servers with self-signed SSL certificates")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        .tint(.blue)
                    }
                }

                // Authentication Status
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Authentication", icon: "person.badge.key")

                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(client.isAuthenticated ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1))
                                    .frame(width: 44, height: 44)
                                Image(systemName: client.isAuthenticated ? "checkmark.shield.fill" : "xmark.shield.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(client.isAuthenticated ? .green : .secondary)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(client.isAuthenticated ? "Authenticated" : "Not Authenticated")
                                    .font(.headline)
                                    .foregroundColor(client.isAuthenticated ? .primary : .secondary)
                                Text(client.isAuthenticated ? "Credentials stored securely in Keychain" : "Connect to your Zabbix server to authenticate")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }

                        if client.isAuthenticated {
                            Divider().opacity(0.5)

                            Button(role: .destructive) {
                                client.logout()
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Clear Saved Credentials")
                                }
                                .font(.subheadline.weight(.medium))
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                Spacer()
            }
            .padding(20)
        }
    }
}

// MARK: - AI Settings

struct AISettingsView: View {
    @EnvironmentObject var client: ZabbixAPIClient
    @State private var testResult: String?
    @State private var testSuccess = false
    @State private var isTesting = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Provider Selection
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "AI Provider", icon: "brain")

                        Picker("Provider", selection: $client.aiProvider) {
                            ForEach(AIProvider.allCases, id: \.self) { provider in
                                Text(provider.displayName).tag(provider)
                            }
                        }
                        .pickerStyle(.segmented)

                        if client.aiProvider == .disabled {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.secondary)
                                Text("AI summaries are disabled. The widget will display actual Zabbix problems.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(10)
                            .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                // Provider Settings
                if client.aiProvider == .ollama {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Ollama Configuration", icon: "server.rack")

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Server URL")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                TextField("http://localhost:11434", text: $client.ollamaURL)
                                    .textFieldStyle(.plain)
                                    .padding(8)
                                    .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(.quaternary, lineWidth: 1)
                                    )
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Model")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                TextField("mistral:7b", text: $client.ollamaModel)
                                    .textFieldStyle(.plain)
                                    .padding(8)
                                    .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(.quaternary, lineWidth: 1)
                                    )
                                Text("Examples: mistral:7b, llama2, codellama")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }

                if client.aiProvider == .openai {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "OpenAI Configuration", icon: "key")

                            VStack(alignment: .leading, spacing: 6) {
                                Text("API Key")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                SecureField("sk-...", text: $client.openAIAPIKey)
                                    .textFieldStyle(.plain)
                                    .padding(8)
                                    .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(.quaternary, lineWidth: 1)
                                    )
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Model")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                TextField("gpt-4o-mini", text: $client.openAIModel)
                                    .textFieldStyle(.plain)
                                    .padding(8)
                                    .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(.quaternary, lineWidth: 1)
                                    )
                                Text("Examples: gpt-4o-mini, gpt-4o, gpt-4-turbo")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }

                if client.aiProvider == .anthropic {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Anthropic Configuration", icon: "key")

                            VStack(alignment: .leading, spacing: 6) {
                                Text("API Key")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                SecureField("sk-ant-...", text: $client.anthropicAPIKey)
                                    .textFieldStyle(.plain)
                                    .padding(8)
                                    .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(.quaternary, lineWidth: 1)
                                    )
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Model")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                TextField("claude-3-5-haiku-latest", text: $client.anthropicModel)
                                    .textFieldStyle(.plain)
                                    .padding(8)
                                    .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(.quaternary, lineWidth: 1)
                                    )
                                Text("Examples: claude-3-5-haiku-latest, claude-3-5-sonnet-latest")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }

                // Test AI
                if client.aiProvider != .disabled {
                    GlassCard {
                        HStack {
                            if let result = testResult {
                                HStack(spacing: 6) {
                                    Image(systemName: testSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(testSuccess ? .green : .red)
                                    Text(result)
                                        .font(.subheadline)
                                        .lineLimit(2)
                                }
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            }

                            Spacer()

                            Button {
                                isTesting = true
                                Task {
                                    let result = await client.testAIProvider()
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        testSuccess = result.success
                                        testResult = result.message
                                    }
                                    isTesting = false
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    if isTesting {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .frame(width: 14, height: 14)
                                    } else {
                                        Image(systemName: "sparkles")
                                    }
                                    Text("Test AI")
                                }
                                .font(.subheadline.weight(.medium))
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                            .disabled(isTesting)
                        }
                    }
                }
            }
            .padding(20)
        }
        .onChange(of: client.aiProvider) { _, _ in
            testResult = nil
        }
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // App Icon and Title
            VStack(spacing: 12) {
                Image("ZabbixIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)

                Text("Zabbix Menu Bar")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Version 1.1")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
                .frame(height: 24)

            // Features
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Features")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        FeatureRow(icon: "bell.fill", text: "Real-time monitoring")
                        FeatureRow(icon: "server.rack", text: "Host overview")
                        FeatureRow(icon: "brain", text: "AI summaries")
                        FeatureRow(icon: "square.grid.2x2", text: "Desktop widget")
                        FeatureRow(icon: "slider.horizontal.3", text: "Severity filters")
                        FeatureRow(icon: "checkmark.circle", text: "Acknowledge")
                        FeatureRow(icon: "lock.shield", text: "Secure storage")
                        FeatureRow(icon: "arrow.clockwise", text: "Auto refresh")
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            Text("Made with ❤️ in Colorado, USA")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 16)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.tint)
                .frame(width: 20)
            Text(text)
                .font(.caption)
                .foregroundStyle(.primary)
            Spacer()
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(ZabbixAPIClient())
}
