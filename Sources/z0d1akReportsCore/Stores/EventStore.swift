import Observation
import SwiftUI

struct SidebarSection: Identifiable {
    let bucket: EventBucket
    let title: String
    let events: [CTFEvent]

    var id: EventBucket { bucket }
}

enum DetailTab: String, CaseIterable, Identifiable {
    case overview
    case drafts

    var id: Self { self }
}

@MainActor
@Observable
public final class EventStore {
    static let dashboardSelectionID = "com.z0d1ak.dashboard"

    var events: [CTFEvent] = []
    var selectedEventID: String? = EventStore.dashboardSelectionID
    var searchText = ""
    var selectedDraftKind: DraftKind = .permissionRequest
    var selectedDetailTab: DetailTab = .overview
    var isLoading = false
    var hasLoaded = false
    var errorMessage: String?
    var showingAddSheet = false

    var teamInfo: CTFTimeTeamInfo?
    var upcomingEvents: [CTFTimeUpcomingEvent] = []
    var isLoadingDashboard = false
    var hasLoadedDashboard = false

    public init() {}

    public var canCopyCurrentDraft: Bool {
        selectedEvent != nil
    }

    public func presentAddEventSheet() {
        showingAddSheet = true
    }

    public func showDashboard() {
        selectedEventID = Self.dashboardSelectionID
    }

    public func copyCurrentDraft() {
        guard let event = selectedEvent else { return }
        ClipboardService.copy(
            DraftComposer.fullDraft(for: selectedDraftKind, event: event)
        )
    }

    var isShowingDashboard: Bool {
        selectedEventID == Self.dashboardSelectionID
    }

    var selectedEvent: CTFEvent? {
        guard let id = selectedEventID, id != Self.dashboardSelectionID else { return nil }
        return events.first(where: { $0.id == id })
    }

    var recentResults: [CTFEvent] {
        events
            .filter { $0.teamResult?.place != nil }
            .sorted(by: { ($0.endDate ?? .distantPast) > ($1.endDate ?? .distantPast) })
    }

    func loadIfNeeded(repoRootPath: String, teamPageURL: String) async {
        guard !hasLoaded else { return }
        await refresh(repoRootPath: repoRootPath, teamPageURL: teamPageURL)
        hasLoaded = true
    }

    func refresh(repoRootPath: String, teamPageURL: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let storedEvents = try EventPersistenceService.loadEvents()
            let repoEvents = (try? WriteupsRepositoryService.scanEvents(repoRootPath: repoRootPath)) ?? []
            let teamParticipations = (try? await CTFTimeService.fetchTeamParticipations(teamURL: teamPageURL)) ?? []

            var merged: [String: CTFEvent] = [:]

            for event in storedEvents {
                merge(event, into: &merged)
            }

            for repoEvent in repoEvents {
                merge(repoEvent, into: &merged)
            }

            for participation in teamParticipations {
                merge(CTFTimeService.stubEvent(from: participation), into: &merged)
            }

            let pendingEventIDs: [Int] = merged.values.compactMap { event -> Int? in
                guard Self.shouldEnrichFromCTFTime(event), let eventID = event.ctftimeEventID else {
                    return nil
                }
                return eventID
            }

            let enrichedEvents = await CTFTimeService.fetchEvents(eventIDs: pendingEventIDs)
            for enrichedEvent in enrichedEvents {
                merge(enrichedEvent, into: &merged)
            }

            events = merged.values.sorted(by: Self.sortEvents)
            if let id = selectedEventID,
               id != Self.dashboardSelectionID,
               !events.contains(where: { $0.id == id }) {
                selectedEventID = Self.dashboardSelectionID
            }

            try EventPersistenceService.saveEvents(events)
            await hydrateSelectedEventIfNeeded()
            await refreshDashboard(teamPageURL: teamPageURL, silent: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadDashboardIfNeeded(teamPageURL: String) async {
        guard !hasLoadedDashboard else { return }
        await refreshDashboard(teamPageURL: teamPageURL, silent: false)
        hasLoadedDashboard = true
    }

    func refreshDashboard(teamPageURL: String, silent: Bool = false) async {
        guard let teamID = CTFTimeService.parseTeamID(from: teamPageURL) else { return }

        if !silent { isLoadingDashboard = true }
        defer { if !silent { isLoadingDashboard = false } }

        async let team = try? CTFTimeService.fetchTeamInfo(teamID: teamID)
        async let upcoming = try? CTFTimeService.fetchUpcomingEvents()

        if let team = await team { self.teamInfo = team }
        if let upcoming = await upcoming { self.upcomingEvents = upcoming }
    }

    func hydrateSelectedEventIfNeeded() async {
        guard let selectedEvent else { return }
        await hydrateEventIfNeeded(eventID: selectedEvent.id)
    }

    func hydrateEventIfNeeded(eventID: String) async {
        guard let event = event(for: eventID), let ctftimeEventID = event.ctftimeEventID else { return }
        let shouldHydrate = event.website.isEmpty || event.startDate == nil || event.endDate == nil || event.description.isEmpty || event.organizer.isEmpty
        guard shouldHydrate else { return }

        do {
            let imported = try await CTFTimeService.fetchEvent(eventID: ctftimeEventID)
            updateEvent(eventID) { existing in
                existing.mergeImportedMetadata(from: imported)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importFromCTFTime(urlString: String) async {
        do {
            let imported = try await CTFTimeService.fetchEvent(urlString: urlString)
            selectedEventID = upsert(imported)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addManualEvent(
        title: String,
        organizer: String,
        website: String,
        format: String,
        startDate: Date?,
        endDate: Date?,
        description: String
    ) {
        let event = CTFEvent(
            id: "manual-\(UUID().uuidString)",
            origin: .manual,
            title: title,
            organizer: organizer,
            website: website,
            format: format,
            restrictions: "",
            location: "",
            description: description,
            startDate: startDate,
            endDate: endDate,
            participatingTeams: nil,
            weight: nil,
            onsite: false,
            discordURL: "",
            liveFeedURL: "",
            ctftimeURL: "",
            ctftimeEventID: nil,
            repoPath: nil,
            usesCTFd: nil,
            domains: [],
            teamMembers: [],
            teamResult: nil,
            permissionState: .draft,
            reportState: .notStarted,
            attachments: CTFEvent.defaultAttachments(),
            notes: "",
            lastSyncedAt: .now
        )

        selectedEventID = upsert(event)
    }

    func sidebarSections(showHistory: Bool) -> [SidebarSection] {
        let filtered = events
            .filter(matchesSearch)
            .filter { event in
                showHistory || event.eventBucket != .history || event.id == selectedEventID
            }
            .sorted(by: Self.sortEvents)

        let buckets: [(EventBucket, String)] = [
            (.current, "Current"),
            (.reporting, "Needs Report"),
            (.history, "History"),
        ]

        return buckets.compactMap { bucket, title in
            let rows = filtered.filter { $0.eventBucket == bucket }
            guard !rows.isEmpty else { return nil }
            return SidebarSection(bucket: bucket, title: title, events: rows)
        }
    }

    func binding<Value>(for eventID: String, _ keyPath: WritableKeyPath<CTFEvent, Value>) -> Binding<Value> {
        Binding(
            get: {
                self.requiredEvent(for: eventID)[keyPath: keyPath]
            },
            set: { newValue in
                self.updateEvent(eventID) { $0[keyPath: keyPath] = newValue }
            }
        )
    }

    func optionalStringBinding(for eventID: String, _ keyPath: WritableKeyPath<CTFEvent, String?>) -> Binding<String> {
        Binding(
            get: {
                self.requiredEvent(for: eventID)[keyPath: keyPath] ?? ""
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                self.updateEvent(eventID) { $0[keyPath: keyPath] = trimmed.isEmpty ? nil : trimmed }
            }
        )
    }

    func optionalIntTextBinding(for eventID: String, _ keyPath: WritableKeyPath<CTFEvent, Int?>) -> Binding<String> {
        Binding(
            get: {
                self.requiredEvent(for: eventID)[keyPath: keyPath].map(String.init) ?? ""
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                self.updateEvent(eventID) { event in
                    event[keyPath: keyPath] = Int(trimmed)
                }
            }
        )
    }

    func attachmentStatusBinding(for eventID: String, kind: AttachmentKind) -> Binding<AttachmentStatus> {
        Binding(
            get: {
                self.event(for: eventID)?.attachment(for: kind).status ?? .unknown
            },
            set: { newValue in
                self.updateEvent(eventID) { event in
                    guard let index = event.attachments.firstIndex(where: { $0.kind == kind }) else { return }
                    event.attachments[index].status = newValue
                }
            }
        )
    }

    func teamMembersTextBinding(for eventID: String) -> Binding<String> {
        Binding(
            get: {
                self.event(for: eventID)?.teamMembers
                    .map(\.displayLine)
                    .joined(separator: "\n") ?? ""
            },
            set: { newValue in
                self.updateEvent(eventID) { event in
                    event.teamMembers = newValue
                        .split(whereSeparator: \.isNewline)
                        .map { line in
                            let value = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !value.isEmpty else {
                                return TeamMember(name: "", registrationNumber: "")
                            }

                            if let open = value.lastIndex(of: "("), value.hasSuffix(")") {
                                let name = String(value[..<open]).trimmingCharacters(in: .whitespaces)
                                let reg = String(value[value.index(after: open)..<value.index(before: value.endIndex)])
                                return TeamMember(name: name, registrationNumber: reg)
                            }

                            return TeamMember(name: value, registrationNumber: "")
                        }
                        .filter { !$0.name.isEmpty }
                }
            }
        )
    }

    private func matchesSearch(_ event: CTFEvent) -> Bool {
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return true }

        let haystack = [
            event.title,
            event.organizer,
            event.description,
            event.notes,
            event.domains.joined(separator: " "),
            event.registrationFee ?? "",
            event.prizeSummary ?? "",
            event.totalPlayers.map(String.init) ?? "",
            event.teamSizeLimit.map(String.init) ?? "",
            event.teamMembers.map(\.displayLine).joined(separator: " "),
        ].joined(separator: " ").lowercased()

        return haystack.contains(needle)
    }

    private func event(for eventID: String) -> CTFEvent? {
        events.first(where: { $0.id == eventID })
    }

    private func requiredEvent(for eventID: String) -> CTFEvent {
        guard let event = event(for: eventID) ?? events.first else {
            preconditionFailure("Attempted to bind an event before the store was hydrated.")
        }
        return event
    }

    private func updateEvent(_ eventID: String, mutation: (inout CTFEvent) -> Void) {
        guard let index = events.firstIndex(where: { $0.id == eventID }) else { return }
        mutation(&events[index])
        events[index].lastSyncedAt = .now
        events.sort(by: Self.sortEvents)
        try? EventPersistenceService.saveEvents(events)
    }

    @discardableResult
    private func upsert(_ incoming: CTFEvent) -> String {
        let incomingKey = Self.canonicalKey(for: incoming)

        if let index = events.firstIndex(where: {
            $0.id == incoming.id || Self.canonicalKey(for: $0) == incomingKey
        }) {
            events[index] = Self.merge(events[index], with: incoming)
        } else {
            events.append(incoming)
        }

        events.sort(by: Self.sortEvents)
        try? EventPersistenceService.saveEvents(events)
        return events.first(where: {
            $0.id == incoming.id || Self.canonicalKey(for: $0) == incomingKey
        })?.id ?? incoming.id
    }

    private func merge(_ incoming: CTFEvent, into merged: inout [String: CTFEvent]) {
        let key = Self.canonicalKey(for: incoming)
        if let existing = merged[key] {
            merged[key] = Self.merge(existing, with: incoming)
        } else {
            merged[key] = incoming
        }
    }

    private static func canonicalKey(for event: CTFEvent) -> String {
        if let ctftimeEventID = event.ctftimeEventID {
            return "ctftime-\(ctftimeEventID)"
        }

        let normalizedTitle = normalized(event.title)
        if let startDate = event.startDate {
            let day = startDate.formatted(.iso8601.year().month().day())
            return "title-\(normalizedTitle)-\(day)"
        }

        if !normalizedTitle.isEmpty {
            return "title-\(normalizedTitle)"
        }

        if let repoPath = event.repoPath, !repoPath.isEmpty {
            return "repo-\(repoPath)"
        }

        return "id-\(event.id)"
    }

    private static func merge(_ existing: CTFEvent, with incoming: CTFEvent) -> CTFEvent {
        var merged = existing
        merged.id = preferredID(existing: existing, incoming: incoming)
        merged.origin = preferredOrigin(existing: existing.origin, incoming: incoming.origin)
        merged.mergeImportedMetadata(from: incoming)

        if merged.teamResult == nil, let teamResult = incoming.teamResult {
            merged.teamResult = teamResult
        }

        if merged.attachments.isEmpty {
            merged.attachments = CTFEvent.defaultAttachments()
        }

        return merged
    }

    private static func preferredID(existing: CTFEvent, incoming: CTFEvent) -> String {
        if let ctftimeEventID = existing.ctftimeEventID ?? incoming.ctftimeEventID {
            return "ctftime-\(ctftimeEventID)"
        }

        if existing.origin == .manual {
            return existing.id
        }

        if incoming.origin == .manual {
            return incoming.id
        }

        return existing.id
    }

    private static func preferredOrigin(existing: EventOrigin, incoming: EventOrigin) -> EventOrigin {
        let rank: [EventOrigin: Int] = [
            .teamHistory: 0,
            .writeupsRepo: 1,
            .ctftime: 2,
            .manual: 3,
        ]

        return (rank[incoming] ?? 0) > (rank[existing] ?? 0) ? incoming : existing
    }

    private static func normalized(_ value: String) -> String {
        value
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    private static func shouldEnrichFromCTFTime(_ event: CTFEvent) -> Bool {
        guard event.ctftimeEventID != nil else { return false }
        return event.description.isEmpty
            || event.organizer.isEmpty
            || event.startDate == nil
            || event.endDate == nil
            || event.website.isEmpty
            || event.format.isEmpty
    }

    private static func sortEvents(lhs: CTFEvent, rhs: CTFEvent) -> Bool {
        if lhs.eventBucket != rhs.eventBucket {
            return bucketOrder(lhs.eventBucket) < bucketOrder(rhs.eventBucket)
        }

        switch lhs.eventBucket {
        case .current:
            if lhs.isLive != rhs.isLive {
                return lhs.isLive && !rhs.isLive
            }

            let lhsAnchor = lhs.startDate ?? lhs.lastSyncedAt ?? .distantFuture
            let rhsAnchor = rhs.startDate ?? rhs.lastSyncedAt ?? .distantFuture
            if lhsAnchor != rhsAnchor {
                return lhsAnchor < rhsAnchor
            }

        case .reporting, .history:
            let lhsAnchor = lhs.endDate ?? lhs.startDate ?? lhs.lastSyncedAt ?? .distantPast
            let rhsAnchor = rhs.endDate ?? rhs.startDate ?? rhs.lastSyncedAt ?? .distantPast
            if lhsAnchor != rhsAnchor {
                return lhsAnchor > rhsAnchor
            }
        }

        let lhsEventID = lhs.ctftimeEventID ?? 0
        let rhsEventID = rhs.ctftimeEventID ?? 0
        if lhsEventID != rhsEventID {
            return lhsEventID > rhsEventID
        }

        if lhs.teamResult?.place != rhs.teamResult?.place {
            return (lhs.teamResult?.place ?? .max) < (rhs.teamResult?.place ?? .max)
        }

        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private static func bucketOrder(_ bucket: EventBucket) -> Int {
        switch bucket {
        case .current: 0
        case .reporting: 1
        case .history: 2
        }
    }
}
