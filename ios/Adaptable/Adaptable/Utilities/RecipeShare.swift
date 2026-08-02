import Foundation
import SwiftUI
import UIKit

/// Formats a cookable plain-text recipe + deep link for the system share sheet.
/// Prefers the AI dish photo for the iMessage image card when available.
/// Mirrors `src/lib/shareRecipe.ts`.
enum RecipeShare {
    struct Payload {
        let title: String
        let text: String
        let url: URL
    }

    private static var photoCache: [String: UIImage] = [:]
    private static let photoLoadTimeoutNs: UInt64 = 1_500_000_000

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
        lines.append(url.absoluteString)

        return Payload(
            title: head,
            text: lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines),
            url: url
        )
    }

    /// Load dish photo (cached) then render a share card for iMessage / social.
    /// Falls back to emoji gradient if the photo is missing or times out (~1.5s).
    @MainActor
    static func cardImage(recipe: Recipe, servings: Int? = nil) async -> UIImage? {
        let photo = await loadDishPhoto(recipe: recipe)
        return renderCard(recipe: recipe, photo: photo, servings: servings)
    }

    /// Synchronous fallback (emoji card only) when callers cannot await.
    @MainActor
    static func cardImage(recipe: Recipe) -> UIImage? {
        if let url = recipe.image_url, let cached = photoCache[url] {
            return renderCard(recipe: recipe, photo: cached, servings: nil)
        }
        return renderCard(recipe: recipe, photo: nil, servings: nil)
    }

    // MARK: - Photo load

    @MainActor
    private static func loadDishPhoto(recipe: Recipe) async -> UIImage? {
        guard let raw = recipe.image_url?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty,
              let url = URL(string: raw)
        else { return nil }

        if let cached = photoCache[raw] { return cached }

        return await withTaskGroup(of: UIImage?.self) { group in
            group.addTask {
                do {
                    let (data, response) = try await URLSession.shared.data(from: url)
                    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                          let image = UIImage(data: data)
                    else { return nil }
                    await MainActor.run { photoCache[raw] = image }
                    return image
                } catch {
                    return nil
                }
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: photoLoadTimeoutNs)
                return nil
            }
            // First finished task wins (image, failed fetch, or timeout); cancel the rest.
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }

    @MainActor
    private static func renderCard(recipe: Recipe, photo: UIImage?, servings: Int?) -> UIImage? {
        let view = RecipeShareCardView(recipe: recipe, photo: photo, servingsOverride: servings)
            .frame(width: 600, height: 360)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.uiImage
    }
}

// MARK: - Share card

private struct RecipeShareCardView: View {
    let recipe: Recipe
    var photo: UIImage?
    var servingsOverride: Int?

    var body: some View {
        ZStack {
            background
            LinearGradient(
                colors: [
                    .black.opacity(photo == nil ? 0.15 : 0.25),
                    .black.opacity(0.55),
                    .black.opacity(0.78),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(spacing: 14) {
                Spacer(minLength: 8)
                if photo == nil {
                    Text(recipe.emoji ?? "🍳")
                        .font(.system(size: 72))
                        .shadow(color: .black.opacity(0.35), radius: 10, y: 6)
                }
                Text(recipe.title ?? "Recipe")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.45), radius: 8, y: 2)
                    .padding(.horizontal, 28)
                    .lineLimit(3)
                HStack(spacing: 12) {
                    let mins = Format.totalMinutes(
                        prep: recipe.prep_time_minutes ?? 0,
                        cook: recipe.cook_time_minutes ?? 0
                    )
                    if !mins.isEmpty { chip(mins) }
                    if let difficulty = recipe.difficulty?.rawValue { chip(difficulty) }
                    let serves = servingsOverride ?? recipe.servings
                    if let serves { chip("Serves \(serves)") }
                }
                Text("Adaptable")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 2)
                Spacer(minLength: 8)
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private var background: some View {
        if let photo {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: 600, height: 360)
                .clipped()
        } else {
            Gradients.cover(for: recipe.id)
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
