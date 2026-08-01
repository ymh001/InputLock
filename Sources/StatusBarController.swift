import AppKit

final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let input = InputSourceManager.shared
    private let rules = AppRuleManager.shared
    private let controller = LockController.shared
    private var menuIsOpen = false
    private var needsMenuRefresh = false

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        setupStatusItem()
        bind()
        refreshMenu()
    }

    private func setupStatusItem() {
        let icon = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "InputLock")
        icon?.isTemplate = true
        statusItem.button?.image = icon
        statusItem.button?.toolTip = "InputLock"
        statusItem.menu = menu
        statusItem.isVisible = true
        menu.delegate = self
    }

    private func bind() {
        controller.onStateChanged = { [weak self] in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.needsMenuRefresh = true
                if !self.menuIsOpen {
                    self.refreshMenu()
                    self.needsMenuRefresh = false
                }
            }
        }
        controller.onFrontAppChanged = nil
        rules.onRulesChanged = { [weak self] in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.needsMenuRefresh = true
                if !self.menuIsOpen {
                    self.refreshMenu()
                    self.needsMenuRefresh = false
                }
            }
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        menuIsOpen = true
        refreshMenu()
        needsMenuRefresh = false
    }

    func menuDidClose(_ menu: NSMenu) {
        menuIsOpen = false
        if needsMenuRefresh {
            refreshMenu()
            needsMenuRefresh = false
        }
    }

    private func refreshMenu() {
        // Keep the same menu attached to the status item. Replacing it while
        // the menu is open can make the item disappear on newer macOS versions.
        menu.removeAllItems()

        let statusText: String
        if controller.isPaused {
            if controller.pausedIndefinitely {
                statusText = "已暂停（无期限）"
            } else if let until = UserDefaults.standard.object(forKey: "pauseUntil") as? Date {
                let minutes = Int(ceil(until.timeIntervalSinceNow / 60.0))
                statusText = "已暂停（\(minutes) 分钟后恢复）"
            } else {
                statusText = "已暂停"
            }
        } else if controller.targetSourceID() != nil {
            let name = input.sourceName(for: controller.targetSourceID()!) ?? controller.targetSourceID()!
            statusText = "锁定中：\(name)"
        } else {
            statusText = "未锁定"
        }
        let status = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        let currentAppName = controller.currentFrontAppName()
        let currentName = input.currentSourceName() ?? "未知"
        let info = NSMenuItem(title: "当前应用：\(currentAppName)｜输入法：\(currentName)", action: nil, keyEquivalent: "")
        info.isEnabled = false
        menu.addItem(info)

        menu.addItem(NSMenuItem.separator())

        let globalMenu = NSMenu()
        for source in input.selectableSources() {
            let item = actionItem(source.displayName, #selector(selectGlobal(_:)))
            item.representedObject = source.sourceID
            if source.sourceID == controller.globalSourceID {
                item.state = .on
            }
            globalMenu.addItem(item)
        }
        let globalItem = NSMenuItem(title: "全局锁定输入法", action: nil, keyEquivalent: "")
        globalItem.submenu = globalMenu
        menu.addItem(globalItem)

        let clearGlobal = actionItem("取消全局锁定", #selector(clearGlobal(_:)))
        clearGlobal.isEnabled = controller.globalSourceID != nil
        menu.addItem(clearGlobal)

        menu.addItem(NSMenuItem.separator())

        let appMenu = NSMenu()
        let frontKey = controller.currentFrontAppKey()
        for source in input.selectableSources() {
            let item = actionItem(source.displayName, #selector(selectForCurrentApp(_:)))
            item.representedObject = source.sourceID
            if let rule = rules.rule(forAppKey: frontKey), rule.sourceID == source.sourceID {
                item.state = .on
            }
            appMenu.addItem(item)
        }
        let appItem = NSMenuItem(title: "\(currentAppName) 的输入法", action: nil, keyEquivalent: "")
        appItem.submenu = appMenu
        menu.addItem(appItem)

        let removeForCurrent = actionItem("取消 \(currentAppName) 的规则", #selector(removeCurrentAppRule(_:)))
        removeForCurrent.isEnabled = rules.rule(forAppKey: frontKey) != nil
        menu.addItem(removeForCurrent)

        menu.addItem(NSMenuItem.separator())

        let manageMenu = NSMenu()
        let ruleKeys = rules.rules.keys.sorted()
        if ruleKeys.isEmpty {
            let empty = NSMenuItem(title: "暂无按应用规则", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            manageMenu.addItem(empty)
        } else {
            for key in ruleKeys {
                if let rule = rules.rules[key] {
                    let sourceName = input.sourceName(for: rule.sourceID) ?? rule.sourceID
                    let item = actionItem("\(rule.displayName) → \(sourceName)（点击移除）", #selector(removeRule(_:)))
                    item.representedObject = key
                    manageMenu.addItem(item)
                }
            }
        }
        let manageItem = NSMenuItem(title: "按应用规则管理", action: nil, keyEquivalent: "")
        manageItem.submenu = manageMenu
        menu.addItem(manageItem)

        menu.addItem(NSMenuItem.separator())

        if controller.isPaused {
            menu.addItem(makeItem("恢复锁定", #selector(resume(_:))))
        } else {
            menu.addItem(makeItem("暂停 5 分钟", #selector(pause5m(_:))))
            menu.addItem(makeItem("暂停 30 分钟", #selector(pause30m(_:))))
            menu.addItem(makeItem("一直暂停", #selector(pauseForever(_:))))
        }

        menu.addItem(makeItem("重新扫描输入法", #selector(rescan(_:))))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeItem("退出 InputLock", #selector(quit(_:))))

        statusItem.isVisible = true
        statusItem.button?.isHidden = false
    }

    private func actionItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func makeItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func selectGlobal(_ sender: NSMenuItem) {
        NSLog("[InputLock] action=selectGlobal source=\(sender.representedObject as? String ?? "nil")")
        guard let sourceID = sender.representedObject as? String else { return }
        controller.setGlobal(sourceID: sourceID)
    }

    @objc private func clearGlobal(_ sender: NSMenuItem) {
        NSLog("[InputLock] action=clearGlobal")
        controller.clearGlobal()
    }

    @objc private func selectForCurrentApp(_ sender: NSMenuItem) {
        NSLog("[InputLock] action=selectForCurrentApp app=\(controller.currentFrontAppKey()) source=\(sender.representedObject as? String ?? "nil")")
        guard let sourceID = sender.representedObject as? String else { return }
        controller.setRuleForCurrentApp(sourceID: sourceID)
    }

    @objc private func removeCurrentAppRule(_ sender: NSMenuItem) {
        NSLog("[InputLock] action=removeCurrentAppRule app=\(controller.currentFrontAppKey())")
        let key = controller.currentFrontAppKey()
        guard !key.isEmpty else { return }
        controller.removeRule(appKey: key)
    }

    @objc private func removeRule(_ sender: NSMenuItem) {
        NSLog("[InputLock] action=removeRule key=\(sender.representedObject as? String ?? "nil")")
        guard let key = sender.representedObject as? String else { return }
        controller.removeRule(appKey: key)
    }

    @objc private func pause5m(_ sender: NSMenuItem) {
        NSLog("[InputLock] action=pause5m")
        controller.pause(minutes: 5)
    }

    @objc private func pause30m(_ sender: NSMenuItem) {
        NSLog("[InputLock] action=pause30m")
        controller.pause(minutes: 30)
    }

    @objc private func pauseForever(_ sender: NSMenuItem) {
        NSLog("[InputLock] action=pauseForever")
        controller.pauseIndefinitely()
    }

    @objc private func resume(_ sender: NSMenuItem) {
        NSLog("[InputLock] action=resume")
        controller.resume()
    }

    @objc private func rescan(_ sender: NSMenuItem) {
        NSLog("[InputLock] action=rescan")
        refreshMenu()
    }

    @objc private func quit(_ sender: NSMenuItem) {
        NSLog("[InputLock] action=quit")
        let alert = NSAlert()
        alert.messageText = "退出 InputLock？"
        alert.informativeText = "退出后输入法将不再被锁定。"
        alert.addButton(withTitle: "退出")
        alert.addButton(withTitle: "取消")
        alert.alertStyle = .warning
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSApp.terminate(nil)
        }
    }
}
