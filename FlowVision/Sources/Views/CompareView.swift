import Cocoa

/// 对比模式视图（2-4 图并排，同步缩放/平移）
/// Compare mode view: side-by-side images with synchronized zoom/pan
class CompareView: NSView {

    var urls: [URL] = []
    var synchronized: Bool = false {
        didSet { syncButton?.state = synchronized ? .on : .off }
    }

    private var cells: [CompareCell] = []
    private var exitAction: (() -> Void)?
    private var syncButton: NSButton?

    // MARK: - Init

    convenience init(urls: [URL], exitAction: (() -> Void)? = nil) {
        self.init(frame: .zero)
        self.urls = urls
        self.exitAction = exitAction
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        buildContent()
    }

    private func buildContent() {
        subviews.forEach { $0.removeFromSuperview() }

        let count = min(max(urls.count, 1), 4)

        let columns = count <= 2 ? count : 2
        let rows = (count + columns - 1) / columns

        // Top toolbar — use Auto Layout internally, pinned to our bounds
        let toolbar = NSView()
        toolbar.wantsLayer = true
        toolbar.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.85).cgColor
        toolbar.autoresizingMask = [.width, .minYMargin]
        addSubview(toolbar)

        let exitBtn = NSButton(title: NSLocalizedString("Exit Compare", comment: ""), target: self, action: #selector(exitCompare))
        exitBtn.bezelStyle = .rounded
        exitBtn.sizeToFit()
        exitBtn.autoresizingMask = [.maxXMargin]
        toolbar.addSubview(exitBtn)

        syncButton = NSButton(checkboxWithTitle: NSLocalizedString("Synchronized", comment: ""), target: self, action: #selector(toggleSync(_:)))
        syncButton?.state = synchronized ? .on : .off
        syncButton?.sizeToFit()
        syncButton?.autoresizingMask = [.maxXMargin]
        toolbar.addSubview(syncButton!)

        cells = []
        for i in 0..<count {
            let cell = CompareCell()
            cell.loadImage(url: urls[i])
            addSubview(cell)
            cells.append(cell)

            let label = NSTextField(labelWithString: urls[i].lastPathComponent)
            label.font = NSFont.systemFont(ofSize: 11)
            label.textColor = .white
            label.wantsLayer = true
            label.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.5).cgColor
            label.layer?.cornerRadius = 4
            label.alignment = .center
            cell.addSubview(label)
        }

        layoutContent()
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        layoutContent()
    }

    /// 手动触发布局（frame 改变后调用）
    /// Trigger manual layout after frame change
    func performLayout() {
        layoutContent()
    }

    private func layoutContent() {
        let count = min(max(urls.count, 1), 4)
        let columns = count <= 2 ? count : 2
        let rows = (count + columns - 1) / columns

        let w = bounds.width
        let h = bounds.height
        let toolbarH: CGFloat = 40
        let gap: CGFloat = 1

        // Toolbar at top
        if let tb = subviews.first as? NSView, tb !== cells.first {
            tb.frame = NSRect(x: 0, y: h - toolbarH, width: w, height: toolbarH)
            if let btn = tb.subviews.first as? NSButton {
                btn.frame = NSRect(x: 12, y: (toolbarH - btn.frame.height) / 2, width: btn.frame.width, height: btn.frame.height)
            }
            if let sync = tb.subviews.last as? NSButton, sync !== tb.subviews.first {
                let ref = tb.subviews.first?.frame.maxX ?? 0
                sync.frame = NSRect(x: ref + 20, y: (toolbarH - sync.frame.height) / 2, width: sync.frame.width, height: sync.frame.height)
            }
        }

        // Image cells
        let availW = w - gap * CGFloat(columns - 1)
        let availH = h - toolbarH - gap * CGFloat(rows - 1)
        let cellW = availW / CGFloat(columns)
        let cellH = availH / CGFloat(rows)

        for (i, cell) in cells.enumerated() {
            let col = i % columns
            let row = i / columns
            let x = CGFloat(col) * (cellW + gap)
            let y = (h - toolbarH) - CGFloat(row + 1) * (cellH + gap)
            cell.frame = NSRect(x: x, y: y, width: cellW, height: cellH)

            // filename label
            if let label = cell.subviews.compactMap({ $0 as? NSTextField }).first {
                label.frame = NSRect(x: 8, y: 8, width: cellW - 16, height: 18)
            }
        }
    }

    // MARK: - Actions

    @objc private func exitCompare() {
        exitAction?()
    }

    @objc private func toggleSync(_ sender: NSButton) {
        synchronized = sender.state == .on
    }

    func synchronizeZoom(from source: CompareCell) {
        guard synchronized else { return }
        for cell in cells where cell !== source {
            cell.setZoom(source.currentZoom)
        }
    }

    func synchronizeScroll(from source: CompareCell) {
        guard synchronized else { return }
        for cell in cells where cell !== source {
            cell.setScrollOffset(source.currentScrollOffset)
        }
    }
}

// MARK: - CompareCell

class CompareCell: NSView {

    private let imageView = NSImageView()

    var currentZoom: CGFloat = 0
    var currentScrollOffset: CGPoint = .zero

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        imageView.wantsLayer = true
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.autoresizingMask = [.width, .height]
        imageView.frame = bounds
        addSubview(imageView)
    }

    func loadImage(url: URL) {
        guard let data = try? Data(contentsOf: url),
              let img = NSImage(data: data) else {
            log("CompareCell: failed to load \(url.path)")
            return
        }
        imageView.image = img

        let viewSize = bounds.size
        if viewSize.width > 0, viewSize.height > 0 {
            currentZoom = min(viewSize.width / max(img.size.width, 1),
                              viewSize.height / max(img.size.height, 1))
        }
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        guard let img = imageView.image else { return }
        let viewSize = bounds.size
        guard viewSize.width > 0, viewSize.height > 0 else { return }
        currentZoom = min(viewSize.width / max(img.size.width, 1),
                          viewSize.height / max(img.size.height, 1))
    }

    func setZoom(_ zoom: CGFloat) {
        guard let img = imageView.image else { return }
        currentZoom = max(0.05, zoom)
        let w = img.size.width * currentZoom
        let h = img.size.height * currentZoom
        imageView.frame = CGRect(x: 0, y: 0, width: w, height: h)
    }

    func setScrollOffset(_ offset: CGPoint) {
        currentScrollOffset = offset
    }

    // MARK: - Zoom (Cmd + scroll)

    override func scrollWheel(with event: NSEvent) {
        guard event.modifierFlags.contains(.command) else {
            super.scrollWheel(with: event)
            return
        }

        let delta = event.deltaY
        guard delta != 0, let img = imageView.image, currentZoom > 0 else { return }

        let zoomFactor: CGFloat = delta > 0 ? 1.1 : 0.9
        let newZoom = max(0.05, min(50, currentZoom * zoomFactor))
        setZoom(newZoom)
    }

    override func mouseDown(with event: NSEvent) {
        // pass through drag for scrolling when zoomed
    }
}

/// Helper: flipped-coordinate NSImageView so y increases downward
/// Helper: flipped-coordinate NSImageView so y increases downward
class FlippedImageView: NSImageView {
    override var isFlipped: Bool { true }
}

// MARK: - ViewController extension 对比模式
// MARK: - ViewController extension for compare mode

extension ViewController {
    /// 检查是否在对比模式
    /// Check if compare mode is active
    var isCompareMode: Bool {
        compareView != nil && compareView?.superview != nil
    }

    /// 进入/退出对比模式
    /// Enter / Exit compare mode
    @objc func toggleCompareMode() {
        if isCompareMode {
            exitCompareMode()
        } else {
            enterCompareMode()
        }
    }

    private func enterCompareMode() {
        var urls = publicVar.selectedUrls()

        // 预览大图但不足 2 张时，从文件列表补足相邻图片用于对比
        // Supplement with adjacent images when in large view
        if urls.count < 2, publicVar.isInLargeView {
            let currentPath = largeImageView.file.path
            if !currentPath.isEmpty {
                fileDB.lock()
                if let files = fileDB.db[SortKeyDir(fileDB.curFolder)]?.files {
                    var currentIdx: Int?
                    for (i, pair) in files.enumerated() {
                        if pair.1.path == currentPath {
                            currentIdx = i
                            break
                        }
                    }
                    if let idx = currentIdx {
                        for j in (idx + 1)..<min(idx + 4, files.count) {
                            if let p = files.elementSafe(atOffset: j)?.1.path {
                                urls.append(URL(string: p)!)
                            }
                        }
                    }
                }
                fileDB.unlock()
            }
        }

        guard urls.count >= 2 else { return }

        let cv = CompareView(urls: Array(urls.prefix(4))) { [weak self] in
            self?.exitCompareMode()
        }
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.wantsLayer = true

        // 使用内容面板（largeImageView 的父视图，包含大图和缩略图视图两者）作为容器
        // Use the content panel (largeImageView's superview, containing both image views)
        let container = largeImageView.superview ?? view
        cv.frame = container.bounds
        cv.autoresizingMask = [.width, .height]
        cv.performLayout()
        container.addSubview(cv)

        compareView = cv
    }

    func exitCompareMode() {
        compareView?.removeFromSuperview()
        compareView = nil
    }

    /// 对比模式入口（由快捷键/菜单调用）
    /// Compare mode entry point (called by shortcut / menu)
    func handleCompare() {
        toggleCompareMode()
    }
}
