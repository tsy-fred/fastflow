//
//  CustomEffectView.swift
//  FlowVision
//

import Cocoa

class CustomEffectView: NSVisualEffectView {

    override func awakeFromNib() {
        super.awakeFromNib()
        applyGlassStyle()
        registerForDraggedTypes([.fileURL] + NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) })
    }

    /// 应用设计系统的亚光玻璃样式
    /// Apply design system frosted glass style
    func applyGlassStyle() {
        material = .hudWindow
        state = .active
        blendingMode = .withinWindow

        wantsLayer = true
        layer?.cornerRadius = DSCorner.medium
        layer?.borderWidth = DSBorder.glass

        let appearance = effectiveAppearance.name
        layer?.borderColor = DSColor.glassBorder(for: appearance).cgColor
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        // 跟随系统外观更新边框颜色
        // Update border color to follow system appearance
        let appearance = effectiveAppearance.name
        layer?.borderColor = DSColor.glassBorder(for: appearance).cgColor
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if let viewController = getViewController(self){
            if viewController.publicVar.isInLargeView {
                return .link
            }
        }
        return .every
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let viewController = getViewController(self) {
            if viewController.publicVar.isInLargeView {
                let pasteboard = sender.draggingPasteboard
                if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
                    viewController.handleDraggedFiles(urls)
                    return true
                }
            }else{
                if sender.draggingSource is CustomCollectionView {
                    return false
                }
                if let curFolderUrl = URL(string: viewController.fileDB.curFolder){
                    let pasteboard = sender.draggingPasteboard
                    if viewController.handleFilePromiseDrop(targetURL: curFolderUrl, pasteboard: pasteboard) {
                        return true
                    }
                    viewController.handleMove(targetURL: curFolderUrl, pasteboard: pasteboard)
                    return true
                }
            }
        }
        return false
    }
}
