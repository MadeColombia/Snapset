import SwiftUI

public struct PrimaryButton: View {
    public enum Style: Sendable { case accent, neutral }

    let title: String
    let style: Style
    let action: () -> Void

    /// `.accent` is the screen's one accent element. Use `.neutral` when something else already has it.
    public init(_ title: String, style: Style = .accent, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: Snap.Tap.logging)
                .foregroundStyle(style == .accent ? Color.snap.onAccent : Color.snap.background)
                .background(style == .accent ? Color.snap.accent : Color.snap.textPrimary,
                            in: .rect(cornerRadius: Snap.Radius.control))
        }
        .buttonStyle(.plain)
    }
}

public struct SecondaryButton: View {
    let title: String
    let systemImage: String?
    let iconOnly: Bool
    let action: () -> Void

    /// With `iconOnly`, the title is still read by VoiceOver.
    public init(_ title: String, systemImage: String? = nil, iconOnly: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.iconOnly = iconOnly
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Group {
                if let systemImage, iconOnly {
                    Image(systemName: systemImage).accessibilityLabel(title)
                } else if let systemImage {
                    Label(title, systemImage: systemImage)
                } else {
                    Text(title)
                }
            }
            .font(.headline)
            .padding(.horizontal, Snap.Spacing.l)
            .frame(maxWidth: iconOnly ? nil : .infinity, minHeight: Snap.Tap.logging)
            .frame(minWidth: Snap.Tap.logging)
            .foregroundStyle(Color.snap.textPrimary)
            .background(Color.snap.surfaceRaised, in: .rect(cornerRadius: Snap.Radius.control))
            // Hairline so the button still reads on an Iron raised surface, like the current roadmap step.
            .overlay(RoundedRectangle(cornerRadius: Snap.Radius.control).strokeBorder(Color.snap.line))
        }
        .buttonStyle(.plain)
    }
}

private struct ButtonsPreview: View {
    var body: some View {
        PreviewSurface {
            PrimaryButton("Save set") {}
            PrimaryButton("Finish workout", style: .neutral) {}
            SecondaryButton("Add note") {}
            SecondaryButton("Take photo", systemImage: "camera", iconOnly: true) {}
        }
    }
}

#Preview("Dark") { ButtonsPreview().preferredColorScheme(.dark) }
#Preview("Light") { ButtonsPreview().preferredColorScheme(.light) }
#Preview("AX5") { ButtonsPreview().preferredColorScheme(.dark).dynamicTypeSize(.accessibility5) }
