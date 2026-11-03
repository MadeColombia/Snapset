import Foundation
import SwiftData

enum Equipment: String, Codable, CaseIterable {
    case machine      // pin-stack machine, the only type photo logging covers in v1
    case cable        // pin-stack cable station
    case plateLoaded
    case barbell
    case dumbbell
    case bodyweight

    var isPinStack: Bool { self == .machine || self == .cable }

    var label: String {
        switch self {
        case .machine: "Machine"
        case .cable: "Cable"
        case .plateLoaded: "Plate-loaded"
        case .barbell: "Barbell"
        case .dumbbell: "Dumbbell"
        case .bodyweight: "Bodyweight"
        }
    }
}

@Model
final class Exercise {
    @Attribute(.unique) var id: String
    var name: String
    var equipmentRaw: String

    var equipment: Equipment { Equipment(rawValue: equipmentRaw) ?? .machine }

    init(id: String, name: String, equipment: Equipment) {
        self.id = id
        self.name = name
        self.equipmentRaw = equipment.rawValue
    }
}

@Model
final class Routine {
    var name: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \RoutineItem.routine) var items: [RoutineItem] = []

    init(name: String, createdAt: Date = .now) {
        self.name = name
        self.createdAt = createdAt
    }
}

@Model
final class RoutineItem {
    var order: Int
    var targetSets: Int
    var targetReps: Int?  // nil follows the goal's rep range
    var exercise: Exercise?
    var routine: Routine?

    init(order: Int, targetSets: Int = 3, targetReps: Int? = nil, exercise: Exercise) {
        self.order = order
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.exercise = exercise
    }
}

struct PlannedExercise: Codable, Hashable {
    var exerciseID: String
    var targetSets: Int
    var targetReps: Int?
}

@Model
final class WorkoutSession {
    var startedAt: Date
    var finishedAt: Date?
    // Name and plan copied, not linked, so editing or deleting a routine never touches past sessions.
    var routineName: String?
    var plan: [PlannedExercise] = []
    var pausedAt: Date?
    var pausedSeconds: Double = 0  // finished pauses, left out of the workout time
    // The rest between sets lives here, not in a screen, so the Live Activity, the mini bar and a relaunched app all see it.
    var restEndsAt: Date?
    var restSeconds: Double = 0  // the rest's full length, for the ring
    @Relationship(deleteRule: .cascade, inverse: \SetEntry.session) var sets: [SetEntry] = []

    static let isActive = #Predicate<WorkoutSession> { $0.finishedAt == nil }

    init(startedAt: Date = .now, routineName: String? = nil) {
        self.startedAt = startedAt
        self.routineName = routineName
    }

    /// The time actually spent training, for Health and heart rate: a session left open overnight
    /// must not become a 14-hour workout. Pads 15 minutes around the first and last set for warm-up and the final rest.
    var activeWindow: (start: Date, end: Date) {
        let end = finishedAt ?? .now
        let times = sets.map(\.loggedAt)
        guard let first = times.min(), let last = times.max() else { return (startedAt, end) }
        let pad: TimeInterval = 15 * 60
        return (max(startedAt, first - pad), min(end, last + pad))
    }

    func togglePause(at now: Date = .now) {
        if let pausedAt {
            let paused = now.timeIntervalSince(pausedAt)
            pausedSeconds += paused
            self.pausedAt = nil
            // A pause holds the rest too: what was left when it started is still left. A rest that had already run out ends here.
            if let restEndsAt { self.restEndsAt = restEndsAt > pausedAt ? restEndsAt.addingTimeInterval(paused) : nil }
        } else {
            pausedAt = now
        }
    }

    /// When the workout clock reads 0:00, pauses left out. The rest is lined up with it, so both timers tick together.
    var clockStart: Date { startedAt.addingTimeInterval(pausedSeconds) }

    /// Starts a rest of `seconds`. Logging a set means training again, so a paused workout resumes first;
    /// otherwise the resume would add the whole pause to a rest that only started now.
    func startRest(_ seconds: Double, at now: Date = .now) {
        if pausedAt != nil { togglePause(at: now) }
        // Rounded up to a whole second of the workout clock, so the rest and the clock change digits at the same moment.
        let end = clockStart.addingTimeInterval((now.timeIntervalSince(clockStart) + seconds).rounded(.up))
        restEndsAt = end
        restSeconds = end.timeIntervalSince(now).rounded()
    }

    /// Seconds of rest left, frozen while paused; nil when no rest is running.
    func restRemaining(at now: Date = .now) -> TimeInterval? {
        guard let restEndsAt else { return nil }
        let left = restEndsAt.timeIntervalSince(pausedAt ?? now)
        return left > 0 ? left : nil
    }

    func addRest(_ seconds: Double, at now: Date = .now) {
        guard let restEndsAt else { return }
        self.restEndsAt = restEndsAt.addingTimeInterval(seconds)
        restSeconds = max(restSeconds, (restRemaining(at: now) ?? 0).rounded())
    }

    func endRest() {
        restEndsAt = nil
    }

    convenience init(routine: Routine) {
        self.init(routineName: routine.name)
        plan = routine.items.sorted { $0.order < $1.order }.compactMap { item in
            item.exercise.map { PlannedExercise(exerciseID: $0.id, targetSets: item.targetSets, targetReps: item.targetReps) }
        }
    }
}

@Model
final class SetEntry {
    var weightKg: Double
    var reps: Int
    var loggedAt: Date
    var exercise: Exercise?
    var session: WorkoutSession?

    init(exercise: Exercise, weightKg: Double, reps: Int, loggedAt: Date = .now) {
        self.exercise = exercise
        self.weightKg = weightKg
        self.reps = reps
        self.loggedAt = loggedAt
    }

    /// Epley formula; a single rep is already the max, so it is returned as is.
    static func estimatedOneRepMax(weightKg: Double, reps: Int) -> Double {
        reps <= 1 ? weightKg : weightKg * (1 + Double(reps) / 30)
    }

    var estimatedOneRepMaxKg: Double { Self.estimatedOneRepMax(weightKg: weightKg, reps: reps) }

    /// Most recent set of this exercise across all sessions, used to pre-fill the confirm screen.
    static func latest(of exerciseID: String, in context: ModelContext) -> SetEntry? {
        var descriptor = FetchDescriptor<SetEntry>(
            predicate: #Predicate { $0.exercise?.id == exerciseID },
            sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}

/// Weights are always stored in kg; the unit only changes display and input.
enum WeightUnit: String, CaseIterable, Identifiable {
    case kg, lb

    static let poundsPerKg = 2.20462262185
    var id: String { rawValue }
    var step: Double { self == .kg ? 2.5 : 5 }

    func fromKg(_ kg: Double) -> Double { self == .kg ? kg : kg * Self.poundsPerKg }
    func toKg(_ value: Double) -> Double { self == .kg ? value : value / Self.poundsPerKg }
    func format(kg: Double) -> String { "\(fromKg(kg).formatted(.number.precision(.fractionLength(0...1)))) \(rawValue)" }
}

enum Seed {
    private struct Row: Decodable { let id: String; let name: String; let equipment: Equipment }

    /// Inserts any bundled exercise not already stored, so it is safe to run on every launch.
    static func exercises(into context: ModelContext, bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: "exercises", withExtension: "json") else { return }
        let rows = try JSONDecoder().decode([Row].self, from: Data(contentsOf: url))
        let existing = Set(try context.fetch(FetchDescriptor<Exercise>()).map(\.id))
        for row in rows where !existing.contains(row.id) {
            context.insert(Exercise(id: row.id, name: row.name, equipment: row.equipment))
        }
        try context.save()
    }
}
