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

struct SharedZabbixData: Codable {
    let problems: [SharedProblem]
    let totalProblemCount: Int
    let lastUpdate: Date
    let serverURL: String
    let isAuthenticated: Bool
    let aiSummary: String

    static var empty: SharedZabbixData {
        SharedZabbixData(
            problems: [],
            totalProblemCount: 0,
            lastUpdate: Date(),
            serverURL: "",
            isAuthenticated: false,
            aiSummary: ""
        )
    }
}

// MARK: - Shared Data Manager

class SharedDataManager {
    static let shared = SharedDataManager()

    private let userDefaultsKey = "zabbix_widget_data"

    // Use UserDefaults with Team ID prefixed suite name (Sequoia format)
    private var sharedDefaults: UserDefaults? {
        let defaults = UserDefaults(suiteName: userDefaultsSuite)
        if defaults == nil {
            print("ERROR: Could not create UserDefaults for suite: \(userDefaultsSuite)")
        }
        return defaults
    }

    private init() {}

    func saveData(_ data: SharedZabbixData) {
        guard let defaults = sharedDefaults else {
            print("ERROR: Cannot access shared UserDefaults")
            return
        }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            let encoded = try encoder.encode(data)
            defaults.set(encoded, forKey: userDefaultsKey)
            defaults.synchronize()
            print("Saved widget data to UserDefaults suite: \(userDefaultsSuite)")
            print("  - Problems: \(data.totalProblemCount), Authenticated: \(data.isAuthenticated)")

            // Reload widget timeline on main thread
            #if canImport(WidgetKit)
            DispatchQueue.main.async {
                WidgetCenter.shared.reloadAllTimelines()
                print("Triggered widget timeline reload")
            }
            #endif
        } catch {
            print("ERROR: Failed to save widget data: \(error)")
        }
    }

    func loadData() -> SharedZabbixData {
        guard let defaults = sharedDefaults else {
            print("ERROR: Cannot access shared UserDefaults")
            return .empty
        }

        guard let data = defaults.data(forKey: userDefaultsKey) else {
            print("No data in UserDefaults for key: \(userDefaultsKey)")
            return .empty
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            let decoded = try decoder.decode(SharedZabbixData.self, from: data)
            print("Loaded widget data from UserDefaults: \(decoded.totalProblemCount) problems")
            return decoded
        } catch {
            print("ERROR: Failed to load widget data: \(error)")
            return .empty
        }
    }
}
