import Foundation
import AppKit
import Combine
import AgentDotCore

enum AggregateVisualState: Equatable {
    case waitingUnacknowledged
    case waitingAcknowledged
    case error
    case running
    case done
    case idle
}

final class HUDViewModel: ObservableObject {
    @Published var sessions: [SessionState]
    @Published var expanded: Bool = false
    @Published var config: AppConfig
    @Published var acknowledgedSessionIDs: Set<String> = []
    @Published var settingsStatus: String = ""
    @Published var hooksInstalled: Bool = true
    @Published var jumpStatus: String?
    @Published var jumpStatusDetail: String = ""
    @Published var updateState: UpdateState = .idle
    @Published var needsInstall = false
    @Published var installStatus: String = ""
    @Published var justUpdated = false
    @Published var updateNoticeVersion: String?

    var onManualUpdateMessage: ((String) -> Void)?

    let isDemo: Bool
    private var cancellables = Set<AnyCancellable>()
    private weak var sessionStore: SessionStore?
    private weak var updateService: UpdateService?
    private var reminderScheduler = SessionReminderScheduler()
    private let soundPlayer = SystemSoundPlayer()

    init(config: AppConfig, demo: Bool = false) {
        self.config = config
        self.isDemo = demo
        self.sessions = demo ? Self.demoSessions() : []
    }

    var sortedSessions: [SessionState] {
        sessions.sorted { lhs, rhs in
            let left = sortRank(lhs)
            let right = sortRank(rhs)
            if left != right { return left < right }
            return lhs.lastActivityAt > rhs.lastActivityAt
        }
    }

    var unacknowledgedWaitingCount: Int {
        sessions.filter {
            $0.state == .waitingPermission && !acknowledgedSessionIDs.contains($0.sessionID)
        }.count
    }

    var acknowledgedWaitingCount: Int {
        sessions.filter {
            $0.state == .waitingPermission && acknowledgedSessionIDs.contains($0.sessionID)
        }.count
    }

    var aggregate: AggregateVisualState {
        if unacknowledgedWaitingCount > 0 { return .waitingUnacknowledged }
        if acknowledgedWaitingCount > 0 { return .waitingAcknowledged }
        if sessions.contains(where: { $0.state == .error }) { return .error }
        if sessions.contains(where: { $0.state == .running }) { return .running }
        if sessions.contains(where: { $0.state == .done }) { return .done }
        return .idle
    }

    func bind(to store: SessionStore) {
        sessionStore = store
        store.$visibleSessions
            .receive(on: RunLoop.main)
            .sink { [weak self] sessions in
                self?.sessions = sessions
            }
            .store(in: &cancellables)
        store.$acknowledgedSessionIDs
            .receive(on: RunLoop.main)
            .sink { [weak self] ids in
                self?.acknowledgedSessionIDs = ids
            }
            .store(in: &cancellables)
        store.$visibleSessions
            .combineLatest(store.$acknowledgedSessionIDs)
            .receive(on: RunLoop.main)
            .sink { [weak self] sessions, acknowledgedIDs in
                self?.processSoundReminders(
                    sessions: sessions,
                    acknowledgedIDs: acknowledgedIDs
                )
            }
            .store(in: &cancellables)
    }

    private func processSoundReminders(
        sessions: [SessionState],
        acknowledgedIDs: Set<String>
    ) {
        guard !isDemo else { return }
        let events = reminderScheduler.update(
            sessions: sessions,
            acknowledgedSessionIDs: acknowledgedIDs,
            authorizationEnabled: config.authorizationSoundEnabled,
            completionEnabled: config.completionSoundEnabled,
            now: Int64(Date().timeIntervalSince1970)
        )
        for event in events {
            switch event {
            case .authorization:
                soundPlayer.play(
                    name: config.authorizationSoundName,
                    kind: "authorization"
                )
            case .completion:
                soundPlayer.play(
                    name: config.completionSoundName,
                    kind: "completion"
                )
            }
        }
    }

    func acknowledge(sessionID: String) {
        acknowledgedSessionIDs.insert(sessionID)
        sessionStore?.acknowledge(sessionID: sessionID)
    }

    func clearAcknowledgment(sessionID: String) {
        acknowledgedSessionIDs.remove(sessionID)
        sessionStore?.clearAcknowledgment(sessionID: sessionID)
    }

    func bind(to updateService: UpdateService) {
        self.updateService = updateService
        updateService.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.updateState = state
            }
            .store(in: &cancellables)
    }

    var currentVersionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? "0.0.0-dev"
    }

    var updateStatusText: String {
        switch updateState {
        case .idle:
            return ""
        case .checking:
            return "正在检查更新…"
        case .upToDate:
            return "已是最新版本"
        case .available(let manifest):
            return "新版本 \(manifest.version) 可用"
        case .downloading(let progress):
            return "下载更新 \(Int(progress * 100))%"
        case .verifying:
            return "正在校验更新…"
        case .installing:
            return "正在安装，应用将重启…"
        case .failed(let message):
            return message
        }
    }

    func checkForUpdates(manual: Bool) {
        updateService?.check(manual: manual) { [weak self] message in
            if manual {
                self?.onManualUpdateMessage?(message)
            }
        }
    }

    func upgradeUpdate() {
        updateService?.upgrade()
    }

    func skipUpdate(version: String) {
        updateService?.skip(version: version)
    }

    func setAutomaticUpdateChecks(_ enabled: Bool) {
        updateService?.setAutomaticChecks(enabled)
    }

    func installToUserApplications() {
        do {
            let target = try AppInstaller.installToUserApplications()
            installStatus = "已安装，正在重启…"
            AppInstaller.relaunch(target)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                NSApp.terminate(nil)
            }
        } catch {
            installStatus = "安装失败：\(error)"
        }
    }

    func updateConfig(_ config: AppConfig) {
        self.config = config.clamped()
    }

    func repairHooks() {
        do {
            try HookInstaller.installHelperIfNeeded()
            let report = try HookInstaller.ensureHooks()
            hooksInstalled = true
            let backup = report.backupURL.map { "；备份：\($0.path)" } ?? ""
            settingsStatus = "Hooks 已安装（\(report.eventsInstalled.count) 个事件）\(backup)"
        } catch {
            hooksInstalled = false
            settingsStatus = "修复失败：\(error)"
        }
    }

    private func sortRank(_ session: SessionState) -> Int {
        switch session.state {
        case .waitingPermission:
            return acknowledgedSessionIDs.contains(session.sessionID) ? 1 : 0
        case .error:
            return 2
        case .running:
            return 3
        case .done:
            return 4
        case .idle:
            return 5
        case .ended:
            return 6
        }
    }

    static func demoSessions() -> [SessionState] {
        let now = Int64(Date().timeIntervalSince1970)
        return [
            demo(
                id: "demo-waiting",
                project: "datagrip",
                app: .iTerm2,
                state: .waitingPermission,
                tool: "Bash",
                turnStartedAt: now - 600,
                waitingSince: now - 30
            ),
            demo(
                id: "demo-running-1",
                project: "xbo-product",
                app: .kaku,
                state: .running,
                tool: "Edit",
                turnStartedAt: now - 420
            ),
            demo(
                id: "demo-running-2",
                project: "agent-dot",
                app: .ghostty,
                state: .running,
                tool: "Bash",
                turnStartedAt: now - 180
            ),
            demo(
                id: "demo-done",
                project: "周报",
                app: .terminal,
                state: .done,
                tool: nil,
                turnStartedAt: now - 300,
                turnEndedAt: now - 60
            ),
            demo(
                id: "demo-error",
                project: "legacy-api",
                app: .iTerm2,
                state: .error,
                tool: nil,
                turnStartedAt: now - 240,
                turnEndedAt: now - 120,
                errorKind: "rate_limit"
            ),
            demo(
                id: "demo-idle",
                project: "notes",
                app: .kaku,
                state: .idle,
                tool: nil,
                turnStartedAt: nil
            )
        ]
    }

    private static func demo(
        id: String,
        project: String,
        app: TerminalApp,
        state: SessionPhase,
        tool: String?,
        turnStartedAt: Int64?,
        turnEndedAt: Int64? = nil,
        waitingSince: Int64? = nil,
        errorKind: String? = nil
    ) -> SessionState {
        let now = Int64(Date().timeIntervalSince1970)
        return SessionState(
            schema: 1,
            sessionID: id,
            cwd: "/Users/larry/webroot/\(project)",
            projectName: project,
            state: state,
            currentTool: tool,
            notificationType: state == .waitingPermission ? "permission_prompt" : nil,
            errorKind: errorKind,
            startedAt: now - 900,
            updatedAt: now,
            lastActivityAt: now,
            turnStartedAt: turnStartedAt,
            turnEndedAt: turnEndedAt,
            waitingSince: waitingSince,
            terminal: TerminalContext(app: app)
        )
    }
}
