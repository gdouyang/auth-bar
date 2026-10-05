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

        setupMainMenu()
        setupPopover()
        setupStatusItem()
        setupEventMonitor()
    }

    /// Essential for macOS accessory apps: enables Cmd+C, Cmd+V, Cmd+X, Cmd+A, Cmd+Z shortcuts
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // Application menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于 Google Authenticator", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出", action: #selector(quitApp), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // Edit menu
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    private func setupPopover() {
        let pop = NSPopover()
        pop.contentSize = NSSize(width: 380, height: 490)
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
        if let window = popover.contentViewController?.view.window {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func closePopover() {
        popover?.performClose(nil)
    }

    private func showContextMenu(_ button: NSStatusBarButton) {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "打开身份验证器", action: #selector(openFromMenu), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "从剪贴板导入", action: #selector(importFromClipboardFromMenu), keyEquivalent: "v"))
        menu.addItem(NSMenuItem(title: "一键识别屏幕二维码", action: #selector(scanScreenFromMenu), keyEquivalent: "s"))

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

    @objc private func importFromClipboardFromMenu() {
        let result = AccountManager.shared.importFromClipboard()
        if let err = result.error {
            AccountManager.shared.showToast(err)
        }
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
