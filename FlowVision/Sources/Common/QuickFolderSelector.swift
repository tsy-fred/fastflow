import Cocoa

/// 全键盘快速文件夹选择器
/// Full-keyboard folder picker for copy/move
class QuickFolderSelector: NSWindowController {

    private let confirmKey: String
    private let actionTitle: String
    private let operationType: String
    private var completion: ((URL?) -> Void)?
    private var recentURLs: [URL] = []

    // UI
    private var pathField: NSTextField!
    private var tableView: NSTableView!
    private var statusField: NSTextField!
    private var recentScroll: NSScrollView!

    private static var currentPicker: QuickFolderSelector?
    private let recentKey = "quickFolderRecentURLs"

    // MARK: - Init

    init(confirmKey: String, actionTitle: String, operationType: String, completion: @escaping (URL?) -> Void) {
        self.confirmKey = confirmKey
        self.actionTitle = actionTitle
        self.operationType = operationType
        self.completion = completion

        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 440, height: 280),
                            styleMask: [.titled, .closable, .fullSizeContentView],
                            backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.title = actionTitle
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isOpaque = false

        super.init(window: panel)

        loadRecent()
        panel.contentView = buildContentView()

        panel.setContentSize(NSSize(width: 440, height: 280))
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
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 20, bottom: 16, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Title bar area
        let titleRow = NSView()
        titleRow.translatesAutoresizingMaskIntoConstraints = false

        let iconLabel = NSTextField(labelWithString: operationType == "copy" ? "📋 Copy to Folder" : "📦 Move to Folder")
        iconLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        iconLabel.textColor = .labelColor
        iconLabel.translatesAutoresizingMaskIntoConstraints = false

        titleRow.addSubview(iconLabel)
        NSLayoutConstraint.activate([
            titleRow.heightAnchor.constraint(equalToConstant: 36),
            iconLabel.leadingAnchor.constraint(equalTo: titleRow.leadingAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: titleRow.centerYAnchor),
        ])

        // Selected path (read-only, updated by Browse)
        let pathLabel = NSTextField(labelWithString: NSLocalizedString("Destination:", comment: ""))
        pathLabel.font = .systemFont(ofSize: 11)
        pathLabel.textColor = .secondaryLabelColor

        pathField = NSTextField()
        pathField.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        pathField.isBezeled = false
        pathField.drawsBackground = false
        pathField.isEditable = false
        pathField.isSelectable = true
        pathField.textColor = .labelColor
        pathField.stringValue = recentURLs.first?.path ?? ""
        pathField.placeholderString = NSLocalizedString("Click Browse to select…", comment: "")
        pathField.translatesAutoresizingMaskIntoConstraints = false
        pathField.lineBreakMode = .byTruncatingHead

        // Browse button (primary action)
        browseButton = NSButton(title: NSLocalizedString("Browse…", comment: ""),
                                target: self, action: #selector(browse(_:)))
        browseButton.bezelStyle = .rounded
        browseButton.font = .systemFont(ofSize: 12)
        browseButton.setContentHuggingPriority(.required, for: .horizontal)
        browseButton.translatesAutoresizingMaskIntoConstraints = false

        let browseRow = NSView()
        browseRow.translatesAutoresizingMaskIntoConstraints = false
        browseRow.addSubview(pathField)
        browseRow.addSubview(browseButton)
        NSLayoutConstraint.activate([
            browseRow.heightAnchor.constraint(equalToConstant: 24),
            pathField.leadingAnchor.constraint(equalTo: browseRow.leadingAnchor),
            pathField.trailingAnchor.constraint(equalTo: browseButton.leadingAnchor, constant: -8),
            pathField.centerYAnchor.constraint(equalTo: browseRow.centerYAnchor),
            browseButton.trailingAnchor.constraint(equalTo: browseRow.trailingAnchor),
            browseButton.centerYAnchor.constraint(equalTo: browseRow.centerYAnchor),
        ])

        // Show path in a subtle container
        let pathContainer = NSView()
        pathContainer.wantsLayer = true
        pathContainer.layer?.cornerRadius = DSCorner.small
        pathContainer.layer?.borderWidth = DSBorder.thin
        pathContainer.translatesAutoresizingMaskIntoConstraints = false

        let pathDisplay = NSTextField(wrappingLabelWithString: "")
        pathDisplay.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        pathDisplay.textColor = .labelColor
        pathDisplay.translatesAutoresizingMaskIntoConstraints = false
        pathDisplay.isSelectable = true
        pathDisplay.bind(.value, to: pathField, withKeyPath: "stringValue", options: nil)

        pathContainer.addSubview(pathDisplay)
        NSLayoutConstraint.activate([
            pathContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 28),
            pathDisplay.leadingAnchor.constraint(equalTo: pathContainer.leadingAnchor, constant: 8),
            pathDisplay.trailingAnchor.constraint(equalTo: pathContainer.trailingAnchor, constant: -8),
            pathDisplay.topAnchor.constraint(equalTo: pathContainer.topAnchor, constant: 4),
            pathDisplay.bottomAnchor.constraint(equalTo: pathContainer.bottomAnchor, constant: -4),
        ])

        // Separator
        let sep = NSBox()
        sep.boxType = .separator

        // Recent list
        let recentLabel = NSTextField(labelWithString: NSLocalizedString("Recent Destinations (press 1-9):", comment: ""))
        recentLabel.font = .systemFont(ofSize: 10)
        recentLabel.textColor = .secondaryLabelColor

        recentScroll = NSScrollView()
        recentScroll.hasVerticalScroller = true
        recentScroll.borderType = .noBorder
        recentScroll.drawsBackground = false
        recentScroll.translatesAutoresizingMaskIntoConstraints = false

        tableView = NSTableView()
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.addTableColumn(NSTableColumn(identifier: .init("path")))
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.rowHeight = 22
        tableView.target = self
        tableView.intercellSpacing = NSSize.zero
        tableView.doubleAction = #selector(tableDoubleClick(_:))
        tableView.delegate = self
        tableView.dataSource = self
        recentScroll.documentView = tableView

        // Status & hint
        statusField = NSTextField(labelWithString: NSLocalizedString("Press \(confirmKey.uppercased()) or Enter to confirm · Esc to cancel", comment: ""))
        statusField.font = .systemFont(ofSize: 10)
        statusField.textColor = .tertiaryLabelColor

        // Assemble stack
        stack.addArrangedSubview(titleRow)
        stack.addArrangedSubview(browseRow)
        stack.addArrangedSubview(pathContainer)
        stack.addArrangedSubview(sep)
        stack.addArrangedSubview(recentLabel)
        stack.addArrangedSubview(recentScroll)
        stack.addArrangedSubview(statusField)

        sep.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        recentScroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        recentScroll.heightAnchor.constraint(equalToConstant: 100).isActive = true
        pathContainer.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        root.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -16),
        ])

        tableView.reloadData()
        return root
    }

    private var browseButton: NSButton!

    // MARK: - WindowController lifecycle

    deinit {
        removeMonitor()
    }

    private var monitor: Any?

    private func installMonitor() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.window?.isVisible == true else { return event }
            return self.handleKey(event) ? nil : event
        }
    }

    private func removeMonitor() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }

    // MARK: - Key handling

    private func handleKey(_ event: NSEvent) -> Bool {
        guard let chars = event.charactersIgnoringModifiers?.lowercased() else { return false }
        if chars == confirmKey || chars == "\r" || chars == "\n" {
            confirm()
            return true
        }
        if event.keyCode == 53 {
            cancel()
            return true
        }
        if let num = Int(chars), (1...9).contains(num) {
            if num <= recentURLs.count {
                pathField.stringValue = recentURLs[num - 1].path
                confirm()
                return true
            }
        }
        return false
    }

    // MARK: - Actions

    @objc private func browse(_ sender: Any?) {
        guard let panel = window else { return }
        let open = NSOpenPanel()
        open.canChooseFiles = false
        open.canChooseDirectories = true
        open.canCreateDirectories = true
        open.directoryURL = currentURL()
        open.prompt = operationType == "copy"
            ? NSLocalizedString("Select as Copy Destination", comment: "")
            : NSLocalizedString("Select as Move Destination", comment: "")
        open.beginSheetModal(for: panel) { [weak self] response in
            if response == .OK, let url = open.url {
                self?.pathField.stringValue = url.path
            }
        }
    }

    private func confirm() {
        let path = pathField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !path.isEmpty else {
            statusField.stringValue = NSLocalizedString("Please select a destination folder", comment: "")
            return
        }
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            statusField.stringValue = NSLocalizedString("Directory does not exist", comment: "")
            return
        }
        saveRecent(url)
        removeMonitor()
        window?.close()
        let cb = completion
        completion = nil
        Self.currentPicker = nil
        cb?(url)
    }

    private func cancel() {
        removeMonitor()
        window?.close()
        let cb = completion
        completion = nil
        Self.currentPicker = nil
        cb?(nil)
    }

    @objc private func tableDoubleClick(_ sender: Any?) {
        let row = tableView.clickedRow
        guard row >= 0, row < recentURLs.count else { return }
        pathField.stringValue = recentURLs[row].path
        confirm()
    }

    private func currentURL() -> URL? {
        let path = pathField.stringValue.trimmingCharacters(in: .whitespaces)
        if path.isEmpty { return nil }
        return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    }

    // MARK: - Recent

    private func loadRecent() {
        guard let data = UserDefaults.standard.data(forKey: recentKey),
              let urls = try? NSKeyedUnarchiver.unarchivedArrayOfObjects(ofClass: NSURL.self, from: data) as? [URL]
        else { return }
        recentURLs = urls.filter { (try? $0.checkResourceIsReachable()) ?? false }
    }

    private func saveRecent(_ url: URL) {
        recentURLs.removeAll { $0.path == url.path }
        recentURLs.insert(url, at: 0)
        if recentURLs.count > 10 { recentURLs = Array(recentURLs.prefix(10)) }
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: recentURLs as NSArray, requiringSecureCoding: false) {
            UserDefaults.standard.set(data, forKey: recentKey)
        }
    }

    // MARK: - Show

    static func show(confirmKey: String, actionTitle: String = "", operationType: String, completion: @escaping (URL?) -> Void) {
        let title = actionTitle.isEmpty
            ? (operationType == "copy" ? NSLocalizedString("Copy to Folder…", comment: "") : NSLocalizedString("Move to Folder…", comment: ""))
            : actionTitle
        let picker = QuickFolderSelector(confirmKey: confirmKey, actionTitle: title, operationType: operationType, completion: completion)
        currentPicker = picker
        picker.installMonitor()
        picker.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            picker.browseButton?.becomeFirstResponder()
        }
    }
}

// MARK: - Table

extension QuickFolderSelector: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        recentURLs.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < recentURLs.count else { return nil }
        let id = NSUserInterfaceItemIdentifier("cell")
        var cell = tableView.makeView(withIdentifier: id, owner: nil) as? NSTableCellView
        if cell == nil {
            let tf = NSTextField()
            tf.isBezeled = false
            tf.drawsBackground = false
            tf.isEditable = false
            tf.isSelectable = false
            tf.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            tf.lineBreakMode = .byTruncatingHead
            tf.textColor = .labelColor
            cell = NSTableCellView()
            cell?.identifier = id
            cell?.addSubview(tf)
            tf.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 4),
                tf.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -4),
                tf.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
            ])
            cell?.textField = tf
        }
        cell?.textField?.stringValue = "\(row + 1). \(recentURLs[row].path)"
        return cell
    }
}
