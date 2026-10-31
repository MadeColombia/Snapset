import Foundation
import Testing
import SwiftData
@testable import Snapset

@MainActor
struct BackupTests {
    static func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Exercise.self, Routine.self, RoutineItem.self, WorkoutSession.self, SetEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test func roundTripsAndImportsOnlyOnce() throws {
        let source = try Self.makeContainer()
        let press = Exercise(id: "machine.chest-press", name: "Chest Press", equipment: .machine)
        source.mainContext.insert(press)
        let routine = Routine(name: "Push")
        routine.items.append(RoutineItem(order: 0, targetSets: 3, exercise: press))
        let done = WorkoutSession(routine: routine)
        done.sets.append(SetEntry(exercise: press, weightKg: 42.5, reps: 10))
        done.finishedAt = .now
        source.mainContext.insert(routine)
        source.mainContext.insert(done)
        source.mainContext.insert(WorkoutSession(routineName: "Still going"))
        try source.mainContext.save()

        let data = try JSONEncoder().encode(Backup(context: source.mainContext))

        let target = try Self.makeContainer()
        let context = target.mainContext
        context.insert(Exercise(id: press.id, name: press.name, equipment: press.equipment))
        let backup = try JSONDecoder().decode(Backup.self, from: data)
        #expect(try backup.restore(into: context) == 2)  // routine + finished workout; the unfinished one is skipped

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        #expect(sessions.count == 1)
        #expect(sessions.first?.sets.first?.weightKg == 42.5)
        #expect(sessions.first?.startedAt == done.startedAt)
        #expect(try context.fetch(FetchDescriptor<Routine>()).first?.items.first?.exercise?.id == press.id)

        #expect(try backup.restore(into: context) == 0)
        #expect(try context.fetchCount(FetchDescriptor<WorkoutSession>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<SetEntry>()) == 1)
    }

    @Test func historyGroupsBySessionAndSkipsCurrent() throws {
        let container = try Self.makeContainer()
        let context = container.mainContext
        let press = Exercise(id: "machine.chest-press", name: "Chest Press", equipment: .machine)
        context.insert(press)
        let older = WorkoutSession(startedAt: .now.addingTimeInterval(-172_800))
        older.sets.append(SetEntry(exercise: press, weightKg: 40, reps: 12, loggedAt: .now.addingTimeInterval(-172_800)))
        let last = WorkoutSession(startedAt: .now.addingTimeInterval(-86_400))
        last.sets.append(SetEntry(exercise: press, weightKg: 45, reps: 8, loggedAt: .now.addingTimeInterval(-86_400)))
        last.sets.append(SetEntry(exercise: press, weightKg: 45, reps: 7, loggedAt: .now.addingTimeInterval(-86_300)))
        let current = WorkoutSession()
        current.sets.append(SetEntry(exercise: press, weightKg: 50, reps: 5))
        [older, last, current].forEach(context.insert)
        try context.save()

        let history = Progression.history(of: press.id, excluding: current, in: context)
        #expect(history.count == 2)
        #expect(history.first?.map(\.weightKg) == [45, 45])
        #expect(history.last?.map(\.weightKg) == [40])
    }
}
