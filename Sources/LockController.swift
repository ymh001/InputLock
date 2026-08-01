import AppKit

final class LockController: NSObject {
    static let shared = LockController()

    private let input = InputSourceManager.shared
    private let rules = AppRuleManager.shared
    private let defaults = UserDefaults.standard

    private let pauseKey = "pauseUntil"
    private let globalKey = "globalSourceID"

    var globalSourceID: String? {
        get { defaults.string(forKey: globalKey) }
        set {
            defaults.set(newValue, forKey: globalKey)
            onStateChanged?()
        }
    }

    private var pauseUntil: Date? {
        get { defaults.object(forKey: pauseKey) as? Date }
        set { defaults.set(newValue, forKey: pauseKey) }
    }

    var isPaused: Bool {
        guard let until = pauseUntil else { return false }
        return until.timeIntervalSinceNow > 0
    }

    var pausedIndefinitely: Bool {
        pauseUntil == .distantFuture
    }

    var onStateChanged: (() -> Void)?
    var onFrontAppChanged: ((String, String) -> Void)?

    private var monitorTimer: Timer?
    private var frontAppName = ""
    private var frontAppKey = ""

    func start() {
        observeFrontAppChange()
        updateFrontApp()
        let timer = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        monitorTimer = timer
    }

    func targetSourceID() -> String? {
        if isPaused { return nil }
        if let rule = rules.rule(forAppKey: frontAppKey) {
            return rule.sourceID
        }
        return globalSourceID
    }

    func currentFrontAppName() -> String { frontAppName }
    func currentFrontAppKey() -> String { frontAppKey }

    func tick() {
        guard let target = targetSourceID() else { return }
        guard input.sourceExists(sourceID: target) else { return }
        if input.currentSourceID() != target {
            _ = input.select(sourceID: target)
        }
    }

    func pause(minutes: Int) {
        pauseUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
        onStateChanged?()
    }

    func pauseIndefinitely() {
        pauseUntil = .distantFuture
        onStateChanged?()
    }

    func resume() {
        pauseUntil = nil
        onStateChanged?()
    }

    func setGlobal(sourceID: String) {
        globalSourceID = sourceID
        tick()
    }

    func clearGlobal() {
        globalSourceID = nil
    }

    func setRuleForCurrentApp(sourceID: String) {
        guard !frontAppKey.isEmpty else { return }
        let rule = AppRule(appKey: frontAppKey, displayName: frontAppName, sourceID: sourceID)
        rules.set(rule: rule)
        tick()
    }

    func removeRule(appKey: String) {
        rules.remove(appKey: appKey)
        tick()
    }

    private func observeFrontAppChange() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(frontAppDidChange(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func frontAppDidChange(_ note: Notification) {
        updateFrontApp()
    }

    private func updateFrontApp() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let name = app.localizedName ?? (app.bundleIdentifier ?? "Unknown")
        let key = app.bundleIdentifier ?? name
        frontAppName = name
        frontAppKey = key
        onFrontAppChanged?(frontAppName, frontAppKey)
    }
}
