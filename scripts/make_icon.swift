import Cocoa

// 生成 App 图标：圆角渐变底 + 白色循环箭头
// 用法：swift scripts/make_icon.swift assets/icon-1024.png
let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "assets/icon-1024.png"
let px = 1024

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: px, pixelsHigh: px,
    bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0
) else { fatalError("无法创建位图") }

rep.size = NSSize(width: px, height: px)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.imageInterpolation = .high

let size = CGFloat(px)
let inset: CGFloat = size * 0.098
let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let radius = rect.width * 0.2237   // macOS squircle 比例

let square = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

// 轻微投影，让图标有体积感
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
shadow.shadowBlurRadius = size * 0.022
shadow.shadowOffset = NSSize(width: 0, height: -size * 0.008)
shadow.set()

NSColor.white.setFill()
square.fill()

NSGraphicsContext.current?.saveGraphicsState()
NSShadow().set()

let gradient = NSGradient(colors: [
    NSColor(srgbRed: 0.368, green: 0.443, blue: 0.960, alpha: 1.0),
    NSColor(srgbRed: 0.588, green: 0.306, blue: 0.878, alpha: 1.0)
])!
gradient.draw(in: square, angle: -68)

// 顶部高光
let highlight = NSGradient(colors: [
    NSColor.white.withAlphaComponent(0.26),
    NSColor.white.withAlphaComponent(0.0)
])!
let highlightPath = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
highlight.draw(in: highlightPath, angle: -90)

// 白色循环箭头
let config = NSImage.SymbolConfiguration(pointSize: size * 0.40, weight: .semibold)
    .applying(NSImage.SymbolConfiguration(hierarchicalColor: .white))

var drawn = false
if let symbol = NSImage(systemSymbolName: "arrow.triangle.2.circlepath",
                        accessibilityDescription: nil)?
    .withSymbolConfiguration(config) {
    let w = symbol.size.width
    let h = symbol.size.height
    let target = NSRect(x: (size - w) / 2, y: (size - h) / 2, width: w, height: h)
    symbol.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1.0)
    drawn = true
}

// 极端环境兜底：画不了符号就画个圆环
if !drawn {
    let ring = NSBezierPath()
    ring.appendArc(withCenter: NSPoint(x: size / 2, y: size / 2),
                   radius: size * 0.17, startAngle: 30, endAngle: 330)
    ring.lineWidth = size * 0.035
    NSColor.white.setStroke()
    ring.stroke()
}

NSGraphicsContext.current?.restoreGraphicsState()
NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("PNG 编码失败")
}
try png.write(to: URL(fileURLWithPath: output))
print("✅ 已生成 \(output) (\(px)x\(px))")
