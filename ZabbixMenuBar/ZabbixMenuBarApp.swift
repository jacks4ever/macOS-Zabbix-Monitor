import SwiftUI

@main
struct ZabbixMenuBarApp: App {
    @StateObject private var zabbixClient = ZabbixAPIClient()

    var body: some Scene {
        MenuBarExtra("Zabbix", systemImage: "z.square.fill") {
            ZabbixStatusView()
                .environmentObject(zabbixClient)
                .frame(width: 400, height: 500)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(zabbixClient)
        }
    }
}

struct MenuBarIcon: View {
    let problemCount: Int
    let hasError: Bool

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: hasError ? "exclamationmark.triangle" : "z.square.fill")
            if problemCount > 0 {
                Text("\(problemCount)")
                    .font(.caption2)
            }
        }
    }
}
