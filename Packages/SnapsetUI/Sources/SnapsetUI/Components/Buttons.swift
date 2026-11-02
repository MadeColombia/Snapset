import SwiftUI

public struct PrimaryButton: View {
    /// `.accent` is the screen's main action, `.neutral` when something else already has the accent.
    /// `.finish`, `.resume` and `.pause` are the workout controls' action colours; give them a symbol too.
    public enum Style: Sendable { case accent, neutral, finish, resume, pause }

    let title: String
    let systemImage: String?
    let style: Style
    let action: () -> Void

    public init(_ title: String, systemImage: String? = nil, style: Style = .accent, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
        self.action = action
    }

    private var fill: Color {
        switch style {
        case .accent: Color.snap.accent
        case .neutral: Color.snap.textPrimary
        case .finish: Color.snap.actionFinish
        case .resume: Color.snap.actionResume
        case .pause: Color.snap.actionPause
        }
    }

    public var body: some View {
        Button(action: action) {
            Group {
                if let systemImage { Label(title, systemImage: systemImage) } else { Text(title) }
            }
            .font(.headline)
            .padding(.horizontal, Snap.Spacing.l)
            .frame(maxWidth: .infinity, minHeight: Snap.Tap.logging)
            .foregroundStyle(style == .neutral ? Color.snap.background : Color.snap.onAccent)
            .background(fill, in: .rect(cornerRadius: Snap.Radius.control))
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
            HStack {
                PrimaryButton("Pause", systemImage: "pause.fill", style: .pause) {}
                PrimaryButton("Finish", systemImage: "checkmark", style: .finish) {}
            }
            PrimaryButton("Resume", systemImage: "play.fill", style: .resume) {}
            SecondaryButton("Add note") {}
            SecondaryButton("Take photo", systemImage: "camera", iconOnly: true) {}
        }
    }
}

#Preview("Dark") { ButtonsPreview().preferredColorScheme(.dark) }
#Preview("Light") { ButtonsPreview().preferredColorScheme(.light) }
#Preview("AX5") { ButtonsPreview().preferredColorScheme(.dark).dynamicTypeSize(.accessibility5) }
