import Cocoa
import AVFoundation

/// 幻灯片类型
/// Slideshow configuration manager
class SlideshowManager: NSObject {

    static let shared = SlideshowManager()

    // MARK: - 过渡类型
    // MARK: - Transition type
    enum TransitionType: Int, CaseIterable {
        case none = 0
        case crossfade
        case slide

        var localizedName: String {
            switch self {
            case .none:      return NSLocalizedString("None (Instant)", comment: "")
            case .crossfade: return NSLocalizedString("Crossfade", comment: "")
            case .slide:     return NSLocalizedString("Slide", comment: "")
            }
        }

        var caTransitionType: CATransitionType {
            switch self {
            case .none:      return .fade   // won't be used since we skip
            case .crossfade: return .fade
            case .slide:     return .push
            }
        }

        var caTransitionSubtype: CATransitionSubtype? {
            switch self {
            case .slide: return .fromRight
            default:     return nil
            }
        }

        var duration: CFTimeInterval {
            switch self {
            case .none:      return 0
            case .crossfade: return 0.4
            case .slide:     return 0.35
            }
        }
    }

    // MARK: - 持久化 Key
    // MARK: - Persistence keys
    private let transitionKey  = "slideshowTransition"
    private let intervalKey    = "slideshowInterval"
    private let musicPathKey   = "slideshowMusicPath"
    private let volumeKey      = "slideshowVolume"
    private let loopKey        = "slideshowLoop"

    // MARK: - Properties

    var transition: TransitionType {
        get { TransitionType(rawValue: UserDefaults.standard.integer(forKey: transitionKey)) ?? .crossfade }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: transitionKey) }
    }

    var interval: TimeInterval {
        get { UserDefaults.standard.double(forKey: intervalKey).nonZero(3.0) }
        set { UserDefaults.standard.set(newValue, forKey: intervalKey) }
    }

    var musicURL: URL? {
        get {
            guard let path = UserDefaults.standard.string(forKey: musicPathKey) else { return nil }
            let url = URL(fileURLWithPath: path)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        set {
            if let url = newValue {
                UserDefaults.standard.set(url.path, forKey: musicPathKey)
            } else {
                UserDefaults.standard.removeObject(forKey: musicPathKey)
            }
        }
    }

    var volume: Float {
        get { UserDefaults.standard.float(forKey: volumeKey).nonZeroF(0.5) }
        set { UserDefaults.standard.set(newValue, forKey: volumeKey) }
    }

    var loopMusic: Bool {
        get { UserDefaults.standard.object(forKey: loopKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: loopKey) }
    }

    // MARK: - Runtime state

    private weak var viewController: ViewController?
    private var timer: Timer?
    private var audioPlayer: AVAudioPlayer?
    private var musicObserver: NSObjectProtocol?

    var isPlaying: Bool { timer != nil && !isPaused }
    private(set) var isPaused: Bool = false

    // MARK: - Controls

    /// 开始幻灯片
    /// Start slideshow
    func start(in vc: ViewController) {
        viewController = vc

        // 如果在缩略图视图，自动进入大图模式并从选择/第一张开始
        // If in thumbnail view, enter large view from selection or first image
        if !vc.publicVar.isInLargeView {
            var targetIndex = 0
            let urls = vc.publicVar.selectedUrls()
            if let first = urls.first {
                vc.fileDB.lock()
                if let files = vc.fileDB.db[SortKeyDir(vc.fileDB.curFolder)]?.files {
                    for (i, pair) in files.enumerated() {
                        if pair.1.path == first.absoluteString {
                            targetIndex = i
                            break
                        }
                    }
                }
                vc.fileDB.unlock()
            }
            let cnt = vc.fileDB.db[SortKeyDir(vc.fileDB.curFolder)]?.files.count ?? 0
            if cnt > 0 {
                let idx = min(targetIndex, cnt - 1)
                vc.openLargeImage(IndexPath(item: idx, section: 0))
            } else {
                return
            }
        }

        stopMusic()
        startMusic()
        scheduleNext()
    }

    /// 停止幻灯片
    /// Stop slideshow
    func stop() {
        timer?.invalidate()
        timer = nil
        isPaused = false
        stopMusic()
        viewController = nil
    }

    /// 暂停/恢复
    /// Pause / Resume
    func togglePause() {
        if isPaused {
            isPaused = false
            scheduleNext()
        } else {
            isPaused = true
            timer?.invalidate()
            timer = nil
        }
    }

    /// 手动下一张（触发过渡）
    /// Manually advance (with transition)
    func advance() {
        guard let vc = viewController else { return }
        applyTransition()
        vc.nextLargeImage()
        scheduleNext()
    }

    // MARK: - Timer

    private func scheduleNext() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.advance()
        }
    }

    // MARK: - 过渡动画
    // MARK: - Transition animation

    /// 在 LargeImageView 上执行过渡动画
    /// Apply transition to LargeImageView
    private func applyTransition() {
        guard let vc = viewController,
              let largeView = vc.largeImageView,
              let imageView = largeView.imageView,
              let layer = imageView.layer
        else { return }

        let t = transition
        guard t != .none else { return }

        let transition = CATransition()
        transition.duration = t.duration
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        transition.type = t.caTransitionType
        if let subtype = t.caTransitionSubtype {
            transition.subtype = subtype
        }
        layer.add(transition, forKey: "slideshowTransition")
    }

    // MARK: - 背景音乐
    // MARK: - Background music

    private func startMusic() {
        guard let url = musicURL else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = volume
            audioPlayer?.numberOfLoops = loopMusic ? -1 : 0
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            log("Slideshow music: failed to play \(url.path): \(error)", level: .error)
        }
    }

    private func stopMusic() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    /// 更新音量（运行时调用）
    /// Update volume (live)
    func updateVolume(_ vol: Float) {
        volume = vol
        audioPlayer?.volume = vol
    }
}

// MARK: - Helpers

private extension TimeInterval {
    func nonZero(_ defaultVal: TimeInterval) -> TimeInterval {
        self == 0 ? defaultVal : self
    }
}

private extension Float {
    func nonZeroF(_ defaultVal: Float) -> Float {
        self == 0 ? defaultVal : self
    }
}
