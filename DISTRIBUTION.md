# Distribution Guide for AIUsageBar

## Distribution Options

### 1. GitHub Releases (Recommended for personal/small audience)
The simplest approach for a forked project.

```bash
# Build the app
cd app && ./build.sh

# Create a zip for distribution
cd build
zip -r AIUsageBar-v1.0.0.zip ClaudeUsageBar.app
```

Then create a GitHub Release:
1. Go to your repo → Releases → "Create a new release"
2. Tag version (e.g., `v1.0.0`)
3. Upload the `.zip` file
4. Users download and drag to `/Applications`

**Pros:** Free, simple, no Apple Developer account needed
**Cons:** Users see "unidentified developer" warning (right-click → Open to bypass)

### 2. Notarized Distribution (Recommended for wider audience)
Requires Apple Developer account ($99/year).

```bash
# Build the app
cd app && ./build.sh

# Create a zip for notarization
ditto -c -k --keepParent build/ClaudeUsageBar.app ClaudeUsageBar.zip

# Submit for notarization
xcrun notarytool submit ClaudeUsageBar.zip \
  --apple-id "your@email.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "app-specific-password" \
  --wait

# Staple the ticket
xcrun stapler staple build/ClaudeUsageBar.app
```

**Pros:** No security warnings, trusted by macOS
**Cons:** Requires paid developer account

### 3. Homebrew Cask (For developer audience)
Create a Homebrew tap for easy installation.

1. Create a new repo: `homebrew-tap`
2. Add a cask formula:

```ruby
# Casks/aiusagebar.rb
cask "aiusagebar" do
  version "1.0.0"
  sha256 "SHA256_OF_ZIP"

  url "https://github.com/miguelgbandeira/AIUsageBar/releases/download/v#{version}/AIUsageBar-v#{version}.zip"
  name "AIUsageBar"
  homepage "https://github.com/miguelgbandeira/AIUsageBar"

  app "ClaudeUsageBar.app"
end
```

Users install with:
```bash
brew tap miguelgbandeira/tap
brew install --cask aiusagebar
```

---

## Handling Updates

### Option A: Manual Check (Current)
Users manually download new versions from GitHub Releases.

### Option B: Sparkle Framework (Recommended)
Add automatic update checking with [Sparkle](https://sparkle-project.org/).

1. Add Sparkle to project
2. Host an `appcast.xml` file:

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>AIUsageBar Updates</title>
    <item>
      <title>Version 1.1.0</title>
      <sparkle:version>1.1.0</sparkle:version>
      <sparkle:shortVersionString>1.1.0</sparkle:shortVersionString>
      <pubDate>Mon, 27 Jan 2025 00:00:00 +0000</pubDate>
      <enclosure
        url="https://github.com/miguelgbandeira/AIUsageBar/releases/download/v1.1.0/AIUsageBar-v1.1.0.zip"
        sparkle:edSignature="SIGNATURE"
        length="1234567"
        type="application/octet-stream"/>
    </item>
  </channel>
</rss>
```

3. App checks for updates on launch or via menu item

### Option C: GitHub API Check (Simple)
Add a simple version check on app launch:

```swift
// Check latest release via GitHub API
let url = URL(string: "https://api.github.com/repos/miguelgbandeira/AIUsageBar/releases/latest")!
// Compare with current version, show alert if update available
```

---

## Fork Considerations

### Syncing with Upstream
If the original repo gets updates you want:

```bash
# Add upstream remote (one time)
git remote add upstream https://github.com/ORIGINAL_OWNER/ORIGINAL_REPO.git

# Fetch and merge updates
git fetch upstream
git merge upstream/main
# Resolve any conflicts
```

### Renaming the App
If you want to fully rebrand:

1. Rename `ClaudeUsageBar.app` → `AIUsageBar.app`
2. Update `Info.plist` bundle identifier
3. Update build script
4. Update keychain service name in `CredentialManager.swift`

### License Compliance
- Check the original repo's license
- Keep attribution if required
- Your modifications can have their own license

---

## Quick Start: First Release

```bash
# 1. Build
cd /Users/miguelbandeira/Projects/dev/AIUsageBar/app
./build.sh

# 2. Create release zip
cd build
zip -r ../AIUsageBar-v1.0.0.zip ClaudeUsageBar.app

# 3. Create GitHub release
gh release create v1.0.0 ../AIUsageBar-v1.0.0.zip \
  --title "AIUsageBar v1.0.0" \
  --notes "Initial release with multi-provider support for Claude and Z.ai"
```

Users can then download from:
`https://github.com/miguelgbandeira/AIUsageBar/releases/latest`
