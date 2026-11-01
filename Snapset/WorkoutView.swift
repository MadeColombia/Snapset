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
    @State private var draft: Routine?
    @State private var editingDraft = false
    @State private var countingDown: Routine?

    var body: some View {
        List {
            ForEach(routines) { routine in
                Button {
                    countingDown = routine
                } label: {
                    VStack(alignment: .leading) {
                        Text(routine.name.isEmpty ? "Untitled routine" : routine.name).font(.headline)
                        Text("\(routine.items.count) exercises").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .tint(.primary)
                .disabled(routine.items.isEmpty)
            }
            if !routines.isEmpty {
                Section {
                    Button("New routine", systemImage: "plus.circle.fill", action: newRoutine)
                }
            }
        }
        .overlay {
            if routines.isEmpty {
                ContentUnavailableView {
                    Label("No routines", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("Create a routine to plan the exercises for a workout day, then start it here.")
                } actions: {
                    Button("New routine", action: newRoutine).buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("Start workout")
        .fullScreenCover(item: $countingDown) { routine in
            // The session is created when the countdown ends, so the timer starts at 0:00.
            CountdownView {
                context.insert(WorkoutSession(routine: routine))
                try? context.save()
                countingDown = nil
            } onCancel: {
                countingDown = nil
            }
        }
        .sheet(isPresented: $editingDraft, onDismiss: discardEmptyDraft) {
            if let draft {
                NavigationStack {
                    RoutineEditorView(routine: draft)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) { Button("Done") { editingDraft = false } }
                        }
                }
            }
        }
    }

    private func newRoutine() {
        let routine = Routine(name: "New routine")
        context.insert(routine)
        draft = routine
        editingDraft = true
    }

    /// Same rule as the Routines tab: a routine closed with no exercises is thrown away.
    private func discardEmptyDraft() {
        if let draft, draft.items.isEmpty { context.delete(draft) }
        try? context.save()
        draft = nil
    }
}

struct CountdownView: View {
    static let seconds = 3
    let onFinish: () -> Void
    let onCancel: () -> Void
    @State private var remaining = seconds

    var body: some View {
        VStack(spacing: 32) {
            Text("Get ready").font(.title2.weight(.semibold)).foregroundStyle(.secondary)
            ZStack {
                Circle().stroke(.quaternary, lineWidth: 14)
                Circle()
                    .trim(from: 0, to: Double(remaining) / Double(Self.seconds))
                    .stroke(.green, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(remaining > 0 ? "\(remaining)" : "Go")
                    .font(.system(size: 120, weight: .bold, design: .rounded))
                    .contentTransition(.numericText(countsDown: true))
            }
            .frame(width: 240, height: 240)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(remaining > 0 ? "Starting in \(remaining)" : "Go")
            Button("Cancel", action: onCancel).font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .sensoryFeedback(.impact, trigger: remaining)
        .task {
            while remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }  // Cancel dismissed the cover
                withAnimation(.linear(duration: 0.3)) { remaining -= 1 }
            }
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            onFinish()
        }
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
            Section {
                VStack(spacing: 4) {
                    Label("Workout in progress", systemImage: "record.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                        .symbolEffect(.pulse)
                    Text(timerInterval: session.startedAt...Date.distantFuture, countsDown: false)
                        .font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                        .contentTransition(.numericText())
                    // A workout left open overnight shows its date, so a stale one is easy to spot.
                    let today = Calendar.current.isDateInToday(session.startedAt)
                    Text("Started \(session.startedAt.formatted(date: today ? .omitted : .abbreviated, time: .shortened)) · \(session.sets.count) sets logged")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
            }
            ForEach(Array(session.plan.enumerated()), id: \.offset) { _, planned in
                if let exercise = byID[planned.exerciseID] {
                    let sets = sets(of: exercise)
                    Section {
                        ExerciseDemo(exercise: exercise)
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
        // An alert, not a confirmationDialog: on iOS 26+ the dialog pops over the toolbar button instead of centering.
        .alert(session.sets.isEmpty ? "Discard this workout?" : "Finish this workout?", isPresented: $confirmingFinish) {
            Button("Cancel", role: .cancel) {}
            Button(session.sets.isEmpty ? "Discard" : "Finish", role: session.sets.isEmpty ? .destructive : nil, action: finish)
        } message: {
            Text(session.sets.isEmpty ? "No sets were logged, so nothing will be saved."
                                      : "\(session.sets.count) sets will be saved to your history.")
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
            result[exercise.id] = Progression.next(goal: goal, equipment: exercise.equipment, unit: unit, sets: planned.targetSets, reps: planned.targetReps,
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
        let reps = target.reps.count == 1 ? "\(target.reps.lowerBound) reps" : "\(target.reps.lowerBound)–\(target.reps.upperBound) reps"
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
