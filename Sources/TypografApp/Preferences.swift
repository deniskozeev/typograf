import Foundation
import Carbon.HIToolbox

/// Настройки приложения поверх UserDefaults.
final class Preferences: ObservableObject {
    static let shared = Preferences()

    private enum Key {
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
        static let showStatusIcon = "showStatusIcon"
        static let ruleOverrides = "ruleOverrides"
    }

    static let defaultKeyCode = UInt32(kVK_ANSI_T)
    static let defaultModifiers = UInt32(controlKey | optionKey)

    private let defaults = UserDefaults.standard

    @Published var hotkeyKeyCode: UInt32 {
        didSet { defaults.set(Int(hotkeyKeyCode), forKey: Key.hotkeyKeyCode) }
    }

    @Published var hotkeyModifiers: UInt32 {
        didSet { defaults.set(Int(hotkeyModifiers), forKey: Key.hotkeyModifiers) }
    }

    @Published var showStatusIcon: Bool {
        didSet { defaults.set(showStatusIcon, forKey: Key.showStatusIcon) }
    }

    /// Отклонения от стандартного набора правил: имя правила → включено.
    @Published var ruleOverrides: [String: Bool] {
        didSet { defaults.set(ruleOverrides, forKey: Key.ruleOverrides) }
    }

    private init() {
        if defaults.object(forKey: Key.hotkeyKeyCode) != nil {
            hotkeyKeyCode = UInt32(defaults.integer(forKey: Key.hotkeyKeyCode))
            hotkeyModifiers = UInt32(defaults.integer(forKey: Key.hotkeyModifiers))
        } else {
            hotkeyKeyCode = Self.defaultKeyCode
            hotkeyModifiers = Self.defaultModifiers
        }
        showStatusIcon = defaults.object(forKey: Key.showStatusIcon) as? Bool ?? true
        ruleOverrides = defaults.dictionary(forKey: Key.ruleOverrides) as? [String: Bool] ?? [:]
    }

    var hotkeyDisplay: String {
        KeyCodeTranslator.display(keyCode: hotkeyKeyCode, carbonModifiers: hotkeyModifiers)
    }

    func setHotkey(keyCode: UInt32, carbonModifiers: UInt32) {
        hotkeyKeyCode = keyCode
        hotkeyModifiers = carbonModifiers
    }

    func resetRulesToDefaults() {
        ruleOverrides = [:]
    }
}
