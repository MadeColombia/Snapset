import SwiftUI

/// Text styles. Keep to at most two weights per screen.
public enum SnapTextStyle: Sendable {
    case heroNumber, heroUnit, numberMedium, screenTitle, sectionTitle, body, secondary, label
}

private struct SnapTextModifier: ViewModifier {
    let style: SnapTextStyle
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 64

    func body(content: Content) -> some View {
        switch style {
        case .heroNumber:
            content.font(.system(size: heroSize, weight: .semibold, design: .rounded).monospacedDigit())
        case .heroUnit:
            content.font(.system(.title2, design: .rounded))
        case .numberMedium:
            content.font(.system(.title, design: .rounded, weight: .semibold).monospacedDigit())
        case .screenTitle:
            content.font(.largeTitle.bold())
        case .sectionTitle:
            content.font(.title3.weight(.semibold))
        case .body:
            content.font(.body)
        case .secondary:
            content.font(.subheadline).foregroundStyle(Color.snap.textSecondary)
        case .label:
            content.font(.footnote.weight(.semibold))
        }
    }
}

extension View {
    public func snapText(_ style: SnapTextStyle) -> some View {
        modifier(SnapTextModifier(style: style))
    }
}
