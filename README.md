# NeetMode

A **native macOS kiosk** that locks you into NeetCode for a fixed time. It opens
fullscreen, shows a timer chooser (your React UI, deployed on Vercel), and once
you press **Start** it disables the menu bar, Dock, ⌘Tab, ⌘Q, Force-Quit and ⌘⇧Q
logout, and pins an embedded web view to <https://neetcode.io/> until the timer
runs out. The only ways out are the admin code or the timer elapsing.

## Quick start

Install (in Terminal):

```bash
curl -fsSL https://raw.githubusercontent.com/RameezMilk/NeetMode/dev/install.sh | bash
```

Launch the lock at every login (once per day):

```bash
~/NeetMode/packaging/autostart.sh on
```

Run it now / get out with the admin code (`bankai`):

```bash
~/NeetMode/neetmode        # NEETMODE_PROFILE=test for a windowed dev run
```

Remove everything (autostart + folder + web cache):

```bash
~/NeetMode/uninstall
```

---

No browser is involved — NeetMode renders the web content itself in a `WKWebView`,
so it's genuinely browser-agnostic. No Chrome automation, no Apple Events, no
Network Extension.

The window is **fullscreen and unminimizable** with **no native title-bar buttons**.
The only control is a custom **red close circle** (top-left). Clicking it — or any
quit/close attempt (⌘Q, ⌘W) — opens an **"Admin Access Code Required"** modal. The
app closes only when the code is entered correctly; a wrong or empty code just
dismisses the modal with **no feedback either way**. The lock also releases on its
own when the timer finishes.

> **Admin code:** hardcoded in `Config.adminCode` (default `bankai`). This is
> **discoverable** — `strings` on the binary reveals it — so it's friction, not
> real security. Change it there if you like.

```
┌──────────────────────────────────────────────┐
│  Native kiosk window (fullscreen, OS locked)  │
│  ┌────────────────────────────────────────┐  │
│  │  WKWebView                              │  │
│  │   • Phase 1: timer UI  (Vercel + local) │  │
│  │   • Phase 2: neetcode.io for the timer  │  │
│  └────────────────────────────────────────┘  │
│                        FOCUS · 29:58  ◀ native │
└──────────────────────────────────────────────┘
```

---

## ⚠️ Honest limits (read once)

1. **A web page can't lock anything — the native app does.** A React page on Vercel
   is the *least*-privileged layer: it can't stop its own tab from closing, can't
   touch ⌘Q/⌘Tab, can't reach the OS. So in NeetMode the Vercel page is only the
   **UI**; every bit of enforcement lives in the native kiosk window
   (`NSApplicationPresentationOptions`).

2. **Nothing is truly unkillable.** Holding the **power button** (hard shutdown) or
   booting to Recovery always wins — no userspace app can prevent that. Within
   macOS, though, real mode is a hard lock: ⌘Q, ⌘Tab, Force-Quit, ⌘⇧Q logout and
   the menu bar are all disabled, the deadline is persisted so a kill-and-relaunch
   **resumes the lock**, and the admin prompt is drawn *inside* the kiosk window so
   it can never hide behind it. The only ways out are the admin code or the timer.

3. **NeetCode's Google sign-in may not work in an embedded web view.** Google
   sometimes blocks OAuth in `WKWebView` ("this browser is not secure"). Solving
   problems works fine; logging in *fresh* during a session might not. Sign in once
   (it persists), or add `accounts.google.com` to `allowedSessionHosts` and test.

4. **Real mode takes over the whole screen.** During a session you can't use any
   other app — that's the point. Use **test mode** while developing.

---

## Test mode vs Real mode

**Starts in TEST mode by default**, so you can never lock yourself out while
developing.

Both modes use a borderless window whose only control is the red close circle, and
both ask for the admin code (via an in-window prompt) to close. The difference is
the OS lockdown:

| | **TEST** (default) | **REAL** |
|---|---|---|
| Window | Borderless, **movable**, 1100×780 | Borderless **fullscreen** |
| Closing → admin code required | Yes | Yes |
| ⌘Tab / menu bar / Force-Quit / ⌘⇧Q | All work | All disabled while locked |
| Other apps usable during session | Yes | No (full takeover) |
| Deadline resumes after a kill | No | Yes (relaunches into the lock) |

The admin code (`bankai`) closes either mode, and in real mode the timer also
releases the lock on its own — so the only ways out are the code or the clock.

Pick the profile at launch:

```bash
swift run                      # TEST (default)
NEETMODE_PROFILE=real swift run   # REAL
```

The countdown shows in the top-right overlay (`TEST · mm:ss` or `FOCUS · mm:ss`).

---

## The Vercel ⇄ native contract

Your React timer app does two things:

1. Render the duration buttons + a Start button.
2. On Start, send the chosen minutes to the native app:

```js
// Works only when loaded inside NeetMode (the WKWebView injects this bridge).
const bridge = window.webkit?.messageHandlers?.neetmode;
if (bridge) {
  bridge.postMessage({ action: "start", minutes: 30 });
} else {
  // Running in a normal browser preview — no native app to talk to.
}
```

That's it. The native app handles the timer, the lockdown, and navigating to
NeetCode. `web/index.html` is a complete working reference page that does exactly
this — use it as the template for your React build, or deploy it as-is.

Paste your deployment URL into **`Config.vercelURL`**
(`Sources/NeetMode/Config.swift`). If Vercel is unreachable within
`Config.loadTimeout` seconds, NeetMode shows the bundled local copy instead.

---

## File structure

```
NeetMode/
├── Package.swift
├── README.md
├── Sources/NeetMode/
│   ├── main.swift               # NSApplication bootstrap
│   ├── Config.swift             # Vercel URL, allowed hosts, profile  ← edit here
│   ├── AppDelegate.swift        # kiosk window, presentation lockdown, overlay
│   ├── SessionController.swift  # timer state machine + persistence
│   ├── WebController.swift      # WKWebView: load, bridge, NeetCode-only nav
│   └── IndexHTML.swift          # embedded fallback start screen
├── web/index.html               # deployable / reference start screen (the bridge)
├── packaging/
│   ├── Info.plist
│   ├── make-app-bundle.sh       # builds + assembles NeetMode.app
│   └── com.neetmode.watchdog.plist   # optional KeepAlive watchdog (real mode)
```

## Requirements

- macOS 13+
- Swift toolchain (`swift --version` should work)

## Build & run

### Develop / test (safe — normal window, no lockdown)

```bash
cd NeetMode
swift run
```

A regular window opens with the start screen. Pick a duration → Start → it loads
NeetCode and pins to it, with a live countdown. Close the window anytime.

### Install for real use

```bash
cd NeetMode
./packaging/make-app-bundle.sh
cp -R build/NeetMode.app /Applications/
open /Applications/NeetMode.app          # TEST mode (windowed)
# For the real lock, launch with the env var, e.g. via a wrapper or:
NEETMODE_PROFILE=real /Applications/NeetMode.app/Contents/MacOS/NeetMode
```

### Optional: watchdog (real-mode "can't quit" deterrent)

Restarts NeetMode if it's killed; combined with the persisted deadline, it resumes
the lock. **Don't install this while testing.**

```bash
cp packaging/com.neetmode.watchdog.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.neetmode.watchdog.plist
# remove later:
launchctl unload ~/Library/LaunchAgents/com.neetmode.watchdog.plist
```

## Verification (self-test)

A real end-to-end integration test drives the actual `WKWebView` and live network
through the same code the app uses, then exits 0 (pass) / 1 (fail):

```bash
NEETMODE_SELFTEST=1 swift build -c release && \
  NEETMODE_SELFTEST=1 "$(swift build -c release --show-bin-path)/NeetMode"
```

It runs in an **offscreen, non-locking** window (it never takes over your screen)
and asserts:

1. start screen renders with no 404 (placeholder Vercel → local fallback);
2. the page→native `postMessage` bridge fires;
3. the session goes ACTIVE from that message;
4. close is **blocked with no code**;
5. close is **blocked with a wrong code**;
6. close is **allowed with `bankai`**;
7. the web view loads `neetcode.io` live;
8. an off-site navigation (google.com) is blocked and snapped back;
9. the session ends on timer expiry;
10. the OS is unlocked afterward.

(Verified: 10/10, reproduced across repeated runs.)

**What the self-test does NOT cover** (needs your eyes):
- the **visual** in-window admin prompt + red close button (the *decision* logic is
  tested above; the AppKit rendering is not);
- the real-mode **OS lockdown** itself (`hideMenuBar` / `disableProcessSwitching` /
  `disableForceQuit` …) — disabled during the test so it can't take over the box.

Verify both **safely, in two steps**. First in **test mode** (no lockdown, zero
risk) confirm the prompt renders and the code works:

```bash
swift run         # TEST mode: click the red ✕ → prompt appears → `bankai` quits
```

Then a **short** real session to confirm the lockdown and that the (already-proven)
prompt floats on top. The timer always releases the lock as a backstop:

```bash
# fullscreen hard lock — the timer (or `bankai`) is your way out
NEETMODE_PROFILE=real "$(swift build -c release --show-bin-path)/NeetMode"
```

## Configuration (`Sources/NeetMode/Config.swift`)

- `vercelURL` — your deployed timer UI.
- `neetcodeURL` / `allowedSessionHosts` — what's reachable during a session.
- `loadTimeout` — how long to wait for Vercel before the local fallback.
- `defaultProfile` — `.test` / `.real` (env `NEETMODE_PROFILE` overrides).

## Uninstall

```bash
launchctl unload ~/Library/LaunchAgents/com.neetmode.watchdog.plist 2>/dev/null
rm -f ~/Library/LaunchAgents/com.neetmode.watchdog.plist
rm -rf /Applications/NeetMode.app
rm -rf ~/Library/Application\ Support/NeetMode
```
