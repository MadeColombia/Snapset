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

    @Test func editingASetPersistsAndRechecksTheBest() throws {
        let yesterday = Date.now.addingTimeInterval(-86_400)
        let past = WorkoutSession(startedAt: yesterday)
        past.sets.append(SetEntry(exercise: press, weightKg: 50, reps: 10, loggedAt: yesterday))
        past.finishedAt = yesterday.addingTimeInterval(3_600)
        let session = WorkoutSession()
        let set = SetEntry(exercise: press, weightKg: 50, reps: 10)
        session.sets.append(set)
        [past, session].forEach(context.insert)
        try context.save()
        #expect(!session.isNewBest(set, in: context))  // ties last time's 50 kg

        set.weightKg = 52.5
        set.reps = 8
        try context.save()
        let stored = try ModelContext(container).fetch(FetchDescriptor<SetEntry>(sortBy: [SortDescriptor(\.loggedAt, order: .reverse)])).first
        #expect(stored?.weightKg == 52.5 && stored?.reps == 8)
        #expect(session.isNewBest(set, in: context))

        set.weightKg = 45
        try context.save()
        #expect(!session.isNewBest(set, in: context))
    }

    @Test func onlySetsLoggedEarlierCountAgainstAnEditedSet() throws {
        let session = WorkoutSession()
        let first = SetEntry(exercise: press, weightKg: 40, reps: 10, loggedAt: .now.addingTimeInterval(-300))
        let second = SetEntry(exercise: press, weightKg: 42.5, reps: 10, loggedAt: .now)
        session.sets = [first, second]
        context.insert(session)
        try context.save()
        #expect(session.isNewBest(second, in: context))   // beats the earlier set
        #expect(!session.isNewBest(first, in: context))   // the first set ever has nothing to beat

        second.weightKg = 40
        try context.save()
        #expect(!session.isNewBest(second, in: context))  // edited down to a tie, no longer a best
    }
}
