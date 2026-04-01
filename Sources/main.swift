// ============================================================================
// main.swift - Entry point for apfel-clip
// AI-powered clipboard actions from the menu bar.
// https://github.com/Arthur-Ficial/apfel-clip
// ============================================================================

import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate
app.run()
