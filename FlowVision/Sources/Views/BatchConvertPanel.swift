import Cocoa
import ImageIO
import UniformTypeIdentifiers
import CoreImage

/// 批量转换面板
/// Batch convert panel
class BatchConvertPanel: NSWindowController, NSTextFieldDelegate {

    private var urls: [URL] = []
    private var completion: (() -> Void)?

    // UI elements
    private var formatPopup: NSPopUpButton!
    private var qualitySlider: NSSlider!
    private var qualityLabel: NSTextField!
    private var resizePopup: NSPopUpButton!
    private var sizeField: NSTextField!
    private var widthField: NSTextField!
    private var heightField: NSTextField!
    private var sizeFieldLabel: NSTextField!
    private var presetStack: NSStackView!
    private var pctSlider: NSSlider!
    private var pctSliderLabel: NSTextField!
    private var outputPopup: NSPopUpButton!
    private var subfolderField: NSTextField!
    private var trashCheckbox: NSButton!
    private var infoLabel: NSTextField!

    private var sizeSingleRow: NSView!
    private var sizeDoubleRow: NSView!
    private var pctSliderRow: NSView!

    private let formatKey = "batchConvertFormat"
    private let qualityKey = "batchConvertQuality"
    private let resizeModeKey = "batchConvertResizeModeV2"
    private let resizeValueKey = "batchConvertResizeValue"
    private let subfolderKey = "batchConvertSubfolder"
    private let trashSourceKey = "batchConvertTrashSource"

    private static var currentPanel: BatchConvertPanel?

    private lazy var ciContext: CIContext = {
        CIContext(options: [.highQualityDownsample: true, .workingColorSpace: NSNull()])
    }()

    private enum ResizeMode: Int, CaseIterable {
        case none = 0
        case longestSide = 1
        case shortestSide = 2
        case percentage = 3
        case exact = 4

        var label: String {
            switch self {
            case .none: return NSLocalizedString("None", comment: "")
            case .longestSide: return NSLocalizedString("Longest Side", comment: "最长边")
            case .shortestSide: return NSLocalizedString("Shortest Side", comment: "最短边")
            case .percentage: return NSLocalizedString("Percentage", comment: "百分比")
            case .exact: return NSLocalizedString("Exact Size", comment: "精确尺寸")
            }
        }
    }

    private init(urls: [URL], completion: @escaping () -> Void) {
        self.urls = urls
        self.completion = completion

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 380),
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
        panel.setContentSize(NSSize(width: 480, height: 380))
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
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 24, bottom: 48, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let defaults = UserDefaults.standard

        // Title
        let titleLabel = NSTextField(labelWithString: NSLocalizedString("Batch Convert", comment: ""))
        titleLabel.font = NSFont.boldSystemFont(ofSize: 14)

        // Format row
        let fmtRow = buildFormatRow(defaults: defaults)

        // Resize section
        let resizeSection = buildResizeSection(defaults: defaults)

        // Output section
        let outputSection = buildOutputSection(defaults: defaults)

        // Separator
        let sep = NSBox()
        sep.boxType = .separator

        // Info
        infoLabel = NSTextField(labelWithString: "")
        infoLabel.font = NSFont.systemFont(ofSize: 11)
        infoLabel.textColor = .secondaryLabelColor

        // Buttons
        let btnRow = buildButtonRow()

        // Assemble
        stack.addArrangedSubview(titleLabel)
        stack.setCustomSpacing(4, after: titleLabel)
        stack.addArrangedSubview(fmtRow)
        stack.addArrangedSubview(resizeSection)
        stack.addArrangedSubview(outputSection)
        stack.setCustomSpacing(4, after: outputSection)
        stack.addArrangedSubview(sep)
        stack.addArrangedSubview(infoLabel)
        stack.addArrangedSubview(btnRow)

        for v in [titleLabel, fmtRow, resizeSection, outputSection, sep, infoLabel] as [NSView] {
            v.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stack.topAnchor.constraint(equalTo: root.topAnchor),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])

        updateInfo()
        updateResizeUI()
        return root
    }

    private func buildFormatRow(defaults: UserDefaults) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

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

        row.addSubview(fmtLabel)
        row.addSubview(formatPopup)
        row.addSubview(qualLabel)
        row.addSubview(qualitySlider)
        row.addSubview(qualityLabel)
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 24),
            fmtLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            fmtLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            fmtLabel.widthAnchor.constraint(equalToConstant: 60),
            formatPopup.leadingAnchor.constraint(equalTo: fmtLabel.trailingAnchor, constant: 8),
            formatPopup.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            formatPopup.widthAnchor.constraint(equalToConstant: 90),
            qualLabel.leadingAnchor.constraint(equalTo: formatPopup.trailingAnchor, constant: 16),
            qualLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            qualitySlider.leadingAnchor.constraint(equalTo: qualLabel.trailingAnchor, constant: 6),
            qualitySlider.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            qualitySlider.widthAnchor.constraint(equalToConstant: 100),
            qualityLabel.leadingAnchor.constraint(equalTo: qualitySlider.trailingAnchor, constant: 4),
            qualityLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            qualityLabel.widthAnchor.constraint(equalToConstant: 36),
        ])
        return row
    }

    private func buildResizeSection(defaults: UserDefaults) -> NSView {
        let section = NSView()
        section.translatesAutoresizingMaskIntoConstraints = false

        let header = NSTextField(labelWithString: NSLocalizedString("Resize", comment: ""))
        header.font = NSFont.boldSystemFont(ofSize: 12)
        header.translatesAutoresizingMaskIntoConstraints = false

        let sepLine = NSBox()
        sepLine.boxType = .separator
        sepLine.translatesAutoresizingMaskIntoConstraints = false

        let modeRow = NSView()
        modeRow.translatesAutoresizingMaskIntoConstraints = false

        let modeLabel = NSTextField(labelWithString: NSLocalizedString("Mode:", comment: ""))
        modeLabel.font = NSFont.systemFont(ofSize: 12)
        modeLabel.translatesAutoresizingMaskIntoConstraints = false

        resizePopup = NSPopUpButton()
        resizePopup.addItems(withTitles: ResizeMode.allCases.map { $0.label })
        let savedMode = defaults.integer(forKey: resizeModeKey)
        resizePopup.selectItem(at: savedMode < ResizeMode.allCases.count ? savedMode : 0)
        resizePopup.target = self
        resizePopup.action = #selector(resizeChanged)
        resizePopup.translatesAutoresizingMaskIntoConstraints = false

        modeRow.addSubview(modeLabel)
        modeRow.addSubview(resizePopup)
        NSLayoutConstraint.activate([
            modeRow.heightAnchor.constraint(equalToConstant: 24),
            modeLabel.leadingAnchor.constraint(equalTo: modeRow.leadingAnchor),
            modeLabel.centerYAnchor.constraint(equalTo: modeRow.centerYAnchor),
            modeLabel.widthAnchor.constraint(equalToConstant: 60),
            resizePopup.leadingAnchor.constraint(equalTo: modeLabel.trailingAnchor, constant: 8),
            resizePopup.centerYAnchor.constraint(equalTo: modeRow.centerYAnchor),
            resizePopup.widthAnchor.constraint(equalToConstant: 130),
        ])

        let singleRow = NSView()
        singleRow.translatesAutoresizingMaskIntoConstraints = false

        sizeFieldLabel = NSTextField(labelWithString: NSLocalizedString("Max:", comment: ""))
        sizeFieldLabel.font = NSFont.systemFont(ofSize: 11)
        sizeFieldLabel.translatesAutoresizingMaskIntoConstraints = false

        sizeField = NSTextField()
        sizeField.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        sizeField.placeholderString = "px"
        let savedValue = defaults.integer(forKey: resizeValueKey)
        let defaultPx = savedValue > 0 ? savedValue : 1920
        let isPctDefault = savedMode == ResizeMode.percentage.rawValue
        sizeField.integerValue = isPctDefault ? defaultPx.nonZero(100) : defaultPx
        sizeField.delegate = self
        sizeField.translatesAutoresizingMaskIntoConstraints = false

        presetStack = NSStackView()
        presetStack.orientation = .horizontal
        presetStack.spacing = 6
        presetStack.alignment = .centerY
        presetStack.translatesAutoresizingMaskIntoConstraints = false
        for pct in [25, 50, 75, 100, 150, 200] {
            let btn = NSButton(title: "\(pct)%", target: self, action: #selector(presetClicked(_:)))
            btn.bezelStyle = .inline
            btn.controlSize = .small
            btn.translatesAutoresizingMaskIntoConstraints = false
            presetStack.addArrangedSubview(btn)
        }

        singleRow.addSubview(sizeFieldLabel)
        singleRow.addSubview(sizeField)
        singleRow.addSubview(presetStack)
        NSLayoutConstraint.activate([
            singleRow.heightAnchor.constraint(equalToConstant: 24),
            sizeFieldLabel.leadingAnchor.constraint(equalTo: singleRow.leadingAnchor, constant: 68),
            sizeFieldLabel.centerYAnchor.constraint(equalTo: singleRow.centerYAnchor),
            sizeField.leadingAnchor.constraint(equalTo: sizeFieldLabel.trailingAnchor, constant: 4),
            sizeField.centerYAnchor.constraint(equalTo: singleRow.centerYAnchor),
            sizeField.widthAnchor.constraint(equalToConstant: 60),
            presetStack.leadingAnchor.constraint(equalTo: sizeField.trailingAnchor, constant: 10),
            presetStack.centerYAnchor.constraint(equalTo: singleRow.centerYAnchor),
        ])

        let doubleRow = NSView()
        doubleRow.translatesAutoresizingMaskIntoConstraints = false

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

        doubleRow.addSubview(wLabel)
        doubleRow.addSubview(widthField)
        doubleRow.addSubview(hLabel)
        doubleRow.addSubview(heightField)
        NSLayoutConstraint.activate([
            doubleRow.heightAnchor.constraint(equalToConstant: 24),
            wLabel.leadingAnchor.constraint(equalTo: doubleRow.leadingAnchor, constant: 68),
            wLabel.centerYAnchor.constraint(equalTo: doubleRow.centerYAnchor),
            widthField.leadingAnchor.constraint(equalTo: wLabel.trailingAnchor, constant: 4),
            widthField.centerYAnchor.constraint(equalTo: doubleRow.centerYAnchor),
            widthField.widthAnchor.constraint(equalToConstant: 60),
            hLabel.leadingAnchor.constraint(equalTo: widthField.trailingAnchor, constant: 10),
            hLabel.centerYAnchor.constraint(equalTo: doubleRow.centerYAnchor),
            heightField.leadingAnchor.constraint(equalTo: hLabel.trailingAnchor, constant: 4),
            heightField.centerYAnchor.constraint(equalTo: doubleRow.centerYAnchor),
            heightField.widthAnchor.constraint(equalToConstant: 60),
        ])

        // Percentage slider row
        let sliderRow = NSView()
        sliderRow.translatesAutoresizingMaskIntoConstraints = false

        let initPct = isPctDefault ? sizeField.integerValue : 100
        pctSlider = NSSlider(value: Double(initPct), minValue: 10, maxValue: 400, target: self, action: #selector(pctSliderChanged))
        pctSlider.translatesAutoresizingMaskIntoConstraints = false
        pctSlider.widthAnchor.constraint(equalToConstant: 200).isActive = true

        pctSliderLabel = NSTextField(labelWithString: "100%")
        pctSliderLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        pctSliderLabel.translatesAutoresizingMaskIntoConstraints = false
        pctSliderLabel.widthAnchor.constraint(equalToConstant: 36).isActive = true

        sliderRow.addSubview(pctSlider)
        sliderRow.addSubview(pctSliderLabel)
        NSLayoutConstraint.activate([
            sliderRow.heightAnchor.constraint(equalToConstant: 24),
            pctSlider.leadingAnchor.constraint(equalTo: sliderRow.leadingAnchor, constant: 68),
            pctSlider.centerYAnchor.constraint(equalTo: sliderRow.centerYAnchor),
            pctSliderLabel.leadingAnchor.constraint(equalTo: pctSlider.trailingAnchor, constant: 6),
            pctSliderLabel.centerYAnchor.constraint(equalTo: sliderRow.centerYAnchor),
        ])

        self.pctSliderRow = sliderRow
        self.sizeSingleRow = singleRow
        self.sizeDoubleRow = doubleRow

        section.addSubview(header)
        section.addSubview(sepLine)
        section.addSubview(modeRow)
        section.addSubview(singleRow)
        section.addSubview(sliderRow)
        section.addSubview(doubleRow)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: section.topAnchor),
            header.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: section.trailingAnchor),
            sepLine.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 4),
            sepLine.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            sepLine.trailingAnchor.constraint(equalTo: section.trailingAnchor),
            modeRow.topAnchor.constraint(equalTo: sepLine.bottomAnchor, constant: 6),
            modeRow.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            modeRow.trailingAnchor.constraint(equalTo: section.trailingAnchor),
            singleRow.topAnchor.constraint(equalTo: modeRow.bottomAnchor, constant: 4),
            singleRow.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            singleRow.trailingAnchor.constraint(equalTo: section.trailingAnchor),
            sliderRow.topAnchor.constraint(equalTo: singleRow.bottomAnchor),
            sliderRow.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            sliderRow.trailingAnchor.constraint(equalTo: section.trailingAnchor),
            doubleRow.topAnchor.constraint(equalTo: sliderRow.bottomAnchor),
            doubleRow.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            doubleRow.trailingAnchor.constraint(equalTo: section.trailingAnchor),
            doubleRow.bottomAnchor.constraint(equalTo: section.bottomAnchor),
        ])

        return section
    }

    private func buildOutputSection(defaults: UserDefaults) -> NSView {
        let section = NSView()
        section.translatesAutoresizingMaskIntoConstraints = false

        let header = NSTextField(labelWithString: NSLocalizedString("Output", comment: ""))
        header.font = NSFont.boldSystemFont(ofSize: 12)
        header.translatesAutoresizingMaskIntoConstraints = false

        let sepLine = NSBox()
        sepLine.boxType = .separator
        sepLine.translatesAutoresizingMaskIntoConstraints = false

        let outRow = NSView()
        outRow.translatesAutoresizingMaskIntoConstraints = false

        let outLabel = NSTextField(labelWithString: NSLocalizedString("Location:", comment: ""))
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

        let trashRow = NSView()
        trashRow.translatesAutoresizingMaskIntoConstraints = false

        trashCheckbox = NSButton(checkboxWithTitle: NSLocalizedString("Move original to Trash after conversion", comment: ""), target: self, action: #selector(trashToggled))
        trashCheckbox.state = defaults.bool(forKey: trashSourceKey) ? .on : .off
        trashCheckbox.translatesAutoresizingMaskIntoConstraints = false

        trashRow.addSubview(trashCheckbox)
        NSLayoutConstraint.activate([
            trashRow.heightAnchor.constraint(equalToConstant: 24),
            trashCheckbox.leadingAnchor.constraint(equalTo: trashRow.leadingAnchor, constant: 60),
            trashCheckbox.centerYAnchor.constraint(equalTo: trashRow.centerYAnchor),
        ])

        section.addSubview(header)
        section.addSubview(sepLine)
        section.addSubview(outRow)
        section.addSubview(trashRow)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: section.topAnchor),
            header.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: section.trailingAnchor),
            sepLine.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 4),
            sepLine.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            sepLine.trailingAnchor.constraint(equalTo: section.trailingAnchor),
            outRow.topAnchor.constraint(equalTo: sepLine.bottomAnchor, constant: 6),
            outRow.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            outRow.trailingAnchor.constraint(equalTo: section.trailingAnchor),
            trashRow.topAnchor.constraint(equalTo: outRow.bottomAnchor, constant: 4),
            trashRow.leadingAnchor.constraint(equalTo: section.leadingAnchor),
            trashRow.trailingAnchor.constraint(equalTo: section.trailingAnchor),
            trashRow.bottomAnchor.constraint(equalTo: section.bottomAnchor),
        ])

        return section
    }

    private func buildButtonRow() -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let cancelBtn = NSButton(title: NSLocalizedString("Cancel", comment: ""), target: self, action: #selector(cancel))
        cancelBtn.bezelStyle = .push
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false

        let convertBtn = NSButton(title: NSLocalizedString("Convert", comment: ""), target: self, action: #selector(doConvert))
        convertBtn.bezelStyle = .push
        convertBtn.keyEquivalent = "\r"
        convertBtn.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(cancelBtn)
        row.addSubview(convertBtn)
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 28),
            cancelBtn.trailingAnchor.constraint(equalTo: convertBtn.leadingAnchor, constant: -8),
            cancelBtn.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            convertBtn.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            convertBtn.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            row.widthAnchor.constraint(equalToConstant: 180),
        ])
        return row
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
        updateResizeUI()
        updateInfo()
    }

    @objc private func presetClicked(_ sender: NSButton) {
        let pct = Int(sender.title.trimmingCharacters(in: CharacterSet(charactersIn: "%"))) ?? 100
        sizeField.integerValue = pct
        pctSlider?.doubleValue = Double(pct)
        pctSliderLabel?.stringValue = "\(pct)%"
    }

    @objc private func pctSliderChanged() {
        let pct = Int(pctSlider.integerValue)
        sizeField.integerValue = pct
        pctSliderLabel.stringValue = "\(pct)%"
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field === sizeField else { return }
        let mode = ResizeMode(rawValue: resizePopup.indexOfSelectedItem) ?? .none
        if mode == .percentage {
            pctSlider?.doubleValue = Double(field.integerValue)
            pctSliderLabel?.stringValue = "\(field.integerValue)%"
        }
    }

    @objc private func trashToggled() {
        UserDefaults.standard.set(trashCheckbox.state == .on, forKey: trashSourceKey)
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
        let trash = trashCheckbox.state == .on ? " +\(NSLocalizedString("trash originals", comment: ""))" : ""
        infoLabel.stringValue = "\(urls.count) \(NSLocalizedString("files → ", comment: ""))\(fmt)\(trash)"
    }

    private func updateResizeUI() {
        let mode = ResizeMode(rawValue: resizePopup.indexOfSelectedItem) ?? .none

        let showsSingle = mode == .longestSide || mode == .shortestSide || mode == .percentage
        sizeSingleRow.isHidden = !showsSingle
        presetStack.isHidden = mode != .percentage
        pctSliderRow.isHidden = mode != .percentage

        if showsSingle {
            switch mode {
            case .longestSide:
                sizeFieldLabel.stringValue = NSLocalizedString("Max:", comment: "")
                sizeField.placeholderString = "px"
            case .shortestSide:
                sizeFieldLabel.stringValue = NSLocalizedString("Min:", comment: "")
                sizeField.placeholderString = "px"
            case .percentage:
                sizeFieldLabel.stringValue = "%"
                sizeField.placeholderString = "100"
            default:
                break
            }
        }

        sizeDoubleRow.isHidden = mode != .exact
    }

    @objc private func doConvert() {
        let fmtIndex = formatPopup.indexOfSelectedItem
        let quality = qualitySlider.integerValue
        let resizeMode = ResizeMode(rawValue: resizePopup.indexOfSelectedItem) ?? .none
        let subfolder = subfolderField?.stringValue ?? "converted"

        let defaults = UserDefaults.standard
        defaults.set(fmtIndex, forKey: formatKey)
        defaults.set(quality, forKey: qualityKey)
        defaults.set(resizeMode.rawValue, forKey: resizeModeKey)
        defaults.set(subfolder, forKey: subfolderKey)
        if resizeMode == .percentage || resizeMode == .longestSide || resizeMode == .shortestSide {
            defaults.set(sizeField.integerValue, forKey: resizeValueKey)
        }

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
                case .longestSide:
                    let target = CGFloat(sizeField?.integerValue ?? 0)
                    if target > 0 {
                        if w >= h {
                            let ratio = target / w
                            newW = target
                            newH = h * ratio
                        } else {
                            let ratio = target / h
                            newW = w * ratio
                            newH = target
                        }
                    }
                case .shortestSide:
                    let target = CGFloat(sizeField?.integerValue ?? 0)
                    if target > 0 {
                        if w <= h {
                            let ratio = target / w
                            newW = target
                            newH = h * ratio
                        } else {
                            let ratio = target / h
                            newW = w * ratio
                            newH = target
                        }
                    }
                case .percentage:
                    let pct = CGFloat(sizeField?.integerValue ?? 100)
                    if pct > 0 {
                        newW = w * pct / 100.0
                        newH = h * pct / 100.0
                    }
                case .exact:
                    newW = CGFloat(widthField?.integerValue ?? 0)
                    newH = CGFloat(heightField?.integerValue ?? 0)
                    if newW <= 0 { newW = w }
                    if newH <= 0 { newH = h }
                default:
                    break
                }

                if newW != w || newH != h {
                    finalImage = scaleImageLanczos(image, width: Int(newW), height: Int(newH))
                }
            }

            let uttype = ["public.jpeg", "public.png", "public.tiff", "org.webmproject.webp"][fmtIndex] as CFString
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
                if trashCheckbox.state == .on {
                    try? fm.trashItem(at: url, resultingItemURL: nil)
                }
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

    /// 使用 Lanczos 算法高质量缩放图片
    /// High-quality image scaling using Lanczos algorithm
    private func scaleImageLanczos(_ image: CGImage, width: Int, height: Int) -> CGImage {
        let ow = CGFloat(image.width)
        let oh = CGFloat(image.height)
        let nw = CGFloat(width)
        let nh = CGFloat(height)

        let ciImage = CIImage(cgImage: image)

        guard let filter = CIFilter(name: "CILanczosScaleTransform") else {
            let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
            let bpc = image.bitsPerComponent
            let bitmapInfo = image.bitmapInfo
            if let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: bpc, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) {
                ctx.interpolationQuality = .high
                ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
                if let result = ctx.makeImage() {
                    return result
                }
            }
            return image
        }

        let scale = nh / oh
        let aspectRatio = (nw * oh) / (ow * nh)

        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(scale, forKey: kCIInputScaleKey)
        filter.setValue(aspectRatio, forKey: kCIInputAspectRatioKey)

        guard let output = filter.outputImage,
              let cgImage = ciContext.createCGImage(output, from: output.extent) else {
            return image
        }
        return cgImage
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
