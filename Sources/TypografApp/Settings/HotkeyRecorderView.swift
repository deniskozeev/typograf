import SwiftUI
import AppKit
import Carbon.HIToolbox

/// Кнопка-рекордер: клик — и следующее нажатое сочетание становится хоткеем.
struct HotkeyRecorderView: View {
    @ObservedObject private var prefs = Preferences.shared
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            Button {
                isRecording ? stopRecording() : startRecording()
            } label: {
                Text(isRecording ? "Нажмите сочетание…" : prefs.hotkeyDisplay)
                    .frame(minWidth: 130)
            }
            .tint(isRecording ? .accentColor : nil)

            if !isRecording && !isDefaultHotkey {
                Button {
                    prefs.setHotkey(
                        keyCode: Preferences.defaultKeyCode,
                        carbonModifiers: Preferences.defaultModifiers
                    )
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .buttonStyle(.borderless)
                .help("Вернуть ⌃⌥T")
            }
        }
        .onDisappear { stopRecording() }
    }

    private var isDefaultHotkey: Bool {
        prefs.hotkeyKeyCode == Preferences.defaultKeyCode
            && prefs.hotkeyModifiers == Preferences.defaultModifiers
    }

    private func startRecording() {
        isRecording = true
        // На время записи снимаем глобальный хоткей, чтобы можно было выбрать то же сочетание.
        HotkeyManager.shared.unregister()

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                stopRecording()
                return nil
            }
            let carbonModifiers = KeyCodeTranslator.carbonModifiers(from: event.modifierFlags)
            let hasRequiredModifier = carbonModifiers & UInt32(controlKey | optionKey | cmdKey) != 0
            let isFunctionKey = (Int(event.keyCode) >= kVK_F1 && Int(event.keyCode) <= kVK_F12)
            guard hasRequiredModifier || isFunctionKey else {
                NSSound.beep()
                return nil
            }
            prefs.setHotkey(keyCode: UInt32(event.keyCode), carbonModifiers: carbonModifiers)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        isRecording = false
        HotkeyManager.shared.register(
            keyCode: prefs.hotkeyKeyCode,
            carbonModifiers: prefs.hotkeyModifiers
        )
    }
}
