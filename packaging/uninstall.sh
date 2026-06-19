#!/usr/bin/env bash
#
# Completely remove NeetMode in one step: turn off the login autostart, then
# delete ~/NeetMode and NeetMode's cached web data. Run via `~/NeetMode/uninstall`.
set -euo pipefail
cd "$HOME"   # don't sit inside the directory we're about to delete

LABEL="com.neetmode.agent"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DIR="$HOME/NeetMode"

echo "[NeetMode] Turning off login autostart…"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$PLIST"

echo "[NeetMode] Clearing cached NeetCode login data…"
# Only NeetMode-named paths, so nothing else is touched.
for p in \
  "$HOME/Library/WebKit/NeetMode" \
  "$HOME/Library/Caches/NeetMode" \
  "$HOME/Library/HTTPStorages/NeetMode" \
  "$HOME/Library/HTTPStorages/NeetMode.binarycookies" \
  "$HOME/Library/Saved Application State/NeetMode.savedState"; do
  rm -rf "$p" 2>/dev/null || true
done

echo "[NeetMode] Deleting $DIR…"
rm -rf "$DIR"

echo "[NeetMode] Done — NeetMode has been completely removed."
