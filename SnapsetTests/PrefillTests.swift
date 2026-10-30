import Foundation
import Testing
import SwiftData
@testable import Snapset

@MainActor
struct PrefillTests {
    let container: ModelContainer  // must outlive the context, or SwiftData traps
    let context: ModelContext
    let press = Exercise(id: "machine.chest-press", name: "Chest Press", equipment: .machine)
    let row = Exercise(id: "cable.cable-row", name: "Cable Row", equipment: .cable)

    init() throws {
        container = try ModelContainer(
            for: Exercise.self, Routine.self, RoutineItem.self, WorkoutSession.self, SetEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = container.mainContext
        context.insert(press)
        context.insert(row)
    }

    @Test func noHistoryReturnsNil() {
        #expect(SetEntry.latest(of: press.id, in: context) == nil)
    }

    @Test func returnsMostRecentSetOfThatExerciseOnly() throws {
        let old = WorkoutSession(startedAt: .now.addingTimeInterval(-86_400))
        old.sets.append(SetEntry(exercise: press, weightKg: 40, reps: 12, loggedAt: .now.addingTimeInterval(-86_400)))
        let today = WorkoutSession()
        today.sets.append(SetEntry(exercise: press, weightKg: 45, reps: 8, loggedAt: .now.addingTimeInterval(-60)))
        today.sets.append(SetEntry(exercise: row, weightKg: 60, reps: 10))
        context.insert(old)
        context.insert(today)
        try context.save()

        let latest = try #require(SetEntry.latest(of: press.id, in: context))
        #expect(latest.weightKg == 45)
        #expect(latest.reps == 8)
    }

    @Test func unfinishedSessionIsFoundForResume() throws {
        let routine = Routine(name: "Push")
        routine.items.append(RoutineItem(order: 1, targetSets: 4, exercise: row))
        routine.items.append(RoutineItem(order: 0, targetSets: 3, exercise: press))
        let finished = WorkoutSession(routineName: "Old")
        finished.finishedAt = .now
        context.insert(routine)
        context.insert(finished)
        context.insert(WorkoutSession(routine: routine))
        try context.save()

        let active = try context.fetch(FetchDescriptor(predicate: WorkoutSession.isActive))
        #expect(active.count == 1)
        #expect(active.first?.plan == [PlannedExercise(exerciseID: press.id, targetSets: 3),
                                       PlannedExercise(exerciseID: row.id, targetSets: 4)])
    }
}
