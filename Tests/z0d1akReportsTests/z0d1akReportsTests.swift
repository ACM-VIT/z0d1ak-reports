import Foundation
import Testing
@testable import z0d1akReportsCore

@Test func reportDeadlineTracksThreeDaySubmissionWindow() async throws {
    let endDate = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 4, hour: 23, minute: 0)))
    let expected = try #require(Calendar.current.date(byAdding: .day, value: 3, to: endDate))
    let event = CTFEvent(
        id: "manual-kashictf",
        origin: .manual,
        title: "KashiCTF 2026",
        organizer: "IIT BHU Cybersec",
        website: "https://kashictf.iitbhucybersec.in",
        format: "Jeopardy-style CTF",
        restrictions: "",
        location: "Online",
        description: "Test event",
        startDate: Calendar.current.date(byAdding: .day, value: -2, to: endDate),
        endDate: endDate,
        participatingTeams: 431,
        weight: nil,
        onsite: false,
        discordURL: "",
        liveFeedURL: "",
        ctftimeURL: "https://ctftime.org/event/3133",
        ctftimeEventID: 3133,
        repoPath: nil,
        usesCTFd: true,
        domains: ["Web", "Cryptography", "Forensics"],
        teamMembers: [],
        teamResult: nil,
        permissionState: .sent,
        reportState: .drafting,
        attachments: CTFEvent.defaultAttachments(),
        notes: "",
        lastSyncedAt: nil
    )

    #expect(event.reportDeadline == expected)
}

@Test func teamPageParserFindsUpcomingAndHistoricalRows() async throws {
    let html = #"""
    <table>
      <tr><td><a href="/event/3225">Incognito 7.0</a></td><td>14 Apr. 2026, 00:00 UTC — 15 Apr. 2026, 00:00 UTC</td></tr>
      <tr><td class="place_ico"></td><td class="place">5</td><td><a href="/event/3133">KashiCTF 2026</a></td><td>72.1284</td><td>11.402</td></tr>
    </table>
    """#

    let participations = CTFTimeService.parseParticipations(html: html)
    let upcoming = participations.first(where: { $0.eventID == 3225 })
    let historical = participations.first(where: { $0.eventID == 3133 })

    #expect(participations.count == 2)
    #expect(upcoming?.upcomingLabel != nil)
    #expect(historical?.place == 5)
}

@Test func permissionDraftIncludesEditableEventFields() async throws {
    let startDate = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 14, hour: 5, minute: 30))
    let endDate = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 15, hour: 5, minute: 30))
    let event = CTFEvent(
        id: "ctftime-3225",
        origin: .ctftime,
        title: "INCOGNITO 7.0",
        organizer: "InfoSec Wing, Axios IIIT Lucknow",
        website: "https://incognito.axiosiiitl.dev",
        format: "Jeopardy-style CTF",
        restrictions: "Maximum 5 members",
        location: "Online",
        description: "A 24-hour CTF.",
        startDate: startDate,
        endDate: endDate,
        participatingTeams: nil,
        weight: nil,
        onsite: false,
        discordURL: "",
        liveFeedURL: "",
        ctftimeURL: "https://ctftime.org/event/3225",
        ctftimeEventID: 3225,
        repoPath: nil,
        usesCTFd: nil,
        domains: ["Web", "Cryptography", "OSINT"],
        teamMembers: [
            TeamMember(name: "Ishaan Samdani", registrationNumber: "23BME0453"),
            TeamMember(name: "Aditya Vardhan Kochar", registrationNumber: "24BCE3000"),
        ],
        teamResult: nil,
        permissionState: .draft,
        reportState: .notStarted,
        attachments: CTFEvent.defaultAttachments(),
        notes: "",
        lastSyncedAt: nil
    )

    let draft = DraftComposer.content(for: .permissionRequest, event: event)

    #expect(draft.contains("INCOGNITO 7.0"))
    #expect(draft.contains("Ishaan Samdani [23BME0453]"))
    #expect(draft.contains("Event Link: https://incognito.axiosiiitl.dev"))
}

@Test func teamHistoryResultWithoutDatesFallsIntoHistoryBucket() async throws {
    let event = CTFEvent(
        id: "ctftime-3133",
        origin: .teamHistory,
        title: "KashiCTF 2026",
        organizer: "",
        website: "",
        format: "",
        restrictions: "",
        location: "",
        description: "",
        startDate: nil,
        endDate: nil,
        participatingTeams: nil,
        weight: nil,
        onsite: nil,
        discordURL: "",
        liveFeedURL: "",
        ctftimeURL: "https://ctftime.org/event/3133",
        ctftimeEventID: 3133,
        repoPath: nil,
        usesCTFd: nil,
        domains: [],
        teamMembers: [],
        teamResult: TeamResult(place: 5, ctfPoints: 72.1284, ratingPoints: 11.402),
        permissionState: .unknown,
        reportState: .unknown,
        attachments: CTFEvent.defaultAttachments(),
        notes: "",
        lastSyncedAt: nil
    )

    #expect(event.eventBucket == .history)
}

@Test func reportMailIncludesEventReportBody() async throws {
    let startDate = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 10, hour: 9, minute: 0))
    let endDate = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 12, hour: 18, minute: 0))
    let event = CTFEvent(
        id: "manual-kaalchakra",
        origin: .manual,
        title: "KAALCHAKRA26 CTF Finals",
        organizer: "National Forensic Sciences University (NFSU), Goa",
        website: "",
        format: "Jeopardy-style CTF",
        restrictions: "",
        location: "Goa",
        description: "KAALCHAKRA 26 CTF Finals was an offline national-level cybersecurity event organized by NFSU Goa.",
        startDate: startDate,
        endDate: endDate,
        participatingTeams: 25,
        weight: nil,
        onsite: true,
        discordURL: "",
        liveFeedURL: "",
        ctftimeURL: "",
        ctftimeEventID: nil,
        repoPath: nil,
        usesCTFd: nil,
        domains: [],
        teamMembers: [
            TeamMember(name: "Ishaan Samdani", registrationNumber: "23BME0453"),
            TeamMember(name: "Divyam Agarwal", registrationNumber: "24BIT0423"),
        ],
        teamResult: TeamResult(place: 4, ctfPoints: nil, ratingPoints: nil),
        permissionState: .approved,
        reportState: .drafting,
        attachments: CTFEvent.defaultAttachments(),
        notes: "",
        lastSyncedAt: nil
    )

    let draft = DraftComposer.content(for: .reportMail, event: event)

    #expect(draft.contains("Chapter Name: Association for Computing Machinery"))
    #expect(draft.contains("Team Name: z0d1ak"))
    #expect(draft.contains("Event Name: KAALCHAKRA26 CTF Finals"))
    #expect(draft.contains("Position secured: 4 Place"))
    #expect(draft.contains("Certificates:"))
    #expect(draft.contains("Scoreboard:"))
    #expect(draft.contains("Ishaan Samdani (23BME0453)"))
}

@Test func importedDescriptionReplacesTeamHistoryPlaceholder() async throws {
    var existing = CTFEvent(
        id: "ctftime-3225",
        origin: .teamHistory,
        title: "Incognito 7.0",
        organizer: "",
        website: "",
        format: "",
        restrictions: "",
        location: "",
        description: "Discovered from the team page: April 14, 2026, midnight.",
        startDate: nil,
        endDate: nil,
        participatingTeams: nil,
        weight: nil,
        onsite: nil,
        discordURL: "",
        liveFeedURL: "",
        ctftimeURL: "https://ctftime.org/event/3225/",
        ctftimeEventID: 3225,
        repoPath: nil,
        usesCTFd: nil,
        domains: [],
        teamMembers: [],
        teamResult: nil,
        permissionState: .unknown,
        reportState: .unknown,
        attachments: CTFEvent.defaultAttachments(),
        notes: "",
        lastSyncedAt: nil
    )

    let imported = CTFEvent(
        id: "ctftime-3225",
        origin: .ctftime,
        title: "Incognito 7.0",
        organizer: "Byt3Scr4pp3rs",
        website: "https://incognito.axiosiiitl.dev/",
        format: "Jeopardy",
        restrictions: "Open",
        location: "",
        description: "Step into the world of cybersecurity with INCOGNITO 7.0.",
        startDate: Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 14)),
        endDate: Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 15)),
        participatingTeams: 95,
        weight: 16.56,
        onsite: false,
        discordURL: "https://discord.gg/KPW7QWRRes",
        liveFeedURL: "https://ctftime.org/live/3225/",
        ctftimeURL: "https://ctftime.org/event/3225/",
        ctftimeEventID: 3225,
        repoPath: nil,
        usesCTFd: nil,
        domains: ["Web", "Crypto", "Forensics", "Reverse Engineering", "Pwn", "OSINT"],
        teamMembers: [],
        teamResult: nil,
        permissionState: .unknown,
        reportState: .unknown,
        attachments: CTFEvent.defaultAttachments(),
        notes: "",
        lastSyncedAt: nil
    )

    existing.mergeImportedMetadata(from: imported)

    #expect(existing.description == "Step into the world of cybersecurity with INCOGNITO 7.0.")
    #expect(existing.organizer == "Byt3Scr4pp3rs")
    #expect(existing.participatingTeams == 95)
}
