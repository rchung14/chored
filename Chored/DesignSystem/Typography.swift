import SwiftUI

/// Type-role view modifiers. SF Pro at system scales only — no custom fonts,
/// no italic/underline/letter-spacing. Roles map 1:1 to DESIGN.md's table.
extension View {

    func choredLargeTitle() -> some View { font(.largeTitle) }
    func choredTitle() -> some View { font(.title) }
    func choredTitle2() -> some View { font(.title2) }
    func choredTitle3() -> some View { font(.title3.weight(.semibold)) }
    func choredHeadline() -> some View { font(.headline) }            // 17 semibold
    func choredBody() -> some View { font(.body) }
    func choredCallout() -> some View { font(.callout) }
    func choredSubheadline() -> some View { font(.subheadline) }
    func choredCaption() -> some View { font(.caption) }
    func choredCaption2() -> some View { font(.caption2) }
}
