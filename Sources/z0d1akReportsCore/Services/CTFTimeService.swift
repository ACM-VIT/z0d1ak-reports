import Foundation

struct CTFTimeParticipation: Hashable, Sendable {
    var eventID: Int
    var title: String
    var upcomingLabel: String?
    var place: Int?
    var ctfPoints: Double?
    var ratingPoints: Double?
}

struct CTFTimeTeamRating: Hashable, Sendable {
    var year: Int
    var ratingPoints: Double?
    var ratingPlace: Int?
    var countryPlace: Int?
    var organizerPoints: Double?
}

struct CTFTimeTeamInfo: Hashable, Sendable {
    var id: Int
    var name: String
    var country: String?
    var academic: Bool?
    var logoURL: String?
    var ratingsByYear: [Int: CTFTimeTeamRating]

    var currentYear: Int {
        Calendar(identifier: .gregorian).component(.year, from: Date())
    }

    var currentRating: CTFTimeTeamRating? {
        if let rating = ratingsByYear[currentYear] { return rating }
        return ratingsByYear.values.sorted(by: { $0.year > $1.year }).first
    }
}

struct CTFTimeUpcomingEvent: Identifiable, Hashable, Sendable {
    var id: Int
    var title: String
    var weight: Double?
    var start: Date?
    var finish: Date?
    var format: String
    var url: String
    var organizers: [String]
    var participants: Int?
    var onsite: Bool
    var restrictions: String
    var ctftimeURL: String
}

private struct CTFTimeTeamResponse: Decodable {
    struct Rating: Decodable {
        var organizer_points: Double?
        var rating_points: Double?
        var rating_place: Int?
        var country_place: Int?
    }

    var id: Int
    var name: String
    var primary_alias: String?
    var country: String?
    var academic: Bool?
    var logo: String?
    var rating: [String: Rating]
}

private struct CTFTimeUpcomingResponse: Decodable {
    struct Organizer: Decodable {
        var id: Int?
        var name: String
    }

    var id: Int
    var title: String
    var weight: Double?
    var start: String
    var finish: String
    var format: String?
    var url: String?
    var organizers: [Organizer]
    var participants: Int?
    var onsite: Bool?
    var restrictions: String?
    var ctftime_url: String
}

private struct CTFTimeEventResponse: Decodable {
    struct Organizer: Decodable {
        var id: Int?
        var name: String
    }

    var organizers: [Organizer]
    var ctftime_url: String
    var weight: Double?
    var live_feed: String?
    var id: Int
    var title: String
    var start: String
    var participants: Int?
    var location: String?
    var finish: String
    var description: String?
    var format: String?
    var prizes: String?
    var onsite: Bool?
    var restrictions: String?
    var url: String?
}

enum CTFTimeService {
    static let defaultTeamURL = "https://ctftime.org/team/373452"
    private static let userAgent = "Mozilla/5.0 (compatible; z0d1ak-reports/1.0)"

    static func fetchEvents(eventIDs: [Int]) async -> [CTFEvent] {
        let uniqueIDs = Array(Set(eventIDs)).sorted()
        guard !uniqueIDs.isEmpty else { return [] }

        return await withTaskGroup(of: CTFEvent?.self) { group in
            for eventID in uniqueIDs {
                group.addTask {
                    try? await fetchEvent(eventID: eventID)
                }
            }

            var events: [CTFEvent] = []
            for await event in group {
                if let event {
                    events.append(event)
                }
            }
            return events
        }
    }

    static func fetchEvent(urlString: String) async throws -> CTFEvent {
        try await fetchEvent(eventID: parseEventID(from: urlString))
    }

    static func fetchEvent(eventID: Int) async throws -> CTFEvent {
        let url = URL(string: "https://ctftime.org/api/v1/events/\(eventID)/")!
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, url: url)

        let decoded = try JSONDecoder().decode(CTFTimeEventResponse.self, from: data)
        return importedEvent(from: decoded)
    }

    static func fetchTeamParticipations(teamURL: String) async throws -> [CTFTimeParticipation] {
        let normalized = teamURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: normalized) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, url: url)

        guard let html = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeRawData)
        }

        return parseParticipations(html: html)
    }

    static func parseTeamID(from input: String) -> Int? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct = Int(trimmed) { return direct }

        guard let url = URL(string: trimmed) else { return nil }
        let components = url.pathComponents.filter { $0 != "/" }
        if let teamIndex = components.firstIndex(of: "team"),
           teamIndex + 1 < components.count,
           let id = Int(components[teamIndex + 1]) {
            return id
        }
        if let last = components.last, let id = Int(last) { return id }
        return nil
    }

    static func fetchTeamInfo(teamID: Int) async throws -> CTFTimeTeamInfo {
        let url = URL(string: "https://ctftime.org/api/v1/teams/\(teamID)/")!
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, url: url)

        let decoded = try JSONDecoder().decode(CTFTimeTeamResponse.self, from: data)
        var ratings: [Int: CTFTimeTeamRating] = [:]
        for (key, value) in decoded.rating {
            guard let year = Int(key) else { continue }
            ratings[year] = CTFTimeTeamRating(
                year: year,
                ratingPoints: value.rating_points,
                ratingPlace: value.rating_place,
                countryPlace: value.country_place,
                organizerPoints: value.organizer_points
            )
        }

        return CTFTimeTeamInfo(
            id: decoded.id,
            name: decoded.primary_alias ?? decoded.name,
            country: decoded.country,
            academic: decoded.academic,
            logoURL: decoded.logo,
            ratingsByYear: ratings
        )
    }

    static func fetchUpcomingEvents(limit: Int = 15, windowDays: Int = 90) async throws -> [CTFTimeUpcomingEvent] {
        let now = Date()
        let future = Calendar.current.date(byAdding: .day, value: windowDays, to: now) ?? now
        let startTS = Int(now.timeIntervalSince1970)
        let finishTS = Int(future.timeIntervalSince1970)
        let url = URL(string: "https://ctftime.org/api/v1/events/?limit=\(limit)&start=\(startTS)&finish=\(finishTS)")!

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, url: url)

        let decoded = try JSONDecoder().decode([CTFTimeUpcomingResponse].self, from: data)
        return decoded
            .map { item in
                CTFTimeUpcomingEvent(
                    id: item.id,
                    title: item.title,
                    weight: item.weight,
                    start: parseISO8601(item.start),
                    finish: parseISO8601(item.finish),
                    format: item.format ?? "",
                    url: item.url ?? "",
                    organizers: item.organizers.map(\.name),
                    participants: item.participants,
                    onsite: item.onsite ?? false,
                    restrictions: item.restrictions ?? "",
                    ctftimeURL: item.ctftime_url
                )
            }
            .sorted(by: { ($0.start ?? .distantFuture) < ($1.start ?? .distantFuture) })
    }

    static func parseEventID(from input: String) throws -> Int {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct = Int(trimmed) {
            return direct
        }

        guard let url = URL(string: trimmed) else {
            throw URLError(.badURL)
        }

        let components = url.pathComponents.filter { $0 != "/" }
        if let eventIndex = components.firstIndex(of: "event"), eventIndex + 1 < components.count, let id = Int(components[eventIndex + 1]) {
            return id
        }

        if let last = components.last, let id = Int(last) {
            return id
        }

        throw URLError(.badURL)
    }

    static func parseParticipations(html: String) -> [CTFTimeParticipation] {
        let decodedHTML = decodeHTMLEntities(in: html)
        var resultsByID: [Int: CTFTimeParticipation] = [:]

        let historyPattern = #"<tr><td class="place_ico"></td><td class="place">(\d+)</td><td><a href="/event/(\d+)">([^<]+)</a></td><td>([0-9.]+)</td><td>([0-9.]+)</td></tr>"#
        for match in matches(for: historyPattern, in: decodedHTML) {
            guard
                match.count == 6,
                let place = Int(match[1]),
                let eventID = Int(match[2])
            else {
                continue
            }

            resultsByID[eventID] = CTFTimeParticipation(
                eventID: eventID,
                title: match[3],
                upcomingLabel: nil,
                place: place,
                ctfPoints: Double(match[4]),
                ratingPoints: Double(match[5])
            )
        }

        let upcomingPattern = #"<tr><td><a href="/event/(\d+)">([^<]+)</a></td><td>([^<]+)</td></tr>"#
        for match in matches(for: upcomingPattern, in: decodedHTML) {
            guard match.count == 4, let eventID = Int(match[1]) else {
                continue
            }

            if resultsByID[eventID] != nil {
                continue
            }

            resultsByID[eventID] = CTFTimeParticipation(
                eventID: eventID,
                title: match[2],
                upcomingLabel: match[3].trimmingCharacters(in: .whitespacesAndNewlines),
                place: nil,
                ctfPoints: nil,
                ratingPoints: nil
            )
        }

        return resultsByID.values.sorted { lhs, rhs in
            if lhs.place != nil && rhs.place == nil { return false }
            if lhs.place == nil && rhs.place != nil { return true }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    static func stubEvent(from participation: CTFTimeParticipation) -> CTFEvent {
        CTFEvent(
            id: CTFEvent.makeStableID(ctftimeEventID: participation.eventID, repoPath: nil, fallbackTitle: participation.title),
            origin: .teamHistory,
            title: participation.title,
            organizer: "",
            website: "",
            format: "",
            restrictions: "",
            location: "",
            description: participation.upcomingLabel.map { "Discovered from the team page: \($0)." } ?? "",
            startDate: nil,
            endDate: nil,
            participatingTeams: nil,
            weight: nil,
            onsite: nil,
            discordURL: "",
            liveFeedURL: "",
            ctftimeURL: "https://ctftime.org/event/\(participation.eventID)",
            ctftimeEventID: participation.eventID,
            repoPath: nil,
            usesCTFd: nil,
            domains: [],
            teamMembers: [],
            teamResult: TeamResult(place: participation.place, ctfPoints: participation.ctfPoints, ratingPoints: participation.ratingPoints),
            permissionState: .unknown,
            reportState: .unknown,
            attachments: CTFEvent.defaultAttachments(),
            notes: "",
            lastSyncedAt: .now
        )
    }

    static func extractDomains(from description: String) -> [String] {
        let known = [
            "Web", "Web Exploitation", "Cryptography", "Crypto", "Forensics",
            "Reverse Engineering", "Rev", "Pwn", "OSINT", "Misc", "Miscellaneous",
            "Hardware", "AI", "Cloud", "Mobile", "Programming", "PPC", "Blockchain"
        ]

        let lines = description
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespaces) }

        if let categoriesLine = lines.first(where: { $0.localizedCaseInsensitiveContains("Categories:") }) {
            let tail = categoriesLine.components(separatedBy: ":").dropFirst().joined(separator: ":")
            let items = tail
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            if !items.isEmpty {
                return items
            }
        }

        return known.filter { description.localizedCaseInsensitiveContains($0) }
    }

    private static func importedEvent(from response: CTFTimeEventResponse) -> CTFEvent {
        let description = response.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let prizeText = response.prizes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let organizerLine = response.organizers.map(\.name).joined(separator: ", ")

        return CTFEvent(
            id: CTFEvent.makeStableID(ctftimeEventID: response.id, repoPath: nil, fallbackTitle: response.title),
            origin: .ctftime,
            title: response.title,
            organizer: organizerLine,
            website: response.url ?? "",
            format: response.format ?? "",
            restrictions: response.restrictions ?? "",
            location: response.location ?? "",
            description: description,
            startDate: parseISO8601(response.start),
            endDate: parseISO8601(response.finish),
            participatingTeams: response.participants,
            weight: response.weight,
            onsite: response.onsite,
            discordURL: extractDiscordLink(from: description + "\n" + prizeText),
            liveFeedURL: response.live_feed ?? "",
            ctftimeURL: response.ctftime_url,
            ctftimeEventID: response.id,
            repoPath: nil,
            usesCTFd: nil,
            domains: extractDomains(from: description),
            teamMembers: [],
            teamResult: nil,
            permissionState: .unknown,
            reportState: .unknown,
            attachments: CTFEvent.defaultAttachments(),
            notes: "",
            lastSyncedAt: .now
        )
    }

    private static func parseISO8601(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }

    private static func extractDiscordLink(from text: String) -> String {
        matches(for: #"https:\/\/discord\.gg\/[^\s<>"')]+"#, in: text).first?.first ?? ""
    }

    private static func matches(for pattern: String, in text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: range).compactMap { match in
            var captures: [String] = []
            for index in 0..<match.numberOfRanges {
                let captureRange = match.range(at: index)
                guard let swiftRange = Range(captureRange, in: text) else {
                    captures.append("")
                    continue
                }
                captures.append(String(text[swiftRange]))
            }
            return captures
        }
    }

    private static func decodeHTMLEntities(in text: String) -> String {
        text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }

    private static func validate(response: URLResponse, url: URL) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "CTFTimeService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to fetch \(url.absoluteString)."
            ])
        }
    }
}
