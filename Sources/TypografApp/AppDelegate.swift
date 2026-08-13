import AppKit
import SwiftUI
import Combine
import Sparkle

final class AppDelegate: NSObject, NSApplicationDelegate {

    /// Автообновления Sparkle: фид задан в Info.plist (SUFeedURL).
    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    private var statusItem: NSStatusItem?
    private var settingsWindowController: SettingsWindowController?
    private var cancellables = Set<AnyCancellable>()
    private var badgeView: NSImageView?
    private var badgeReset: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        BrandFont.register()
        TypografEngine.shared.warmUp()

        setUpStatusItem()
        setUpHotkey()
        observePreferences()

        // Без Accessibility приложение не работает — сразу показываем настройки.
        if !AccessibilityHelper.isTrusted {
            openSettings()
            AccessibilityHelper.promptAndOpenSettings()
        }
    }

    /// Повторное открытие Typograf.app (например, из Finder или Launchpad) показывает
    /// настройки — единственный путь к ним, когда иконка в менюбаре скрыта.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return false
    }

    // MARK: - Status item

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = BrandFont.statusBarIcon()
            button.toolTip = "Типограф — \(Preferences.shared.hotkeyDisplay)"
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        item.isVisible = Preferences.shared.showStatusIcon
        statusItem = item
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showStatusMenu()
        } else {
            toggleSettings()
        }
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Настройки…", action: #selector(openSettingsAction), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "Проверить обновления…", action: #selector(checkForUpdates), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Завершить Типограф", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil // иначе меню перехватит и левый клик
    }

    @objc private func openSettingsAction() {
        openSettings()
    }

    @objc func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    /// Подтверждение типографирования: зелёная точка в углу иконки менюбара,
    /// плавно появляется и растворяется.
    func showConfirmationBadge() {
        guard let button = statusItem?.button else { return }
        badgeReset?.cancel()

        let badge = ensureBadgeView(in: button)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            badge.animator().alphaValue = 1
        }

        let reset = DispatchWorkItem { [weak badge] in
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.55
                badge?.animator().alphaValue = 0
            }
        }
        badgeReset = reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: reset)
    }

    private func ensureBadgeView(in button: NSStatusBarButton) -> NSImageView {
        let badge: NSImageView
        if let existing = badgeView, existing.superview === button {
            badge = existing
        } else {
            badge = NSImageView(image: BrandFont.badgeDot())
            badge.alphaValue = 0
            button.addSubview(badge)
            badgeView = badge
        }
        // Позиция из макета: центр точки в (14.5, 1.5) от левого верхнего угла иконки 16×16.
        let bounds = button.bounds
        let x = bounds.midX - 8 + 11.5
        let y = button.isFlipped ? (bounds.midY - 8 - 1.5) : (bounds.midY + 8 - 4.5)
        badge.frame = NSRect(x: x, y: y, width: 6, height: 6)
        return badge
    }

    // MARK: - Settings window

    /// Клик по иконке работает как переключатель: окно на переднем плане — закрываем,
    /// иначе открываем/выводим вперёд.
    private func toggleSettings() {
        if let window = settingsWindowController?.window, window.isVisible, window.isKeyWindow {
            window.close()
        } else {
            openSettings()
        }
    }

    func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Hotkey

    private func setUpHotkey() {
        HotkeyManager.shared.handler = {
            TextReplacer.shared.typografSelection()
        }
        registerHotkeyFromPreferences()
    }

    private func registerHotkeyFromPreferences() {
        let prefs = Preferences.shared
        HotkeyManager.shared.register(
            keyCode: prefs.hotkeyKeyCode,
            carbonModifiers: prefs.hotkeyModifiers
        )
        statusItem?.button?.toolTip = "Типограф — \(prefs.hotkeyDisplay)"
    }

    private func observePreferences() {
        let prefs = Preferences.shared
        prefs.$hotkeyKeyCode
            .combineLatest(prefs.$hotkeyModifiers)
            .dropFirst()
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.registerHotkeyFromPreferences()
            }
            .store(in: &cancellables)

        prefs.$showStatusIcon
            .dropFirst()
            .sink { [weak self] visible in
                self?.statusItem?.isVisible = visible
            }
            .store(in: &cancellables)

        var lastOverrides = prefs.ruleOverrides
        prefs.$ruleOverrides
            .dropFirst()
            .sink { overrides in
                TypografEngine.shared.applyChanges(from: lastOverrides, to: overrides)
                lastOverrides = overrides
            }
            .store(in: &cancellables)
    }
}
