import UIKit

// ✅ Fully migrated — design tokens with no mutable global state

enum ColorToken {
    static let primary = UIColor.systemBlue
    static let secondary = UIColor.systemIndigo
    static let background = UIColor.systemBackground
    static let surface = UIColor.secondarySystemBackground
    static let error = UIColor.systemRed
    static let success = UIColor.systemGreen
    static let warning = UIColor.systemYellow
    static let textPrimary = UIColor.label
    static let textSecondary = UIColor.secondaryLabel
}

enum SpacingToken {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum TypographyToken {
    static let largeTitle = UIFont.preferredFont(forTextStyle: .largeTitle)
    static let title1 = UIFont.preferredFont(forTextStyle: .title1)
    static let title2 = UIFont.preferredFont(forTextStyle: .title2)
    static let headline = UIFont.preferredFont(forTextStyle: .headline)
    static let body = UIFont.preferredFont(forTextStyle: .body)
    static let caption = UIFont.preferredFont(forTextStyle: .caption1)
}
