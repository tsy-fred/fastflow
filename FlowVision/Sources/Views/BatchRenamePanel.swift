import Cocoa

/// 批量重命名面板
/// Batch rename panel
class BatchRenamePanel: NSWindowController {

    private var urls: [URL] = []
    private var previewItems: [(old: String, new: String)] = []
    private var patternField: NSTextField!
    private var startField: NSTextField!
    private var paddingField: NSTextField!
    private var tableView: NSTableView!
    private var completion: (([URL]) -> Void)?

    private let patternKey = "batchRenamePattern"
    private let startKey = "batchRenameStart"
    private let paddingKey = "batchRenamePadding"

    private static var currentPanel: BatchRenamePanel?

    // MARK: - Init

    private init(urls: [URL], completion: @escaping ([URL]) -> Void) {
        self.urls = urls
        self.completion = completion

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = NSLocalizedString("Batch Rename", comment: "批量重命名")
        panel.isFloatingPanel = true
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isOpaque = false

        super.init(window: panel)

        panel.contentView = buildContentView()
        panel.setContentSize(NSSize(width: 520, height: 420))
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

        // Title
        let titleLabel = NSTextField(labelWithString: NSLocalizedString("Batch Rename", comment: ""))
        titleLabel.font = NSFont.boldSystemFont(ofSize: 14)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Pattern row
        let patternRow = NSView()
        patternRow.translatesAutoresizingMaskIntoConstraints = false

        let patternLabel = NSTextField(labelWithString: NSLocalizedString("Pattern:", comment: ""))
        patternLabel.font = NSFont.systemFont(ofSize: 12)
        patternLabel.translatesAutoresizingMaskIntoConstraints = false

        patternField = NSTextField()
        patternField.placeholderString = "photo_%@"
        patternField.stringValue = UserDefaults.standard.string(forKey: patternKey) ?? ""
        patternField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        patternField.target = self
        patternField.action = #selector(patternChanged)
        patternField.translatesAutoresizingMaskIntoConstraints = false

        let hintLabel = NSTextField(labelWithString: NSLocalizedString("%@ = number", comment: ""))
        hintLabel.font = NSFont.systemFont(ofSize: 10)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.translatesAutoresizingMaskIntoConstraints = false

        patternRow.addSubview(patternLabel)
        patternRow.addSubview(patternField)
        patternRow.addSubview(hintLabel)
        NSLayoutConstraint.activate([
            patternRow.heightAnchor.constraint(equalToConstant: 24),
            patternLabel.leadingAnchor.constraint(equalTo: patternRow.leadingAnchor),
            patternLabel.centerYAnchor.constraint(equalTo: patternRow.centerYAnchor),
            patternLabel.widthAnchor.constraint(equalToConstant: 60),
            patternField.leadingAnchor.constraint(equalTo: patternLabel.trailingAnchor, constant: 8),
            patternField.centerYAnchor.constraint(equalTo: patternRow.centerYAnchor),
            patternField.widthAnchor.constraint(equalToConstant: 200),
            hintLabel.leadingAnchor.constraint(equalTo: patternField.trailingAnchor, constant: 8),
            hintLabel.centerYAnchor.constraint(equalTo: patternRow.centerYAnchor),
        ])

        // Start / Digits row
        let numRow = NSView()
        numRow.translatesAutoresizingMaskIntoConstraints = false

        let startLabel = NSTextField(labelWithString: NSLocalizedString("Start:", comment: ""))
        startLabel.font = NSFont.systemFont(ofSize: 12)
        startLabel.translatesAutoresizingMaskIntoConstraints = false

        startField = NSTextField()
        startField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        startField.stringValue = "\(UserDefaults.standard.integer(forKey: startKey).nonZero(1))"
        startField.target = self
        startField.action = #selector(patternChanged)
        startField.translatesAutoresizingMaskIntoConstraints = false

        let stepper1 = NSStepper()
        stepper1.minValue = 0
        stepper1.maxValue = 99999
        stepper1.integerValue = Int(startField.stringValue) ?? 1
        stepper1.target = self
        stepper1.action = #selector(startStepped(_:))
        stepper1.translatesAutoresizingMaskIntoConstraints = false

        let padLabel = NSTextField(labelWithString: NSLocalizedString("Digits:", comment: ""))
        padLabel.font = NSFont.systemFont(ofSize: 12)
        padLabel.translatesAutoresizingMaskIntoConstraints = false

        paddingField = NSTextField()
        paddingField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        paddingField.stringValue = "\(UserDefaults.standard.integer(forKey: paddingKey).nonZero(2))"
        paddingField.target = self
        paddingField.action = #selector(patternChanged)
        paddingField.translatesAutoresizingMaskIntoConstraints = false

        let stepper2 = NSStepper()
        stepper2.minValue = 1
        stepper2.maxValue = 10
        stepper2.integerValue = Int(paddingField.stringValue) ?? 2
        stepper2.target = self
        stepper2.action = #selector(padStepped(_:))
        stepper2.translatesAutoresizingMaskIntoConstraints = false

        numRow.addSubview(startLabel)
        numRow.addSubview(startField)
        numRow.addSubview(stepper1)
        numRow.addSubview(padLabel)
        numRow.addSubview(paddingField)
        numRow.addSubview(stepper2)
        NSLayoutConstraint.activate([
            numRow.heightAnchor.constraint(equalToConstant: 24),
            startLabel.leadingAnchor.constraint(equalTo: numRow.leadingAnchor, constant: 60),
            startLabel.centerYAnchor.constraint(equalTo: numRow.centerYAnchor),
            startField.leadingAnchor.constraint(equalTo: startLabel.trailingAnchor, constant: 4),
            startField.centerYAnchor.constraint(equalTo: numRow.centerYAnchor),
            startField.widthAnchor.constraint(equalToConstant: 48),
            stepper1.leadingAnchor.constraint(equalTo: startField.trailingAnchor, constant: 2),
            stepper1.centerYAnchor.constraint(equalTo: numRow.centerYAnchor),
            padLabel.leadingAnchor.constraint(equalTo: stepper1.trailingAnchor, constant: 16),
            padLabel.centerYAnchor.constraint(equalTo: numRow.centerYAnchor),
            paddingField.leadingAnchor.constraint(equalTo: padLabel.trailingAnchor, constant: 4),
            paddingField.centerYAnchor.constraint(equalTo: numRow.centerYAnchor),
            paddingField.widthAnchor.constraint(equalToConstant: 40),
            stepper2.leadingAnchor.constraint(equalTo: paddingField.trailingAnchor, constant: 2),
            stepper2.centerYAnchor.constraint(equalTo: numRow.centerYAnchor),
        ])

        // Separator
        let sep = NSBox()
        sep.boxType = .separator

        // Preview table
        let previewLabel = NSTextField(labelWithString: NSLocalizedString("Preview:", comment: ""))
        previewLabel.font = NSFont.systemFont(ofSize: 11)
        previewLabel.textColor = .secondaryLabelColor

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        tableView = NSTableView()
        let col1 = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("old"))
        col1.title = NSLocalizedString("Original", comment: "")
        col1.width = 200
        tableView.addTableColumn(col1)
        let col2 = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("new"))
        col2.title = NSLocalizedString("Renamed", comment: "")
        col2.width = 200
        tableView.addTableColumn(col2)
        tableView.headerView = NSTableHeaderView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.usesAlternatingRowBackgroundColors = true
        scrollView.documentView = tableView

        // Buttons
        let btnRow = NSView()
        btnRow.translatesAutoresizingMaskIntoConstraints = false

        let cancelBtn = NSButton(title: NSLocalizedString("Cancel", comment: ""), target: self, action: #selector(cancel))
        cancelBtn.bezelStyle = .push
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false

        let renameBtn = NSButton(title: NSLocalizedString("Rename", comment: ""), target: self, action: #selector(doRename))
        renameBtn.bezelStyle = .push
        renameBtn.keyEquivalent = "\r"
        renameBtn.translatesAutoresizingMaskIntoConstraints = false

        btnRow.addSubview(cancelBtn)
        btnRow.addSubview(renameBtn)
        NSLayoutConstraint.activate([
            btnRow.heightAnchor.constraint(equalToConstant: 28),
            cancelBtn.trailingAnchor.constraint(equalTo: renameBtn.leadingAnchor, constant: -8),
            cancelBtn.centerYAnchor.constraint(equalTo: btnRow.centerYAnchor),
            renameBtn.trailingAnchor.constraint(equalTo: btnRow.trailingAnchor),
            renameBtn.centerYAnchor.constraint(equalTo: btnRow.centerYAnchor),
            btnRow.widthAnchor.constraint(equalToConstant: 180),
        ])

        // Assemble stack
        stack.addArrangedSubview(titleLabel)
        stack.setCustomSpacing(4, after: titleLabel)
        stack.addArrangedSubview(patternRow)
        stack.addArrangedSubview(numRow)
        stack.setCustomSpacing(6, after: numRow)
        stack.addArrangedSubview(sep)
        stack.addArrangedSubview(previewLabel)
        stack.addArrangedSubview(scrollView)
        stack.addArrangedSubview(btnRow)

        scrollView.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        scrollView.heightAnchor.constraint(equalToConstant: 180).isActive = true
        titleLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        patternRow.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        numRow.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        sep.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        previewLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stack.topAnchor.constraint(equalTo: root.topAnchor),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])

        updatePreview()
        return root
    }

    // MARK: - Preview

    @objc private func patternChanged() {
        updatePreview()
    }

    @objc private func startStepped(_ sender: NSStepper) {
        startField.integerValue = sender.integerValue
        updatePreview()
    }

    @objc private func padStepped(_ sender: NSStepper) {
        paddingField.integerValue = sender.integerValue
        updatePreview()
    }

    private func updatePreview() {
        let pattern = patternField.stringValue
        let start = startField.integerValue
        let pad = max(1, paddingField.integerValue)
        let count = urls.count
        let digitCount = String(count).count
        let effectivePad = max(pad, digitCount)
        let usePattern = pattern.isEmpty ? "file_%@" : pattern

        let fm = FileManager.default
        let sourcePaths = Set(urls.map { $0.path })
        var seenNames = Set<String>()
        previewItems = urls.enumerated().map { (i, url) in
            let old = url.lastPathComponent
            let seq = String(format: "%0\(effectivePad)d", start + i)
            var newName = usePattern.replacingOccurrences(of: "%@", with: seq)
            let ext = url.pathExtension
            if !newName.hasSuffix(".\(ext)") {
                newName += ".\(ext)"
            }
            let baseName = (newName as NSString).deletingPathExtension
            var dedupCounter = 2
            let dir = URL(fileURLWithPath: url.deletingLastPathComponent().path)
            // 去重：batch 内同名 + 磁盘上已有同名
            // Dedup against both batch and disk
            while true {
                let checkURL = dir.appendingPathComponent(newName)
                let isSelf = url.path == checkURL.path
                let existsInBatch = seenNames.contains(newName)
                let existsOnDisk = !isSelf && fm.fileExists(atPath: checkURL.path) && !sourcePaths.contains(checkURL.path)
                if !existsInBatch && !existsOnDisk { break }
                newName = "\(baseName)_\(dedupCounter).\(ext)"
                dedupCounter += 1
            }
            seenNames.insert(newName)
            return (old, newName)
        }
        tableView?.reloadData()
    }

    // MARK: - Actions

    @objc private func doRename() {
        window?.makeFirstResponder(nil)
        updatePreview()
        UserDefaults.standard.set(patternField.stringValue, forKey: patternKey)
        UserDefaults.standard.set(startField.integerValue, forKey: startKey)
        UserDefaults.standard.set(paddingField.integerValue, forKey: paddingKey)

        let fm = FileManager.default
        var renamed: [URL] = []
        var errors: [String] = []

        for (i, url) in urls.enumerated() {
            guard i < previewItems.count else {
                log("Batch rename: index \(i) out of range", level: .error)
                errors.append(url.lastPathComponent)
                continue
            }
            let newName = previewItems[i].new
            let dir = URL(fileURLWithPath: url.deletingLastPathComponent().path)
            let newURLBase = dir.appendingPathComponent(newName)
            log("Batch rename: \(url.lastPathComponent) → \(newName)", level: .debug)

            guard fm.fileExists(atPath: url.path) else {
                log("Batch rename: source not found: \(url.path)", level: .error)
                errors.append(url.lastPathComponent)
                continue
            }

            if url.path == newURLBase.path {
                renamed.append(newURLBase)
                continue
            }

            // 如果目标已存在，自动去重（追加 _2, _3 ...）
            // If target exists, auto-dedup by appending _2, _3 ...
            var finalURL = newURLBase
            if fm.fileExists(atPath: finalURL.path) {
                let ext = finalURL.pathExtension
                let base = (finalURL.deletingPathExtension().path as NSString).lastPathComponent
                var counter = 2
                repeat {
                    finalURL = dir.appendingPathComponent("\(base)_\(counter).\(ext)")
                    counter += 1
                } while fm.fileExists(atPath: finalURL.path)
                log("Batch rename: \(newURLBase.lastPathComponent) exists, using \(finalURL.lastPathComponent)", level: .debug)
            }

            do {
                try fm.moveItem(at: url, to: finalURL)
                log("Batch rename: \(url.lastPathComponent) → \(finalURL.lastPathComponent) success", level: .debug)
                renamed.append(finalURL)
            } catch {
                log("Batch rename: \(url.lastPathComponent) → \(finalURL.lastPathComponent) failed: \(error)", level: .error)
                errors.append(url.lastPathComponent)
            }
        }

        window?.close()
        Self.currentPanel = nil

        if !errors.isEmpty {
            let msg = "\(renamed.count)/\(urls.count) renamed, \(errors.count) errors"
            log("Batch rename: \(msg)", level: .info)
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Batch Rename", comment: "")
            alert.informativeText = msg
            alert.runModal()
        } else {
            log("Batch rename: \(renamed.count)/\(urls.count) done", level: .debug)
        }

        completion?(renamed)
    }

    @objc private func cancel() {
        window?.close()
        Self.currentPanel = nil
        completion?([])
    }

    // MARK: - Show

    static func show(urls: [URL], completion: @escaping ([URL]) -> Void) {
        let panel = BatchRenamePanel(urls: urls, completion: completion)
        Self.currentPanel = panel
        panel.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - NSTableView DataSource / Delegate

extension BatchRenamePanel: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        previewItems.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < previewItems.count else { return nil }
        let text = tableColumn?.identifier.rawValue == "old"
            ? previewItems[row].old
            : previewItems[row].new
        let cell = NSTextField(labelWithString: text)
        cell.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        cell.lineBreakMode = .byTruncatingMiddle
        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        20
    }
}

// MARK: - Int helper

private extension Int {
    func nonZero(_ defaultVal: Int) -> Int {
        self == 0 ? defaultVal : self
    }
}
