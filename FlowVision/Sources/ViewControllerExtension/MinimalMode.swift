//
//  MinimalMode.swift
//  FlowVision
//

import Cocoa

extension ViewController {

    /// Tab 键切换简洁模式
    /// Tab key toggles minimal mode
    func toggleMinimalMode() {
        if publicVar.isMinimalMode {
            enterMinimalMode()
        } else {
            exitMinimalMode()
        }
    }

    /// 进入简洁模式：隐藏 sidebar、toolbar、路径栏，只保留图片
    /// Enter minimal mode: hide sidebar, toolbar, path bar, keep only the image
    func enterMinimalMode() {
        guard let window = view.window, let windowController = window.windowController as? WindowController else { return }

        // 记录展开前的 sidebar 状态，用于恢复
        // Save sidebar state before collapsing, for restoration
        if publicVar.profile.isDirTreeHidden == false {
            lastSidebarWidth = splitView.subviews[0].frame.width
        }

        // 收起 sidebar
        // Collapse sidebar
        splitView.setPosition(0, ofDividerAt: 0)

        // 隐藏 toolbar 和标题栏
        // Hide toolbar and title bar
        windowController.hideTitleBar()

        // 设置窗口以支持全尺寸内容
        // Set window to support full-size content
        if !window.styleMask.contains(.fullSizeContentView) {
            window.styleMask.insert(.fullSizeContentView)
        }

        // 添加简洁模式样式 —— 图片背景用纯黑
        // Apply minimal mode styling — pure black image background
        largeImageBgEffectView.material = .dark
        largeImageBgEffectView.blendingMode = .behindWindow
        largeImageBgEffectView.layer?.borderWidth = 0

        // 显示简洁模式提示
        // Show minimal mode hint
        coreAreaView.showInfo(NSLocalizedString("Minimal Mode — Press Tab to Exit", comment: "简洁模式 — 按 Tab 退出"), timeOut: 2.0, cannotBeCleard: false)
    }

    /// 退出简洁模式：恢复 sidebar、toolbar、路径栏
    /// Exit minimal mode: restore sidebar, toolbar, path bar
    func exitMinimalMode() {
        guard let window = view.window, let windowController = window.windowController as? WindowController else { return }

        // 恢复 sidebar（如果原来就是显示的）
        // Restore sidebar (if it was visible before)
        if lastSidebarWidth > 0 {
            splitView.setPosition(lastSidebarWidth, ofDividerAt: 0)
        } else if !publicVar.profile.isDirTreeHidden {
            splitView.setPosition(270, ofDividerAt: 0)
        }
        lastSidebarWidth = 0

        // 恢复 toolbar 和标题栏
        // Restore toolbar and title bar
        windowController.showTitleBar()

        // 恢复图片背景样式
        // Restore image background style
        largeImageBgEffectView.material = .hudWindow
        largeImageBgEffectView.blendingMode = .withinWindow
        largeImageBgEffectView.layer?.borderWidth = DSBorder.glass
        let appearanceName = view.effectiveAppearance.name
        largeImageBgEffectView.layer?.borderColor = DSColor.glassBorder(for: appearanceName).cgColor
    }
}

private var lastSidebarWidthKey: UInt8 = 0

extension ViewController {
    /// 记录简洁模式展开前的 sidebar 宽度，用于恢复
    /// Record sidebar width before entering minimal mode, for restoration
    var lastSidebarWidth: CGFloat {
        get {
            return objc_getAssociatedObject(self, &lastSidebarWidthKey) as? CGFloat ?? 0
        }
        set {
            objc_setAssociatedObject(self, &lastSidebarWidthKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
