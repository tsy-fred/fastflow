//
//  DesignSystem.swift
//  FlowVision
//

import Cocoa

// MARK: - 颜色
// MARK: - Colors

enum DSColor {
    // 集合视图背景
    // Collection view background
    static let collectionBgLight = "#F7F7F7"
    static let collectionBgDark  = "#1E1E1E"

    // 玻璃面板: 亚光半透明白色/黑色
    // Glass panel: frosted translucent white/black
    static let glassLight = NSColor(calibratedWhite: 1.0, alpha: 0.65)
    static let glassDark  = NSColor(calibratedWhite: 0.15, alpha: 0.65)

    // 玻璃边框: 高光/暗色半透
    // Glass border: highlight/dark translucent
    static let glassBorderLight = NSColor(calibratedWhite: 1.0, alpha: 0.45)
    static let glassBorderDark  = NSColor(calibratedWhite: 0.4, alpha: 0.25)

    // 玻璃阴影
    // Glass shadow
    static let glassShadowLight = NSColor(calibratedWhite: 0.0, alpha: 0.08)
    static let glassShadowDark  = NSColor(calibratedWhite: 0.0, alpha: 0.30)

    // 选中态
    // Selection
    static let selectionBorder = NSColor(calibratedRed: 0.0, green: 0.48, blue: 1.0, alpha: 0.7)
    static let selectionGlow   = NSColor(calibratedRed: 0.0, green: 0.48, blue: 1.0, alpha: 0.15)

    // 悬浮按钮背景
    // Floating button background
    static let floatingButtonBg = NSColor(calibratedWhite: 0.0, alpha: 0.3)
    static let floatingButtonHoverBg = NSColor(calibratedWhite: 0.0, alpha: 0.45)

    // 缩略图文标签
    // Thumbnail filename label
    static let thumbLabelBgLight = NSColor(calibratedWhite: 1.0, alpha: 0.85)
    static let thumbLabelBgDark  = NSColor(calibratedWhite: 0.1, alpha: 0.75)

    static func glassBg(for appearance: NSAppearance.Name) -> NSColor {
        appearance == .darkAqua ? glassDark : glassLight
    }
    static func glassBorder(for appearance: NSAppearance.Name) -> NSColor {
        appearance == .darkAqua ? glassBorderDark : glassBorderLight
    }
    static func glassShadow(for appearance: NSAppearance.Name) -> NSColor {
        appearance == .darkAqua ? glassShadowDark : glassShadowLight
    }
}

// MARK: - 圆角
// MARK: - Corner Radii

enum DSCorner {
    static let small: CGFloat   = 4
    static let medium: CGFloat  = 8
    static let large: CGFloat   = 12
    static let xlarge: CGFloat  = 16
    static let pill: CGFloat    = 999
}

// MARK: - 边框
// MARK: - Borders

enum DSBorder {
    static let glass: CGFloat  = 0.5
    static let thin: CGFloat   = 1.0
}

// MARK: - 阴影
// MARK: - Shadows

enum DSShadow {
    static func glass(for view: NSView) {
        guard let layer = view.layer else { return }
        let appearance = view.effectiveAppearance.name
        layer.shadowColor = DSColor.glassShadow(for: appearance).cgColor
        layer.shadowOffset = NSSize(width: 0, height: -2)
        layer.shadowRadius = 12
        layer.shadowOpacity = 1.0
    }
}

// MARK: - 玻璃材质工厂
// MARK: - Glass Effect Factory

enum DSGlass {
    /// 亚光玻璃面板: sidebar / 工具栏 / 信息叠加层
    /// Frosted glass panel: sidebar / toolbar / info overlays
    static func panel() -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.state = .active
        v.blendingMode = .withinWindow
        v.wantsLayer = true
        v.layer?.cornerRadius = DSCorner.medium
        v.layer?.borderWidth = DSBorder.glass
        return v
    }

    /// 大图背景（behindWindow 模式）
    /// Large image background (behindWindow mode)
    static func background() -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .dark
        v.state = .active
        v.blendingMode = .behindWindow
        return v
    }

    /// 视频播放器控制栏
    /// Video player controls
    static func videoControls() -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.state = .active
        v.blendingMode = .withinWindow
        v.wantsLayer = true
        v.layer?.cornerRadius = DSCorner.medium
        v.layer?.borderWidth = DSBorder.glass
        v.layer?.borderColor = DSColor.glassBorderDark.cgColor
        v.layer?.masksToBounds = true
        return v
    }

    /// 为 NSVisualEffectView 设置边框颜色（跟随主题）
    /// Set border color for NSVisualEffectView (follows theme)
    static func updateBorder(_ v: NSVisualEffectView) {
        let c = DSColor.glassBorder(for: v.effectiveAppearance.name)
        v.layer?.borderColor = c.cgColor
    }

    /// 设置阴影（跟随主题）
    /// Set shadow (follows theme)
    static func updateShadow(_ v: NSView) {
        DSShadow.glass(for: v)
    }

    /// 更新所有玻璃效果（主题变化时调用）
    /// Update all glass effects (call when theme changes)
    static func updateAppearance(_ v: NSVisualEffectView) {
        updateBorder(v)
        updateShadow(v)
    }
}

// MARK: - 字体尺寸
// MARK: - Font Sizes

enum DSFont {
    static let infoSmall: CGFloat   = 11
    static let infoRegular: CGFloat = 13
    static let infoLarge: CGFloat   = 15
    static let filename: CGFloat    = 12
    static let toolbarTitle: CGFloat = 14
}

// MARK: - 间距
// MARK: - Spacing

enum DSSpacing {
    static let tiny: CGFloat   = 4
    static let small: CGFloat  = 8
    static let medium: CGFloat = 12
    static let large: CGFloat  = 16
    static let xlarge: CGFloat = 24
}

// MARK: - 动画时长
// MARK: - Animation Durations

enum DSAnimation {
    static let fast: TimeInterval    = 0.15
    static let normal: TimeInterval  = 0.25
    static let slow: TimeInterval    = 0.35
    static let fade: TimeInterval    = 0.2
}
