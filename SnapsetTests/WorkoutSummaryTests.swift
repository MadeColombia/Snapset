import Foundation
import SwiftData
import Testing
@testable import Snapset

@MainActor
struct WorkoutSummaryTests {
    let container: ModelContainer
    let context: ModelContext
    let press: Exercise
    let row: Exercise
    let curl: Exercise
    let start = Date(timeIntervalSince1970: 1_700_000_000)

    init() throws {
        container = try ModelContainer(
            for: Exercise.self, Routine.self, RoutineItem.self, WorkoutSession.self, SetEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = container.mainContext
        press = Exercise(id: "press", name: "Chest Press", equipment: .machine)
        row = Exercise(id: "row", name: "Seated Row", equipment: .machine)
        curl = Exercise(id: "curl", name: "Curl", equipment: .dumbbell)
        [press, row, curl].forEach(context.insert)
    }

    /// A finished session a week before `start`: press 45 kg, row 40 kg.
    private func lastWeek() {
        let past = WorkoutSession(startedAt: start.addingTimeInterval(-7 * 86_400))
        context.insert(past)
        past.sets = [SetEntry(exercise: press, weightKg: 45, reps: 12, loggedAt: past.startedAt.addingTimeInterval(60)),
                     SetEntry(exercise: row, weightKg: 40, reps: 12, loggedAt: past.startedAt.addingTimeInterval(120))]
        past.finishedAt = past.startedAt.addingTimeInterval(3_600)
    }

    private func today() -> WorkoutSession {
        let session = WorkoutSession(startedAt: start)
        session.plan = [PlannedExercise(exerciseID: "row", targetSets: 3), PlannedExercise(exerciseID: "press", targetSets: 3),
                        PlannedExercise(exerciseID: "legs", targetSets: 3)]
        context.insert(session)
        session.sets = [SetEntry(exercise: press, weightKg: 47.5, reps: 10, loggedAt: start.addingTimeInterval(300)),
                        SetEntry(exercise: press, weightKg: 45, reps: 12, loggedAt: start.addingTimeInterval(400)),
                        SetEntry(exercise: row, weightKg: 40, reps: 12, loggedAt: start.addingTimeInterval(600)),
                        SetEntry(exercise: curl, weightKg: 10, reps: 12, loggedAt: start.addingTimeInterval(900))]
        session.finishedAt = start.addingTimeInterval(1_800)
        return session
    }

    @Test func exercisesFollowThePlanThenExtrasAndSkipUntrainedOnes() throws {
        lastWeek()
        let summary = WorkoutSummary(session: today(), nextKg: [:], in: context)
        #expect(summary.exercises.map(\.id) == ["row", "press", "curl"])  // "legs" was planned but never trained
        #expect(summary.setsLogged == 4)
        #expect(summary.setsPlanned == 9)
    }

    @Test func comparesTheTopSetWithLastTimeAndFlagsANewBest() throws {
        lastWeek()
        let summary = WorkoutSummary(session: today(), nextKg: [:], in: context)
        let press = try #require(summary.exercises.first { $0.id == "press" })
        #expect(press.topKg == 47.5)
        #expect(press.lastTopKg == 45)
        #expect(press.isNewBest)
        let row = try #require(summary.exercises.first { $0.id == "row" })
        #expect(!row.isNewBest)  // same as last week
        let curl = try #require(summary.exercises.first { $0.id == "curl" })
        #expect(curl.lastTopKg == nil)
        #expect(!curl.isNewBest)  // the first time is not a best: nothing to beat
        #expect(summary.newBests.map(\.id) == ["press"])
    }

    @Test func goingUpListsOnlyExercisesWithANextWeight() throws {
        let summary = WorkoutSummary(session: today(), nextKg: ["row": 45], in: context)
        #expect(summary.goingUp.map(\.id) == ["row"])
        #expect(summary.goingUp.first?.nextKg == 45)
    }

    @Test func workoutTimeLeavesOutPausesAndHeartRateCoversTheSets() throws {
        let session = today()
        session.togglePause(at: start.addingTimeInterval(1_000))
        session.togglePause(at: start.addingTimeInterval(1_300))  // 5 minutes paused
        let summary = WorkoutSummary(session: session, nextKg: [:], in: context)
        #expect(summary.activeSeconds == 1_500)
        #expect(summary.heartRateWindow.lowerBound == start)  // first set at 5 min, padded 15 min, not before the start
        #expect(summary.heartRateWindow.upperBound == start.addingTimeInterval(1_800))
        #expect(summary.setTimes.count == 4)
    }

    @Test func restIsTheGapBetweenSetsOfOneExerciseJudgedAgainstThePlan() throws {
        let session = today()  // press sets 100 s apart; row and curl have one set each
        #expect(WorkoutSummary(session: session, nextKg: [:], targetRestSeconds: 90, in: context).restGaps == [100])
        #expect(WorkoutSummary(session: session, nextKg: [:], targetRestSeconds: 90, in: context).restVerdict == .onPoint)
        #expect(WorkoutSummary(session: session, nextKg: [:], targetRestSeconds: 60, in: context).restVerdict == .long)
        #expect(WorkoutSummary(session: session, nextKg: [:], targetRestSeconds: 180, in: context).restVerdict == .short)
    }

    @Test func theHighlightIsTheBiggestUpgrade() throws {
        lastWeek()
        let summary = WorkoutSummary(session: today(), nextKg: ["row": 45], in: context)
        #expect(summary.highlight.title == "Chest Press got the upgrade!")
    }

    @Test func withoutABestTheHighlightIsWhatGoesUp() throws {
        let summary = WorkoutSummary(session: today(), nextKg: ["row": 45], in: context)  // no history: no bests
        #expect(summary.highlight.title == "Seated Row goes up next time")
    }

    @Test func exerciseBlocksFollowRunsOfSetsAndNeverOverlap() {
        let t = { (s: Double) in self.start.addingTimeInterval(s) }
        let blocks = Health.exerciseBlocks([("Row", t(600)), ("Press", t(100)), ("Press", t(300)), ("Row", t(700)), ("Press", t(900))],
                                           workoutStart: start)
        #expect(blocks == [Health.ExerciseBlock(name: "Press", start: start, end: t(300), sets: 2),
                           Health.ExerciseBlock(name: "Row", start: t(300), end: t(700), sets: 2),
                           Health.ExerciseBlock(name: "Press", start: t(700), end: t(900), sets: 1)])
    }

    @Test func syncIdentifierIsStableForASession() {
        #expect(Health.syncIdentifier(sessionStartedAt: start) == "snapset.workout.1700000000000")
    }

    @Test func calorieEstimateUsesBodyWeightOrSeventyKilos() {
        #expect(Health.estimatedKcal(activeSeconds: 3_600, bodyKg: 80) == 200)
        #expect(Health.estimatedKcal(activeSeconds: 3_600, bodyKg: nil) == 175)
    }

    @Test func liveCaloriesShowAsMeasured() {
        var summary = WorkoutSummary.sample()
        #expect(summary.liveEnergy == nil)  // no live session: the overview looks them up in Health
        summary.liveKcal = 0
        #expect(summary.liveEnergy == nil)
        summary.liveKcal = 241.5
        #expect(summary.liveEnergy == Health.Energy(kcal: 241.5, measured: true))
    }
}
