import SwiftUI
import ServiceManagement

struct GeneralSettingsView: View {
    @ObservedObject private var prefs = Preferences.shared
    @State private var accessibilityGranted = AccessibilityHelper.isTrusted
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var hotkeyConflict: String?

    private let accessibilityTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Сочетание клавиш")
                    Spacer()
                    HotkeyRecorderView(conflictMessage: $hotkeyConflict)
                }
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    if let hotkeyConflict {
                        Text(hotkeyConflict)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    Text("Выделите текст в любом приложении и нажмите сочетание — текст будет типографирован и заменён на месте.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .animation(.easeOut(duration: 0.2), value: hotkeyConflict)
            }

            Section {
                Toggle("Показывать иконку в менюбаре", isOn: $prefs.showStatusIcon)
                Toggle("Запускать при входе в систему", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { enabled in
                        setLaunchAtLogin(enabled)
                    }
            } footer: {
                Text("Если иконка скрыта, хоткей продолжает работать; чтобы вернуться в настройки, откройте Typograf.app ещё раз.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Доступ") {
                if accessibilityGranted {
                    Label {
                        Text("Универсальный доступ разрешён")
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                } else {
                    Label {
                        Text("Нет разрешения «Универсальный доступ»")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                    }
                    Text("Без него Типограф не может читать выделенный текст и заменять его. Включите Типограф в списке: Настройки → Конфиденциальность и безопасность → Универсальный доступ.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("Открыть системные настройки…") {
                        AccessibilityHelper.openSystemSettings()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onReceive(accessibilityTimer) { _ in
            let trusted = AccessibilityHelper.isTrusted
            // Не трогаем @State без изменения — иначе вкладка перерисовывается каждые 1.5 с.
            if trusted != accessibilityGranted {
                accessibilityGranted = trusted
            }
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
