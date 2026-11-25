import AppKit
import SwiftUI
import AgentDotCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hudWindow: HUDWindow?
    private var viewModel: HUDViewModel?
    private var configStore: ConfigStore?
    private var sessionStore: SessionStore?
    private var updateService: UpdateService?
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private let jumpQueue = DispatchQueue(
        label: "dev.agentdot.jump",
        qos: .userInitiated
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        try? AgentDotPaths.ensureDirectories()
        AppInstaller.cleanupLegacyBackups()
        let store = ConfigStore(fileURL: AgentDotPaths.configURL)
        let demo = CommandLine.arguments.contains("--demo")
        var config = store.load()
        let loginEnabled = LaunchAtLogin.isEnabled()
        config.launchAtLogin = loginEnabled
        if loginEnabled,
           Bundle.main.bundleURL.pathExtension == "app",
           !LaunchAtLogin.isEnabled(for: Bundle.main.bundleURL) {
            try? LaunchAtLogin.enable(appPath: Bundle.main.bundleURL)
        }
        let model = HUDViewModel(config: config, demo: demo)
        if !demo,
           let version = Bundle.main.infoDictionary?[
               "CFBundleShortVersionString"
           ] as? String {
            if let last = model.config.lastLaunchedVersion, last != version {
                model.justUpdated = true
                model.updateNoticeVersion = version
            }
            if model.config.lastLaunchedVersion != version {
                var updatedConfig = model.config
                updatedConfig.lastLaunchedVersion = version
                model.updateConfig(updatedConfig)
                try? store.save(updatedConfig)
            }
        }
        do {
            try HookInstaller.installHelperIfNeeded()
        } catch {
            // Running from `swift run` has no bundled helper; the panel banner handles it.
        }
        model.hooksInstalled = HookInstaller.isInstalled()
        let window = HUDWindow(
            viewModel: model,
            configStore: store,
            onOpenSettings: { [weak self] in self?.openSettings() },
            onJump: { [weak self] session in self?.jump(to: session) }
        )

        if !demo {
            let store = SessionStore(
                sessionsDirectory: AgentDotPaths.sessionsDirectory,
                uiStateURL: AgentDotPaths.uiStateURL
            )
            model.bind(to: store)
            store.start()
            sessionStore = store
        }

        let updater = UpdateService(configStore: store)
        model.bind(to: updater)
        model.onManualUpdateMessage = { [weak self] message in
            self?.showInfoAlert(message)
        }
        model.needsInstall = !demo && AppInstaller.shouldOfferInstall()
        if !demo && (model.needsInstall || !model.hooksInstalled || model.justUpdated) {
            model.expanded = true
        }
        updater.startAutomaticChecks()
        updateService = updater

        configStore = store
        viewModel = model
        hudWindow = window
        setupStatusItem()
        window.show()
    }

    func applicationWillTerminate(_ notification: Notification) {
        sessionStore?.stop()
        updateService?.stopAutomaticChecks()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "circle.grid.2x2",
            accessibilityDescription: "AgentDot"
        )
        item.button?.toolTip = "AgentDot"

        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(
                title: "显示/隐藏悬浮球",
                action: #selector(toggleVisibility),
                keyEquivalent: ""
            )
        )
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(
                title: "设置…",
                action: #selector(openSettings),
                keyEquivalent: ","
            )
        )
        menu.addItem(
            NSMenuItem(
                title: "检查更新…",
                action: #selector(checkForUpdates),
                keyEquivalent: ""
            )
        )
        menu.addItem(
            NSMenuItem(
                title: "修复 Hooks",
                action: #selector(repairHooks),
                keyEquivalent: ""
            )
        )
        menu.addItem(
            NSMenuItem(
                title: "打开状态目录",
                action: #selector(openStateDirectory),
                keyEquivalent: ""
            )
        )
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(
                title: "退出 AgentDot",
                action: #selector(quit),
                keyEquivalent: "q"
            )
        )
        for menuItem in menu.items where menuItem.action != nil {
            menuItem.target = self
        }
        item.menu = menu
        statusItem = item
    }

    @objc private func toggleVisibility() {
        guard let hudWindow else { return }
        if hudWindow.isVisible {
            hudWindow.hide()
        } else {
            hudWindow.show()
        }
    }

    @objc private func openSettings() {
        guard let viewModel, let configStore else { return }
        if let existing = settingsWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 444, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "AgentDot 设置"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: SettingsView(viewModel: viewModel, configStore: configStore)
        )
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    @objc private func repairHooks() {
        viewModel?.repairHooks()
    }

    @objc private func checkForUpdates() {
        viewModel?.checkForUpdates(manual: true)
    }

    private func showInfoAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "AgentDot 更新"
        alert.informativeText = message
        alert.alertStyle = .informational
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func jump(to session: SessionState) {
        viewModel?.jumpStatus = nil
        viewModel?.jumpStatusDetail = ""
        jumpQueue.async { [weak self] in
            let result = TerminalJumper().jump(to: session)
            DispatchQueue.main.async {
                self?.handleJumpResult(result, session: session)
            }
        }
    }

    private func handleJumpResult(_ result: JumpResult, session: SessionState) {
        switch result {
        case .success:
            viewModel?.jumpStatus = nil
            sessionStore?.probeNow()
        case .unsupported(let reason), .failed(let reason):
            viewModel?.jumpStatus = Self.jumpFailureMessage(reason)
            viewModel?.jumpStatusDetail = SessionRowView.terminalInfo(for: session)
            viewModel?.expanded = true
        }
    }

    private static func jumpFailureMessage(_ reason: String) -> String {
        let lower = reason.lowercased()
        if reason.contains("-1743")
            || lower.contains("not allowed")
            || lower.contains("not authorized")
            || lower.contains("not permitted") {
            return "无法跳转：请在「系统设置 → 隐私与安全性 → 自动化」中允许 AgentDot 控制该终端。"
        }
        return "无法跳转：\(reason)"
    }

    @objc private func openStateDirectory() {
        NSWorkspace.shared.open(AgentDotPaths.stateDirectory)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
