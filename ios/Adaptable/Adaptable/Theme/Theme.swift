import SwiftUI
import UIKit

/// Design tokens ported from `src/index.css`. Colors auto-adapt to light
/// and dark mode via `UIColor` dynamic providers, exactly like the web
/// app's `prefers-color-scheme` CSS variables.
enum Theme {
    static let surface = Color(dynamic: (light: "#FAF8F5", dark: "#0C0A09"))
    static let raised = Color(dynamic: (light: "#FFFFFF", dark: "#1C1917"))
    static let sunken = Color(dynamic: (light: "#F0ECE6", dark: "#141110"))
    static let line = Color(dynamic: (light: "#1C1917", dark: "#FAF8F5")).opacity(0.09)
    static let content = Color(dynamic: (light: "#1C1917", dark: "#F5F2EE"))
    static let muted = Color(dynamic: (light: "#78716C", dark: "#A8A29E"))
    static let faint = Color(dynamic: (light: "#A8A29E", dark: "#78716C"))
    static let accent = Color(dynamic: (light: "#EA580C", dark: "#F97316"))
    static let accentStrong = Color(dynamic: (light: "#C2410C", dark: "#FB923C"))
    static let accentSoft = Color(dynamic: (light: "#EA580C", dark: "#F97316")).opacity(0.14)
    static let up = Color(dynamic: (light: "#16A34A", dark: "#4ADE80"))
    static let down = Color(dynamic: (light: "#DC2626", dark: "#F87171"))

    /// The hero chef-hat gradient used on the Auth splash, Generate CTA and
    /// action buttons — identical across themes.
    static let heroGradient = LinearGradient(
        colors: [Color(hex: "#fb923c"), Color(hex: "#ea580c"), Color(hex: "#dc2626")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardRadius: CGFloat = 24
}

extension Color {
    init(dynamic pair: (light: String, dark: String)) {
        self.init(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hexString: pair.dark) : UIColor(hexString: pair.light)
        })
    }
}

private extension UIColor {
    convenience init(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        s.removeAll { $0 == "#" }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r = CGFloat((value & 0xFF0000) >> 16) / 255
        let g = CGFloat((value & 0x00FF00) >> 8) / 255
        let b = CGFloat(value & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

// MARK: - Shared view modifiers

/// Scale-down-on-press feedback used across all tappables (`.pressable` in CSS).
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
}

/// Gentle up-and-fade entrance, staggered by index. Mirrors `animate-fade-up`.
struct FadeUpAppear: ViewModifier {
    var delay: Double
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 14)
            .onAppear {
                withAnimation(.easeOut(duration: 0.45).delay(delay)) { shown = true }
            }
    }
}

extension View {
    func fadeUpAppear(index: Int = 0, unit: Double = 0.06, cap: Int = 8) -> some View {
        modifier(FadeUpAppear(delay: Double(min(index, cap)) * unit))
    }
}

/// Slow float used on hero icons and empty-state emoji. Mirrors `animate-float`.
struct FloatEffect: ViewModifier {
    @State private var up = false
    func body(content: Content) -> some View {
        content
            .offset(y: up ? -8 : 0)
            .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: up)
            .onAppear { up = true }
    }
}

extension View {
    var floating: some View { modifier(FloatEffect()) }
}
