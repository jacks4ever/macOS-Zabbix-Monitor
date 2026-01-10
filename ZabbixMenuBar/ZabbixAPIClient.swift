import Foundation
import Security

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

// MARK: - Ollama API Models

struct OllamaRequest: Encodable {
    let model: String
    let prompt: String
    let stream: Bool
}

struct OllamaResponse: Decodable {
    let response: String
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

    // Configuration
    @Published var serverURL: String {
        didSet {
            UserDefaults.standard.set(serverURL, forKey: "zabbix_server_url")
        }
    }
    @Published var username: String {
        didSet {
            UserDefaults.standard.set(username, forKey: "zabbix_username")
        }
    }
    @Published var refreshInterval: TimeInterval = 60 {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: "zabbix_refresh_interval")
            setupRefreshTimer()
        }
    }
    @Published var allowSelfSignedCerts: Bool = true {
        didSet {
            UserDefaults.standard.set(allowSelfSignedCerts, forKey: "zabbix_allow_self_signed")
            setupSession()
        }
    }

    // Ollama Configuration
    @Published var ollamaURL: String {
        didSet {
            UserDefaults.standard.set(ollamaURL, forKey: "ollama_url")
        }
    }
    @Published var ollamaModel: String {
        didSet {
            UserDefaults.standard.set(ollamaModel, forKey: "ollama_model")
        }
    }
    @Published var aiSummary: String = ""

    private var authToken: String?
    private var lastProblemSignature: String = "" // Track problems to avoid regenerating AI summary
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
        self.ollamaURL = UserDefaults.standard.string(forKey: "ollama_url") ?? "http://192.168.200.246:11434"
        self.ollamaModel = UserDefaults.standard.string(forKey: "ollama_model") ?? "mistral:7b"

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
                await self?.refreshData()
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
        // Filter to only High (4) and Disaster (5) severity, then take top 10
        let highSeverityProblems = problems.filter { (Int($0.severity) ?? 0) >= 4 }
        let sharedProblems = highSeverityProblems.prefix(10).map { problem in
            SharedProblem(
                eventid: problem.eventid,
                name: problem.name,
                severity: Int(problem.severity) ?? 0,
                timestamp: problem.timestamp,
                isAcknowledged: problem.isAcknowledged
            )
        }

        // Create a signature of current problems to detect changes
        let currentSignature = sharedProblems.map { "\($0.eventid):\($0.name):\($0.severity)" }.joined(separator: "|")

        // Only regenerate AI summary if problems have changed
        if currentSignature != lastProblemSignature {
            lastProblemSignature = currentSignature

            Task {
                await generateAISummary(for: Array(sharedProblems))
            }
        } else {
            // Still save data to update timestamp, but use existing AI summary
            let sharedData = SharedZabbixData(
                problems: Array(sharedProblems),
                totalProblemCount: highSeverityProblems.count,
                lastUpdate: lastRefresh ?? Date(),
                serverURL: serverURL,
                isAuthenticated: isAuthenticated,
                aiSummary: aiSummary
            )
            SharedDataManager.shared.saveData(sharedData)
        }
    }

    private func generateAISummary(for problems: [SharedProblem]) async {
        // If no problems, set a default message
        if problems.isEmpty {
            aiSummary = "All systems operational - no critical issues detected."
            // Update shared data with the summary
            let sharedData = SharedZabbixData(
                problems: [],
                totalProblemCount: 0,
                lastUpdate: lastRefresh ?? Date(),
                serverURL: serverURL,
                isAuthenticated: isAuthenticated,
                aiSummary: aiSummary
            )
            SharedDataManager.shared.saveData(sharedData)
            return
        }

        // Build problem list for the prompt
        let problemList = problems.map { p in
            let severityName = p.severityName
            return "- \(p.name) (Severity: \(severityName))"
        }.joined(separator: "\n")

        let prompt = """
        You are a network analyst. Summarize these Zabbix monitoring alerts in ONE concise sentence.
        Explain what the problems are and suggest what action might be needed.
        Be direct and helpful. Do not use phrases like "Based on the alerts" - just state the summary.

        Current alerts:
        \(problemList)

        One sentence summary:
        """

        // Get the problems data ready first
        let highSeverityProblems = self.problems.filter { (Int($0.severity) ?? 0) >= 4 }
        let sharedProblems = highSeverityProblems.prefix(10).map { problem in
            SharedProblem(
                eventid: problem.eventid,
                name: problem.name,
                severity: Int(problem.severity) ?? 0,
                timestamp: problem.timestamp,
                isAcknowledged: problem.isAcknowledged
            )
        }

        do {
            let summary = try await callOllama(prompt: prompt)
            aiSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            aiSummary = "Unable to generate summary"
        }

        // Always save shared data (with or without AI summary)
        let sharedData = SharedZabbixData(
            problems: Array(sharedProblems),
            totalProblemCount: highSeverityProblems.count,
            lastUpdate: lastRefresh ?? Date(),
            serverURL: serverURL,
            isAuthenticated: isAuthenticated,
            aiSummary: aiSummary
        )
        SharedDataManager.shared.saveData(sharedData)
    }

    private func callOllama(prompt: String) async throws -> String {
        guard let url = URL(string: "\(ollamaURL)/api/generate") else {
            throw NSError(domain: "OllamaError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Ollama URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let ollamaRequest = OllamaRequest(model: ollamaModel, prompt: prompt, stream: false)
        request.httpBody = try JSONEncoder().encode(ollamaRequest)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "OllamaError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Ollama request failed"])
        }

        let ollamaResponse = try JSONDecoder().decode(OllamaResponse.self, from: data)
        return ollamaResponse.response
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
                "sortfield": "name",
                "limit": 100
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
