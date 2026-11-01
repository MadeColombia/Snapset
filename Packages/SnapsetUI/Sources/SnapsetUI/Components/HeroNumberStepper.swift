import SwiftUI

/// A large number with minus and plus buttons, for weight and reps.
public struct HeroNumberStepper: View {
    let label: String
    @Binding var value: Double
    let step: Double
    let range: ClosedRange<Double>
    let unit: String
    let editable: Bool

    /// With `editable`, the number is a text field so a weight can be typed as well as stepped.
    public init(_ label: String, value: Binding<Double>, step: Double, in range: ClosedRange<Double>, unit: String, editable: Bool = false) {
        self.label = label
        self._value = value
        self.step = step
        self.range = range
        self.unit = unit
        self.editable = editable
    }

    private static let format = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...2))
    private var text: String { value.formatted(Self.format) }

    private func change(by delta: Double) {
        value = min(max(value + delta, range.lowerBound), range.upperBound)
    }

    public var body: some View {
        if editable {
            row  // the field and the buttons stay separate VoiceOver elements
        } else {
            row
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label)
                .accessibilityValue("\(text) \(unit)")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: change(by: step)
                    case .decrement: change(by: -step)
                    @unknown default: break
                    }
                }
        }
    }

    private var row: some View {
        HStack(spacing: Snap.Spacing.m) {
            stepButton("minus", label: "Less \(label.lowercased())") { change(by: -step) }
            VStack(spacing: 0) {
                Group {
                    if editable {
                        TextField("0", value: $value, format: Self.format)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .accessibilityLabel("\(label) in \(unit)")
                    } else {
                        Text(text).contentTransition(.numericText(value: value))
                    }
                }
                .snapText(.heroNumber)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                Text(unit)
                    .snapText(.heroUnit)
                    .foregroundStyle(Color.snap.textSecondary)
                    .accessibilityHidden(editable)
            }
            .foregroundStyle(Color.snap.textPrimary)
            .frame(maxWidth: .infinity)
            stepButton("plus", label: "More \(label.lowercased())") { change(by: step) }
        }
        .snapAnimation(Snap.Motion.quick, value: value)
        .sensoryFeedback(Snap.Haptic.stepperChange, trigger: value)
    }

    private func stepButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .frame(width: Snap.Tap.logging, height: Snap.Tap.logging)
                .foregroundStyle(Color.snap.textPrimary)
                .background(Color.snap.surfaceRaised, in: .rect(cornerRadius: Snap.Radius.control))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct StepperPreview: View {
    @State private var weight = 42.5
    @State private var reps = 12.0
    var body: some View {
        PreviewSurface {
            HeroNumberStepper("Weight", value: $weight, step: 2.5, in: 0...500, unit: "kg", editable: true)
            HeroNumberStepper("Reps", value: $reps, step: 1, in: 0...100, unit: "reps")
        }
    }
}

#Preview("Dark") { StepperPreview().preferredColorScheme(.dark) }
#Preview("Light") { StepperPreview().preferredColorScheme(.light) }
#Preview("AX5") { StepperPreview().preferredColorScheme(.dark).dynamicTypeSize(.accessibility5) }
