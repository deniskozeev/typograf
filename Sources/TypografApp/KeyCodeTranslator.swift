import AppKit
import Carbon.HIToolbox

/// Преобразование кодов клавиш и модификаторов в человекочитаемый вид (⌃⌥T).
enum KeyCodeTranslator {

    static func display(keyCode: UInt32, carbonModifiers: UInt32) -> String {
        var result = ""
        if carbonModifiers & UInt32(controlKey) != 0 { result += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { result += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { result += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { result += "⌘" }
        result += keyName(for: keyCode)
        return result
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        return carbon
    }

    private static let specialKeys: [UInt32: String] = [
        UInt32(kVK_Space): "Пробел",
        UInt32(kVK_Return): "↩",
        UInt32(kVK_Tab): "⇥",
        UInt32(kVK_Delete): "⌫",
        UInt32(kVK_ForwardDelete): "⌦",
        UInt32(kVK_Escape): "⎋",
        UInt32(kVK_LeftArrow): "←",
        UInt32(kVK_RightArrow): "→",
        UInt32(kVK_UpArrow): "↑",
        UInt32(kVK_DownArrow): "↓",
        UInt32(kVK_Home): "↖",
        UInt32(kVK_End): "↘",
        UInt32(kVK_PageUp): "⇞",
        UInt32(kVK_PageDown): "⇟",
        UInt32(kVK_F1): "F1", UInt32(kVK_F2): "F2", UInt32(kVK_F3): "F3",
        UInt32(kVK_F4): "F4", UInt32(kVK_F5): "F5", UInt32(kVK_F6): "F6",
        UInt32(kVK_F7): "F7", UInt32(kVK_F8): "F8", UInt32(kVK_F9): "F9",
        UInt32(kVK_F10): "F10", UInt32(kVK_F11): "F11", UInt32(kVK_F12): "F12"
    ]

    /// Стандартные шорткаты macOS, которые работают в каждом приложении.
    /// Глобальный хоткей перехватил бы их системно — «Вставить» или «Найти»
    /// перестали бы работать везде, поэтому такие сочетания не даём назначить.
    static func standardShortcutName(keyCode: UInt32, carbonModifiers: UInt32) -> String? {
        let cmdOnly = UInt32(cmdKey)
        let cmdShift = UInt32(cmdKey | shiftKey)
        let relevant = carbonModifiers & UInt32(controlKey | optionKey | shiftKey | cmdKey)

        let cmdOnlyShortcuts: [UInt32: String] = [
            UInt32(kVK_ANSI_A): "Выделить всё",
            UInt32(kVK_ANSI_C): "Скопировать",
            UInt32(kVK_ANSI_V): "Вставить",
            UInt32(kVK_ANSI_X): "Вырезать",
            UInt32(kVK_ANSI_Z): "Отменить",
            UInt32(kVK_ANSI_F): "Найти",
            UInt32(kVK_ANSI_S): "Сохранить",
            UInt32(kVK_ANSI_N): "Новое окно",
            UInt32(kVK_ANSI_O): "Открыть",
            UInt32(kVK_ANSI_P): "Напечатать",
            UInt32(kVK_ANSI_W): "Закрыть окно",
            UInt32(kVK_ANSI_Q): "Завершить программу",
            UInt32(kVK_ANSI_T): "Новая вкладка",
            UInt32(kVK_ANSI_R): "Обновить",
            UInt32(kVK_ANSI_M): "Свернуть",
            UInt32(kVK_ANSI_H): "Скрыть",
            UInt32(kVK_ANSI_Comma): "Настройки"
        ]
        let cmdShiftShortcuts: [UInt32: String] = [
            UInt32(kVK_ANSI_Z): "Повторить",
            UInt32(kVK_ANSI_T): "Восстановить вкладку",
            UInt32(kVK_ANSI_N): "Новое приватное окно",
            UInt32(kVK_ANSI_S): "Сохранить как"
        ]

        if relevant == cmdOnly { return cmdOnlyShortcuts[keyCode] }
        if relevant == cmdShift { return cmdShiftShortcuts[keyCode] }
        return nil
    }

    private static func keyName(for keyCode: UInt32) -> String {
        if let special = specialKeys[keyCode] {
            return special
        }

        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return "?"
        }
        let data = Unmanaged<CFData>.fromOpaque(layoutData).takeUnretainedValue() as Data

        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        var deadKeyState: UInt32 = 0
        let status = data.withUnsafeBytes { buffer -> OSStatus in
            let layout = buffer.bindMemory(to: UCKeyboardLayout.self).baseAddress!
            return UCKeyTranslate(
                layout,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &length,
                &chars
            )
        }
        guard status == noErr, length > 0 else { return "?" }
        return String(utf16CodeUnits: chars, count: length).uppercased()
    }
}
