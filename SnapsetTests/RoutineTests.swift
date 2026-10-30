import Foundation
import Testing
import SwiftData
@testable import Snapset

@MainActor
struct RoutineTests {
    @Test func deletingRoutineKeepsSessionsAndExercises() throws {
        let container = try ModelContainer(
            for: Exercise.self, Routine.self, RoutineItem.self, WorkoutSession.self, SetEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let press = Exercise(id: "machine.chest-press", name: "Chest Press", equipment: .machine)
        let routine = Routine(name: "Push")
        routine.items.append(RoutineItem(order: 0, exercise: press))
        let session = WorkoutSession(routineName: routine.name)
        session.sets.append(SetEntry(exercise: press, weightKg: 40, reps: 10))
        context.insert(routine)
        context.insert(session)
        try context.save()

        context.delete(routine)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Routine>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<RoutineItem>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Exercise>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<WorkoutSession>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<SetEntry>()) == 1)
        #expect(try context.fetch(FetchDescriptor<WorkoutSession>()).first?.routineName == "Push")
    }
}
