import SwiftUI
import SwiftData

/// Shows the unfinished session if there is one (so a killed app resumes), otherwise the routine picker.
struct WorkoutView: View {
    @Query(filter: WorkoutSession.isActive, sort: \WorkoutSession.startedAt, order: .reverse) private var active: [WorkoutSession]

    var body: some View {
        NavigationStack {
            if let session = active.first {
                SessionView(session: session)
            } else {
                StartWorkoutView()
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
    @Bindable var session: WorkoutSession
    @Query private var exercises: [Exercise]
    @State private var logging: Exercise?
    @State private var confirmingFinish = false

    var body: some View {
        let byID = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        List {
            ForEach(Array(session.plan.enumerated()), id: \.offset) { _, planned in
                if let exercise = byID[planned.exerciseID] {
                    let sets = sets(of: exercise)
                    Section {
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
            SetConfirmView(exercise: exercise) { weightKg, reps in
                session.sets.append(SetEntry(exercise: exercise, weightKg: weightKg, reps: reps))
                try? context.save()  // save each set at once so a killed app loses nothing
            }
        }
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
        if session.sets.isEmpty {
            context.delete(session)
        } else {
            session.finishedAt = .now
        }
        try? context.save()
    }
}
