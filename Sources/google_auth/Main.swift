import AppKit
import SwiftUI

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as menu bar accessory app
        NSApp.setActivationPolicy(.accessory)

        setupPopover()
        setupStatusItem()
        setupEventMonitor()
    }

    private func setupPopover() {
        let pop = NSPopover()
        pop.contentSize = NSSize(width: 360, height: 480)
        pop.behavior = .transient
        pop.animates = true

        let rootView = MenuBarView()
        pop.contentViewController = NSHostingController(rootView: rootView)
        self.popover = pop
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            if let image = NSImage(systemSymbolName: "shield.lefthalf.filled", accessibilityDescription: "Google Authenticator") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "2FA"
            }
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        self.statusItem = item
    }

    private func setupEventMonitor() {
        // Dismiss popover when clicking outside if needed
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, let pop = self.popover, pop.isShown else { return }
            self.closePopover()
        }
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button, let popover = popover else { return }

        let currentEvent = NSApp.currentEvent
        if currentEvent?.type == .rightMouseUp {
            // Show quick context menu on right click
            showContextMenu(button)
            return
        }

        if popover.isShown {
            closePopover()
        } else {
            showPopover(button)
        }
    }

    private func showPopover(_ button: NSStatusBarButton) {
        guard let popover = popover else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func closePopover() {
        popover?.performClose(nil)
    }

    private func showContextMenu(_ button: NSStatusBarButton) {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "打开身份验证器", action: #selector(openFromMenu), keyEquivalent: "o"))

        let scanItem = NSMenuItem(title: "一键识别屏幕二维码", action: #selector(scanScreenFromMenu), keyEquivalent: "s")
        menu.addItem(scanItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
        button.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func openFromMenu() {
        if let button = statusItem?.button {
            showPopover(button)
        }
    }

    @objc private func scanScreenFromMenu() {
        let result = AccountManager.shared.importFromScreenQR()
        if let err = result.error {
            AccountManager.shared.showToast(err)
        }
        if let button = statusItem?.button {
            showPopover(button)
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
