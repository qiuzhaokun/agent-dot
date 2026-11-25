#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-${AGENTDOT_VERSION:-}}"
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "usage: package-release.sh <major.minor.patch>" >&2
  exit 2
fi
if [ -z "${AGENTDOT_UPDATE_PRIVATE_KEY:-}" ]; then
  echo "AGENTDOT_UPDATE_PRIVATE_KEY is required" >&2
  exit 1
fi
NOTES="${AGENTDOT_RELEASE_NOTES:-AgentDot $VERSION}"

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
chmod 755 "$APP/Contents/MacOS/AgentDot" \
  "$APP/Contents/Helpers/dot-hook" \
  "$APP/Contents/Helpers/AgentDotUpdater"

plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$VERSION" "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"

ZIP="dist/AgentDot-$VERSION.zip"
DMG="dist/AgentDot-$VERSION.dmg"
rm -f "$ZIP" "$DMG"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

STAGING="dist/dmg-staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
cat > "$STAGING/README.txt" <<EOF
AgentDot $VERSION

首次安装：
1. 双击 AgentDot.app。
2. 如果 macOS 提示无法验证，右键点击 → 打开（或系统设置 → 隐私与安全性 → 仍要打开）。
3. 应用会提示安装到 ~/Applications，点击“安装”。
4. 在面板中点击“修复 Hooks”安装 Claude Code hooks。
5. 可在设置里开启“开机自启”。

自动更新：
应用会自动检查新版本；点击“升级”后自动下载、校验、替换并重启。
首次从本 DMG 打开需要右键打开一次；这是 ad-hoc 签名在 Gatekeeper 下的限制。
EOF
hdiutil create -volname "AgentDot" -srcfolder "$STAGING" \
  -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"

SHA_ZIP=$(shasum -a 256 "$ZIP" | awk '{print $1}')
SHA_DMG=$(shasum -a 256 "$DMG" | awk '{print $1}')
SIZE=$(stat -f%z "$ZIP")
PUBLIC_KEY=$(plutil -extract AgentDotUpdatePublicKey raw -o - "$APP/Contents/Info.plist")
SIGNATURE=$(AGENTDOT_UPDATE_PRIVATE_KEY="$AGENTDOT_UPDATE_PRIVATE_KEY" \
  swift scripts/sign-update.swift "$ZIP")
swift scripts/verify-update.swift "$ZIP" "$SIGNATURE" "$PUBLIC_KEY" >/dev/null

ZIP_URL="https://github.com/qiuzhaokun/agent-dot/releases/download/v$VERSION/AgentDot-$VERSION.zip"
DMG_URL="https://github.com/qiuzhaokun/agent-dot/releases/download/v$VERSION/AgentDot-$VERSION.dmg"
RELEASE_PAGE="https://github.com/qiuzhaokun/agent-dot/releases/tag/v$VERSION"

python3 - "$VERSION" "$ZIP_URL" "$DMG_URL" "$RELEASE_PAGE" \
  "$SHA_ZIP" "$SIZE" "$SIGNATURE" "$NOTES" > dist/latest.json <<'PY'
import datetime
import json
import sys

version, zip_url, dmg_url, release_page, sha, size, signature, notes = sys.argv[1:]
print(json.dumps({
    "schema": 1,
    "version": version,
    "minimum_macos": "13.0",
    "zip_url": zip_url,
    "dmg_url": dmg_url,
    "release_page": release_page,
    "sha256": sha,
    "size": int(size),
    "signature": signature,
    "published_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "notes": notes,
}, ensure_ascii=False, indent=2))
PY

printf '%s  %s\n%s  %s\n' \
  "$SHA_ZIP" "AgentDot-$VERSION.zip" \
  "$SHA_DMG" "AgentDot-$VERSION.dmg" > dist/SHA256SUMS

echo "built $ZIP, $DMG, dist/latest.json, dist/SHA256SUMS"
