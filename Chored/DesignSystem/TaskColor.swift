import SwiftUI

/// The six (and only) custom colors in the app. Hex values + paired label
/// colors come straight from DESIGN.md. No business logic — purely presentation.
enum TaskColorPreset: Int, CaseIterable, Identifiable {
    case sage = 0
    case rose = 1
    case lavender = 2
    case sky = 3
    case peach = 4
    case slate = 5

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .sage: return "Sage"
        case .rose: return "Rose"
        case .lavender: return "Lavender"
        case .sky: return "Sky"
        case .peach: return "Peach"
        case .slate: return "Slate"
        }
    }

    /// Chip background hex (100% opacity in light mode).
    private var backgroundHex: String {
        switch self {
        case .sage: return "A8C5A0"
        case .rose: return "E8B4B8"
        case .lavender: return "C3B1E1"
        case .sky: return "A8C8E8"
        case .peach: return "F5C5A3"
        case .slate: return "9BB5C8"
        }
    }

    /// Paired dark label color for text rendered on the chip.
    private var labelHex: String {
        switch self {
        case .sage: return "2D4A28"
        case .rose: return "5C2327"
        case .lavender: return "3B2769"
        case .sky: return "1A3D5C"
        case .peach: return "6B3A1F"
        case .slate: return "1E3444"
        }
    }

    var labelColor: Color { Color(hex: labelHex) }

    /// Chip/dot color. Per DESIGN.md, dark mode renders at 70% opacity so the
    /// color does not dominate the dark surface.
    func background(for scheme: ColorScheme) -> Color {
        let base = Color(hex: backgroundHex)
        return scheme == .dark ? base.opacity(0.70) : base
    }

    /// Safe lookup from a stored preset index, defaulting to Sage.
    static func from(index: Int) -> TaskColorPreset {
        TaskColorPreset(rawValue: index) ?? .sage
    }
}

extension Color {
    /// Initialize from a 6-digit RGB hex string (no leading #).
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)
        let r = Double((value & 0xFF0000) >> 16) / 255.0
        let g = Double((value & 0x00FF00) >> 8) / 255.0
        let b = Double(value & 0x0000FF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}
