import SwiftUI

/// Motion tokens — the single source of animation parameters (B12).
///
/// Grounded in the apple-design / emil-design-eng rules:
/// - Critically damped springs (dampingFraction 1.0) for state changes;
///   bounce is reserved for gesture releases that carried momentum.
/// - UI animations stay under ~300 ms; exits are faster than entrances.
/// - Entrances never start from scale 0 — 0.95 + opacity.
/// - Reduced motion swaps movement for short cross-fades, never "no feedback".
enum Motion {
    /// Touch-down feedback (scale 0.97). Instant-feeling, ease-out.
    static let press = Animation.easeOut(duration: 0.12)

    /// State morphs on screen (mic ↔ stop, chip changes). No overshoot.
    static let state = Animation.spring(response: 0.28, dampingFraction: 1.0)

    /// Element entrances (lock target, cancel button, new cards).
    static let enter = Animation.spring(response: 0.35, dampingFraction: 0.9)

    /// Exits — always snappier than entrances.
    static let exit = Animation.easeOut(duration: 0.16)

    /// Release of a drag: carries momentum, slight bounce is earned.
    static let momentum = Animation.spring(response: 0.35, dampingFraction: 0.8)

    /// Interactive tracking spring for values that follow the finger
    /// but need light smoothing (stack-behind cards catching up).
    static let interactive = Animation.interactiveSpring(response: 0.15, dampingFraction: 0.86)

    /// Entrance transition: nothing appears from nothing.
    static var cardInsertion: AnyTransition {
        AnyTransition.scale(scale: 0.96, anchor: .center)
            .combined(with: .opacity)
            .combined(with: .offset(y: 8))
    }

    /// Pick the token, honoring Reduce Motion (cross-fade instead of movement).
    static func respecting(_ reduce: Bool, _ animation: Animation) -> Animation {
        reduce ? .easeOut(duration: 0.15) : animation
    }

    /// Apple's rubber-band: progressive resistance past a boundary instead of
    /// a hard stop. The further past the limit, the less the element follows.
    static func rubberband(_ overshoot: CGFloat, dimension: CGFloat = 150, constant: CGFloat = 0.55) -> CGFloat {
        (overshoot * dimension * constant) / (dimension + constant * abs(overshoot))
    }
}
