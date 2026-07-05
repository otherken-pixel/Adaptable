import SwiftUI

/// Deterministic, appetizing cover gradients — every recipe gets a stable
/// pair derived from its id, so cards look designed without image assets.
/// Mirrors `src/lib/gradients.ts`.
enum Gradients {
    private static let palettes: [(String, String)] = [
        ("#FF9A62", "#F0432C"), // ember
        ("#FFC148", "#F07C22"), // saffron
        ("#7BD88F", "#1F9D6B"), // herb
        ("#67C5E8", "#2D6CDF"), // tide
        ("#C48BF0", "#7D3CE8"), // ube
        ("#FF8FB1", "#E4426E"), // hibiscus
        ("#F6D365", "#FDA085"), // apricot
        ("#84FAB0", "#8FD3F4"), // matcha mist
    ]

    static func cover(for seed: String) -> LinearGradient {
        var hash: Int32 = 0
        for ch in seed.unicodeScalars {
            hash = hash &* 31 &+ Int32(ch.value)
        }
        let idx = abs(Int(hash)) % palettes.count
        let (from, to) = palettes[idx]
        return LinearGradient(
            colors: [Color(hex: from), Color(hex: to)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        s.removeAll { $0 == "#" }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r = Double((value & 0xFF0000) >> 16) / 255
        let g = Double((value & 0x00FF00) >> 8) / 255
        let b = Double(value & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
