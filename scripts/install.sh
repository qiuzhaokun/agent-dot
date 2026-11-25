#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

"$ROOT/scripts/build-app.sh"
pkill -x AgentDot 2>/dev/null || true

mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/AgentDot.app"
cp -R "$ROOT/dist/AgentDot.app" "$HOME/Applications/AgentDot.app"

mkdir -p "$HOME/.agent-dot/bin"
cp "$HOME/Applications/AgentDot.app/Contents/Helpers/dot-hook" "$HOME/.agent-dot/bin/dot-hook"
chmod 755 "$HOME/.agent-dot/bin/dot-hook"
"$HOME/.agent-dot/bin/dot-hook" install-hooks

PLIST="$HOME/Library/LaunchAgents/dev.agentdot.app.plist"
mkdir -p "$(dirname "$PLIST")"
cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>dev.agentdot.app</string>
    <key>ProgramArguments</key>
    <array>
        <string>$HOME/Applications/AgentDot.app/Contents/MacOS/AgentDot</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
PLIST_EOF
chmod 644 "$PLIST"
launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null || true

open "$HOME/Applications/AgentDot.app"
echo "Installed AgentDot to $HOME/Applications/AgentDot.app"
echo "Hooks: $HOME/.claude/settings.json (backup created by install-hooks)"
echo "Login item: $PLIST"
