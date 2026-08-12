import AppKit
import SwiftUI

/// Окно настроек в классическом стиле macOS:
/// вкладки — иконки с подписями в тулбаре (NSTabViewController .toolbar).
final class SettingsWindowController: NSWindowController {

    convenience init() {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar

        tabs.addTabViewItem(Self.makeTab(
            title: "Основные",
            symbol: "gearshape",
            view: GeneralSettingsView(),
            height: 465
        ))
        tabs.addTabViewItem(Self.makeTab(
            title: "Правила",
            symbol: "text.badge.checkmark",
            view: RulesSettingsView(),
            height: 540
        ))
        tabs.addTabViewItem(Self.makeTab(
            title: "О программе",
            symbol: "info.circle",
            view: AboutSettingsView(),
            height: 490
        ))

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.title = "Типограф"
        window.isReleasedWhenClosed = false
        // Окно приходит на текущий рабочий стол, а не утаскивает на тот, где было открыто.
        window.collectionBehavior = [.moveToActiveSpace]
        window.center()

        self.init(window: window)
    }

    private static func makeTab(
        title: String,
        symbol: String,
        view: some View,
        height: CGFloat
    ) -> NSTabViewItem {
        let controller = NSHostingController(
            rootView: AnyView(view.frame(width: 480, height: height))
        )
        controller.title = title
        let item = NSTabViewItem(viewController: controller)
        item.label = title
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        return item
    }
}
