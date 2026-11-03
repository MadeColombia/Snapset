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
            // Expanded: the badge and the clock sit beside the camera, each with fixed room so the clock never truncates;
            // the phase, exercise and set share one line below, then one row of icon buttons.
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    WorkoutBadge(state: context.state, isStale: context.isStale, size: 44) { Logo() }
                        .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    WorkoutClock(state: context.state, isStale: context.isStale)
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 112, height: 44, alignment: .trailing)
                        .padding(.trailing, 6)
                        .dynamicIsland(verticalPlacement: .belowIfTooWide)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        StatusLine(state: context.state, phase: phase, routineName: context.attributes.routineName)
                        Controls(state: context.state)
                    }
                    .padding(.horizontal, 6)
                    .padding(.top, 4)
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

/// One line: "RESTING  Leg Extension · Set 1/4 · 15 kg × 15". Live Activities can't animate a scrolling line,
/// so the set details give way first (the exercise name is kept, the end is cut with an ellipsis).
private struct StatusLine: View {
    let state: WorkoutActivityAttributes.ContentState
    let phase: WorkoutPhase
    let routineName: String

    var body: some View {
        HStack(spacing: 8) {
            Text(phase.label.uppercased())
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(phase.color)
                .fixedSize()
            Text(state.exercise.isEmpty ? routineName : state.exercise)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.snap.textPrimary)
                .layoutPriority(1)
            Text(state.setLine)
                .font(.subheadline)
                .foregroundStyle(Color.snap.textSecondary)
            Spacer(minLength: 0)
        }
        .lineLimit(1)
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
    static let resting = Self(times: WorkoutTimes(startedAt: start,
                                                  restEndsAt: .now.addingTimeInterval(72), restSeconds: 90),
                              exercise: "Chest Press", setLine: "Set 2/4 · 47.5 kg × 12", detail: "")
    static let paused = Self(times: WorkoutTimes(startedAt: start, holdSince: .now, pausedAt: .now,
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
