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
    var exercise: Exercise?
    var routine: Routine?

    init(order: Int, targetSets: Int = 3, exercise: Exercise) {
        self.order = order
        self.targetSets = targetSets
        self.exercise = exercise
    }
}

struct PlannedExercise: Codable, Hashable {
    var exerciseID: String
    var targetSets: Int
}

@Model
final class WorkoutSession {
    var startedAt: Date
    var finishedAt: Date?
    // Name and plan copied, not linked, so editing or deleting a routine never touches past sessions.
    var routineName: String?
    var plan: [PlannedExercise] = []
    @Relationship(deleteRule: .cascade, inverse: \SetEntry.session) var sets: [SetEntry] = []

    static let isActive = #Predicate<WorkoutSession> { $0.finishedAt == nil }

    init(startedAt: Date = .now, routineName: String? = nil) {
        self.startedAt = startedAt
        self.routineName = routineName
    }

    convenience init(routine: Routine) {
        self.init(routineName: routine.name)
        plan = routine.items.sorted { $0.order < $1.order }.compactMap { item in
            item.exercise.map { PlannedExercise(exerciseID: $0.id, targetSets: item.targetSets) }
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
