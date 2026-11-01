import SwiftUI

/// Puts a component on the app background for previews.
struct PreviewSurface<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: Snap.Spacing.l) { content }
            .padding(Snap.Spacing.l)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.snap.background)
    }
}
