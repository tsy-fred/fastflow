# FlowVision (FastFlow)

macOS 瀑布流图片浏览器，Swift + AppKit。

## 构建

- Xcode 15.2+，打开 `FlowVision.xcodeproj` 构建
- 依赖（需克隆到同级目录）：
  - `ffmpeg-kit-build/bundle-apple-xcframework-macos/` — 需预构建或下载 xcframework，移除 quarantine 属性
  - `BTree/` — Swift Package
  - `Settings/` — Swift Package
- 构建方式：Xcode `Product → Build For → Profiling`（Release），产物在 `Products/Release/FlowVision.app`

## 开发配置

- `Base.xcconfig` 包含 `#include? "LocalDev.xcconfig"`，本地配置按需创建（已 gitignore）
- `cp LocalDev.xcconfig.template LocalDev.xcconfig` 启用 `LOCAL_DEV` 编译条件，用于 `#if DEBUG && LOCAL_DEV` 等调试路径

## 项目结构

| 目录 | 内容 |
|------|------|
| `FlowVision/Sources/AppDelegate.swift` | 应用入口 (`@main`)，窗口管理、菜单 |
| `FlowVision/Sources/ViewController.swift` | 主 VC：collectionView、outlineView、largeImageView |
| `FlowVision/Sources/WindowController.swift` | 窗口管理、工具栏、全屏 |
| `FlowVision/Sources/Common/` | 全局变量、数据模型、枚举、FFmpeg/图片/视频处理、日志 |
| `FlowVision/Sources/Views/` | 19 个自定义 UI 组件 |
| `FlowVision/Sources/ViewControllerExtension/` | 按功能拆分的扩展（手势、快捷键、搜索、标签等 16 个文件） |
| `FlowVision/Sources/SettingsViews/` | 5 个设置面板 |
| `FlowVision/Resources/` | Assets、Storyboard、本地化字符串 |

## 约定

- 源码中双语注释（中文+英文），保持该风格
- 全局状态通过 `globalVar`（`Common/GlobalVariable.swift`）持有
- UserDefaults 是主要持久化存储，无 Core Data
- FastStone 式快键在 `KeyShortcut.swift` 中通过 `KeyBindingManager` 派发，设置面板在 Actions 标签页底部
- 批量操作面板：`BatchRenamePanel`（B 键）、`BatchConvertPanel`（通过菜单/快捷键触发）
- 批量操作（C/M/B 等）使用 FileOperation.swift 中的 handleCopy/handlePaste/handleMove 作为底层
- 日志使用 `log()` 函数，无第三方日志库
- 使用 `file://` scheme URL 作为路径表示
