import SwiftUI

/// iOS 26/27 Liquid Glass can wash out custom cook chrome, recipe bands, and
/// sheets. These helpers pin opaque Adaptable surfaces and replace APIs that
/// the iOS 27 SDK treats as deprecated (notably `navigationBarHidden`).
extension View {
    /// Replaces deprecated `navigationBarHidden(true)` for Xcode 27.
    @ViewBuilder
    func kitchenNavigationHidden() -> some View {
        if #available(iOS 18.0, *) {
            self.toolbarVisibility(.hidden, for: .navigationBar)
        } else {
            self.toolbar(.hidden, for: .navigationBar)
        }
    }

    /// Replaces deprecated `toolbar(.hidden, for: .tabBar)` naming on iOS 18+.
    @ViewBuilder
    func kitchenTabBarHidden() -> some View {
        if #available(iOS 18.0, *) {
            self.toolbarVisibility(.hidden, for: .tabBar)
        } else {
            self.toolbar(.hidden, for: .tabBar)
        }
    }

    /// Forces an opaque sheet fill so ingredients / adapt / plan lists stay
    /// readable when the system sheet material becomes Liquid Glass.
    func kitchenSheetSurface() -> some View {
        self.presentationBackground(Theme.surface)
    }

    /// Pins a solid bar behind custom cook / recipe chrome so step type does
    /// not show through when the window adopts glass.
    func kitchenOpaqueBar() -> some View {
        self.background(Theme.surface)
    }

    /// Hard scroll-edge treatment so step text does not blur under cook chrome.
    @ViewBuilder
    func kitchenScrollEdge() -> some View {
        if #available(iOS 26.0, *) {
            self.scrollEdgeEffectStyle(.hard, for: .top)
        } else {
            self
        }
    }
}
