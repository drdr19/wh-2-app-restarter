import Cocoa

/// 列表行：圆角高亮，浅色温和
final class RestartRowView: NSTableRowView {

    override func drawSelection(in dirtyRect: NSRect) {
        guard selectionHighlightStyle != .none else { return }
        let rect = bounds.insetBy(dx: 6, dy: 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: 9, yRadius: 9)
        NSColor.controlAccentColor.withAlphaComponent(0.16).setFill()
        path.fill()
    }

    override var isEmphasized: Bool {
        get { false }
        set { }
    }
}

/// 单元格：图标 + 应用名 + bundle id
final class AppCellView: NSTableCellView {

    private let iconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let idLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.wantsLayer = true
        iconView.layer?.cornerRadius = 6
        iconView.layer?.masksToBounds = true

        nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        nameLabel.textColor = .labelColor
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        idLabel.font = .systemFont(ofSize: 10.5)
        idLabel.textColor = .secondaryLabelColor
        idLabel.lineBreakMode = .byTruncatingTail
        idLabel.translatesAutoresizingMaskIntoConstraints = false
        // 让提示更淡一点
        idLabel.alphaValue = 0.85

        addSubview(iconView)
        addSubview(nameLabel)
        addSubview(idLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 11),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14),
            nameLabel.bottomAnchor.constraint(equalTo: centerYAnchor, constant: 0.5),

            idLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            idLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14),
            idLabel.topAnchor.constraint(equalTo: centerYAnchor, constant: 1.5)
        ])
    }

    func configure(name: String, bundleID: String, icon: NSImage) {
        iconView.image = icon
        nameLabel.stringValue = name
        idLabel.stringValue = bundleID
        // 无 bundle id 的行不显示小字
        idLabel.isHidden = bundleID.isEmpty
    }
}
