import SwiftUI

/// One suggested 2–3 meal prep bundle. Shows why the meals are grouped
/// and either adds them to the week or generates the missing piece.
struct MealPrepBundleCard: View {
    let bundle: MealPrepBundle
    var isCompleting: Bool = false
    var justAdded: Bool = false
    var onAddToWeek: () -> Void
    var onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                kindChip
                Spacer()
                Text(countLabel)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.muted)
            }

            Text(bundle.headline)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(Theme.content)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .center, spacing: 12) {
                coverStack
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(bundle.recipes.prefix(3)) { recipe in
                        NavigationLink(value: Route.recipe(id: recipe.id)) {
                            HStack(spacing: 6) {
                                Text(recipe.title ?? "Recipe")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.content)
                                    .lineLimit(1)
                                if bundle.generated_ids.contains(recipe.id) {
                                    Text("NEW")
                                        .font(.system(size: 9, weight: .heavy))
                                        .foregroundStyle(Theme.accent)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Theme.accentSoft, in: Capsule())
                                }
                            }
                        }
                    }
                    if bundle.missing_count > 0 {
                        Text("+ \(bundle.missing_count) to generate")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.accent)
                    }
                }
            }

            Text(bundle.reason)
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                MetaPill(icon: "clock", label: "\(bundle.session_minutes) min")
                if let cal = bundle.avg_calories {
                    MetaPill(icon: "flame", label: "~\(cal) cal")
                }
                if !bundle.shared_ingredients.isEmpty, bundle.kind == .sharedBase {
                    MetaPill(icon: "leaf", label: Format.list(bundle.shared_ingredients))
                }
            }

            actionButton
        }
        .padding(16)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .stroke(Theme.line)
        )
    }

    private var countLabel: String {
        if bundle.missing_count > 0 {
            return "\(bundle.recipes.count) of 3 meals"
        }
        return "\(bundle.recipes.count) \(bundle.recipes.count == 1 ? "meal" : "meals")"
    }

    private var kindChip: some View {
        let (label, accent) = chipStyle
        return Text(label)
            .font(.system(size: 10, weight: .heavy))
            .tracking(0.6)
            .foregroundStyle(accent ? Theme.accent : Theme.muted)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(accent ? Theme.accentSoft : Theme.sunken, in: Capsule())
    }

    private var chipStyle: (String, Bool) {
        if bundle.missing_count > 0 { return ("NEEDS A MEAL", true) }
        switch bundle.kind {
        case .sharedBase: return ("SHARED BASE", true)
        case .concurrent: return ("COOK TOGETHER", true)
        }
    }

    private var coverStack: some View {
        HStack(spacing: -14) {
            ForEach(Array(bundle.recipes.prefix(3).enumerated()), id: \.element.id) { i, recipe in
                NavigationLink(value: Route.recipe(id: recipe.id)) {
                    RecipeCoverView(
                        recipeId: recipe.id,
                        emoji: recipe.emoji,
                        imageUrl: recipe.image_url,
                        cuisine: nil,
                        height: 56,
                        emojiSize: 22
                    )
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Theme.raised, lineWidth: 2)
                    )
                    .zIndex(Double(3 - i))
                }
            }
            if bundle.missing_count > 0 {
                ZStack {
                    Theme.sunken
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Theme.raised, lineWidth: 2)
                )
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if bundle.isComplete {
            Button(action: onAddToWeek) {
                HStack(spacing: 8) {
                    Image(systemName: justAdded ? "checkmark" : "calendar.badge.plus")
                    Text(justAdded ? "Added to this week" : "Add to this week")
                        .font(.system(size: 15, weight: .heavy))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(justAdded ? Theme.accent : Theme.surface)
                .background(
                    justAdded ? AnyShapeStyle(Theme.accentSoft) : AnyShapeStyle(Theme.content),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            }
            .buttonStyle(.pressable)
            .disabled(justAdded)
        } else {
            Button(action: onComplete) {
                HStack(spacing: 8) {
                    if isCompleting {
                        ProgressView().tint(Theme.surface)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(isCompleting ? "Cooking up the missing meal…" : completeLabel)
                        .font(.system(size: 15, weight: .heavy))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(Theme.surface)
                .background(Theme.heroGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.pressable)
            .disabled(isCompleting)
        }
    }

    private var completeLabel: String {
        bundle.missing_count == 1 ? "Generate the missing meal" : "Generate the missing meals"
    }
}
