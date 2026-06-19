import AppKit

// Entry point. NeetMode runs as a background ("accessory") agent with a
// menu-bar item — no Dock icon, no main window of its own.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
