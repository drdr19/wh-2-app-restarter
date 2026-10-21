import Cocoa

// 入口
// 正常：出窗口让用户选应用（Dock 里有关标）
// 调试/自动化：--restart <bundleID> 直接重启指定应用，不显示界面（不占 Dock）
let arguments = CommandLine.arguments
let application = NSApplication.shared

if let flag = arguments.firstIndex(of: "--restart"), flag + 1 < arguments.count {
    // 命令行模式保持后台形态，不打扰 Dock
    application.setActivationPolicy(.accessory)
    HeadlessRunner.run(bundleID: arguments[flag + 1])
} else {
    // 常规模式：像普通 App 一样出现在 Dock 和 ⌘Tab 里
    application.setActivationPolicy(.regular)
    let appDelegate = AppDelegate()
    application.delegate = appDelegate
    application.run()
}
