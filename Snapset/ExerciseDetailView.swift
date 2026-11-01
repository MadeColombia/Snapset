import SwiftUI
import SwiftData
import Charts

struct ExerciseDetailView: View {
    @AppStorage("weightUnit") private var unit: WeightUnit = .kg
    let exercise: Exercise
    @Query private var sets: [SetEntry]

    init(exercise: Exercise) {
        self.exercise = exercise
        let id = exercise.id
        _sets = Query(filter: #Predicate<SetEntry> { $0.exercise?.id == id }, sort: \SetEntry.loggedAt)
    }

    var body: some View {
        List {
            let drawings = exercise.drawings
            if !drawings.isEmpty {
                Section {
                    HStack {
                        ForEach(Array(drawings.enumerated()), id: \.offset) { _, drawing in
                            Image(uiImage: drawing).resizable().scaledToFit().frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.white)  // black line art needs white in dark mode too
                    .accessibilityElement()
                    .accessibilityLabel("Drawing of \(exercise.name), start and end position")
                } footer: {
                    Text("Drawing by Everkinetic, CC BY-SA 4.0")
                }
            }
            if let heaviest = sets.max(by: { ($0.weightKg, $0.reps) < ($1.weightKg, $1.reps) }),
               let best = sets.max(by: { $0.estimatedOneRepMaxKg < $1.estimatedOneRepMaxKg }) {
                Section {
                    LabeledContent("Heaviest set", value: "\(unit.format(kg: heaviest.weightKg)) × \(heaviest.reps)")
                    LabeledContent("Best estimated 1RM", value: unit.format(kg: best.estimatedOneRepMaxKg))
                }
                Section("Estimated 1RM by day") {
                    Chart(dailyBest, id: \.day) { point in
                        LineMark(x: .value("Day", point.day, unit: .day), y: .value(unit.rawValue, unit.fromKg(point.kg)))
                        PointMark(x: .value("Day", point.day, unit: .day), y: .value(unit.rawValue, unit.fromKg(point.kg)))
                    }
                    .chartXAxis {
                        // Label only training days; otherwise one day of data shows hour ticks.
                        AxisMarks(values: dailyBest.map(\.day)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        }
                    }
                    .frame(height: 220)
                }
            }
        }
        .overlay {
            if sets.isEmpty {
                ContentUnavailableView("No sets yet", systemImage: "dumbbell", description: Text("Log this exercise to see your progress."))
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var dailyBest: [(day: Date, kg: Double)] {
        Dictionary(grouping: sets) { Calendar.current.startOfDay(for: $0.loggedAt) }
            .map { (day: $0.key, kg: $0.value.map(\.estimatedOneRepMaxKg).max() ?? 0) }
            .sorted { $0.day < $1.day }
    }
}
