import SwiftUI
import SnapsetUI

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
                    .foregroundStyle(Color.snap.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.snap.surfaceRaised, in: .rect(cornerRadius: Snap.Radius.chip))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Start and end drawings side by side on the workout screen, so anyone can see the movement.
struct ExerciseDemo: View {
    let exercise: Exercise

    var body: some View {
        let drawings = exercise.drawings
        if !drawings.isEmpty {
            HStack(spacing: 12) {
                ForEach(Array(drawings.enumerated()), id: \.offset) { index, drawing in
                    VStack(spacing: 4) {
                        Image(uiImage: drawing).resizable().scaledToFit().frame(maxHeight: 110)
                        Text(index == 0 ? "Start" : "Finish")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color(white: 0.35))  // fixed: the card is white in dark mode too
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(10)
            .background(.white, in: .rect(cornerRadius: 12))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Drawing of \(exercise.name), start and finish position")
        }
    }
}
