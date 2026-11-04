import SwiftUI

/// A large number with minus and plus buttons, for weight and reps.
public struct HeroNumberStepper: View {
    let label: String
    @Binding var value: Double
    let step: Double
    let range: ClosedRange<Double>
    let unit: String
    let editable: Bool
    @State private var typing = false
    @State private var draft = ""  // what is typed; read on every key so a step right after typing builds on it
    @FocusState private var fieldFocused: Bool

    /// With `editable`, tapping the number opens the keyboard so a weight can be typed as well as stepped.
    /// Until then it is plain text, so stepping rolls the digits exactly like a non-editable stepper.
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

    /// Reads a typed number in the user's locale ("47,5" or "47.5").
    static func parse(_ typed: String) -> Double? {
        let trimmed = typed.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return (try? format.parseStrategy.parse(trimmed)) ?? Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }

    private func change(by delta: Double) {
        typing = false  // a step ends typing, so the new number rolls in
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
                    if typing {
                        TextField("0", text: $draft)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .focused($fieldFocused)
                            .onAppear { draft = text; fieldFocused = true }
                            .onChange(of: draft) { _, typed in
                                guard let number = Self.parse(typed) else { return }
                                value = min(max(number, range.lowerBound), range.upperBound)
                            }
                            .onChange(of: fieldFocused) { _, focused in if !focused { typing = false } }
                            .accessibilityLabel("\(label) in \(unit)")
                    } else if editable {
                        Button { typing = true } label: { number }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(label), \(text) \(unit)")
                            .accessibilityHint("Double tap to type it.")
                    } else {
                        number
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
        .sensoryFeedback(Snap.Haptic.stepperChange, trigger: value) { _, _ in !typing }  // the keyboard already clicks
    }

    private var number: some View {
        Text(text).contentTransition(.numericText(value: value))
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
