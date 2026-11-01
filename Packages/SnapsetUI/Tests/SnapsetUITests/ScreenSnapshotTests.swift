import SwiftUI
import UIKit
import XCTest
@testable import SnapsetUI

/// Renders the screen previews to PNGs in design/previews/ at the repo root, for design review.
/// It asserts only that each render produced an image; it does not diff against a reference.
@MainActor
final class ScreenSnapshotTests: XCTestCase {
    private let outputDir = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "design/previews")

    func testRenderScreens() throws {
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        let screens: [(String, AnyView)] = [
            ("set-confirm-manual", AnyView(SetConfirmView(model: .mock(.manual)))),
            ("set-confirm-photo-sure", AnyView(SetConfirmView(model: .mock(.photoSure)))),
            ("set-confirm-photo-unsure", AnyView(SetConfirmView(model: .mock(.photoUnsure(guess: "40 kg"))))),
            ("set-confirm-unreadable", AnyView(SetConfirmView(model: .mock(.photoUnreadable)))),
            ("workout-session-mid", AnyView(WorkoutSessionView(model: .midSession))),
            ("workout-session-first-time", AnyView(WorkoutSessionView(model: .firstTime))),
            ("workout-session-resting", AnyView(WorkoutSessionView(model: .resting))),
        ]
        for (name, view) in screens {
            for style in [UIUserInterfaceStyle.dark, .light] {
                let data = try XCTUnwrap(render(view, style: style))
                XCTAssertGreaterThan(data.count, 0)
                try data.write(to: outputDir.appending(path: "\(name)-\(style == .dark ? "dark" : "light").png"))
            }
        }
    }

    private func render(_ view: AnyView, style: UIUserInterfaceStyle) -> Data? {
        let size = CGSize(width: 402, height: 874) // iPhone 17 in points
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.overrideUserInterfaceStyle = style
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        // drawHierarchy needs a host app's render server; layer.render works in a hostless test bundle.
        return UIGraphicsImageRenderer(size: size).pngData { context in
            host.view.layer.render(in: context.cgContext)
        }
    }
}
