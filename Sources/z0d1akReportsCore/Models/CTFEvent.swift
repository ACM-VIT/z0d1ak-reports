import Foundation
import SwiftUI

struct TeamMember: Codable, Identifiable, Hashable, Sendable {
    var name: String
    var registrationNumber: String

    var id: String { [name, registrationNumber].filter { !$0.isEmpty }.joined(separator: "-") }
    var displayLine: String {
        registrationNumber.isEmpty ? name : "\(name) (\(registrationNumber))"
    }
}

struct TeamResult: Codable, Hashable, Sendable {
    var place: Int?
    var ctfPoints: Double?
    var ratingPoints: Double?
}

enum EventOrigin: String, Codable, CaseIterable, Hashable, Sendable {
    case manual
    case ctftime
    case writeupsRepo
    case teamHistory

    var title: String {
        switch self {
        case .manual: "Manual"
        case .ctftime: "CTFTime"
        case .writeupsRepo: "Writeups Repo"
        case .teamHistory: "Team History"
        }
    }
}

enum PermissionState: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case unknown
    case draft
    case sent
    case approved

    var id: Self { self }

    var title: String {
        switch self {
        case .unknown: "Unknown"
        case .draft: "Draft"
        case .sent: "Sent"
        case .approved: "Approved"
        }
    }

    var systemImage: String {
        switch self {
        case .unknown: "questionmark.circle"
        case .draft: "square.and.pencil"
        case .sent: "paperplane"
        case .approved: "checkmark.seal"
        }
    }

    var tint: Color {
        switch self {
        case .unknown: .secondary
        case .draft: .orange
        case .sent: .blue
        case .approved: .green
        }
    }
}

enum ReportState: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case unknown
    case notStarted
    case drafting
    case ready
    case submitted

    var id: Self { self }

    var title: String {
        switch self {
        case .unknown: "Unknown"
        case .notStarted: "Not Started"
        case .drafting: "Drafting"
        case .ready: "Ready"
        case .submitted: "Submitted"
        }
    }

    var systemImage: String {
        switch self {
        case .unknown: "questionmark.circle"
        case .notStarted: "clock.arrow.circlepath"
        case .drafting: "doc.text"
        case .ready: "tray.full"
        case .submitted: "checkmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .unknown: .secondary
        case .notStarted: .secondary
        case .drafting: .indigo
        case .ready: .mint
        case .submitted: .green
        }
    }
}

enum AttachmentStatus: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case unknown
    case missing
    case pending
    case ready

    var id: Self { self }

    var title: String {
        switch self {
        case .unknown: "Unknown"
        case .missing: "Missing"
        case .pending: "Pending"
        case .ready: "Ready"
        }
    }

    var tint: Color {
        switch self {
        case .unknown: .secondary
        case .missing: .orange
        case .pending: .blue
        case .ready: .green
        }
    }
}

enum AttachmentKind: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case reportDocument
    case certificateBundle
    case scoreboardEvidence
    case geotaggedPhotos
    case prizeDocumentation

    var id: Self { self }

    var title: String {
        switch self {
        case .reportDocument: "Event Report"
        case .certificateBundle: "Certificates"
        case .scoreboardEvidence: "Scoreboard"
        case .geotaggedPhotos: "Geotagged Photos"
        case .prizeDocumentation: "Prize Proof"
        }
    }

    var systemImage: String {
        switch self {
        case .reportDocument: "doc.richtext"
        case .certificateBundle: "rosette"
        case .scoreboardEvidence: "list.number"
        case .geotaggedPhotos: "camera.viewfinder"
        case .prizeDocumentation: "gift"
        }
    }

    func detail(for event: CTFEvent) -> String {
        switch self {
        case .reportDocument:
            "Mandatory Word-style report with event summary, standing, supporting proof, and outcome."
        case .certificateBundle:
            "Attach participation or achievement certificates separately once the organizers release them."
        case .scoreboardEvidence:
            "Screenshot or public scoreboard link proving the team's standing."
        case .geotaggedPhotos:
            "Photos of the team working on the event for the welfare office trail."
        case .prizeDocumentation:
            event.teamResult?.place != nil
                ? "Optional proof block for prizes, sponsor perks, or result screenshots."
                : "Only needed when the event yields a prize or sponsored reward."
        }
    }

    func isRelevant(for event: CTFEvent) -> Bool {
        switch self {
        case .prizeDocumentation:
            event.teamResult?.place != nil
        default:
            true
        }
    }
}

struct EventAttachment: Codable, Identifiable, Hashable, Sendable {
    var kind: AttachmentKind
    var status: AttachmentStatus
    var note: String?

    var id: AttachmentKind { kind }
}

enum DraftKind: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case permissionRequest
    case reportMail
    case reportDocument

    var id: Self { self }

    var title: String {
        switch self {
        case .permissionRequest: "Permission Mail"
        case .reportMail: "Report Mail"
        case .reportDocument: "Event Report"
        }
    }
}

enum EventBucket: String, CaseIterable, Identifiable, Hashable, Sendable {
    case current
    case reporting
    case history

    var id: Self { self }
}

struct CTFEvent: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var origin: EventOrigin
    var title: String
    var organizer: String
    var website: String
    var format: String
    var restrictions: String
    var location: String
    var description: String
    var startDate: Date?
    var endDate: Date?
    var participatingTeams: Int?
    var weight: Double?
    var onsite: Bool?
    var discordURL: String
    var liveFeedURL: String
    var ctftimeURL: String
    var ctftimeEventID: Int?
    var repoPath: String?
    var usesCTFd: Bool?
    var domains: [String]
    var registrationFee: String? = nil
    var prizeSummary: String? = nil
    var totalPlayers: Int? = nil
    var teamSizeLimit: Int? = nil
    var teamMembers: [TeamMember]
    var teamResult: TeamResult?
    var permissionState: PermissionState
    var reportState: ReportState
    var attachments: [EventAttachment]
    var notes: String
    var lastSyncedAt: Date?
}

extension CTFEvent {
    static func makeStableID(ctftimeEventID: Int?, repoPath: String?, fallbackTitle: String) -> String {
        if let ctftimeEventID {
            return "ctftime-\(ctftimeEventID)"
        }

        if let repoPath, !repoPath.isEmpty {
            return "repo-\(repoPath)"
        }

        return "manual-\(fallbackTitle.lowercased().replacingOccurrences(of: " ", with: "-"))-\(UUID().uuidString)"
    }

    static func defaultAttachments() -> [EventAttachment] {
        AttachmentKind.allCases.map { EventAttachment(kind: $0, status: .unknown, note: nil) }
    }

    var reportDeadline: Date? {
        guard let endDate else { return nil }
        return Calendar.current.date(byAdding: .day, value: 3, to: endDate)
    }

    var extendedCertificateDeadline: Date? {
        guard let endDate else { return nil }
        return Calendar.current.date(byAdding: .day, value: 15, to: endDate)
    }

    var isLive: Bool {
        guard let startDate, let endDate else { return false }
        let now = Date()
        return startDate <= now && now <= endDate
    }

    var isUpcoming: Bool {
        guard let startDate else { return false }
        return startDate > Date()
    }

    var isPast: Bool {
        guard let endDate else { return false }
        return endDate < Date()
    }

    var eventBucket: EventBucket {
        if teamResult?.place != nil, startDate == nil, endDate == nil {
            return .history
        }
        if isPast && reportState != .submitted {
            return .reporting
        }
        if isPast {
            return .history
        }
        return .current
    }

    var displayLinks: [(title: String, url: String)] {
        [
            ("Website", website),
            ("CTFTime", ctftimeURL),
            ("Discord", discordURL),
            ("Live Feed", liveFeedURL),
        ].filter { !$0.url.isEmpty }
    }

    var resultSummary: String {
        if let place = teamResult?.place {
            return "#\(place)"
        }
        return isUpcoming ? "Upcoming" : "No result yet"
    }

    var timelineLabel: String {
        guard let startDate, let endDate else { return "Schedule unknown" }
        return DateFormatting.compactDateRange(start: startDate, end: endDate)
    }

    var sidebarSubtitle: String {
        let pieces = [
            startDate.map(DateFormatting.shortDate),
            reportDeadline.flatMap { reportState == .submitted ? nil : "Report due \(DateFormatting.shortDate($0))" },
            teamResult?.place.map { "#\($0)" },
        ].compactMap { $0 }

        if !pieces.isEmpty {
            return pieces.joined(separator: " • ")
        }

        if !organizer.isEmpty {
            return organizer
        }

        return origin.title
    }

    func attachment(for kind: AttachmentKind) -> EventAttachment {
        attachments.first(where: { $0.kind == kind }) ?? EventAttachment(kind: kind, status: .unknown)
    }

    mutating func mergeImportedMetadata(from imported: CTFEvent) {
        if title.isEmpty { title = imported.title }
        if organizer.isEmpty { organizer = imported.organizer }
        if website.isEmpty { website = imported.website }
        if format.isEmpty { format = imported.format }
        if restrictions.isEmpty { restrictions = imported.restrictions }
        if location.isEmpty { location = imported.location }
        if shouldReplaceDescription(with: imported.description) {
            description = imported.description
        }
        if startDate == nil { startDate = imported.startDate }
        if endDate == nil { endDate = imported.endDate }
        if participatingTeams == nil { participatingTeams = imported.participatingTeams }
        if weight == nil { weight = imported.weight }
        if onsite == nil { onsite = imported.onsite }
        if discordURL.isEmpty { discordURL = imported.discordURL }
        if liveFeedURL.isEmpty { liveFeedURL = imported.liveFeedURL }
        if ctftimeURL.isEmpty { ctftimeURL = imported.ctftimeURL }
        if ctftimeEventID == nil { ctftimeEventID = imported.ctftimeEventID }
        if repoPath == nil { repoPath = imported.repoPath }
        if usesCTFd == nil { usesCTFd = imported.usesCTFd }
        if domains.isEmpty { domains = imported.domains }
        if (registrationFee ?? "").isEmpty { registrationFee = imported.registrationFee }
        if (prizeSummary ?? "").isEmpty { prizeSummary = imported.prizeSummary }
        if totalPlayers == nil { totalPlayers = imported.totalPlayers }
        if teamSizeLimit == nil { teamSizeLimit = imported.teamSizeLimit }
        if teamMembers.isEmpty { teamMembers = imported.teamMembers }
        if teamResult == nil { teamResult = imported.teamResult }
        lastSyncedAt = imported.lastSyncedAt ?? .now
    }

    mutating func apply(participation: CTFTimeParticipation) {
        if ctftimeEventID == nil {
            ctftimeEventID = participation.eventID
        }
        if ctftimeURL.isEmpty {
            ctftimeURL = "https://ctftime.org/event/\(participation.eventID)"
        }
        if title.isEmpty {
            title = participation.title
        }
        teamResult = TeamResult(
            place: participation.place,
            ctfPoints: participation.ctfPoints,
            ratingPoints: participation.ratingPoints
        )
        if description.isEmpty, let upcomingLabel = participation.upcomingLabel {
            description = "Discovered from the team page: \(upcomingLabel)."
        }
        lastSyncedAt = .now
    }

    private func shouldReplaceDescription(with importedDescription: String) -> Bool {
        let current = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let incoming = importedDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !incoming.isEmpty else { return false }
        guard !current.isEmpty else { return true }

        if current.hasPrefix("Discovered from the team page:") {
            return true
        }

        return false
    }
}
