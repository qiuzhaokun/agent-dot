#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product AgentDot
swift build -c release --product dot-hook
swift build -c release --product AgentDotUpdater

APP="dist/AgentDot.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Helpers" "$APP/Contents/Resources"
cp .build/release/AgentDot "$APP/Contents/MacOS/AgentDot"
cp .build/release/dot-hook "$APP/Contents/Helpers/dot-hook"
cp .build/release/AgentDotUpdater "$APP/Contents/Helpers/AgentDotUpdater"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
chmod 755 "$APP/Contents/MacOS/AgentDot" "$APP/Contents/Helpers/dot-hook" "$APP/Contents/Helpers/AgentDotUpdater"

codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
echo "built $APP"
