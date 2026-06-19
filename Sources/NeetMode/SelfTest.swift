import AppKit
import WebKit

/// Real end-to-end integration test. Drives the actual WKWebView and live
/// network through the same code paths the app uses, asserting on observable
/// behavior at each step, then exits 0 (all pass) or 1 (any fail).
///
/// Run with:  NEETMODE_SELFTEST=1 swift run
final class SelfTest {
    private let web: WebController
    private let session: SessionController
    private var timer: Timer?
    private var step = 0
    private var deadline = Date()
    private var results: [(String, Bool)] = []
    private var neetcodeLoadedAt: Date?
    private var awaitingAsync = false

    /// Injected admin-gate decision (AppDelegate.quitDecision). Lets the test
    /// verify the password logic without driving the NSAlert UI.
    var gateCheck: ((String?) -> Bool)?

    init(web: WebController, session: SessionController) {
        self.web = web
        self.session = session
    }

    func run() {
        log("starting end-to-end self-test (placeholder Vercel → local fallback → NeetCode lock)")
        setStep(1, timeout: 12)
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.poll() }
    }

    private func setStep(_ s: Int, timeout: TimeInterval) {
        step = s
        deadline = Date().addingTimeInterval(timeout)
    }

    private func poll() {
        if Date() > deadline { record("step \(step) reached without timing out", false); finish(); return }
        switch step {

        // 1) Start screen must render. With the placeholder Vercel URL this
        //    proves the 404 fix: it should land on the bundled local page.
        case 1:
            guard !awaitingAsync, !web.webView.isLoading, web.webView.url != nil else { return }
            awaitingAsync = true
            web.webView.evaluateJavaScript("document.title") { [weak self] result, _ in
                guard let self else { return }
                let title = (result as? String) ?? ""
                self.record("start screen rendered without 404 (title=\"\(title)\")", title.contains("NeetMode"))
                // Fire the page→native bridge exactly like the real Start button,
                // using an 12s session so the rest of the test has headroom.
                self.web.webView.evaluateJavaScript(
                    "window.webkit.messageHandlers.neetmode.postMessage({action:'start', seconds:12}); true"
                ) { _, err in
                    self.record("page→native start bridge delivered", err == nil)
                }
                self.awaitingAsync = false
                self.setStep(2, timeout: 4)
            }

        // 2) The bridge message must have driven the session into ACTIVE.
        case 2:
            if session.isActive {
                record("session entered ACTIVE via bridge", true)
                // Admin-gate logic (the decision the close modal feeds into).
                if let gate = gateCheck {
                    record("close BLOCKED with no code", gate(nil) == false)
                    record("close BLOCKED with wrong code", gate("wrongcode") == false)
                    record("close ALLOWED with admin code 'bankai'", gate("bankai") == true)
                }
                setStep(3, timeout: 20)
            }

        // 3) The app must navigate the web view to NeetCode for real.
        case 3:
            if web.webView.url?.host == "neetcode.io", !web.webView.isLoading {
                record("WKWebView loaded neetcode.io live", true)
                neetcodeLoadedAt = Date()
                // Now attempt to escape to another site.
                if let google = URL(string: "https://www.google.com/") {
                    web.webView.load(URLRequest(url: google))
                }
                setStep(4, timeout: 8)
            }

        // 4) Enforcement: the escape attempt must be blocked and snapped back.
        case 4:
            if let t = neetcodeLoadedAt, Date().timeIntervalSince(t) > 3.0 {
                let host = web.webView.url?.host ?? "(nil)"
                record("off-site navigation blocked, snapped back to NeetCode (host=\(host))",
                       host == "neetcode.io")
                setStep(5, timeout: 16)
            }

        // 5) When the timer elapses, the session ends and the OS is unlocked.
        case 5:
            if case .done = session.mode {
                record("session completed on timer expiry", true)
                record("OS unlocked after session (presentationOptions empty)",
                       NSApp.presentationOptions.isEmpty)
                finish()
            }

        default:
            break
        }
    }

    private func record(_ name: String, _ pass: Bool) {
        results.append((name, pass))
        log("\(pass ? "PASS" : "FAIL") — \(name)")
    }

    private func finish() {
        timer?.invalidate()
        let passed = results.filter { $0.1 }.count
        let total = results.count
        log("================  \(passed)/\(total) checks passed  ================")
        let ok = total >= 6 && passed == total
        log(ok ? "SELF-TEST RESULT: PASS ✅" : "SELF-TEST RESULT: FAIL ❌")
        exit(ok ? 0 : 1)
    }

    private func log(_ s: String) {
        FileHandle.standardError.write(Data("[SELFTEST] \(s)\n".utf8))
    }
}
