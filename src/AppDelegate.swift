import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var windowController: MainWindowController?
    private let appName = "WH-2：应用重启器"

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()

        let controller = MainWindowController()
        windowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 窗口一关就退出，符合"用完即走"的定位
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    /// 点 Dock 图标时，如果窗口不在就再开一个
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            windowController?.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        return true
    }

    // MARK: - 菜单栏

    /// 有了 Dock 图标就该有菜单栏；编辑菜单尤其重要，
    /// 否则搜索框里的 ⌘C / ⌘V / ⌘A 全都用不了。
    private func buildMenu() {
        let mainMenu = NSMenu()

        // 应用菜单
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        appMenu.addItem(withTitle: "关于\(appName)",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "隐藏\(appName)",
                        action: #selector(NSApplication.hide(_:)),
                        keyEquivalent: "h")

        let hideOthers = appMenu.addItem(withTitle: "隐藏其他",
                                         action: #selector(NSApplication.hideOtherApplications(_:)),
                                         keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]

        appMenu.addItem(withTitle: "显示全部",
                        action: #selector(NSApplication.unhideAllApplications(_:)),
                        keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出\(appName)",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")

        // 编辑菜单
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "编辑")
        editMenuItem.submenu = editMenu

        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        // 窗口菜单
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "窗口")
        windowMenuItem.submenu = windowMenu

        windowMenu.addItem(withTitle: "关闭",
                           action: #selector(NSWindow.performClose(_:)),
                           keyEquivalent: "w")
        windowMenu.addItem(withTitle: "前置全部窗口",
                           action: #selector(NSApplication.arrangeInFront(_:)),
                           keyEquivalent: "")

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
    }
}
