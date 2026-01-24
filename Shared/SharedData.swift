import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - App Group Identifier
// macOS Sequoia requires Team ID prefix format (not "group." prefix)
// The container name uses no dot after Team ID, but UserDefaults suiteName uses a dot
let appGroupContainer = "QGG9KJ66D2.com.zabbixmenubar"
let userDefaultsSuite = "QGG9KJ66D2.com.zabbixmenubar"

// MARK: - Shared Problem Data

struct SharedProblem: Codable, Identifiable {
    let eventid: String
    let name: String
    let severity: Int
    let timestamp: Date
    let isAcknowledged: Bool

    var id: String { eventid }

    var severityName: String {
        switch severity {
        case 0: return "Not Classified"
        case 1: return "Information"
        case 2: return "Warning"
        case 3: return "Average"
        case 4: return "High"
        case 5: return "Disaster"
        default: return "Unknown"
        }
    }
}

// MARK: - Widget Severity Filter (shared between app and widget)

struct WidgetSeverityFilter: Codable, Equatable {
    var disaster: Bool = true
    var high: Bool = true
    var average: Bool = true
    var warning: Bool = true
    var information: Bool = false
    var notClassified: Bool = false

    /// Returns set of severity levels that are enabled for widget display
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

struct SharedZabbixData: Codable {
    let problems: [SharedProblem]
    let totalProblemCount: Int
    let lastUpdate: Date
    let serverURL: String
    let isAuthenticated: Bool
    let aiSummary: String
    let severityFilter: WidgetSeverityFilter
    let widgetProblemCount: Int

    enum CodingKeys: String, CodingKey {
        case problems, totalProblemCount, lastUpdate, serverURL, isAuthenticated, aiSummary, severityFilter, widgetProblemCount
    }

    // Custom decoder for backwards compatibility - provides defaults if missing
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        problems = try container.decode([SharedProblem].self, forKey: .problems)
        totalProblemCount = try container.decode(Int.self, forKey: .totalProblemCount)
        lastUpdate = try container.decode(Date.self, forKey: .lastUpdate)
        serverURL = try container.decode(String.self, forKey: .serverURL)
        isAuthenticated = try container.decode(Bool.self, forKey: .isAuthenticated)
        aiSummary = try container.decode(String.self, forKey: .aiSummary)
        // Use default filter if not present (backwards compatibility)
        severityFilter = try container.decodeIfPresent(WidgetSeverityFilter.self, forKey: .severityFilter) ?? WidgetSeverityFilter()
        // Use default problem count if not present (backwards compatibility)
        widgetProblemCount = try container.decodeIfPresent(Int.self, forKey: .widgetProblemCount) ?? 6
    }

    init(problems: [SharedProblem], totalProblemCount: Int, lastUpdate: Date, serverURL: String, isAuthenticated: Bool, aiSummary: String, severityFilter: WidgetSeverityFilter = WidgetSeverityFilter(), widgetProblemCount: Int = 6) {
        self.problems = problems
        self.totalProblemCount = totalProblemCount
        self.lastUpdate = lastUpdate
        self.serverURL = serverURL
        self.isAuthenticated = isAuthenticated
        self.aiSummary = aiSummary
        self.severityFilter = severityFilter
        self.widgetProblemCount = widgetProblemCount
    }

    static var empty: SharedZabbixData {
        SharedZabbixData(
            problems: [],
            totalProblemCount: 0,
            lastUpdate: Date(),
            serverURL: "",
            isAuthenticated: false,
            aiSummary: "",
            severityFilter: WidgetSeverityFilter(),
            widgetProblemCount: 6
        )
    }
}

// MARK: - Shared Data Manager

class SharedDataManager {
    static let shared = SharedDataManager()

    private let userDefaultsKey = "zabbix_widget_data"

    // Use UserDefaults with Team ID prefixed suite name (Sequoia format)
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: userDefaultsSuite)
    }

    private init() {}

    /// Track last saved data signature to avoid redundant widget reloads
    private var lastSavedSignature: String = ""

    func saveData(_ data: SharedZabbixData) {
        guard let defaults = sharedDefaults else { return }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            let encoded = try encoder.encode(data)

            // Create a signature from problem IDs, AI summary, and display settings to detect real changes
            let problemIds = data.problems.map { $0.eventid }.sorted().joined()
            let signature = "\(problemIds)|\(data.aiSummary)|\(data.totalProblemCount)|\(data.widgetProblemCount)"

            defaults.set(encoded, forKey: userDefaultsKey)
            // Note: synchronize() removed - macOS handles flushing automatically
            // This avoids synchronous disk I/O on every save, improving battery life

            // Only reload widget if data actually changed
            #if canImport(WidgetKit)
            if signature != lastSavedSignature {
                lastSavedSignature = signature
                DispatchQueue.main.async {
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
            #endif
        } catch {
            // Silently fail - widget will use stale data
        }
    }

    func loadData() -> SharedZabbixData {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: userDefaultsKey) else {
            return .empty
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            return try decoder.decode(SharedZabbixData.self, from: data)
        } catch {
            return .empty
        }
    }
}
