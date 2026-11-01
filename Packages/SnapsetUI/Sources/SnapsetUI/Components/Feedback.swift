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

/// Rest countdown with Skip and +30 s, and what comes next. Between sets this is all the screen needs to show.
public struct RestTimer: View {
    let remaining: TimeInterval
    let next: String?
    let onSkip: () -> Void
    let onAddThirty: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    public init(remaining: TimeInterval, next: String? = nil, onSkip: @escaping () -> Void, onAddThirty: @escaping () -> Void) {
        self.remaining = remaining
        self.next = next
        self.onSkip = onSkip
        self.onAddThirty = onAddThirty
    }

    public var body: some View {
        // Buttons drop under the time at accessibility sizes, where three across would cut off their words.
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: Snap.Spacing.m))
                                                  : AnyLayout(HStackLayout(spacing: Snap.Spacing.m))
        VStack(alignment: .leading, spacing: Snap.Spacing.s) {
            layout {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Rest").snapText(.secondary)
                    Text(Duration.seconds(max(0, remaining.rounded(.up))).formatted(.time(pattern: .minuteSecond)))
                        .snapText(.numberMedium)
                        .foregroundStyle(Color.snap.textPrimary)
                        .contentTransition(.numericText(countsDown: true))
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 0)
                HStack(spacing: Snap.Spacing.m) {
                    SecondaryButton("Skip", action: onSkip).fixedSize()
                    SecondaryButton("+30 s", action: onAddThirty).fixedSize()
                        .accessibilityLabel("Add 30 seconds")
                }
            }
            if let next { Text(next).snapText(.body).foregroundStyle(Color.snap.textPrimary) }
        }
    }
}

private struct FeedbackPreview: View {
    var body: some View {
        PreviewSurface {
            Banner(.amber, systemImage: "camera.badge.ellipsis", "Couldn't read the photo. Enter it by hand, it's already filled in.")
            Banner(.sky, systemImage: "play.circle", "First time? Watch the loop, then go light.")
            UndoToast("Set saved") {}
            UndoToast("New best: 50 kg on chest press!", isBest: true) {}
            RestTimer(remaining: 84, next: "Next: 42.5 kg × 10", onSkip: {}, onAddThirty: {})
        }
    }
}

#Preview("Dark") { FeedbackPreview().preferredColorScheme(.dark) }
#Preview("Light") { FeedbackPreview().preferredColorScheme(.light) }
#Preview("AX5") { FeedbackPreview().preferredColorScheme(.dark).dynamicTypeSize(.accessibility5) }
