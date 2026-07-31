import Foundation
import SwiftUI
import UIKit

/// Formats a cookable plain-text recipe + deep link for the system share sheet.
/// Mirrors `src/lib/shareRecipe.ts`.
enum RecipeShare {
    struct Payload {
        let title: String
        let text: String
        let url: URL
    }

    static func build(recipe: Recipe, servings: Int) -> Payload {
        let baseServings = max(1, recipe.servings ?? 1)
        let factor = Double(servings) / Double(baseServings)
        let url = SiteConfig.recipeURL(id: recipe.id)
        let emoji = (recipe.emoji ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let title = (recipe.title ?? "Recipe").trimmingCharacters(in: .whitespacesAndNewlines)
        let head = emoji.isEmpty ? title : "\(emoji) \(title)"

        var lines: [String] = [head, ""]

        if let description = recipe.description?.trimmingCharacters(in: .whitespacesAndNewlines),
           !description.isEmpty {
            lines.append(description)
            lines.append("")
        }

        var meta: [String] = []
        let mins = Format.totalMinutes(
            prep: recipe.prep_time_minutes ?? 0,
            cook: recipe.cook_time_minutes ?? 0
        )
        if !mins.isEmpty { meta.append("⏱ \(mins)") }
        if let difficulty = recipe.difficulty?.rawValue { meta.append(difficulty) }
        meta.append("Serves \(servings)")
        lines.append(meta.joined(separator: " · "))
        lines.append("")

        let ingredients = recipe.ingredients ?? []
        if !ingredients.isEmpty {
            lines.append("INGREDIENTS")
            for ing in ingredients {
                let qty = Quantity.scale(ing.quantity, factor: factor)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let note: String = {
                    guard let n = ing.note?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty else {
                        return ""
                    }
                    return " (\(n))"
                }()
                let qtyPart = qty.isEmpty ? "" : "\(qty) "
                lines.append("• \(qtyPart)\(ing.item)\(note)")
            }
            lines.append("")
        }

        let steps = recipe.steps ?? []
        if !steps.isEmpty {
            lines.append("METHOD")
            for step in steps {
                lines.append("\(step.step). \(step.instruction.trimmingCharacters(in: .whitespacesAndNewlines))")
                if let tip = step.tip?.trimmingCharacters(in: .whitespacesAndNewlines), !tip.isEmpty {
                    lines.append("   💡 \(tip)")
                }
            }
            lines.append("")
        }

        lines.append("Made with Adaptable")
        // Include the deep link in the plain-text body so Messages recipients
        // always get a tappable Universal Link even when the share sheet
        // strips separate URL items for some targets.
        lines.append(url.absoluteString)

        return Payload(
            title: head,
            text: lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines),
            url: url
        )
    }

    /// Render a simple share card image for iMessage / social.
    @MainActor
    static func cardImage(recipe: Recipe) -> UIImage? {
        let view = RecipeShareCardView(recipe: recipe)
            .frame(width: 600, height: 360)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.uiImage
    }
}

// MARK: - Share card

private struct RecipeShareCardView: View {
    let recipe: Recipe

    var body: some View {
        ZStack {
            Gradients.cover(for: recipe.id)
            VStack(spacing: 16) {
                Text(recipe.emoji ?? "🍳")
                    .font(.system(size: 88))
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                Text(recipe.title ?? "Recipe")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                    .padding(.horizontal, 28)
                    .lineLimit(3)
                HStack(spacing: 14) {
                    let mins = Format.totalMinutes(
                        prep: recipe.prep_time_minutes ?? 0,
                        cook: recipe.cook_time_minutes ?? 0
                    )
                    if !mins.isEmpty {
                        chip(mins)
                    }
                    if let difficulty = recipe.difficulty?.rawValue {
                        chip(difficulty)
                    }
                    if let servings = recipe.servings {
                        chip("Serves \(servings)")
                    }
                }
                Text("Adaptable")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 4)
            }
            .padding(28)
        }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.white.opacity(0.22), in: Capsule())
    }
}
