import SwiftUI
import SnapsetUI

/// What the workout is doing, and its colour. The same colours as the Workout screen, so a glance at the
/// Lock Screen or the Dynamic Island says what is happening: white while training, green while resting, orange while paused.
typealias WorkoutPhase = WorkoutTimes.Phase

extension WorkoutTimes.Phase {
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
    /// Read when the view is drawn; a rest that has run out reads as training (the activity goes stale at the rest's end,
    /// which redraws it).
    func phase(isStale: Bool) -> WorkoutPhase { times.phase(at: .now) }
}

/// The phase's own clock: the rest counting down while resting (frozen while a rest is paused), otherwise the workout
/// time. Runs on its own without updates from the app. Coloured by phase.
struct WorkoutClock: View {
    let state: WorkoutActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        let phase = state.phase(isStale: isStale)
        let times = state.times
        Group {
            if phase == .resting, let end = times.restEndsAt {
                Text(timerInterval: Date.now...max(end, .now), countsDown: true)
            } else if phase == .paused, let left = times.restRemaining() {
                Text(Duration.seconds(left.rounded()), format: .time(pattern: .minuteSecond))
            } else {
                ElapsedTime(times: times)
            }
        }
        .monospacedDigit()
        .foregroundStyle(phase.color)
        .lineLimit(1)
        .accessibilityLabel(phase == .training ? "Workout time" : "\(phase.label), rest left")
    }
}

/// The round badge: the logo while training, a ring that empties as the rest runs (green), or the frozen ring with
/// a pause sign (orange).
struct WorkoutBadge<Logo: View>: View {
    let state: WorkoutActivityAttributes.ContentState
    let isStale: Bool
    let size: CGFloat
    @ViewBuilder let logo: () -> Logo

    var body: some View {
        let phase = state.phase(isStale: isStale)
        let times = state.times
        let line = size * 0.1
        ZStack {
            switch phase {
            case .resting:
                let end = times.restEndsAt ?? .now
                Circle().stroke(phase.color.opacity(0.25), lineWidth: line)
                ProgressView(timerInterval: end.addingTimeInterval(-max(times.restSeconds, 1))...end, countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.circular)
                .tint(phase.color)
                Image(systemName: "timer").font(.system(size: size * 0.36, weight: .semibold)).foregroundStyle(phase.color)
            case .paused:
                let left = times.restRemaining() ?? 0
                Circle().stroke(phase.color.opacity(0.25), lineWidth: line)
                Circle()
                    .trim(from: 0, to: times.restSeconds > 0 ? min(1, left / times.restSeconds) : 0)
                    .stroke(phase.color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "pause.fill").font(.system(size: size * 0.34, weight: .bold)).foregroundStyle(phase.color)
            case .training:
                logo()
                    .frame(width: size, height: size)
                    .clipShape(.rect(cornerRadius: size * 0.24, style: .continuous))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The Lock Screen (and notification banner) Live Activity: phase and routine, the live heart rate when there is one,
/// a big clock in the phase colour, and the next set underneath. While resting, the big clock is the rest and the workout time runs on, small, top right.
struct WorkoutLockScreenView<Logo: View>: View {
    let routineName: String
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
                    if state.heartRate != nil || state.times.restRemaining() != nil {
                        Spacer(minLength: 4)
                    }
                    if let bpm = state.heartRate {
                        HStack(spacing: 3) {
                            Image(systemName: "heart.fill").foregroundStyle(Color.snap.heartRate)
                            Text("\(bpm)").monospacedDigit().foregroundStyle(Color.snap.textSecondary)
                        }
                        .font(.caption.weight(.semibold))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Heart rate \(bpm) beats per minute")
                    }
                    if state.times.restRemaining() != nil {
                        // The big clock shows the rest; the total keeps its place up here, so the activity time stays clear.
                        ElapsedTime(times: state.times)
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(Color.snap.textSecondary)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 64, alignment: .trailing)
                    }
                }
                WorkoutClock(state: state, isStale: isStale)
                    .font(.system(size: 46, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                NextSetLine(state: state)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }
}

/// "Chest Press · Set 2/4 · 60 kg × 8", the exercise in the primary colour.
struct NextSetLine: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 6) {
            if !state.exercise.isEmpty {
                Text(state.exercise).foregroundStyle(Color.snap.textPrimary)
            }
            Text(state.setLine).foregroundStyle(Color.snap.textSecondary)
        }
        .font(.footnote.weight(.medium))
        .lineLimit(1)
    }
}
