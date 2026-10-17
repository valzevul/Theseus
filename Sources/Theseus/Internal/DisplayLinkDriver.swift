import UIKit
import QuartzCore

/// One shared `CADisplayLink` for many subscribers: it runs at the fastest rate requested
/// and delivers each link at its own cadence. Links are held weakly; keep the `Link` from `add`.
public final class DisplayLinkDriver {

    public static let shared = DisplayLinkDriver()

    public enum FramesPerSecond {
        case fps(Int)
        case max

        var preferredFPS: Int {
            switch self {
            case .fps(let fps):
                return fps
            case .max:
                return 60
            }
        }
    }

    /// Delivery order within one tick: animation links run before render links.
    public enum CallbackPriority: Int {
        case animation = 0
        case render = 100
    }

    /// A subscription to the driver; releasing it unsubscribes.
    public final class Link {
        fileprivate let id: UUID
        fileprivate weak var driver: DisplayLinkDriver?
        fileprivate let callback: (CFTimeInterval) -> Void
        fileprivate var lastDeliveryTimestamp: CFTimeInterval?
        fileprivate var priority: CallbackPriority = .animation
        fileprivate var sequence: Int = 0

        public var isPaused: Bool {
            get { _isPaused }
            set {
                _isPaused = newValue
                if !newValue {
                    lastDeliveryTimestamp = nil
                }
                driver?.linkStateDidChange()
            }
        }
        private var _isPaused: Bool = false

        public var preferredFramesPerSecond: Int {
            get { _preferredFramesPerSecond }
            set {
                _preferredFramesPerSecond = newValue
                driver?.linkStateDidChange()
            }
        }
        fileprivate var _preferredFramesPerSecond: Int = 60

        fileprivate init(id: UUID, driver: DisplayLinkDriver, callback: @escaping (CFTimeInterval) -> Void) {
            self.id = id
            self.driver = driver
            self.callback = callback
        }

        deinit {
            invalidate()
        }

        public func invalidate() {
            driver?.removeLink(self)
        }
    }

    /// Weak so a dropped `Link` unsubscribes through its `deinit`.
    private final class WeakLink {
        weak var link: Link?
        init(_ link: Link) { self.link = link }
    }

    private var displayLink: CADisplayLink?
    private var links: [UUID: WeakLink] = [:]
    /// Recursive: dropping the last reference to a `Link` under this lock
    /// re-enters `removeLink` from its `deinit`.
    private let lock = NSRecursiveLock()
    private var currentFrameRate: Int = 0
    private var nextSequence: Int = 0

    private init() {}

    /// Subscribes `callback` at `framesPerSecond`; the caller must keep the returned `Link`.
    public func add(
        framesPerSecond: FramesPerSecond = .max,
        priority: CallbackPriority = .animation,
        _ callback: @escaping (CFTimeInterval) -> Void
    ) -> Link {
        lock.lock()
        defer { lock.unlock() }

        let id = UUID()
        let link = Link(id: id, driver: self, callback: callback)
        link._preferredFramesPerSecond = framesPerSecond.preferredFPS
        link.priority = priority
        nextSequence += 1
        link.sequence = nextSequence
        links[id] = WeakLink(link)

        ensureDisplayLinkExists()
        refreshRateAndStateLocked()

        return link
    }

    private func removeLink(_ link: Link) {
        lock.lock()
        defer { lock.unlock() }

        links.removeValue(forKey: link.id)
        refreshRateAndStateLocked()
    }

    fileprivate func linkStateDidChange() {
        lock.lock()
        defer { lock.unlock() }

        refreshRateAndStateLocked()
    }

    private func ensureDisplayLinkExists() {
        guard displayLink == nil else { return }

        let link = CADisplayLink(target: self, selector: #selector(handleDisplayLink(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
        currentFrameRate = 0
    }

    /// Must be called with the lock held.
    private func liveLinksLocked() -> [Link] {
        var live: [Link] = []
        live.reserveCapacity(links.count)
        for (id, box) in links {
            if let link = box.link {
                live.append(link)
            } else {
                links.removeValue(forKey: id)
            }
        }
        return live
    }

    /// Must be called with the lock held.
    private func refreshRateAndStateLocked() {
        let live = liveLinksLocked()

        if live.isEmpty {
            displayLink?.invalidate()
            displayLink = nil
            currentFrameRate = 0
            return
        }

        let activeLinks = live.filter { !$0.isPaused }
        displayLink?.isPaused = activeLinks.isEmpty

        let maxFPS = activeLinks.map { $0._preferredFramesPerSecond }.max() ?? 60
        if maxFPS != currentFrameRate, let displayLink = displayLink {
            currentFrameRate = maxFPS
            if #available(iOS 15.0, *) {
                let fps = Float(maxFPS)
                displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: fps, maximum: fps, preferred: fps)
            } else {
                displayLink.preferredFramesPerSecond = maxFPS
            }
        }
    }

    @objc private func handleDisplayLink(_ displayLink: CADisplayLink) {
        // Unlock before iterating: a callback may add or remove links.
        lock.lock()
        let activeLinks = liveLinksLocked()
            .filter { !$0.isPaused }
            .sorted {
                ($0.priority.rawValue, $0.sequence) < ($1.priority.rawValue, $1.sequence)
            }
        lock.unlock()

        let timestamp = displayLink.timestamp
        // Half a frame of slack so jitter never starves a subscriber at the display rate.
        let slack = displayLink.duration * 0.5

        for link in activeLinks {
            let fps = max(link._preferredFramesPerSecond, 1)
            let interval = 1.0 / CFTimeInterval(fps)
            if let last = link.lastDeliveryTimestamp,
               timestamp - last < interval - slack {
                continue
            }
            link.lastDeliveryTimestamp = timestamp
            link.callback(timestamp)
        }
    }
}
