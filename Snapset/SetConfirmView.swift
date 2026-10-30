import SwiftUI
import SwiftData

/// The one logging screen: manual entry now, and photo logging will pre-fill it later.
struct SetConfirmView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage("weightUnit") private var unit: WeightUnit = .kg
    let exercise: Exercise
    let onLog: (_ weightKg: Double, _ reps: Int) -> Void

    @State private var weight: Double = 0  // in the display unit
    @State private var reps = 10
    @State private var hasHistory = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if !hasHistory {
                    Text("First time logging this exercise. Enter the weight you lifted.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }

                StepperCard(title: "Weight (\(unit.rawValue))",
                            minus: { weight = max(0, weight - unit.step) },
                            plus: { weight += unit.step }) {
                    TextField("0", value: $weight, format: .number.precision(.fractionLength(0...2)))
                        .keyboardType(.decimalPad)
                }

                StepperCard(title: "Reps",
                            minus: { reps = max(1, reps - 1) },
                            plus: { reps += 1 }) {
                    Text("\(reps)")
                }

                Spacer()

                Button {
                    onLog(unit.toKg(weight), reps)
                    dismiss()
                } label: {
                    Text("Log set").font(.title2.bold()).frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .task {
            guard let last = SetEntry.latest(of: exercise.id, in: context) else { return }
            hasHistory = true
            weight = (unit.fromKg(last.weightKg) * 100).rounded() / 100
            reps = last.reps
        }
    }
}

private struct StepperCard<Value: View>: View {
    let title: String
    let minus: () -> Void
    let plus: () -> Void
    @ViewBuilder let value: Value

    var body: some View {
        VStack(spacing: 8) {
            Text(title).font(.headline).foregroundStyle(.secondary)
            HStack {
                StepButton(systemImage: "minus", label: "Decrease \(title)", action: minus)
                value
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                StepButton(systemImage: "plus", label: "Increase \(title)", action: plus)
            }
        }
        .padding()
        .background(.fill.tertiary, in: .rect(cornerRadius: 20))
    }
}

private struct StepButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage).font(.title.bold()).frame(width: 64, height: 64)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .accessibilityLabel(label)
    }
}
