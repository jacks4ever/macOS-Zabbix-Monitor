import SwiftUI
import ServiceManagement

@main
struct ZabbixMenuBarApp: App {
    @StateObject private var zabbixClient = ZabbixAPIClient()
    @ObservedObject private var languageManager = LanguageManager.shared

    init() {
        // Ensure login item is registered with the correct app name
        registerLoginItem()
    }

    var body: some Scene {
        MenuBarExtra {
            ZabbixStatusView()
                .environmentObject(zabbixClient)
                .frame(width: 400, height: 500)
                .environment(\.colorScheme, .dark)
                .environment(\.locale, languageManager.effectiveLocale)
        } label: {
            Image(nsImage: {
                let image = NSImage(systemSymbolName: "z.square.fill", accessibilityDescription: "Zabbix")!
                image.isTemplate = true
                let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
                return image.withSymbolConfiguration(config)!
            }())
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(zabbixClient)
                .environment(\.locale, languageManager.effectiveLocale)
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

// MARK: - Login Item Management

private func registerLoginItem() {
    // Check if there's a migration needed from old login item name
    let script = """
    tell application "System Events"
        set loginItemNames to name of every login item
        if loginItemNames contains "ZabbixMenuBar" then
            delete login item "ZabbixMenuBar"
        end if

        -- Check if current app is already registered
        if loginItemNames does not contain "Zabbix Monitor" then
            make login item at end with properties {path:"/Applications/Zabbix Monitor.app", hidden:false}
        end if
    end tell
    """

    var error: NSDictionary?
    if let appleScript = NSAppleScript(source: script) {
        appleScript.executeAndReturnError(&error)
        if let error = error {
            print("Login item registration warning: \(error)")
        }
    }
}
