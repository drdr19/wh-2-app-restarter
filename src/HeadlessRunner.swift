import Cocoa

/// 无界面运行：`应用重启器 --restart <bundleID>`
/// 用于脚本调用，也用来验证退出权限是否正常
enum HeadlessRunner {

    private static let engine = RestartEngine()

    static func run(bundleID: String) {
        let application = NSApplication.shared

        DispatchQueue.main.async {
            guard let target = RunningAppsProvider.fetch().first(where: { $0.bundleID == bundleID }) else {
                FileHandle.standardError.write(Data("未找到正在运行的 \(bundleID)\n".utf8))
                exit(2)
            }

            print("目标：\(target.name)  pid=\(target.processIdentifier)")

            engine.restart(target, onProgress: { message in
                print("  · \(message)")
            }, completion: { outcome in
                switch outcome {
                case .success:
                    print("✅ 重启完成")
                    exit(0)
                case .failure(let message):
                    print("❌ \(message)")
                    exit(1)
                }
            })
        }

        application.run()
    }
}
