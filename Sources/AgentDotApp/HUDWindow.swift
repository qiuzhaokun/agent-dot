import AppKit
import SwiftUI
import Combine
import AgentDotCore

final class HUDWindow: NSObject, NSWindowDelegate {
    private let panel: NSPanel
    private let viewModel: HUDViewModel
    private let configStore: ConfigStore
    private var cancellables = Set<AnyCancellable>()
    private var moveWorkItem: DispatchWorkItem?
    private var screenObserver: NSObjectProtocol?

    init(
        viewModel: HUDViewModel,
        configStore: ConfigStore,
        onOpenSettings: @escaping () -> Void,
        onJump: @escaping (SessionState) -> Void
    ) {
        self.viewModel = viewModel
        self.configStore = configStore
        self.panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 56, height: 56),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.level = .statusBar
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.worksWhenModal = true
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.restorePosition()
        }

        let root = HUDView(
            viewModel: viewModel,
            onOpenSettings: onOpenSettings,
            onJump: onJump
        )
        panel.contentView = NSHostingView(rootView: root)
        panel.setFrame(
            NSRect(origin: .zero, size: desiredSize(expanded: viewModel.expanded)),
            display: false
        )
        bind()
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    func show() {
        restorePosition()
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    var isVisible: Bool {
        panel.isVisible
    }

    private func bind() {
        viewModel.$expanded
            .receive(on: RunLoop.main)
            .sink { [weak self] expanded in
                self?.resize(expanded: expanded)
            }
            .store(in: &cancellables)

        viewModel.$sessions
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.viewModel.expanded else { return }
                self.resize(expanded: true)
            }
            .store(in: &cancellables)

        viewModel.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.viewModel.expanded else { return }
                self.resize(expanded: true)
            }
            .store(in: &cancellables)
    }

    private func desiredSize(expanded: Bool) -> NSSize {
        guard expanded else {
            return NSSize(width: 56, height: 56)
        }
        let rows = CGFloat(min(max(viewModel.sessions.count, 1), 6))
        let hooksBanner: CGFloat = viewModel.hooksInstalled ? 0 : 30
        let jumpBanner: CGFloat = viewModel.jumpStatus == nil ? 0 : 40
        var extraBanner: CGFloat = 0
        if viewModel.needsInstall {
            extraBanner += viewModel.installStatus.isEmpty ? 44 : 58
        }
        if viewModel.justUpdated {
            extraBanner += 52
        }
        switch viewModel.updateState {
        case .checking, .available, .verifying, .installing, .failed:
            extraBanner += 44
        case .downloading:
            extraBanner += 52
        case .idle, .upToDate:
            break
        }
        let bodyHeight: CGFloat = viewModel.sessions.isEmpty ? 150 : rows * 64
        let contentHeight: CGFloat =
            44 + hooksBanner + jumpBanner + extraBanner + bodyHeight + 16
        let height = min(CGFloat(440), contentHeight)
        return NSSize(width: 340, height: height)
    }

    private func resize(expanded: Bool) {
        let old = panel.frame
        let size = desiredSize(expanded: expanded)
        if abs(old.width - size.width) < 0.5,
           abs(old.height - size.height) < 0.5 {
            return
        }
        var frame = NSRect(
            x: old.maxX - size.width,
            y: old.maxY - size.height,
            width: size.width,
            height: size.height
        )
        if let screen = panel.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            frame.origin.x = min(max(frame.origin.x, visible.minX), visible.maxX - size.width)
            frame.origin.y = min(max(frame.origin.y, visible.minY), visible.maxY - size.height)
        }
        panel.setFrame(frame, display: true, animate: true)
    }

    private func restorePosition() {
        let size = desiredSize(expanded: viewModel.expanded)
        let screen = screenForAnchor() ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let visible = screen.visibleFrame
        var origin: NSPoint

        if let anchor = viewModel.config.ballAnchor {
            let centerX = visible.minX + anchor.normalizedX * visible.width
            let centerY = visible.minY + anchor.normalizedY * visible.height
            origin = NSPoint(x: centerX - size.width / 2, y: centerY - size.height / 2)
        } else {
            origin = NSPoint(
                x: visible.maxX - size.width - 24,
                y: visible.maxY - size.height - 24
            )
        }

        origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
        origin.y = min(max(origin.y, visible.minY), visible.maxY - size.height)
        panel.setFrame(NSRect(origin: origin, size: size), display: false)
    }

    private func screenForAnchor() -> NSScreen? {
        guard let anchor = viewModel.config.ballAnchor,
              let screenID = anchor.screenID else {
            return nil
        }
        return NSScreen.screens.first { self.screenID($0) == screenID }
    }

    private func screenID(_ screen: NSScreen) -> String {
        let number = screen.deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")
        ] as? NSNumber
        return number?.stringValue ?? screen.localizedName
    }

    func windowDidMove(_ notification: Notification) {
        moveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.snapToEdgeIfNeeded()
            self.persistPosition()
        }
        moveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func snapToEdgeIfNeeded() {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        var frame = panel.frame
        var changed = false
        let threshold: CGFloat = 16

        if abs(frame.minX - visible.minX) < threshold {
            frame.origin.x = visible.minX
            changed = true
        }
        if abs(visible.maxX - frame.maxX) < threshold {
            frame.origin.x = visible.maxX - frame.width
            changed = true
        }
        if abs(frame.minY - visible.minY) < threshold {
            frame.origin.y = visible.minY
            changed = true
        }
        if abs(visible.maxY - frame.maxY) < threshold {
            frame.origin.y = visible.maxY - frame.height
            changed = true
        }

        if changed {
            panel.setFrame(frame, display: true, animate: true)
        }
    }

    private func persistPosition() {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        guard visible.width > 0, visible.height > 0 else { return }
        let frame = panel.frame
        let ballCenterX = frame.maxX - 28
        let ballCenterY = frame.maxY - 28
        var config = viewModel.config
        config.ballAnchor = BallAnchor(
            screenID: screenID(screen),
            normalizedX: (ballCenterX - visible.minX) / visible.width,
            normalizedY: (ballCenterY - visible.minY) / visible.height
        )
        viewModel.updateConfig(config)
        try? configStore.save(config)
    }
}
