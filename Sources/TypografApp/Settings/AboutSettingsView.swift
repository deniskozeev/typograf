import SwiftUI

struct AboutSettingsView: View {
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    /// Письмо с заранее заполненной темой и данными окружения.
    private var feedbackMailURL: URL {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "dakozeev@gmail.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Типограф \(appVersion) — отзыв"),
            URLQueryItem(name: "body", value: "\n\n—\nТипограф \(appVersion), macOS \(osVersion)")
        ]
        return components.url!
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 80, height: 80)
                Text("Типограф")
                    .font(.title3.weight(.semibold))
                Text("Версия \(appVersion)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)
            .padding(.bottom, 8)

            Form {
                Section {
                    LabeledContent("Разработчик") {
                        Link("Denis Kozeev — kozeev.ru", destination: URL(string: "https://kozeev.ru")!)
                    }
                    LabeledContent("Движок правил") {
                        Link(
                            "typograf \(TypografEngine.shared.libraryVersion) — GitHub",
                            destination: URL(string: "https://github.com/typograf/typograf")!
                        )
                    }
                }

                Section {
                    LabeledContent("Обновления") {
                        Button("Проверить…") {
                            (NSApp.delegate as? AppDelegate)?.checkForUpdates()
                        }
                    }
                    Link(destination: feedbackMailURL) {
                        Label("Сообщить об ошибке или пожелании", systemImage: "envelope")
                    }
                    Link(destination: URL(string: "https://pay.cloudtips.ru/p/2e5a46a4")!) {
                        Label("Угостить автора кофе", systemImage: "cup.and.saucer.fill")
                    }
                } footer: {
                    Text("Правила типографики — библиотека typograf © Denis Seleznev, MIT License.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
    }
}
