#!/bin/sh
# Keep the Voice Inbox backend running on this Mac via launchd (survives Claude
# sessions, logouts and reboots). Usage: scripts/server-agent.sh install|uninstall|status
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LABEL=com.langlipro.voice-inbox-server
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
NODE="$(command -v node || echo /opt/homebrew/bin/node)"
case "${1:-status}" in
  install)
    (cd "$ROOT/server" && npm run build --silent)
    mkdir -p "$HOME/Library/LaunchAgents" "$ROOT/server/.data"
    cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$NODE</string><string>dist/index.js</string></array>
  <key>WorkingDirectory</key><string>$ROOT/server</string>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$ROOT/server/.data/launchd.log</string>
  <key>StandardErrorPath</key><string>$ROOT/server/.data/launchd.log</string>
</dict></plist>
PLIST
    launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
    pkill -f "node dist/index.js" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$PLIST"
    sleep 2; curl -s -m 5 http://localhost:8787/health && echo && echo "installed: $PLIST"
    ;;
  uninstall)
    launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
    rm -f "$PLIST"; echo "removed $LABEL"
    ;;
  status)
    launchctl print "gui/$(id -u)/$LABEL" 2>/dev/null | grep -E "state|pid" | head -3 || echo "not installed"
    curl -s -m 3 http://localhost:8787/health || echo "server not answering on :8787"
    ;;
  *) echo "usage: $0 install|uninstall|status"; exit 2 ;;
esac
