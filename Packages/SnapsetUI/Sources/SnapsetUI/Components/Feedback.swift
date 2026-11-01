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
    let onUndo: () -> Void

    public init(_ message: String, onUndo: @escaping () -> Void) {
        self.message = message
        self.onUndo = onUndo
    }

    public var body: some View {
        HStack(spacing: Snap.Spacing.m) {
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
        .overlay(RoundedRectangle(cornerRadius: Snap.Radius.control).stroke(Color.snap.line))
    }
}

/// Rest countdown with Skip and +30 s.
public struct RestTimer: View {
    let remaining: TimeInterval
    let onSkip: () -> Void
    let onAddThirty: () -> Void

    public init(remaining: TimeInterval, onSkip: @escaping () -> Void, onAddThirty: @escaping () -> Void) {
        self.remaining = remaining
        self.onSkip = onSkip
        self.onAddThirty = onAddThirty
    }

    public var body: some View {
        HStack(spacing: Snap.Spacing.m) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Rest").snapText(.secondary)
                Text(Duration.seconds(remaining).formatted(.time(pattern: .minuteSecond)))
                    .snapText(.numberMedium)
                    .foregroundStyle(Color.snap.textPrimary)
                    .contentTransition(.numericText(countsDown: true))
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            SecondaryButton("Skip", action: onSkip).fixedSize()
            SecondaryButton("+30 s", action: onAddThirty).fixedSize()
                .accessibilityLabel("Add 30 seconds")
        }
    }
}

private struct FeedbackPreview: View {
    var body: some View {
        PreviewSurface {
            Banner(.amber, systemImage: "camera.badge.ellipsis", "Couldn't read the photo. Enter it by hand, it's already filled in.")
            Banner(.sky, systemImage: "play.circle", "First time? Watch the loop, then go light.")
            UndoToast("Set saved") {}
            RestTimer(remaining: 84, onSkip: {}, onAddThirty: {})
        }
    }
}

#Preview("Dark") { FeedbackPreview().preferredColorScheme(.dark) }
#Preview("Light") { FeedbackPreview().preferredColorScheme(.light) }
#Preview("AX5") { FeedbackPreview().preferredColorScheme(.dark).dynamicTypeSize(.accessibility5) }
