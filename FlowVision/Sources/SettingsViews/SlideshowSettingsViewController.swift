import Cocoa
import Settings

final class SlideshowSettingsViewController: NSViewController, SettingsPane {
    let paneIdentifier = Settings.PaneIdentifier.slideshow
    let paneTitle = NSLocalizedString("Slideshow", comment: "幻灯片设置")
    let toolbarItemIcon = NSImage(systemSymbolName: "play.rectangle", accessibilityDescription: "")!

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 510, height: 320))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildContent()
    }

    private func buildContent() {
        view.subviews.forEach { $0.removeFromSuperview() }

        let mgr = SlideshowManager.shared
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 0, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        // Transition
        let transitionRow = NSStackView()
        transitionRow.orientation = .horizontal
        transitionRow.alignment = .centerY
        transitionRow.spacing = 10

        let transLabel = NSTextField(labelWithString: NSLocalizedString("Transition:", comment: ""))
        transitionRow.addArrangedSubview(transLabel)

        let transPop = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 180, height: 24))
        transPop.target = self
        transPop.action = #selector(transitionChanged(_:))
        for t in SlideshowManager.TransitionType.allCases { transPop.addItem(withTitle: t.localizedName) }
        transPop.selectItem(at: mgr.transition.rawValue)
        transitionRow.addArrangedSubview(transPop)
        transitionRow.addArrangedSubview(NSView())
        stack.addArrangedSubview(transitionRow)

        // Interval
        let intervalRow = NSStackView()
        intervalRow.orientation = .horizontal
        intervalRow.alignment = .centerY
        intervalRow.spacing = 10

        let intLabel = NSTextField(labelWithString: NSLocalizedString("Interval (sec):", comment: ""))
        intervalRow.addArrangedSubview(intLabel)

        let intField = NSTextField(frame: NSRect(x: 0, y: 0, width: 60, height: 22))
        intField.stringValue = "\(Int(mgr.interval))"
        intField.tag = 1
        intField.target = self
        intField.action = #selector(intervalChanged(_:))
        intervalRow.addArrangedSubview(intField)

        let stepper = NSStepper(frame: NSRect(x: 0, y: 0, width: 16, height: 22))
        stepper.minValue = 1
        stepper.maxValue = 60
        stepper.integerValue = Int(mgr.interval)
        stepper.target = self
        stepper.action = #selector(intervalStepped(_:))
        intervalRow.addArrangedSubview(stepper)
        intervalRow.addArrangedSubview(NSView())
        stack.addArrangedSubview(intervalRow)

        // Separator
        let sep = NSBox()
        sep.boxType = .separator
        stack.addArrangedSubview(sep)

        // Music file
        let musicRow = NSStackView()
        musicRow.orientation = .horizontal
        musicRow.alignment = .centerY
        musicRow.spacing = 10

        let musicLabel = NSTextField(labelWithString: NSLocalizedString("Music:", comment: ""))
        musicRow.addArrangedSubview(musicLabel)

        let musicField = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 22))
        musicField.isEditable = false
        musicField.isSelectable = true
        musicField.stringValue = mgr.musicURL?.lastPathComponent ?? NSLocalizedString("None selected", comment: "")
        musicField.tag = 2
        musicField.textColor = .secondaryLabelColor
        musicRow.addArrangedSubview(musicField)

        let browseBtn = NSButton(title: NSLocalizedString("Browse…", comment: ""), target: self, action: #selector(chooseMusic))
        browseBtn.bezelStyle = .rounded
        musicRow.addArrangedSubview(browseBtn)

        let clearBtn = NSButton(title: "✕", target: self, action: #selector(clearMusic))
        clearBtn.bezelStyle = .rounded
        clearBtn.setContentHuggingPriority(.required, for: .horizontal)
        musicRow.addArrangedSubview(clearBtn)
        musicRow.addArrangedSubview(NSView())
        stack.addArrangedSubview(musicRow)

        // Volume
        let volumeRow = NSStackView()
        volumeRow.orientation = .horizontal
        volumeRow.alignment = .centerY
        volumeRow.spacing = 10

        let volLabel = NSTextField(labelWithString: NSLocalizedString("Volume:", comment: ""))
        volumeRow.addArrangedSubview(volLabel)

        let volSlider = NSSlider(value: Double(mgr.volume * 100), minValue: 0, maxValue: 100, target: self, action: #selector(volumeChanged(_:)))
        volSlider.frame = NSRect(x: 0, y: 0, width: 120, height: 20)
        volumeRow.addArrangedSubview(volSlider)

        let volVal = NSTextField(labelWithString: "\(Int(mgr.volume * 100))%")
        volVal.tag = 3
        volVal.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        volumeRow.addArrangedSubview(volVal)
        volumeRow.addArrangedSubview(NSView())
        stack.addArrangedSubview(volumeRow)

        // Loop
        let loopRow = NSStackView()
        loopRow.orientation = .horizontal
        loopRow.alignment = .centerY
        loopRow.spacing = 10

        let loopCb = NSButton(checkboxWithTitle: NSLocalizedString("Loop music", comment: ""), target: self, action: #selector(loopChanged(_:)))
        loopCb.state = mgr.loopMusic ? .on : .off
        loopRow.addArrangedSubview(loopCb)
        loopRow.addArrangedSubview(NSView())
        stack.addArrangedSubview(loopRow)
    }

    // MARK: - Actions

    @objc private func transitionChanged(_ sender: NSPopUpButton) {
        let mgr = SlideshowManager.shared
        mgr.transition = SlideshowManager.TransitionType(rawValue: sender.indexOfSelectedItem) ?? .crossfade
    }

    @objc private func intervalChanged(_ sender: NSTextField) {
        let val = max(1, sender.integerValue)
        SlideshowManager.shared.interval = TimeInterval(val)
        if let stepper = sender.superview?.subviews.compactMap({ $0 as? NSStepper }).first {
            stepper.integerValue = val
        }
    }

    @objc private func intervalStepped(_ sender: NSStepper) {
        SlideshowManager.shared.interval = TimeInterval(sender.integerValue)
        if let field = sender.superview?.subviews.compactMap({ $0 as? NSTextField }).first(where: { $0.tag == 1 }) {
            field.stringValue = "\(sender.integerValue)"
        }
    }

    @objc private func chooseMusic() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedFileTypes = ["mp3", "aac", "wav", "m4a", "flac"]
        let window = view.window ?? NSApp.keyWindow ?? NSApp.mainWindow
        if let w = window {
            panel.beginSheetModal(for: w) { [weak self] response in
                guard let self = self, response == .OK, let url = panel.url else { return }
                self.musicSelected(url)
            }
        } else {
            let response = panel.runModal()
            guard response == .OK, let url = panel.url else { return }
            musicSelected(url)
        }
    }

    private func musicSelected(_ url: URL) {
        SlideshowManager.shared.musicURL = url
        if let field = view.subviews.first?.subviews.compactMap({ $0 as? NSTextField }).first(where: { $0.tag == 2 }) {
            field.stringValue = url.lastPathComponent
            field.textColor = .labelColor
        }
    }

    @objc private func clearMusic() {
        SlideshowManager.shared.musicURL = nil
        if let field = view.subviews.first?.subviews.compactMap({ $0 as? NSTextField }).first(where: { $0.tag == 2 }) {
            field.stringValue = NSLocalizedString("None selected", comment: "")
            field.textColor = .secondaryLabelColor
        }
    }

    @objc private func volumeChanged(_ sender: NSSlider) {
        let val = sender.floatValue / 100.0
        SlideshowManager.shared.updateVolume(val)
        if let label = sender.superview?.subviews.compactMap({ $0 as? NSTextField }).first(where: { $0.tag == 3 }) {
            label.stringValue = "\(Int(sender.floatValue))%"
        }
    }

    @objc private func loopChanged(_ sender: NSButton) {
        SlideshowManager.shared.loopMusic = sender.state == .on
    }
}
