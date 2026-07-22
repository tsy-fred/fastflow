import Cocoa
import Settings

final class KeyBindingSettingsViewController: NSViewController, SettingsPane {
    let paneIdentifier = Settings.PaneIdentifier.shortcuts
    let paneTitle = NSLocalizedString("Shortcuts", comment: "快捷键（设置里的面板）")
    let toolbarItemIcon = NSImage(systemSymbolName: "command", accessibilityDescription: "")!

    private var stackView: NSStackView!
    private var recordingAction: ShortcutAction?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 510, height: 600))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(view)
    }

    private func setupUI() {
        stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 0
        stackView.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        let titleLabel = NSTextField(labelWithString: NSLocalizedString("Configure keyboard shortcuts", comment: "配置快捷键"))
        stackView.addArrangedSubview(titleLabel)

        let descLabel = NSTextField(wrappingLabelWithString: NSLocalizedString("Click a shortcut to change it, then press the new key.", comment: "点击快捷键后按下新键即可更改。"))
        descLabel.font = .systemFont(ofSize: 11)
        descLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(descLabel)
        stackView.setCustomSpacing(16, after: descLabel)

        for action in ShortcutAction.allCases {
            let rowView = createRow(for: action)
            stackView.addArrangedSubview(rowView)
        }

        let resetButton = NSButton(title: NSLocalizedString("Reset All to Defaults", comment: "全部重置为默认值"), target: self, action: #selector(resetAll))
        resetButton.bezelStyle = .rounded
        stackView.addArrangedSubview(resetButton)
    }

    private func createRow(for action: ShortcutAction) -> NSView {
        let row = NSView()
        row.wantsLayer = true
        row.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: action.localizedName)
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false

        let button = NSButton(title: displayString(for: action), target: self, action: #selector(shortcutButtonClicked(_:)))
        button.bezelStyle = .rounded
        button.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        button.tag = actionRowTag(action)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)

        row.addSubview(label)
        row.addSubview(button)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 32),
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 4),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: button.leadingAnchor, constant: -12),
            button.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -4),
            button.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
        ])

        return row
    }

    @objc private func shortcutButtonClicked(_ sender: NSButton) {
        guard let action = actionForRowTag(sender.tag) else { return }

        if let recording = recordingAction, recording != action {
            restoreRow(for: recording)
        }

        recordingAction = action
        sender.title = NSLocalizedString("Press key…", comment: "按按键…")
        sender.state = .on
        view.window?.makeFirstResponder(view)
    }

    override func keyDown(with event: NSEvent) {
        guard let action = recordingAction else {
            super.keyDown(with: event)
            return
        }

        let chars = (event.charactersIgnoringModifiers ?? "").lowercased()
        guard chars.count == 1, chars.first!.isLetter || chars.first!.isNumber else {
            NSSound.beep()
            return
        }

        let hasCmd = event.modifierFlags.contains(.command)
        let hasOpt = event.modifierFlags.contains(.option)
        let hasCtrl = event.modifierFlags.contains(.control)
        let hasShift = event.modifierFlags.contains(.shift)

        var modifiers: ShortcutModifiers = []
        if hasCmd { modifiers.insert(.command) }
        if hasOpt { modifiers.insert(.option) }
        if hasCtrl { modifiers.insert(.control) }
        if hasShift { modifiers.insert(.shift) }

        let binding = KeyBinding(key: chars, modifiers: modifiers)
        KeyBindingManager.shared.setBinding(binding, for: action)
        recordingAction = nil
        rebuildRows()
    }

    private func restoreRow(for action: ShortcutAction) {
        recordingAction = nil
        rebuildRows()
    }

    private func rebuildRows() {
        for case let row in stackView.arrangedSubviews {
            for subview in row.subviews {
                if let button = subview as? NSButton, button.action == #selector(shortcutButtonClicked(_:)) {
                    if let action = actionForRowTag(button.tag) {
                        button.title = displayString(for: action)
                        button.state = .off
                    }
                }
            }
        }
    }

    @objc private func resetAll() {
        KeyBindingManager.shared.resetAll()
        rebuildRows()
    }

    private func actionRowTag(_ action: ShortcutAction) -> Int {
        ShortcutAction.allCases.firstIndex(of: action)!
    }

    private func actionForRowTag(_ tag: Int) -> ShortcutAction? {
        guard tag >= 0, tag < ShortcutAction.allCases.count else { return nil }
        return ShortcutAction.allCases[tag]
    }

    private func displayString(for action: ShortcutAction) -> String {
        let binding = KeyBindingManager.shared.binding(for: action)
        return binding.modifiers.displayString + binding.key.uppercased()
    }
}
