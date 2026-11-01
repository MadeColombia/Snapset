import SwiftUI

/// Brand colours from the package asset catalog. Each has a light (Any) and a dark appearance.
/// There is deliberately no red: lighter weights and warnings use `statusDown` (amber).
public struct SnapColors: Sendable {
    public let background = Color("background", bundle: .module)
    public let surface = Color("surface", bundle: .module)
    public let surfaceRaised = Color("surfaceRaised", bundle: .module)
    public let line = Color("line", bundle: .module)
    public let textPrimary = Color("textPrimary", bundle: .module)
    public let textSecondary = Color("textSecondary", bundle: .module)
    /// Use on at most one element per screen.
    public let accent = Color("accent", bundle: .module)
    public let onAccent = Color("onAccent", bundle: .module)
    public let statusUp = Color("statusUp", bundle: .module)
    public let statusHold = Color("statusHold", bundle: .module)
    public let statusDown = Color("statusDown", bundle: .module)
}

extension Color {
    public static let snap = SnapColors()
}
