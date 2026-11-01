import SwiftUI
import SwiftData
import SnapsetUI

/// The one logging screen: manual entry now, and photo logging will pre-fill it later.
struct SetConfirmView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage("weightUnit") private var unit: WeightUnit = .kg
    let exercise: Exercise
    var targetKg: Double? = nil  // from the progression engine; otherwise the last set pre-fills
    var targetReps: Int? = nil
    var editing: SetEntry? = nil  // edit mode: pre-fills this set's values and offers Delete
    var onDelete: (() -> Void)? = nil
    let onLog: (_ weightKg: Double, _ reps: Int) -> Void

    @State private var weight: Double = 0  // in the display unit
    @State private var reps = 10
    @State private var hasHistory = false
    @State private var logged = false

    var body: some View {
        NavigationStack {
            VStack(spacing: Snap.Spacing.xl) {
                if !hasHistory {
                    Text("First time logging this exercise. Enter the weight you lifted.")
                        .snapText(.secondary).multilineTextAlignment(.center)
                }

                HeroNumberStepper("Weight", value: $weight, step: unit.step, in: 0...9_999, unit: unit.rawValue, editable: true)
                HeroNumberStepper("Reps", value: Binding(get: { Double(reps) }, set: { reps = Int($0) }),
                                  step: 1, in: 1...999, unit: "reps")

                Spacer(minLength: 0)

                PrimaryButton(editing == nil ? "Save set" : "Save changes") {
                    guard !logged else { return }  // a double tap must log one set, not two
                    logged = true
                    onLog(unit.toKg(weight), reps)
                    dismiss()
                }
                if let onDelete {
                    // No dialog: the session screen offers Undo.
                    Button("Delete set", systemImage: "trash") {
                        guard !logged else { return }
                        logged = true
                        onDelete()
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundStyle(Color.snap.textPrimary)
                    .frame(minHeight: Snap.Tap.min)
                }
            }
            .padding(Snap.Spacing.l)
            .background(Color.snap.surface)
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .task {
            if let editing {
                hasHistory = true
                weight = (unit.fromKg(editing.weightKg) * 100).rounded() / 100
                reps = editing.reps
                return
            }
            let last = SetEntry.latest(of: exercise.id, in: context)
            hasHistory = last != nil
            if let kg = targetKg ?? last?.weightKg {
                weight = (unit.fromKg(kg) * 100).rounded() / 100
            }
            if let targetReps = targetReps ?? last?.reps {
                reps = targetReps
            }
        }
    }
}
