import SwiftUI
import SwiftData

/// Shows the unfinished session if there is one (so a killed app resumes), otherwise the routine picker.
struct WorkoutView: View {
    @Query(filter: WorkoutSession.isActive, sort: \WorkoutSession.startedAt, order: .reverse) private var active: [WorkoutSession]
    @State private var goingUp: [String]?

    var body: some View {
        NavigationStack {
            if let session = active.first {
                SessionView(session: session) { goingUp = $0 }
            } else {
                StartWorkoutView()
            }
        }
        .alert("Workout saved", isPresented: Binding(get: { goingUp != nil }, set: { if !$0 { goingUp = nil } })) {
            Button("OK") {}
        } message: {
            if let goingUp, !goingUp.isEmpty {
                Text("Going up next time:\n" + goingUp.joined(separator: "\n"))
            } else {
                Text("No weight increases yet. Hit the top of the rep range on every set to go up.")
            }
        }
    }
}

struct StartWorkoutView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Routine.createdAt) private var routines: [Routine]

    var body: some View {
        List(routines) { routine in
            Button {
                context.insert(WorkoutSession(routine: routine))
                try? context.save()
            } label: {
                VStack(alignment: .leading) {
                    Text(routine.name.isEmpty ? "Untitled routine" : routine.name).font(.headline)
                    Text("\(routine.items.count) exercises").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .tint(.primary)
            .disabled(routine.items.isEmpty)
        }
        .overlay {
            if routines.isEmpty {
                ContentUnavailableView("No routines", systemImage: "list.bullet.rectangle",
                                       description: Text("Create a routine in the Routines tab, then start it here."))
            }
        }
        .navigationTitle("Start workout")
    }
}

struct SessionView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("weightUnit") private var unit: WeightUnit = .kg
    @AppStorage("goal") private var goal: Goal = .muscle
    @AppStorage("saveToHealth") private var saveToHealth = true
    @Bindable var session: WorkoutSession
    let onFinish: (_ goingUp: [String]) -> Void
    @Query private var exercises: [Exercise]
    @State private var logging: Exercise?
    @State private var confirmingFinish = false
    @State private var targets: [String: Progression.Target] = [:]

    var body: some View {
        let byID = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        List {
            ForEach(Array(session.plan.enumerated()), id: \.offset) { _, planned in
                if let exercise = byID[planned.exerciseID] {
                    let sets = sets(of: exercise)
                    Section {
                        if let target = targets[exercise.id] {
                            TargetRow(target: target, unit: unit)
                        }
                        ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                            LabeledContent("Set \(index + 1)", value: "\(unit.format(kg: set.weightKg)) × \(set.reps)")
                        }
                        .onDelete { offsets in remove(offsets.map { sets[$0] }) }

                        Button("Log set", systemImage: "plus.circle.fill") { logging = exercise }
                    } header: {
                        HStack {
                            Text(exercise.name)
                            Spacer()
                            Text("\(sets.count)/\(planned.targetSets) sets")
                        }
                    }
                }
            }
        }
        .navigationTitle(session.routineName ?? "Workout")
        .toolbar {
            Button("Finish") { confirmingFinish = true }
        }
        .confirmationDialog("Finish this workout?", isPresented: $confirmingFinish, titleVisibility: .visible) {
            Button(session.sets.isEmpty ? "Discard empty workout" : "Finish workout", role: session.sets.isEmpty ? .destructive : nil, action: finish)
        }
        .sheet(item: $logging) { exercise in
            // The target pre-fills the first set; later sets repeat what was just lifted.
            let target = sets(of: exercise).isEmpty ? targets[exercise.id] : nil
            SetConfirmView(exercise: exercise,
                           targetKg: target?.weightKg,
                           targetReps: target?.change == .hold ? nil : target?.reps.lowerBound) { weightKg, reps in
                session.sets.append(SetEntry(exercise: exercise, weightKg: weightKg, reps: reps))
                try? context.save()  // save each set at once so a killed app loses nothing
            }
        }
        .task(id: "\(goal.rawValue)-\(unit.rawValue)") {
            targets = nextTargets(excluding: session)
        }
    }

    /// Targets per exercise from past sessions; pass nil to include this one (the post-workout summary).
    private func nextTargets(excluding current: WorkoutSession?) -> [String: Progression.Target] {
        let byID = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var result: [String: Progression.Target] = [:]
        for planned in session.plan {
            guard let exercise = byID[planned.exerciseID] else { continue }
            result[exercise.id] = Progression.next(goal: goal, equipment: exercise.equipment, unit: unit, sets: planned.targetSets,
                                                   sessions: Progression.history(of: exercise.id, excluding: current, in: context))
        }
        return result
    }

    private func sets(of exercise: Exercise) -> [SetEntry] {
        session.sets.filter { $0.exercise?.id == exercise.id }.sorted { $0.loggedAt < $1.loggedAt }
    }

    private func remove(_ removed: [SetEntry]) {
        session.sets.removeAll { removed.contains($0) }
        removed.forEach(context.delete)
        try? context.save()
    }

    private func finish() {
        guard session.finishedAt == nil, !session.isDeleted else { return }  // a second tap must not finish or save twice
        if session.sets.isEmpty {
            context.delete(session)
            try? context.save()
            return
        }
        session.finishedAt = .now
        try? context.save()
        let window = session.activeWindow

        let byID = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let trained = Set(session.sets.compactMap(\.exercise?.id))
        let goingUp = nextTargets(excluding: nil).compactMap { id, target -> String? in
            guard trained.contains(id), target.change == .increase, let kg = target.weightKg, let name = byID[id]?.name else { return nil }
            return "\(name): \(unit.format(kg: kg))"
        }
        onFinish(goingUp.sorted())
        if saveToHealth {
            Task { await Health.saveWorkout(start: window.start, end: window.end) }
        }
    }
}

private struct TargetRow: View {
    let target: Progression.Target
    let unit: WeightUnit

    var body: some View {
        let reps = "\(target.reps.lowerBound)–\(target.reps.upperBound) reps"
        switch (target.change, target.weightKg) {
        case (.start, _), (_, nil):
            Label("Find your starting weight · \(reps)", systemImage: "scope")
                .foregroundStyle(.secondary)
        case (let change, let kg?):
            Label("Target \(unit.format(kg: kg)) · \(reps)", systemImage: change.symbol)
                .foregroundStyle(change == .increase ? Color.green : change == .decrease ? Color.orange : Color.secondary)
        }
    }
}

private extension Progression.Target.Change {
    var symbol: String {
        switch self {
        case .increase: "arrow.up.circle.fill"
        case .decrease: "arrow.down.circle.fill"
        case .hold, .start: "equal.circle"
        }
    }
}
