import AppIntents
import ReplayKit
import UIKit

/// Holds the live broadcast picker so anything in the app can raise the
/// system broadcast sheet without the user hunting for the card.
///
/// iOS allows no programmatic *start* of a broadcast — but the sheet that
/// starts one can be raised from code, by sending the picker's own button
/// its action. So the shortest possible path is: trigger (Siri, Back Tap,
/// Shortcuts, or the card's Start button) raises the sheet, and the user
/// confirms with a single tap on Start Broadcast. That last tap is the
/// consent, and there is no way around it — nor should there be.
final class BroadcastLauncher {
    static let shared = BroadcastLauncher()
    private init() {}

    weak var picker: RPSystemBroadcastPickerView?

    /// True when a picker is mounted and the sheet can be raised.
    var isReady: Bool { picker != nil }

    func presentSheet() {
        guard let picker, let button = Self.firstButton(in: picker) else { return }
        button.sendActions(for: .touchUpInside)
    }

    static func firstButton(in view: UIView) -> UIButton? {
        for subview in view.subviews {
            if let button = subview as? UIButton { return button }
            if let nested = firstButton(in: subview) { return nested }
        }
        return nil
    }
}

extension Notification.Name {
    static let startScreenLearning = Notification.Name("TypikeyStartScreenLearning")
}

/// Shortcuts entry point. Opens Typikey and raises the broadcast sheet, so
/// starting a training session costs one confirming tap.
///
/// The trigger matters more than it looks. Our user cannot speak, so voice
/// is not an option, and his iPad lives on a stand, so Back Tap is not
/// either — both of those "just say / just tap the back" answers assume a
/// body this keyboard exists precisely because its user does not have.
/// What does reach him is a shortcut placed in the AssistiveTouch menu,
/// which a pointer or joystick can open, or one bound to a switch. Being a
/// Shortcuts action is what makes all of those possible.
struct StartScreenLearningIntent: AppIntent {
    static var title: LocalizedStringResource = "Start screen learning"
    static var description = IntentDescription(
        "Opens Typikey and brings up the broadcast sheet, ready to learn the words on your screen. You still confirm with Start Broadcast.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .startScreenLearning, object: nil)
        return .result()
    }
}

struct TypikeyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartScreenLearningIntent(),
            phrases: ["Start screen learning in \(.applicationName)"],
            shortTitle: "Start screen learning",
            systemImageName: "text.viewfinder")
    }
}
