import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct ZabbixProvider: TimelineProvider {
    func placeholder(in context: Context) -> ZabbixEntry {
        ZabbixEntry(date: Date(), problemCount: 0, problems: [], aiSummary: "", isConfigured: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (ZabbixEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ZabbixEntry>) -> Void) {
        let entry = loadEntry()

        // Refresh every 1 minute to stay in sync with the menu bar app
        // Note: macOS may throttle this to save battery, but the app also triggers
        // reloadAllTimelines() when data changes for immediate updates
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> ZabbixEntry {
        // Try to load from shared data
        let data = SharedDataManager.shared.loadData()
        let hasData = !data.serverURL.isEmpty

        if hasData {
            // Filter problems based on user's severity filter settings
            let filteredProblems = data.problems.filter { data.severityFilter.includes(severity: $0.severity) }

            // Sort by severity (highest first), then by timestamp (most recent first)
            let sortedProblems = filteredProblems.sorted { a, b in
                if a.severity != b.severity {
                    return a.severity > b.severity
                }
                return a.timestamp > b.timestamp
            }

            let problems = sortedProblems.map { p in
                WidgetProblem(id: p.eventid, name: p.name, severity: p.severity, timestamp: p.timestamp)
            }
            return ZabbixEntry(
                date: Date(),
                problemCount: filteredProblems.count,
                problems: problems,
                aiSummary: data.aiSummary,
                isConfigured: true
            )
        }

        // If no shared data, show "All Clear" as default (widget is working)
        // This helps debug - if you see "All Clear", widget works but data sharing doesn't
        return ZabbixEntry(
            date: Date(),
            problemCount: 0,
            problems: [],
            aiSummary: "",
            isConfigured: true  // Always show as configured so we can see widget content
        )
    }
}

// MARK: - Simple Problem struct for widget

struct WidgetProblem: Identifiable {
    let id: String
    let name: String
    let severity: Int
    let timestamp: Date

    var color: Color {
        switch severity {
        case 5: return .purple
        case 4: return .red
        case 3: return .orange
        case 2: return .yellow
        case 1: return .blue
        default: return .gray
        }
    }

    var severityIcon: String {
        switch severity {
        case 5: return "exclamationmark.octagon.fill"  // Disaster
        case 4: return "exclamationmark.triangle.fill" // High
        case 3: return "exclamationmark.circle.fill"   // Average
        case 2: return "info.circle.fill"              // Warning
        case 1: return "info.circle"                   // Information
        default: return "questionmark.circle"          // Not Classified
        }
    }
}

// MARK: - Timeline Entry

struct ZabbixEntry: TimelineEntry {
    let date: Date
    let problemCount: Int
    let problems: [WidgetProblem]
    let aiSummary: String
    let isConfigured: Bool
}

// MARK: - Widget View

struct ZabbixWidgetEntryView: View {
    var entry: ZabbixEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallView
            case .systemMedium:
                mediumView
            case .systemLarge:
                largeView
            default:
                smallView
            }
        }
        .containerBackground(Color(nsColor: .windowBackgroundColor), for: .widget)
    }

    // MARK: - Small Widget

    var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image("ZabbixIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                Text("Zabbix")
                    .font(.headline)
            }

            Spacer()

            if !entry.isConfigured {
                VStack(spacing: 4) {
                    Image(systemName: "gear")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("Open app to setup")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            } else if entry.problemCount == 0 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("All Clear")
                        .font(.title3)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(entry.problemCount)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(maxSeverityColor)
                    Text(entry.problemCount == 1 ? "Problem" : "Problems")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Medium Widget

    var mediumView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image("ZabbixIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                    Text("Zabbix")
                        .font(.headline)
                }

                Spacer()

                if !entry.isConfigured {
                    Text("Open app to setup")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if entry.problemCount == 0 {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("All Clear")
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(entry.problemCount)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(maxSeverityColor)
                        Text(entry.problemCount == 1 ? "Problem" : "Problems")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }

            if entry.isConfigured && entry.problemCount > 0 {
                Divider()

                if !entry.aiSummary.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI Summary")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Text(entry.aiSummary)
                            .font(.caption2)
                            .minimumScaleFactor(0.8)
                    }
                } else {
                    // Show problem list when AI is disabled
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Active Problems")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        ForEach(entry.problems.prefix(3)) { problem in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(problem.color)
                                    .frame(width: 6, height: 6)
                                Text(problem.name)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            } else if entry.isConfigured && !entry.aiSummary.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Summary")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Text(entry.aiSummary)
                        .font(.caption2)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .padding()
    }

    // MARK: - Large Widget

    var largeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image("ZabbixIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                Text("Zabbix Monitor")
                    .font(.headline)

                Spacer()

                if entry.isConfigured {
                    if entry.problemCount == 0 {
                        Label("All Clear", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("\(entry.problemCount) \(entry.problemCount == 1 ? "Problem" : "Problems")")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(maxSeverityColor.opacity(0.2))
                            .foregroundColor(maxSeverityColor)
                            .cornerRadius(8)
                    }
                }
            }

            Divider()

            if !entry.isConfigured {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "gear")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Open app to setup")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                if entry.problemCount == 0 {
                    // No problems
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("All systems operational")
                                .font(.body)
                        }
                    }
                    Spacer()
                } else {
                    // Has problems - show AI summary if available, then problem list
                    if !entry.aiSummary.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AI Analysis")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            Text(entry.aiSummary)
                                .font(.caption)
                                .lineLimit(3)
                                .minimumScaleFactor(0.8)
                        }

                        Divider()
                    }

                    // Always show top 5 problems with severity icons
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Top Problems")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        ForEach(entry.problems.prefix(5)) { problem in
                            HStack(spacing: 6) {
                                Image(systemName: problem.severityIcon)
                                    .font(.system(size: 12))
                                    .foregroundColor(problem.color)
                                    .frame(width: 14)
                                Text(problem.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer()
                            }
                        }

                        if entry.problems.count > 5 {
                            Text("+ \(entry.problems.count - 5) more...")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                }
            }
        }
        .padding()
    }

    var maxSeverityColor: Color {
        // Find the highest severity problem and return its color
        guard let maxSeverity = entry.problems.map({ $0.severity }).max() else {
            return .blue
        }
        switch maxSeverity {
        case 5: return .purple
        case 4: return .red
        case 3: return .orange
        case 2: return .yellow
        case 1: return .blue
        default: return .gray
        }
    }
}

// MARK: - Widget Configuration

struct ZabbixWidget: Widget {
    let kind: String = "ZabbixWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ZabbixProvider()) { entry in
            ZabbixWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Zabbix Monitor")
        .description("View active problems from your Zabbix server.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    ZabbixWidget()
} timeline: {
    ZabbixEntry(date: Date(), problemCount: 3, problems: [
        WidgetProblem(id: "1", name: "High CPU usage", severity: 4, timestamp: Date()),
        WidgetProblem(id: "2", name: "Disk space low", severity: 3, timestamp: Date().addingTimeInterval(-60)),
        WidgetProblem(id: "3", name: "Memory warning", severity: 2, timestamp: Date().addingTimeInterval(-120))
    ], aiSummary: "Server performance degraded - check CPU load and disk space on primary servers.", isConfigured: true)
}
