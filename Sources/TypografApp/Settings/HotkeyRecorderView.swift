import SwiftUI
import AppKit
import Carbon.HIToolbox

/// Кнопка-рекордер: клик — и следующее нажатое сочетание становится хоткеем.
/// Занятые сочетания (системные или чужих приложений) не принимаются.
struct HotkeyRecorderView: View {
    /// Сообщение о занятом сочетании — рендерится снаружи, под серым блоком секции.
    @Binding var conflictMessage: String?

    @ObservedObject private var prefs = Preferences.shared
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            Button {
                isRecording ? cancelRecording() : startRecording()
            } label: {
                Text(isRecording ? "Нажмите сочетание…" : prefs.hotkeyDisplay)
                    .frame(minWidth: 130)
            }
            .tint(isRecording ? .accentColor : nil)

            // Стрелка вставляется в строку, появление — фейд со сдвигом слева;
            // сдвиг соседних полей анимируется тем же .animation(value: showsReset).
            if showsReset {
                Button {
                    conflictMessage = nil
                    prefs.setHotkey(
                        keyCode: Preferences.defaultKeyCode,
                        carbonModifiers: Preferences.defaultModifiers
                    )
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .buttonStyle(.borderless)
                .help("Вернуть ⌃⌥T")
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: showsReset)
        // Ширина плашки меняется вместе с текстом («Нажмите сочетание…» ↔ «⌃⌥T»)
        // и при смене самого сочетания — эти сдвиги тоже анимируем.
        .animation(.easeOut(duration: 0.2), value: isRecording)
        .animation(.easeOut(duration: 0.2), value: prefs.hotkeyDisplay)
        .onDisappear { cancelRecording() }
    }

    private var showsReset: Bool {
        !isRecording && !isDefaultHotkey
    }

    private var isDefaultHotkey: Bool {
        prefs.hotkeyKeyCode == Preferences.defaultKeyCode
            && prefs.hotkeyModifiers == Preferences.defaultModifiers
    }

    private func startRecording() {
        isRecording = true
        conflictMessage = nil
        // На время записи снимаем глобальный хоткей, чтобы можно было выбрать то же сочетание.
        HotkeyManager.shared.unregister()

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                cancelRecording()
                return nil
            }
            let carbonModifiers = KeyCodeTranslator.carbonModifiers(from: event.modifierFlags)
            let hasRequiredModifier = carbonModifiers & UInt32(controlKey | optionKey | cmdKey) != 0
            let isFunctionKey = (Int(event.keyCode) >= kVK_F1 && Int(event.keyCode) <= kVK_F12)
            guard hasRequiredModifier || isFunctionKey else {
                NSSound.beep()
                return nil
            }
            capture(keyCode: UInt32(event.keyCode), carbonModifiers: carbonModifiers)
            return nil
        }
    }

    /// Проверяет кандидата: системные сочетания и хоткеи других приложений
    /// отклоняются, прежний хоткей остаётся.
    private func capture(keyCode: UInt32, carbonModifiers: UInt32) {
        let display = KeyCodeTranslator.display(keyCode: keyCode, carbonModifiers: carbonModifiers)

        if let shortcut = KeyCodeTranslator.standardShortcutName(
            keyCode: keyCode,
            carbonModifiers: carbonModifiers
        ) {
            NSSound.beep()
            finishRecording(message: "\(display) — это «\(shortcut)» во всех приложениях")
            return
        }

        if HotkeyManager.isReservedBySystem(keyCode: keyCode, carbonModifiers: carbonModifiers) {
            NSSound.beep()
            finishRecording(message: "\(display) занято системным сочетанием macOS")
            return
        }

        if !HotkeyManager.shared.register(keyCode: keyCode, carbonModifiers: carbonModifiers) {
            NSSound.beep()
            finishRecording(message: "\(display) уже использует другое приложение")
            return
        }

        // Успех: хоткей уже зарегистрирован, сохраняем в настройки.
        prefs.setHotkey(keyCode: keyCode, carbonModifiers: carbonModifiers)
        finishRecording(message: nil)
    }

    private func cancelRecording() {
        finishRecording(message: nil)
    }

    private func finishRecording(message: String?) {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        isRecording = false
        conflictMessage = message
        // Возвращаем действующий хоткей (после успешной записи — уже новый).
        HotkeyManager.shared.register(
            keyCode: prefs.hotkeyKeyCode,
            carbonModifiers: prefs.hotkeyModifiers
        )
    }
}
