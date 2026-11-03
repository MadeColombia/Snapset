import SwiftUI
import SnapsetUI

/// What the workout is doing, and its colour. The same colours as the Workout screen, so a glance at the
/// Lock Screen or the Dynamic Island says what is happening: white while training, green while resting, orange while paused.
enum WorkoutPhase: Equatable {
    case training, resting, paused

    var color: Color {
        switch self {
        case .training: Color.snap.textPrimary
        case .resting: Color.snap.statusUp
        case .paused: Color.snap.actionResume
        }
    }

    var label: String {
        switch self {
        case .training: "Training"
        case .resting: "Resting"
        case .paused: "Paused"
        }
    }
}

extension WorkoutActivityAttributes.ContentState {
    /// Stale means the rest's end has passed and the app has not sent an update yet, so the rest is over.
    func phase(isStale: Bool) -> WorkoutPhase {
        if pausedAt != nil { return .paused }
        return !isStale && rest() != nil ? .resting : .training
    }
}

/// Between sets, the rest counting down; otherwise the workout time counting up. Both run on their own without
/// updates from the app, and freeze while paused. Coloured by phase.
struct WorkoutClock: View {
    let startedAt: Date
    let state: WorkoutActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        let phase = state.phase(isStale: isStale)
        Group {
            switch isStale ? nil : state.rest() {
            case .running(let end)?:
                Text(timerInterval: Date.now...max(end, .now), countsDown: true)
            case .paused(let seconds)?:
                Text(Duration.seconds(seconds), format: .time(pattern: .minuteSecond))
            case nil:
                ElapsedTime(startedAt: startedAt, pausedAt: state.pausedAt, pausedSeconds: state.pausedSeconds)
            }
        }
        .monospacedDigit()
        .foregroundStyle(phase.color)
        .lineLimit(1)
        .accessibilityLabel(phase == .training ? "Workout time" : "\(phase.label), rest left")
    }
}

/// The round badge at the start of the Lock Screen and the expanded Dynamic Island: the logo while training,
/// a ring that empties as the rest runs (green), or the frozen ring with a pause sign (orange).
struct WorkoutBadge<Logo: View>: View {
    let state: WorkoutActivityAttributes.ContentState
    let isStale: Bool
    let size: CGFloat
    @ViewBuilder let logo: () -> Logo

    var body: some View {
        let phase = state.phase(isStale: isStale)
        let line = size * 0.1
        ZStack {
            switch (phase, isStale ? nil : state.rest()) {
            case (.resting, .running(let end)?):
                Circle().stroke(phase.color.opacity(0.25), lineWidth: line)
                ProgressView(timerInterval: end.addingTimeInterval(-max(state.restSeconds, 1))...end, countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.circular)
                .tint(phase.color)
                Image(systemName: "timer").font(.system(size: size * 0.36, weight: .semibold)).foregroundStyle(phase.color)
            case (.paused, let rest):
                let left = Self.seconds(of: rest)
                Circle().stroke(phase.color.opacity(0.25), lineWidth: line)
                Circle()
                    .trim(from: 0, to: state.restSeconds > 0 ? min(1, left / state.restSeconds) : 0)
                    .stroke(phase.color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "pause.fill").font(.system(size: size * 0.34, weight: .bold)).foregroundStyle(phase.color)
            default:
                logo()
                    .frame(width: size, height: size)
                    .clipShape(.rect(cornerRadius: size * 0.24, style: .continuous))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private static func seconds(of rest: WorkoutActivityAttributes.ContentState.Rest?) -> Double {
        guard case .paused(let seconds)? = rest else { return 0 }
        return Double(seconds)
    }
}

/// The Lock Screen (and notification banner) Live Activity: phase and routine, a big clock in the phase colour,
/// and the next set underneath.
struct WorkoutLockScreenView<Logo: View>: View {
    let routineName: String
    let startedAt: Date
    let state: WorkoutActivityAttributes.ContentState
    let isStale: Bool
    @ViewBuilder let logo: () -> Logo

    var body: some View {
        let phase = state.phase(isStale: isStale)
        HStack(alignment: .center, spacing: 16) {
            WorkoutBadge(state: state, isStale: isStale, size: 56, logo: logo)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(phase.label.uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(phase.color)
                    Text(routineName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.snap.textSecondary)
                        .lineLimit(1)
                }
                WorkoutClock(startedAt: startedAt, state: state, isStale: isStale)
                    .font(.system(size: 46, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                Text(state.detail)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.snap.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }
}
