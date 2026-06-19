import AppKit
import WebKit

/// Owns the WKWebView. Loads the Vercel timer UI (with a bundled fallback),
/// bridges the page's "start" message back to native code, and — during an
/// active session — refuses to navigate anywhere except NeetCode.
final class WebController: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {

    let webView: WKWebView

    /// Allowed hosts for the current phase, or nil to allow any navigation
    /// (used on the start screen). Set by AppDelegate from session state.
    var allowedHosts: (() -> [String]?)?
    /// Called with a DURATION IN SECONDS when the start screen posts
    /// {action:"start", minutes:N} (or {seconds:N}).
    var onStart: ((Int) -> Void)?
    /// Fired after every successful navigation (used by the self-test).
    var onNavigationFinished: ((URL?) -> Void)?

    /// View that popups (e.g. the Google sign-in window) are presented inside.
    weak var hostView: NSView?

    private let fallbackHTML: String
    private var loadingStartUI = false
    private var usedFallback = false
    private var fallbackTimer: Timer?
    private var popups: [(web: WKWebView, card: NSView)] = []

    init(fallbackHTML: String) {
        self.fallbackHTML = fallbackHTML
        let config = WKWebViewConfiguration()
        self.webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        // Use the webview's live content controller (the config is copied at init).
        webView.configuration.userContentController.add(self, name: "neetmode")
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = false
        webView.customUserAgent = Config.desktopUserAgent
    }

    // MARK: - Loading

    /// Load the remote start UI; fall back to the bundled page on error, HTTP
    /// status >= 400, or timeout. If Vercel isn't configured yet, go straight to
    /// the bundled page (so the placeholder never shows a 404).
    func loadStartUI(primary: String) {
        loadingStartUI = true
        usedFallback = false
        guard Config.isVercelConfigured,
              let url = URL(string: primary), url.scheme?.hasPrefix("http") == true else {
            loadFallback()
            return
        }
        webView.load(URLRequest(url: url))
        fallbackTimer?.invalidate()
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: Config.loadTimeout, repeats: false) { [weak self] _ in
            self?.loadFallbackIfNeeded()
        }
    }

    func loadURL(_ string: String) {
        loadingStartUI = false
        fallbackTimer?.invalidate()
        if let url = URL(string: string) { webView.load(URLRequest(url: url)) }
    }

    private func loadFallbackIfNeeded() {
        guard loadingStartUI, !usedFallback else { return }
        loadFallback()
    }
    private func loadFallback() {
        usedFallback = true
        webView.loadHTMLString(fallbackHTML, baseURL: URL(string: "https://neetmode.local/"))
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if loadingStartUI { loadingStartUI = false; fallbackTimer?.invalidate() }
        onNavigationFinished?(webView.url)
    }

    /// Catch HTTP error pages (e.g. a 404 from a wrong/placeholder Vercel URL),
    /// which "succeed" at the network layer and so don't trigger didFail.
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if loadingStartUI, let http = navigationResponse.response as? HTTPURLResponse, http.statusCode >= 400 {
            decisionHandler(.cancel)
            loadFallback()
            return
        }
        decisionHandler(.allow)
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        loadFallbackIfNeeded()
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadFallbackIfNeeded()
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // nil => no restriction (start screen). Otherwise enforce host allow-list.
        guard let hosts = allowedHosts?() else { decisionHandler(.allow); return }
        guard let url = navigationAction.request.url else { decisionHandler(.allow); return }
        if url.scheme == "about" { decisionHandler(.allow); return }
        if isAllowed(url, hosts: hosts) {
            decisionHandler(.allow)
        } else {
            // Surface what was blocked so the allow-list can be tuned (e.g. an
            // unexpected Firebase auth host during sign-in).
            FileHandle.standardError.write(Data("[NeetMode] blocked navigation to host: \(url.host ?? url.absoluteString)\n".utf8))
            decisionHandler(.cancel)
            if webView === self.webView, let back = URL(string: Config.neetcodeURL) {
                webView.load(URLRequest(url: back))
            }
        }
    }

    // MARK: - WKUIDelegate (popups — needed for Google sign-in)

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // Only allow popups to permitted hosts (e.g. accounts.google.com). A real
        // child web view — built from the provided configuration so window.opener
        // works — is required for popup-based OAuth. The same host allow-list
        // applies, so the popup can't be used to browse off-limits sites either.
        guard let url = navigationAction.request.url,
              (allowedHosts?().map { isAllowed(url, hosts: $0) } ?? true),
              let host = hostView else { return nil }

        let popup = WKWebView(frame: .zero, configuration: configuration)
        popup.customUserAgent = Config.desktopUserAgent
        popup.navigationDelegate = self
        popup.uiDelegate = self

        let card = makePopupCard(around: popup, in: host)
        host.addSubview(card)
        popups.append((popup, card))
        return popup
    }

    func webViewDidClose(_ webView: WKWebView) {
        guard let idx = popups.firstIndex(where: { $0.web === webView }) else { return }
        popups[idx].card.removeFromSuperview()
        popups.remove(at: idx)
    }

    @objc private func popupCloseTapped() {
        guard let last = popups.popLast() else { return }
        last.card.removeFromSuperview()
    }

    private func makePopupCard(around popup: WKWebView, in host: NSView) -> NSView {
        let w = min(480, host.bounds.width - 80)
        let h = min(660, host.bounds.height - 80)
        let card = NSView(frame: NSRect(x: (host.bounds.width - w) / 2,
                                        y: (host.bounds.height - h) / 2, width: w, height: h))
        card.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        card.layer?.cornerRadius = 10
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.separatorColor.cgColor
        card.layer?.masksToBounds = true

        let barH: CGFloat = 30
        let close = NSButton(frame: NSRect(x: 8, y: h - barH + 4, width: 22, height: 22))
        close.isBordered = false
        close.title = "✕"
        close.target = self
        close.action = #selector(popupCloseTapped)
        card.addSubview(close)

        popup.frame = NSRect(x: 0, y: 0, width: w, height: h - barH)
        popup.autoresizingMask = [.width, .height]
        card.addSubview(popup)
        return card
    }

    private func isAllowed(_ url: URL, hosts: [String]) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return hosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    // MARK: - WKScriptMessageHandler (page → native bridge)

    func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "neetmode" else { return }
        if let seconds = durationSeconds(from: message.body) { onStart?(seconds) }
    }

    /// Resolve a start message to a duration in seconds. Accepts a dict with
    /// `seconds` or `minutes`, a JSON string of the same, or a bare integer
    /// (treated as minutes).
    private func durationSeconds(from body: Any) -> Int? {
        func fromDict(_ d: [String: Any]) -> Int? {
            if let s = intValue(d["seconds"]) { return s }
            if let m = intValue(d["minutes"]) { return m * 60 }
            return nil
        }
        if let dict = body as? [String: Any] { return fromDict(dict) }
        if let s = body as? String, let data = s.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return fromDict(obj)
        }
        if let n = body as? Int { return n * 60 }
        return nil
    }

    private func intValue(_ any: Any?) -> Int? {
        if let i = any as? Int { return i }
        if let d = any as? Double { return Int(d) }
        if let s = any as? String { return Int(s) }
        return nil
    }
}
