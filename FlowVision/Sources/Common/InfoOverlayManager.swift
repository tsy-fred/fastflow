import Cocoa

// MARK: - 信息模块定义
// MARK: - Info Module Definition

/// 信息模块类型
/// Info module type
enum InfoModuleType: String, CaseIterable, Codable {
    case filename
    case fileSize
    case dimensions
    case dateCreated
    case dateModified
    case cameraModel
    case exifSummary    // 光圈/快门/ISO/焦距
    case gpsLocation
    case finderTags
    case rating

    var localizedName: String {
        switch self {
        case .filename:     return NSLocalizedString("Filename", comment: "")
        case .fileSize:     return NSLocalizedString("File Size", comment: "")
        case .dimensions:   return NSLocalizedString("Dimensions", comment: "")
        case .dateCreated:  return NSLocalizedString("Date Created", comment: "")
        case .dateModified: return NSLocalizedString("Date Modified", comment: "")
        case .cameraModel:  return NSLocalizedString("Camera", comment: "")
        case .exifSummary:  return NSLocalizedString("EXIF Summary", comment: "")
        case .gpsLocation:  return NSLocalizedString("GPS", comment: "")
        case .finderTags:   return NSLocalizedString("Finder Tags", comment: "")
        case .rating:       return NSLocalizedString("Rating", comment: "")
        }
    }

    var defaultValue: Bool {
        switch self {
        case .filename, .fileSize, .dimensions: return true
        case .dateCreated, .exifSummary: return true
        default: return false
        }
    }
}

/// 单个信息行
/// Single info line
struct InfoLine: Equatable {
    let label: String
    let value: String
}

/// 信息模块
/// Info module
struct InfoModule: Equatable {
    let type: InfoModuleType
    let lines: [InfoLine]
    var isEmpty: Bool { lines.isEmpty }
}

// MARK: - 信息叠加层管理器
// MARK: - Info Overlay Manager

class InfoOverlayManager {

    static let shared = InfoOverlayManager()

    /// 启用的模块（持久化）
    /// Enabled modules (persisted)
    var enabledModules: Set<InfoModuleType> {
        get {
            guard let data = UserDefaults.standard.data(forKey: enabledModulesKey),
                  let decoded = try? JSONDecoder().decode(Set<InfoModuleType>.self, from: data)
            else { return Set(InfoModuleType.allCases.filter { $0.defaultValue }) }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: enabledModulesKey)
            }
        }
    }

    /// 模块显示位置
    /// Module display position
    var overlayPosition: InfoOverlayPosition {
        get {
            let raw = UserDefaults.standard.integer(forKey: overlayPositionKey)
            return InfoOverlayPosition(rawValue: raw) ?? .bottomRight
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: overlayPositionKey)
        }
    }

    private let enabledModulesKey = "infoOverlayEnabledModules_v1"
    private let overlayPositionKey = "infoOverlayPosition_v1"

    private init() {}

    // MARK: - 提取信息模块
    // MARK: - Extract Modules

    /// 从 FileModel 提取所有启用的模块
    /// Extract all enabled modules from FileModel
    func modules(for file: FileModel) -> [InfoModule] {
        InfoModuleType.allCases.compactMap { type in
            guard enabledModules.contains(type) else { return nil }
            return buildModule(type: type, for: file)
        }.filter { !$0.isEmpty }
    }

    private func buildModule(type: InfoModuleType, for file: FileModel) -> InfoModule {
        switch type {
        case .filename:   return filenameModule(for: file)
        case .fileSize:   return fileSizeModule(for: file)
        case .dimensions: return dimensionsModule(for: file)
        case .dateCreated: return dateCreatedModule(for: file)
        case .dateModified: return dateModifiedModule(for: file)
        case .cameraModel: return cameraModule(for: file)
        case .exifSummary: return exifSummaryModule(for: file)
        case .gpsLocation: return gpsModule(for: file)
        case .finderTags:  return tagsModule(for: file)
        case .rating:      return ratingModule(for: file)
        }
    }

    // MARK: - Individual Modules

    private func filenameModule(for file: FileModel) -> InfoModule {
        let name = (file.path as NSString).lastPathComponent.removingPercentEncoding ?? (file.path as NSString).lastPathComponent
        return InfoModule(type: .filename, lines: [InfoLine(label: "", value: name)])
    }

    private func fileSizeModule(for file: FileModel) -> InfoModule {
        guard let size = file.fileSize else { return InfoModule(type: .fileSize, lines: []) }
        return InfoModule(type: .fileSize, lines: [InfoLine(label: NSLocalizedString("Size", comment: ""), value: readableFileSize(size))])
    }

    private func dimensionsModule(for file: FileModel) -> InfoModule {
        guard let s = file.imageInfo?.size ?? file.originalSize else { return InfoModule(type: .dimensions, lines: []) }
        return InfoModule(type: .dimensions, lines: [InfoLine(label: NSLocalizedString("Dimensions", comment: ""),
                                                              value: "\(Int(s.width)) × \(Int(s.height)) px")])
    }

    private func dateCreatedModule(for file: FileModel) -> InfoModule {
        guard let d = file.createDate else { return InfoModule(type: .dateCreated, lines: []) }
        return InfoModule(type: .dateCreated, lines: [InfoLine(label: NSLocalizedString("Created", comment: ""), value: formatDateToCurrentTimeZone(d))])
    }

    private func dateModifiedModule(for file: FileModel) -> InfoModule {
        guard let d = file.modDate else { return InfoModule(type: .dateModified, lines: []) }
        return InfoModule(type: .dateModified, lines: [InfoLine(label: NSLocalizedString("Modified", comment: ""), value: formatDateToCurrentTimeZone(d))])
    }

    private func cameraModule(for file: FileModel) -> InfoModule {
        guard let props = file.imageInfo?.properties else { return InfoModule(type: .cameraModel, lines: []) }
        let tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let make = tiff?[kCGImagePropertyTIFFMake as String] as? String
        let model = tiff?[kCGImagePropertyTIFFModel as String] as? String
        var lines: [InfoLine] = []
        if let camera = model ?? make {
            lines.append(InfoLine(label: NSLocalizedString("Camera", comment: ""), value: camera))
        }
        if let lens = exif?[kCGImagePropertyExifLensModel as String] as? String {
            lines.append(InfoLine(label: NSLocalizedString("Lens", comment: ""), value: lens))
        }
        if let software = tiff?[kCGImagePropertyTIFFSoftware as String] as? String {
            lines.append(InfoLine(label: NSLocalizedString("Software", comment: ""), value: software))
        }
        return InfoModule(type: .cameraModel, lines: lines)
    }

    private func exifSummaryModule(for file: FileModel) -> InfoModule {
        guard let props = file.imageInfo?.properties,
              let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any]
        else { return InfoModule(type: .exifSummary, lines: []) }
        var lines: [InfoLine] = []
        // 光圈
        if let fn = exif[kCGImagePropertyExifFNumber as String] as? Double {
            lines.append(InfoLine(label: NSLocalizedString("Aperture", comment: ""), value: "f/\(String(format: "%.1f", fn))"))
        }
        // 快门
        if let exp = exif[kCGImagePropertyExifExposureTime as String] as? Double {
            lines.append(InfoLine(label: NSLocalizedString("Shutter", comment: ""), value: "\(convertExposureTimeToFraction(exp))"))
        }
        // ISO
        if let iso = exif[kCGImagePropertyExifISOSpeedRatings as String] as? [Int], let v = iso.first {
            lines.append(InfoLine(label: "ISO", value: "\(v)"))
        } else if let iso = exif[kCGImagePropertyExifISOSpeedRatings as String] as? Int {
            lines.append(InfoLine(label: "ISO", value: "\(iso)"))
        }
        // 焦距
        if let fl = exif[kCGImagePropertyExifFocalLength as String] as? Double {
            lines.append(InfoLine(label: NSLocalizedString("Focal Length", comment: ""), value: "\(String(format: "%.0f", fl)) mm"))
        }
        // 闪光灯
        if let flash = exif[kCGImagePropertyExifFlash as String] as? Int {
            lines.append(InfoLine(label: NSLocalizedString("Flash", comment: ""), value: flash == 0 ? "No" : "Yes"))
        }
        // 白平衡
        if let wb = exif[kCGImagePropertyExifWhiteBalance as String] as? Int {
            lines.append(InfoLine(label: NSLocalizedString("White Balance", comment: ""), value: wb == 1 ? "Manual" : "Auto"))
        }
        return InfoModule(type: .exifSummary, lines: lines)
    }

    private func gpsModule(for file: FileModel) -> InfoModule {
        guard let props = file.imageInfo?.properties,
              let gps = props[kCGImagePropertyGPSDictionary as String] as? [String: Any],
              let lat = gps[kCGImagePropertyGPSLatitude as String] as? Double,
              let lon = gps[kCGImagePropertyGPSLongitude as String] as? Double
        else { return InfoModule(type: .gpsLocation, lines: []) }
        let latDir = gps[kCGImagePropertyGPSLatitudeRef as String] as? String ?? "N"
        let lonDir = gps[kCGImagePropertyGPSLongitudeRef as String] as? String ?? "E"
        return InfoModule(type: .gpsLocation, lines: [
            InfoLine(label: "GPS", value: String(format: "%.4f° %@, %.4f° %@", lat, latDir, lon, lonDir))
        ])
    }

    private func tagsModule(for file: FileModel) -> InfoModule {
        guard !file.finderTags.isEmpty else { return InfoModule(type: .finderTags, lines: []) }
        return InfoModule(type: .finderTags, lines: [InfoLine(label: NSLocalizedString("Tags", comment: ""), value: file.finderTags.joined(separator: ", "))])
    }

    private func ratingModule(for file: FileModel) -> InfoModule {
        guard let r = file.imageInfo?.rating, r > 0 else { return InfoModule(type: .rating, lines: []) }
        let stars = String(repeating: "★", count: r) + String(repeating: "☆", count: 5 - r)
        return InfoModule(type: .rating, lines: [InfoLine(label: NSLocalizedString("Rating", comment: ""), value: stars)])
    }
}

// MARK: - 叠加层位置
// MARK: - Overlay Position

enum InfoOverlayPosition: Int, CaseIterable, Codable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var localizedName: String {
        switch self {
        case .topLeft:      return NSLocalizedString("Top Left", comment: "")
        case .topRight:     return NSLocalizedString("Top Right", comment: "")
        case .bottomLeft:   return NSLocalizedString("Bottom Left", comment: "")
        case .bottomRight:  return NSLocalizedString("Bottom Right", comment: "")
        }
    }
}
