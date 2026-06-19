#!/usr/bin/env bash
#
# Enable / disable launching NeetMode (REAL mode) at every login.
#
#   ~/NeetMode/packaging/autostart.sh on     # lock at every login
#   ~/NeetMode/packaging/autostart.sh off    # stop it
#
# This installs a per-user LaunchAgent. It is the ONE file NeetMode writes
# outside ~/NeetMode, so a full uninstall is `autostart.sh off` then
# `rm -rf ~/NeetMode`.
set -euo pipefail

LABEL="com.neetmode.agent"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LAUNCHER="$HOME/NeetMode/neetmode"

case "${1:-}" in
  on)
    [ -x "$LAUNCHER" ] || { echo "Not installed: $LAUNCHER missing. Run the installer first."; exit 1; }
    mkdir -p "$HOME/Library/LaunchAgents"
    cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$LAUNCHER</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>NEETMODE_PROFILE</key>
        <string>real</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
PL
    launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$PLIST"
    echo "[NeetMode] Autostart ON — real-mode lock launches at every login."
    ;;
  off)
    launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
    rm -f "$PLIST"
    echo "[NeetMode] Autostart OFF."
    ;;
  *)
    echo "usage: $0 on|off"; exit 1 ;;
esac
