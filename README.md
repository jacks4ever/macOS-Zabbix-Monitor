# macOS Zabbix Monitor

A macOS SwiftUI menu bar application for monitoring Zabbix server alerts with an AI-powered desktop widget.

![macOS](https://img.shields.io/badge/macOS-Sequoia-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-WidgetKit-green)

## Features

### Menu Bar App
- **Real-time Problem Count**: Displays current Zabbix problem count in the macOS menu bar
- **Severity-based Colors**: Menu bar icon color reflects highest severity (Purple=Disaster, Red=High, Orange=Average, Yellow=Warning, Blue=Info, Green=OK)
- **Problems Tab**: View all active problems with severity indicators and timestamps
- **Hosts Tab**: Browse all monitored hosts with problem count badges
- **Problem Acknowledgement**: Right-click to acknowledge problems with optional messages
- **Host Search**: Filter hosts by name with instant search

### Host Monitoring
- **Smart Host Icons**: Automatic SF Symbol icon assignment based on host naming patterns:
  - Network devices (routers, switches, firewalls)
  - Servers and VMs
  - Smart home devices (lights, thermostats, cameras)
  - Entertainment devices (TVs, speakers, gaming consoles)
  - Appliances and more
- **Custom Icons**: Right-click any host to manually override with any available SF Symbol
- **Problem Badges**: Click on problem count badges to see detailed error information
- **Flexible Sorting**: Sort hosts alphabetically or by problem severity (bidirectional)

### Desktop Widget
- **Multiple Sizes**: Small, Medium, and Large widget options
- **AI Summaries**: Generate concise problem summaries using your choice of AI provider
- **Problem List**: Shows top problems with severity icons when AI is disabled
- **Real-time Updates**: Syncs with menu bar app via App Groups

### AI Integration
- **Multiple Providers**:
  - Ollama (local/self-hosted LLM)
  - OpenAI (GPT-4, GPT-3.5-turbo)
  - Anthropic (Claude models)
  - Disable AI (shows raw problems instead)
- **Configurable Models**: Choose your preferred model for each provider
- **Test Connection**: Verify AI provider connectivity from Settings

### Filtering & Customization
- **Severity Filtering**: Independent filters for menu bar and widget
  - Disaster, High, Average, Warning, Information, Not Classified
- **Problem Sorting**: Sort by Criticality, Latest, or Alphabetical
- **Auto-Refresh**: Configurable intervals (5 seconds to 5 minutes, or manual only)

### Security
- **Keychain Storage**: Credentials stored securely in macOS Keychain
- **Self-Signed Certificates**: Optional support for local network servers with self-signed SSL
- **Session Management**: Logout clears all saved credentials

### Localization
- **8 Languages Supported**: English, Spanish, French, German, Chinese (Simplified), Japanese, Latvian, and Russian
- **Language Selection**: Choose your preferred language in Settings
- **Full UI Translation**: All menus, settings, severity labels, and widget text are localized

## Screenshots

The menu bar icon shows the current problem count, color-coded by severity:
- Purple: Disaster (severity 5)
- Red: High (severity 4)
- Orange: Average (severity 3)
- Yellow: Warning (severity 2)
- Blue: Information (severity 1)
- Green: No active problems

## Requirements

- macOS Sequoia or later
- Xcode 15+
- A Zabbix server with API access (Zabbix 6.4+ recommended)
- (Optional) AI provider for summaries: Ollama (local), OpenAI, or Anthropic

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

3. Build and run (`Cmd+R`)

4. Configure via the menu bar app's Settings

## Configuration

All settings are configurable through the app's Settings panel (accessible via the menu bar dropdown):

### Connection Tab
- **Zabbix Server URL**: Your Zabbix API endpoint (e.g., `https://your-zabbix-server/api_jsonrpc.php`)
- **Username**: Zabbix API username
- **Refresh Interval**: How often to fetch updates (5 seconds to 5 minutes)
- **Problem Sort Order**: Criticality, Latest, or Alphabetical

### Filters Tab
- **Menu Bar Severity**: Choose which severity levels appear in the menu bar
- **Widget Severity**: Independent severity filter for the desktop widget

### Security Tab
- **Self-Signed Certificates**: Enable for local network servers
- **Authentication Status**: View connection status and clear saved credentials

### AI Tab
- **Provider Selection**: Choose between Disabled, Ollama, OpenAI, or Anthropic
- **Provider Settings**: Configure server URLs, API keys, and model selection
- **Test AI**: Verify your AI provider connection

## Architecture

### Targets
- **ZabbixMenuBar** - Main menu bar application
- **ZabbixWidget** - WidgetKit extension for desktop widget

### Key Files
- `ZabbixMenuBar/ZabbixAPIClient.swift` - Zabbix API client, AI provider integration, Keychain storage
- `ZabbixMenuBar/ZabbixStatusView.swift` - Main UI with Problems/Hosts tabs, smart icon detection
- `ZabbixMenuBar/SettingsView.swift` - Settings UI with Connection, Filters, Security, AI, Language, and About tabs
- `ZabbixWidget/ZabbixWidget.swift` - Widget views (small, medium, large)
- `Shared/SharedData.swift` - Data sharing between app and widget via App Groups
- `Shared/AppLanguage.swift` - Language enum and manager for localization
- `Shared/Localizable.xcstrings` - String Catalog with translations (8 languages)

## Adding the Widget

1. Right-click on the desktop
2. Select "Edit Widgets..."
3. Search for "Zabbix"
4. Drag the widget to your desktop (available in Small, Medium, and Large sizes)

## Technical Notes

### Zabbix API
- Uses `trigger.get` with `value=1` filter for real-time problem state (more reliable than `problem.get`)
- Supports Zabbix 6.4+ Bearer token authentication
- Disables caching to ensure fresh data on every request

### Widget Data Sharing
- Uses App Groups with Team ID prefix format required by macOS Sequoia
- Data stored in `~/Library/Group Containers/[TeamID].com.zabbixmenubar/`

## Disclaimer

This project is an independent, unofficial application and is not affiliated with, endorsed by, or connected to Zabbix SIA or the Zabbix project in any way. "Zabbix" is a registered trademark of Zabbix SIA. This application is a third-party tool that interfaces with the Zabbix API for personal monitoring purposes.

## License

MIT License

---

Made with love in Colorado, USA
