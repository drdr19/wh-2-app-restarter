import Cocoa

/// 重启引擎：温和退出优先，关不掉再逐级升级
///
/// 三档策略：
/// 1. terminate()：发送系统"退出"事件，应用有机会保存文件再退出
/// 2. SIGTERM：普通的终止信号
/// 3. SIGKILL：强制结束
///
/// 关于等待时间：某些应用（或系统未授予"自动化"权限时）不会响应退出事件。
/// 这里按 bundleID 记住谁不响应——第一次给 4 秒（留出系统授权弹窗的时间），
/// 确认不响应后以后只等 1.2 秒，避免每次重启都干等。
final class RestartEngine {

    enum Outcome {
        case success
        case failure(String)
    }

    private static let slowQuitKey = "SlowQuitBundleIDs"

    private var timer: Timer?
    private var bundleID: String = ""

    deinit { cancel() }

    func cancel() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - 主流程

    func restart(_ target: RunningAppItem,
                 onProgress: @escaping (String) -> Void,
                 completion: @escaping (Outcome) -> Void) {

        cancel()

        let app = target.app
        let pid = target.processIdentifier
        let url = target.bundleURL
        let name = target.name
        bundleID = target.bundleID

        // 已经不在运行：直接打开
        if app.isTerminated || !Self.isAlive(pid) {
            onProgress("\(name) 当前没有运行，正在打开…")
            open(url: url, name: name, completion: completion)
            return
        }

        let isSlowQuitter = Self.slowQuitters().contains(bundleID)
        let gracefulTimeout: TimeInterval = isSlowQuitter ? 1.2 : 3.0
        let sigtermGrace: TimeInterval = 0.8
        let totalTimeout: TimeInterval = 10.0

        onProgress("正在请求 \(name) 退出…")
        app.terminate()   // 第一档

        let start = Date()
        var sentSigterm = false
        var sentSigkill = false

        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }

            // 已退出：进入重开
            if app.isTerminated || !Self.isAlive(pid) {
                t.invalidate()
                self.timer = nil
                // 只有没发过 SIGTERM 才算真正的"优雅退出"，可以清掉慢速标记
                if !sentSigterm {
                    Self.markFastQuitter(bundleID)
                }
                onProgress("\(name) 已退出，正在重新打开…")
                self.open(url: url, name: name, completion: completion)
                return
            }

            let elapsed = Date().timeIntervalSince(start)

            // 第二档：普通终止信号
            if !sentSigterm && elapsed > gracefulTimeout {
                sentSigterm = true
                Self.markSlowQuitter(bundleID)
                onProgress("\(name) 没有响应，正在发送终止信号…")
                kill(pid, SIGTERM)
                return
            }

            // 第三档：强制结束
            if !sentSigkill && elapsed > gracefulTimeout + sigtermGrace {
                sentSigkill = true
                onProgress("\(name) 仍未退出，强制关闭…")
                kill(pid, SIGKILL)
                return
            }

            if elapsed > totalTimeout {
                t.invalidate()
                self.timer = nil
                completion(.failure("\(name) 关不掉，可能受系统保护，请手动退出后再试。"))
            }
        }

        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    // MARK: - 重新打开

    /// 进程刚被杀掉时 LaunchServices 可能还没更新状态，直接拉起会报
    /// "miscellaneous error"，所以先等旧实例彻底消失，失败再退避重试。
    private func open(url: URL, name: String, attempt: Int = 1,
                      completion: @escaping (Outcome) -> Void) {

        // 访达由 launchd 托管，退出后系统会自己拉起来，不用我们插手
        if bundleID == "com.apple.finder" {
            waitForSystemRelaunch(name: name, attempt: 1, completion: completion)
            return
        }

        let target = url.standardizedFileURL
        let stillRunning = NSWorkspace.shared.runningApplications.contains {
            $0.bundleURL?.standardizedFileURL == target
        }

        if stillRunning && attempt <= 12 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.open(url: url, name: name, attempt: attempt + 1, completion: completion)
            }
            return
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        NSWorkspace.shared.openApplication(at: url, configuration: config) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let error else {
                    completion(.success)
                    return
                }

                // 前两次失败先退避重试，别急着报错
                if attempt <= 3 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.open(url: url, name: name, attempt: attempt + 1, completion: completion)
                    }
                } else {
                    completion(.failure("打开 \(name) 失败：\(error.localizedDescription)"))
                }
            }
        }
    }

    /// 等系统把（访达这类）托管应用自己拉起来
    private func waitForSystemRelaunch(name: String, attempt: Int,
                                       completion: @escaping (Outcome) -> Void) {
        let alive = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID)
            .contains { !$0.isTerminated }

        if alive {
            completion(.success)
            return
        }

        if attempt > 30 {
            completion(.failure("\(name) 没有自动重启，请手动打开。"))
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.waitForSystemRelaunch(name: name, attempt: attempt + 1, completion: completion)
        }
    }

    // MARK: - 记住谁不响应退出事件

    private static func slowQuitters() -> Set<String> {
        let list = UserDefaults.standard.stringArray(forKey: slowQuitKey) ?? []
        return Set(list)
    }

    private static func markSlowQuitter(_ bundleID: String) {
        guard !bundleID.isEmpty else { return }
        var list = slowQuitters()
        list.insert(bundleID)
        UserDefaults.standard.set(Array(list), forKey: slowQuitKey)
    }

    private static func markFastQuitter(_ bundleID: String) {
        guard !bundleID.isEmpty else { return }
        var list = slowQuitters()
        guard list.contains(bundleID) else { return }
        list.remove(bundleID)
        UserDefaults.standard.set(Array(list), forKey: slowQuitKey)
    }

    // MARK: - 工具

    private static func isAlive(_ pid: pid_t) -> Bool {
        guard pid > 0 else { return false }
        return kill(pid, 0) == 0
    }
}
