import SwiftUI

/// S13: confirm a set before saving. Manual entry and photo capture both land here, pre-filled.
struct SetConfirmView: View {
    enum Source: Equatable {
        case manual
        case photoSure
        case photoUnsure(guess: String)
        case photoUnreadable
    }

    struct Model {
        var exercise: String
        var equipmentSymbol: String
        var weight: Double
        var reps: Double
        var unit = "kg"
        var lastTime: String
        var target: String
        var source: Source
    }

    let model: Model
    @State private var weight: Double
    @State private var reps: Double
    @State private var isWarmUp = false
    @State private var savedCount = 0

    init(model: Model) {
        self.model = model
        _weight = State(initialValue: model.weight)
        _reps = State(initialValue: model.reps)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Snap.Spacing.xl) {
            exerciseRow
            sourceNotice
            VStack(spacing: Snap.Spacing.l) {
                HeroNumberStepper("Weight", value: $weight, step: 2.5, in: 0...500, unit: model.unit)
                HeroNumberStepper("Reps", value: $reps, step: 1, in: 0...100, unit: "reps")
            }
            VStack(alignment: .leading, spacing: Snap.Spacing.xs) {
                Text("Last time: \(model.lastTime)").snapText(.secondary)
                Text(model.target).snapText(.secondary)
            }
            HStack(spacing: Snap.Spacing.s) {
                warmUpChip
                Button { } label: {
                    Label("Add note", systemImage: "note.text")
                        .snapText(.body)
                        .frame(minHeight: Snap.Tap.min)
                        .padding(.horizontal, Snap.Spacing.m)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.snap.textPrimary)
            }
            Spacer(minLength: 0)
            PrimaryButton("Save set") { savedCount += 1 }
                .sensoryFeedback(Snap.Haptic.setSaved, trigger: savedCount)
        }
        .padding(.horizontal, Snap.Spacing.l)
        .padding(.top, Snap.Spacing.xl)
        .padding(.bottom, Snap.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.snap.surface)
    }

    private var exerciseRow: some View {
        HStack(spacing: Snap.Spacing.m) {
            Image(systemName: model.equipmentSymbol)
                .font(.title3)
                .frame(width: Snap.Tap.min, height: Snap.Tap.min)
                .background(Color.snap.surfaceRaised, in: .rect(cornerRadius: Snap.Radius.chip))
                .accessibilityHidden(true)
            Text(model.exercise).snapText(.sectionTitle)
            Spacer(minLength: 0)
            Button("Change") { }
                .snapText(.body)
                .frame(minHeight: Snap.Tap.min)
                .foregroundStyle(Color.snap.textSecondary)
        }
        .foregroundStyle(Color.snap.textPrimary)
    }

    @ViewBuilder private var sourceNotice: some View {
        switch model.source {
        case .manual: EmptyView()
        case .photoSure: ConfidenceBadge(.sure)
        case .photoUnsure(let guess): ConfidenceBadge(.unsure(guess: guess))
        case .photoUnreadable:
            Banner(.amber, systemImage: "camera.badge.ellipsis",
                   "Couldn't read the photo. Enter it by hand, it's already filled in.")
        }
    }

    private var warmUpChip: some View {
        Button { isWarmUp.toggle() } label: {
            Label("Warm-up", systemImage: isWarmUp ? "checkmark" : "flame")
                .snapText(.body)
                .padding(.horizontal, Snap.Spacing.m)
                .frame(minHeight: Snap.Tap.min)
                .foregroundStyle(isWarmUp ? Color.snap.background : Color.snap.textPrimary)
                .background(isWarmUp ? Color.snap.textPrimary : Color.snap.surfaceRaised,
                            in: .rect(cornerRadius: Snap.Radius.chip))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isWarmUp ? .isSelected : [])
        .sensoryFeedback(Snap.Haptic.stepperChange, trigger: isWarmUp)
    }
}

extension SetConfirmView.Model {
    static func mock(_ source: SetConfirmView.Source) -> Self {
        Self(exercise: "Seated row", equipmentSymbol: "figure.rower",
             weight: source == .photoUnsure(guess: "40 kg") ? 40 : 42.5, reps: 12,
             lastTime: "42.5 × 12, 42.5 × 11", target: "Today's target", source: source)
    }
}

#Preview("Manual, dark") { SetConfirmView(model: .mock(.manual)).preferredColorScheme(.dark) }
#Preview("Manual, light") { SetConfirmView(model: .mock(.manual)).preferredColorScheme(.light) }
#Preview("Photo sure") { SetConfirmView(model: .mock(.photoSure)).preferredColorScheme(.dark) }
#Preview("Photo unsure") { SetConfirmView(model: .mock(.photoUnsure(guess: "40 kg"))).preferredColorScheme(.dark) }
#Preview("Couldn't read") { SetConfirmView(model: .mock(.photoUnreadable)).preferredColorScheme(.dark) }
#Preview("Manual, AX5") {
    SetConfirmView(model: .mock(.manual)).preferredColorScheme(.dark).dynamicTypeSize(.accessibility5)
}
