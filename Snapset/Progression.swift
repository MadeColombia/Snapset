import Foundation

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
    }

    /// Sessions in a row that miss the bottom of the range at the same weight before going lighter.
    static let missesBeforeReduce = 2

    /// `sessions` holds one exercise's sets per past session, newest first.
    static func next(goal: Goal, equipment: Equipment, unit: WeightUnit, sets: Int, sessions: [[LoggedSet]]) -> Target {
        let range = goal.repRange
        let done = sessions.filter { !$0.isEmpty }
        guard let last = done.first, let weight = last.map(\.weightKg).max() else {
            return Target(change: .start, weightKg: nil, reps: range, sets: sets)
        }
        // Lighter sets are warm-ups; only sets at the session's top weight count.
        let working = last.filter { $0.weightKg == weight }
        let target = { (change: Target.Change, kg: Double) in Target(change: change, weightKg: kg, reps: range, sets: sets) }

        guard let step = step(for: equipment, unit: unit) else { return target(.hold, weight) }
        // Work in the user's unit so targets land on numbers they can actually load.
        let current = unit.fromKg(weight)
        let onGrid = (current / step).rounded() * step

        if working.count >= sets, working.allSatisfy({ $0.reps >= range.upperBound }) {
            return target(.increase, unit.toKg(onGrid + step))
        }
        let recent = done.prefix(missesBeforeReduce)
        let missedEach = recent.count == missesBeforeReduce && recent.allSatisfy { session in
            session.map(\.weightKg).max() == weight
                && session.contains { $0.weightKg == weight && $0.reps < range.lowerBound }
        }
        if missedEach, current > 0 {
            let tenPercentLess = ((current * 0.9) / step + 1e-9).rounded(.down) * step
            return target(.decrease, unit.toKg(max(0, min(onGrid - step, tenPercentLess))))
        }
        return target(.hold, weight)
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
