import AppKit
import SwiftUI
import z0d1akReportsCore

@main
struct z0d1akReportsApp: App {
    @State private var store = EventStore()

    var body: some Scene {
        WindowGroup("z0d1ak Reports", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 1040, minHeight: 680)
        }
        .defaultSize(width: 1260, height: 820)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Event…") {
                    store.presentAddEventSheet()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            CommandGroup(after: .pasteboard) {
                Button("Copy Current Draft") {
                    store.copyCurrentDraft()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(!store.canCopyCurrentDraft)
            }
        }

        Settings {
            SettingsView()
        }
    }
}
