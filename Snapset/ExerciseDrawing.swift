import SwiftUI

extension Exercise {
    /// Everkinetic drawings (CC BY-SA 4.0) bundled as "<id>-0.png" (start) and "<id>-1.png" (end); empty when there are none.
    var drawings: [UIImage] {
        (0...1).compactMap { UIImage(named: "\(id)-\($0)") }
    }
}

extension Equipment {
    var symbol: String {
        switch self {
        case .dumbbell: "dumbbell.fill"
        case .bodyweight: "figure.core.training"
        case .machine, .cable, .plateLoaded, .barbell: "figure.strengthtraining.traditional"
        }
    }
}

/// The start drawing, or an equipment icon for exercises without one.
struct ExerciseThumbnail: View {
    let exercise: Exercise
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let drawing = exercise.drawings.first {
                // Black line art on white: keep the white tile in dark mode so the lines stay visible.
                Image(uiImage: drawing).resizable().scaledToFit().padding(2)
                    .background(.white, in: .rect(cornerRadius: 8))
            } else {
                Image(systemName: exercise.equipment.symbol)
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.quaternary, in: .rect(cornerRadius: 8))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
