# AIUsageBar

> Track your AI usage across multiple providers right from your Mac menu bar!

A lightweight macOS menu bar app that displays your AI usage limits across multiple providers with real-time updates and notifications.

## ✨ Features

- 🌐 **Multi-Provider Support**: Track usage across Claude, Zhipu/Z.ai, Codex, and more
- 🔌 **Extensible Architecture**: Easy to add new AI providers
- 🟢 **Real-time Usage Tracking**: Monitor session and usage limits
- 🎨 **Color-Coded Menu Bar Icon**: Visual indication of usage levels (green/yellow/red)
- 🔔 **Smart Notifications**: Alerts at 25%, 50%, 75%, and 90% usage thresholds
- ⚡ **Auto-Refresh**: Updates every 5 minutes automatically
- ⌨️ **Keyboard Shortcut**: Toggle popup with Cmd+U from anywhere
- 🔒 **Privacy First**: All data stored locally on your Mac
- 📊 **Pro Plan Support**: Shows weekly Sonnet usage for Claude Pro subscribers
- 🎯 **Menu Bar Only**: No Dock icon, stays out of your way
- 🔄 **Auto-Update**: Checks for new versions automatically

## 🖼️ Screenshots

**Menu Bar Display:**
- Shows current session percentage with color-coded emoji
- Example: `🟢 45%` (green < 70%, yellow 70-90%, red > 90%)

**Popup Interface:**
- Provider cards showing usage for each configured service
- Session and limit usage with progress bars
- Settings for notifications and keyboard shortcuts

## 📋 Requirements

- macOS 12.0 (Monterey) or later
- Apple Silicon (M1/M2/M3) or Intel Mac

## 🚀 Installation

### Option 1: ZIP Archive (Recommended)

1. Download `AIUsageBar.zip` from [Releases](../../releases)
2. Extract the ZIP file
3. Drag AIUsageBar.app to Applications folder
4. Open AIUsageBar from Applications

### Option 2: Build from Source

```bash
cd app
chmod +x build.sh
./build.sh
```

The built app will be in `build/AIUsageBar.app`.

## 🔧 First-Time Setup

When you first launch AIUsageBar, you'll see a welcome message. Configure your providers in the settings.

### Claude Provider - Getting Your Session Cookie

1. Go to **Settings > Usage** on claude.ai
2. Press **F12** (or Cmd+Option+I on Mac)
3. Go to **Network** tab in DevTools
4. Refresh the page, click the "usage" request
5. Find **'Cookie'** in Request Headers
6. Copy the **full cookie value** (starts with `anthropic-device-id=...`)

### Adding Cookie to App

1. Click **"Set Session Cookie"** in the app
2. Paste your cookie (Cmd+V works!)
3. Click **"Save Cookie & Fetch"**
4. Your usage will appear immediately!

### Other Providers

Each provider has its own authentication method. Configure credentials in the app's settings panel.

## ⚙️ Settings

Access settings by clicking the gear icon in the popup:

### Notifications
- Enable/disable usage alerts
- Get notifications at 25%, 50%, 75%, 90% thresholds
- Click "Test Notification" to verify it works

### Keyboard Shortcut (Cmd+U)
- Toggle popup from anywhere on your Mac
- Requires Accessibility permission
- Click "Enable Keyboard Shortcut" to grant permission

### Launch at Login
- Start AIUsageBar automatically when you log in

## 🔒 Privacy & Security

- ✅ **All data stays on your Mac** - stored in UserDefaults only
- ✅ **No analytics or tracking** - zero external services
- ✅ **Credentials stored locally** - never sent anywhere except to the respective providers
- ✅ **Open source** - review the code yourself

## 🎯 How It Works

1. Uses your credentials to authenticate with each provider's API
2. Fetches usage data from the same endpoints the websites use
3. Displays real-time usage in your menu bar
4. Sends notifications when you hit usage thresholds

## 🔨 Building

### Build the App
```bash
./build.sh
```

### Clean Build
```bash
rm -rf build
./build.sh
```

## 🐛 Troubleshooting

### "No data yet" showing
- Make sure you've configured your provider credentials
- Click refresh to fetch the latest data
- Verify your credentials are valid

### Cookie expired (Claude)
- Session cookies expire periodically
- Get a new cookie from claude.ai
- Click "Clear Cookie" then re-add it

### Notifications not working
- Click "Test Notification" in Settings
- Notifications work without permission prompts
- Check macOS Focus mode isn't blocking them

### Cmd+U shortcut not working
- Click "Enable Keyboard Shortcut" in Settings
- Grant Accessibility permission in System Settings
- Restart the app after granting permission

### Usage not updating
- App auto-refreshes every 5 minutes
- Click the refresh button to update manually
- If credentials expired, update them

## 🤝 Contributing

Contributions are welcome! Here's how you can help:
- Report bugs via Issues
- Suggest features
- Submit pull requests
- Add support for new AI providers

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details

## ⚠️ Disclaimer

This app uses internal API endpoints from various AI providers which may change without notice. It is not affiliated with or endorsed by Anthropic, Zhipu, or any other AI provider. Use at your own risk.

## 🙏 Acknowledgments

This project is a fork of [ClaudeUsageBar](https://github.com/Artzainnn/ClaudeUsageBar) by [@Artzainnn](https://github.com/Artzainnn).
Thanks for creating the original app and making it open source!

Built with:
- SwiftUI for the interface
- AppKit for menu bar integration
- Carbon for global keyboard shortcuts
- NSUserNotification for alerts

---

**Made with ❤️ for the AI community**
