import Cocoa

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowControllers: [MainWindowController] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenuBar()
        // Compile the tracker blocklist once, then open one window per profile.
        ContentBlocker.prepare {
            DispatchQueue.main.async {
                self.createWindows()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func createWindows() {
        for (index, profile) in AppConfig.profiles.enumerated() {
            let controller = MainWindowController(profile: profile)
            controller.showWindow(nil)
            // Stagger windows so both are visible on launch
            if index > 0, let window = controller.window {
                var origin = window.frame.origin
                origin.x += 40 * CGFloat(index)
                origin.y -= 40 * CGFloat(index)
                window.setFrameOrigin(origin)
            }
            windowControllers.append(controller)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func keyWindowController() -> MainWindowController? {
        windowControllers.first { $0.window?.isKeyWindow == true } ?? windowControllers.first
    }

    @objc private func zoomIn(_ sender: Any?) {
        keyWindowController()?.zoomIn()
    }

    @objc private func zoomOut(_ sender: Any?) {
        keyWindowController()?.zoomOut()
    }

    @objc private func resetZoom(_ sender: Any?) {
        keyWindowController()?.resetZoom()
    }

    private func buildMenuBar() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Grindr", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")

        let zoomInItem = NSMenuItem(title: "Zoom In", action: #selector(AppDelegate.zoomIn(_:)), keyEquivalent: "+")
        zoomInItem.keyEquivalentModifierMask = [.command]
        zoomInItem.target = self
        viewMenu.addItem(zoomInItem)

        let zoomOutItem = NSMenuItem(title: "Zoom Out", action: #selector(AppDelegate.zoomOut(_:)), keyEquivalent: "-")
        zoomOutItem.keyEquivalentModifierMask = [.command]
        zoomOutItem.target = self
        viewMenu.addItem(zoomOutItem)

        let zoomResetItem = NSMenuItem(title: "Actual Size", action: #selector(AppDelegate.resetZoom(_:)), keyEquivalent: "0")
        zoomResetItem.keyEquivalentModifierMask = [.command]
        zoomResetItem.target = self
        viewMenu.addItem(zoomResetItem)

        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
    }
}
