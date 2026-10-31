import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("weightUnit") private var unit: WeightUnit = .kg
    @AppStorage("goal") private var goal: Goal = .muscle
    @AppStorage("experience") private var experience: Experience = .beginner
    @AppStorage("trainingDays") private var days = 3
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    var body: some View {
        NavigationStack {
            Form {
                Picker("Weight unit", selection: $unit) {
                    ForEach(WeightUnit.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                TrainingProfileSection(goal: $goal, experience: $experience, days: $days)

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
