import Cocoa
import ImageIO
import UniformTypeIdentifiers

/// 批量转换面板
/// Batch convert panel
class BatchConvertPanel: NSWindowController {

    private var urls: [URL] = []

    private var formatPopup: NSPopUpButton!
    private var qualitySlider: NSSlider!
    private var qualityLabel: NSTextField!
    private var resizePopup: NSPopUpButton!
    private var widthField: NSTextField!
    private var heightField: NSTextField!
    private var outputPopup: NSPopUpButton!
    private var subfolderField: NSTextField!
    private var infoLabel: NSTextField!
    private var completion: (() -> Void)?

    private let formatKey = "batchConvertFormat"
    private let qualityKey = "batchConvertQuality"
    private let resizeModeKey = "batchConvertResizeMode"
    private let subfolderKey = "batchConvertSubfolder"

    private static var currentPanel: BatchConvertPanel?

    private enum ResizeMode: Int {
        case none = 0
        case maxDimension = 1
        case percentage = 2
        case exact = 3
    }

    private init(urls: [URL], completion: @escaping () -> Void) {
        self.urls = urls
        self.completion = completion

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered, defer: false
        )
        panel.title = NSLocalizedString("Batch Convert", comment: "批量转换")
        panel.isFloatingPanel = true
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isOpaque = false

        super.init(window: panel)

        panel.contentView = buildContentView()
        panel.setContentSize(NSSize(width: 480, height: 400))
        panel.center()
        panel.title = ""
        panel.invalidateShadow()
    }

    required init?(coder: NSCoder) { nil }

    // MARK: - UI

    private func buildContentView() -> NSView {
        let root = NSVisualEffectView()
        root.wantsLayer = true
        root.material = .popover
        root.state = .active
        root.blendingMode = .withinWindow
        root.layer?.cornerRadius = DSCorner.large
        root.layer?.masksToBounds = true

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 24, bottom: 52, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let defaults = UserDefaults.standard

        // Title
        let titleLabel = NSTextField(labelWithString: NSLocalizedString("Batch Convert", comment: ""))
        titleLabel.font = NSFont.boldSystemFont(ofSize: 14)

        // Format row
        let fmtRow = NSView()
        fmtRow.translatesAutoresizingMaskIntoConstraints = false

        let fmtLabel = NSTextField(labelWithString: NSLocalizedString("Format:", comment: ""))
        fmtLabel.font = NSFont.systemFont(ofSize: 12)
        fmtLabel.translatesAutoresizingMaskIntoConstraints = false

        formatPopup = NSPopUpButton()
        formatPopup.addItems(withTitles: ["JPEG", "PNG", "TIFF", "WebP"])
        formatPopup.selectItem(at: max(0, defaults.integer(forKey: formatKey)))
        formatPopup.target = self
        formatPopup.action = #selector(formatChanged)
        formatPopup.translatesAutoresizingMaskIntoConstraints = false

        let qualLabel = NSTextField(labelWithString: NSLocalizedString("Quality:", comment: ""))
        qualLabel.font = NSFont.systemFont(ofSize: 12)
        qualLabel.translatesAutoresizingMaskIntoConstraints = false

        qualitySlider = NSSlider(value: Double(defaults.integer(forKey: qualityKey).nonZero(85)), minValue: 10, maxValue: 100, target: self, action: #selector(qualityChanged))
        qualitySlider.translatesAutoresizingMaskIntoConstraints = false

        qualityLabel = NSTextField(labelWithString: "\(qualitySlider.integerValue)%")
        qualityLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        qualityLabel.translatesAutoresizingMaskIntoConstraints = false

        fmtRow.addSubview(fmtLabel)
        fmtRow.addSubview(formatPopup)
        fmtRow.addSubview(qualLabel)
        fmtRow.addSubview(qualitySlider)
        fmtRow.addSubview(qualityLabel)
        NSLayoutConstraint.activate([
            fmtRow.heightAnchor.constraint(equalToConstant: 24),
            fmtLabel.leadingAnchor.constraint(equalTo: fmtRow.leadingAnchor),
            fmtLabel.centerYAnchor.constraint(equalTo: fmtRow.centerYAnchor),
            fmtLabel.widthAnchor.constraint(equalToConstant: 60),
            formatPopup.leadingAnchor.constraint(equalTo: fmtLabel.trailingAnchor, constant: 8),
            formatPopup.centerYAnchor.constraint(equalTo: fmtRow.centerYAnchor),
            formatPopup.widthAnchor.constraint(equalToConstant: 90),
            qualLabel.leadingAnchor.constraint(equalTo: formatPopup.trailingAnchor, constant: 16),
            qualLabel.centerYAnchor.constraint(equalTo: fmtRow.centerYAnchor),
            qualitySlider.leadingAnchor.constraint(equalTo: qualLabel.trailingAnchor, constant: 6),
            qualitySlider.centerYAnchor.constraint(equalTo: fmtRow.centerYAnchor),
            qualitySlider.widthAnchor.constraint(equalToConstant: 100),
            qualityLabel.leadingAnchor.constraint(equalTo: qualitySlider.trailingAnchor, constant: 4),
            qualityLabel.centerYAnchor.constraint(equalTo: fmtRow.centerYAnchor),
            qualityLabel.widthAnchor.constraint(equalToConstant: 36),
        ])

        // Resize row
        let resRow = NSView()
        resRow.translatesAutoresizingMaskIntoConstraints = false

        let resizeLabel = NSTextField(labelWithString: NSLocalizedString("Resize:", comment: ""))
        resizeLabel.font = NSFont.systemFont(ofSize: 12)
        resizeLabel.translatesAutoresizingMaskIntoConstraints = false

        resizePopup = NSPopUpButton()
        resizePopup.addItems(withTitles: [
            NSLocalizedString("None", comment: ""),
            NSLocalizedString("Max Dimension", comment: ""),
            NSLocalizedString("Percentage", comment: ""),
            NSLocalizedString("Exact Size", comment: "")
        ])
        resizePopup.selectItem(at: min(defaults.integer(forKey: resizeModeKey), 3))
        resizePopup.target = self
        resizePopup.action = #selector(resizeChanged)
        resizePopup.translatesAutoresizingMaskIntoConstraints = false

        let wLabel = NSTextField(labelWithString: NSLocalizedString("W:", comment: ""))
        wLabel.font = NSFont.systemFont(ofSize: 11)
        wLabel.translatesAutoresizingMaskIntoConstraints = false

        widthField = NSTextField()
        widthField.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        widthField.placeholderString = "px"
        widthField.translatesAutoresizingMaskIntoConstraints = false

        let hLabel = NSTextField(labelWithString: NSLocalizedString("H:", comment: ""))
        hLabel.font = NSFont.systemFont(ofSize: 11)
        hLabel.translatesAutoresizingMaskIntoConstraints = false

        heightField = NSTextField()
        heightField.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        heightField.placeholderString = "px"
        heightField.translatesAutoresizingMaskIntoConstraints = false

        resRow.addSubview(resizeLabel)
        resRow.addSubview(resizePopup)
        resRow.addSubview(wLabel)
        resRow.addSubview(widthField)
        resRow.addSubview(hLabel)
        resRow.addSubview(heightField)
        NSLayoutConstraint.activate([
            resRow.heightAnchor.constraint(equalToConstant: 24),
            resizeLabel.leadingAnchor.constraint(equalTo: resRow.leadingAnchor),
            resizeLabel.centerYAnchor.constraint(equalTo: resRow.centerYAnchor),
            resizeLabel.widthAnchor.constraint(equalToConstant: 60),
            resizePopup.leadingAnchor.constraint(equalTo: resizeLabel.trailingAnchor, constant: 8),
            resizePopup.centerYAnchor.constraint(equalTo: resRow.centerYAnchor),
            resizePopup.widthAnchor.constraint(equalToConstant: 130),
            wLabel.leadingAnchor.constraint(equalTo: resizePopup.trailingAnchor, constant: 12),
            wLabel.centerYAnchor.constraint(equalTo: resRow.centerYAnchor),
            widthField.leadingAnchor.constraint(equalTo: wLabel.trailingAnchor, constant: 4),
            widthField.centerYAnchor.constraint(equalTo: resRow.centerYAnchor),
            widthField.widthAnchor.constraint(equalToConstant: 48),
            hLabel.leadingAnchor.constraint(equalTo: widthField.trailingAnchor, constant: 8),
            hLabel.centerYAnchor.constraint(equalTo: resRow.centerYAnchor),
            heightField.leadingAnchor.constraint(equalTo: hLabel.trailingAnchor, constant: 4),
            heightField.centerYAnchor.constraint(equalTo: resRow.centerYAnchor),
            heightField.widthAnchor.constraint(equalToConstant: 48),
        ])

        // Output row
        let outRow = NSView()
        outRow.translatesAutoresizingMaskIntoConstraints = false

        let outLabel = NSTextField(labelWithString: NSLocalizedString("Output:", comment: ""))
        outLabel.font = NSFont.systemFont(ofSize: 12)
        outLabel.translatesAutoresizingMaskIntoConstraints = false

        outputPopup = NSPopUpButton()
        outputPopup.addItems(withTitles: [
            NSLocalizedString("Same Folder", comment: ""),
            NSLocalizedString("Subfolder", comment: ""),
            NSLocalizedString("Choose…", comment: "")
        ])
        outputPopup.target = self
        outputPopup.action = #selector(outputChanged)
        outputPopup.translatesAutoresizingMaskIntoConstraints = false

        subfolderField = NSTextField()
        subfolderField.font = NSFont.systemFont(ofSize: 12)
        subfolderField.placeholderString = "converted"
        subfolderField.stringValue = defaults.string(forKey: subfolderKey) ?? "converted"
        subfolderField.translatesAutoresizingMaskIntoConstraints = false

        outRow.addSubview(outLabel)
        outRow.addSubview(outputPopup)
        outRow.addSubview(subfolderField)
        NSLayoutConstraint.activate([
            outRow.heightAnchor.constraint(equalToConstant: 24),
            outLabel.leadingAnchor.constraint(equalTo: outRow.leadingAnchor),
            outLabel.centerYAnchor.constraint(equalTo: outRow.centerYAnchor),
            outLabel.widthAnchor.constraint(equalToConstant: 60),
            outputPopup.leadingAnchor.constraint(equalTo: outLabel.trailingAnchor, constant: 8),
            outputPopup.centerYAnchor.constraint(equalTo: outRow.centerYAnchor),
            outputPopup.widthAnchor.constraint(equalToConstant: 130),
            subfolderField.leadingAnchor.constraint(equalTo: outputPopup.trailingAnchor, constant: 8),
            subfolderField.centerYAnchor.constraint(equalTo: outRow.centerYAnchor),
            subfolderField.widthAnchor.constraint(equalToConstant: 120),
        ])

        // Separator
        let sep = NSBox()
        sep.boxType = .separator

        // Info
        infoLabel = NSTextField(labelWithString: "")
        infoLabel.font = NSFont.systemFont(ofSize: 11)
        infoLabel.textColor = .secondaryLabelColor

        // Buttons
        let btnRow = NSView()
        btnRow.translatesAutoresizingMaskIntoConstraints = false

        let cancelBtn = NSButton(title: NSLocalizedString("Cancel", comment: ""), target: self, action: #selector(cancel))
        cancelBtn.bezelStyle = .push
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false

        let convertBtn = NSButton(title: NSLocalizedString("Convert", comment: ""), target: self, action: #selector(doConvert))
        convertBtn.bezelStyle = .push
        convertBtn.keyEquivalent = "\r"
        convertBtn.translatesAutoresizingMaskIntoConstraints = false

        btnRow.addSubview(cancelBtn)
        btnRow.addSubview(convertBtn)
        NSLayoutConstraint.activate([
            btnRow.heightAnchor.constraint(equalToConstant: 28),
            cancelBtn.trailingAnchor.constraint(equalTo: convertBtn.leadingAnchor, constant: -8),
            cancelBtn.centerYAnchor.constraint(equalTo: btnRow.centerYAnchor),
            convertBtn.trailingAnchor.constraint(equalTo: btnRow.trailingAnchor),
            convertBtn.centerYAnchor.constraint(equalTo: btnRow.centerYAnchor),
            btnRow.widthAnchor.constraint(equalToConstant: 180),
        ])

        // Assemble
        stack.addArrangedSubview(titleLabel)
        stack.setCustomSpacing(4, after: titleLabel)
        stack.addArrangedSubview(fmtRow)
        stack.addArrangedSubview(resRow)
        stack.addArrangedSubview(outRow)
        stack.setCustomSpacing(6, after: outRow)
        stack.addArrangedSubview(sep)
        stack.addArrangedSubview(infoLabel)
        stack.addArrangedSubview(btnRow)

        titleLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        fmtRow.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        resRow.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        outRow.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        sep.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        infoLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stack.topAnchor.constraint(equalTo: root.topAnchor),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])

        updateInfo()
        updateResizeFieldsVisibility()
        return root
    }

    // MARK: - Actions

    @objc private func formatChanged() {
        let isJPEG = formatPopup.indexOfSelectedItem == 0
        qualitySlider.isEnabled = isJPEG || formatPopup.indexOfSelectedItem == 3
        qualityLabel.isEnabled = qualitySlider.isEnabled
        updateInfo()
    }

    @objc private func qualityChanged() {
        qualityLabel.stringValue = "\(qualitySlider.integerValue)%"
    }

    @objc private func resizeChanged() {
        updateResizeFieldsVisibility()
        updateInfo()
    }

    private func updateResizeFieldsVisibility() {
        let mode = ResizeMode(rawValue: resizePopup.indexOfSelectedItem) ?? .none
        let hasSizeFields = mode == .maxDimension || mode == .exact
        widthField.isHidden = !hasSizeFields
        heightField.isHidden = !hasSizeFields
    }

    @objc private func outputChanged() {
        if outputPopup.indexOfSelectedItem == 2 {
            let openPanel = NSOpenPanel()
            openPanel.canChooseFiles = false
            openPanel.canChooseDirectories = true
            openPanel.canCreateDirectories = true
            openPanel.beginSheetModal(for: window!) { [weak self] response in
                guard let self = self else { return }
                if response == .OK, let url = openPanel.url {
                    UserDefaults.standard.set(url.path, forKey: "batchConvertCustomPath")
                    self.outputPopup.setTitle(url.lastPathComponent)
                }
                self.outputPopup.selectItem(at: 0)
            }
        }
    }

    private func updateInfo() {
        let fmt = ["JPEG", "PNG", "TIFF", "WebP"][formatPopup.indexOfSelectedItem]
        infoLabel.stringValue = "\(urls.count) \(NSLocalizedString("files → ", comment: ""))\(fmt)"
    }

    @objc private func doConvert() {
        let fmtIndex = formatPopup.indexOfSelectedItem
        let quality = qualitySlider.integerValue
        let resizeMode = ResizeMode(rawValue: resizePopup.indexOfSelectedItem) ?? .none
        let maxW = CGFloat(widthField?.integerValue ?? 0)
        let maxH = CGFloat(heightField?.integerValue ?? 0)
        let subfolder = subfolderField?.stringValue ?? "converted"

        let defaults = UserDefaults.standard
        defaults.set(fmtIndex, forKey: formatKey)
        defaults.set(quality, forKey: qualityKey)
        defaults.set(resizeMode.rawValue, forKey: resizeModeKey)
        defaults.set(subfolder, forKey: subfolderKey)

        let fm = FileManager.default
        var convertedCount = 0
        var errors: [String] = []

        for url in urls {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
                errors.append(url.lastPathComponent)
                continue
            }

            let parentDir = url.deletingLastPathComponent()
            var outputDir = parentDir
            if outputPopup.indexOfSelectedItem == 1 {
                outputDir = parentDir.appendingPathComponent(subfolder)
                try? fm.createDirectory(at: outputDir, withIntermediateDirectories: true)
            } else if outputPopup.indexOfSelectedItem == 2, let customPath = defaults.string(forKey: "batchConvertCustomPath") {
                outputDir = URL(fileURLWithPath: customPath)
            }

            let uttypes = ["public.jpeg", "public.png", "public.tiff", "org.webmproject.webp"]
            let ext = ["jpg", "png", "tiff", "webp"][fmtIndex]
            let baseName = url.deletingPathExtension().lastPathComponent
            let destURL = outputDir.appendingPathComponent("\(baseName).\(ext)")

            guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                errors.append(url.lastPathComponent)
                continue
            }

            var finalImage = image
            if resizeMode != .none {
                let w = CGFloat(image.width)
                let h = CGFloat(image.height)
                var newW = w
                var newH = h

                switch resizeMode {
                case .maxDimension:
                    let maxDim = max(maxW, maxH)
                    if maxDim > 0 && (w > maxDim || h > maxDim) {
                        let ratio = min(maxDim / w, maxDim / h)
                        newW = w * ratio
                        newH = h * ratio
                    }
                case .percentage:
                    let pct = maxW > 0 ? maxW / 100.0 : 1.0
                    newW = w * pct
                    newH = h * pct
                case .exact:
                    newW = maxW > 0 ? maxW : w
                    newH = maxH > 0 ? maxH : h
                default:
                    break
                }

                if newW != w || newH != h {
                    let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
                    let bpc = image.bitsPerComponent
                    let bitmapInfo = image.bitmapInfo
                    if let ctx = CGContext(data: nil, width: Int(newW), height: Int(newH), bitsPerComponent: bpc, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo.rawValue),
                       let imgRef = ctx.makeImage() {
                        finalImage = imgRef
                    }
                }
            }

            let uttype = uttypes[fmtIndex] as CFString
            guard let dest = CGImageDestinationCreateWithURL(destURL as CFURL, uttype, 1, nil) else {
                errors.append(url.lastPathComponent)
                continue
            }

            var props: [CFString: Any] = [:]
            if fmtIndex == 0 || fmtIndex == 3 {
                props[kCGImageDestinationLossyCompressionQuality] = Double(quality) / 100.0
            }

            CGImageDestinationAddImage(dest, finalImage, props as CFDictionary)
            if CGImageDestinationFinalize(dest) {
                convertedCount += 1
            } else {
                errors.append(url.lastPathComponent)
            }
        }

        window?.close()
        Self.currentPanel = nil

        if !errors.isEmpty {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Convert completed", comment: "")
            alert.informativeText = "\(convertedCount)/\(urls.count) \(NSLocalizedString("files converted", comment: ""))"
            alert.alertStyle = convertedCount > 0 ? .informational : .critical
            alert.runModal()
        }

        completion?()
    }

    @objc private func cancel() {
        window?.close()
        Self.currentPanel = nil
        completion?()
    }

    // MARK: - Show

    static func show(urls: [URL], completion: @escaping () -> Void) {
        let panel = BatchConvertPanel(urls: urls, completion: completion)
        Self.currentPanel = panel
        panel.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Int helper

private extension Int {
    func nonZero(_ defaultVal: Int) -> Int {
        self == 0 ? defaultVal : self
    }
}
