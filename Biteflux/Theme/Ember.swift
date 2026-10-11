import SwiftUI

/// Colours and type from the B4 Ember design.
enum Ember {
    static let background = Color(hex: 0x17110E)
    static let surface = Color(hex: 0x241B16)
    static let track = Color(hex: 0x31251E)
    static let alertSurface = Color(hex: 0x2E1A17)

    static let text = Color(hex: 0xF7EDE6)
    static let rowText = Color(hex: 0xE2D3C8)
    static let secondaryText = Color(hex: 0xC4B2A6)

    static let accent = Color(hex: 0xFF9466)
    static let onAccent = Color(hex: 0x1F0E06)

    /// Sync status: in Apple Health, still saving, and failed.
    static let confirmed = Color(hex: 0x9FD3A8)
    static let pending = Color(hex: 0xF4C46A)
    static let failed = Color(hex: 0xFF9C8F)

    /// DM Serif Display, used for the big numbers and headlines.
    static func serif(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .custom("DMSerifDisplay-Regular", size: size, relativeTo: style)
    }

    /// DM Sans, used for everything else.
    static func sans(_ size: CGFloat, weight: SansWeight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(weight.fontName, size: size, relativeTo: style)
    }

    enum SansWeight {
        case regular
        case medium
        case bold

        var fontName: String {
            switch self {
            case .regular: "DMSans-Regular"
            case .medium: "DMSans-Medium"
            case .bold: "DMSans-Bold"
            }
        }
    }
}

extension Color {
    /// A colour from a 0xRRGGBB value, as written in the design files.
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
