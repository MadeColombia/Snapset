import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Every routine and workout as one JSON file, for Export and Import in Settings.
struct Backup: Codable {
    struct Item: Codable { var order: Int; var targetSets: Int; var exerciseID: String }
    struct RoutineRecord: Codable { var name: String; var createdAt: Date; var items: [Item] }
    struct SetRecord: Codable { var exerciseID: String; var weightKg: Double; var reps: Int; var loggedAt: Date }
    struct SessionRecord: Codable {
        var startedAt: Date
        var finishedAt: Date?
        var routineName: String?
        var plan: [PlannedExercise]
        var sets: [SetRecord]
    }

    var version = 1
    var routines: [RoutineRecord]
    var sessions: [SessionRecord]

    init(context: ModelContext) throws {
        routines = try context.fetch(FetchDescriptor<Routine>()).map { routine in
            RoutineRecord(name: routine.name, createdAt: routine.createdAt, items: routine.items.compactMap { item in
                item.exercise.map { Item(order: item.order, targetSets: item.targetSets, exerciseID: $0.id) }
            })
        }
        sessions = try context.fetch(FetchDescriptor<WorkoutSession>()).map { session in
            SessionRecord(startedAt: session.startedAt, finishedAt: session.finishedAt, routineName: session.routineName, plan: session.plan,
                          sets: session.sets.compactMap { set in
                              set.exercise.map { SetRecord(exerciseID: $0.id, weightKg: set.weightKg, reps: set.reps, loggedAt: set.loggedAt) }
                          })
        }
    }

    /// Adds only what isn't stored yet, matched by creation time, so importing the same file twice adds nothing.
    /// Returns how many routines and workouts were added.
    @discardableResult
    func restore(into context: ModelContext) throws -> Int {
        let exercises = Dictionary(try context.fetch(FetchDescriptor<Exercise>()).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let knownRoutines = Set(try context.fetch(FetchDescriptor<Routine>()).map(\.createdAt))
        let knownSessions = Set(try context.fetch(FetchDescriptor<WorkoutSession>()).map(\.startedAt))
        var added = 0

        for record in routines where !knownRoutines.contains(record.createdAt) {
            let routine = Routine(name: record.name, createdAt: record.createdAt)
            context.insert(routine)
            for item in record.items {
                guard let exercise = exercises[item.exerciseID] else { continue }
                routine.items.append(RoutineItem(order: item.order, targetSets: item.targetSets, exercise: exercise))
            }
            added += 1
        }
        // shortcut: a workout still in progress is not restored, so an import never creates a second active workout
        for record in sessions where record.finishedAt != nil && !knownSessions.contains(record.startedAt) {
            let session = WorkoutSession(startedAt: record.startedAt, routineName: record.routineName)
            session.finishedAt = record.finishedAt
            session.plan = record.plan
            context.insert(session)
            for set in record.sets {
                guard let exercise = exercises[set.exerciseID] else { continue }
                session.sets.append(SetEntry(exercise: exercise, weightKg: set.weightKg, reps: set.reps, loggedAt: set.loggedAt))
            }
            added += 1
        }
        try context.save()
        return added
    }
}

/// Wraps the backup bytes for the system's save-to-Files sheet.
struct BackupFile: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    let data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
