import SwiftUI
import UIKit

// PROJECT.md §6.5 — black-and-white neutral base, warm amber as the only accent.

extension Color {
    /// Warm amber accent: #FFA01E in light mode, #FFB84D in dark mode.
    static let amber = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 184.0 / 255.0, blue: 77.0 / 255.0, alpha: 1)
            : UIColor(red: 1.0, green: 160.0 / 255.0, blue: 30.0 / 255.0, alpha: 1)
    })
}
