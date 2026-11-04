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
    /// The finished session, to store the effort picked on the overview; nil in previews.
    var sessionID: PersistentIdentifier?
    let routineName: String?
    let startedAt: Date
    let finishedAt: Date
    /// The workout clock at the finish: pauses left out, rests counted.
    let activeSeconds: TimeInterval
    let setsPlanned: Int
    let exercises: [ExerciseResult]
    /// Where Health looks for heart rate: the sets plus a little warm-up and cool-down, never a whole forgotten night.
    let heartRateWindow: ClosedRange<Date>
    /// The rest the goal asks for between sets.
    var targetRestSeconds: TimeInterval = 90

    var setsLogged: Int { exercises.reduce(0) { $0 + $1.sets.count } }
    var newBests: [ExerciseResult] { exercises.filter(\.isNewBest) }
    var goingUp: [ExerciseResult] { exercises.filter { $0.nextKg != nil } }
    /// Set times, marked on the heart rate chart.
    var setTimes: [Date] { exercises.flatMap { $0.sets.map(\.loggedAt) }.sorted() }

    // MARK: Rest

    /// Gaps between back-to-back sets of the same exercise: the real rests. Over 15 minutes is a break, not a rest.
    var restGaps: [TimeInterval] {
        exercises.flatMap { result in
            zip(result.sets, result.sets.dropFirst()).map { $1.loggedAt.timeIntervalSince($0.loggedAt) }
        }
        .filter { $0 > 0 && $0 <= 15 * 60 }
    }

    var averageRest: TimeInterval? {
        let gaps = restGaps
        return gaps.isEmpty ? nil : gaps.reduce(0, +) / Double(gaps.count)
    }

    enum RestVerdict: Equatable { case short, onPoint, long }

    /// Within 25% under to 50% over the goal's rest is on point; resting long is more common, so it gets more room.
    var restVerdict: RestVerdict? {
        guard let average = averageRest else { return nil }
        if average < targetRestSeconds * 0.75 { return .short }
        if average > targetRestSeconds * 1.5 { return .long }
        return .onPoint
    }

    // MARK: Highlight

    /// The one thing worth shouting about, best first: the biggest new best, a weight going up, every set done.
    var highlight: (title: String, detail: String) {
        let gain = { (result: ExerciseResult) in result.topKg - (result.lastTopKg ?? result.topKg) }
        if let best = newBests.max(by: { gain($0) < gain($1) }) {
            let detail = gain(best) > 0 ? "Top set \(Self.kg(gain(best))) heavier than last time." : "Heavier than ever."
            return ("\(best.name) got the upgrade!", detail)
        }
        if let up = goingUp.first, let next = up.nextKg {
            return ("\(up.name) goes up next time", "You earned \(Self.kg(next)). Nice work.")
        }
        if setsPlanned > 0, setsLogged >= setsPlanned {
            return ("Every set, done", "All \(setsPlanned) planned sets logged.")
        }
        return ("Showing up is the win", "Same weights next time. Try for one more rep.")
    }

    private static func kg(_ value: Double) -> String {
        UserDefaults.standard.string(forKey: "weightUnit").flatMap(WeightUnit.init(rawValue:)).map { $0.format(kg: value) }
            ?? WeightUnit.kg.format(kg: value)
    }
}

extension WorkoutSummary {
    /// Builds the overview from a session. `nextKg` holds next session's weight for exercises going up.
    /// Exercises follow the plan, then any extra ones in the order they were first logged.
    @MainActor
    init(session: WorkoutSession, nextKg: [String: Double], targetRestSeconds: TimeInterval = 90,
         in context: ModelContext, finishedAt: Date = .now) {
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
        self.targetRestSeconds = targetRestSeconds
        sessionID = session.persistentModelID
    }
}
