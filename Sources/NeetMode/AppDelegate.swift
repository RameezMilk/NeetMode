import AppKit
import WebKit

/// A borderless window that is still allowed to become key (so the embedded
/// NeetCode code editor can receive keyboard focus).
final class KioskWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    private let session = SessionController()
    private var web: WebController!
    private var window: KioskWindow!
    private let isSelfTest = ProcessInfo.processInfo.environment["NEETMODE_SELFTEST"] == "1"
    private var selfTest: SelfTest?

    /// In-window admin prompt state (replaces the old pop-up NSAlert).
    private var adminOverlay: NSView?
    private var adminField: NSSecureTextField?
    private var adminCompletion: ((Bool) -> Void)?
    private var adminTicker: Timer?

    /// Set true once the admin code has been accepted, so the subsequent
    /// terminate isn't re-challenged.
    private var adminUnlocked = false

    /// The close gate is active until the session has finished on its own.
    private var gateActive: Bool {
        if case .done = session.mode { return false }
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(isSelfTest ? .accessory : .regular)

        web = WebController(fallbackHTML: indexHTML)
        web.onStart = { [weak self] seconds in
            DispatchQueue.main.async { self?.session.start(seconds: seconds) }
        }
        web.allowedHosts = { [weak self] in
            // nil on the start screen (allow anything), locked to NeetCode when active.
            (self?.session.isActive ?? false) ? Config.allowedSessionHosts : nil
        }

        buildWindow()

        session.onModeChange = { [weak self] in self?.handleModeChange() }

        if !isSelfTest { NSApp.activate(ignoringOtherApps: true) }
        session.begin()       // → idle, or resumes a real-mode active session
        handleModeChange()    // initial load + presentation lockdown

        NotificationCenter.default.addObserver(
            self, selector: #selector(didResignActive),
            name: NSApplication.didResignActiveNotification, object: nil)

        if isSelfTest {
            selfTest = SelfTest(web: web, session: session)
            selfTest?.gateCheck = { [weak self] code in self?.quitDecision(forCode: code) ?? false }
            selfTest?.run()
        }
    }

    // MARK: - Window

    private func buildWindow() {
        if isSelfTest {
            // Offscreen, normal, never-locking window so the test can't take over
            // your screen but the WKWebView still loads/renders for real.
            let frame = NSRect(x: -6000, y: -6000, width: 1000, height: 700)
            window = KioskWindow(contentRect: frame, styleMask: [.titled, .closable, .resizable],
                                 backing: .buffered, defer: false)
            let container = NSView(frame: NSRect(origin: .zero, size: frame.size))
            assembleContent(in: container, withCloseButton: false)
            window.contentView = container
            window.delegate = self
            window.orderFrontRegardless()
            return
        }

        // Both profiles use a borderless window with NO native traffic lights —
        // the only control is our custom red close circle. REAL mode is a
        // fullscreen kiosk pinned ABOVE everything (shield window level) so the
        // Dock, menu bar and other apps can't surface; TEST mode is a smaller,
        // movable window with no OS lockdown.
        let frame: NSRect
        if session.profile == .real {
            frame = (NSScreen.main ?? NSScreen.screens[0]).frame
            window = KioskWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            window.isMovable = false
            window.setFrame(frame, display: true)
        } else {
            frame = NSRect(x: 0, y: 0, width: 1100, height: 780)
            window = KioskWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.isMovableByWindowBackground = true
            window.center()
        }

        let container = NSView(frame: NSRect(origin: .zero, size: frame.size))
        assembleContent(in: container, withCloseButton: true)
        window.contentView = container
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
    }

    private func assembleContent(in container: NSView, withCloseButton: Bool) {
        container.autoresizingMask = [.width, .height]

        web.webView.frame = container.bounds
        web.webView.autoresizingMask = [.width, .height]
        container.addSubview(web.webView)
        web.hostView = container   // sign-in popups present inside this view

        if withCloseButton {
            container.addSubview(makeCloseButton(in: container))
        }
    }

    /// The red close circle — sized/positioned like a standard macOS close button
    /// so it doesn't cover the NeetCode logo.
    private func makeCloseButton(in container: NSView) -> NSButton {
        let size: CGFloat = 14, left: CGFloat = 14, top: CGFloat = 12
        let button = NSButton(frame: NSRect(x: left, y: container.bounds.height - size - top,
                                            width: size, height: size))
        button.autoresizingMask = [.maxXMargin, .minYMargin]   // pinned top-left
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.systemRed.cgColor
        button.layer?.cornerRadius = size / 2
        button.attributedTitle = NSAttributedString(string: "✕", attributes: [
            .foregroundColor: NSColor.black.withAlphaComponent(0.5),
            .font: NSFont.systemFont(ofSize: 9, weight: .bold)])
        button.target = self
        button.action = #selector(closeButtonTapped)
        button.toolTip = "Close"
        return button
    }

    // MARK: - Mode handling

    private func handleModeChange() {
        switch session.mode {
        case .idle:
            web.loadStartUI(primary: Config.vercelURL)
        case .active:
            web.loadURL(Config.neetcodeURL)
        case .done:
            // Timer finished: the lock is fully released. Drop out of shield level
            // so the menu bar / other apps are reachable again while staying on
            // NeetCode.
            if session.profile == .real { window.level = .normal }
        }
        applyPresentation()
        // Real mode keeps itself frontmost & key for the whole locked session.
        if !isSelfTest && session.profile == .real && gateActive {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    /// Formatted remaining time, e.g. "27:14 remaining".
    private func remainingString() -> String {
        let r = session.remaining
        return String(format: "%02d:%02d remaining", r / 60, r % 60)
    }

    /// OS lockdown. Real mode HARD-disables every escape — Dock, menu bar, ⌘Tab,
    /// ⌘Q, Force-Quit and ⌘⇧Q logout — for the whole locked session (idle +
    /// active). The only ways out are the correct admin code or the timer expiring,
    /// at which point this releases. The self-test never locks.
    private func applyPresentation() {
        if isSelfTest { NSApp.presentationOptions = []; return }
        if session.profile == .real && gateActive {
            NSApp.presentationOptions = [
                .hideDock, .hideMenuBar, .disableAppleMenu, .disableProcessSwitching,
                .disableForceQuit, .disableSessionTermination, .disableHideApplication]
        } else {
            NSApp.presentationOptions = []
        }
    }

    // MARK: - Close / quit (admin-gated, in-window prompt)

    @objc private func closeButtonTapped() { attemptClose() }

    /// Any close attempt routes here. While the gate is active the only way out is
    /// the correct admin code, asked for via an IN-WINDOW overlay (never a separate
    /// pop-up that could render behind the fullscreen kiosk or block the run loop).
    private func attemptClose() {
        if !gateActive { NSApp.terminate(nil); return }
        presentAdminPrompt { [weak self] accepted in
            guard let self, accepted else { return }
            self.adminUnlocked = true
            NSApp.terminate(nil)
        }
    }

    /// Pure, testable gate decision. `code == nil` means "no code supplied yet".
    /// Returns whether the app is allowed to quit.
    func quitDecision(forCode code: String?) -> Bool {
        if adminUnlocked || !gateActive { return true }
        guard let code else { return false }
        return code == Config.adminCode
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if quitDecision(forCode: nil) { return .terminateNow } // already unlocked or gate off
        if isSelfTest { return .terminateNow }
        // Ask asynchronously; reply once the user answers the in-window prompt.
        presentAdminPrompt { accepted in
            if accepted { self.adminUnlocked = true }
            NSApp.reply(toApplicationShouldTerminate: accepted)
        }
        return .terminateLater
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        attemptClose()
        return false
    }

    @objc private func didResignActive() {
        // If anything steals focus mid-session in real mode, grab it straight back
        // so the kiosk can't be left running in the background.
        guard !isSelfTest, session.profile == .real, gateActive else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        applyPresentation()
    }

    // MARK: - In-window admin prompt

    /// Show the "Admin Access Code Required" overlay INSIDE the kiosk window and
    /// call `completion(true)` only if the correct code is entered. Cancel or a
    /// wrong/empty code calls `completion(false)` with no feedback. Because it's a
    /// subview of the (shield-level) kiosk window it can never be occluded and never
    /// blocks the run loop — the failure that previously forced a reboot.
    private func presentAdminPrompt(completion: @escaping (Bool) -> Void) {
        if isSelfTest { completion(true); return }
        if adminOverlay != nil { completion(false); return }   // a prompt is already up
        guard let content = window.contentView else { completion(false); return }

        let backdrop = NSView(frame: content.bounds)
        backdrop.autoresizingMask = [.width, .height]
        backdrop.wantsLayer = true
        backdrop.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.55).cgColor

        let showTimer = session.isActive
        let panelW: CGFloat = 360
        let panelH: CGFloat = showTimer ? 210 : 178
        let panel = NSView(frame: NSRect(x: (content.bounds.width - panelW) / 2,
                                         y: (content.bounds.height - panelH) / 2,
                                         width: panelW, height: panelH))
        panel.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
        panel.wantsLayer = true
        panel.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        panel.layer?.cornerRadius = 12
        panel.layer?.borderWidth = 1
        panel.layer?.borderColor = NSColor.separatorColor.cgColor

        let pad: CGFloat = 24
        let innerW = panelW - pad * 2

        let title = NSTextField(labelWithString: "Admin Access Code Required")
        title.font = .boldSystemFont(ofSize: 15)
        title.alignment = .center
        title.frame = NSRect(x: pad, y: panelH - 50, width: innerW, height: 22)
        panel.addSubview(title)

        let field = NSSecureTextField(frame: NSRect(x: pad, y: panelH - 92, width: innerW, height: 26))
        field.alignment = .center
        panel.addSubview(field)
        adminField = field

        if showTimer {
            let label = NSTextField(labelWithString: remainingString())
            label.frame = NSRect(x: pad, y: panelH - 124, width: innerW, height: 20)
            label.alignment = .center
            label.font = .monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
            label.textColor = .secondaryLabelColor
            label.isBezeled = false; label.drawsBackground = false; label.isEditable = false
            panel.addSubview(label)
            let ticker = Timer(timeInterval: 1, repeats: true) { [weak self, weak label] _ in
                label?.stringValue = self?.remainingString() ?? ""
            }
            RunLoop.main.add(ticker, forMode: .common)
            adminTicker = ticker
        }

        let btnW: CGFloat = 100, btnH: CGFloat = 30, gap: CGFloat = 12
        let cancel = NSButton(frame: NSRect(x: (panelW - btnW * 2 - gap) / 2, y: 20, width: btnW, height: btnH))
        cancel.title = "Cancel"; cancel.bezelStyle = .rounded
        cancel.target = self; cancel.action = #selector(adminCancelTapped)
        cancel.keyEquivalent = "\u{1b}"                  // Esc cancels
        panel.addSubview(cancel)

        let submit = NSButton(frame: NSRect(x: cancel.frame.maxX + gap, y: 20, width: btnW, height: btnH))
        submit.title = "Submit"; submit.bezelStyle = .rounded
        submit.target = self; submit.action = #selector(adminSubmitTapped)
        submit.keyEquivalent = "\r"                      // Return submits
        panel.addSubview(submit)

        backdrop.addSubview(panel)
        content.addSubview(backdrop)
        adminOverlay = backdrop
        adminCompletion = completion

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(field)
    }

    @objc private func adminSubmitTapped() {
        dismissAdminPrompt(result: adminField?.stringValue == Config.adminCode)
    }

    @objc private func adminCancelTapped() {
        dismissAdminPrompt(result: false)
    }

    /// Tear down the overlay and deliver the result exactly once.
    private func dismissAdminPrompt(result: Bool) {
        adminTicker?.invalidate(); adminTicker = nil
        adminOverlay?.removeFromSuperview(); adminOverlay = nil
        adminField = nil
        let done = adminCompletion; adminCompletion = nil
        done?(result)
    }
}
