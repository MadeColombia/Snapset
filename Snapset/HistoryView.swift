import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(filter: #Predicate<WorkoutSession> { $0.finishedAt != nil }, sort: \WorkoutSession.startedAt, order: .reverse)
    private var sessions: [WorkoutSession]

    var body: some View {
        NavigationStack {
            List(sessions) { session in
                NavigationLink(value: session) {
                    VStack(alignment: .leading) {
                        Text(session.routineName ?? "Workout").font(.headline)
                        Text("\(session.startedAt.formatted(date: .abbreviated, time: .shortened)) · \(session.sets.count) sets")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            .overlay {
                if sessions.isEmpty {
                    ContentUnavailableView("No workouts yet", systemImage: "chart.line.uptrend.xyaxis",
                                           description: Text("Finished workouts show up here."))
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: WorkoutSession.self) { SessionDetailView(session: $0) }
            .navigationDestination(for: Exercise.self) { ExerciseDetailView(exercise: $0) }
        }
    }
}

struct SessionDetailView: View {
    @AppStorage("weightUnit") private var unit: WeightUnit = .kg
    let session: WorkoutSession
    @State private var heartRate: (average: Double, max: Double)?

    var body: some View {
        let sets = session.sets.sorted { $0.loggedAt < $1.loggedAt }
        // Exercises in the order they were first logged.
        let exercises = sets.compactMap(\.exercise).reduce(into: [Exercise]()) { if !$0.contains($1) { $0.append($1) } }
        List {
            ForEach(exercises) { exercise in
                NavigationLink(value: exercise) {
                    VStack(alignment: .leading) {
                        Text(exercise.name).font(.headline)
                        Text(sets.filter { $0.exercise == exercise }.map { "\(unit.format(kg: $0.weightKg)) × \($0.reps)" }.joined(separator: ", "))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            if let heartRate {
                Section {
                    LabeledContent("Average", value: "\(Int(heartRate.average.rounded())) bpm")
                    LabeledContent("Max", value: "\(Int(heartRate.max.rounded())) bpm")
                } header: {
                    Text("Heart rate")
                } footer: {
                    Text("From Apple Health. Start a Strength Training workout on your Watch for a reading every few seconds instead of every few minutes.")
                }
            }
        }
        .navigationTitle(session.routineName ?? "Workout")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard session.finishedAt != nil else { return }
            let window = session.activeWindow
            heartRate = await Health.heartRate(from: window.start, to: window.end)
        }
    }
}
