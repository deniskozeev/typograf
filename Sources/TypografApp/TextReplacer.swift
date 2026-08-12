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
                  let text = pasteboard.string(forType: .string),
                  !text.isEmpty,
                  let processed = TypografEngine.shared.process(text) else {
                self.restore(pasteboard, from: saved)
                self.busy = false
                return
            }

            guard processed != text else {
                // Текст уже типографирован — менять нечего.
                self.restore(pasteboard, from: saved)
                self.busy = false
                self.confirm()
                return
            }

            pasteboard.clearContents()
            pasteboard.setString(processed, forType: .string)
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
