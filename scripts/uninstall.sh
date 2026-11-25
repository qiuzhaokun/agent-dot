#!/usr/bin/env bash
set -euo pipefail

pkill -x AgentDot 2>/dev/null || true

if [ -x "$HOME/.agent-dot/bin/dot-hook" ]; then
  "$HOME/.agent-dot/bin/dot-hook" uninstall-hooks || true
else
  echo "warning: $HOME/.agent-dot/bin/dot-hook not found; remove AgentDot hooks manually if needed"
fi

PLIST="$HOME/Library/LaunchAgents/dev.agentdot.app.plist"
launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
rm -f "$PLIST"
rm -rf "$HOME/Applications/AgentDot.app"

echo "AgentDot app, hooks, and login item removed."
if [ "${1:-}" = "--purge" ]; then
  rm -rf "$HOME/Library/Application Support/AgentDot" "$HOME/.agent-dot"
  echo "State and helper directories purged."
else
  echo "State kept at $HOME/Library/Application Support/AgentDot"
  echo "Helper kept at $HOME/.agent-dot (use --purge to remove both)."
fi
