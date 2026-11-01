import Foundation
import Testing
import SwiftData
@testable import Snapset

@MainActor
struct WorkoutControlsTests {
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

    @Test func pausesAddUpAndLeaveTheWorkoutTime() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let session = WorkoutSession(startedAt: start)
        session.togglePause(at: start.addingTimeInterval(60))
        #expect(session.pausedAt != nil)
        session.togglePause(at: start.addingTimeInterval(90))
        session.togglePause(at: start.addingTimeInterval(100))
        session.togglePause(at: start.addingTimeInterval(110))
        #expect(session.pausedAt == nil)
        #expect(session.pausedSeconds == 40)
    }

    @Test func nextSetMovesOnOnceAnExerciseHasItsSetsAndRepeatsTheLastSet() throws {
        let session = WorkoutSession()
        session.plan = [PlannedExercise(exerciseID: press.id, targetSets: 1), PlannedExercise(exerciseID: row.id, targetSets: 2)]
        context.insert(session)
        // No history for the first exercise: nothing to log blindly.
        #expect(WorkoutActivity.nextSet(of: session, in: context) == nil)

        session.sets.append(SetEntry(exercise: press, weightKg: 40, reps: 10))
        session.sets.append(SetEntry(exercise: row, weightKg: 55, reps: 9))
        try context.save()
        let next = try #require(WorkoutActivity.nextSet(of: session, in: context))
        #expect(next.exercise.id == row.id)
        #expect(next.weightKg == 55 && next.reps == 9)

        session.sets.append(SetEntry(exercise: row, weightKg: 55, reps: 9))
        #expect(WorkoutActivity.nextSet(of: session, in: context) == nil)  // every planned set done
    }
}
