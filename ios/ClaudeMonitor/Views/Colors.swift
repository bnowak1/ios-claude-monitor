import SwiftUI

extension Color {
    // Background colors
    static let backgroundPrimary = Color(hex: "0D0D0D")
    static let surface = Color(hex: "1A1A1A")
    static let surfaceElevated = Color(hex: "262626")

    // Accent
    static let accentOrange = Color(hex: "E07A3A")

    // Status colors
    static let statusActive = Color(hex: "34C759")
    static let statusIdle = Color(hex: "FFD60A")
    static let statusEnded = Color(hex: "636366")
    static let statusError = Color(hex: "FF453A")

    // Text colors
    static let textPrimary = Color(hex: "FFFFFF")
    static let textSecondary = Color(hex: "8E8E93")
    static let textTertiary = Color(hex: "636366")

    // Initialize from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// Color by name for dynamic status colors
extension Color {
    init(_ name: String) {
        switch name {
        case "statusActive":
            self = .statusActive
        case "statusIdle":
            self = .statusIdle
        case "statusEnded":
            self = .statusEnded
        case "statusError":
            self = .statusError
        default:
            self = .textPrimary
        }
    }
}
