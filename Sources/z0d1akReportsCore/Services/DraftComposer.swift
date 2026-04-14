import Foundation

enum DraftComposer {
    static func subject(for kind: DraftKind, event: CTFEvent) -> String {
        switch kind {
        case .permissionRequest:
            return "Permission to Participate in \(permissionEventTitle(for: event))"
        case .reportMail:
            return "Event Report- \(event.title)- ACM/z0d1ak- \(DateFormatting.subjectDateRange(start: event.startDate ?? .now, end: event.endDate ?? .now))"
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
        let teamLines = event.teamMembers.isEmpty
            ? "- Add team members"
            : event.teamMembers.map { "- \($0.name) [\($0.registrationNumber)]" }.joined(separator: "\n")

        return """
        Dear Sir,

        We would like to seek your permission to participate in \(permissionEventTitle(for: event)), a \(valueOrFallback(event.format, fallback: "CTF")) cybersecurity competition.

        Event Details:

        Name: \(event.title)
        Date & Time: \(event.startDate.flatMap { start in event.endDate.map { DateFormatting.permissionDateRange(start: start, end: $0) } } ?? "To be updated")
        Mode: \(event.onsite == true ? "On-site" : "Online")
        Organizers: \(valueOrFallback(event.organizer, fallback: "To be updated"))
        Format: \(valueOrFallback(event.format, fallback: "CTF"))
        Domains Covered: \(event.domains.isEmpty ? "To be updated" : event.domains.joined(separator: ", "))
        Team Size: Maximum \(max(event.teamMembers.count, 1)) members

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
        let teamLines = reportTeamLines(for: event)
        let totalTeams = event.participatingTeams.map { "\($0)" } ?? "To be updated"
        let positionLine = reportPositionLine(for: event)
        let attachmentIntro = event.teamResult?.place != nil
            ? "Here is the event report for the event. We have also attached the certificates and the day to day report with geotagged photos."
            : "Here is the event report for the event. We have also attached the participation certificates and the day to day report with geotagged photos."

        return """
        Dear Professor,

        \(attachmentIntro)

        Chapter Name: Association for Computing Machinery
        Team Name: z0d1ak
        Event Name: \(event.title)
        Date: \(DateFormatting.reportMailDateRange(start: event.startDate, end: event.endDate))
        Organizer: \(valueOrFallback(event.organizer, fallback: "To be updated"))

        Event Description:

        \(valueOrFallback(event.description, fallback: "Event description to be added."))

        Position secured: \(positionLine)
        Total Teams: \(totalTeams)
        Team Members:
        \(teamLines)

        Certificates:

        Attached in document

        Scoreboard:

        Attached in document

        Regards,
        Ishaan Samdani
        On behalf of Team z0d1ak
        ACM-VIT
        """
    }

    private static func reportDocument(for event: CTFEvent) -> String {
        let achievementSection: String
        if let place = event.teamResult?.place {
            achievementSection = """
            Achievement
            Team z0d1ak secured a distinguished position in the overall standings.

            Position Secured: \(place) Place
            """
        } else {
            achievementSection = """
            Achievement
            Team z0d1ak successfully represented the chapter and completed the event as a participating team.
            """
        }

        let teamLines = (event.teamMembers.isEmpty ? [TeamMember(name: "Add team members", registrationNumber: "")] : event.teamMembers)
            .map { "- \($0.displayLine)" }
            .joined(separator: "\n")

        let supportingItems = event.attachments
            .filter { $0.kind.isRelevant(for: event) }
            .map { attachment in
                let note = attachment.note ?? attachment.kind.detail(for: event)
                return "- \(attachment.kind.title): \(attachment.status.title) — \(note)"
            }
            .joined(separator: "\n")

        return """
        \(event.title) Event Report

        Event Overview
        \(valueOrFallback(event.description, fallback: "Event description to be added."))

        Chapter Name: Association for Computing Machinery (ACM)
        Event Name: \(event.title)
        Date: \(DateFormatting.optionalDateRange(start: event.startDate, end: event.endDate))
        Organizer: \(valueOrFallback(event.organizer))
        Total Participating Teams: \(event.participatingTeams.map(String.init) ?? "To be confirmed")
        Official Link: \(event.displayLinks.map { "\($0.title) (\($0.url))" }.joined(separator: ", "))

        \(achievementSection)

        Team Composition
        \(teamLines)

        Supporting Documentation
        \(supportingItems)

        Notes
        \(valueOrFallback(event.notes, fallback: "No additional notes."))
        """
    }

    private static func permissionEventTitle(for event: CTFEvent) -> String {
        event.title.localizedCaseInsensitiveContains("CTF") ? event.title : "\(event.title) CTF"
    }

    private static func reportAttachmentLines(for event: CTFEvent) -> String {
        let base = [
            "1. Event report (\(event.title) Event Report)",
            "2. Certificates (Participation/Achievement if issued)",
            "3. Scoreboard evidence",
            "4. Geotagged photos",
        ]

        let prizeLine = event.teamResult?.place != nil ? "5. Prize documentation" : nil
        return (base + [prizeLine].compactMap { $0 }).joined(separator: "\n")
    }

    private static func reportPositionLine(for event: CTFEvent) -> String {
        if let place = event.teamResult?.place {
            return "\(place) Place"
        }

        return "Participation"
    }

    private static func reportTeamLines(for event: CTFEvent) -> String {
        let members = event.teamMembers.isEmpty
            ? [TeamMember(name: "Add team members", registrationNumber: "")]
            : event.teamMembers

        return members.map(\.displayLine).joined(separator: "\n")
    }

    private static func valueOrFallback(_ value: String, fallback: String = "N/A") -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}
