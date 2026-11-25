import AppKit
import SwiftUI
import AgentDotCore

struct HUDView: View {
    @ObservedObject var viewModel: HUDViewModel
    let dragController: WindowDragController
    let listResizeController: ListResizeController
    let onOpenSettings: () -> Void
    let onJump: (SessionState) -> Void
    @State private var isDraggingWindow = false
    @State private var isResizingList = false

    var body: some View {
        Group {
            if viewModel.expanded {
                expandedView
            } else {
                BallView(
                    sessions: viewModel.sortedSessions,
                    threshold: viewModel.config.thresholdN,
                    aggregate: viewModel.aggregate,
                    acknowledgedSessionIDs: viewModel.acknowledgedSessionIDs,
                    hasUpdate: isUpdateAvailable,
                    backgroundOpacity: viewModel.config.ballBackgroundOpacity / 100
                )
                .frame(width: 56, height: 56)
                .contentShape(Circle())
                .gesture(windowDragGesture(tapAction: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        viewModel.expanded = true
                    }
                }))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var expandedView: some View {
        VStack(spacing: 0) {
            header
            panelSeparator
            if !viewModel.hooksInstalled {
                Button {
                    viewModel.repairHooks()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Hooks 未安装，点此修复")
                            .font(.system(size: 11))
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 30)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Divider().opacity(0.2)
            }
            if let jumpStatus = viewModel.jumpStatus {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                    Text(jumpStatus)
                        .font(.system(size: 11))
                        .lineLimit(2)
                    Spacer(minLength: 6)
                    Button("复制终端信息") {
                        copy(viewModel.jumpStatusDetail)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 40)
                .background(Color.orange.opacity(0.08))
                Divider().opacity(0.2)
            }
            if viewModel.needsInstall {
                installBanner
            }
            if viewModel.justUpdated {
                updatedBanner
            }
            updateBanner
            if viewModel.sessions.isEmpty {
                emptyView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.sortedSessions, id: \.sessionID) { session in
                            SessionRowView(
                                session: session,
                                acknowledged: viewModel.acknowledgedSessionIDs.contains(session.sessionID),
                                onJump: { onJump(session) },
                                onAcknowledge: {
                                    viewModel.acknowledge(sessionID: session.sessionID)
                                },
                                onClearAcknowledgment: {
                                    viewModel.clearAcknowledgment(sessionID: session.sessionID)
                                }
                            )
                        }
                    }
                }
                .scrollIndicators(.visible)
                resizeHandle
            }
        }
        .background(
            RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                .fill(.regularMaterial)
                .opacity(viewModel.config.listBackgroundOpacity / 100)
        )
        .overlay(
            // 玻璃拟态描边：顶部亮、底部淡。
            RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.primary.opacity(0.16),
                            Color.primary.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .overlay(
            // 顶部内高光，增强玻璃边缘。
            RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.20), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
                .mask(
                    LinearGradient(
                        colors: [.white, .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .allowsHitTesting(false)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
        )
        .shadow(color: .black.opacity(0.24), radius: 18, y: 6)
        .padding(6)
    }

    private var panelCornerRadius: CGFloat { 18 }

    private var panelSeparator: some View {
        LinearGradient(
            colors: [.clear, Color.primary.opacity(0.12), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
        .padding(.horizontal, 14)
    }

    private var isUpdateAvailable: Bool {
        if case .available = viewModel.updateState {
            return true
        }
        return false
    }

    @ViewBuilder
    private var installBanner: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.to.line.compact")
                    .foregroundColor(.blue)
                Text("安装到 ~/Applications 才能自动更新")
                    .font(.system(size: 11))
                Spacer(minLength: 6)
                Button("安装") {
                    viewModel.installToUserApplications()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
            }
            if !viewModel.installStatus.isEmpty {
                Text(viewModel.installStatus)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(Color.blue.opacity(0.08))
        Divider().opacity(0.2)
    }

    @ViewBuilder
    private var updatedBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("已更新到 \(viewModel.updateNoticeVersion ?? viewModel.currentVersionString)。若跳转失败，请在 系统设置 → 隐私与安全性 → 自动化 重新允许 AgentDot。")
                .font(.system(size: 11))
                .lineLimit(2)
            Spacer(minLength: 6)
            Button("知道了") {
                viewModel.justUpdated = false
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .background(Color.green.opacity(0.08))
        Divider().opacity(0.2)
    }

    @ViewBuilder
    private var updateBanner: some View {
        switch viewModel.updateState {
        case .idle, .upToDate:
            EmptyView()
        case .checking:
            bannerRow(
                icon: "arrow.triangle.2.circlepath",
                color: .secondary,
                text: "正在检查更新…"
            )
        case .available(let manifest):
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.blue)
                Text("新版本 \(manifest.version) 可用")
                    .font(.system(size: 11))
                Spacer(minLength: 6)
                Button("升级") {
                    viewModel.upgradeUpdate()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                Button("稍后") {
                    viewModel.skipUpdate(version: manifest.version)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(Color.blue.opacity(0.08))
            Divider().opacity(0.2)
        case .downloading(let progress):
            VStack(alignment: .leading, spacing: 4) {
                Text("下载更新 \(Int(progress * 100))%")
                    .font(.system(size: 11))
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(Color.blue.opacity(0.08))
            Divider().opacity(0.2)
        case .verifying:
            bannerRow(
                icon: "checkmark.shield",
                color: .blue,
                text: "正在校验更新…"
            )
        case .installing:
            bannerRow(
                icon: "arrow.clockwise.circle",
                color: .blue,
                text: "正在安装，应用将重启…"
            )
        case .failed(let message):
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.orange)
                Text(message)
                    .font(.system(size: 11))
                    .lineLimit(2)
                Spacer(minLength: 6)
                Button("检查更新") {
                    viewModel.checkForUpdates(manual: true)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(Color.orange.opacity(0.08))
            Divider().opacity(0.2)
        }
    }

    @ViewBuilder
    private func bannerRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 11))
            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(color.opacity(0.06))
        Divider().opacity(0.2)
    }

    private func windowDragGesture(tapAction: (() -> Void)? = nil) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                if !isDraggingWindow {
                    isDraggingWindow = true
                    dragController.begin()
                }
                dragController.update()
            }
            .onEnded { _ in
                let wasTap = dragController.totalDistance < 4
                dragController.end()
                isDraggingWindow = false
                if wasTap {
                    tapAction?()
                }
            }
    }

    private func listResizeGesture() -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                if !isResizingList {
                    isResizingList = true
                    listResizeController.begin()
                }
                listResizeController.update()
            }
            .onEnded { _ in
                listResizeController.end()
                isResizingList = false
            }
    }

    private var resizeHandle: some View {
        ZStack {
            Color.clear
            Capsule()
                .fill(Color.primary.opacity(0.18))
                .frame(width: 36, height: 3)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 10)
        .contentShape(Rectangle())
        .gesture(listResizeGesture())
        .onHover { hovering in
            if hovering {
                NSCursor.resizeUpDown.set()
            } else {
                NSCursor.arrow.set()
            }
        }
        .help("拖动调整列表高度")
    }

    private var header: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(headerColor)
                    .frame(width: 10, height: 10)
                Text("AgentDot")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(viewModel.sessions.count) 个会话")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
            .gesture(windowDragGesture())
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help("设置")
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    viewModel.expanded = false
                }
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.plain)
            .help("收起")
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "circle.dashed")
                .font(.system(size: 26))
                .foregroundColor(.secondary)
            Text("暂无 Claude Code 会话")
                .font(.system(size: 13, weight: .medium))
            Text("在终端里运行 claude 即可自动出现")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private var headerColor: Color {
        switch viewModel.aggregate {
        case .waitingUnacknowledged, .waitingAcknowledged:
            return .red
        case .error:
            return .orange
        case .running, .done:
            return .green
        case .idle:
            return .secondary
        }
    }

}
