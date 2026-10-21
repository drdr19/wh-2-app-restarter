import Cocoa

/// 一个可重启的目标应用
struct RunningAppItem {
    let name: String
    let bundleID: String
    let icon: NSImage
    let bundleURL: URL
    let app: NSRunningApplication

    var processIdentifier: pid_t { app.processIdentifier }
}

/// 列出当前所有「有窗口界面」的应用（排除自己、后台服务、无 bundle 的进程）
enum RunningAppsProvider {

    static func fetch() -> [RunningAppItem] {
        let selfPID = ProcessInfo.processInfo.processIdentifier
        let selfBundleID = Bundle.main.bundleIdentifier

        let items: [RunningAppItem] = NSWorkspace.shared.runningApplications.compactMap { app in
            // 只要常规前台应用：后台 agent / 守护进程不出现
            guard app.activationPolicy == .regular else { return nil }
            guard app.processIdentifier != selfPID else { return nil }
            if let selfBundleID, app.bundleIdentifier == selfBundleID { return nil }

            guard let name = app.localizedName, !name.isEmpty else { return nil }
            guard let url = app.bundleURL else { return nil }
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }

            return RunningAppItem(
                name: name,
                bundleID: app.bundleIdentifier ?? "",
                icon: app.icon ?? NSWorkspace.shared.icon(forFile: url.path),
                bundleURL: url,
                app: app
            )
        }

        return items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
