import AppKit
import SwiftUI
import z0d1akReportsCore

@main
struct z0d1akApp: App {
    @State private var store = EventStore()

    var body: some Scene {
        WindowGroup("z0d1ak", id: "main") {
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

            CommandGroup(before: .sidebar) {
                Button("Go to Dashboard") {
                    store.showDashboard()
                }
                .keyboardShortcut("0", modifiers: .command)

                Divider()
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
