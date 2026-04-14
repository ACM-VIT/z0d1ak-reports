import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
enum ClipboardService {
    static func copy(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}

@MainActor
enum ExportService {
    static func export(text: String, suggestedFilename: String) throws {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedFilename
        panel.allowedContentTypes = [.plainText]

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        try text.write(to: url, atomically: true, encoding: .utf8)
    }
}
