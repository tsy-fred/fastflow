import Cocoa

/// 现代化信息叠加视图 — 替代 ExifTextView
/// Modern info overlay view — replaces ExifTextView
class InfoOverlayView: NSView {

    /// 当前显示的模块
    /// Currently displayed modules
    var modules: [InfoModule] = [] {
        didSet {
            invalidateIntrinsicContentSize()
            needsDisplay = true
        }
    }

    /// 是否可见
    /// Whether visible
    var isOverlayVisible: Bool = true {
        didSet { isHidden = !isOverlayVisible; needsLayout = true }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard !modules.isEmpty else { return }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let isDark = effectiveAppearance.name == .darkAqua
        let bgColor: NSColor = isDark
            ? NSColor(calibratedWhite: 0.0, alpha: 0.55)
            : NSColor(calibratedWhite: 0.0, alpha: 0.40)
        let textColor: NSColor = .white
        let dimColor: NSColor = NSColor(calibratedWhite: 1.0, alpha: 0.65)
        let sepColor: NSColor = NSColor(calibratedWhite: 1.0, alpha: 0.15)

        let padding: CGFloat = 12
        let moduleSpacing: CGFloat = 2
        let lineHeight: CGFloat = 18
        let fontSize: CGFloat = 12
        let keyFont = NSFont.boldSystemFont(ofSize: fontSize)
        let valFont = NSFont.systemFont(ofSize: fontSize)
        let titleFont = NSFont.systemFont(ofSize: 10)

        // Calculate layout
        var y: CGFloat = padding
        let maxWidth = frame.width - padding * 2

        // Draw background
        let bgRect = bounds
        let bezier = NSBezierPath(roundedRect: bgRect, xRadius: DSCorner.medium, yRadius: DSCorner.medium)
        bgColor.setFill()
        bezier.fill()

        // Draw module sections
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail

        for module in modules {
            // Module title
            if module.type != .filename {
                let titleAttr: [NSAttributedString.Key: Any] = [
                    .font: titleFont,
                    .foregroundColor: dimColor,
                    .paragraphStyle: paragraphStyle,
                ]
                let title = (module.type.localizedName.uppercased() as NSString)
                let titleSize = title.size(withAttributes: titleAttr)
                if y + titleSize.height + 4 > frame.height - padding { break }
                title.draw(at: NSPoint(x: padding, y: frame.height - y - titleSize.height),
                           withAttributes: titleAttr)
                y += titleSize.height + 4
            }

            for line in module.lines {
                let maxLabelWidth: CGFloat = maxWidth * 0.35
                let maxValueWidth = maxWidth - maxLabelWidth - 4

                // Label
                let labelAttr: [NSAttributedString.Key: Any] = [
                    .font: keyFont,
                    .foregroundColor: dimColor,
                    .paragraphStyle: paragraphStyle,
                ]
                let labelStr = line.label.isEmpty ? "" : "\(line.label):"

                // Value
                let valueAttr: [NSAttributedString.Key: Any] = [
                    .font: valFont,
                    .foregroundColor: textColor,
                    .paragraphStyle: paragraphStyle,
                ]

                let valStr = line.value as NSString
                let valSize = valStr.size(withAttributes: valueAttr)

                if y + lineHeight > frame.height - padding { break }

                if !line.label.isEmpty {
                    let labelStrN = labelStr as NSString
                    let labelSize = labelStrN.size(withAttributes: labelAttr)
                    // Truncate label if too long
                    let labelW = min(labelSize.width, maxLabelWidth)
                    labelStrN.draw(at: NSPoint(x: padding, y: frame.height - y - labelSize.height),
                                   withAttributes: labelAttr)
                    // Value aligned right of label
                    let valX = padding + labelW + 4
                    let valW = min(valSize.width, frame.width - valX - padding)
                    valStr.draw(at: NSPoint(x: valX, y: frame.height - y - valSize.height),
                                withAttributes: valueAttr)
                } else {
                    // Full-width value (e.g. filename)
                    let valW = min(valSize.width, maxWidth)
                    valStr.draw(at: NSPoint(x: padding, y: frame.height - y - valSize.height),
                                withAttributes: valueAttr)
                }
                y += lineHeight
            }

            // Separator between modules
            if module != modules.last {
                let sepY = frame.height - y - 6
                ctx.setStrokeColor(sepColor.cgColor)
                ctx.setLineWidth(0.5)
                ctx.move(to: CGPoint(x: padding, y: sepY))
                ctx.addLine(to: CGPoint(x: frame.width - padding, y: sepY))
                ctx.strokePath()
                y += 6
            }
        }
    }

    // MARK: - Size

    override var intrinsicContentSize: NSSize {
        guard !modules.isEmpty else { return .zero }
        return NSSize(width: 220, height: calculatedHeight())
    }

    private func calculatedHeight() -> CGFloat {
        let padding: CGFloat = 12
        let lineHeight: CGFloat = 18
        let titleHeight: CGFloat = 14
        let sepHeight: CGFloat = 8
        var h = padding
        for module in modules {
            if module.type != .filename { h += titleHeight + 4 }
            h += CGFloat(module.lines.count) * lineHeight
            if module != modules.last { h += sepHeight }
        }
        h += padding
        return h
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        invalidateIntrinsicContentSize()
    }
}
