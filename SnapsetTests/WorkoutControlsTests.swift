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

    @Test func aPauseHoldsTheRestAndResumingKeepsWhatWasLeft() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let session = WorkoutSession(startedAt: start)
        session.startRest(90, at: start.addingTimeInterval(60))
        #expect(session.restRemaining(at: start.addingTimeInterval(70)) == 80)
        session.togglePause(at: start.addingTimeInterval(70))
        // Frozen while paused, however long the pause.
        #expect(session.restRemaining(at: start.addingTimeInterval(400)) == 80)
        session.togglePause(at: start.addingTimeInterval(250))
        #expect(session.restRemaining(at: start.addingTimeInterval(250)) == 80)
    }

    /// Field-test bug: pause, log a set, resume, and the rest had the whole pause added to it.
    @Test func loggingASetWhilePausedResumesAndStartsAPlainRest() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let session = WorkoutSession(startedAt: start)
        session.togglePause(at: start.addingTimeInterval(60))
        let logged = start.addingTimeInterval(240)  // three minutes paused
        session.startRest(90, at: logged)
        #expect(session.pausedAt == nil)
        #expect(session.pausedSeconds == 180)
        #expect(session.restRemaining(at: logged) == 90)
        // A later pause and resume still adds nothing.
        session.togglePause(at: logged.addingTimeInterval(10))
        session.togglePause(at: logged.addingTimeInterval(70))
        #expect(session.restRemaining(at: logged.addingTimeInterval(70)) == 80)
    }

    @Test func aRestThatRanOutBeforeThePauseEndsOnResume() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let session = WorkoutSession(startedAt: start)
        session.startRest(60, at: start)
        session.togglePause(at: start.addingTimeInterval(100))
        #expect(session.restRemaining(at: start.addingTimeInterval(100)) == nil)
        session.togglePause(at: start.addingTimeInterval(200))
        #expect(session.restEndsAt == nil)
    }

    @Test func theRestEndsOnAWholeSecondOfTheWorkoutClock() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let session = WorkoutSession(startedAt: start)
        session.startRest(90, at: start.addingTimeInterval(12.4))
        let end = try #require(session.restEndsAt)
        #expect(end.timeIntervalSince(session.startedAt) == 103)
        #expect(session.restSeconds == 91)  // 90.6, shown as a whole second
    }

    // MARK: Two clocks: the workout clock stands still while resting, and picks up when the rest runs out.

    @Test func theWorkoutClockStandsStillDuringARestAndRunsAgainAfter() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var times = WorkoutTimes(startedAt: start)
        times.startRest(90, at: start.addingTimeInterval(60))
        #expect(times.phase(at: start.addingTimeInterval(61)) == .resting)
        #expect(times.elapsed(at: start.addingTimeInterval(61)) == 60)
        #expect(times.elapsed(at: start.addingTimeInterval(149)) == 60)
        // No update needed at the rest's end: the clock picks up from 60 on its own.
        #expect(times.phase(at: start.addingTimeInterval(150)) == .training)
        #expect(times.elapsed(at: start.addingTimeInterval(160)) == 70)
        #expect(times.runningSince(at: start.addingTimeInterval(160)) == start.addingTimeInterval(90))
        // Settling later changes nothing on screen.
        times.settle(at: start.addingTimeInterval(500))
        #expect(times.elapsed(at: start.addingTimeInterval(160)) == 70)
        #expect(times.stoppedSeconds == 90)
    }

    @Test func pausingDuringARestFreezesBothClocks() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var times = WorkoutTimes(startedAt: start)
        times.startRest(90, at: start.addingTimeInterval(60))
        times.togglePause(at: start.addingTimeInterval(80))  // 70 s of rest left
        #expect(times.elapsed(at: start.addingTimeInterval(500)) == 60)
        #expect(times.restRemaining(at: start.addingTimeInterval(500)) == 70)
        times.togglePause(at: start.addingTimeInterval(200))  // resting again, 70 s left
        #expect(times.phase(at: start.addingTimeInterval(200)) == .resting)
        #expect(times.elapsed(at: start.addingTimeInterval(269)) == 60)
        // Rest over at 270: the clock carries on from 60.
        #expect(times.elapsed(at: start.addingTimeInterval(280)) == 70)
    }

    @Test func skippingTheRestStartsTheClockAtOnce() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var times = WorkoutTimes(startedAt: start)
        times.startRest(90, at: start.addingTimeInterval(60))
        times.endRest(at: start.addingTimeInterval(75))
        #expect(times.phase(at: start.addingTimeInterval(75)) == .training)
        #expect(times.elapsed(at: start.addingTimeInterval(85)) == 70)
    }

    @Test func aPauseInTrainingFreezesTheClockAndResumeCarriesOn() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var times = WorkoutTimes(startedAt: start)
        times.togglePause(at: start.addingTimeInterval(30))
        #expect(times.elapsed(at: start.addingTimeInterval(300)) == 30)
        times.togglePause(at: start.addingTimeInterval(300))
        #expect(times.elapsed(at: start.addingTimeInterval(310)) == 40)
    }

    /// Both numbers change on the same instant: the rest's whole seconds line up with the workout clock's.
    @Test func theRestAndTheClockTickTogether() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var times = WorkoutTimes(startedAt: start)
        times.startRest(90, at: start.addingTimeInterval(41.7))
        let end = try #require(times.restEndsAt)
        let resumed = try #require(times.runningSince(at: end))
        #expect(end.timeIntervalSince(resumed).truncatingRemainder(dividingBy: 1) == 0)
        #expect(times.elapsed(at: end) == 41)  // the second it showed when the rest began
    }

    @Test func aSessionPausedBeforeHoldSinceExistedStillResumes() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let session = WorkoutSession(startedAt: start)
        session.pausedAt = start.addingTimeInterval(30)  // as stored by the previous version
        session.togglePause(at: start.addingTimeInterval(90))
        #expect(session.pausedSeconds == 60)
        #expect(session.holdSince == nil)
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
