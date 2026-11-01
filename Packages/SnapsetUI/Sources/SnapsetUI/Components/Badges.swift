import SwiftUI

/// What the coach suggests for the next set. Colour is never the only signal: each has a symbol and a word.
public struct StatusBadge: View {
    public enum Status: Sendable { case up, hold, lighter }

    let status: Status

    public init(_ status: Status) { self.status = status }

    private var parts: (color: Color, symbol: String, word: String) {
        switch status {
        case .up: (Color.snap.statusUp, "arrow.up", "Up")
        case .hold: (Color.snap.statusHold, "equal", "Hold")
        case .lighter: (Color.snap.statusDown, "arrow.down", "Lighter")
        }
    }

    public var body: some View {
        Label(parts.word, systemImage: parts.symbol)
            .snapText(.label)
            .foregroundStyle(parts.color)
            .padding(.horizontal, Snap.Spacing.s)
            .padding(.vertical, Snap.Spacing.xs)
            .background(parts.color.opacity(0.15), in: .rect(cornerRadius: Snap.Radius.chip))
    }
}

/// How sure the photo reading is.
public struct ConfidenceBadge: View {
    public enum Confidence: Sendable {
        case sure
        case unsure(guess: String)
    }

    let confidence: Confidence

    public init(_ confidence: Confidence) { self.confidence = confidence }

    public var body: some View {
        switch confidence {
        case .sure:
            Label("Read from photo", systemImage: "checkmark")
                .snapText(.label)
                .foregroundStyle(Color.snap.statusUp)
        case .unsure(let guess):
            Label("Not sure about this one. Is it \(guess)?", systemImage: "exclamationmark.circle")
                .snapText(.label)
                .foregroundStyle(Color.snap.statusDown)
        }
    }
}

private struct BadgesPreview: View {
    var body: some View {
        PreviewSurface {
            HStack { StatusBadge(.up); StatusBadge(.hold); StatusBadge(.lighter) }
            ConfidenceBadge(.sure)
            ConfidenceBadge(.unsure(guess: "40 kg"))
        }
    }
}

#Preview("Dark") { BadgesPreview().preferredColorScheme(.dark) }
#Preview("Light") { BadgesPreview().preferredColorScheme(.light) }
#Preview("AX5") { BadgesPreview().preferredColorScheme(.dark).dynamicTypeSize(.accessibility5) }
