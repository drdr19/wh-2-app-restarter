import Cocoa

final class MainWindowController: NSWindowController,
                                  NSTableViewDataSource,
                                  NSTableViewDelegate,
                                  NSSearchFieldDelegate {

    private let searchField = NSSearchField()
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let hintLabel = NSTextField(labelWithString: "↩ 重启    esc 关闭")
    private let spinner = NSProgressIndicator()
    private let emptyLabel = NSTextField(labelWithString: "没有找到可重启的应用")

    private let engine = RestartEngine()
    private var allItems: [RunningAppItem] = []
    private var filteredItems: [RunningAppItem] = []
    private var isBusy = false
    private var keyMonitor: Any?

    // MARK: - 初始化

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 600),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "重启应用"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .windowBackgroundColor
        window.center()

        super.init(window: window)

        buildInterface()
        installKeyMonitor()
        reloadApps()
    }

    required init?(coder: NSCoder) {
        fatalError("不支持从 nib 载入")
    }

    deinit {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(searchField)
    }

    // MARK: - 界面

    private func buildInterface() {
        guard let contentView = window?.contentView else { return }

        // 搜索框
        searchField.placeholderString = "搜索应用"
        searchField.font = .systemFont(ofSize: 13)
        searchField.delegate = self
        searchField.sendsSearchStringImmediately = true
        searchField.focusRingType = .none
        searchField.translatesAutoresizingMaskIntoConstraints = false

        // 列表
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 46
        tableView.intercellSpacing = NSSize(width: 0, height: 1)
        tableView.backgroundColor = .clear
        tableView.style = .plain
        tableView.selectionHighlightStyle = .regular
        tableView.allowsEmptySelection = true
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(rowDoubleClicked)

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 2, left: 0, bottom: 10, right: 0)
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        // 空状态提示
        emptyLabel.font = .systemFont(ofSize: 12.5)
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.isHidden = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        // 底栏
        let hairline = NSBox()
        hairline.boxType = .separator
        hairline.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = .systemFont(ofSize: 11.5)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        hintLabel.font = .systemFont(ofSize: 11)
        hintLabel.textColor = .tertiaryLabelColor
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        hintLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        spinner.isHidden = true
        spinner.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(searchField)
        contentView.addSubview(scrollView)
        contentView.addSubview(emptyLabel)
        contentView.addSubview(hairline)
        contentView.addSubview(statusLabel)
        contentView.addSubview(hintLabel)
        contentView.addSubview(spinner)

        NSLayoutConstraint.activate([
            // 搜索框（左侧避开红绿灯）
            searchField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 13),
            searchField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 78),
            searchField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            searchField.heightAnchor.constraint(equalToConstant: 26),

            // 列表
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 11),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
            scrollView.bottomAnchor.constraint(equalTo: hairline.topAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),

            // 底栏分隔线
            hairline.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            hairline.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            hairline.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -46),
            hairline.heightAnchor.constraint(equalToConstant: 1),

            // 状态文字
            spinner.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            spinner.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
            spinner.widthAnchor.constraint(equalToConstant: 12),
            spinner.heightAnchor.constraint(equalToConstant: 12),

            statusLabel.leadingAnchor.constraint(equalTo: spinner.trailingAnchor, constant: 7),
            statusLabel.centerYAnchor.constraint(equalTo: hairline.bottomAnchor, constant: 23),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: hintLabel.leadingAnchor, constant: -12),

            hintLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            hintLabel.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor)
        ])
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let window = self.window, window.isKeyWindow else { return event }

            if event.modifierFlags.contains(.command) {
                if event.charactersIgnoringModifiers?.lowercased() == "r" {
                    self.reloadApps()
                    return nil
                }
                return event
            }

            switch event.keyCode {
            case 53:   // esc
                if !self.searchField.stringValue.isEmpty {
                    self.searchField.stringValue = ""
                    self.applyFilter()
                } else {
                    NSApp.terminate(nil)
                }
                return nil

            case 36, 76:   // return / enter
                self.performRestart()
                return nil

            case 125, 126: // ↓ / ↑
                if self.searchField.currentEditor() != nil {
                    window.makeFirstResponder(self.tableView)
                    self.moveSelection(by: event.keyCode == 125 ? 1 : -1)
                    return nil
                }
                return event

            default:
                return event
            }
        }
    }

    // MARK: - 数据

    private func reloadApps() {
        guard !isBusy else { return }
        allItems = RunningAppsProvider.fetch()
        applyFilter()
    }

    private func applyFilter() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if query.isEmpty {
            filteredItems = allItems
        } else {
            filteredItems = allItems.filter {
                $0.name.lowercased().contains(query) || $0.bundleID.lowercased().contains(query)
            }
        }

        tableView.reloadData()
        emptyLabel.isHidden = !filteredItems.isEmpty
        emptyLabel.stringValue = query.isEmpty ? "没有正在运行的应用" : "没有匹配的应用"

        if !filteredItems.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            tableView.scrollRowToVisible(0)
        }

        updateStatusText()
    }

    private func updateStatusText() {
        statusLabel.textColor = .secondaryLabelColor
        if filteredItems.isEmpty {
            statusLabel.stringValue = searchField.stringValue.isEmpty
                ? "当前没有可重启的应用"
                : "没有匹配的应用"
        } else {
            statusLabel.stringValue = "\(filteredItems.count) 个应用正在运行 ⌘R 刷新"
        }
    }

    private func moveSelection(by delta: Int) {
        guard !filteredItems.isEmpty else { return }
        var row = tableView.selectedRow
        if row < 0 { row = delta > 0 ? -1 : 0 }
        let next = max(0, min(filteredItems.count - 1, row + delta))
        tableView.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
        tableView.scrollRowToVisible(next)
    }

    // MARK: - 动作

    @objc private func rowDoubleClicked() {
        performRestart()
    }

    private func performRestart() {
        guard !isBusy else { return }
        let row = tableView.selectedRow
        guard row >= 0, row < filteredItems.count else { return }

        let item = filteredItems[row]
        isBusy = true
        searchField.isEnabled = false
        tableView.alphaValue = 0.45
        spinner.isHidden = false
        spinner.startAnimation(nil)
        hintLabel.isHidden = true
        statusLabel.textColor = .secondaryLabelColor

        engine.restart(item, onProgress: { [weak self] message in
            self?.statusLabel.stringValue = message
        }, completion: { [weak self] outcome in
            guard let self else { return }
            self.spinner.stopAnimation(nil)
            self.spinner.isHidden = true

            switch outcome {
            case .success:
                self.statusLabel.stringValue = "✓ 已重启 \(item.name)，正在关闭…"
                self.statusLabel.textColor = .labelColor
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    NSApp.terminate(nil)
                }

            case .failure(let message):
                self.statusLabel.stringValue = message
                self.statusLabel.textColor = .systemRed
                self.isBusy = false
                self.searchField.isEnabled = true
                self.tableView.alphaValue = 1
                self.hintLabel.isHidden = false
            }
        })
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        applyFilter()
    }

    // MARK: - NSTableViewDataSource / Delegate

    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredItems.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("AppCell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? AppCellView
            ?? AppCellView(frame: .zero)
        cell.identifier = identifier

        let item = filteredItems[row]
        cell.configure(name: item.name, bundleID: item.bundleID, icon: item.icon)
        return cell
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return RestartRowView()
    }

    // MARK: - 窗口关闭

    override func windowDidLoad() {
        super.windowDidLoad()
    }

    func windowWillClose(_ notification: Notification) {
        engine.cancel()
    }
}
