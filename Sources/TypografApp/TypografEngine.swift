import Foundation
import JavaScriptCore

struct TypografRule: Identifiable, Hashable {
    let name: String
    let group: String
    let locale: String
    let enabledByDefault: Bool
    let title: String
    /// Предвычисленный ключ для поиска — чтобы не гонять ICU-сравнения на каждый ввод.
    let searchKey: String

    var id: String { name }
}

struct TypografRuleGroup: Identifiable {
    let name: String
    let title: String
    let rules: [TypografRule]

    var id: String { name }
}

/// Движок правил: оригинальная библиотека typograf, исполняемая системным JavaScriptCore.
final class TypografEngine {
    static let shared = TypografEngine()

    private let context: JSContext
    private let instance: JSValue
    private(set) var groups: [TypografRuleGroup] = []
    private(set) var libraryVersion = "?"
    private var defaultEnabledByName: [String: Bool] = [:]

    private init() {
        context = JSContext()!
        context.exceptionHandler = { _, exception in
            NSLog("Typograf JS error: %@", exception?.toString() ?? "unknown")
        }

        guard let jsURL = Bundle.module.url(forResource: "typograf.min", withExtension: "js"),
              let source = try? String(contentsOf: jsURL, encoding: .utf8) else {
            fatalError("typograf.min.js not found in bundle")
        }
        context.evaluateScript(source, withSourceURL: jsURL)

        let typograf = context.objectForKeyedSubscript("Typograf")!
        instance = typograf.construct(withArguments: [["locale": ["ru", "en-US"]]])!
        if let version = typograf.objectForKeyedSubscript("version"), version.isString {
            libraryVersion = version.toString()
        }

        loadRules(typograf: typograf)
        applyOverrides(Preferences.shared.ruleOverrides)
    }

    /// Прогревает синглтон (загрузка и парсинг JS) — вызывается один раз на старте.
    func warmUp() {}

    func process(_ text: String) -> String? {
        guard let result = instance.invokeMethod("execute", withArguments: [text]),
              result.isString else { return nil }
        return result.toString()
    }

    func setRule(name: String, enabled: Bool) {
        instance.invokeMethod(enabled ? "enableRule" : "disableRule", withArguments: [name])
    }

    func applyOverrides(_ overrides: [String: Bool]) {
        for (name, defaultEnabled) in defaultEnabledByName {
            let enabled = overrides[name] ?? defaultEnabled
            if enabled != defaultEnabled {
                setRule(name: name, enabled: enabled)
            }
        }
    }

    /// Точечно применяет только изменившиеся правила —
    /// чтобы не дёргать движок 105 раз на каждый переключатель.
    func applyChanges(from old: [String: Bool], to new: [String: Bool]) {
        for name in Set(old.keys).union(new.keys) {
            let defaultEnabled = defaultEnabledByName[name] ?? true
            let oldEnabled = old[name] ?? defaultEnabled
            let newEnabled = new[name] ?? defaultEnabled
            if oldEnabled != newEnabled {
                setRule(name: name, enabled: newEnabled)
            }
        }
    }

    private func loadRules(typograf: JSValue) {
        let titles = loadJSON("typograf.titles") as? [String: [String: String]] ?? [:]
        let groupsJSON = loadJSON("typograf.groups") as? [[String: Any]] ?? []

        guard let rawRules = typograf.invokeMethod("getRules", withArguments: [])?
            .toArray() as? [[String: Any]] else { return }

        var rulesByGroup: [String: [TypografRule]] = [:]
        for raw in rawRules {
            guard let name = raw["name"] as? String,
                  let group = raw["group"] as? String else { continue }
            let locale = raw["locale"] as? String ?? "common"
            let enabled = raw["enabled"] as? Bool ?? true
            let title = titles[name]?["ru"] ?? titles[name]?["en-US"] ?? name
            let rule = TypografRule(
                name: name,
                group: group,
                locale: locale,
                enabledByDefault: enabled,
                title: title,
                searchKey: "\(title) \(name)".lowercased()
            )
            defaultEnabledByName[name] = enabled
            rulesByGroup[group, default: []].append(rule)
        }

        var result: [TypografRuleGroup] = []
        for entry in groupsJSON {
            guard let groupName = entry["name"] as? String,
                  var rules = rulesByGroup.removeValue(forKey: groupName) else { continue }
            let title = (entry["title"] as? [String: String])?["ru"] ?? groupName
            rules.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            result.append(TypografRuleGroup(name: groupName, title: title, rules: rules))
        }
        // Группы, которых нет в groups.json, добавляем в конец как есть.
        for (groupName, rules) in rulesByGroup.sorted(by: { $0.key < $1.key }) {
            result.append(TypografRuleGroup(name: groupName, title: groupName, rules: rules))
        }
        groups = result
    }

    private func loadJSON(_ resource: String) -> Any? {
        guard let url = Bundle.module.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }
}
