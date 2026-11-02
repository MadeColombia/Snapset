import SwiftUI

public struct Banner: View {
    public enum Tone: Sendable { case amber, sky }

    let tone: Tone
    let systemImage: String
    let text: String

    public init(_ tone: Tone, systemImage: String, _ text: String) {
        self.tone = tone
        self.systemImage = systemImage
        self.text = text
    }

    public var body: some View {
        let color = tone == .amber ? Color.snap.statusDown : Color.snap.statusHold
        HStack(alignment: .firstTextBaseline, spacing: Snap.Spacing.s) {
            Image(systemName: systemImage).foregroundStyle(color)
            Text(text).foregroundStyle(Color.snap.textPrimary)
            Spacer(minLength: 0)
        }
        .snapText(.body)
        .padding(Snap.Spacing.m)
        .background(color.opacity(0.15), in: .rect(cornerRadius: Snap.Radius.control))
        .accessibilityElement(children: .combine)
    }
}

public struct UndoToast: View {
    let message: String
    let isBest: Bool
    let onUndo: () -> Void

    /// `isBest` turns the toast into the screen's one cheer: a Sage check and glow.
    public init(_ message: String, isBest: Bool = false, onUndo: @escaping () -> Void) {
        self.message = message
        self.isBest = isBest
        self.onUndo = onUndo
    }

    public var body: some View {
        HStack(spacing: Snap.Spacing.m) {
            if isBest {
                Image(systemName: "checkmark").foregroundStyle(Color.snap.statusUp).accessibilityHidden(true)
            }
            Text(message).foregroundStyle(Color.snap.textPrimary)
            Spacer(minLength: 0)
            Button("Undo", action: onUndo)
                .font(.headline)
                .foregroundStyle(Color.snap.textPrimary)
                .frame(minWidth: Snap.Tap.min, minHeight: Snap.Tap.min)
        }
        .snapText(.body)
        .padding(.horizontal, Snap.Spacing.l)
        .padding(.vertical, Snap.Spacing.xs)
        .background(Color.snap.surfaceRaised, in: .rect(cornerRadius: Snap.Radius.control))
        .overlay(RoundedRectangle(cornerRadius: Snap.Radius.control).stroke(isBest ? Color.snap.statusUp : Color.snap.line))
        .shadow(color: isBest ? Color.snap.statusUp.opacity(0.5) : .clear, radius: 12)
    }
}

/// Rest countdown, the biggest thing on the step between sets: a ring that empties, Skip, +30 s and what comes next.
/// Paused (the workout is paused), the time stops and turns the resume colour.
public struct RestTimer: View {
    let remaining: TimeInterval
    let total: TimeInterval
    let paused: Bool
    let next: String?
    let onSkip: () -> Void
    let onAddThirty: () -> Void
    @ScaledMetric(relativeTo: .largeTitle) private var ring: CGFloat = 220

    public init(remaining: TimeInterval, total: TimeInterval, paused: Bool = false, next: String? = nil,
                onSkip: @escaping () -> Void, onAddThirty: @escaping () -> Void) {
        self.remaining = remaining
        self.total = total
        self.paused = paused
        self.next = next
        self.onSkip = onSkip
        self.onAddThirty = onAddThirty
    }

    public var body: some View {
        let left = max(0, remaining.rounded(.up))
        let color = paused ? Color.snap.actionResume : Color.snap.statusUp
        VStack(spacing: Snap.Spacing.l) {
            ZStack {
                Circle().stroke(Color.snap.line, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: total > 0 ? min(1, left / total) : 0)
                    .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(paused ? "Paused" : "Rest").snapText(.secondary)
                    Text(Duration.seconds(left).formatted(.time(pattern: .minuteSecond)))
                        .snapText(.heroNumber)
                        .foregroundStyle(paused ? Color.snap.actionResume : Color.snap.textPrimary)
                        .contentTransition(.numericText(countsDown: true))
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                }
                .padding(Snap.Spacing.xl)
            }
            .frame(maxWidth: ring, maxHeight: ring)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(paused ? "Rest paused" : "Rest")
            .accessibilityValue(Duration.seconds(left).formatted(.units(allowed: [.minutes, .seconds], width: .wide)))
            if let next { Text(next).snapText(.body).foregroundStyle(Color.snap.textPrimary) }
            HStack(spacing: Snap.Spacing.m) {
                SecondaryButton("Skip", action: onSkip)
                SecondaryButton("+30 s", action: onAddThirty).accessibilityLabel("Add 30 seconds")
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct FeedbackPreview: View {
    var body: some View {
        PreviewSurface {
            Banner(.amber, systemImage: "camera.badge.ellipsis", "Couldn't read the photo. Enter it by hand, it's already filled in.")
            Banner(.sky, systemImage: "play.circle", "First time? Watch the loop, then go light.")
            UndoToast("Set saved") {}
            UndoToast("New best: 50 kg on chest press!", isBest: true) {}
            RestTimer(remaining: 84, total: 90, next: "Next: 42.5 kg × 10", onSkip: {}, onAddThirty: {})
        }
    }
}

private struct RestTimerPreview: View {
    var body: some View {
        PreviewSurface {
            RestTimer(remaining: 74, total: 90, next: "Next: 42.5 kg × 10", onSkip: {}, onAddThirty: {})
            RestTimer(remaining: 51, total: 90, paused: true, next: "Next: 42.5 kg × 10", onSkip: {}, onAddThirty: {})
        }
    }
}

#Preview("Rest dark") { ScrollView { RestTimerPreview() }.preferredColorScheme(.dark) }
#Preview("Rest light") { ScrollView { RestTimerPreview() }.preferredColorScheme(.light) }
#Preview("Rest AX5") { ScrollView { RestTimerPreview() }.preferredColorScheme(.dark).dynamicTypeSize(.accessibility5) }
#Preview("Dark") { FeedbackPreview().preferredColorScheme(.dark) }
#Preview("Light") { FeedbackPreview().preferredColorScheme(.light) }
#Preview("AX5") { FeedbackPreview().preferredColorScheme(.dark).dynamicTypeSize(.accessibility5) }
