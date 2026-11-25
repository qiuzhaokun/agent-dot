import Foundation
import AppKit
import Combine
import AgentDotCore

final class SessionStore: ObservableObject {
    @Published private(set) var visibleSessions: [SessionState] = []
    @Published private(set) var acknowledgedSessionIDs: Set<String> = []

    private let fileStore: SessionFileStore
    private let uiStore: UIStateStore
    private let liveness: ProcessLivenessProviding
    private let probe: ActiveTerminalProbing
    private let nameResolver: SessionNameResolver
    private let pollInterval: TimeInterval

    private var timer: Timer?
    private var isRunning = false
    private var visibilityTracker = SessionVisibilityTracker()
    private var aliveCache: [String: Bool] = [:]
    private var alivePID: [String: Int32] = [:]
    private var lastAliveCheck: Int64 = 0
    private var lastSessionIDs: Set<String> = []
    private var lastProbeAt: Int64 = 0
    private var probeInFlight = false
    private let probeQueue = DispatchQueue(
        label: "dev.agentdot.probe",
        qos: .utility
    )

    init(
        sessionsDirectory: URL,
        uiStateURL: URL,
        pollInterval: TimeInterval = 0.5,
        liveness: ProcessLivenessProviding = LiveProcessLiveness(),
        probe: ActiveTerminalProbing = LiveActiveTerminalProbe(),
        nameResolver: SessionNameResolver = SessionNameResolver()
    ) {
        self.fileStore = SessionFileStore(directory: sessionsDirectory)
        self.uiStore = UIStateStore(fileURL: uiStateURL)
        self.pollInterval = pollInterval
        self.liveness = liveness
        self.probe = probe
        self.nameResolver = nameResolver
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true

        let now = Int64(Date().timeIntervalSince1970)
        fileStore.removeOlderThan(now - 7 * 86_400)
        fileStore.removeOrphanLocks()
        let existingIDs = Set(fileStore.loadAll().map { $0.sessionID })
        uiStore.prune(existingSessionIDs: existingIDs)

        tick()
        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    func acknowledge(sessionID: String) {
        let now = Int64(Date().timeIntervalSince1970)
        guard let session = fileStore.loadAll().first(where: {
            $0.sessionID == sessionID
        }), let waitingSince = session.waitingSince else {
            return
        }
        uiStore.acknowledge(
            sessionID: sessionID,
            at: now,
            waitingSince: waitingSince
        )
        tick()
    }

    func clearAcknowledgment(sessionID: String) {
        uiStore.clearAcknowledgment(sessionID: sessionID)
        tick()
    }

    func probeNow() {
        lastProbeAt = 0
        if !probeInFlight {
            tick()
        }
    }

    private func tick() {
        let now = Int64(Date().timeIntervalSince1970)
        let stored = fileStore.loadAll()
        let displayNames = nameResolver.resolveNames(for: stored)
        let all = stored.map { state -> SessionState in
            var copy = state
            copy.displayName = displayNames[state.sessionID]
            return copy
        }
        let ids = Set(all.map { $0.sessionID })
        let shouldCheckAlive = now - lastAliveCheck >= 5 || aliveCache.isEmpty
        if shouldCheckAlive {
            lastAliveCheck = now
        }

        var ui = uiStore.load()
        var clearedAck = false
        for state in all where state.state == .waitingPermission {
            guard let waitingSince = state.waitingSince else { continue }
            if let entry = ui.sessions[state.sessionID],
               entry.acknowledgedAt != nil,
               entry.waitingSinceAtAck != waitingSince {
                uiStore.clearAcknowledgment(sessionID: state.sessionID)
                clearedAck = true
            }
        }
        if clearedAck {
            ui = uiStore.load()
        }

        var visible: [SessionState] = []
        for state in all {
            let pid = state.terminal.claudePID
            if alivePID[state.sessionID] != pid {
                visibilityTracker.reset(sessionID: state.sessionID)
            }
            if shouldCheckAlive
                || aliveCache[state.sessionID] == nil
                || alivePID[state.sessionID] != pid {
                aliveCache[state.sessionID] = liveness.isAlive(
                    pid: pid,
                    expectedExecPath: state.terminal.claudeExecPath
                )
                alivePID[state.sessionID] = pid
            }

            let alive = aliveCache[state.sessionID] ?? false
            switch visibilityTracker.evaluate(
                state: state,
                now: now,
                isProcessAlive: alive
            ) {
            case .visible:
                visible.append(state)
            case .hidden:
                break
            }
        }

        visibilityTracker.prune(existingSessionIDs: ids)
        aliveCache = aliveCache.filter { ids.contains($0.key) }
        alivePID = alivePID.filter { ids.contains($0.key) }

        if ids != lastSessionIDs {
            uiStore.prune(existingSessionIDs: ids)
            lastSessionIDs = ids
            ui = uiStore.load()
        }

        acknowledgedSessionIDs = Set(
            all.filter { state in
                state.state == .waitingPermission
                    && AcknowledgmentStatePolicy.isAcknowledged(
                        session: state,
                        uiState: ui.sessions[state.sessionID]
                    )
            }.map { $0.sessionID }
        )
        visibleSessions = visible

        let unacknowledgedWaiting = visible.filter { state in
            state.state == .waitingPermission
                && state.terminal.app != .unknown
                && !AcknowledgmentStatePolicy.isAcknowledged(
                    session: state,
                    uiState: ui.sessions[state.sessionID]
                )
        }
        guard !unacknowledgedWaiting.isEmpty,
              now - lastProbeAt >= 1,
              !probeInFlight else {
            return
        }

        lastProbeAt = now
        probeInFlight = true
        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let grouped = Dictionary(
            grouping: unacknowledgedWaiting,
            by: { $0.terminal.app }
        )
        probeQueue.async { [weak self] in
            guard let self else { return }
            var acknowledgements: [(String, Int64)] = []
            for (app, sessions) in grouped {
                guard let snapshot = self.probe.snapshot(
                    for: app,
                    frontmostBundleID: frontmost
                ) else {
                    continue
                }
                for session in sessions {
                    guard let waitingSince = session.waitingSince else { continue }
                    if AcknowledgmentPolicy.shouldAcknowledge(
                        session: session,
                        snapshot: snapshot
                    ) {
                        acknowledgements.append((session.sessionID, waitingSince))
                    }
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let ackTime = Int64(Date().timeIntervalSince1970)
                for (sessionID, waitingSince) in acknowledgements {
                    self.uiStore.acknowledge(
                        sessionID: sessionID,
                        at: ackTime,
                        waitingSince: waitingSince
                    )
                }
                self.probeInFlight = false
                if !acknowledgements.isEmpty {
                    self.tick()
                }
            }
        }
    }
}
