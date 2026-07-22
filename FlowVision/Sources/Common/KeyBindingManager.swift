import Cocoa

/// 可配置的快捷键操作
/// Configurable keyboard shortcut actions
enum ShortcutAction: String, CaseIterable, Codable {
    case copyToFolder     // C — 复制到指定文件夹
    case moveToFolder     // M — 移动到指定文件夹
    case delete           // X — 删除
    case rename           // N — 重命名
    case paste            // V — 粘贴
    case batchRename      // B — 批量重命名
    case batchConvert     // — 批量转换
    case toggleSidebar    // F — 切换侧边栏
    case compareImages    // K — 对比模式
    case slideshowToggle  // — 幻灯片播放

    var localizedName: String {
        switch self {
        case .copyToFolder:   return NSLocalizedString("Copy to Folder…", comment: "复制到文件夹…")
        case .moveToFolder:   return NSLocalizedString("Move to Folder…", comment: "移动到文件夹…")
        case .delete:         return NSLocalizedString("Delete", comment: "删除")
        case .rename:         return NSLocalizedString("Rename", comment: "重命名")
        case .paste:          return NSLocalizedString("Paste", comment: "粘贴")
        case .batchRename:    return NSLocalizedString("Batch Rename…", comment: "批量重命名…")
        case .batchConvert:   return NSLocalizedString("Batch Convert…", comment: "批量转换…")
        case .toggleSidebar:  return NSLocalizedString("Toggle Sidebar", comment: "切换侧边栏")
        case .compareImages:  return NSLocalizedString("Compare Images…", comment: "对比模式")
        case .slideshowToggle: return NSLocalizedString("Slideshow", comment: "幻灯片播放")
        }
    }
}

/// 修饰键选项
/// Modifier key options
struct ShortcutModifiers: OptionSet, Codable, Hashable {
    let rawValue: Int
    static let command  = ShortcutModifiers(rawValue: 1 << 0)
    static let option   = ShortcutModifiers(rawValue: 1 << 1)
    static let control  = ShortcutModifiers(rawValue: 1 << 2)
    static let shift    = ShortcutModifiers(rawValue: 1 << 3)

    static let none: ShortcutModifiers = []

    var displayString: String {
        var parts: [String] = []
        if contains(.command)  { parts.append("⌘") }
        if contains(.option)   { parts.append("⌥") }
        if contains(.control)  { parts.append("⌃") }
        if contains(.shift)    { parts.append("⇧") }
        return parts.joined()
    }
}

/// 单个快捷键映射
/// Single key binding mapping
struct KeyBinding: Codable, Equatable {
    var key: String
    var modifiers: ShortcutModifiers

    static let `default`: [ShortcutAction: KeyBinding] = [
        .copyToFolder:  KeyBinding(key: "c", modifiers: .none),
        .moveToFolder:  KeyBinding(key: "m", modifiers: .none),
        .delete:        KeyBinding(key: "x", modifiers: .none),
        .rename:        KeyBinding(key: "n", modifiers: .none),
        .paste:         KeyBinding(key: "v", modifiers: .none),
        .batchRename:   KeyBinding(key: "b", modifiers: .none),
        .batchConvert:  KeyBinding(key: "c", modifiers: [.command, .shift]),
        .toggleSidebar: KeyBinding(key: "f", modifiers: .none),
        .compareImages: KeyBinding(key: "k", modifiers: .none),
        .slideshowToggle: KeyBinding(key: "y", modifiers: .none),
    ]
}

/// 快捷键管理器——加载/保存/查询
/// Key binding manager — load/save/query
class KeyBindingManager {
    static let shared = KeyBindingManager()

    private let defaultsKey = "keyBindings_v1"
    private var bindings: [ShortcutAction: KeyBinding] = [:]

    private init() {
        load()
    }

    // MARK: - Public API

    /// 获取某个动作的快捷键
    /// Get the key binding for an action
    func binding(for action: ShortcutAction) -> KeyBinding {
        bindings[action] ?? KeyBinding.default[action]!
    }

    /// 设置某个动作的快捷键
    /// Set the key binding for an action
    func setBinding(_ binding: KeyBinding, for action: ShortcutAction) {
        bindings[action] = binding
        save()
    }

    /// 检测事件是否匹配某个动作（用于 KeyShortcutManager）
    /// Check if an event matches an action (for use in KeyShortcutManager)
    func eventMatches(_ event: NSEvent, action: ShortcutAction) -> Bool {
        let b = binding(for: action)
        let chars = (event.charactersIgnoringModifiers ?? "").lowercased()
        guard chars == b.key.lowercased() else { return false }
        let modifierFlags = event.modifierFlags
        let isCommand  = modifierFlags.contains(.command)
        let isOption   = modifierFlags.contains(.option)
        let isControl  = modifierFlags.contains(.control)
        let isShift    = modifierFlags.contains(.shift)
        let hasCmd   = b.modifiers.contains(.command)
        let hasOpt   = b.modifiers.contains(.option)
        let hasCtrl  = b.modifiers.contains(.control)
        let hasShift = b.modifiers.contains(.shift)
        return isCommand == hasCmd && isOption == hasOpt && isControl == hasCtrl && isShift == hasShift
    }

    /// 获取所有已配置的动作列表（含未自定义的默认值）
    /// Get all configured actions (including defaults)
    var allActions: [ShortcutAction] {
        ShortcutAction.allCases
    }

    /// 重置所有为默认值
    /// Reset all to defaults
    func resetAll() {
        bindings = [:]
        save()
    }

    /// 重置单个动作为默认值
    /// Reset a single action to default
    func reset(_ action: ShortcutAction) {
        bindings.removeValue(forKey: action)
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([String: KeyBinding].self, from: data) else { return }
        for (rawValue, binding) in decoded {
            guard let action = ShortcutAction(rawValue: rawValue) else { continue }
            bindings[action] = binding
        }
    }

    private func save() {
        let dict = Dictionary(uniqueKeysWithValues: bindings.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
