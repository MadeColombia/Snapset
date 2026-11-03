import ActivityKit
import Foundation
import SwiftData

/// Starts, updates and ends the workout's Live Activity (Dynamic Island and Lock Screen).
enum WorkoutActivity {
    /// Shows `session` as it is now, starting the activity or updating the one already running for it.
    /// Also keeps the rest-over and idle notifications in step, since every change to the session comes through here.
    static func sync(_ session: WorkoutSession, in context: ModelContext) {
        let state = state(of: session, in: context)
        WorkoutReminders.sync(session, upNext: state.detail)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // Going stale when the rest runs out tells the widget to go back to the workout time, even if the app is asleep by then.
        let staleDate = state.pausedAt == nil ? state.restEndsAt : nil
        let content = ActivityContent(state: state, staleDate: staleDate)
        let running = Activity<WorkoutActivityAttributes>.activities
        if let current = running.first(where: { $0.activityState == .active && $0.attributes.startedAt == session.startedAt }) {
            Task { await current.update(content) }
            return
        }
        endActivities()  // one left over from a workout that ended while the app was closed
        let attributes = WorkoutActivityAttributes(routineName: session.routineName ?? "Workout", startedAt: session.startedAt)
        _ = try? Activity.request(attributes: attributes, content: content)
    }

    /// Ends the Live Activity and cancels the workout's reminders.
    static func end() {
        WorkoutReminders.cancel()
        endActivities()
    }

    private static func endActivities() {
        for activity in Activity<WorkoutActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    /// Runs a Dynamic Island button against the workout in progress.
    @MainActor static func handle(_ button: WorkoutButton, in context: ModelContext) {
        var active = FetchDescriptor(predicate: WorkoutSession.isActive, sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        active.fetchLimit = 1
        guard let session = try? context.fetch(active).first else { return end() }
        switch button {
        case .pause:
            session.togglePause()
        case .finish:
            session.finish(in: context)
            return
        }
        try? context.save()
        sync(session, in: context)
    }

    struct NextSet {
        let exercise: Exercise
        let weightKg: Double
        let reps: Int
    }

    /// The next set shown in the Dynamic Island: the first planned exercise still short of its sets, filled in the way the log screen
    /// would be (the target for the first set, then a repeat of the last one). Nil while there is no weight to go on.
    static func nextSet(of session: WorkoutSession, in context: ModelContext) -> NextSet? {
        guard let planned = pending(in: session), let exercise = exercise(planned.exerciseID, in: context) else { return nil }
        let goal = Goal(rawValue: UserDefaults.standard.string(forKey: "goal") ?? "") ?? .muscle
        let isFirst = !session.sets.contains { $0.exercise?.id == exercise.id }
        let target = isFirst ? Progression.next(goal: goal, equipment: exercise.equipment, unit: unit, sets: planned.targetSets, reps: planned.targetReps,
                                                sessions: Progression.history(of: exercise.id, excluding: session, in: context)) : nil
        let last = SetEntry.latest(of: exercise.id, in: context)
        guard let kg = target?.weightKg ?? last?.weightKg,
              let reps = (target?.change == .hold ? nil : target?.reps.lowerBound) ?? last?.reps else { return nil }
        return NextSet(exercise: exercise, weightKg: kg, reps: reps)
    }

    private static var unit: WeightUnit {
        WeightUnit(rawValue: UserDefaults.standard.string(forKey: "weightUnit") ?? "") ?? .kg
    }

    private static func pending(in session: WorkoutSession) -> PlannedExercise? {
        session.plan.first { planned in
            session.sets.filter { $0.exercise?.id == planned.exerciseID }.count < planned.targetSets
        }
    }

    private static func exercise(_ id: String, in context: ModelContext) -> Exercise? {
        try? context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == id })).first
    }

    private static func state(of session: WorkoutSession, in context: ModelContext) -> WorkoutActivityAttributes.ContentState {
        let next = nextSet(of: session, in: context)
        let detail: String
        if let next, let planned = pending(in: session) {
            // The set number changes with every log, so a tap on Log set visibly lands even when the load repeats.
            let number = session.sets.filter { $0.exercise?.id == planned.exerciseID }.count + 1
            let load = next.weightKg > 0 ? "\(unit.format(kg: next.weightKg)) × \(next.reps)" : "\(next.reps) reps"
            detail = "Set \(number)/\(planned.targetSets): \(load) · \(next.exercise.name)"
        } else if let planned = pending(in: session), let exercise = exercise(planned.exerciseID, in: context) {
            detail = "Next: \(exercise.name) · log the first set in the app"
        } else {
            detail = "All planned sets logged"
        }
        return .init(pausedAt: session.pausedAt, pausedSeconds: session.pausedSeconds, detail: detail,
                     restEndsAt: session.restRemaining() == nil ? nil : session.restEndsAt, restSeconds: session.restSeconds)
    }
}

extension WorkoutSession {
    /// Ends the workout: thrown away when no set was logged, otherwise saved and sent to Health when that's on.
    /// Returns whether it was saved; a second call does nothing.
    @MainActor @discardableResult
    func finish(in context: ModelContext) -> Bool {
        guard finishedAt == nil, !isDeleted else { return false }
        WorkoutActivity.end()
        if sets.isEmpty {
            context.delete(self)
            try? context.save()
            return false
        }
        finishedAt = .now
        try? context.save()
        if UserDefaults.standard.object(forKey: "saveToHealth") as? Bool ?? true {
            let window = activeWindow
            Task { await Health.saveWorkout(start: window.start, end: window.end) }
        }
        return true
    }
}
