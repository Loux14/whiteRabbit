import SwiftUI

enum Theme {

    // MARK: - Colors

    static let background       = Color(red: 0.04, green: 0.04, blue: 0.04)
    static let backgroundChat   = Color(red: 0.08, green: 0.08, blue: 0.08)
    static let surface          = Color(red: 0.08, green: 0.08, blue: 0.08)
    static let border           = Color(red: 0.15, green: 0.15, blue: 0.15)

    static let primary          = Color(red: 0.18, green: 0.95, blue: 0.35)   // terminal green
    static let primaryDim       = Color(red: 0.08, green: 0.45, blue: 0.16)   // darker green
    static let textPrimary      = Color(red: 0.85, green: 0.95, blue: 0.85)
    static let textSecondary    = Color(red: 0.40, green: 0.60, blue: 0.40)

    static let bubbleOut        = Color(red: 0.06, green: 0.28, blue: 0.10)
    static let bubbleOutText    = Color(red: 0.18, green: 0.95, blue: 0.35)
    static let bubbleIn         = Color(red: 0.10, green: 0.10, blue: 0.10)
    static let bubbleInText     = Color(red: 0.85, green: 0.95, blue: 0.85)

    // MARK: - Fonts

    static let fontMono         = Font.system(.body, design: .monospaced)
    static let fontMonoCaption  = Font.system(.caption, design: .monospaced)
    static let fontMonoSmall    = Font.system(.caption2, design: .monospaced)

    // MARK: - UIKit (for NavigationBar)

    static func applyNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(background)
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(primary),
            .font: UIFont.monospacedSystemFont(ofSize: 17, weight: .semibold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(primary),
            .font: UIFont.monospacedSystemFont(ofSize: 34, weight: .bold)
        ]
        appearance.shadowColor = UIColor(border)
        UINavigationBar.appearance().standardAppearance        = appearance
        UINavigationBar.appearance().scrollEdgeAppearance      = appearance
        UINavigationBar.appearance().compactAppearance         = appearance
        UINavigationBar.appearance().compactScrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor                 = UIColor(primary)
        UIBarButtonItem.appearance().tintColor                 = UIColor(primary)
    }

    static func applyGlobalAppearance() {
        UITableView.appearance().backgroundColor = UIColor(background)
        UITableViewCell.appearance().backgroundColor = UIColor(background)
        applyNavigationBarAppearance()
    }
}
