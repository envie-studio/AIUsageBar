# Homebrew Submission Instructions for AIUsageBar

## ✅ Phase 1 & 2 Complete!

Your Homebrew cask has been created and successfully tested locally!

## 📦 What's Been Done

1. ✅ Created `Casks/a/aiusagebar.rb` with the complete formula
2. ✅ Tested installation via Homebrew
3. ✅ Verified app signature and notarization
4. ✅ Tested uninstallation
5. ✅ Created automation workflow for future releases

## 🚀 Phase 3: Submit to Official Homebrew (Your Action Required)

Follow these steps to submit your cask:

### Step 1: Fork Homebrew
```bash
# Visit this URL in your browser:
https://github.com/Homebrew/homebrew-cask/fork
```

### Step 2: Clone and Set Up
```bash
# Clone your fork (replace YOUR_USERNAME with your GitHub username)
git clone https://github.com/YOUR_USERNAME/homebrew-cask.git
cd homebrew-cask

# Create a new branch
git checkout -b aiusagebar-1.0.5
```

### Step 3: Add Your Cask
```bash
# Create the Casks/a directory if it doesn't exist
mkdir -p Casks/a

# Copy your cask file
cp /Users/miguelbandeira/Projects/dev/AIUsageBar/Casks/a/aiusagebar.rb Casks/a/aiusagebar.rb

# Commit the changes
git add Casks/a/aiusagebar.rb
git commit -m "aiusagebar 1.0.5 (new formula)"
```

### Step 4: Push and Create PR
```bash
# Push to your fork
git push -u origin aiusagebar-1.0.5

# Create the PR (this will open your browser)
gh pr create --repo Homebrew/homebrew-cask \
  --title "aiusagebar 1.0.5 (new formula)" \
  --body "Track AI usage across multiple providers from your menu bar

- Supports Claude, Zhipu/Z.ai, Codex providers
- Real-time usage tracking with notifications
- Auto-updates enabled
- Built for macOS 12.0+

Homepage: https://github.com/miguelgbandeira/AIUsageBar"
```

## 📋 PR Description Template

When creating your PR, use this description:

```
AIUsageBar: Track AI usage across multiple providers from your menu bar

**Features:**
- Multi-provider support (Claude, Zhipu/Z.ai, Codex)
- Real-time usage tracking with color-coded indicators
- Smart notifications at 25%, 50%, 75%, 90% thresholds
- Keyboard shortcut (Cmd+U) for quick access
- Auto-refresh every 5 minutes
- Privacy-first design (local storage only)
- Built-in auto-update mechanism

**Technical Details:**
- macOS 12.0+ required (Monterey and later)
- Universal binary (arm64 + x86_64)
- Signed and notarized
- SHA256 verified downloads
- Uses `.zip` distribution format

**Homepage:** https://github.com/miguelgbandeira/AIUsageBar
```

## ⏱️ What to Expect

1. **Automated Checks**: Homebrew will run CI checks (typically 5-15 minutes)
2. **Human Review**: Homebrew maintainers will review your PR (2-7 days)
3. **Feedback**: They may request changes or clarifications
4. **Approval**: Once approved, your cask will be merged

## 🎉 After Approval

Users will be able to install AIUsageBar with:

```bash
brew install --cask aiusagebar
```

## 🔄 Future Updates

The GitHub Actions workflow at `.github/workflows/update-homebrew-cask.yml` will automatically:
- Trigger on new GitHub releases
- Calculate SHA256 checksum
- Create PR to update the Homebrew cask
- Submit to Homebrew for review

**Note:** You'll need to configure this workflow with your GitHub token permissions.

## 📞 Need Help?

- Homebrew Cask Documentation: https://docs.brew.sh/Cask-Cookbook
- Cask Contributing Guide: https://github.com/Homebrew/homebrew-cask/blob/master/CONTRIBUTING.md
- Homebrew Discord: https://discord.gg/zZ7sZ2w

---

**Your cask is ready!** Good luck with the submission! 🚀
