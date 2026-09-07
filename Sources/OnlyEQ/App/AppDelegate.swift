import AppKit
import Combine
import Sparkle
import SwiftUI
import CoreAudio

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var menuPanel: MenuPanel!
    private var localMouseMonitor: Any?
    private var workspaceActivationObserver: NSObjectProtocol?
    private var hidePanelObserver: NSObjectProtocol?
    private var statusIconSubscription: AnyCancellable?
    private let appShortcutMonitor = AppShortcutMonitor()
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.write("app: didFinishLaunching")
        NSApp.setActivationPolicy(.accessory)
        appShortcutMonitor.start()

        let state = AppState.shared
        Log.write("app: state ready")

        let hosting = NSHostingController(
            rootView: PopoverView()
                .environmentObject(state)
                .background(PanelMaterial(cornerRadius: PopoverView.cornerRadius))
        )
        hosting.sizingOptions = .standardBounds
        menuPanel = MenuPanel(
            contentRect: NSRect(x: 0, y: 0, width: PopoverView.width, height: PopoverView.minHeight),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        menuPanel.contentViewController = hosting
        menuPanel.level = .popUpMenu
        menuPanel.isFloatingPanel = true
        menuPanel.hidesOnDeactivate = false
        menuPanel.isReleasedWhenClosed = false
        menuPanel.hasShadow = true
        menuPanel.isOpaque = false
        menuPanel.backgroundColor = .clear
        menuPanel.collectionBehavior = [.transient, .moveToActiveSpace, .fullScreenAuxiliary]
        hosting.view.wantsLayer = true
        hosting.view.layer?.cornerRadius = PopoverView.cornerRadius
        hosting.view.layer?.cornerCurve = .continuous
        hosting.view.layer?.masksToBounds = true
        Log.write("app: menu panel ready")

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        // The mark itself says whether the EQ is shaping sound: filled while
        // active, outlined while off or bypassed.
        statusIconSubscription = state.$isEnabled.combineLatest(state.$bypassed)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled, bypassed in
                self?.updateStatusIcon(active: enabled && !bypassed)
            }
        Log.write("app: status item ready (visible: \(statusItem.isVisible))")
        installPanelDismissalObservers()

        if CommandLine.arguments.contains("--menu-panel-probe") {
            DispatchQueue.main.async { [weak self] in self?.togglePopover() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) { NSApp.terminate(nil) }
        }

        if CommandLine.arguments.contains("--accessory-import-probe") {
            DispatchQueue.main.async { WindowManager.shared.showEditor(importing: true) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) { NSApp.terminate(nil) }
        }

        // `--window-layout-probe`: open the editor and report the real title
        // bar geometry (the offscreen renderer fakes it), then quit.
        if CommandLine.arguments.contains("--window-layout-probe") {
            WindowManager.shared.showEditor()
            WindowManager.shared.showSettings()
            for window in NSApp.windows where !window.title.isEmpty {
                window.contentView?.layoutSubtreeIfNeeded()
                let titleBar = window.frame.height - window.contentLayoutRect.height
                let close = window.standardWindowButton(.closeButton)?.frame ?? .zero
                let items = window.toolbar?.items.map(\.itemIdentifier.rawValue) ?? []
                print("layout: \(window.title) titleBar=\(titleBar) close=\(close) frame=\(window.frame.size) toolbar=\(items)")
            }
            exit(0)
        }

        HotKeyManager.shared.install()

        if !UserDefaults.standard.bool(forKey: "onboarded") {
            WindowManager.shared.showOnboarding()
            Log.write("app: onboarding shown")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let localMouseMonitor { NSEvent.removeMonitor(localMouseMonitor) }
        if let workspaceActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceActivationObserver)
        }
        if let hidePanelObserver { NotificationCenter.default.removeObserver(hidePanelObserver) }
        appShortcutMonitor.stop()
        AppState.shared.flushWorkingPresetPersistence()
        AppState.shared.engine.stop()
    }

    // MARK: - Status item

    private func updateStatusIcon(active: Bool) {
        guard let button = statusItem.button else { return }
        let icon = NSImage(
            systemSymbolName: active ? OnlyEQIcon.symbolName : OnlyEQIcon.inactiveSymbolName,
            accessibilityDescription: active ? "OnlyEQ, active" : "OnlyEQ, off"
        )
        // Template rendering keeps the mark consistent in light/dark menu
        // bars and white-ish while the custom panel is highlighted open.
        icon?.isTemplate = true
        button.image = icon
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if menuPanel.isVisible {
            hideMenuPanel()
        } else {
            AppState.shared.refreshDevices()
            positionMenuPanel(below: button)
            NSApp.activate(ignoringOtherApps: true)
            menuPanel.makeKeyAndOrderFront(nil)
            button.highlight(true)
            // Reassert after the status button finishes its mouse-up tracking;
            // AppKit otherwise clears the pressed highlight when the action returns.
            DispatchQueue.main.async { [weak self, weak button] in
                guard let self, self.menuPanel.isVisible else { return }
                button?.highlight(true)
            }
            AppState.shared.popoverIsVisible = true
            Log.write("menu-panel: shown")
        }
    }

    private func installPanelDismissalObservers() {
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self, self.menuPanel.isVisible else { return event }
            let statusWindow = self.statusItem.button?.window
            if event.window !== self.menuPanel, event.window !== statusWindow {
                DispatchQueue.main.async { [weak self] in self?.hideMenuPanel() }
            }
            return event
        }

        // The panel activates this accessory app while open, so an outside
        // click is represented reliably by another workspace application
        // becoming active. A global mouse monitor is both redundant and unsafe:
        // status-item clicks are hosted out of process and appear there before
        // the button's mouse-up action, which can hide then immediately reopen.
        workspaceActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] notification in
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication
            guard application?.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
            Task { @MainActor in self?.hideMenuPanel() }
        }

        hidePanelObserver = NotificationCenter.default.addObserver(
            forName: .onlyEQHideMenuPanel,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.hideMenuPanel() }
        }
    }

    private func positionMenuPanel(below button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }
        let buttonInWindow = button.convert(button.bounds, to: nil)
        let buttonOnScreen = buttonWindow.convertToScreen(buttonInWindow)
        let screenFrame = buttonWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        // Larger system text makes the content taller; size the panel to it.
        if let content = menuPanel.contentViewController?.view {
            menuPanel.setContentSize(content.fittingSize)
        }
        let panelSize = menuPanel.frame.size
        let x = min(max(buttonOnScreen.midX - panelSize.width / 2, screenFrame.minX + 6),
                    screenFrame.maxX - panelSize.width - 6)
        let y = buttonOnScreen.minY - panelSize.height - 4
        menuPanel.setFrameOrigin(NSPoint(x: x, y: max(y, screenFrame.minY + 6)))
    }

    private func hideMenuPanel() {
        let wasVisible = menuPanel.isVisible
        statusItem.button?.highlight(false)
        if wasVisible { menuPanel.orderOut(nil) }
        AppState.shared.popoverIsVisible = false
        if wasVisible { Log.write("menu-panel: hidden") }
    }

    /// Right-click menu. Mirrors the gear menu in the popover so both entry
    /// points offer the same items.
    private func showContextMenu() {
        hideMenuPanel()
        let state = AppState.shared
        let menu = NSMenu()

        let enable = NSMenuItem(title: "Enable EQ", action: #selector(toggleEnabled), keyEquivalent: "")
        enable.target = self
        enable.state = state.isEnabled ? .on : .off
        menu.addItem(enable)
        menu.addItem(.separator())

        let editor = NSMenuItem(title: "Open Equalizer…", action: #selector(openEditor), keyEquivalent: "")
        editor.target = self
        menu.addItem(editor)
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let updates = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        updates.target = self
        menu.addItem(updates)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit OnlyEQ", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil  // restore click handling
    }

    // MARK: - Menu actions

    @objc private func toggleEnabled() { AppState.shared.isEnabled.toggle() }
    @objc private func openEditor() { WindowManager.shared.showEditor() }
    @objc private func openSettings() { WindowManager.shared.showSettings() }
    @objc func checkForUpdates() { updaterController.checkForUpdates(nil) }
}

extension Notification.Name {
    /// Posted by anything that wants the menu panel gone: opening a window,
    /// or Escape inside the popover.
    static let onlyEQHideMenuPanel = Notification.Name("OnlyEQ.HideMenuPanel")
}

/// Borderless AppKit windows do not normally become key. This tiny subclass
/// gives the arrowless menu panel normal control focus and active appearance.
private final class MenuPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Owns the editor, settings, and onboarding windows.
@MainActor
final class WindowManager {
    static let shared = WindowManager()

    private var editorWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    func showEditor(importing: Bool = false, profileSuggestion: ProfileSuggestion? = nil) {
        let isCreatingWindow = editorWindow == nil
        if editorWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 840, height: 560),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false
            )
            window.title = "Equalizer"
            window.minSize = NSSize(width: 720, height: 480)
            window.isReleasedWhenClosed = false
            // EditorView supplies the toolbar items; the preset menu stands
            // where a document title would, so the title itself stays hidden.
            window.toolbarStyle = .unified
            window.titleVisibility = .hidden
            let hosting = NSHostingController(
                rootView: EditorView(initialImportRequested: importing,
                                     initialProfileSuggestion: profileSuggestion)
                    .environmentObject(AppState.shared)
            )
            window.contentViewController = hosting
            // Restore the saved frame if there is one; otherwise center.
            if !window.setFrameUsingName("EditorWindow") { window.center() }
            window.setFrameAutosaveName("EditorWindow")
            // The window survives close (isReleasedWhenClosed = false, just
            // ordered out), so EditorView gates its spectrum/clip refresh work
            // on real visibility. Occlusion state also covers "fully covered
            // by another window" and "on another Space", not just close.
            NotificationCenter.default.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification,
                object: window, queue: .main
            ) { note in
                guard let window = note.object as? NSWindow else { return }
                let visible = window.occlusionState.contains(.visible)
                Task { @MainActor in AppState.shared.editorIsVisible = visible }
            }
            editorWindow = window
        }
        if let editorWindow { focus(editorWindow) }
        if importing, !isCreatingWindow {
            EditorView.importRequested.send(profileSuggestion)
        }
    }

    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: SettingsPage.width, height: 420),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered, defer: false
            )
            window.title = "Settings"
            window.isReleasedWhenClosed = false
            // Toolbar-style tabs, as System Settings and every Mac app's
            // settings window draw them; the window resizes to each page.
            let tabs = NSTabViewController()
            tabs.tabStyle = .toolbar
            for page in SettingsPage.allCases {
                let hosting = NSHostingController(
                    rootView: page.view
                        .environmentObject(AppState.shared)
                        .frame(width: SettingsPage.width)
                )
                hosting.sizingOptions = .preferredContentSize
                let item = NSTabViewItem(viewController: hosting)
                item.label = page.title
                item.image = NSImage(systemSymbolName: page.symbol, accessibilityDescription: page.title)
                tabs.addTabViewItem(item)
            }
            window.contentViewController = tabs
            if !window.setFrameUsingName("SettingsWindow") { window.center() }
            window.setFrameAutosaveName("SettingsWindow")
            settingsWindow = window
        }
        if let settingsWindow { focus(settingsWindow) }
    }

    /// Deleting a stored preset has no undo, so it asks first. Called from the
    /// preset menus in the popover and the editor.
    func confirmDeletePreset(_ preset: EQPreset) {
        let alert = NSAlert()
        alert.messageText = "Delete “\(preset.name)”?"
        alert.informativeText = "The preset is removed from this Mac. Devices set to it fall back to no preset."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        AppState.shared.store.delete(preset)
    }

    func showOnboarding() {
        if onboardingWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: OnboardingView.width, height: OnboardingView.height),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered, defer: false
            )
            window.title = "Welcome to OnlyEQ"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isReleasedWhenClosed = false
            let hosting = NSHostingController(
                rootView: OnboardingView().environmentObject(AppState.shared)
                    .ignoresSafeArea(.container, edges: .top)
            )
            // Fixed width; the height follows the system text size.
            hosting.sizingOptions = .preferredContentSize
            window.contentViewController = hosting
            window.center()
            onboardingWindow = window
        }
        if let onboardingWindow { focus(onboardingWindow) }
    }

    func closeOnboarding() {
        onboardingWindow?.close()
    }

    /// Accessory/menu-bar apps must activate before asking a window to become
    /// key. Retry on the next run-loop turn because a closing transient popover
    /// can otherwise return focus to the previous application.
    private func focus(_ window: NSWindow) {
        NotificationCenter.default.post(name: .onlyEQHideMenuPanel, object: nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { [weak window] in
            guard let window, window.isVisible else { return }
            if !NSApp.isActive || !window.isKeyWindow {
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
}
