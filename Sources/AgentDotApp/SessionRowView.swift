import AppKit
import Foundation
import SwiftUI
import AgentDotCore

struct SessionRowView: View {
    let session: SessionState
    let acknowledged: Bool
    let onJump: () -> Void
    let onAcknowledge: () -> Void
    let onClearAcknowledgment: () -> Void

    var body: some View {
        let now = Int64(Date().timeIntervalSince1970)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                statusDot

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.displayName ?? session.projectName)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text(subtitle(now: now))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(elapsedText(now: now))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text(stateLabel)
                        .font(.system(size: 10))
                        .foregroundColor(statusColor)
                }
            }

            MarqueeBar(state: session.state, acknowledged: acknowledged)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(height: 64)
        .overlay(alignment: .bottom) {
            // 分隔线画在行内部，保证每行严格占用 64pt，列表高度可按行数精确计算。
            Divider().opacity(0.2).padding(.leading, 14)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onJump)
        .contextMenu {
            if session.state == .waitingPermission && !acknowledged {
                Button("忽略本次提醒") {
                    onAcknowledge()
                }
            }
            if session.state == .waitingPermission && acknowledged {
                Button("重新提醒") {
                    onClearAcknowledgment()
                }
            }
            Button("复制会话 ID") {
                copy(session.sessionID)
            }
            Button("复制终端信息") {
                copy(Self.terminalInfo(for: session))
            }
        }
    }

    private var statusColor: Color {
        switch session.state {
        case .waitingPermission:
            return .red
        case .error:
            return .orange
        case .running, .done:
            return .green
        case .idle, .ended:
            return .gray
        }
    }

    private var stateLabel: String {
        switch session.state {
        case .idle:
            return "空闲"
        case .running:
            return "运行中"
        case .waitingPermission:
            return "等待授权"
        case .done:
            return "已完成 ✓"
        case .error:
            return "失败 !"
        case .ended:
            return "已结束"
        }
    }

    private var statusDot: some View {
        Group {
            if session.state == .waitingPermission
                && !acknowledged
                && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let phase = (sin(time * .pi / 0.8) + 1.0) / 2.0
                    Circle()
                        .fill(Color.red.opacity(0.35 + 0.65 * phase))
                        .frame(width: 8, height: 8)
                        .scaleEffect(0.9 + 0.2 * phase)
                }
            } else {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }
        }
        .frame(width: 8, height: 8)
    }

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private func subtitle(now: Int64) -> String {
        let app = session.terminal.app == .unknown
            ? "未知终端"
            : session.terminal.app.rawValue
        let shortID = String(session.sessionID.suffix(4))
        if session.state == .waitingPermission, let waitingSince = session.waitingSince {
            return "\(app) · 等待 \(duration(now - waitingSince)) · \(shortID)"
        }
        if session.state == .running, let tool = session.currentTool {
            return "\(app) · \(tool) · \(shortID)"
        }
        return "\(app) · \(stateLabel) · \(shortID)"
    }

    private func elapsedText(now: Int64) -> String {
        guard let startedAt = session.turnStartedAt else { return "—" }
        let end = session.turnEndedAt ?? now
        return duration(end - startedAt)
    }

    private func duration(_ seconds: Int64) -> String {
        let value = max(0, seconds)
        if value < 60 {
            return "\(value)s"
        }
        if value < 3600 {
            return "\(value / 60)m"
        }
        let hours = value / 3600
        let minutes = (value % 3600) / 60
        return String(format: "%dh %02dm", hours, minutes)
    }

    static func terminalInfo(for session: SessionState) -> String {
        let terminal = session.terminal
        return [
            "app=\(terminal.app.rawValue)",
            "tty=\(terminal.tty ?? "-")",
            "iterm=\(terminal.itermSessionID ?? "-")",
            "term=\(terminal.termSessionID ?? "-")",
            "ghostty=\(terminal.ghosttySurfaceID ?? "-")",
            "kaku=\(terminal.weztermPane ?? "-")",
            "session=\(session.sessionID)"
        ].joined(separator: " ")
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}
