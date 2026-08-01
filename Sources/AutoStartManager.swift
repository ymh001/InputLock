import ServiceManagement

final class AutoStartManager {
    static let shared = AutoStartManager()

    private let service = SMAppService.mainApp

    var isEnabled: Bool {
        service.status == .enabled
    }

    var needsApproval: Bool {
        service.status == .requiresApproval
    }

    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            return true
        } catch {
            NSLog("[InputLock] autoStart enabled=\(enabled) failed=\(error.localizedDescription)")
            return false
        }
    }
}
