import SwiftUI

extension View {
    /// Theme background for a List or Form. Give rows `.listRowBackground(Color.snap.surface)` per section.
    public func snapListBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(Color.snap.background)
            .textCase(nil)  // section headers stay in sentence case
    }
}
