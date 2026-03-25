import UIKit

enum Haptics {
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let notification = UINotificationFeedbackGenerator()
    private static let selection = UISelectionFeedbackGenerator()

    /// Light tap — filter toggles, tab switches, expanding items
    static func tap() {
        lightImpact.impactOccurred()
    }

    /// Medium impact — button presses, significant actions
    static func impact() {
        mediumImpact.impactOccurred()
    }

    /// Success — pipeline complete, workflow submitted, import done
    static func success() {
        notification.notificationOccurred(.success)
    }

    /// Warning — degraded connection, low confidence
    static func warning() {
        notification.notificationOccurred(.warning)
    }

    /// Error — failed request, server unreachable
    static func error() {
        notification.notificationOccurred(.error)
    }

    /// Selection changed — picker changes, category overrides
    static func selectionChanged() {
        selection.selectionChanged()
    }
}
