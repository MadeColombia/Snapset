import Foundation

/// One logged set, reduced to what the progress overview needs.
struct Lift {
    let exerciseID: String
    let date: Date
    let weightKg: Double
    let reps: Int

    var estimatedOneRepMaxKg: Double { SetEntry.estimatedOneRepMax(weightKg: weightKg, reps: reps) }
}

struct ExerciseTrend {
    let exerciseID: String
    let days: Int
    let firstKg: Double
    let latestKg: Double

    /// Latest day's best estimated 1RM against the first day's, e.g. 0.1 for 10% stronger.
    var change: Double { firstKg > 0 ? latestKg / firstKg - 1 : 0 }
}

enum ProgressReport {
    /// Best estimated 1RM per exercise per training day, oldest first.
    static func dailyBest(_ lifts: [Lift], calendar: Calendar = .current) -> [String: [(day: Date, kg: Double)]] {
        Dictionary(grouping: lifts, by: \.exerciseID).mapValues { lifts in
            Dictionary(grouping: lifts) { calendar.startOfDay(for: $0.date) }
                .map { (day: $0.key, kg: $0.value.map(\.estimatedOneRepMaxKg).max() ?? 0) }
                .sorted { $0.day < $1.day }
        }
    }

    static func trends(_ lifts: [Lift], calendar: Calendar = .current) -> [ExerciseTrend] {
        dailyBest(lifts, calendar: calendar).compactMap { id, days in
            guard let first = days.first, let latest = days.last else { return nil }
            return ExerciseTrend(exerciseID: id, days: days.count, firstKg: first.kg, latestKg: latest.kg)
        }
    }

    /// Average change across exercises, by training day. Each exercise keeps its latest best until it is trained again,
    /// so training different lifts on different days does not make the line jump. Bodyweight sets (0 kg) are left out.
    static func strengthIndex(_ lifts: [Lift], calendar: Calendar = .current) -> [(day: Date, change: Double)] {
        let byDay = Dictionary(grouping: lifts.filter { $0.weightKg > 0 }) { calendar.startOfDay(for: $0.date) }
        var first: [String: Double] = [:]
        var latest: [String: Double] = [:]
        return byDay.keys.sorted().map { day in
            for (id, sets) in Dictionary(grouping: byDay[day] ?? [], by: \.exerciseID) {
                let best = sets.map(\.estimatedOneRepMaxKg).max() ?? 0
                if first[id] == nil { first[id] = best }
                latest[id] = best
            }
            let changes = latest.map { id, kg in kg / (first[id] ?? kg) - 1 }
            return (day, changes.reduce(0, +) / Double(changes.count))
        }
    }
}
