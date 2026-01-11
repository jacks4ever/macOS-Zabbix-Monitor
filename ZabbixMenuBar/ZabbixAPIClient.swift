import Foundation
import Security
import SwiftUI

// MARK: - Zabbix API Models

struct ZabbixProblem: Identifiable, Codable {
    let eventid: String
    let objectid: String
    let name: String
    let severity: String
    let clock: String
    let acknowledged: String

    var id: String { eventid }

    var severityLevel: SeverityLevel {
        SeverityLevel(rawValue: Int(severity) ?? 0) ?? .notClassified
    }

    var timestamp: Date {
        Date(timeIntervalSince1970: Double(clock) ?? 0)
    }

    var isAcknowledged: Bool {
        acknowledged == "1"
    }
}

enum SeverityLevel: Int, CaseIterable {
    case notClassified = 0
    case information = 1
    case warning = 2
    case average = 3
    case high = 4
    case disaster = 5

    var name: String {
        switch self {
        case .notClassified: return "Not Classified"
        case .information: return "Information"
        case .warning: return "Warning"
        case .average: return "Average"
        case .high: return "High"
        case .disaster: return "Disaster"
        }
    }

    var color: String {
        switch self {
        case .notClassified: return "gray"
        case .information: return "blue"
        case .warning: return "yellow"
        case .average: return "orange"
        case .high: return "red"
        case .disaster: return "purple"
        }
    }
}

struct ZabbixHost: Identifiable, Codable {
    let hostid: String
    let host: String
    let name: String
    let status: String

    var id: String { hostid }

    var isEnabled: Bool {
        status == "0"
    }
}

struct ZabbixTrigger: Codable {
    let triggerid: String
    let description: String
    let priority: String
    let lastchange: String
    let value: String
}

// MARK: - API Response Types

struct ZabbixAPIResponse<T: Decodable>: Decodable {
    let jsonrpc: String
    let result: T?
    let error: ZabbixAPIError?
    let id: Int
}

struct ZabbixAPIError: Decodable, Error {
    let code: Int
    let message: String
    let data: String?

    var localizedDescription: String {
        if let data = data {
            return "\(message): \(data)"
        }
        return message
    }
}

struct AcknowledgeResult: Decodable {
    let eventids: [Int]?
}

// MARK: - Problem Sort Order

enum ProblemSortOrder: String, CaseIterable, Codable {
    case criticality = "criticality"
    case latest = "latest"
    case alphabetical = "alphabetical"

    var displayName: String {
        switch self {
        case .criticality: return "Criticality"
        case .latest: return "Latest"
        case .alphabetical: return "Alphabetical"
        }
    }

    var localizedName: String {
        switch self {
        case .criticality: return String(localized: "sort.criticality")
        case .latest: return String(localized: "sort.latest")
        case .alphabetical: return String(localized: "sort.alphabetical")
        }
    }
}

// MARK: - Severity Filter

struct SeverityFilter: Codable, Equatable {
    var disaster: Bool = true
    var high: Bool = true
    var average: Bool = true
    var warning: Bool = true
    var information: Bool = false
    var notClassified: Bool = false

    /// Returns array of severity levels that are enabled
    var enabledLevels: Set<Int> {
        var levels = Set<Int>()
        if disaster { levels.insert(5) }
        if high { levels.insert(4) }
        if average { levels.insert(3) }
        if warning { levels.insert(2) }
        if information { levels.insert(1) }
        if notClassified { levels.insert(0) }
        return levels
    }

    /// Check if a severity level is enabled
    func includes(severity: Int) -> Bool {
        enabledLevels.contains(severity)
    }
}

// MARK: - AI Provider Types

enum AIProvider: String, CaseIterable, Codable {
    case disabled = "disabled"
    case ollama = "ollama"
    case openai = "openai"
    case anthropic = "anthropic"

    var displayName: String {
        switch self {
        case .disabled: return "Disabled"
        case .ollama: return "Ollama (Local)"
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        }
    }

    var localizedName: LocalizedStringKey {
        switch self {
        case .disabled: return "ai.disabled"
        case .ollama: return "ai.ollamaLocal"
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .disabled, .ollama: return false
        case .openai, .anthropic: return true
        }
    }
}

// MARK: - Ollama API Models

struct OllamaRequest: Encodable {
    let model: String
    let prompt: String
    let stream: Bool
    let options: OllamaOptions?
}

struct OllamaOptions: Encodable {
    let num_predict: Int  // Max tokens to generate
}

struct OllamaResponse: Decodable {
    let response: String
}

// MARK: - OpenAI API Models

struct OpenAIRequest: Encodable {
    let model: String
    let messages: [OpenAIMessage]
    let max_tokens: Int
}

struct OpenAIMessage: Encodable {
    let role: String
    let content: String
}

struct OpenAIResponse: Decodable {
    let choices: [OpenAIChoice]
}

struct OpenAIChoice: Decodable {
    let message: OpenAIMessageResponse
}

struct OpenAIMessageResponse: Decodable {
    let content: String
}

// MARK: - Anthropic API Models

struct AnthropicRequest: Encodable {
    let model: String
    let max_tokens: Int
    let messages: [AnthropicMessage]
}

struct AnthropicMessage: Encodable {
    let role: String
    let content: String
}

struct AnthropicResponse: Decodable {
    let content: [AnthropicContent]
}

struct AnthropicContent: Decodable {
    let text: String
}

// MARK: - Session Delegate for Self-Signed Certs

class ZabbixSessionDelegate: NSObject, URLSessionDelegate {
    let allowSelfSigned: Bool

    init(allowSelfSigned: Bool = true) {
        self.allowSelfSigned = allowSelfSigned
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           allowSelfSigned {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
                return
            }
        }
        completionHandler(.performDefaultHandling, nil)
    }
}

// MARK: - Keychain Helper

enum KeychainHelper {
    static let service = "com.zabbixmenubar.credentials"

    static func save(token: String, for server: String) throws {
        let data = token.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: server,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: "KeychainError", code: Int(status))
        }
    }

    static func getToken(for server: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: server,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        return token
    }

    static func deleteToken(for server: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: server
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Zabbix API Client

@MainActor
class ZabbixAPIClient: ObservableObject {
    @Published var problems: [ZabbixProblem] = []
    @Published var hosts: [ZabbixHost] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var isAuthenticated = false
    @Published var lastRefresh: Date?

    /// Pause auto-refresh (e.g., when context menu is open)
    var pauseRefresh = false

    // Configuration
    @Published var serverURL: String {
        didSet {
            // Defer to avoid "Publishing changes from within view updates" warning
            DispatchQueue.main.async {
                UserDefaults.standard.set(self.serverURL, forKey: "zabbix_server_url")
            }
        }
    }
    @Published var username: String {
        didSet {
            // Defer to avoid "Publishing changes from within view updates" warning
            DispatchQueue.main.async {
                UserDefaults.standard.set(self.username, forKey: "zabbix_username")
            }
        }
    }
    @Published var refreshInterval: TimeInterval = 60 {
        didSet {
            // Defer to avoid "Publishing changes from within view updates" warning
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                UserDefaults.standard.set(self.refreshInterval, forKey: "zabbix_refresh_interval")
                self.setupRefreshTimer()
            }
        }
    }
    @Published var allowSelfSignedCerts: Bool = true {
        didSet {
            // Defer to avoid "Publishing changes from within view updates" warning
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                UserDefaults.standard.set(self.allowSelfSignedCerts, forKey: "zabbix_allow_self_signed")
                self.setupSession()
            }
        }
    }
    @Published var problemSortOrder: ProblemSortOrder {
        didSet {
            // Defer to avoid "Publishing changes from within view updates" warning
            DispatchQueue.main.async {
                UserDefaults.standard.set(self.problemSortOrder.rawValue, forKey: "problem_sort_order")
            }
        }
    }
    @Published var severityFilter: SeverityFilter {
        didSet {
            // Defer to avoid "Publishing changes from within view updates" warning
            DispatchQueue.main.async {
                if let data = try? JSONEncoder().encode(self.severityFilter) {
                    UserDefaults.standard.set(data, forKey: "severity_filter")
                }
            }
        }
    }
    @Published var widgetSeverityFilter: WidgetSeverityFilter {
        didSet {
            // Defer to avoid "Publishing changes from within view updates" warning
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if let data = try? JSONEncoder().encode(self.widgetSeverityFilter) {
                    UserDefaults.standard.set(data, forKey: "widget_severity_filter")
                }
                self.saveDataForWidget()
            }
        }
    }

    // AI Configuration
    @Published var aiProvider: AIProvider {
        didSet {
            // Defer to avoid "Publishing changes from within view updates" warning
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                UserDefaults.standard.set(self.aiProvider.rawValue, forKey: "ai_provider")
                self.onAIProviderChanged()
            }
        }
    }
    @Published var ollamaURL: String {
        didSet {
            // Defer to avoid "Publishing changes from within view updates" warning
            DispatchQueue.main.async {
                UserDefaults.standard.set(self.ollamaURL, forKey: "ollama_url")
            }
        }
    }
    @Published var ollamaModel: String {
        didSet {
            // Defer to avoid "Publishing changes from within view updates" warning
            DispatchQueue.main.async {
                UserDefaults.standard.set(self.ollamaModel, forKey: "ollama_model")
            }
        }
    }
    @Published var openAIAPIKey: String {
        didSet {
            // Defer to avoid "Publishing changes from within view updates" warning
            DispatchQueue.main.async {
                UserDefaults.standard.set(self.openAIAPIKey, forKey: "openai_api_key")
            }
        }
    }
    @Published var openAIModel: String {
        didSet {
            // Defer to avoid "Publishing changes from within view updates" warning
            DispatchQueue.main.async {
                UserDefaults.standard.set(self.openAIModel, forKey: "openai_model")
            }
        }
    }
    @Published var anthropicAPIKey: String {
        didSet {
            // Defer to avoid "Publishing changes from within view updates" warning
            DispatchQueue.main.async {
                UserDefaults.standard.set(self.anthropicAPIKey, forKey: "anthropic_api_key")
            }
        }
    }
    @Published var anthropicModel: String {
        didSet {
            // Defer to avoid "Publishing changes from within view updates" warning
            DispatchQueue.main.async {
                UserDefaults.standard.set(self.anthropicModel, forKey: "anthropic_model")
            }
        }
    }
    @Published var customAIPrompt: String {
        didSet {
            // Defer to avoid "Publishing changes from within view updates" warning
            DispatchQueue.main.async {
                UserDefaults.standard.set(self.customAIPrompt, forKey: "custom_ai_prompt")
            }
        }
    }
    @Published var aiSummary: String = ""

    static let defaultAIPrompt = """
Analyze these Zabbix alerts and identify common themes or patterns. Keep response under 150 characters total. Be extremely concise - 1-2 short sentences max.

{PROBLEM_LIST}

Severity breakdown: {SEVERITY_COUNTS}
"""

    private var authToken: String?
    private var lastProblemSignature: String = "" // Track problem IDs + filter to detect changes
    private var session: URLSession!
    private var sessionDelegate: ZabbixSessionDelegate!
    private var refreshTimer: Timer?

    init() {
        // Initialize all stored properties first (before any didSet can fire)
        let savedRefreshInterval = UserDefaults.standard.double(forKey: "zabbix_refresh_interval")

        self.serverURL = UserDefaults.standard.string(forKey: "zabbix_server_url") ?? "https://192.168.46.183:2443/api_jsonrpc.php"
        self.username = UserDefaults.standard.string(forKey: "zabbix_username") ?? ""
        self._refreshInterval = Published(initialValue: savedRefreshInterval == 0 ? 60 : savedRefreshInterval)
        self.allowSelfSignedCerts = UserDefaults.standard.object(forKey: "zabbix_allow_self_signed") as? Bool ?? true
        let savedSortOrder = UserDefaults.standard.string(forKey: "problem_sort_order") ?? "criticality"
        self.problemSortOrder = ProblemSortOrder(rawValue: savedSortOrder) ?? .criticality

        // Severity Filter (menu bar app)
        if let filterData = UserDefaults.standard.data(forKey: "severity_filter"),
           let savedFilter = try? JSONDecoder().decode(SeverityFilter.self, from: filterData) {
            self.severityFilter = savedFilter
        } else {
            self.severityFilter = SeverityFilter()
        }

        // Widget Severity Filter
        if let filterData = UserDefaults.standard.data(forKey: "widget_severity_filter"),
           let savedFilter = try? JSONDecoder().decode(WidgetSeverityFilter.self, from: filterData) {
            self.widgetSeverityFilter = savedFilter
        } else {
            self.widgetSeverityFilter = WidgetSeverityFilter()
        }

        // AI Configuration
        let savedProvider = UserDefaults.standard.string(forKey: "ai_provider") ?? "ollama"
        self.aiProvider = AIProvider(rawValue: savedProvider) ?? .ollama
        self.ollamaURL = UserDefaults.standard.string(forKey: "ollama_url") ?? "http://192.168.200.246:11434"
        self.ollamaModel = UserDefaults.standard.string(forKey: "ollama_model") ?? "mistral:7b"
        self.openAIAPIKey = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
        self.openAIModel = UserDefaults.standard.string(forKey: "openai_model") ?? "gpt-4o-mini"
        self.anthropicAPIKey = UserDefaults.standard.string(forKey: "anthropic_api_key") ?? ""
        self.anthropicModel = UserDefaults.standard.string(forKey: "anthropic_model") ?? "claude-3-5-haiku-latest"
        self.customAIPrompt = UserDefaults.standard.string(forKey: "custom_ai_prompt") ?? ZabbixAPIClient.defaultAIPrompt

        setupSession()

        // Try to restore cached token
        if let cachedToken = KeychainHelper.getToken(for: serverURL) {
            self.authToken = cachedToken
            self.isAuthenticated = true
            Task {
                await refreshData()
            }
            // Defer timer setup to ensure run loop is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.startAutoRefresh()
            }
        }
    }

    private func setupSession() {
        sessionDelegate = ZabbixSessionDelegate(allowSelfSigned: allowSelfSignedCerts)
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        // Disable caching to ensure fresh data on every request
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        session = URLSession(configuration: config, delegate: sessionDelegate, delegateQueue: nil)
    }

    private func setupRefreshTimer() {
        // Ensure we're on the main thread
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.setupRefreshTimer()
            }
            return
        }

        refreshTimer?.invalidate()
        refreshTimer = nil
        guard refreshInterval > 0 else { return }

        // Create timer and add to common run loop mode for menu bar apps
        let timer = Timer(timeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, !self.pauseRefresh else { return }
                await self.refreshData()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    func startAutoRefresh() {
        setupRefreshTimer()
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - API Methods

    func authenticate(password: String) async {
        isLoading = true
        error = nil

        do {
            let payload: [String: Any] = [
                "jsonrpc": "2.0",
                "method": "user.login",
                "params": [
                    "username": username,
                    "password": password
                ],
                "id": 1
            ]

            let response: ZabbixAPIResponse<String> = try await performRequest(payload: payload)

            if let token = response.result {
                authToken = token
                isAuthenticated = true
                try? KeychainHelper.save(token: token, for: serverURL)
                await refreshData()
                startAutoRefresh()
            } else if let apiError = response.error {
                throw apiError
            }
        } catch let apiError as ZabbixAPIError {
            error = apiError.localizedDescription
            isAuthenticated = false
        } catch {
            self.error = error.localizedDescription
            isAuthenticated = false
        }

        isLoading = false
    }

    func logout() {
        guard authToken != nil else { return }

        Task {
            let payload: [String: Any] = [
                "jsonrpc": "2.0",
                "method": "user.logout",
                "params": [],
                "id": 1
            ]
            _ = try? await performRequest(payload: payload, useAuth: true) as ZabbixAPIResponse<Bool>
        }

        authToken = nil
        isAuthenticated = false
        problems = []
        hosts = []
        KeychainHelper.deleteToken(for: serverURL)
        stopAutoRefresh()
    }

    func refreshData() async {
        guard isAuthenticated else { return }

        isLoading = true
        error = nil

        do {
            async let problemsResult = fetchProblems()
            async let hostsResult = fetchHosts()

            let newProblems = try await problemsResult
            hosts = try await hostsResult
            problems = newProblems
            lastRefresh = Date()

            // Save to shared storage for widget
            saveDataForWidget()
        } catch let apiError as ZabbixAPIError {
            error = apiError.localizedDescription
            // Token might be expired
            if apiError.code == -32602 || apiError.message.contains("Session") {
                isAuthenticated = false
                authToken = nil
                KeychainHelper.deleteToken(for: serverURL)
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func saveDataForWidget() {
        // Send all problems to widget, take top 20 for widget display
        // Widget will filter based on its own severity filter settings
        let sharedProblems = problems.prefix(20).map { problem in
            SharedProblem(
                eventid: problem.eventid,
                name: problem.name,
                severity: Int(problem.severity) ?? 0,
                timestamp: problem.timestamp,
                isAcknowledged: problem.isAcknowledged
            )
        }

        // Filter problems by widget severity filter for AI summary
        let filteredProblems = sharedProblems.filter { problem in
            widgetSeverityFilter.includes(severity: problem.severity)
        }

        // Create a signature from unique problem names + filter settings to detect new problems
        // Using names (not IDs) ensures we only regenerate AI summary when there's a genuinely new problem,
        // not when the same problem is re-reported with a new event ID
        let uniqueProblemNames = Set(filteredProblems.map { $0.name }).sorted().joined(separator: "|")
        let filterSignature = "\(widgetSeverityFilter.enabledLevels.sorted())"
        let currentSignature = "\(uniqueProblemNames)|\(filterSignature)"

        // Regenerate AI summary if problems or filter changed
        if currentSignature != lastProblemSignature {
            lastProblemSignature = currentSignature

            Task {
                await generateAISummary(for: Array(filteredProblems))
            }
        } else {
            // Still save data to update timestamp, but use existing AI summary
            let sharedData = SharedZabbixData(
                problems: Array(sharedProblems),
                totalProblemCount: problems.count,
                lastUpdate: lastRefresh ?? Date(),
                serverURL: serverURL,
                isAuthenticated: isAuthenticated,
                aiSummary: aiSummary,
                severityFilter: widgetSeverityFilter
            )
            SharedDataManager.shared.saveData(sharedData)
        }
    }

    private func generateAISummary(for problems: [SharedProblem]) async {
        // Get all problems for widget (top 20)
        let sharedProblems = self.problems.prefix(20).map { problem in
            SharedProblem(
                eventid: problem.eventid,
                name: problem.name,
                severity: Int(problem.severity) ?? 0,
                timestamp: problem.timestamp,
                isAcknowledged: problem.isAcknowledged
            )
        }

        // If AI is disabled, clear the summary so widget shows raw problems
        if aiProvider == .disabled {
            aiSummary = ""
            let sharedData = SharedZabbixData(
                problems: Array(sharedProblems),
                totalProblemCount: self.problems.count,
                lastUpdate: lastRefresh ?? Date(),
                serverURL: serverURL,
                isAuthenticated: isAuthenticated,
                aiSummary: "",
                severityFilter: widgetSeverityFilter
            )
            SharedDataManager.shared.saveData(sharedData)
            return
        }

        // If no problems, set a default message
        if problems.isEmpty {
            aiSummary = "All systems operational - no critical issues detected."
            let sharedData = SharedZabbixData(
                problems: [],
                totalProblemCount: 0,
                lastUpdate: lastRefresh ?? Date(),
                serverURL: serverURL,
                isAuthenticated: isAuthenticated,
                aiSummary: aiSummary,
                severityFilter: widgetSeverityFilter
            )
            SharedDataManager.shared.saveData(sharedData)
            return
        }

        // Build a list of all problem names for theme analysis
        let problemNames = problems.map { $0.name }

        // Group problems by severity for context
        var severityCounts: [String: Int] = [:]
        for p in problems {
            severityCounts[p.severityName, default: 0] += 1
        }
        let countSummary = severityCounts.map { "\($0.value) \($0.key)" }.joined(separator: ", ")

        // Send all problem names to the AI for theme detection
        let problemList = problemNames.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")

        // Build prompt from custom template with placeholder substitution
        let prompt = customAIPrompt
            .replacingOccurrences(of: "{PROBLEM_LIST}", with: problemList)
            .replacingOccurrences(of: "{SEVERITY_COUNTS}", with: countSummary)
            .replacingOccurrences(of: "{PROBLEM_COUNT}", with: "\(problems.count)")

        do {
            let summary = try await callAIProvider(prompt: prompt)
            aiSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            aiSummary = "Unable to generate summary"
        }

        // Always save shared data (with or without AI summary)
        let sharedData = SharedZabbixData(
            problems: Array(sharedProblems),
            totalProblemCount: self.problems.count,
            lastUpdate: lastRefresh ?? Date(),
            serverURL: serverURL,
            isAuthenticated: isAuthenticated,
            aiSummary: aiSummary,
            severityFilter: widgetSeverityFilter
        )
        SharedDataManager.shared.saveData(sharedData)
    }

    private func onAIProviderChanged() {
        // Reset the problem signature to force regeneration
        lastProblemSignature = ""

        // If AI is disabled, immediately clear the summary and update widget
        if aiProvider == .disabled {
            aiSummary = ""
        }

        // Trigger a widget data refresh with the new AI setting
        saveDataForWidget()
    }

    // MARK: - AI Provider Methods

    private func callAIProvider(prompt: String) async throws -> String {
        switch aiProvider {
        case .disabled:
            return ""
        case .ollama:
            return try await callOllama(prompt: prompt)
        case .openai:
            return try await callOpenAI(prompt: prompt)
        case .anthropic:
            return try await callAnthropic(prompt: prompt)
        }
    }

    private func callOllama(prompt: String) async throws -> String {
        guard let url = URL(string: "\(ollamaURL)/api/generate") else {
            throw NSError(domain: "OllamaError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Ollama URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let ollamaRequest = OllamaRequest(model: ollamaModel, prompt: prompt, stream: false, options: OllamaOptions(num_predict: 80))
        request.httpBody = try JSONEncoder().encode(ollamaRequest)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "OllamaError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Ollama request failed"])
        }

        let ollamaResponse = try JSONDecoder().decode(OllamaResponse.self, from: data)
        return ollamaResponse.response
    }

    private func callOpenAI(prompt: String) async throws -> String {
        guard !openAIAPIKey.isEmpty else {
            throw NSError(domain: "OpenAIError", code: -1, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key not configured"])
        }

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw NSError(domain: "OpenAIError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid OpenAI URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60

        let openAIRequest = OpenAIRequest(
            model: openAIModel,
            messages: [OpenAIMessage(role: "user", content: prompt)],
            max_tokens: 80
        )
        request.httpBody = try JSONEncoder().encode(openAIRequest)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "OpenAIError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "OpenAIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "OpenAI error: \(errorMessage)"])
        }

        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        return openAIResponse.choices.first?.message.content ?? ""
    }

    private func callAnthropic(prompt: String) async throws -> String {
        guard !anthropicAPIKey.isEmpty else {
            throw NSError(domain: "AnthropicError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Anthropic API key not configured"])
        }

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw NSError(domain: "AnthropicError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Anthropic URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anthropicAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 60

        let anthropicRequest = AnthropicRequest(
            model: anthropicModel,
            max_tokens: 80,
            messages: [AnthropicMessage(role: "user", content: prompt)]
        )
        request.httpBody = try JSONEncoder().encode(anthropicRequest)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AnthropicError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "AnthropicError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Anthropic error: \(errorMessage)"])
        }

        let anthropicResponse = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        return anthropicResponse.content.first?.text ?? ""
    }

    func testAIProvider() async -> (success: Bool, message: String) {
        let testPrompt = "Say 'Hello' in exactly one word."

        do {
            let response = try await callAIProvider(prompt: testPrompt)
            if response.isEmpty {
                return (false, "Empty response from AI provider")
            }
            return (true, "Connected successfully")
        } catch {
            return (false, error.localizedDescription)
        }
    }

    private func fetchProblems() async throws -> [ZabbixProblem] {
        guard authToken != nil else { return [] }

        // Use trigger.get with filter for triggers currently in PROBLEM state (value=1)
        // This is more reliable than problem.get for getting current active problems
        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "trigger.get",
            "params": [
                "output": ["triggerid", "description", "priority", "lastchange", "value"],
                "filter": [
                    "value": 1  // Only triggers currently in PROBLEM state
                ],
                "sortfield": "lastchange",
                "sortorder": "DESC",
                "limit": 50,
                "skipDependent": true,
                "monitored": true,
                "active": true,
                "expandDescription": true
            ],
            "id": 2
        ]

        let response: ZabbixAPIResponse<[ZabbixTrigger]> = try await performRequest(payload: payload, useAuth: true)

        if let triggers = response.result {
            // Convert triggers to problems format
            let problems = triggers.map { trigger in
                ZabbixProblem(
                    eventid: trigger.triggerid,
                    objectid: trigger.triggerid,
                    name: trigger.description,
                    severity: trigger.priority,
                    clock: trigger.lastchange,
                    acknowledged: "0"  // Triggers don't have acknowledgement status directly
                )
            }
            return problems
        } else if let apiError = response.error {
            throw apiError
        }
        return []
    }

    private func fetchHosts() async throws -> [ZabbixHost] {
        guard authToken != nil else { return [] }

        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "host.get",
            "params": [
                "output": ["hostid", "host", "name", "status"],
                "sortfield": "name"
            ],
            "id": 3
        ]

        let response: ZabbixAPIResponse<[ZabbixHost]> = try await performRequest(payload: payload, useAuth: true)

        if let hosts = response.result {
            return hosts
        } else if let apiError = response.error {
            throw apiError
        }
        return []
    }

    func acknowledgeProblem(eventId: String, message: String = "Acknowledged via ZabbixMenuBar") async throws {
        guard authToken != nil else { return }

        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "event.acknowledge",
            "params": [
                "eventids": eventId,
                "action": 6,
                "message": message
            ],
            "id": 4
        ]

        let response: ZabbixAPIResponse<AcknowledgeResult> = try await performRequest(payload: payload, useAuth: true)

        if let apiError = response.error {
            throw apiError
        }

        await refreshData()
    }

    // MARK: - Network Helper

    private func performRequest<T: Decodable>(payload: [String: Any], useAuth: Bool = false) async throws -> T {
        guard let url = URL(string: serverURL) else {
            throw NSError(domain: "ZabbixAPIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json-rpc", forHTTPHeaderField: "Content-Type")
        // Disable caching at the request level
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("no-cache, no-store, must-revalidate", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")

        // Zabbix 6.4+ uses Authorization header instead of auth parameter in body
        if useAuth, let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "ZabbixAPIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "ZabbixAPIClient", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Test Connection

    func testConnection() async -> (success: Bool, message: String) {
        do {
            let payload: [String: Any] = [
                "jsonrpc": "2.0",
                "method": "apiinfo.version",
                "params": [],
                "id": 1
            ]

            let response: ZabbixAPIResponse<String> = try await performRequest(payload: payload)

            if let version = response.result {
                return (true, "Connected to Zabbix API v\(version)")
            } else if let apiError = response.error {
                return (false, apiError.localizedDescription)
            }
            return (false, "Unknown error")
        } catch {
            return (false, error.localizedDescription)
        }
    }
}
