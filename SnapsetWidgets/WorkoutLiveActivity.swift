import ActivityKit
import AppIntents
import SwiftUI
import SnapsetUI
import WidgetKit

@main
struct SnapsetWidgets: WidgetBundle {
    var body: some Widget {
        WorkoutLiveActivity()
    }
}

/// Colours follow the Workout screen: white while training, green while resting, orange while paused
/// (WorkoutPhase, in Shared, with the Lock Screen view so the app can render it for design review).
struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            // Lock Screen and notification banner
            WorkoutLockScreenView(routineName: context.attributes.routineName, state: context.state, isStale: context.isStale) { Logo() }
                .activityBackgroundTint(Color.snap.background)
                .activitySystemActionForegroundColor(Color.snap.textPrimary)
        } dynamicIsland: { context in
            let phase = context.state.phase(isStale: context.isStale)
            // Expanded: badge and next set on the left, phase and clock on the right, one row of icon buttons below.
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    WorkoutBadge(state: context.state, isStale: context.isStale, size: 48) { Logo() }
                        .padding(.leading, 6)
                        .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(phase.label.uppercased())
                            .font(.caption2.weight(.bold))
                            .tracking(0.8)
                            .foregroundStyle(phase.color)
                        WorkoutClock(state: context.state, isStale: context.isStale)
                            .font(.system(size: 36, weight: .semibold, design: .rounded))
                            .minimumScaleFactor(0.6)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 140, alignment: .trailing)
                    }
                    .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.exercise.isEmpty ? context.attributes.routineName : context.state.exercise)
                            .font(.headline)
                            .foregroundStyle(Color.snap.textPrimary)
                        Text(context.state.setLine)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.snap.textSecondary)
                    }
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Controls(state: context.state)
                        .padding(.horizontal, 6)
                        .padding(.top, 8)
                }
            } compactLeading: {
                CompactIcon(phase: phase)
            } compactTrailing: {
                WorkoutClock(state: context.state, isStale: context.isStale)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 64, alignment: .trailing)  // a timer Text otherwise claims all the width it can
            } minimal: {
                WorkoutBadge(state: context.state, isStale: context.isStale, size: 22) { Logo() }
            }
            .keylineTint(phase.color)
        }
    }
}

/// The compact Dynamic Island's left side: the logo while training, a timer or pause sign in the phase colour otherwise.
private struct CompactIcon: View {
    let phase: WorkoutPhase

    var body: some View {
        switch phase {
        case .training: Logo().frame(width: 22, height: 22).clipShape(.rect(cornerRadius: 6, style: .continuous))
        case .resting: Image(systemName: "timer").font(.subheadline.weight(.semibold)).foregroundStyle(phase.color)
        case .paused: Image(systemName: "pause.fill").font(.subheadline.weight(.semibold)).foregroundStyle(phase.color)
        }
    }
}

/// Pause or Resume, log the next set, finish: icon only, in the Workout screen's action colours, one orange at a time
/// (Log set, or Resume while paused). They run in the app, which then updates the activity; Log set opens the app.
private struct Controls: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        let paused = state.pausedAt != nil
        HStack(spacing: 10) {
            button(intent: WorkoutButtonIntent(.pause), symbol: paused ? "play.fill" : "pause.fill",
                   label: paused ? "Resume" : "Pause", tint: paused ? Color.snap.actionResume : Color.snap.actionPause)
            button(intent: LogSetIntent(), symbol: "plus", label: "Log set",
                   tint: paused ? Color.snap.textPrimary : Color.snap.accent)
            button(intent: WorkoutButtonIntent(.finish), symbol: "checkmark", label: "Finish", tint: Color.snap.actionFinish)
        }
    }

    private func button(intent: some AppIntent, symbol: String, label: String, tint: Color) -> some View {
        Button(intent: intent) {
            Image(systemName: symbol)
                .font(.title3.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 30)
        }
        .tint(tint)
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .accessibilityLabel(label)
    }
}

private struct Logo: View {
    var body: some View {
        Image("AppLogo")
            .resizable()
            .scaledToFit()
            .accessibilityLabel("Snapset")
    }
}

#if DEBUG
private extension WorkoutActivityAttributes {
    static let preview = WorkoutActivityAttributes(routineName: "Upper and lower A", startedAt: .now.addingTimeInterval(-1_520))
}

private extension WorkoutActivityAttributes.ContentState {
    static let start = Date.now.addingTimeInterval(-1_520)
    static let training = Self(times: WorkoutTimes(startedAt: start), exercise: "Chest Press",
                               setLine: "Set 2/4 · 47.5 kg × 12", detail: "")
    static let resting = Self(times: WorkoutTimes(startedAt: start, holdSince: .now.addingTimeInterval(-18),
                                                  restEndsAt: .now.addingTimeInterval(72), restSeconds: 90),
                              exercise: "Chest Press", setLine: "Set 2/4 · 47.5 kg × 12", detail: "")
    static let paused = Self(times: WorkoutTimes(startedAt: start, holdSince: .now.addingTimeInterval(-49), pausedAt: .now,
                                                 restEndsAt: .now.addingTimeInterval(41), restSeconds: 90),
                             exercise: "Chest Press", setLine: "Set 2/4 · 47.5 kg × 12", detail: "")
}

#Preview("Lock Screen", as: .content, using: WorkoutActivityAttributes.preview) {
    WorkoutLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState.training
    WorkoutActivityAttributes.ContentState.resting
    WorkoutActivityAttributes.ContentState.paused
}

#Preview("Island expanded", as: .dynamicIsland(.expanded), using: WorkoutActivityAttributes.preview) {
    WorkoutLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState.training
    WorkoutActivityAttributes.ContentState.resting
    WorkoutActivityAttributes.ContentState.paused
}

#Preview("Island compact", as: .dynamicIsland(.compact), using: WorkoutActivityAttributes.preview) {
    WorkoutLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState.training
    WorkoutActivityAttributes.ContentState.resting
    WorkoutActivityAttributes.ContentState.paused
}
#endif
