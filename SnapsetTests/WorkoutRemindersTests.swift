import Foundation
import Testing
@testable import Snapset

struct WorkoutRemindersTests {
    let start = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func aRestGetsARestOverReminderAndTheIdleNudgeCountsFromItsEnd() throws {
        let session = WorkoutSession(startedAt: start)
        let now = start.addingTimeInterval(300)
        session.startRest(90, at: now)
        let plan = try #require(WorkoutReminders.plan(for: session, at: now))
        #expect(plan.restOver == session.restEndsAt)
        #expect(plan.idle == session.restEndsAt!.addingTimeInterval(15 * 60))
        #expect(!plan.idlePaused)
    }

    @Test func noRestMeansOnlyTheIdleNudge() throws {
        let session = WorkoutSession(startedAt: start)
        let plan = try #require(WorkoutReminders.plan(for: session, at: start))
        #expect(plan.restOver == nil)
        #expect(plan.idle == start.addingTimeInterval(15 * 60))
    }

    @Test func pausedWaitsLongerAndDropsTheRestReminder() throws {
        let session = WorkoutSession(startedAt: start)
        session.startRest(90, at: start)
        session.togglePause(at: start.addingTimeInterval(10))
        let now = start.addingTimeInterval(10)
        let plan = try #require(WorkoutReminders.plan(for: session, at: now))
        #expect(plan.restOver == nil)
        #expect(plan.idlePaused)
        #expect(plan.idle == now.addingTimeInterval(30 * 60))
    }

    @Test func aFinishedWorkoutHasNoReminders() {
        let session = WorkoutSession(startedAt: start)
        session.finishedAt = start.addingTimeInterval(600)
        #expect(WorkoutReminders.plan(for: session, at: start.addingTimeInterval(600)) == nil)
    }
}
