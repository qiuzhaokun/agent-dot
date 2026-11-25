import AppKit
import SwiftUI
import AgentDotCore

struct BallView: View {
    let sessions: [SessionState]
    let threshold: Int
    let aggregate: AggregateVisualState
    let acknowledgedSessionIDs: Set<String>
    let hasUpdate: Bool
    let backgroundOpacity: Double

    private var limit: Int {
        min(max(threshold, 1), 9)
    }

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private var needsAnimation: Bool {
        !reduceMotion && aggregate == .waitingUnacknowledged
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !needsAnimation)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let phase = reduceMotion ? 0.5 : (sin(time * .pi / 0.8) + 1.0) / 2.0
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .opacity(backgroundOpacity)
                Circle()
                    .fill(glowColor.opacity(0.10))
                    .opacity(backgroundOpacity)
                Circle()
                    .strokeBorder(
                        borderColor,
                        lineWidth: aggregate == .waitingUnacknowledged ? 2 : 1
                    )
                content
                if aggregate == .waitingUnacknowledged {
                    Circle()
                        .stroke(Color.red.opacity(0.55), lineWidth: 3)
                        .scaleEffect(0.92 + 0.30 * phase)
                        .opacity(0.7 * (1.0 - phase))
                }
                if hasUpdate {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 7, height: 7)
                        .offset(x: 18, y: -18)
                        .shadow(color: .black.opacity(0.25), radius: 2)
                }
            }
        }
        .shadow(color: .black.opacity(0.28), radius: 8, y: 3)
    }

    @ViewBuilder
    private var content: some View {
        if sessions.isEmpty {
            Circle()
                .stroke(
                    Color.secondary.opacity(0.5),
                    style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])
                )
                .frame(width: 16, height: 16)
        } else if sessions.count > limit {
            Text("\(sessions.count)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(borderColor)
        } else {
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(8), spacing: 5), count: 3),
                spacing: 5
            ) {
                ForEach(Array(sessions.prefix(limit).enumerated()), id: \.offset) { _, session in
                    Circle()
                        .fill(color(for: session.state))
                        .frame(width: 6, height: 6)
                }
            }
            .frame(width: 45, height: 45)
        }
    }

    private var borderColor: Color {
        switch aggregate {
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

    private var glowColor: Color {
        switch aggregate {
        case .waitingUnacknowledged, .waitingAcknowledged:
            return .red
        case .error:
            return .orange
        case .running, .done:
            return .green
        case .idle:
            return .gray
        }
    }

    private func color(for state: SessionPhase) -> Color {
        switch state {
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
}
