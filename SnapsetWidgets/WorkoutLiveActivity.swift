import ActivityKit
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
            WorkoutLockScreenView(routineName: context.attributes.routineName, startedAt: context.attributes.startedAt,
                                  state: context.state, isStale: context.isStale) { Logo() }
                .activityBackgroundTint(Color.snap.background)
                .activitySystemActionForegroundColor(Color.snap.textPrimary)
        } dynamicIsland: { context in
            let phase = context.state.phase(isStale: context.isStale)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    WorkoutBadge(state: context.state, isStale: context.isStale, size: 52) { Logo() }
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(phase.label.uppercased())
                            .font(.caption2.weight(.bold))
                            .tracking(0.8)
                            .foregroundStyle(phase.color)
                        WorkoutClock(startedAt: context.attributes.startedAt, state: context.state, isStale: context.isStale)
                            .font(.system(size: 38, weight: .semibold, design: .rounded))
                            .minimumScaleFactor(0.6)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 150, alignment: .trailing)
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 12) {
                        Text(context.state.detail)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.snap.textSecondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Controls(state: context.state)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                CompactIcon(phase: phase)
            } compactTrailing: {
                WorkoutClock(startedAt: context.attributes.startedAt, state: context.state, isStale: context.isStale)
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

/// Pause or Resume, log the next set, finish, in the Workout screen's action colours. They run in the app, which then
/// updates the activity; Log set opens the app on the set confirm sheet rather than saving anything from here.
/// One orange button at a time: Log set, or Resume while paused.
private struct Controls: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        let paused = state.pausedAt != nil
        HStack(spacing: 8) {
            Button(intent: WorkoutButtonIntent(.pause)) {
                Label(paused ? "Resume" : "Pause", systemImage: paused ? "play.fill" : "pause.fill").frame(maxWidth: .infinity)
            }
            .tint(paused ? Color.snap.actionResume : Color.snap.actionPause)
            Button(intent: LogSetIntent()) {
                Label("Log set", systemImage: "plus").frame(maxWidth: .infinity)
            }
            .tint(paused ? Color.snap.textPrimary : Color.snap.accent)
            Button(intent: WorkoutButtonIntent(.finish)) {
                Label("Finish", systemImage: "checkmark").frame(maxWidth: .infinity)
            }
            .tint(Color.snap.actionFinish)
        }
        .font(.subheadline.weight(.semibold))
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .lineLimit(1)
        .labelStyle(.titleAndIcon)
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
    static let training = Self(detail: "Set 2/3: 47.5 kg × 12 · Chest Press")
    static let resting = Self(detail: "Set 2/3: 47.5 kg × 12 · Chest Press", restEndsAt: .now.addingTimeInterval(72), restSeconds: 90)
    static let paused = Self(pausedAt: .now, detail: "Set 2/3: 47.5 kg × 12 · Chest Press",
                             restEndsAt: .now.addingTimeInterval(41), restSeconds: 90)
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
