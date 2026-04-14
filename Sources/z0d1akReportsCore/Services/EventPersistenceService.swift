import Foundation

enum EventPersistenceService {
    static func loadEvents() throws -> [CTFEvent] {
        let url = try existingStorageURL() ?? storageURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([CTFEvent].self, from: data)) ?? []
    }

    static func saveEvents(_ events: [CTFEvent]) throws {
        let url = try storageURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(events)
        try data.write(to: url, options: .atomic)
    }

    private static func storageURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        return base
            .appendingPathComponent("z0d1akReports", isDirectory: true)
            .appendingPathComponent("events.json")
    }

    private static func existingStorageURL() throws -> URL? {
        let fileManager = FileManager.default
        let candidates = try legacyStorageURLs()
        return candidates.first(where: { fileManager.fileExists(atPath: $0.path) })
    }

    private static func legacyStorageURLs() throws -> [URL] {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        return [
            base.appendingPathComponent("z0d1akReports", isDirectory: true).appendingPathComponent("events.json"),
            base.appendingPathComponent("Z0d1akReports", isDirectory: true).appendingPathComponent("events.json"),
        ]
    }
}
