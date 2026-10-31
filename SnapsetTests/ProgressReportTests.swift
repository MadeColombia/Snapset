import Foundation
import Testing
@testable import Snapset

struct ProgressReportTests {
    let day0 = Date(timeIntervalSince1970: 1_700_000_000)
    func day(_ n: Int) -> Date { day0.addingTimeInterval(Double(n) * 86_400) }

    @Test func trendComparesBestOfFirstAndLatestDay() throws {
        let lifts = [
            Lift(exerciseID: "press", date: day(0), weightKg: 50, reps: 1),
            Lift(exerciseID: "press", date: day(0), weightKg: 40, reps: 1),
            Lift(exerciseID: "press", date: day(3), weightKg: 55, reps: 1),
        ]
        let trend = try #require(ProgressReport.trends(lifts).first)
        #expect(trend.days == 2)
        #expect(abs(trend.change - 0.1) < 0.0001)
    }

    @Test func indexCarriesExercisesForwardBetweenDays() {
        let lifts = [
            Lift(exerciseID: "press", date: day(0), weightKg: 100, reps: 1),
            Lift(exerciseID: "row", date: day(1), weightKg: 50, reps: 1),
            Lift(exerciseID: "press", date: day(2), weightKg: 110, reps: 1),  // press +10%, row still 0%
            Lift(exerciseID: "pullup", date: day(2), weightKg: 0, reps: 8),   // bodyweight, ignored
        ]
        let index = ProgressReport.strengthIndex(lifts)
        #expect(index.count == 3)
        #expect(index[0].change == 0 && index[1].change == 0)
        #expect(abs(index[2].change - 0.05) < 0.0001)
    }
}
