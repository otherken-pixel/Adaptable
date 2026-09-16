import SwiftUI
import UIKit

/// Opaque kitchen palette for widgets / Live Activities.
/// `.fill.tertiary` becomes Liquid Glass on iOS 26/27 and washes out type.
enum KitchenWidgetChrome {
    static let surface = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.047, green: 0.039, blue: 0.035, alpha: 1)
            : UIColor(red: 0.980, green: 0.973, blue: 0.961, alpha: 1)
    })

    static let content = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.961, green: 0.949, blue: 0.933, alpha: 1)
            : UIColor(red: 0.110, green: 0.098, blue: 0.090, alpha: 1)
    })

    static let secondary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.659, green: 0.635, blue: 0.620, alpha: 1)
            : UIColor(red: 0.471, green: 0.443, blue: 0.424, alpha: 1)
    })

    static let accent = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.976, green: 0.451, blue: 0.086, alpha: 1)
            : UIColor(red: 0.918, green: 0.345, blue: 0.047, alpha: 1)
    })

    /// Lock-screen / Dynamic Island fill — dark on purpose so the countdown
    /// stays readable over glass chrome the system composites around activities.
    static let activityFill = Color(red: 0.121, green: 0.071, blue: 0.043)
}

extension View {
    func kitchenWidgetSurface() -> some View {
        containerBackground(for: .widget) {
            KitchenWidgetChrome.surface
        }
    }

    func kitchenActivitySurface() -> some View {
        self
            .containerBackground(for: .widget) {
                KitchenWidgetChrome.activityFill
            }
            .activityBackgroundTint(KitchenWidgetChrome.activityFill)
            .activitySystemActionForegroundColor(.white)
    }
}
