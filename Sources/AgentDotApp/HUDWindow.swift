import AppKit
import SwiftUI
import Combine
import AgentDotCore

/// 让无边框面板支持自由拖动。
/// NSHostingView 会接管鼠标事件，`isMovableByWindowBackground` 对 SwiftUI 内容不生效，
/// 因此这里用拖拽过程中的全局鼠标位置手动移动窗口。
final class WindowDragController {
    private weak var panel: NSWindow?
    private var startMouse: NSPoint?
    private var startOrigin: NSPoint?
    private(set) var totalDistance: CGFloat = 0

    init(panel: NSWindow) {
        self.panel = panel
    }

    func begin() {
        guard let panel else { return }
        startMouse = NSEvent.mouseLocation
        startOrigin = panel.frame.origin
        totalDistance = 0
    }

    func update() {
        guard let panel, let startMouse, let startOrigin else { return }
        let mouse = NSEvent.mouseLocation
        panel.setFrameOrigin(
            NSPoint(
                x: startOrigin.x + mouse.x - startMouse.x,
                y: startOrigin.y + mouse.y - startMouse.y
            )
        )
        totalDistance = max(totalDistance, hypot(mouse.x - startMouse.x, mouse.y - startMouse.y))
    }

    func end() {
        startMouse = nil
        startOrigin = nil
    }
}

/// 拖拽展开面板底边调整列表区域高度；面板顶部保持不动。
final class ListResizeController {
    private weak var panel: NSWindow?
    var listHeightProvider: (() -> CGFloat)?
    var chromeHeightProvider: (() -> CGFloat)?
    var maxTotalHeightProvider: (() -> CGFloat)?
    var onLiveChange: ((CGFloat) -> Void)?
    /// 拖拽真正改变高度后才回调新高度；只是点击手柄时回调 nil。
    var onCommit: ((CGFloat?) -> Void)?

    private var startMouseY: CGFloat?
    private var startTop: CGFloat = 0
    private var startListHeight: CGFloat = 0
    private var chromeHeight: CGFloat = 0
    private var maxTotalHeight: CGFloat = 0
    private var didResize = false
    private(set) var currentListHeight: CGFloat = 0

    init(panel: NSWindow) {
        self.panel = panel
    }

    func begin() {
        guard let panel,
              let listHeight = listHeightProvider?(),
              let chrome = chromeHeightProvider?() else {
            return
        }
        startMouseY = NSEvent.mouseLocation.y
        startTop = panel.frame.maxY
        startListHeight = listHeight
        chromeHeight = chrome
        maxTotalHeight = maxTotalHeightProvider?() ?? 900
        if let screen = panel.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            maxTotalHeight = min(
                maxTotalHeight,
                max(240, startTop - visible.minY - 8)
            )
        }
        currentListHeight = listHeight
        didResize = false
        onLiveChange?(listHeight)
    }

    func update() {
        guard let panel, let startMouseY else { return }
        let mouseY = NSEvent.mouseLocation.y
        let minHeight = CGFloat(AppConfig.minListHeight)
        let maxHeight = CGFloat(AppConfig.maxListHeight)
        var height = startListHeight + (startMouseY - mouseY)
        height = min(max(height.rounded(), minHeight), maxHeight)
        let available = maxTotalHeight - chromeHeight
        if available >= minHeight {
            height = min(height, available)
        }
        if abs(height - startListHeight) > 0.5 {
            didResize = true
        }
        currentListHeight = height
        onLiveChange?(height)
        let total = chromeHeight + height
        panel.setFrame(
            NSRect(
                x: panel.frame.minX,
                y: startTop - total,
                width: panel.frame.width,
                height: total
            ),
            display: true
        )
    }

    func end() {
        guard startMouseY != nil else { return }
        startMouseY = nil
        onCommit?(didResize ? currentListHeight : nil)
    }
}

final class HUDWindow: NSObject, NSWindowDelegate {
    private enum Layout {
        static let collapsedSize: CGFloat = 56
        static let panelWidth: CGFloat = 340
        static let headerHeight: CGFloat = 44
        static let panelPadding: CGFloat = 16
        static let emptyListHeight: CGFloat = 150
        static let resizeHandleHeight: CGFloat = 10
    }

    private let panel: NSPanel
    private let viewModel: HUDViewModel
    private let configStore: ConfigStore
    private let dragController: WindowDragController
    private let listResizeController: ListResizeController
    private var liveListHeight: CGFloat?
    private var isResizingListHeight = false
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
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 56, height: 56),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.panel = panel
        self.dragController = WindowDragController(panel: panel)
        self.listResizeController = ListResizeController(panel: panel)
        super.init()
        wireResizeController()

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
            dragController: dragController,
            listResizeController: listResizeController,
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

    private func wireResizeController() {
        listResizeController.listHeightProvider = { [weak self] in
            self?.currentListHeight ?? 0
        }
        listResizeController.chromeHeightProvider = { [weak self] in
            self?.chromeHeight() ?? 0
        }
        listResizeController.maxTotalHeightProvider = { [weak self] in
            self?.maxPanelHeight() ?? 900
        }
        listResizeController.onLiveChange = { [weak self] height in
            guard let self else { return }
            self.liveListHeight = height
            self.isResizingListHeight = true
        }
        listResizeController.onCommit = { [weak self] height in
            guard let self else { return }
            guard let height else {
                self.liveListHeight = nil
                self.resize(expanded: true)
                self.isResizingListHeight = false
                return
            }
            self.liveListHeight = height
            var config = self.viewModel.config
            config.expandedListHeight = Double(height)
            self.viewModel.updateConfig(config)
            try? self.configStore.save(config)
            self.liveListHeight = nil
            self.resize(expanded: true)
            self.isResizingListHeight = false
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

    /// 头部、横幅、拖拽手柄和内边距占用的固定高度。
    private func chromeHeight() -> CGFloat {
        var height = Layout.headerHeight + Layout.panelPadding
        if !viewModel.hooksInstalled {
            height += 30
        }
        if viewModel.jumpStatus != nil {
            height += 40
        }
        if viewModel.needsInstall {
            height += viewModel.installStatus.isEmpty ? 44 : 58
        }
        if viewModel.justUpdated {
            height += 52
        }
        switch viewModel.updateState {
        case .checking, .available, .verifying, .installing, .failed:
            height += 44
        case .downloading:
            height += 52
        case .idle, .upToDate:
            break
        }
        if !viewModel.sessions.isEmpty {
            height += Layout.resizeHandleHeight
        }
        return height
    }

    /// 展开面板中列表区域的高度（不含拖拽手柄、头部和横幅）。
    private var currentListHeight: CGFloat {
        let minHeight = CGFloat(AppConfig.minListHeight)
        let maxHeight = CGFloat(AppConfig.maxListHeight)
        let height: CGFloat
        if let liveListHeight {
            height = liveListHeight
        } else if let saved = viewModel.config.expandedListHeight {
            height = CGFloat(saved)
        } else {
            let rows = min(max(viewModel.sessions.count, 1), 5)
            height = CGFloat(rows) * CGFloat(AppConfig.listRowHeight)
        }
        let screenMax = max(
            minHeight,
            maxPanelHeight() - chromeHeight()
        )
        return min(max(height, minHeight), min(maxHeight, screenMax))
    }

    private func maxPanelHeight() -> CGFloat {
        let screen = panel.screen ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return 900 }
        return max(240, visible.height - 40)
    }

    private func desiredSize(expanded: Bool) -> NSSize {
        guard expanded else {
            return NSSize(
                width: Layout.collapsedSize,
                height: Layout.collapsedSize
            )
        }
        let listHeight: CGFloat = viewModel.sessions.isEmpty
            ? Layout.emptyListHeight
            : currentListHeight
        let height = min(chromeHeight() + listHeight, maxPanelHeight())
        return NSSize(width: Layout.panelWidth, height: height)
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
        guard !isResizingListHeight else { return }
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
