#!/bin/bash

# Build script for AIUsageBar (Multi-Provider Version)

echo "Building AIUsageBar..."

# Create build directory
mkdir -p build

# Create app bundle structure first
APP_NAME="AIUsageBar.app"
APP_PATH="build/$APP_NAME"

mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# Copy Info.plist
cp Info.plist "$APP_PATH/Contents/"

# Create icon if it doesn't exist
if [ ! -f "AIUsageBar.icns" ]; then
    echo "Creating app icon..."
    ./make_app_icon.sh >/dev/null 2>&1
fi

# Copy icon to Resources
if [ -f "AIUsageBar.icns" ]; then
    cp AIUsageBar.icns "$APP_PATH/Contents/Resources/"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AIUsageBar" "$APP_PATH/Contents/Info.plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AIUsageBar" "$APP_PATH/Contents/Info.plist"
fi

# Define all Swift source files (order matters for dependencies)
SWIFT_FILES=(
    "Models/UsageData.swift"
    "Models/Settings.swift"
    "Models/TabState.swift"
    "Core/Providers/UsageProvider.swift"
    "Core/CredentialManager.swift"
    "Core/Providers/ClaudeWebProvider.swift"
    "Core/Providers/ZhipuProvider.swift"
    "Core/Providers/CodexProvider.swift"
    "Core/Providers/CursorProvider.swift"
    "Core/Providers/KimiK2Provider.swift"
    "Core/UsageManager.swift"
    "Core/UpdateChecker.swift"
    "UI/Components/TabButton.swift"
    "UI/Components/TabBar.swift"
    "UI/Components/CompactProviderCard.swift"
    "UI/ProviderCardView.swift"
    "UI/Tabs/OverviewTabView.swift"
    "UI/Tabs/ProviderDetailTabView.swift"
    "UI/SettingsView.swift"
    "UI/UsageView.swift"
    "AIUsageBar.swift"
)

# Build the file list
FILE_LIST=""
for file in "${SWIFT_FILES[@]}"; do
    FILE_LIST="$FILE_LIST $file"
done

echo "Compiling Swift files..."
echo "Files: ${SWIFT_FILES[@]}"

# Compile the Swift app for arm64
echo "Building for arm64..."
swiftc -parse-as-library -o "$APP_PATH/Contents/MacOS/AIUsageBar_arm64" \
    $FILE_LIST \
    -framework SwiftUI \
    -framework AppKit \
    -framework WebKit \
    -framework Security \
    -framework Carbon \
    -target arm64-apple-macos12.0 \
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks

if [ $? -ne 0 ]; then
    echo "❌ Failed to build for arm64"
    exit 1
fi

# Compile for x86_64 (Intel)
echo "Building for x86_64..."
swiftc -parse-as-library -o "$APP_PATH/Contents/MacOS/AIUsageBar_x86_64" \
    $FILE_LIST \
    -framework SwiftUI \
    -framework AppKit \
    -framework WebKit \
    -framework Security \
    -framework Carbon \
    -target x86_64-apple-macos12.0 \
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks

if [ $? -ne 0 ]; then
    echo "❌ Failed to build for x86_64"
    exit 1
fi

# Create universal binary
echo "Creating universal binary..."
lipo -create -output "$APP_PATH/Contents/MacOS/AIUsageBar" \
    "$APP_PATH/Contents/MacOS/AIUsageBar_arm64" \
    "$APP_PATH/Contents/MacOS/AIUsageBar_x86_64"

# Clean up individual arch binaries
rm "$APP_PATH/Contents/MacOS/AIUsageBar_arm64"
rm "$APP_PATH/Contents/MacOS/AIUsageBar_x86_64"

# Create PkgInfo file
echo -n "APPL????" > "$APP_PATH/Contents/PkgInfo"

# Set proper permissions first
chmod 755 "$APP_PATH/Contents/MacOS/AIUsageBar"

# Clean extended attributes before signing
xattr -cr "$APP_PATH"

# Sign with Developer ID certificate
DEVELOPER_ID="Developer ID Application: Miguel Bandeira (SRL7W9A4C6)"
if codesign --force --deep --options runtime --sign "$DEVELOPER_ID" "$APP_PATH" 2>/dev/null; then
    echo "✅ App signed with Developer ID"
else
    echo "⚠️  Falling back to ad-hoc signature"
    codesign --force --deep --sign - "$APP_PATH"
fi

echo "✅ Build successful!"
echo "App bundle created at: $APP_PATH"
echo "Launching app..."
open "$APP_PATH"
