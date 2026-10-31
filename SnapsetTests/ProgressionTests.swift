import Foundation
import Testing
@testable import Snapset

struct ProgressionTests {
    typealias S = Progression.LoggedSet

    struct Case: CustomTestStringConvertible {
        let name: String
        var goal = Goal.muscle
        var equipment = Equipment.barbell
        let sessions: [[S]]
        let change: Progression.Target.Change
        let weightKg: Double?
        var testDescription: String { name }
    }

    static func sets(_ kg: Double, _ reps: Int...) -> [S] { reps.map { S(weightKg: kg, reps: $0) } }

    static let cases: [Case] = [
        Case(name: "all sets at top of range progresses", sessions: [sets(60, 12, 12, 12)], change: .increase, weightKg: 62.5),
        Case(name: "warm-ups do not block progress", sessions: [sets(40, 8) + sets(60, 12, 12, 12)], change: .increase, weightKg: 62.5),
        Case(name: "one set short of the top holds", sessions: [sets(60, 12, 12, 10)], change: .hold, weightKg: 60),
        Case(name: "fewer sets than planned holds", sessions: [sets(60, 12, 12)], change: .hold, weightKg: 60),
        Case(name: "strength tops out at 6", goal: .strength, sessions: [sets(100, 6, 6, 6)], change: .increase, weightKg: 102.5),
        Case(name: "lean needs 15", goal: .lean, sessions: [sets(30, 12, 12, 12)], change: .hold, weightKg: 30),
        Case(name: "pin stack steps by 5 kg", equipment: .machine, sessions: [sets(40, 12, 12, 12)], change: .increase, weightKg: 45),
        Case(name: "bodyweight never adds load", equipment: .bodyweight, sessions: [sets(0, 12, 12, 12)], change: .hold, weightKg: 0),
        Case(name: "one miss holds", sessions: [sets(60, 5, 6, 6), sets(60, 8, 8, 7)], change: .hold, weightKg: 60),
        Case(name: "two misses in a row reduce about 10%", sessions: [sets(60, 5, 4, 4), sets(60, 6, 5, 5)], change: .decrease, weightKg: 52.5),
        Case(name: "misses at different weights do not reduce", sessions: [sets(60, 5, 4, 4), sets(57.5, 6, 5, 5)], change: .hold, weightKg: 60),
        Case(name: "small loads reduce by at least one step", equipment: .machine, sessions: [sets(10, 4, 4, 4), sets(10, 5, 5, 5)], change: .decrease, weightKg: 5),
        Case(name: "no history asks for a starting weight", sessions: [], change: .start, weightKg: nil),
        Case(name: "empty sessions count as no history", sessions: [[], []], change: .start, weightKg: nil),
    ]

    @Test(arguments: cases)
    func nextTarget(_ c: Case) {
        let target = Progression.next(goal: c.goal, equipment: c.equipment, unit: .kg, sets: 3, sessions: c.sessions)
        #expect(target.change == c.change)
        #expect(target.weightKg == c.weightKg)
        #expect(target.reps == c.goal.repRange)
        #expect(target.sets == 3)
    }

    @Test func fixedRepsReplaceTheGoalRange() {
        let hit = Progression.next(goal: .muscle, equipment: .barbell, unit: .kg, sets: 3, reps: 8, sessions: [Self.sets(60, 8, 8, 8)])
        #expect(hit.change == .increase && hit.reps == 8...8)
        let short = Progression.next(goal: .muscle, equipment: .barbell, unit: .kg, sets: 3, reps: 8, sessions: [Self.sets(60, 8, 8, 7)])
        #expect(short.change == .hold)
    }

    @Test func switchingToPoundsLandsOnAPoundStep() throws {
        // 60 kg is 132.3 lb: the nearest 5 lb mark is 130, so the next target is 135 lb.
        let target = Progression.next(goal: .muscle, equipment: .barbell, unit: .lb, sets: 3, sessions: [Self.sets(60, 12, 12, 12)])
        let lb = WeightUnit.lb.fromKg(try #require(target.weightKg))
        #expect(abs(lb - 135) < 0.001)
    }

    @Test func weightLoggedInPoundsStepsByFivePounds() throws {
        let kg = WeightUnit.lb.toKg(135)
        let target = Progression.next(goal: .muscle, equipment: .dumbbell, unit: .lb, sets: 3, sessions: [Self.sets(kg, 12, 12, 12)])
        #expect(abs(WeightUnit.lb.fromKg(try #require(target.weightKg)) - 140) < 0.001)
    }
}
