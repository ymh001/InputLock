import Foundation

struct AppRule: Codable, Equatable {
    var appKey: String
    var displayName: String
    var sourceID: String
}

final class AppRuleManager {
    static let shared = AppRuleManager()

    private let defaultsKey = "appRules"
    private(set) var rules: [String: AppRule] = [:]
    var onRulesChanged: (() -> Void)?

    init() {
        load()
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([String: AppRule].self, from: data) else { return }
        rules = decoded
    }

    func save() {
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
        onRulesChanged?()
    }

    func set(rule: AppRule) {
        rules[rule.appKey] = rule
        save()
    }

    func remove(appKey: String) {
        rules.removeValue(forKey: appKey)
        save()
    }

    func rule(forAppKey key: String) -> AppRule? {
        rules[key]
    }
}
