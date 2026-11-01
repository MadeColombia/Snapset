import ActivityKit
import SwiftUI
import WidgetKit

@main
struct SnapsetWidgets: WidgetBundle {
    var body: some Widget {
        WorkoutLiveActivity()
    }
}

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            // Lock Screen and notification banner
            HStack(spacing: 12) {
                Logo(size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.routineName).font(.headline).lineLimit(1)
                    Text("Workout in progress").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Elapsed(context: context)
                    .font(.title.weight(.semibold))
                    .frame(maxWidth: 130, alignment: .trailing)
            }
            .padding()
            .activityBackgroundTint(.black.opacity(0.8))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Logo(size: 44)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Elapsed(context: context)
                        .font(.title2.weight(.semibold))
                        .frame(maxWidth: 120, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        Text(context.state.detail)
                            .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                        Controls(state: context.state)
                    }
                }
            } compactLeading: {
                Logo(size: 24)
            } compactTrailing: {
                Elapsed(context: context)
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: 64, alignment: .trailing)  // a timer Text otherwise claims all the width it can
            } minimal: {
                Logo(size: 24)
            }
            .keylineTint(.orange)
        }
    }
}

/// Counts up on its own without the app sending updates; grey and frozen while paused.
private struct Elapsed: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        ElapsedTime(startedAt: context.attributes.startedAt, pausedAt: context.state.pausedAt, pausedSeconds: context.state.pausedSeconds)
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
            .foregroundStyle(context.state.pausedAt == nil ? .orange : .gray)
    }
}

/// Pause or resume, log the next set, finish. They run in the app, which then updates the activity.
private struct Controls: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        let paused = state.pausedAt != nil
        HStack(spacing: 8) {
            Button(intent: WorkoutButtonIntent(.pause)) {
                Label(paused ? "Resume" : "Pause", systemImage: paused ? "play.fill" : "pause.fill").frame(maxWidth: .infinity)
            }
            .tint(.orange)
            Button(intent: WorkoutButtonIntent(.logSet)) {
                Label("Log set", systemImage: "plus").frame(maxWidth: .infinity)
            }
            .tint(.green)
            .disabled(!state.canLogSet)
            Button(intent: WorkoutButtonIntent(.finish)) {
                Label("Finish", systemImage: "checkmark").frame(maxWidth: .infinity)
            }
            .tint(.red)
        }
        .font(.subheadline.weight(.semibold))
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .lineLimit(1)
    }
}

private struct Logo: View {
    let size: CGFloat

    var body: some View {
        Image("AppLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("Snapset")
    }
}
