import SwiftUI

/// One logged set: weight × reps, with a "W" mark for warm-up sets.
public struct SetRow: View {
    let number: Int
    let weight: Double
    let reps: Int
    let unit: String
    let isWarmUp: Bool

    public init(number: Int, weight: Double, reps: Int, unit: String = "kg", isWarmUp: Bool = false) {
        self.number = number
        self.weight = weight
        self.reps = reps
        self.unit = unit
        self.isWarmUp = isWarmUp
    }

    public var body: some View {
        HStack(spacing: Snap.Spacing.m) {
            Text(isWarmUp ? "W" : "\(number)")
                .snapText(.label)
                .foregroundStyle(isWarmUp ? Color.snap.statusDown : Color.snap.textSecondary)
                .frame(minWidth: 28, minHeight: 28)
                .background(Color.snap.surface, in: .rect(cornerRadius: Snap.Radius.chip))
            Text("\(weight.formatted(.number.precision(.fractionLength(0...1)))) × \(reps)")
                .font(.system(.body, design: .rounded).monospacedDigit())
                .foregroundStyle(Color.snap.textPrimary)
            Spacer(minLength: 0)
        }
        .frame(minHeight: Snap.Tap.min)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isWarmUp ? "Warm-up set" : "Set \(number)")
        .accessibilityValue("\(weight.formatted()) \(unit), \(reps) reps")
    }
}

private struct SetRowPreview: View {
    var body: some View {
        PreviewSurface {
            SetRow(number: 0, weight: 20, reps: 10, isWarmUp: true)
            SetRow(number: 1, weight: 42.5, reps: 12)
            SetRow(number: 2, weight: 42.5, reps: 11)
        }
    }
}

#Preview("Dark") { SetRowPreview().preferredColorScheme(.dark) }
#Preview("Light") { SetRowPreview().preferredColorScheme(.light) }
#Preview("AX5") { SetRowPreview().preferredColorScheme(.dark).dynamicTypeSize(.accessibility5) }
