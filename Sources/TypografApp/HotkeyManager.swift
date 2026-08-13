import Foundation
import Carbon.HIToolbox

/// Глобальный хоткей через Carbon RegisterEventHotKey —
/// не требует Accessibility и не ставит event tap на всю систему.
final class HotkeyManager {
    static let shared = HotkeyManager()

    var handler: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private init() {}

    /// Регистрирует глобальный хоткей. `false` — сочетание уже занято
    /// другим приложением (eventHotKeyExistsErr) или регистрация не удалась.
    @discardableResult
    func register(keyCode: UInt32, carbonModifiers: UInt32) -> Bool {
        unregister()
        installEventHandlerIfNeeded()

        let hotKeyID = EventHotKeyID(signature: OSType(0x5450_4746), id: 1) // 'TPGF'
        let status = RegisterEventHotKey(
            keyCode,
            carbonModifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            OptionBits(kEventHotKeyExclusive),
            &hotKeyRef
        )
        if status != noErr {
            NSLog("Typograf: failed to register hotkey (status %d)", status)
            hotKeyRef = nil
            return false
        }
        return true
    }

    /// Сочетание зарезервировано системой (Spotlight, скриншоты, Mission Control…).
    /// Список берётся из активных системных клавиш (CopySymbolicHotKeys).
    static func isReservedBySystem(keyCode: UInt32, carbonModifiers: UInt32) -> Bool {
        var hotKeysArray: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&hotKeysArray) == noErr,
              let entries = hotKeysArray?.takeRetainedValue() as? [[String: Any]] else {
            return false
        }
        let relevantMask = UInt32(controlKey | optionKey | shiftKey | cmdKey)
        return entries.contains { entry in
            guard entry[kHISymbolicHotKeyEnabled as String] as? Bool == true,
                  let code = entry[kHISymbolicHotKeyCode as String] as? Int,
                  let modifiers = entry[kHISymbolicHotKeyModifiers as String] as? Int else {
                return false
            }
            return UInt32(code) == keyCode
                && UInt32(modifiers) & relevantMask == carbonModifiers & relevantMask
        }
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, _, _ in
                DispatchQueue.main.async {
                    HotkeyManager.shared.handler?()
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
    }
}
