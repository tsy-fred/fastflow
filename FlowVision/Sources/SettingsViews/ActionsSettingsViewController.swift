import Cocoa
import Settings

final class ActionsSettingsViewController: NSViewController, SettingsPane {
    let paneIdentifier = Settings.PaneIdentifier.actions
    let paneTitle = NSLocalizedString("Actions", comment: "操作（设置里的面板）")
    let toolbarItemIcon = NSImage(systemSymbolName: "keyboard.badge.ellipsis", accessibilityDescription: "")!

    private var stackView: NSStackView!
    private var recordingAction: ShortcutAction?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 510, height: 600))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildContent()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(view)
    }

    // MARK: - Build UI

    private func buildContent() {
        view.subviews.forEach { $0.removeFromSuperview() }

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

        buildActionsSection()
        stackView.addArrangedSubview(SpacerView(12))

        let sep1 = NSBox()
        sep1.boxType = .separator
        stackView.addArrangedSubview(sep1)

        stackView.addArrangedSubview(SpacerView(12))
        buildShortcutsSection()
    }

    // MARK: - Actions Section

    private func buildActionsSection() {
        // Enter key behavior
        let enterLabel = NSTextField(labelWithString: NSLocalizedString("Enter Key:", comment: ""))
        stackView.addArrangedSubview(enterLabel)

        let enterRename = NSButton(radioButtonWithTitle: NSLocalizedString("Rename selected item", comment: ""), target: self, action: #selector(enterKeyToggled(_:)))
        enterRename.tag = 0
        enterRename.state = globalVar.isEnterKeyToOpen ? .off : .on
        stackView.addArrangedSubview(enterRename)

        let enterOpen = NSButton(radioButtonWithTitle: NSLocalizedString("Open item / Enter folder", comment: ""), target: self, action: #selector(enterKeyToggled(_:)))
        enterOpen.tag = 1
        enterOpen.state = globalVar.isEnterKeyToOpen ? .on : .off
        stackView.addArrangedSubview(enterOpen)

        stackView.addArrangedSubview(SpacerView(12))

        // Esc key behavior
        let escLabel = NSTextField(labelWithString: NSLocalizedString("Esc Key:", comment: ""))
        stackView.addArrangedSubview(escLabel)

        let escBack = NSButton(radioButtonWithTitle: NSLocalizedString("Go back (previous folder)", comment: ""), target: self, action: #selector(escKeyToggled(_:)))
        escBack.tag = 0
        escBack.state = globalVar.isEscKeyToGoBack ? .on : .off
        stackView.addArrangedSubview(escBack)

        let escClose = NSButton(radioButtonWithTitle: NSLocalizedString("Close / Minimize window", comment: ""), target: self, action: #selector(escKeyToggled(_:)))
        escClose.tag = 1
        escClose.state = globalVar.isEscKeyToGoBack ? .off : .on
        stackView.addArrangedSubview(escClose)
    }

    // MARK: - Shortcuts Section

    private func buildShortcutsSection() {
        let titleLabel = NSTextField(labelWithString: NSLocalizedString("Keyboard Shortcuts", comment: ""))
        stackView.addArrangedSubview(titleLabel)

        let descLabel = NSTextField(wrappingLabelWithString: NSLocalizedString("Click a shortcut to change it, then press the new key.", comment: ""))
        descLabel.font = .systemFont(ofSize: 11)
        descLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(descLabel)
        stackView.setCustomSpacing(12, after: descLabel)

        for action in ShortcutAction.allCases {
            let rowView = createShortcutRow(for: action)
            stackView.addArrangedSubview(rowView)
        }

        let resetButton = NSButton(title: NSLocalizedString("Reset All to Defaults", comment: ""), target: self, action: #selector(resetAllShortcuts))
        resetButton.bezelStyle = .rounded
        stackView.addArrangedSubview(resetButton)
    }

    private func createShortcutRow(for action: ShortcutAction) -> NSView {
        let row = NSView()
        row.wantsLayer = true
        row.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: action.localizedName)
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false

        let button = NSButton(title: shortcutDisplayString(for: action), target: self, action: #selector(shortcutButtonClicked(_:)))
        button.bezelStyle = .rounded
        button.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        button.tag = shortcutTag(for: action)
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

    // MARK: - Actions Handlers

    @objc private func enterKeyToggled(_ sender: NSButton) {
        globalVar.isEnterKeyToOpen = sender.tag == 1
        UserDefaults.standard.set(globalVar.isEnterKeyToOpen, forKey: "isEnterKeyToOpen")
        updateRadioState()
    }

    @objc private func escKeyToggled(_ sender: NSButton) {
        globalVar.isEscKeyToGoBack = sender.tag == 0
        UserDefaults.standard.set(globalVar.isEscKeyToGoBack, forKey: "isEscKeyToGoBack")
        updateRadioState()
    }

    private func updateRadioState() {
        for case let row in stackView.arrangedSubviews {
            for subview in row.subviews {
                if let button = subview as? NSButton {
                    if button.action == #selector(enterKeyToggled(_:)) {
                        if button.tag == 0 { button.state = globalVar.isEnterKeyToOpen ? .off : .on }
                        if button.tag == 1 { button.state = globalVar.isEnterKeyToOpen ? .on : .off }
                    }
                    if button.action == #selector(escKeyToggled(_:)) {
                        if button.tag == 0 { button.state = globalVar.isEscKeyToGoBack ? .on : .off }
                        if button.tag == 1 { button.state = globalVar.isEscKeyToGoBack ? .off : .on }
                    }
                }
            }
        }
    }

    // MARK: - Shortcuts Handlers

    @objc private func shortcutButtonClicked(_ sender: NSButton) {
        guard let action = shortcutForTag(sender.tag) else { return }

        if let recording = recordingAction, recording != action {
            restoreShortcutRow(for: recording)
        }

        recordingAction = action
        sender.title = NSLocalizedString("Press key…", comment: "")
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

        var modifiers: ShortcutModifiers = []
        if event.modifierFlags.contains(.command) { modifiers.insert(.command) }
        if event.modifierFlags.contains(.option) { modifiers.insert(.option) }
        if event.modifierFlags.contains(.control) { modifiers.insert(.control) }
        if event.modifierFlags.contains(.shift) { modifiers.insert(.shift) }

        let binding = KeyBinding(key: chars, modifiers: modifiers)
        KeyBindingManager.shared.setBinding(binding, for: action)
        recordingAction = nil
        rebuildShortcutRows()
    }

    private func restoreShortcutRow(for action: ShortcutAction) {
        recordingAction = nil
        rebuildShortcutRows()
    }

    private func rebuildShortcutRows() {
        for case let row in stackView.arrangedSubviews {
            for subview in row.subviews {
                if let button = subview as? NSButton, button.action == #selector(shortcutButtonClicked(_:)) {
                    if let action = shortcutForTag(button.tag) {
                        button.title = shortcutDisplayString(for: action)
                        button.state = .off
                    }
                }
            }
        }
    }

    @objc private func resetAllShortcuts() {
        KeyBindingManager.shared.resetAll()
        rebuildShortcutRows()
    }

    private func shortcutTag(for action: ShortcutAction) -> Int {
        ShortcutAction.allCases.firstIndex(of: action)!
    }

    private func shortcutForTag(_ tag: Int) -> ShortcutAction? {
        guard tag >= 0, tag < ShortcutAction.allCases.count else { return nil }
        return ShortcutAction.allCases[tag]
    }

    private func shortcutDisplayString(for action: ShortcutAction) -> String {
        let binding = KeyBindingManager.shared.binding(for: action)
        return binding.modifiers.displayString + binding.key.uppercased()
    }
}

// MARK: - Helper

private class SpacerView: NSView {
    init(_ height: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: 1, height: height))
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: height).isActive = true
    }
    required init?(coder: NSCoder) { nil }
}
