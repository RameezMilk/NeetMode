import Foundation

/// How aggressively NeetMode locks the machine.
///
/// - `.test`: a centered, movable, borderless window with NO OS lockdown. ⌘Q and
///   ⌘Tab work. The whole flow is exercised but you can never get stuck. Default.
/// - `.real`: a borderless **fullscreen kiosk** pinned above everything. The Dock,
///   menu bar, ⌘Tab, ⌘Q, Force-Quit and ⌘⇧Q logout are all disabled for the whole
///   session. The ONLY ways out are the correct admin code (entered in the
///   in-window prompt) or the timer elapsing.
enum RunProfile { case test, real }

enum Config {

    /// Your deployed React timer UI. Paste your Vercel URL here.
    /// If it can't be reached (or is still the placeholder), NeetMode falls back
    /// to the bundled start screen.
    static let vercelURL = "https://your-neetmode.vercel.app"

    /// True only once you've replaced the placeholder with a real deployment.
    /// Until then NeetMode loads the bundled start screen directly (no 404).
    static var isVercelConfigured: Bool {
        !vercelURL.isEmpty && !vercelURL.contains("your-neetmode")
    }

    /// Admin override code. Entering this in the close modal quits the app at
    /// any time. NOTE: this is hardcoded and therefore DISCOVERABLE — running
    /// `strings` on the binary reveals it. It's friction, not real security.
    static let adminCode = "bankai"

    /// The single site allowed during a focus session.
    static let neetcodeURL = "https://neetcode.io/"

    /// Hosts reachable during a session (host == one of these, or a subdomain).
    /// `accounts.google.com` lets the Google sign-in flow load WITHOUT opening up
    /// general Google browsing — search (`www.google.com`) is a different host and
    /// stays blocked. If sign-in still fails, watch stderr for "blocked navigation
    /// to host: X" and add the missing host (likely NeetCode's Firebase authDomain).
    static let allowedSessionHosts: [String] = [
        "neetcode.io",
        "accounts.google.com",
        "accounts.youtube.com",   // Google routes OAuth through here; the video
                                  // site (www.youtube.com) stays blocked.
    ]

    /// Desktop Safari user-agent. Google refuses its OAuth page inside the default
    /// WKWebView user-agent ("this browser is not secure"); presenting as Safari
    /// gets the sign-in flow to load.
    static let desktopUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4.1 Safari/605.1.15"

    /// Seconds to wait for the Vercel UI before showing the local fallback.
    static let loadTimeout: TimeInterval = 6

    /// Default profile. `.test` so you can never accidentally lock yourself out.
    /// Override at launch: `NEETMODE_PROFILE=real swift run`
    static var defaultProfile: RunProfile {
        switch ProcessInfo.processInfo.environment["NEETMODE_PROFILE"]?.lowercased() {
        case "real": return .real
        case "test": return .test
        default:     return .test
        }
    }

    /// Where the active-session deadline is persisted, so a real-mode lock resumes
    /// if NeetMode is killed and relaunched (killing the process isn't an escape).
    static var stateFile: URL {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NeetMode", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("session.json")
    }
}
