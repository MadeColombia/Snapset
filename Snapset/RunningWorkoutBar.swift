import SwiftUI
import SwiftData
import SnapsetUI

/// The workout in progress, shown on the other tabs like a mini player: tap to go back to it, or pause from here.
struct RunningWorkoutBar: View {
    @Environment(\.modelContext) private var context
    let session: WorkoutSession
    let open: () -> Void

    var body: some View {
        let paused = session.pausedAt != nil
        HStack(spacing: 12) {
            Button(action: open) {
                HStack(spacing: 10) {
                    Image(systemName: paused ? "pause.circle.fill" : "record.circle")
                        .foregroundStyle(paused ? Color.snap.textSecondary : Color.snap.textPrimary)
                        .symbolEffect(.pulse, isActive: !paused)
                    Text(session.routineName ?? "Workout").lineLimit(1).foregroundStyle(Color.snap.textPrimary)
                    Spacer(minLength: 4)
                    ElapsedTime(startedAt: session.startedAt, pausedAt: session.pausedAt, pausedSeconds: session.pausedSeconds)
                        .monospacedDigit()
                        .foregroundStyle(paused ? Color.snap.textSecondary : Color.snap.textPrimary)
                        .fixedSize()  // a timer Text otherwise claims all the width it can
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the workout")

            Button(paused ? "Resume" : "Pause", systemImage: paused ? "play.fill" : "pause.fill") {
                session.togglePause()
                try? context.save()
                WorkoutActivity.sync(session, in: context)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .foregroundStyle(Color.snap.textPrimary)
            .frame(minWidth: Snap.Tap.min, minHeight: Snap.Tap.min)
            .contentShape(.rect)
        }
        .font(.subheadline.weight(.semibold))
        .padding(.leading)
        .padding(.trailing, 6)
    }
}

extension View {
    /// iOS 26.1+: the bar sits above the tab bar, where the system draws mini players.
    @ViewBuilder func runningWorkoutAccessory(_ bar: RunningWorkoutBar?) -> some View {
        if #available(iOS 26.1, *) {
            tabViewBottomAccessory(isEnabled: bar != nil) { bar }
        } else {
            self
        }
    }

    /// Before iOS 26.1 there is no tab bar accessory, so each tab pins the bar to its own bottom edge.
    @ViewBuilder func runningWorkoutInset(_ bar: RunningWorkoutBar?) -> some View {
        if #available(iOS 26.1, *) {
            self
        } else {
            safeAreaInset(edge: .bottom) {
                if let bar {
                    bar.padding(.vertical, Snap.Spacing.xs).background(Color.snap.surface)
                }
            }
        }
    }
}
