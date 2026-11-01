import SwiftUI
import SwiftData
import SnapsetUI

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
                Text("Same weights next time. Hit the top of the rep range on every set to go up.")
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
                    VStack(alignment: .leading, spacing: Snap.Spacing.xs) {
                        Text(routine.name.isEmpty ? "Untitled routine" : routine.name).snapText(.sectionTitle)
                        Text("^[\(routine.items.count) exercise](inflect: true)").snapText(.secondary)
                    }
                    .frame(minHeight: Snap.Tap.min, alignment: .leading)
                }
                .tint(Color.snap.textPrimary)
                .disabled(routine.items.isEmpty)
            }
            .listRowBackground(Color.snap.surface)
            if !routines.isEmpty {
                Section {
                    Button("New routine", systemImage: "plus.circle", action: newRoutine)
                        .frame(minHeight: Snap.Tap.min)
                }
                .listRowBackground(Color.snap.surface)
            }
        }
        .snapListBackground()
        .overlay {
            if routines.isEmpty {
                ContentUnavailableView {
                    Label("No routines", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("Create a routine to plan the exercises for a workout day, then start it here.")
                } actions: {
                    PrimaryButton("New routine", action: newRoutine).padding(.horizontal, Snap.Spacing.xl)
                }
            }
        }
        .navigationTitle("Start workout")
        .task { WorkoutActivity.end() }  // no workout running, so none should show in the Dynamic Island
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
            Text("Get ready").snapText(.sectionTitle).foregroundStyle(Color.snap.textSecondary)
            ZStack {
                Circle().stroke(Color.snap.surfaceRaised, lineWidth: 14)
                Circle()
                    .trim(from: 0, to: Double(remaining) / Double(Self.seconds))
                    .stroke(Color.snap.accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(remaining > 0 ? "\(remaining)" : "Go")
                    .font(.system(size: 120, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Color.snap.textPrimary)
                    .contentTransition(.numericText(countsDown: true))
            }
            .frame(width: 240, height: 240)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(remaining > 0 ? "Starting in \(remaining)" : "Go")
            SecondaryButton("Cancel", action: onCancel).fixedSize()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.snap.background)
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
                    if session.pausedAt == nil {
                        Label("Workout in progress", systemImage: "record.circle")
                            .snapText(.label)
                            .foregroundStyle(Color.snap.textPrimary)
                            .symbolEffect(.pulse)
                    } else {
                        Label("Paused", systemImage: "pause.circle")
                            .snapText(.label)
                            .foregroundStyle(Color.snap.statusHold)
                    }
                    // Smaller than the target weights below: the weight is the biggest number on this screen.
                    ElapsedTime(startedAt: session.startedAt, pausedAt: session.pausedAt, pausedSeconds: session.pausedSeconds)
                        .font(.system(.title2, design: .rounded, weight: .semibold).monospacedDigit())
                        .foregroundStyle(session.pausedAt == nil ? Color.snap.textPrimary : Color.snap.textSecondary)
                        .contentTransition(.numericText())
                    // A workout left open overnight shows its date, so a stale one is easy to spot.
                    let today = Calendar.current.isDateInToday(session.startedAt)
                    Text("Started \(session.startedAt.formatted(date: today ? .omitted : .abbreviated, time: .shortened)) · \(session.sets.count) sets logged")
                        .snapText(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .accessibilityElement(children: .combine)
                WorkoutControls(paused: session.pausedAt != nil, allDone: upNext == nil) {
                    session.togglePause()
                    try? context.save()
                } finish: {
                    confirmingFinish = true
                }
            }
            .listRowBackground(Color.snap.surface)
            ForEach(Array(session.plan.enumerated()), id: \.offset) { index, planned in
                if let exercise = byID[planned.exerciseID] {
                    let sets = sets(of: exercise)
                    Section {
                        ExerciseDemo(exercise: exercise)
                        if let target = targets[exercise.id] {
                            TargetRow(target: target, unit: unit)
                        }
                        ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                            SetRow(number: index + 1, weight: unit.fromKg(set.weightKg), reps: set.reps, unit: unit.rawValue)
                        }
                        .onDelete { offsets in remove(offsets.map { sets[$0] }) }

                        // Only the next exercise gets the orange button, so each screen has one accent.
                        if index == upNext {
                            PrimaryButton("Log set") { logging = exercise }
                        } else {
                            SecondaryButton("Log set", systemImage: "plus") { logging = exercise }
                        }
                    } header: {
                        HStack {
                            Text(exercise.name).snapText(.sectionTitle).foregroundStyle(Color.snap.textPrimary)
                            Spacer()
                            Text("\(sets.count) of \(planned.targetSets) sets").snapText(.secondary).monospacedDigit()
                        }
                    }
                    .listRowBackground(Color.snap.surface)
                }
            }
        }
        .snapListBackground()
        .sensoryFeedback(Snap.Haptic.setSaved, trigger: session.sets.count) { old, new in new > old }
        .navigationTitle(session.routineName ?? "Workout")
        // An alert, not a confirmationDialog: on iOS 26+ the dialog pops over the button instead of centering.
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
        // Keeps the Dynamic Island's next set and pause state in step with this screen.
        .task(id: "\(session.sets.count)-\(String(describing: session.pausedAt))-\(goal.rawValue)-\(unit.rawValue)") {
            WorkoutActivity.sync(session, in: context)
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

    /// Plan position of the first exercise with sets still to do, or nil when every planned set is logged.
    private var upNext: Int? {
        session.plan.indices.first { index in
            let planned = session.plan[index]
            return session.sets.filter { $0.exercise?.id == planned.exerciseID }.count < planned.targetSets
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
        guard session.finish(in: context) else { return }  // discarded, or a second tap
        let byID = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let trained = Set(session.sets.compactMap(\.exercise?.id))
        let goingUp = nextTargets(excluding: nil).compactMap { id, target -> String? in
            guard trained.contains(id), target.change == .increase, let kg = target.weightKg, let name = byID[id]?.name else { return nil }
            return "\(name): \(unit.format(kg: kg))"
        }
        onFinish(goingUp.sorted())
    }
}

/// Pause and Finish under the timer; sets are logged from each exercise below.
private struct WorkoutControls: View {
    let paused: Bool
    let allDone: Bool  // Finish takes the accent once every planned set is logged
    let togglePause: () -> Void
    let finish: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // Snapset buttons use a plain style, which keeps each one tappable on its own inside a List row.
        // Stacked at accessibility text sizes, where two side by side would cut off their words.
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: Snap.Spacing.s))
                                                  : AnyLayout(HStackLayout(spacing: Snap.Spacing.s))
        layout { buttons }
            .padding(.bottom, Snap.Spacing.s)
        .listRowSeparator(.hidden)
    }

    @ViewBuilder private var buttons: some View {
        SecondaryButton(paused ? "Resume" : "Pause", systemImage: paused ? "play.fill" : "pause.fill", action: togglePause)
        if allDone {
            PrimaryButton("Finish", action: finish)
        } else {
            SecondaryButton("Finish", systemImage: "checkmark", action: finish)
        }
    }
}

/// Number first, then the reason, so the next weight reads at a glance.
private struct TargetRow: View {
    let target: Progression.Target
    let unit: WeightUnit

    var body: some View {
        let reps = target.reps.count == 1 ? "\(target.reps.lowerBound) reps" : "\(target.reps.lowerBound) to \(target.reps.upperBound) reps"
        VStack(alignment: .leading, spacing: Snap.Spacing.s) {
            if let kg = target.weightKg, target.change != .start {
                HStack(alignment: .firstTextBaseline, spacing: Snap.Spacing.s) {
                    Text(unit.fromKg(kg).formatted(.number.precision(.fractionLength(0...1))))
                        .snapText(.numberMedium)
                    Text("\(unit.rawValue) × \(reps)").snapText(.body)
                }
                .foregroundStyle(Color.snap.textPrimary)
                .accessibilityElement(children: .combine)
                HStack(alignment: .firstTextBaseline, spacing: Snap.Spacing.s) {
                    StatusBadge(target.change.status)
                    Text(target.change.reason).snapText(.secondary)
                }
            } else {
                Text(reps).snapText(.numberMedium).foregroundStyle(Color.snap.textPrimary)
                Text("First time? Pick a weight you can lift for \(reps) with good form.").snapText(.secondary)
            }
        }
        .padding(.vertical, Snap.Spacing.xs)
    }
}

private extension Progression.Target.Change {
    var status: StatusBadge.Status {
        switch self {
        case .increase: .up
        case .decrease: .lighter
        case .hold, .start: .hold
        }
    }

    var reason: String {
        switch self {
        case .increase: "You hit the top of the range on every set last time. Add weight."
        case .decrease: "Missed the bottom of the range \(Progression.missesBeforeReduce) times in a row. Go a bit lighter."
        case .hold, .start: "Same weight as last time. Aim for more reps."
        }
    }
}
