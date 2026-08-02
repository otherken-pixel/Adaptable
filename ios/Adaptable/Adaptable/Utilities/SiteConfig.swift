import Foundation

/// Public web origin for share links, Universal Links, and OG previews.
/// Mirrors `src/lib/site.ts`.
enum SiteConfig {
    static let baseURLString = "https://adaptable-pi.vercel.app"
    static let baseURL = URL(string: baseURLString)!

    /// Hosts accepted for Universal Links / deep link parsing.
    static let universalLinkHosts: Set<String> = [
        "adaptable-pi.vercel.app",
        "adaptable.cooking",
        "www.adaptable.cooking",
    ]

    static func recipeURL(id: String) -> URL {
        baseURL
            .appendingPathComponent("recipe")
            .appendingPathComponent(id)
    }

    /// Parse a recipe id from a Universal Link or custom-scheme URL.
    static func recipeId(from url: URL) -> String? {
        let scheme = url.scheme?.lowercased() ?? ""
        let host = url.host?.lowercased() ?? ""

        if scheme == "https" || scheme == "http" {
            let allowed =
                universalLinkHosts.contains(host) ||
                host.hasSuffix(".vercel.app")
            guard allowed else { return nil }
            return recipeId(fromPath: url.path)
        }

        if scheme == "com.adaptable.app" {
            if host == "recipe" {
                let id = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                return id.isEmpty ? nil : id
            }
            return recipeId(fromPath: url.path)
        }

        return nil
    }

    private static func recipeId(fromPath path: String) -> String? {
        let parts = path.split(separator: "/").map(String.init)
        guard let idx = parts.firstIndex(of: "recipe"), idx + 1 < parts.count else {
            return nil
        }
        let id = parts[idx + 1]
        return id.isEmpty ? nil : id
    }
}
