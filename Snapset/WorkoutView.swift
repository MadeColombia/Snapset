import SwiftUI
import SwiftData
import SnapsetUI

/// Shows the unfinished session if there is one (so a killed app resumes), otherwise the routine picker.
struct WorkoutView: View {
    @Query(filter: WorkoutSession.isActive, sort: \WorkoutSession.startedAt, order: .reverse) private var active: [WorkoutSession]
    @State private var goingUp: [String]?
    @State private var best: String?

    var body: some View {
        NavigationStack {
            if let session = active.first {
                SessionView(session: session) { goingUp = $0; best = $1 }
            } else {
                StartWorkoutView()
            }
        }
        .alert("Workout saved", isPresented: Binding(get: { goingUp != nil }, set: { if !$0 { goingUp = nil; best = nil } })) {
            Button("OK") {}
        } message: {
            // The new best is the summary's one cheer, so it leads.
            let cheer = best.map { $0 + "\n\n" } ?? ""
            if let goingUp, !goingUp.isEmpty {
                Text(cheer + "Going up next time:\n" + goingUp.joined(separator: "\n"))
            } else {
                Text(cheer + "Same weights next time. Try for one more rep.")
            }
        }
        .sensoryFeedback(Snap.Haptic.newBest, trigger: best) { _, new in new != nil }
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

/// The workout as a roadmap: one step per planned exercise, top to bottom, with planned start times.
/// The current step is open; done steps collapse; any step can be tapped to make it current.
struct SessionView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("weightUnit") private var unit: WeightUnit = .kg
    @AppStorage("goal") private var goal: Goal = .muscle
    @Bindable var session: WorkoutSession
    let onFinish: (_ goingUp: [String], _ best: String?) -> Void
    @Query private var exercises: [Exercise]
    @State private var sheet: Sheet?
    @AppStorage("openLogSet") private var openLogSet = false  // set by Log set in the Dynamic Island
    @State private var confirmingFinish = false
    @State private var targets: [String: Progression.Target] = [:]
    @State private var chosen: Int?  // a step the lifter tapped; nil follows the plan
    @State private var restEnds: Date?
    @State private var restTotal: TimeInterval = 0
    @State private var toast: Toast?

    init(session: WorkoutSession, restingUntil: Date? = nil, onFinish: @escaping (_ goingUp: [String], _ best: String?) -> Void) {
        self.session = session
        self.onFinish = onFinish
        _restEnds = State(initialValue: restingUntil)
        // The goal's full rest, so a rest already under way shows how much of it is left.
        let goal = Goal(rawValue: UserDefaults.standard.string(forKey: "goal") ?? "") ?? .muscle
        _restTotal = State(initialValue: max(Double(goal.restSeconds), restingUntil?.timeIntervalSinceNow.rounded(.up) ?? 0))
    }

    enum Sheet: Identifiable {
        case log(Exercise)
        case edit(SetEntry)

        var id: PersistentIdentifier {
            switch self {
            case .log(let exercise): exercise.persistentModelID
            case .edit(let set): set.persistentModelID
            }
        }
    }

    struct Toast: Equatable {
        let id = UUID()
        let message: String
        let isBest: Bool
        let undo: () -> Void

        static func == (a: Toast, b: Toast) -> Bool { a.id == b.id }
    }

    var body: some View {
        let byID = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let current = chosen ?? upNext
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: Snap.Spacing.xl) {
                    header
                    VStack(spacing: 0) {
                        ForEach(Array(session.plan.enumerated()), id: \.offset) { index, planned in
                            if let exercise = byID[planned.exerciseID] {
                                step(index: index, planned: planned, exercise: exercise, current: current)
                                    .id(index)
                            }
                        }
                    }
                }
                .padding(Snap.Spacing.l)
                .padding(.bottom, toast == nil ? 0 : 80)  // room to scroll the last step clear of the toast
            }
            .onAppear { if let current { proxy.scrollTo(current, anchor: .top) } }
            .onChange(of: current) { _, new in
                if let new { withAnimation(Snap.Motion.standard) { proxy.scrollTo(new, anchor: .top) } }
            }
        }
        .background(Color.snap.background)
        .snapAnimation(value: current)
        .snapAnimation(value: restEnds)
        .overlay(alignment: .bottom) {
            if let toast {
                UndoToast(toast.message, isBest: toast.isBest) {
                    self.toast = nil
                    toast.undo()
                }
                    .padding(Snap.Spacing.l)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .snapAnimation(Snap.Motion.quick, value: toast)
        .sensoryFeedback(trigger: toast) { _, new in new.map { $0.isBest ? Snap.Haptic.newBest : Snap.Haptic.setSaved } }
        .task(id: toast?.id) {
            guard toast != nil else { return }
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled { toast = nil }
        }
        .task(id: restEnds) {
            guard let restEnds else { return }
            try? await Task.sleep(for: .seconds(max(0, restEnds.timeIntervalSinceNow)))
            // A pause holds the rest; resuming moves its end and restarts this task.
            if !Task.isCancelled, session.pausedAt == nil { self.restEnds = nil }
        }
        .onChange(of: session.pausedAt) { old, new in
            if let old, new == nil, let restEnds { self.restEnds = restEnds.addingTimeInterval(Date.now.timeIntervalSince(old)) }
        }
        .navigationTitle(session.routineName ?? "Workout")
        // An alert, not a confirmationDialog: on iOS 26+ the dialog pops over the button instead of centering.
        .alert(session.sets.isEmpty ? "Discard this workout?" : "Finish this workout?", isPresented: $confirmingFinish) {
            Button("Cancel", role: .cancel) {}
            Button(session.sets.isEmpty ? "Discard" : "Finish", role: session.sets.isEmpty ? .destructive : nil, action: finish)
        } message: {
            Text(session.sets.isEmpty ? "No sets were logged, so nothing will be saved."
                                      : "\(session.sets.count) sets will be saved to your history.")
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .log(let exercise):
                // The target pre-fills the first set; later sets repeat what was just lifted.
                let target = sets(of: exercise).isEmpty ? targets[exercise.id] : nil
                SetConfirmView(exercise: exercise,
                               targetKg: target?.weightKg,
                               targetReps: target?.change == .hold ? nil : target?.reps.lowerBound) { weightKg, reps in
                    log(exercise, weightKg: weightKg, reps: reps)
                }
            case .edit(let set):
                if let exercise = set.exercise {
                    SetConfirmView(exercise: exercise, editing: set, onDelete: { delete(set) }) { weightKg, reps in
                        change(set, weightKg: weightKg, reps: reps)
                    }
                }
            }
        }
        .onChange(of: openLogSet, initial: true) { _, open in
            guard open else { return }
            openLogSet = false
            let byID = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            if let index = chosen ?? upNext, let exercise = byID[session.plan[index].exerciseID] { sheet = .log(exercise) }
        }
        // Keeps the Dynamic Island's next set and pause state in step with this screen.
        .task(id: "\(session.sets.count)-\(String(describing: session.pausedAt))-\(goal.rawValue)-\(unit.rawValue)") {
            WorkoutActivity.sync(session, in: context)
        }
        .task(id: "\(goal.rawValue)-\(unit.rawValue)") {
            targets = nextTargets(excluding: session)
        }
    }

    private var header: some View {
        VStack(spacing: Snap.Spacing.m) {
            VStack(spacing: Snap.Spacing.xs) {
                // The workout clock is the screen's main number. Paused, it turns the resume colour; the Resume button says the word.
                ElapsedTime(startedAt: session.startedAt, pausedAt: session.pausedAt, pausedSeconds: session.pausedSeconds)
                    .snapText(.heroNumber)
                    .foregroundStyle(session.pausedAt == nil ? Color.snap.textPrimary : Color.snap.actionResume)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .accessibilityLabel(session.pausedAt == nil ? "Workout time" : "Workout paused")
                // A workout left open overnight shows its date, so a stale one is easy to spot.
                let today = Calendar.current.isDateInToday(session.startedAt)
                Text("Started \(session.startedAt.formatted(date: today ? .omitted : .abbreviated, time: .shortened)) · \(session.sets.count) sets logged")
                    .snapText(.secondary)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            WorkoutControls(paused: session.pausedAt != nil) {
                session.togglePause()
                try? context.save()
            } finish: {
                confirmingFinish = true
            }
        }
    }

    @ViewBuilder
    private func step(index: Int, planned: PlannedExercise, exercise: Exercise, current: Int?) -> some View {
        let logged = sets(of: exercise)
        let done = logged.count >= planned.targetSets
        let target = targets[exercise.id]
        let reps = (target?.reps).map(Self.repsText) ?? "\(planned.targetReps ?? goal.repRange.lowerBound) reps"
        let state: RoadmapStepState = index == current ? .current : done ? .done : .upcoming
        let detail = switch state {
        case .done: "Done. \(logged.count) sets of \(exercise.name.lowercased())."
        case _ where !logged.isEmpty: "\(logged.count) of \(planned.targetSets) sets · \(reps)"
        default: "\(planned.targetSets) sets · about \(minutes(for: planned)) min"
        }
        RoadmapStep(title: exercise.name, detail: detail, state: state,
                    isLast: index == session.plan.count - 1, onSelect: { chosen = index }) {
            if let restEnds {
                // Between sets the step goes quiet: the countdown and what comes next.
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    let pausedAt = session.pausedAt
                    RestTimer(remaining: restEnds.timeIntervalSince(pausedAt ?? timeline.date), total: restTotal,
                              paused: pausedAt != nil, next: nextLine) {
                        self.restEnds = nil
                    } onAddThirty: {
                        self.restEnds = restEnds.addingTimeInterval(30)
                        restTotal = max(restTotal, restEnds.addingTimeInterval(30).timeIntervalSince(pausedAt ?? .now))
                    }
                }
                setRows(logged)
            } else {
                ExerciseDemo(exercise: exercise)
                if target?.change == .start {
                    Text("First time? Watch the loop, then go light.").snapText(.secondary)
                }
                if let target { TargetBlock(target: target, unit: unit) }
                setRows(logged)
                // Only the step with sets still to do gets the orange button; while paused, Resume has it.
                if done {
                    SecondaryButton("Log another set", systemImage: "plus") { sheet = .log(exercise) }
                } else {
                    PrimaryButton("Log set", style: session.pausedAt == nil ? .accent : .neutral) { sheet = .log(exercise) }
                }
            }
        }
    }

    private func setRows(_ logged: [SetEntry]) -> some View {
        ForEach(Array(logged.enumerated()), id: \.element.id) { index, set in
            Button { sheet = .edit(set) } label: {
                SetRow(number: index + 1, weight: unit.fromKg(set.weightKg), reps: set.reps, unit: unit.rawValue)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Edit this set")
            .contextMenu {
                Button("Edit set", systemImage: "pencil") { sheet = .edit(set) }
                Button("Delete set", systemImage: "trash") { delete(set) }
            }
        }
    }

    static func repsText(_ reps: ClosedRange<Int>) -> String {
        reps.count == 1 ? "\(reps.lowerBound) reps" : "\(reps.lowerBound) to \(reps.upperBound) reps"
    }

    /// About how long a step takes: every set plus the rest after it.
    private func minutes(for planned: PlannedExercise) -> Int {
        max(1, Int((Double(planned.targetSets * (Self.secondsPerSet + goal.restSeconds)) / 60).rounded()))
    }

    /// shortcut: a fixed guess at how long one set takes; upgrade once timed sets are measured.
    private static let secondsPerSet = 40

    /// "Next: 42.5 kg × 10" under the rest timer: another set of the current exercise, or the first set of the next one.
    private var nextLine: String? {
        let byID = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        if let index = chosen ?? upNext, let exercise = byID[session.plan[index].exerciseID],
           sets(of: exercise).count < session.plan[index].targetSets, let last = sets(of: exercise).last {
            return "Next: " + load(kg: last.weightKg, reps: last.reps)
        }
        guard let index = upNext, let exercise = byID[session.plan[index].exerciseID] else { return nil }
        guard let target = targets[exercise.id], let kg = target.weightKg else { return "Next: \(exercise.name)" }
        return "Next: \(exercise.name), " + load(kg: kg, reps: target.reps.lowerBound)
    }

    private func load(kg: Double, reps: Int) -> String {
        kg > 0 ? "\(unit.format(kg: kg)) × \(reps)" : "\(reps) reps"
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

    private func log(_ exercise: Exercise, weightKg: Double, reps: Int) {
        let entry = SetEntry(exercise: exercise, weightKg: weightKg, reps: reps)
        session.sets.append(entry)
        try? context.save()  // save each set at once so a killed app loses nothing
        let isBest = session.isNewBest(entry, in: context)
        toast = Toast(message: isBest ? "New best: \(load(kg: weightKg, reps: reps)) on \(exercise.name.lowercased())!" : "Set saved",
                      isBest: isBest) {
            restEnds = nil
            remove(entry)
        }
        // A finished step hands over to the next one with sets to do.
        if let index = chosen, sets(of: exercise).count >= session.plan[index].targetSets { chosen = nil }
        restTotal = Double(goal.restSeconds)
        restEnds = upNext == nil ? nil : .now.addingTimeInterval(restTotal)
    }

    private func change(_ set: SetEntry, weightKg: Double, reps: Int) {
        let old = (set.weightKg, set.reps)
        set.weightKg = weightKg
        set.reps = reps
        try? context.save()
        // Checked again, so a corrected typo can make (or stop being) a best.
        let isBest = set.exercise.map { exercise in
            session.isNewBest(set, in: context) ? "New best: \(load(kg: weightKg, reps: reps)) on \(exercise.name.lowercased())!" : nil
        } ?? nil
        toast = Toast(message: isBest ?? "Set updated", isBest: isBest != nil) {
            set.weightKg = old.0
            set.reps = old.1
            try? context.save()
        }
    }

    private func delete(_ set: SetEntry) {
        guard let exercise = set.exercise else { return remove(set) }
        let copy = (set.weightKg, set.reps, set.loggedAt)
        remove(set)
        toast = Toast(message: "Set deleted", isBest: false) {
            session.sets.append(SetEntry(exercise: exercise, weightKg: copy.0, reps: copy.1, loggedAt: copy.2))
            try? context.save()
        }
    }

    private func remove(_ set: SetEntry) {
        session.sets.removeAll { $0 == set }
        context.delete(set)
        try? context.save()
    }

    private func finish() {
        let byID = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        // The first exercise (in plan order) with a heavier top set than ever is the summary's one cheer.
        let best = session.plan.lazy.compactMap { planned -> String? in
            guard let exercise = byID[planned.exerciseID],
                  let top = sets(of: exercise).max(by: { ($0.weightKg, $0.reps) < ($1.weightKg, $1.reps) }),
                  Progression.isNewBest(.init(weightKg: top.weightKg, reps: top.reps),
                                        previous: Progression.history(of: exercise.id, excluding: session, in: context).flatMap { $0 })
            else { return nil }
            return "New best: \(load(kg: top.weightKg, reps: top.reps)) on \(exercise.name.lowercased())!"
        }.first
        guard session.finish(in: context) else { return }  // discarded, or a second tap
        let trained = Set(session.sets.compactMap(\.exercise?.id))
        let goingUp = nextTargets(excluding: nil).compactMap { id, target -> String? in
            guard trained.contains(id), target.change == .increase, let kg = target.weightKg, let name = byID[id]?.name else { return nil }
            return "\(name): \(unit.format(kg: kg))"
        }
        onFinish(goingUp.sorted(), best)
    }
}

/// Pause or Resume, and Finish, under the timer, each in its action colour; sets are logged from the current step below.
private struct WorkoutControls: View {
    let paused: Bool
    let togglePause: () -> Void
    let finish: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // Stacked at accessibility text sizes, where two side by side would cut off their words.
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: Snap.Spacing.s))
                                                  : AnyLayout(HStackLayout(spacing: Snap.Spacing.s))
        layout {
            if paused {
                PrimaryButton("Resume", systemImage: "play.fill", style: .resume, action: togglePause)
            } else {
                PrimaryButton("Pause", systemImage: "pause.fill", style: .pause, action: togglePause)
            }
            PrimaryButton("Finish", systemImage: "checkmark", style: .finish, action: finish)
        }
    }
}

/// Number first, then the reason, so the next weight reads at a glance.
private struct TargetBlock: View {
    let target: Progression.Target
    let unit: WeightUnit

    var body: some View {
        let reps = SessionView.repsText(target.reps)
        VStack(alignment: .leading, spacing: Snap.Spacing.s) {
            if let kg = target.weightKg, target.change != .start {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: Snap.Spacing.s) {
                        Text(unit.fromKg(kg).formatted(.number.precision(.fractionLength(0...1)))).snapText(.heroNumber)
                        Text(unit.rawValue).snapText(.heroUnit)
                    }
                    Text("× \(reps) · \(target.sets) sets").snapText(.body)
                }
                .foregroundStyle(Color.snap.textPrimary)
                .accessibilityElement(children: .combine)
                StatusBadge(target.change.status)
            } else {
                Text(reps).snapText(.numberMedium).foregroundStyle(Color.snap.textPrimary)
            }
            Text(target.reason).snapText(.secondary)
        }
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
}
