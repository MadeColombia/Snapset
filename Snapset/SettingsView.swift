import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("weightUnit") private var unit: WeightUnit = .kg
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    var body: some View {
        NavigationStack {
            Form {
                Picker("Weight unit", selection: $unit) {
                    ForEach(WeightUnit.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                Section("Exercise library") {
                    LabeledContent("Exercises", value: "\(exercises.count)")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView().modelContainer(for: Exercise.self, inMemory: true)
}
