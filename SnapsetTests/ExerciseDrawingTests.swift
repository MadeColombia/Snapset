import Foundation
import Testing
@testable import Snapset

struct ExerciseDrawingTests {
    /// A drawing whose name doesn't match a seed id would never show, so catch typos here.
    @Test func everyDrawingBelongsToASeedExercise() throws {
        let url = try #require(Bundle.main.url(forResource: "exercises", withExtension: "json"))
        let ids = Set(try JSONDecoder().decode([[String: String]].self, from: Data(contentsOf: url)).compactMap { $0["id"] })
        let drawings = Bundle.main.paths(forResourcesOfType: "png", inDirectory: nil)
            .map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent }
            .filter { $0.hasSuffix("-0") || $0.hasSuffix("-1") }
        #expect(drawings.count == 92)
        for name in drawings {
            #expect(ids.contains(String(name.dropLast(2))), "\(name) has no matching exercise")
        }
    }
}
