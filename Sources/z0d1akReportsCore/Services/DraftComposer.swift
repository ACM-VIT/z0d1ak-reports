import Foundation

enum DraftComposer {
    private enum ReportMailStyle {
        case achievement
        case participation
    }

    static func subject(for kind: DraftKind, event: CTFEvent) -> String {
        switch kind {
        case .permissionRequest:
            return "Permission to Participate in \(permissionEventTitle(for: event))"
        case .reportMail:
            switch reportMailStyle(for: event) {
            case .achievement:
                let position = event.teamResult?.place.map { "\(DateFormatting.ordinal($0)) position" } ?? "result update"
                return "Achievement - ACM (z0d1ak) - \(position)"
            case .participation:
                return "Event Report- \(event.title)- ACM/z0d1ak- \(DateFormatting.subjectDateRange(start: event.startDate ?? .now, end: event.endDate ?? .now))"
            }
        case .reportDocument:
            return "\(event.title) Event Report"
        }
    }

    static func content(for kind: DraftKind, event: CTFEvent) -> String {
        switch kind {
        case .permissionRequest:
            permissionMail(for: event)
        case .reportMail:
            reportMail(for: event)
        case .reportDocument:
            reportDocument(for: event)
        }
    }

    static func fullDraft(for kind: DraftKind, event: CTFEvent) -> String {
        """
        Subject: \(subject(for: kind, event: event))

        \(content(for: kind, event: event))
        """
    }

    static func suggestedFilename(for kind: DraftKind, event: CTFEvent, preferMarkdown: Bool) -> String {
        let slug = event.title
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        let suffix: String

        switch kind {
        case .permissionRequest:
            suffix = "permission-mail"
        case .reportMail:
            suffix = "report-mail"
        case .reportDocument:
            suffix = "event-report"
        }

        let ext = preferMarkdown ? "md" : "txt"
        return "\(slug)-\(suffix).\(ext)"
    }

    private static func permissionMail(for event: CTFEvent) -> String {
        let teamLines = bulletedMailTeamLines(for: event)
        let details = permissionDetailLines(for: event).joined(separator: "\n")

        return """
        Dear Sir,

        We would like to seek your permission to participate in \(permissionEventTitle(for: event)), \(permissionCompetitionSummary(for: event)).

        Event Details:

        \(details)

        Team Members:

        \(teamLines)

        We believe this competition will help us further develop our practical cybersecurity skills and gain exposure to real-world problem-solving scenarios.

        Event Link: \(event.website.isEmpty ? (event.ctftimeURL.isEmpty ? "https://ctftime.org" : event.ctftimeURL) : event.website)

        We kindly request your approval to participate in this event.

        Thank you for your time and support.

        Sincerely,
        Ishaan Samdani
        On behalf of Team z0d1ak
        ACM-VIT
        """
    }

    private static func reportMail(for event: CTFEvent) -> String {
        switch reportMailStyle(for: event) {
        case .achievement:
            achievementReportMail(for: event)
        case .participation:
            participationReportMail(for: event)
        }
    }

    private static func reportDocument(for event: CTFEvent) -> String {
        let noteSections = parseNoteSections(from: event.notes)
        let prizesWon = noteSection(["prizes won", "prizes"], in: noteSections)
        let certificates = certificatesSummary(for: event, noteSections: noteSections)
        let scoreboard = scoreboardSummary(for: event, noteSections: noteSections)
        let totalPlayersLine = optionalReportPlayersLine(for: event)

        return """
        \(event.title) Event Report

        Chapter Name: Association for Computing Machinery
        Team Name: z0d1ak
        Event Name: \(event.title)
        Date: \(DateFormatting.reportMailDateRange(start: event.startDate, end: event.endDate))
        Organizer: \(valueOrFallback(event.organizer, fallback: "To be updated"))

        Event Description:

        \(valueOrFallback(event.description, fallback: "Event description to be added."))

        Format: \(permissionFormatLine(for: event))
        Mode: \(eventMode(for: event))
        Total Teams: \(event.participatingTeams.map(String.init) ?? "To be updated")
        \(totalPlayersLine)
        Position secured: \(reportPositionLine(for: event))

        Team Members:
        \(plainMailTeamLines(for: event))

        \(prizesWon.map { "Prizes won:\n\n\($0)\n" } ?? "")
        Certificates:

        \(certificates)

        Scoreboard:

        \(scoreboard)

        Supporting Documentation:
        \(reportAttachmentLines(for: event))
        """
    }

    private static func permissionEventTitle(for event: CTFEvent) -> String {
        event.title.localizedCaseInsensitiveContains("CTF") ? event.title : "\(event.title) CTF"
    }

    private static func reportAttachmentLines(for event: CTFEvent) -> String {
        [
            "1. Event report (\(event.title) and description, number of external teams participated, performance details, position secured if any, geotagged photos, certificate, and prize documentation if any)",
            "2. Certificates (Participation/Achievement if any)",
        ].joined(separator: "\n")
    }

    private static func reportPositionLine(for event: CTFEvent) -> String {
        if let place = event.teamResult?.place {
            return DateFormatting.ordinal(place)
        }

        return "Participation"
    }

    private static func plainMailTeamLines(for event: CTFEvent) -> String {
        let members = event.teamMembers.isEmpty
            ? [TeamMember(name: "Add team members", registrationNumber: "")]
            : event.teamMembers

        return members.map(mailDisplayLine(for:)).joined(separator: "\n")
    }

    private static func bulletedMailTeamLines(for event: CTFEvent) -> String {
        let members = event.teamMembers.isEmpty
            ? [TeamMember(name: "Add team members", registrationNumber: "")]
            : event.teamMembers

        return members.map { "- \(mailDisplayLine(for: $0))" }.joined(separator: "\n")
    }

    private static func mailDisplayLine(for member: TeamMember) -> String {
        member.registrationNumber.isEmpty ? member.name : "\(member.name) [\(member.registrationNumber)]"
    }

    private static func reportMailStyle(for event: CTFEvent) -> ReportMailStyle {
        event.teamResult?.place != nil ? .achievement : .participation
    }

    private static func permissionCompetitionSummary(for event: CTFEvent) -> String {
        if let start = event.startDate, let end = event.endDate {
            let hours = Int(end.timeIntervalSince(start) / 3600)
            if hours > 0 {
                return "a \(hours)-hour Capture The Flag (CTF) cybersecurity competition"
            }
        }

        return "a Capture The Flag (CTF) cybersecurity competition"
    }

    private static func permissionDetailLines(for event: CTFEvent) -> [String] {
        var lines = [
            "Name: \(event.title)",
            "Date & Time: \(event.startDate.flatMap { start in event.endDate.map { DateFormatting.permissionDateRange(start: start, end: $0) } } ?? "To be updated")",
            "Mode: \(eventMode(for: event))",
            "Organizers: \(valueOrFallback(event.organizer, fallback: "To be updated"))",
            "Format: \(permissionFormatLine(for: event))",
            "Domains Covered: \(event.domains.isEmpty ? "To be updated" : event.domains.joined(separator: ", "))",
        ]

        if let registrationFee = permissionRegistrationFee(for: event) {
            lines.append("Registration Fee: \(registrationFee)")
        }

        lines.append("Team Size: \(permissionTeamSizeLine(for: event))")

        if let prizes = permissionPrizeSummary(for: event) {
            lines.append("Prizes: \(prizes)")
        }

        return lines
    }

    private static func permissionFormatLine(for event: CTFEvent) -> String {
        let trimmed = event.format.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "CTF" }

        if trimmed.localizedCaseInsensitiveContains("jeopardy") {
            return "Jeopardy-style CTF"
        }

        if trimmed.localizedCaseInsensitiveContains("attack") || trimmed.localizedCaseInsensitiveContains("defense") {
            return trimmed.localizedCaseInsensitiveContains("ctf") ? trimmed : "\(trimmed) CTF"
        }

        return trimmed.localizedCaseInsensitiveContains("ctf") ? trimmed : "\(trimmed) CTF"
    }

    private static func eventMode(for event: CTFEvent) -> String {
        event.onsite == true ? "Offline" : "Online"
    }

    private static func permissionRegistrationFee(for event: CTFEvent) -> String? {
        firstNonEmpty(
            event.registrationFee,
            noteSection(["registration fee"], in: parseNoteSections(from: event.notes))
        )
    }

    private static func permissionPrizeSummary(for event: CTFEvent) -> String? {
        firstNonEmpty(
            event.prizeSummary,
            noteSection(["prizes"], in: parseNoteSections(from: event.notes))
        )
    }

    private static func permissionTeamSizeLine(for event: CTFEvent) -> String {
        if let teamSizeLimit = event.teamSizeLimit {
            return "Maximum \(teamSizeLimit) members"
        }

        if let extracted = extractTeamSizeLimit(from: [event.restrictions, event.description].joined(separator: "\n")) {
            return "Maximum \(extracted) members"
        }

        let trimmedRestrictions = event.restrictions.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedRestrictions.isEmpty, !trimmedRestrictions.localizedCaseInsensitiveContains("open") {
            return trimmedRestrictions
        }

        return "To be updated"
    }

    private static func participationReportMail(for event: CTFEvent) -> String {
        let reportDate = DateFormatting.reportMailDateRange(start: event.startDate, end: event.endDate)

        return """
        Dear Professor,

        PFA report of our participation in \(event.title)-\(reportDate)
        Positions secured: \(reportPositionLine(for: event))

        Attachments:
        \(reportAttachmentLines(for: event))

        Kindly find the above mentioned details attached within the required reporting window.

        Regards,
        Ishaan Samdani
        On behalf of Team z0d1ak
        ACM-VIT
        """
    }

    private static func achievementReportMail(for event: CTFEvent) -> String {
        let noteSections = parseNoteSections(from: event.notes)
        let intro = achievementIntro(for: event, noteSections: noteSections)
        let teamLines = plainMailTeamLines(for: event)
        let totalTeams = event.participatingTeams.map(String.init) ?? "To be updated"
        let totalPlayers = optionalReportPlayersLine(for: event)
        let prizesWon = noteSection(["prizes won", "prizes"], in: noteSections)
        let certificates = certificatesSummary(for: event, noteSections: noteSections)
        let scoreboard = scoreboardSummary(for: event, noteSections: noteSections)

        return """
        Dear Professor,

        \(intro)

        Chapter Name: Association for Computing Machinery
        Team Name: z0d1ak
        Event Name: \(event.title)
        Date: \(DateFormatting.reportMailDateRange(start: event.startDate, end: event.endDate))
        Organizer: \(valueOrFallback(event.organizer, fallback: "To be updated"))

        Event Description:

        \(valueOrFallback(event.description, fallback: "Event description to be added."))

        Position secured: \(reportPositionLine(for: event))
        Total Teams: \(totalTeams)
        \(totalPlayers)
        Team Members:

        \(teamLines)

        \(prizesWon.map { prizes in "Prizes won:\n\n\(prizes)\n" } ?? "")
        Certificates:

        \(certificates)

        Scoreboard:

        \(scoreboard)

        Regards,
        Ishaan Samdani
        On behalf of Team z0d1ak
        ACM-VIT
        """
    }

    private static func achievementIntro(for event: CTFEvent, noteSections: [String: String]) -> String {
        if let custom = noteSection(["mail intro", "intro"], in: noteSections) {
            return custom
        }

        if let place = event.teamResult?.place {
            return "Here is the event report for \(event.title). Team z0d1ak secured \(DateFormatting.ordinal(place)) position in the event."
        }

        return "Here is the event report for \(event.title)."
    }

    private static func optionalReportPlayersLine(for event: CTFEvent) -> String {
        guard let totalPlayers = event.totalPlayers else { return "" }
        return "Total Players: \(totalPlayers)"
    }

    private static func certificatesSummary(for event: CTFEvent, noteSections: [String: String]) -> String {
        if let explicit = noteSection(["certificates"], in: noteSections) {
            return explicit
        }

        switch event.attachment(for: .certificateBundle).status {
        case .ready:
            return "Attached"
        case .pending:
            return "Not yet released"
        default:
            return "Attached in document"
        }
    }

    private static func scoreboardSummary(for event: CTFEvent, noteSections: [String: String]) -> String {
        if let explicit = noteSection(["scoreboard"], in: noteSections) {
            return explicit
        }

        return firstNonEmpty(event.ctftimeURL, event.website) ?? "Attached in document"
    }

    private static func parseNoteSections(from notes: String) -> [String: String] {
        let aliases = [
            "mail intro": "mail intro",
            "intro": "mail intro",
            "registration fee": "registration fee",
            "prizes won": "prizes won",
            "prizes": "prizes",
            "certificates": "certificates",
            "scoreboard": "scoreboard",
        ]

        var sections: [String: [String]] = [:]
        var currentSection: String?

        for rawLine in notes.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            if let colon = trimmed.firstIndex(of: ":") {
                let heading = trimmed[..<colon].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if let canonical = aliases[heading] {
                    currentSection = canonical
                    let remainder = trimmed[trimmed.index(after: colon)...].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !remainder.isEmpty {
                        sections[canonical, default: []].append(remainder)
                    }
                    continue
                }
            }

            guard let currentSection else { continue }
            sections[currentSection, default: []].append(rawLine)
        }

        return sections.mapValues {
            $0.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func noteSection(_ keys: [String], in sections: [String: String]) -> String? {
        for key in keys {
            if let value = sections[key], !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private static func extractTeamSizeLimit(from text: String) -> Int? {
        let patterns = [
            #"team size[^0-9]{0,20}(\d+)"#,
            #"maximum[^0-9]{0,20}(\d+)\s+(?:members?|players?|people)"#,
            #"max(?:imum)?[^0-9]{0,20}(\d+)\s+(?:members?|players?|people)"#,
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }

            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = regex.firstMatch(in: text, options: [], range: nsRange),
                  match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: text),
                  let value = Int(text[range]) else {
                continue
            }

            return value
        }

        return nil
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }

    private static func valueOrFallback(_ value: String, fallback: String = "N/A") -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}
