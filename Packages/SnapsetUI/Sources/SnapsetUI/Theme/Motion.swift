import SwiftUI

extension Snap {
    public enum Motion {
        public static let quick: Animation = .snappy
        /// `.smooth` has no bounce.
        public static let standard: Animation = .smooth
        /// Used for everything when Reduce Motion is on, paired with opacity-only transitions.
        public static let reduced: Animation = .easeInOut(duration: 0.2)

        public static func animation(_ base: Animation, reduceMotion: Bool) -> Animation {
            reduceMotion ? reduced : base
        }

        public static func transition(_ base: AnyTransition, reduceMotion: Bool) -> AnyTransition {
            reduceMotion ? .opacity : base
        }
    }

    /// Haptics, played with `.sensoryFeedback(_:trigger:)`.
    public enum Haptic {
        public static let setSaved: SensoryFeedback = .impact(weight: .light)
        public static let newBest: SensoryFeedback = .success
        public static let stepperChange: SensoryFeedback = .selection
    }
}

private struct SnapAnimation<V: Equatable>: ViewModifier {
    let base: Animation
    let value: V
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(Snap.Motion.animation(base, reduceMotion: reduceMotion), value: value)
    }
}

extension View {
    /// Animates changes to `value` with a Snapset motion, falling back to a short ease when Reduce Motion is on.
    public func snapAnimation<V: Equatable>(_ base: Animation = Snap.Motion.standard, value: V) -> some View {
        modifier(SnapAnimation(base: base, value: value))
    }
}
