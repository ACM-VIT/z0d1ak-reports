import Foundation

enum WriteupsRepositoryService {
    static func scanEvents(repoRootPath: String) throws -> [CTFEvent] {
        let rootURL = URL(fileURLWithPath: repoRootPath)
        let fileManager = FileManager.default
        let entries = try fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        return try entries.compactMap { entry in
            let values = try entry.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else { return nil }
            guard entry.lastPathComponent != "node_modules", entry.lastPathComponent != "scripts" else { return nil }

            let readmeURL = entry.appendingPathComponent("README.md")
            guard fileManager.fileExists(atPath: readmeURL.path) else { return nil }

            let raw = try String(contentsOf: readmeURL, encoding: .utf8)
            let parsed = parseEventReadme(raw)
            let categoryFolders = try categoryNames(in: entry)

            let title = parsed.title.isEmpty ? entry.lastPathComponent : parsed.title
            let ctftimeURL = parsed.fields["CTFtime"] ?? ""
            let website = parsed.fields["Website"] ?? ""
            let ctftimeID = try? CTFTimeService.parseEventID(from: ctftimeURL)

            return CTFEvent(
                id: CTFEvent.makeStableID(ctftimeEventID: ctftimeID, repoPath: entry.lastPathComponent, fallbackTitle: title),
                origin: .writeupsRepo,
                title: title,
                organizer: "",
                website: website,
                format: parsed.fields["Format"] ?? "",
                restrictions: parsed.fields["Restrictions"] ?? "",
                location: parsed.fields["Location"] ?? "",
                description: parsed.description,
                startDate: isoDate(parsed.fields["Start"]),
                endDate: isoDate(parsed.fields["End"]),
                participatingTeams: parsed.fields["Participants"].flatMap(Int.init),
                weight: parsed.fields["Weight"].flatMap(Double.init),
                onsite: boolValue(parsed.fields["Onsite"]),
                discordURL: parsed.fields["Discord"] ?? "",
                liveFeedURL: parsed.fields["Live Feed"] ?? "",
                ctftimeURL: ctftimeURL,
                ctftimeEventID: ctftimeID,
                repoPath: entry.path,
                usesCTFd: boolValue(parsed.fields["CTFd"]),
                domains: categoryFolders,
                teamMembers: [],
                teamResult: nil,
                permissionState: .unknown,
                reportState: .unknown,
                attachments: CTFEvent.defaultAttachments(),
                notes: "",
                lastSyncedAt: .now
            )
        }
    }

    private static func parseEventReadme(_ markdown: String) -> (title: String, fields: [String: String], description: String) {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var title = ""
        var fields: [String: String] = [:]
        var descriptionLines: [String] = []
        var inDescription = false

        for line in lines {
            if line.hasPrefix("# "), title.isEmpty {
                title = String(line.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                continue
            }

            if line == "## Description" {
                inDescription = true
                continue
            }

            if inDescription {
                if line.hasPrefix("## ") {
                    break
                }
                descriptionLines.append(line)
                continue
            }

            guard line.hasPrefix("|"), line.contains("|") else { continue }
            let cells = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard cells.count >= 2 else { continue }
            let key = cells[0]
            let value = cells[1]
            guard key != "Field", !key.allSatisfy({ $0 == "-" }) else { continue }
            fields[key] = value
        }

        return (
            title,
            fields,
            descriptionLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private static func categoryNames(in eventFolder: URL) throws -> [String] {
        let fileManager = FileManager.default
        let children = try fileManager.contentsOfDirectory(
            at: eventFolder,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        return try children.compactMap { child -> String? in
            let values = try child.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else { return nil }
            return child.lastPathComponent
        }.sorted()
    }

    private static func isoDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }

    private static func boolValue(_ value: String?) -> Bool? {
        guard let value else { return nil }
        switch value.lowercased() {
        case "true", "yes", "y", "1":
            return true
        case "false", "no", "n", "0":
            return false
        default:
            return nil
        }
    }
}
