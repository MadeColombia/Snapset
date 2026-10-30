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

@Model
final class WorkoutSession {
    var startedAt: Date
    var finishedAt: Date?
    // Name copied, not linked, so deleting a routine never touches past sessions.
    var routineName: String?
    @Relationship(deleteRule: .cascade, inverse: \SetEntry.session) var sets: [SetEntry] = []

    init(startedAt: Date = .now, routineName: String? = nil) {
        self.startedAt = startedAt
        self.routineName = routineName
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
}

/// Weights are always stored in kg; the unit only changes display and input.
enum WeightUnit: String, CaseIterable, Identifiable {
    case kg, lb

    static let poundsPerKg = 2.20462262185
    var id: String { rawValue }

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
