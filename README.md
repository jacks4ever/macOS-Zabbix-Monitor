# macOS-Zabbix-Monitor

A macOS SwiftUI menu bar application for monitoring Zabbix server alerts with an AI-powered desktop widget.

![macOS](https://img.shields.io/badge/macOS-Sequoia-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-WidgetKit-green)

## Features

- **Menu Bar App**: Displays real-time Zabbix problem count in the macOS menu bar
- **Desktop Widget**: Shows high-severity alerts (High/Disaster) with multiple size options
- **AI Summaries**: Uses local Ollama LLM to generate concise problem summaries
- **Auto-Refresh**: Configurable refresh intervals (5 seconds to 5 minutes)
- **Host Monitoring**: View all hosts with problem count badges and severity indicators
- **Problem Details**: Click on host problem badges to see detailed error information
- **Flexible Sorting**: Sort hosts alphabetically or by problem severity (bidirectional)
- **Severity Filtering**: Filter problems by severity level (Disaster, High, Average, Warning, Info)
- **Custom Host Icons**: Assign custom SF Symbol icons to hosts for easy identification

## Screenshots

The menu bar icon shows the current problem count, color-coded by severity:
- Red: Disaster-level problems
- Orange: High-severity problems
- Green: No active problems

## Requirements

- macOS Sequoia or later
- Xcode 15+
- A Zabbix server with API access
- (Optional) Ollama server for AI summaries

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/jacks4ever/macOS-Zabbix-Monitor.git
   ```

2. Open the project in Xcode:
   ```bash
   cd macOS-Zabbix-Monitor
   open ZabbixMenuBar.xcodeproj
   ```

3. Update the configuration in `ZabbixAPIClient.swift` with your Zabbix server details

4. Build and run (`Cmd+R`)

## Configuration

Edit the following values in `ZabbixAPIClient.swift`:

```swift
// Zabbix API endpoint
let zabbixURL = "https://your-zabbix-server/api_jsonrpc.php"

// Ollama server (optional, for AI summaries)
let ollamaURL = "http://your-ollama-server:11434"
let ollamaModel = "mistral:7b"
```

## Architecture

### Targets
- **ZabbixMenuBar** - Main menu bar application
- **ZabbixWidget** - WidgetKit extension for desktop widget

### Key Files
- `ZabbixMenuBar/ZabbixAPIClient.swift` - Zabbix API client and Ollama integration
- `ZabbixMenuBar/ZabbixMenuBarApp.swift` - Main app entry point
- `ZabbixWidget/ZabbixWidget.swift` - Widget views (small, medium, large)
- `Shared/SharedData.swift` - Data sharing between app and widget via App Groups

## Build & Deploy

1. Clean build: `Cmd+Shift+K`
2. Build: `Cmd+B`
3. Copy to Applications:
   ```bash
   cp -R ~/Library/Developer/Xcode/DerivedData/ZabbixMenuBar-*/Build/Products/Debug/ZabbixMenuBar.app /Applications/
   ```
4. Launch: `open /Applications/ZabbixMenuBar.app`

## Adding the Widget

1. Right-click on the desktop
2. Select "Edit Widgets..."
3. Search for "Zabbix"
4. Drag the widget to your desktop

## Disclaimer

This project is an independent, unofficial application and is not affiliated with, endorsed by, or connected to Zabbix SIA or the Zabbix project in any way. "Zabbix" is a registered trademark of Zabbix SIA. This application is a third-party tool that interfaces with the Zabbix API for personal monitoring purposes.

## License

MIT License
