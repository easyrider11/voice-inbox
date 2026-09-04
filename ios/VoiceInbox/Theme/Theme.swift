import SwiftUI
import UIKit

// PROJECT.md §6.5 — two-mode identity, one accent at a time:
// day  = white ground + orange accent
// night = black ground + yellow accent
// The ground comes from the system grouped backgrounds (white-ish / true black);
// these tokens carry the accent and whatever sits on top of it.

extension Color {
    /// The only chromatic color in the app.
    /// Light: orange `#FF8C1A`. Dark: yellow `#FFD60A`.
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 214.0 / 255.0, blue: 10.0 / 255.0, alpha: 1)
            : UIColor(red: 1.0, green: 140.0 / 255.0, blue: 26.0 / 255.0, alpha: 1)
    })

    /// Glyphs and text drawn on top of `accent`: white on orange by day,
    /// black on yellow by night (white on yellow is unreadable).
    static let onAccent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? .black : .white
    })
}
