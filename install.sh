#!/usr/bin/env bash
#
# NeetMode installer — self-contained.
#
#   curl -fsSL https://raw.githubusercontent.com/RameezMilk/NeetMode/dev/install.sh | bash
#
# Everything lives in ~/NeetMode. To uninstall completely:
#
#   rm -rf ~/NeetMode
#
# Nothing is written outside that directory (no LaunchAgents, no Application
# Support), so deleting the folder removes the program and all of its state.
set -euo pipefail

DIR="$HOME/NeetMode"
REPO="https://github.com/RameezMilk/NeetMode.git"
BRANCH="${NEETMODE_BRANCH:-dev}"

say() { printf '\033[1;35m[NeetMode]\033[0m %s\n' "$1"; }

# 1. Build prerequisite: the Swift toolchain (Xcode Command Line Tools).
if ! xcode-select -p >/dev/null 2>&1; then
  say "Xcode Command Line Tools are required to build. Launching the installer…"
  xcode-select --install || true
  say "Finish that install, then re-run this command."
  exit 1
fi

# 2. Fetch the source into ~/NeetMode (clone fresh, or fast-forward in place).
if [ -d "$DIR/.git" ]; then
  say "Updating existing install in $DIR"
  git -C "$DIR" fetch --depth 1 origin "$BRANCH"
  git -C "$DIR" reset --hard "origin/$BRANCH"
else
  say "Cloning into $DIR"
  rm -rf "$DIR"
  git clone --depth 1 --branch "$BRANCH" "$REPO" "$DIR"
fi

# 3. Build the release binary (stays inside $DIR/.build).
say "Building (this can take a minute the first time)…"
cd "$DIR"
swift build -c release

# 4. A tiny launcher that pins all state inside ~/NeetMode.
cat > "$DIR/neetmode" <<'LAUNCH'
#!/usr/bin/env bash
export NEETMODE_HOME="$HOME/NeetMode"
exec "$NEETMODE_HOME/.build/release/NeetMode" "$@"
LAUNCH
chmod +x "$DIR/neetmode"

say "Installed to $DIR"
echo
echo "  Start a focus session (windowed, safe):   $DIR/neetmode"
echo "  Real fullscreen lock:            NEETMODE_PROFILE=real $DIR/neetmode"
echo "  Uninstall completely:            rm -rf $DIR"
echo
