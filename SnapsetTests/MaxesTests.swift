import Testing
@testable import Snapset

struct MaxesTests {
    @Test func singleRepIsTheMax() {
        #expect(SetEntry.estimatedOneRepMax(weightKg: 100, reps: 1) == 100)
    }

    @Test func epleyForMultipleReps() {
        #expect(abs(SetEntry.estimatedOneRepMax(weightKg: 100, reps: 10) - 133.333) < 0.001)
        #expect(SetEntry.estimatedOneRepMax(weightKg: 60, reps: 5) == 70)
    }
}
