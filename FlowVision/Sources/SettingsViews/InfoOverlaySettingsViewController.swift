import Cocoa
import Settings

final class InfoOverlaySettingsViewController: NSViewController, SettingsPane {
    let paneIdentifier = Settings.PaneIdentifier.infoOverlay
    let paneTitle = NSLocalizedString("Info Overlay", comment: "信息叠加层设置")
    let toolbarItemIcon = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "")!

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 510, height: 480))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildContent()
    }

    private func buildContent() {
        view.subviews.forEach { $0.removeFromSuperview() }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 0, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        let enabled = InfoOverlayManager.shared.enabledModules
        for type in InfoModuleType.allCases {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 10

            let cb = NSButton(checkboxWithTitle: type.localizedName, target: self, action: #selector(moduleToggle(_:)))
            cb.identifier = NSUserInterfaceItemIdentifier(type.rawValue)
            cb.state = enabled.contains(type) ? .on : .off
            row.addArrangedSubview(cb)
            row.addArrangedSubview(NSView())
            stack.addArrangedSubview(row)
        }

        let sep = NSBox()
        sep.boxType = .separator
        stack.addArrangedSubview(sep)

        let posRow = NSStackView()
        posRow.orientation = .horizontal
        posRow.alignment = .centerY
        posRow.spacing = 10

        let posLabel = NSTextField(labelWithString: NSLocalizedString("Display Position:", comment: ""))
        posRow.addArrangedSubview(posLabel)

        let pop = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        pop.target = self
        pop.action = #selector(posChanged(_:))
        for p in InfoOverlayPosition.allCases { pop.addItem(withTitle: p.localizedName) }
        pop.selectItem(at: InfoOverlayManager.shared.overlayPosition.rawValue)
        posRow.addArrangedSubview(pop)

        posRow.addArrangedSubview(NSView())
        stack.addArrangedSubview(posRow)
    }

    @objc private func moduleToggle(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, let t = InfoModuleType(rawValue: raw) else { return }
        var s = InfoOverlayManager.shared.enabledModules
        if sender.state == .on { s.insert(t) } else { s.remove(t) }
        InfoOverlayManager.shared.enabledModules = s
        refreshOverlay()
    }

    @objc private func posChanged(_ sender: NSPopUpButton) {
        guard let p = InfoOverlayPosition(rawValue: sender.indexOfSelectedItem) else { return }
        InfoOverlayManager.shared.overlayPosition = p
        refreshOverlay()
        findMainVC()?.largeImageView?.updateInfoOverlayPosition()
    }

    private func refreshOverlay() {
        guard let vc = findMainVC(),
              let img = vc.largeImageView,
              vc.publicVar.isShowExif else { return }
        img.infoOverlayView.modules = InfoOverlayManager.shared.modules(for: img.file)
    }

    private func findMainVC() -> ViewController? {
        for w in NSApp.windows {
            if let vc = w.contentViewController as? ViewController { return vc }
            if let vc = w.windowController?.contentViewController as? ViewController { return vc }
        }
        return nil
    }
}
