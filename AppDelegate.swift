import Cocoa

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var mainWindowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenuBar()
        mainWindowController = MainWindowController()
        mainWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func buildMenuBar() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit \(AppConfig.windowTitle)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
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

    @objc private func zoomIn(_ sender: Any?) {
        mainWindowController?.zoomIn()
    }

    @objc private func zoomOut(_ sender: Any?) {
        mainWindowController?.zoomOut()
    }

    @objc private func resetZoom(_ sender: Any?) {
        mainWindowController?.resetZoom()
    }
}
