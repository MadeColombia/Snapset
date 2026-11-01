import SwiftUI

public enum RoadmapStepState: Sendable { case done, current, upcoming }

/// One step on the workout roadmap: a marker on the vertical line, and the step itself.
/// The current step is Iron raised with a Chalk leading line, never the accent; done steps collapse to one line with a check.
public struct RoadmapStep<Content: View>: View {
    public typealias State = RoadmapStepState

    let title: String
    let detail: String
    let state: State
    let isLast: Bool
    let onSelect: (() -> Void)?
    @ViewBuilder let content: Content

    /// `content` is shown only while the step is current.
    /// `onSelect` makes a step that isn't current tappable.
    public init(title: String, detail: String, state: State, isLast: Bool = false,
                onSelect: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.detail = detail
        self.state = state
        self.isLast = isLast
        self.onSelect = onSelect
        self.content = content()
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Snap.Spacing.m) {
            VStack(spacing: 0) {
                marker.padding(.top, Snap.Spacing.m)
                Rectangle().fill(isLast ? .clear : Color.snap.line).frame(width: 2).frame(maxHeight: .infinity)
            }
            .accessibilityHidden(true)
            Group {
                if state == .current {
                    card
                } else if let onSelect {
                    Button(action: onSelect) { card }
                        .buttonStyle(.plain)
                        .accessibilityHint("Makes this the current step")
                } else {
                    card
                }
            }
            .padding(.bottom, isLast ? 0 : Snap.Spacing.m)
        }
        .fixedSize(horizontal: false, vertical: true)  // lets the line run the full height of the step
    }

    @ViewBuilder private var marker: some View {
        switch state {
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.snap.statusUp)
                .frame(width: 22, height: 22)
        case .current:
            // Neutral on purpose: the screen's one accent is the Log set button.
            Circle().fill(Color.snap.textPrimary).frame(width: 14, height: 14).frame(width: 22, height: 22)
        case .upcoming:
            Circle().strokeBorder(Color.snap.line, lineWidth: 2).frame(width: 14, height: 14).frame(width: 22, height: 22)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: Snap.Spacing.m) {
            VStack(alignment: .leading, spacing: Snap.Spacing.xs) {
                if state == .done {
                    Text(detail).snapText(.body).foregroundStyle(Color.snap.textSecondary)
                } else {
                    Text(title).snapText(.sectionTitle)
                        .foregroundStyle(state == .current ? Color.snap.textPrimary : Color.snap.textSecondary)
                    Text(detail).snapText(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue(state == .done ? "Done" : state == .current ? "Current step" : "")
            if state == .current { content }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)  // the row's fixed height must not truncate wrapping text
        .padding(state == .current ? Snap.Spacing.l : Snap.Spacing.m)
        .background(state == .current ? Color.snap.surfaceRaised : Color.snap.surface, in: .rect(cornerRadius: Snap.Radius.card))
        .overlay(alignment: .leading) {
            if state == .current {
                UnevenRoundedRectangle(topLeadingRadius: Snap.Radius.card, bottomLeadingRadius: Snap.Radius.card)
                    .fill(Color.snap.textPrimary)
                    .frame(width: 2)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(.rect)
    }
}

private struct RoadmapStepPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                RoadmapStep(title: "Leg press", detail: "Done. 3 sets of leg press.", state: .done, onSelect: {}) {
                    EmptyView()
                }
                RoadmapStep(title: "Chest press", detail: "3 sets · about 7 min", state: .current) {
                    SetRow(number: 1, weight: 42.5, reps: 12)
                    RestTimer(remaining: 74, total: 90, next: "Next: 42.5 kg × 12", onSkip: {}, onAddThirty: {})
                }
                RoadmapStep(title: "Seated row", detail: "3 sets · about 7 min", state: .upcoming, isLast: true, onSelect: {}) {
                    EmptyView()
                }
            }
            .padding(Snap.Spacing.l)
        }
        .background(Color.snap.background)
    }
}

#Preview("Dark") { RoadmapStepPreview().preferredColorScheme(.dark) }
#Preview("Light") { RoadmapStepPreview().preferredColorScheme(.light) }
#Preview("AX5") { RoadmapStepPreview().preferredColorScheme(.dark).dynamicTypeSize(.accessibility5) }
