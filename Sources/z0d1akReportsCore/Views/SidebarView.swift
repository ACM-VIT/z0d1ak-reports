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
                Label("Dashboard", systemImage: "square.grid.2x2")
                    .tag(EventStore.dashboardSelectionID as String?)
            }

            ForEach(sections) { section in
                Section {
                    ForEach(section.events) { event in
                        SidebarRow(event: event)
                            .tag(event.id as String?)
                    }
                } header: {
                    Text(section.title)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("z0d1ak")
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
