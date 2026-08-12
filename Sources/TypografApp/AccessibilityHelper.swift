import AppKit
import ApplicationServices

/// Проверка и запрос разрешения «Универсальный доступ» (Accessibility),
/// без которого нельзя эмулировать ⌘C/⌘V.
enum AccessibilityHelper {

    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Показывает системный запрос и открывает нужный раздел Настроек.
    static func promptAndOpenSettings() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
