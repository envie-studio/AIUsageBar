# AIUsageBar

> Track your AI usage across multiple providers right from your Mac menu bar!

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![macOS](https://img.shields.io/badge/macOS-12.0+-blue.svg)](https://www.apple.com/macos/)

A lightweight, open-source macOS menu bar application that displays your AI usage limits across multiple providers with real-time updates and notifications.

## 📥 Download

**[Download Latest Release](https://github.com/miguelgbandeira/AIUsageBar/releases)** (ZIP Archive)

## 📦 Set Up (1mn)

### Claude Provider
Go to [claude.ai/settings/usage](https://claude.ai/settings/usage) from browser, open Developer Tools (Cmd+Option+I), go to the Network tab, refresh the page, click the "usage" request, and copy the full "Cookie" value from the Request Headers.

### Other Providers
Each provider has its own authentication method. Configure credentials in the app's settings panel.

## ✨ Features

- 🌐 **Multi-provider support** - Track usage across Claude, Zhipu/Z.ai, Codex, and more
- 🔌 **Extensible architecture** - Easy to add new AI providers
- 🟢 **Real-time usage tracking** - Monitor session and usage limits
- 🎨 **Color-coded menu bar icon** - Visual spark icon that changes color (green/yellow/red)
- 🔔 **Smart notifications** - Alerts at 25%, 50%, 75%, 90% usage thresholds
- ⌨️ **Keyboard shortcut** - Toggle popup with Cmd+U from anywhere
- ⚡ **Auto-refresh** - Updates every 5 minutes automatically
- 🔒 **Privacy-first** - All data stored locally on your Mac
- 📊 **Pro plan support** - Shows weekly Sonnet usage for Claude Pro subscribers
- 🎯 **Menu bar only** - No Dock icon, stays out of your way
- 🔄 **Auto-update** - Checks for new versions automatically

[See full feature list →](app/README.md)

## 🚀 Quick Start

1. **Download** the latest ZIP from [Releases](https://github.com/miguelgbandeira/AIUsageBar/releases)
2. **Extract** and drag AIUsageBar to Applications folder
3. **Launch** AIUsageBar from Applications
4. **Configure providers** - Set up credentials for your AI providers
5. **Done!** Usage appears in menu bar

## 📸 Screenshots

**Menu Bar Display:**
```
⚡ 45%  (Green spark icon when usage < 70%)
```

**Popup Interface:**
- Provider cards showing usage for each configured service
- Session and limit usage with progress bars
- Settings for notifications and shortcuts

## 📁 Repository Structure

```
app/
├── AIUsageBar.swift         - Main application entry point
├── Core/
│   ├── Providers/           - AI provider implementations
│   │   ├── UsageProvider.swift      - Provider protocol
│   │   ├── ClaudeWebProvider.swift  - Claude.ai provider
│   │   ├── ZhipuProvider.swift      - Zhipu/Z.ai provider
│   │   └── CodexProvider.swift      - Codex provider
│   ├── UsageManager.swift   - Usage tracking coordinator
│   ├── CredentialManager.swift - Secure credential storage
│   └── UpdateChecker.swift  - Auto-update functionality
├── Models/
│   ├── UsageData.swift      - Usage data models
│   └── Settings.swift       - App settings
└── UI/
    ├── UsageView.swift      - Main popup view
    ├── ProviderCardView.swift - Provider usage cards
    └── SettingsView.swift   - Settings panel
website/                     - Landing page (HTML/CSS)
```

## 🛠️ Build from Source

**Requirements:**
- macOS 12.0 (Monterey) or later
- Xcode Command Line Tools

**Build the app:**
```bash
cd app
chmod +x build.sh
./build.sh
```

The built app will be in `app/build/AIUsageBar.app`

## 🔧 Development

### Adding a New Provider

1. Create a new file in `app/Core/Providers/`
2. Implement the `UsageProvider` protocol
3. Register the provider in `UsageManager.swift`

### Key Technologies

- **SwiftUI** - Modern macOS UI framework
- **AppKit** - Menu bar integration
- **Carbon** - Global keyboard shortcuts
- **NSUserNotification** - System notifications (no permissions needed)

## 🤝 Contributing

Contributions are welcome! Here's how you can help:

- 🐛 Report bugs via [Issues](https://github.com/miguelgbandeira/AIUsageBar/issues)
- 💡 Suggest features or improvements
- 🔧 Submit pull requests
- 📖 Improve documentation
- 🔌 Add support for new AI providers

## 📄 License

MIT License - see [LICENSE](LICENSE) for details

## ⚠️ Disclaimer

This app uses internal API endpoints from various AI providers which may change without notice. It is not affiliated with or endorsed by Anthropic, Zhipu, or any other AI provider. Use at your own risk.

## 🙏 Acknowledgments

This project is a fork of [ClaudeUsageBar](https://github.com/Artzainnn/ClaudeUsageBar) by [@Artzainnn](https://github.com/Artzainnn).
Thanks for creating the original app and making it open source!

## 🙏 Support

If you find this useful, consider:
- ⭐ Starring this repository
- 📢 Sharing with others who use AI tools
- ☕ [Buy me a coffee](https://buymeacoffee.com/miguelgbandeira)

## 🔗 Links

- **Issues:** [GitHub Issues](https://github.com/miguelgbandeira/AIUsageBar/issues)
- **Releases:** [GitHub Releases](https://github.com/miguelgbandeira/AIUsageBar/releases)

---

**Made with ❤️ for the AI community**
