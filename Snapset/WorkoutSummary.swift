import Foundation
import SwiftData

/// What the post-workout overview shows, worked out once when the workout finishes.
/// Plain values, so the screen, its previews and the tests don't need a live session.
struct WorkoutSummary: Identifiable {
    struct SetResult: Hashable {
        let weightKg: Double
        let reps: Int
        let loggedAt: Date
    }

    struct ExerciseResult: Identifiable, Hashable {
        let id: String
        let name: String
        let sets: [SetResult]
        /// The heaviest set last session, nil the first time this exercise is trained.
        let lastTopKg: Double?
        let isNewBest: Bool
        /// Next session's weight, only when it goes up.
        let nextKg: Double?

        /// The heaviest set (most reps on a tie), the one the overview compares and cheers.
        var top: SetResult? { sets.max { ($0.weightKg, $0.reps) < ($1.weightKg, $1.reps) } }
        var topKg: Double { top?.weightKg ?? 0 }
    }

    let id = UUID()
    let routineName: String?
    let startedAt: Date
    let finishedAt: Date
    /// The workout clock at the finish: pauses left out, rests counted.
    let activeSeconds: TimeInterval
    let setsPlanned: Int
    let exercises: [ExerciseResult]
    /// Where Health looks for heart rate: the sets plus a little warm-up and cool-down, never a whole forgotten night.
    let heartRateWindow: ClosedRange<Date>

    var setsLogged: Int { exercises.reduce(0) { $0 + $1.sets.count } }
    var newBests: [ExerciseResult] { exercises.filter(\.isNewBest) }
    var goingUp: [ExerciseResult] { exercises.filter { $0.nextKg != nil } }
    /// Set times, marked on the heart rate chart.
    var setTimes: [Date] { exercises.flatMap { $0.sets.map(\.loggedAt) }.sorted() }
}

extension WorkoutSummary {
    /// Builds the overview from a session. `nextKg` holds next session's weight for exercises going up.
    /// Exercises follow the plan, then any extra ones in the order they were first logged.
    @MainActor
    init(session: WorkoutSession, nextKg: [String: Double], in context: ModelContext, finishedAt: Date = .now) {
        let sets = session.sets.sorted { $0.loggedAt < $1.loggedAt }
        var order = session.plan.map(\.exerciseID)
        for id in sets.compactMap(\.exercise?.id) where !order.contains(id) { order.append(id) }

        exercises = order.compactMap { id in
            let mine = sets.filter { $0.exercise?.id == id }
            guard let exercise = mine.first?.exercise else { return nil }  // planned but skipped: nothing to show
            let history = Progression.history(of: id, excluding: session, in: context)
            let logged = mine.map { SetResult(weightKg: $0.weightKg, reps: $0.reps, loggedAt: $0.loggedAt) }
            let top = logged.max { ($0.weightKg, $0.reps) < ($1.weightKg, $1.reps) }
            return ExerciseResult(
                id: id,
                name: exercise.name,
                sets: logged,
                lastTopKg: history.first?.map(\.weightKg).max(),
                isNewBest: top.map { Progression.isNewBest(.init(weightKg: $0.weightKg, reps: $0.reps), previous: history.flatMap { $0 }) } ?? false,
                nextKg: nextKg[id]
            )
        }
        routineName = session.routineName
        startedAt = session.startedAt
        self.finishedAt = session.finishedAt ?? finishedAt
        activeSeconds = session.times.elapsed(at: self.finishedAt)
        setsPlanned = session.plan.reduce(0) { $0 + $1.targetSets }
        let window = session.activeWindow
        heartRateWindow = window.start...max(window.start, window.end)
    }
}
