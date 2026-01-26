cask "aiusagebar" do
  version "1.0.5"
  sha256 "12270887afed0713ff809825518e9dec6cd9cd9cd682b508b15b86a096b4672a"

  url "https://github.com/envie-studio/AIUsageBar/releases/download/v#{version}/AIUsageBar-v#{version}.zip",
      verified: "github.com/envie-studio/AIUsageBar/"

  name "AIUsageBar"
  desc "Track AI usage across multiple providers from your menu bar"
  homepage "https://github.com/envie-studio/AIUsageBar"

  auto_updates true
  depends_on macos: ">= :monterey"

  app "AIUsageBar.app"

  uninstall quit: "com.aiusagebar"

  zap trash: [
    "~/Library/Preferences/com.aiusagebar.plist",
  ],
      rmdir: [
    "~/Library/Caches/com.aiusagebar",
  ]
end
