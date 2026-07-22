import Cocoa

extension ViewController {

    // MARK: - Auto Scroll (unchanged)

    func promptForScrollSpeed(completion: @escaping (CGFloat?) -> Void) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Set Scroll Speed", comment: "设置滚动速度")
        alert.informativeText = NSLocalizedString("Enter the scroll speed in pixels per second:", comment: "输入每秒滚动的像素数：")
        alert.alertStyle = .informational

        let inputTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        inputTextField.stringValue = "60"
        alert.accessoryView = inputTextField

        alert.addButton(withTitle: NSLocalizedString("OK", comment: "确定"))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "取消"))

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let text = inputTextField.stringValue
            if let speed = Double(text), speed != 0 {
                completion(CGFloat(speed))
            } else {
                completion(nil)
            }
        } else {
            completion(nil)
        }
    }

    func startContinuousAutoScroll() {
        stopAutoScroll()
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.performContinuousScroll()
        }
    }

    func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }

    func performContinuousScroll() {
        guard let scrollView = collectionView.enclosingScrollView, !isAutoScrollPaused else { return }

        let currentOrigin = scrollView.contentView.bounds.origin
        let newY = max(0, min(currentOrigin.y + scrollSpeed / 60.0, collectionView.bounds.height - scrollView.contentSize.height))
        let newOrigin = NSPoint(x: currentOrigin.x, y: newY)

        scrollView.contentView.scroll(to: newOrigin)
        scrollView.reflectScrolledClipView(scrollView.contentView)

        debounceSetLoadThumbPriority(interval: 1, ifNeedVisable: true)
    }

    func toggleAutoScroll() {
        if autoScrollTimer == nil {
            promptForScrollSpeed { [weak self] speed in
                guard let self = self, let speed = speed else { return }
                self.scrollSpeed = speed
                self.isAutoScrollPaused = false
                self.startContinuousAutoScroll()
            }
        } else {
            stopAutoScroll()
        }
    }

    // MARK: - Slideshow (via SlideshowManager)

    func startAutoPlay() {
        guard !SlideshowManager.shared.isPlaying else { return }
        SlideshowManager.shared.start(in: self)
    }

    func stopAutoPlay() {
        SlideshowManager.shared.stop()
    }

    func toggleAutoPlay() {
        if SlideshowManager.shared.isPlaying {
            stopAutoPlay()
        } else {
            startAutoPlay()
        }
    }
}
