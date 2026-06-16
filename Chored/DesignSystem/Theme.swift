import SwiftUI

/// Visual layout tokens. No logic. Values come directly from DESIGN.md.
enum Theme {

    /// Base-8 spacing scale. Every padding/margin/gap derives from this.
    enum Spacing {
        /// 4pt — chip internal padding (vertical).
        static let xs: CGFloat = 4
        /// 8pt — chip internal padding (horizontal), icon gaps.
        static let sm: CGFloat = 8
        /// 16pt — standard cell padding, form field insets.
        static let md: CGFloat = 16
        /// 24pt — section spacing, card padding, FAB inset.
        static let lg: CGFloat = 24
        /// 32pt — screen-level top/bottom padding.
        static let xl: CGFloat = 32
    }

    /// Corner radii from DESIGN.md.
    enum Radius {
        /// 6pt — task chips.
        static let chip: CGFloat = 6
        /// 12pt — cards / sheets.
        static let card: CGFloat = 12
        /// 10pt — buttons.
        static let button: CGFloat = 10
    }

    /// Fixed dimensions called out in component specs.
    enum Size {
        static let chipMinHeight: CGFloat = 56
        static let chipColorBarWidth: CGFloat = 3
        static let assigneeAvatar: CGFloat = 28
        static let fab: CGFloat = 52
        static let monthDot: CGFloat = 7
        static let calendarDot: CGFloat = 10
        static let minTouchTarget: CGFloat = 44
    }
}
