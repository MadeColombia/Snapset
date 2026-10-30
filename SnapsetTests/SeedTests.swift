import Foundation
import Testing
import SwiftData
@testable import Snapset

@MainActor
struct SeedTests {
    @Test func seedingTwiceDoesNotDuplicate() throws {
        let container = try ModelContainer(for: Exercise.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let bundle = Bundle(for: Exercise.self)

        try Seed.exercises(into: context, bundle: bundle)
        let first = try context.fetchCount(FetchDescriptor<Exercise>())
        try Seed.exercises(into: context, bundle: bundle)

        #expect(first >= 50)
        #expect(try context.fetchCount(FetchDescriptor<Exercise>()) == first)
    }

    @Test func unitRoundTripLeavesStoredWeightUnchanged() {
        let storedKg = 72.5
        let shownInLb = WeightUnit.lb.fromKg(storedKg)
        #expect(abs(WeightUnit.lb.toKg(shownInLb) - storedKg) < 1e-9)
        #expect(WeightUnit.kg.fromKg(storedKg) == storedKg)
        #expect(abs(WeightUnit.lb.fromKg(100) - 220.462) < 0.001)
    }
}
