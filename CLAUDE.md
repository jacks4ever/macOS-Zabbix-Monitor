# Zabbix Monitor

A macOS SwiftUI menu bar application for monitoring Zabbix server alerts with an AI-powered desktop widget.

## Overview

- **Menu Bar App**: Displays Zabbix problem count in the macOS menu bar
- **Desktop Widget**: Shows high-severity alerts (High/Disaster) with AI-generated summaries
- **AI Integration**: Uses local Ollama LLM to generate concise problem summaries

## Configuration

- **Zabbix Server**: https://192.168.46.183:2443/api_jsonrpc.php
- **Ollama Server**: http://192.168.200.246:11434
- **Ollama Model**: mistral:7b
- **Team ID**: QGG9KJ66D2

## Architecture

### Targets
- `ZabbixMenuBar` - Main menu bar application (builds as "Zabbix Monitor.app")
- `ZabbixWidget` - WidgetKit extension for desktop widget

### Key Files
- `ZabbixMenuBar/ZabbixAPIClient.swift` - Zabbix API client, Ollama integration
- `ZabbixWidget/ZabbixWidget.swift` - Widget views (small, medium, large)
- `Shared/SharedData.swift` - Data sharing between app and widget via App Groups
- `Shared/AppLanguage.swift` - Language enum and manager for localization
- `Shared/Localizable.xcstrings` - String Catalog with translations (8 languages)

## Critical Lessons Learned

### macOS Sequoia App Groups (IMPORTANT)

**Problem**: Widget was not receiving data from the main app. Standard `group.` prefix for App Groups did not work.

**Solution**: macOS Sequoia requires Team ID prefix format for App Groups:

```
WRONG:  group.com.zabbixmenubar.shared
RIGHT:  QGG9KJ66D2.com.zabbixmenubar
```

Both the main app and widget extension must use the identical App Group identifier in:
1. Entitlements files (`com.apple.security.application-groups`)
2. `SharedData.swift` constants (`appGroupContainer`, `userDefaultsSuite`)

### Widget Sandbox Requirement

Widgets REQUIRE `com.apple.security.app-sandbox` to be `YES`. If sandbox is disabled, the widget will not appear in the widget gallery at all.

### Widget Data Sharing

Data is shared via `UserDefaults(suiteName:)` with the Team ID prefixed suite name:
```swift
let userDefaultsSuite = "QGG9KJ66D2.com.zabbixmenubar"
UserDefaults(suiteName: userDefaultsSuite)
```

The shared data is stored at:
```
~/Library/Group Containers/QGG9KJ66D2.com.zabbixmenubar/Library/Preferences/
```

### Async AI Summary Generation

The AI summary is generated asynchronously. The widget data must be saved AFTER the Ollama call completes, not before:

```swift
// Generate AI summary and save data (all done in the async task)
Task {
    await generateAISummary(for: problems)
    // generateAISummary saves shared data after getting the summary
}
```

### Widget Timeline Refresh

Call `WidgetCenter.shared.reloadAllTimelines()` on the main thread after saving data:
```swift
DispatchQueue.main.async {
    WidgetCenter.shared.reloadAllTimelines()
}
```

## Build & Deploy

1. Clean build: `Cmd+Shift+K`
2. Build: `Cmd+B`
3. Copy to Applications:
   ```bash
   cp -R ~/Library/Developer/Xcode/DerivedData/ZabbixMenuBar-*/Build/Products/Debug/"Zabbix Monitor.app" /Applications/
   ```
4. Launch: `open "/Applications/Zabbix Monitor.app"`

## Debugging Widget Issues

Check if data is being saved correctly:
```bash
plutil -extract zabbix_widget_data raw -o - \
  ~/Library/Group\ Containers/QGG9KJ66D2.com.zabbixmenubar/Library/Preferences/QGG9KJ66D2.com.zabbixmenubar.plist
```

If widget shows stale data, remove and re-add the widget from the desktop.

### Widget UI Caching (IMPORTANT)

**Problem**: After changing widget UI elements (icons, colors, layouts), the widget continues to show the old appearance even after:
- Clean build in Xcode
- Removing and re-adding the widget
- Killing NotificationCenter process

**Solution**: macOS aggressively caches widget appearances. To see UI changes in widgets:

1. Clean build in Xcode (`Cmd+Shift+K`)
2. Rebuild (`Cmd+B`)
3. Deploy to `/Applications`
4. Remove the widget from desktop
5. **Log out and log back in** (or restart macOS)
6. Re-add the widget

Simply removing/re-adding the widget is NOT sufficient for UI changes. A full logout/login is required to clear the widget cache.

### Zabbix API: Use trigger.get Instead of problem.get (IMPORTANT)

**Problem**: The `problem.get` API with `"recent": true` returns stale data. Problems that have been resolved in the Zabbix web UI continue to appear in API responses for an extended period.

**Solution**: Use `trigger.get` with `"filter": {"value": 1}` instead. This queries triggers currently in PROBLEM state (value=1), which reflects the actual real-time status shown in the Zabbix web interface.

```swift
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
```

**Key differences**:
- `problem.get` returns historical problem events (can be stale)
- `trigger.get` with `value=1` returns current trigger states (real-time)
- Trigger `priority` maps to problem `severity`
- Trigger `description` maps to problem `name`

### Menu Bar App Timer Issues

**Problem**: Timers created during `init()` may not fire reliably in menu bar apps because the run loop isn't ready.

**Solution**:
1. Defer timer setup using `DispatchQueue.main.asyncAfter`
2. Use `Timer(timeInterval:...)` constructor instead of `Timer.scheduledTimer`
3. Add timer to `.common` run loop mode for menu bar apps

```swift
// Defer timer setup to ensure run loop is ready
DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
    self?.startAutoRefresh()
}

// In setupRefreshTimer():
let timer = Timer(timeInterval: refreshInterval, repeats: true) { ... }
RunLoop.main.add(timer, forMode: .common)
```

### SwiftUI "Publishing changes from within view updates" Warning (IMPORTANT)

**Problem**: When using `@Published` properties in an `ObservableObject` with SwiftUI Picker bindings, changing the picker value triggers the warning:
```
Publishing changes from within view updates is not allowed, this will cause undefined behavior.
```

This happens because:
1. SwiftUI Picker directly modifies the `@Published` property via binding
2. `@Published` publishes on `willSet` (before the value changes)
3. Any Combine subscribers or side effects that modify other `@Published` properties fire synchronously during the view update cycle

**Solution**: Use a custom binding that defers the property write to the next run loop:

```swift
struct AISettingsView: View {
    @EnvironmentObject var client: ZabbixAPIClient

    /// Custom binding that defers writes to avoid "Publishing changes from within view updates"
    private var aiProviderBinding: Binding<AIProvider> {
        Binding(
            get: { client.aiProvider },
            set: { newValue in
                // Defer the write to next run loop to avoid publishing during view update
                DispatchQueue.main.async {
                    client.aiProvider = newValue
                }
            }
        )
    }

    var body: some View {
        Picker("", selection: aiProviderBinding) {  // Use custom binding, not $client.aiProvider
            ForEach(AIProvider.allCases, id: \.self) { provider in
                Text(provider.localizedName).tag(provider)
            }
        }
    }
}
```

**Why this works**: `DispatchQueue.main.async` schedules the property change for the next run loop iteration, after the current SwiftUI view update cycle completes. This breaks the synchronous chain that causes the warning.

**When to use**: Apply this pattern to any Picker (or other control) binding to an `@Published` property that has Combine subscribers or side effects that modify other `@Published` properties.
