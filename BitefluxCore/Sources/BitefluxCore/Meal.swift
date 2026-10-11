import Foundation

/// The meal an entry belongs to on the Today screen.
public enum Meal: String, CaseIterable, Codable, Sendable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case snacks

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        case .snacks: "Snacks"
        }
    }

    /// The meal to pick for food eaten at `date`:
    /// breakfast 04:00 to 10:59, lunch 11:00 to 14:59, dinner 17:00 to 21:29, snacks otherwise.
    public static func suggested(at date: Date, calendar: Calendar = .current) -> Meal {
        let time = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = (time.hour ?? 0) * 60 + (time.minute ?? 0)
        switch minutes {
        case 4 * 60 ..< 11 * 60: return .breakfast
        case 11 * 60 ..< 15 * 60: return .lunch
        case 17 * 60 ..< 21 * 60 + 30: return .dinner
        default: return .snacks
        }
    }
}
