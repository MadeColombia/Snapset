import SwiftUI
import SwiftData
import SnapsetUI
import Charts

struct HistoryView: View {
    enum Scope: Hashable { case all, routine(String), exercise(String) }

    enum Period: String, CaseIterable, Identifiable {
        case month = "4W", quarter = "3M", year = "1Y", all = "All"
        var id: Self { self }
        var days: Int? { switch self { case .month: 28; case .quarter: 91; case .year: 365; case .all: nil } }
    }

    @AppStorage("weightUnit") private var unit: WeightUnit = .kg
    @Query(sort: \SetEntry.loggedAt) private var allSets: [SetEntry]
    @State private var scope = Scope.all
    @State private var period = Period.quarter

    var body: some View {
        // shortcut: filters in memory over every set, fine for years of one person's training; move to predicates if it lags.
        let finished = allSets.filter { $0.session?.finishedAt != nil }
        let sets = filtered(finished)
        let lifts = sets.compactMap { set in
            set.exercise.map { Lift(exerciseID: $0.id, date: set.loggedAt, weightKg: set.weightKg, reps: set.reps) }
        }
        let sessions = Set(sets.compactMap(\.session)).sorted { $0.startedAt > $1.startedAt }
        let exercises = Dictionary(finished.compactMap(\.exercise).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

        NavigationStack {
            List {
                Section {
                    Picker("Show", selection: $scope) {
                        Text("All training").tag(Scope.all)
                        Section("Routines") {
                            ForEach(Set(finished.compactMap { $0.session?.routineName }).sorted(), id: \.self) {
                                Text($0).tag(Scope.routine($0))
                            }
                        }
                        Section("Exercises") {
                            ForEach(exercises.values.sorted { $0.name < $1.name }) { Text($0.name).tag(Scope.exercise($0.id)) }
                        }
                    }
                    Picker("Period", selection: $period) {
                        ForEach(Period.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.snap.surface)

                if !sets.isEmpty {
                    Section {
                        strengthChart(lifts)
                        LabeledContent("Workouts", value: "\(sessions.count)")
                        LabeledContent("Per week", value: perWeek(sessions.count, since: sets.first!.loggedAt))
                        LabeledContent("Sets", value: "\(sets.count)")
                        LabeledContent("Total lifted", value: unit.format(kg: sets.reduce(0) { $0 + $1.weightKg * Double($1.reps) }))
                    } header: {
                        Text("Strength")
                    } footer: {
                        Text("Change in your estimated best, the most you could probably lift once, from the first to the latest time each lift was trained in this period.")
                    }
                    .listRowBackground(Color.snap.surface)

                    Section("Exercises") {
                        ForEach(ProgressReport.trends(lifts).sorted { $0.days > $1.days }, id: \.exerciseID) { trend in
                            if let exercise = exercises[trend.exerciseID] {
                                NavigationLink(value: exercise) {
                                    LabeledContent {
                                        if trend.firstKg > 0 { trendLabel(trend.change) } else { Text("No weight") }
                                    } label: {
                                        Text(exercise.name)
                                        Text("\(trend.days) \(trend.days == 1 ? "day" : "days") · estimated best \(unit.format(kg: trend.latestKg))")
                                    }
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.snap.surface)

                    Section("Workouts") {
                        ForEach(sessions) { session in
                            NavigationLink(value: session) {
                                VStack(alignment: .leading) {
                                    Text(session.routineName ?? "Workout").font(.headline)
                                    Text("\(session.startedAt.formatted(date: .abbreviated, time: .shortened)) · \(session.sets.count) sets")
                                        .snapText(.secondary)
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.snap.surface)
                }
            }
            .snapListBackground()
            .overlay {
                if finished.isEmpty {
                    ContentUnavailableView("No workouts yet", systemImage: "chart.line.uptrend.xyaxis",
                                           description: Text("Finished workouts show up here."))
                } else if sets.isEmpty {
                    ContentUnavailableView("Nothing in this period", systemImage: "calendar",
                                           description: Text("Pick a longer period or another filter."))
                }
            }
            .navigationTitle("Progress")
            .navigationDestination(for: WorkoutSession.self) { SessionDetailView(session: $0) }
            .navigationDestination(for: Exercise.self) { ExerciseDetailView(exercise: $0) }
        }
    }

    private func filtered(_ sets: [SetEntry]) -> [SetEntry] {
        let start = period.days.flatMap { Calendar.current.date(byAdding: .day, value: -$0, to: .now) } ?? .distantPast
        return sets.filter { set in
            guard set.loggedAt >= start else { return false }
            switch scope {
            case .all: return true
            case .routine(let name): return set.session?.routineName == name
            case .exercise(let id): return set.exercise?.id == id
            }
        }
    }

    @ViewBuilder private func strengthChart(_ lifts: [Lift]) -> some View {
        let index = ProgressReport.strengthIndex(lifts)
        if let last = index.last, index.count > 1 {
            VStack(alignment: .leading, spacing: 8) {
                trendLabel(last.change).snapText(.numberMedium)
                indexChart(index)
            }
            .padding(.vertical, 4)
        } else {
            // A blurred example keeps the screen's shape until there is a real trend to draw.
            let example: [(day: Date, change: Double)] = [0, 0.02, 0.015, 0.04, 0.05, 0.07].enumerated().map { i, change in
                (day: Date.now.addingTimeInterval(Double(i) * 4 * 86_400), change: change)
            }
            indexChart(example)
                .blur(radius: 6)
                .accessibilityHidden(true)
                .overlay {
                    Label("Train the same lift on two different days to see your trend.", systemImage: "chart.line.uptrend.xyaxis")
                        .snapText(.body)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .padding(.vertical, 4)
        }
    }

    private func indexChart(_ index: [(day: Date, change: Double)]) -> some View {
        Chart(index, id: \.day) { point in
            LineMark(x: .value("Day", point.day, unit: .day), y: .value("Change", point.change))
            PointMark(x: .value("Day", point.day, unit: .day), y: .value("Change", point.change))
        }
        .foregroundStyle(Color.snap.textPrimary)
        .chartYAxis { AxisMarks { AxisGridLine(); AxisValueLabel(format: FloatingPointFormatStyle<Double>.Percent()) } }
        .frame(height: 200)
    }

    private func perWeek(_ count: Int, since first: Date) -> String {
        let start = period.days.flatMap { Calendar.current.date(byAdding: .day, value: -$0, to: .now) } ?? first
        let weeks = max(1, Date.now.timeIntervalSince(start) / (7 * 86_400))
        return (Double(count) / weeks).formatted(.number.precision(.fractionLength(0...1)))
    }

    private func percent(_ change: Double) -> String {
        change.formatted(.percent.precision(.fractionLength(0...1)).sign(strategy: .always(includingZero: false)))
    }

    /// Status colour always comes with an arrow, never colour alone, and never red.
    private func trendLabel(_ change: Double) -> some View {
        let (color, symbol) = change > 0 ? (Color.snap.statusUp, "arrow.up")
            : change < 0 ? (Color.snap.statusDown, "arrow.down") : (Color.snap.textSecondary, "equal")
        return Label(percent(change), systemImage: symbol)
            .foregroundStyle(color)
            .monospacedDigit()
            .accessibilityLabel(change > 0 ? "Up \(percent(change))" : change < 0 ? "Down \(percent(change))" : "No change")
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
                            .snapText(.secondary).monospacedDigit()
                    }
                }
            }
            .listRowBackground(Color.snap.surface)
            if let heartRate {
                Section {
                    LabeledContent("Average", value: "\(Int(heartRate.average.rounded())) bpm")
                    LabeledContent("Max", value: "\(Int(heartRate.max.rounded())) bpm")
                } header: {
                    Text("Heart rate")
                } footer: {
                    Text("From Apple Health. Start a strength training workout on your Watch for a reading every few seconds instead of every few minutes.")
                }
                .listRowBackground(Color.snap.surface)
            }
        }
        .snapListBackground()
        .navigationTitle(session.routineName ?? "Workout")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard session.finishedAt != nil else { return }
            let window = session.activeWindow
            heartRate = await Health.heartRate(from: window.start, to: window.end)
        }
    }
}
