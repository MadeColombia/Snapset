import SwiftUI

/// A large number with minus and plus buttons, for weight and reps.
public struct HeroNumberStepper: View {
    let label: String
    @Binding var value: Double
    let step: Double
    let range: ClosedRange<Double>
    let unit: String

    public init(_ label: String, value: Binding<Double>, step: Double, in range: ClosedRange<Double>, unit: String) {
        self.label = label
        self._value = value
        self.step = step
        self.range = range
        self.unit = unit
    }

    private var text: String { value.formatted(.number.precision(.fractionLength(0...1))) }

    private func change(by delta: Double) {
        value = min(max(value + delta, range.lowerBound), range.upperBound)
    }

    public var body: some View {
        HStack(spacing: Snap.Spacing.m) {
            stepButton("minus", label: "Less") { change(by: -step) }
            VStack(spacing: 0) {
                Text(text)
                    .snapText(.heroNumber)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText(value: value))
                Text(unit)
                    .snapText(.heroUnit)
                    .foregroundStyle(Color.snap.textSecondary)
            }
            .foregroundStyle(Color.snap.textPrimary)
            .frame(maxWidth: .infinity)
            stepButton("plus", label: "More") { change(by: step) }
        }
        .snapAnimation(Snap.Motion.quick, value: value)
        .sensoryFeedback(Snap.Haptic.stepperChange, trigger: value)
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
            HeroNumberStepper("Weight", value: $weight, step: 2.5, in: 0...500, unit: "kg")
            HeroNumberStepper("Reps", value: $reps, step: 1, in: 0...100, unit: "reps")
        }
    }
}

#Preview("Dark") { StepperPreview().preferredColorScheme(.dark) }
#Preview("Light") { StepperPreview().preferredColorScheme(.light) }
#Preview("AX5") { StepperPreview().preferredColorScheme(.dark).dynamicTypeSize(.accessibility5) }
