import SwiftUI
import AppKit

struct RulesSettingsView: View {
    @ObservedObject private var prefs = Preferences.shared
    @State private var searchText = ""
    @State private var appliedQuery = ""
    @State private var pendingFilter: DispatchWorkItem?

    private var groups: [TypografRuleGroup] { TypografEngine.shared.groups }

    var body: some View {
        Form {
            Section {
                NativeSearchField(text: $searchText, placeholder: "Найти правило")
                HStack {
                    Text(overridesSummary)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Сбросить") {
                        prefs.resetRulesToDefaults()
                    }
                    .controlSize(.small)
                    .disabled(prefs.ruleOverrides.isEmpty)
                }
            } header: {
                // Отступ от тулбара, чтобы блок поиска не прилипал к нему.
                Color.clear.frame(height: 8)
            }

            ForEach(filteredGroups) { group in
                Section(group.title) {
                    ForEach(group.rules) { rule in
                        RuleRow(
                            rule: rule,
                            isChanged: prefs.ruleOverrides[rule.name] != nil,
                            isOn: binding(for: rule)
                        )
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: searchText) { newValue in
            scheduleFilter(newValue)
        }
    }

    /// Дебаунс фильтра + отключение анимаций List:
    /// иначе каждая буква запускает анимированную перестройку секций.
    private func scheduleFilter(_ text: String) {
        pendingFilter?.cancel()
        let work = DispatchWorkItem {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                appliedQuery = text.lowercased()
            }
        }
        pendingFilter = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    private var filteredGroups: [TypografRuleGroup] {
        guard !appliedQuery.isEmpty else { return groups }
        return groups.compactMap { group in
            let rules = group.rules.filter { $0.searchKey.contains(appliedQuery) }
            guard !rules.isEmpty else { return nil }
            return TypografRuleGroup(name: group.name, title: group.title, rules: rules)
        }
    }

    private var overridesSummary: String {
        let count = prefs.ruleOverrides.count
        guard count > 0 else { return "Стандартный набор правил" }
        return "Изменено правил: \(count)"
    }

    private func binding(for rule: TypografRule) -> Binding<Bool> {
        Binding(
            get: { prefs.ruleOverrides[rule.name] ?? rule.enabledByDefault },
            set: { newValue in
                if newValue == rule.enabledByDefault {
                    prefs.ruleOverrides.removeValue(forKey: rule.name)
                } else {
                    prefs.ruleOverrides[rule.name] = newValue
                }
            }
        )
    }
}

/// Системное поле поиска — нативные плейсхолдер, лупа и кнопка очистки.
private struct NativeSearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        if field.stringValue != text {
            field.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        private let text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            text.wrappedValue = field.stringValue
        }
    }
}

private struct RuleRow: View {
    let rule: TypografRule
    let isChanged: Bool
    let isOn: Binding<Bool>

    var body: some View {
        HStack(spacing: 8) {
            Text(rule.title)
                .lineLimit(2)
            if rule.locale != "common" {
                Text(rule.locale == "ru" ? "ru" : "en")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: Capsule())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isChanged {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 6, height: 6)
                    .help("Правило изменено")
            }
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }
}
