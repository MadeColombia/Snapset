import SwiftUI

public enum Snap {
    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 12
        public static let l: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
    }

    /// Minimum tap target heights.
    public enum Tap {
        public static let min: CGFloat = 44
        public static let logging: CGFloat = 60
        public static let gym: CGFloat = 80
    }

    public enum Radius {
        public static let card: CGFloat = 16
        public static let control: CGFloat = 14
        public static let chip: CGFloat = 8
    }
}
