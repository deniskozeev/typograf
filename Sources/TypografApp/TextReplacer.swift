import AppKit
import Carbon.HIToolbox

/// Пайплайн замены: копирует выделение (⌘C), типографирует,
/// вставляет результат (⌘V) и восстанавливает прежний буфер обмена.
final class TextReplacer {
    static let shared = TextReplacer()

    private var busy = false

    private init() {}

    func typografSelection() {
        guard !busy else { return }
        guard AccessibilityHelper.isTrusted else {
            AccessibilityHelper.promptAndOpenSettings()
            return
        }
        busy = true

        let pasteboard = NSPasteboard.general
        let saved = snapshot(of: pasteboard)
        let baseline = pasteboard.changeCount

        postKeystroke(keyCode: CGKeyCode(kVK_ANSI_C), flags: .maskCommand)

        waitForChange(of: pasteboard, baseline: baseline, deadline: Date().addingTimeInterval(0.6)) { changed in
            guard changed,
                  let raw = pasteboard.string(forType: .string),
                  !raw.isEmpty else {
                self.restore(pasteboard, from: saved)
                self.busy = false
                return
            }

            // Bear добавляет при копировании невидимый U+2800 перед маркерами —
            // при вставке он приклеивается к «**» и ломает разметку. Вычищаем.
            let text = self.sanitize(raw)
            guard var processed = TypografEngine.shared.process(text) else {
                self.restore(pasteboard, from: saved)
                self.busy = false
                return
            }

            let isMarkdown = self.looksLikeMarkdown(text)
            if isMarkdown {
                processed = self.fixMarkdownMarkers(processed)
            }

            // HTML-представление выделения: typograf обрабатывает текст, не трогая теги.
            // Возвращаем его в буфер вместе с plain — иначе богатые редакторы (Ghost,
            // Notion и т.п.) при вставке plain-текста теряют списки и заголовки.
            // Исключение — markdown-редакторы (Bear, Obsidian…): у них разметка живёт
            // прямо в тексте, и вставка HTML задваивает маркеры (**жирный** → ****…).
            let html = isMarkdown ? nil : pasteboard.string(forType: .html)
            let processedHTML = html.flatMap { TypografEngine.shared.process($0) }

            guard processed != raw || (processedHTML != nil && processedHTML != html) else {
                // Текст уже типографирован — менять нечего.
                self.restore(pasteboard, from: saved)
                self.busy = false
                self.confirm()
                return
            }

            pasteboard.clearContents()
            pasteboard.setString(processed, forType: .string)
            if let processedHTML {
                pasteboard.setString(processedHTML, forType: .html)
            }
            self.postKeystroke(keyCode: CGKeyCode(kVK_ANSI_V), flags: .maskCommand)

            // Даём приложению время принять вставку, затем возвращаем прежний буфер.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                self.restore(pasteboard, from: saved)
                self.busy = false
                self.confirm()
            }
        }
    }

    private func confirm() {
        (NSApp.delegate as? AppDelegate)?.showConfirmationBadge()
    }

    /// Невидимые символы-паразиты из буфера: U+2800 (брайлевский пробел,
    /// его вставляет Bear) и U+FEFF (BOM).
    private func sanitize(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{2800}", with: "")
            .replacingOccurrences(of: "\u{FEFF}", with: "")
    }

    /// Откатывает пробелы, вставленные типографом вплотную к закрывающим
    /// markdown-маркерам: «**список:**» → «**список: **» → обратно «**список:**».
    /// Открывающие маркеры не трогаем — за ними идёт текст, а не пробел/конец строки.
    private func fixMarkdownMarkers(_ text: String) -> String {
        text.replacingOccurrences(
            of: #"(?m)([:;,.!?…»)]) (\*{1,2}|_{1,2}|~~|`)(?=\s|$)"#,
            with: "$1$2",
            options: .regularExpression
        )
    }

    /// Текст содержит markdown-разметку — источник хранит её как символы,
    /// и возвращать HTML в буфер нельзя.
    private func looksLikeMarkdown(_ text: String) -> Bool {
        let patterns = [
            #"\*\*[^*\n]+\*\*"#,   // **жирный**
            #"__[^_\n]+__"#,       // __жирный__
            #"~~[^~\n]+~~"#,       // ~~зачёркнутый~~
            #"`[^`\n]+`"#,         // `код`
            #"(?m)^#{1,6} "#       // # заголовок
        ]
        return patterns.contains { text.range(of: $0, options: .regularExpression) != nil }
    }

    // MARK: - Pasteboard

    private func snapshot(of pasteboard: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        (pasteboard.pasteboardItems ?? []).map { item in
            var copy: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy[type] = data
                }
            }
            return copy
        }
    }

    private func restore(_ pasteboard: NSPasteboard, from snapshot: [[NSPasteboard.PasteboardType: Data]]) {
        pasteboard.clearContents()
        guard !snapshot.isEmpty else { return }
        let items = snapshot.map { entry -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in entry {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(items)
    }

    private func waitForChange(
        of pasteboard: NSPasteboard,
        baseline: Int,
        deadline: Date,
        completion: @escaping (Bool) -> Void
    ) {
        if pasteboard.changeCount != baseline {
            completion(true)
            return
        }
        if Date() > deadline {
            completion(false)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            self.waitForChange(of: pasteboard, baseline: baseline, deadline: deadline, completion: completion)
        }
    }

    // MARK: - Keystrokes

    private func postKeystroke(keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .combinedSessionState)
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else { return }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
