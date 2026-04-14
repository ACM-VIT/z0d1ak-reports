import SwiftUI

struct SidebarView: View {
    @Bindable var store: EventStore
    let showHistory: Bool

    private var sections: [SidebarSection] {
        store.sidebarSections(showHistory: showHistory)
    }

    var body: some View {
        List(selection: $store.selectedEventID) {
            Section {
                ForEach(SidebarShortcut.allCases) { shortcut in
                    ShortcutRow(shortcut: shortcut)
                        .tag(shortcut.id as String?)
                }
            }

            ForEach(sections) { section in
                Section {
                    ForEach(section.events) { event in
                        SidebarRow(event: event)
                            .tag(event.id as String?)
                    }
                } header: {
                    HStack(spacing: 6) {
                        Text(section.title)
                        Text("\(section.events.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            if sections.isEmpty {
                emptyState
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("z0d1ak")
    }

    @ViewBuilder
    private var emptyState: some View {
        let trimmed = store.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(trimmed.isEmpty ? "No events yet" : "No matches")
                    .font(.callout.weight(.medium))
                Text(trimmed.isEmpty
                     ? "Refresh to pull from CTFTime."
                     : "Try a different search term.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        }
    }
}

@MainActor
private enum SidebarShortcut: String, CaseIterable, Identifiable {
    case dashboard

    nonisolated var id: String {
        switch self {
        case .dashboard: "com.z0d1ak.dashboard"
        }
    }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        }
    }
}

private struct ShortcutRow: View {
    let shortcut: SidebarShortcut

    var body: some View {
        Label(shortcut.title, systemImage: shortcut.systemImage)
            .labelStyle(.titleAndIcon)
    }
}

private struct SidebarRow: View {
    let event: CTFEvent

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(event.title)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 4)

                    accessory
                }

                Text(event.sidebarSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        } icon: {
            Image(systemName: iconName)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(iconTint)
                .imageScale(.medium)
        }
    }

    @ViewBuilder
    private var accessory: some View {
        if let place = event.teamResult?.place {
            Text("#\(place)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        } else if event.isLive {
            Circle()
                .fill(.orange)
                .frame(width: 6, height: 6)
        }
    }

    private var iconName: String {
        if event.isLive { return "dot.radiowaves.left.and.right" }
        if event.teamResult?.place != nil { return "trophy" }
        if event.eventBucket == .reporting { return "tray.and.arrow.down" }
        return "calendar"
    }

    private var iconTint: Color {
        if event.isLive { return .orange }
        if event.teamResult?.place != nil { return .yellow }
        if event.eventBucket == .reporting { return .blue }
        return .secondary
    }
}
