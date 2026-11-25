import AppKit
import Foundation
import SwiftUI
import AgentDotCore

struct MarqueeBar: View {
    let state: SessionPhase
    let acknowledged: Bool

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private var needsAnimation: Bool {
        guard !reduceMotion else { return false }
        return state == .running || (state == .waitingPermission && !acknowledged)
    }

    var body: some View {
        TimelineView(
            .animation(minimumInterval: 1.0 / 30.0, paused: !needsAnimation)
        ) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(trackColor)

                    if state == .running && !reduceMotion {
                        let segment = max(geometry.size.width * 0.35, 24)
                        let cycle = 1.8
                        let progress = time.truncatingRemainder(dividingBy: cycle) / cycle
                        Capsule()
                            .fill(greenGradient)
                            .frame(width: segment)
                            .offset(
                                x: progress * (geometry.size.width + segment) - segment
                            )
                    } else if state == .waitingPermission && !acknowledged && !reduceMotion {
                        let phase = (sin(time * .pi / 0.8) + 1.0) / 2.0
                        Capsule()
                            .fill(Color.red.opacity(0.35 + 0.65 * phase))
                    } else {
                        Capsule()
                            .fill(fillColor)
                    }
                }
            }
        }
        .frame(height: 5)
    }

    private var trackColor: Color {
        switch state {
        case .running:
            return .green.opacity(0.18)
        case .waitingPermission:
            return .red.opacity(0.20)
        case .done:
            return .green.opacity(0.15)
        case .error:
            return .orange.opacity(0.18)
        case .idle, .ended:
            return .gray.opacity(0.20)
        }
    }

    private var fillColor: Color {
        switch state {
        case .running:
            return .green.opacity(0.80)
        case .waitingPermission:
            return .red.opacity(0.75)
        case .done:
            return .green.opacity(0.75)
        case .error:
            return .orange.opacity(0.75)
        case .idle, .ended:
            return .gray.opacity(0.30)
        }
    }

    private var greenGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.green.opacity(0.15),
                Color.green.opacity(0.95),
                Color.green.opacity(0.15)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
