import Foundation

enum DateFormatting {
    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year())
    }

    static func compactDateRange(start: Date, end: Date) -> String {
        "\(shortDate(start)) - \(shortDate(end))"
    }

    static func dateTime(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year().hour().minute())
    }

    static func subjectDateRange(start: Date, end: Date) -> String {
        "\(start.formatted(.dateTime.day().month(.abbreviated).year())) - \(end.formatted(.dateTime.day().month(.abbreviated).year()))"
    }

    static func permissionDateRange(start: Date, end: Date) -> String {
        let startString = start.formatted(.dateTime.day().month(.wide).year().hour().minute())
        let endString = end.formatted(.dateTime.day().month(.wide).year().hour().minute())
        return "\(startString) – \(endString)"
    }

    static func relativeDeadline(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    static func optionalDateRange(start: Date?, end: Date?) -> String {
        guard let start, let end else { return "Schedule unknown" }
        return compactDateRange(start: start, end: end)
    }

    static func reportMailDateRange(start: Date?, end: Date?) -> String {
        guard let start, let end else { return "Schedule to be updated" }

        let calendar = Calendar.current
        let sameMonth = calendar.component(.month, from: start) == calendar.component(.month, from: end)
        let sameYear = calendar.component(.year, from: start) == calendar.component(.year, from: end)

        if sameMonth && sameYear {
            let monthYear = start.formatted(.dateTime.month(.wide).year())
            return "\(ordinalDay(start)) to \(ordinalDay(end)) \(monthYear)"
        }

        let startString = start.formatted(.dateTime.day().month(.wide).year())
        let endString = end.formatted(.dateTime.day().month(.wide).year())
        return "\(startString) to \(endString)"
    }

    private static func ordinalDay(_ date: Date) -> String {
        let day = Calendar.current.component(.day, from: date)
        let suffix: String

        switch day % 100 {
        case 11, 12, 13:
            suffix = "th"
        default:
            switch day % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }

        return "\(day)\(suffix)"
    }
}
