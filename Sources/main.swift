import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination("InputLock is a menu bar agent")
        statusController = StatusBarController()
        LockController.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSLog("[InputLock] applicationWillTerminate")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
