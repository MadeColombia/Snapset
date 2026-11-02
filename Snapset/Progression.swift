import Foundation
import SwiftData

/// Training goal; it sets the rep range progression works within.
enum Goal: String, CaseIterable {
    case muscle, lean, strength

    var label: String {
        switch self {
        case .muscle: "Build muscle"
        case .lean: "Get lean"
        case .strength: "Strength"
        }
    }

    var repRange: ClosedRange<Int> {
        switch self {
        case .strength: 3...6
        case .muscle: 6...12
        case .lean: 10...15
        }
    }

    /// Rest between sets, in seconds.
    /// shortcut: one rest per goal, since routines don't store a rest per exercise yet; upgrade when the editor gets a rest field (F2b).
    var restSeconds: Int {
        switch self {
        case .strength: 180
        case .muscle: 90
        case .lean: 60
        }
    }
}

/// Double progression: hit the top of the rep range on every set, then add the smallest load step.
enum Progression {
    struct LoggedSet: Equatable {
        var weightKg: Double
        var reps: Int
    }

    struct Target: Equatable {
        enum Change { case start, increase, hold, decrease }
        var change: Change
        var weightKg: Double?  // nil without history: the user finds a starting weight
        var reps: ClosedRange<Int>
        var sets: Int
        /// Why, in the numbers from last time: "You got 12 on every set. Add 2.5 kg."
        var reason: String
    }

    /// Sessions in a row that miss the bottom of the range at the same weight before going lighter.
    static let missesBeforeReduce = 2

    /// `sessions` holds one exercise's sets per past session, newest first.
    /// Fixed `reps` from the routine replace the goal's range: hit them on every set to add weight.
    static func next(goal: Goal, equipment: Equipment, unit: WeightUnit, sets: Int, reps: Int? = nil, sessions: [[LoggedSet]]) -> Target {
        let range = reps.map { $0...$0 } ?? goal.repRange
        let done = sessions.filter { !$0.isEmpty }
        guard let last = done.first, let weight = last.map(\.weightKg).max() else {
            let pick = range.lowerBound + (range.upperBound - range.lowerBound + 1) / 2
            return Target(change: .start, weightKg: nil, reps: range, sets: sets,
                          reason: "Find your starting weight: pick one you can lift \(pick) times with good form.")
        }
        // Lighter sets are warm-ups; only sets at the session's top weight count.
        let working = last.filter { $0.weightKg == weight }
        let target = { (change: Target.Change, kg: Double, reason: String) in
            Target(change: change, weightKg: kg, reps: range, sets: sets, reason: reason)
        }
        let got = working.map { "\($0.reps)" }.joined(separator: ", ")
        let at = unit.format(kg: weight)

        guard let step = step(for: equipment, unit: unit) else { return target(.hold, weight, "You got \(got). Aim for one more rep.") }
        // Work in the user's unit so targets land on numbers they can actually load.
        let current = unit.fromKg(weight)
        let onGrid = (current / step).rounded() * step

        if working.count >= sets, let fewest = working.map(\.reps).min(), fewest >= range.upperBound {
            let every = working.allSatisfy { $0.reps == fewest } ? "\(fewest)" : "\(fewest) or more"
            let heavier = unit.toKg(onGrid + step)
            // Off the grid (a weight converted from the other unit), the jump isn't one step, so name the weight instead.
            let add = abs(onGrid - current) < 0.01 ? "Add \(unit.format(kg: unit.toKg(step)))." : "Go up to \(unit.format(kg: heavier))."
            return target(.increase, heavier, "You got \(every) on every set. \(add)")
        }
        let recent = done.prefix(missesBeforeReduce)
        let missedEach = recent.count == missesBeforeReduce && recent.allSatisfy { session in
            session.map(\.weightKg).max() == weight
                && session.contains { $0.weightKg == weight && $0.reps < range.lowerBound }
        }
        if missedEach, current > 0 {
            let tenPercentLess = ((current * 0.9) / step + 1e-9).rounded(.down) * step
            let lighter = unit.toKg(max(0, min(onGrid - step, tenPercentLess)))
            return target(.decrease, lighter,
                          "Under \(range.lowerBound) reps at \(at) the last \(missesBeforeReduce) times. Try \(unit.format(kg: lighter)).")
        }
        if working.count < sets {
            return target(.hold, weight, "You did \(working.count) of \(sets) sets at \(at). Do all \(sets) to add weight.")
        }
        return target(.hold, weight, "You got \(got) at \(at). Get \(range.upperBound) on every set to add weight.")
    }

    /// A set heavier than any before it for this exercise; with no load (bodyweight), more reps than ever.
    /// The very first set is not a best, since there is nothing to beat yet.
    static func isNewBest(_ set: LoggedSet, previous: [LoggedSet]) -> Bool {
        guard let heaviest = previous.map(\.weightKg).max() else { return false }
        if heaviest > 0 || set.weightKg > 0 { return set.weightKg > heaviest + 0.001 }  // tolerance: kg stored from lb input
        return set.reps > previous.map(\.reps).max() ?? 0
    }

    /// Smallest sensible load jump, or nil when load is not what progresses.
    static func step(for equipment: Equipment, unit: WeightUnit) -> Double? {
        switch equipment {
        case .bodyweight: nil  // progress by reps; adding a belt is the user's call
        // shortcut: assumes 5 kg / 10 lb stack plates; real stacks vary, upgrade to a per-machine step if users ask
        case .machine, .cable: unit == .kg ? 5 : 10
        case .barbell, .plateLoaded, .dumbbell: unit.step
        }
    }
}

extension WorkoutSession {
    /// Whether `set` is a new best against every set of its exercise logged before it, here and in past sessions.
    func isNewBest(_ set: SetEntry, in context: ModelContext) -> Bool {
        guard let id = set.exercise?.id else { return false }
        let earlier = sets.filter { $0.exercise?.id == id && $0 != set && $0.loggedAt <= set.loggedAt }
        let previous = Progression.history(of: id, excluding: self, in: context).flatMap { $0 }
            + earlier.map { Progression.LoggedSet(weightKg: $0.weightKg, reps: $0.reps) }
        return Progression.isNewBest(.init(weightKg: set.weightKg, reps: set.reps), previous: previous)
    }
}

extension Progression {
    /// One exercise's sets grouped by session, newest session first, leaving out `current`.
    static func history(of exerciseID: String, excluding current: WorkoutSession?, in context: ModelContext) -> [[LoggedSet]] {
        let descriptor = FetchDescriptor<SetEntry>(
            predicate: #Predicate { $0.exercise?.id == exerciseID },
            sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
        )
        var sessions: [[LoggedSet]] = []
        var previous: PersistentIdentifier?
        for set in (try? context.fetch(descriptor)) ?? [] {
            guard let session = set.session, session != current else { continue }
            if session.persistentModelID != previous {
                sessions.append([])
                previous = session.persistentModelID
            }
            sessions[sessions.count - 1].append(LoggedSet(weightKg: set.weightKg, reps: set.reps))
        }
        return sessions
    }
}
