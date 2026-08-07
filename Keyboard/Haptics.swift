import UIKit

/// Touch feedback for a user who cannot rely on sight or precision to know
/// what just happened.
///
/// Deliberately strong. A light tap is a nicety on a phone held in the
/// hand; here the iPad sits on a stand and is driven with a joystick or a
/// stiff finger, so the impulse has to carry through a mount and through
/// limited sensation to answer the only question that matters — did that
/// count?
///
/// Three distinct signals, so they can be told apart without looking:
/// a heavy thud when a key commits, a soft tick when the finger slides onto
/// a different key, and a warning pattern when Clear all arms itself.
///
/// Note for testing: haptics in a keyboard extension require Full Access.
/// Without the grant iOS silently drops them, which is one more reason the
/// keyboard must never depend on feedback it might not be allowed to give.
final class Haptics {
    private let commitGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let slideGenerator = UISelectionFeedbackGenerator()
    private let warningGenerator = UINotificationFeedbackGenerator()

    /// Warms the Taptic Engine so the first tap of a session is as prompt
    /// as the rest — an unprepared generator can lag by tens of
    /// milliseconds, which reads as a missed key.
    func prepare() {
        commitGenerator.prepare()
        slideGenerator.prepare()
    }

    /// A key committed: the strongest signal the system offers, at full
    /// intensity, alongside the standard keyboard click.
    func commit() {
        UIDevice.current.playInputClick()
        commitGenerator.impactOccurred(intensity: 1.0)
        commitGenerator.prepare()
    }

    /// The highlight moved to a different key mid-slide. Explore-then-commit
    /// means sliding is free, and this is what makes it legible without
    /// watching the screen.
    func slidToNewKey() {
        slideGenerator.selectionChanged()
        slideGenerator.prepare()
    }

    /// Clear all is armed and the next tap erases everything.
    func armedDestructive() {
        warningGenerator.notificationOccurred(.warning)
    }
}
