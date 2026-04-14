import SwiftUI

public struct ContentView: View {
    @Bindable var store: EventStore
    @AppStorage("writeupsRepoPath") private var writeupsRepoPath = "/Users/ishaan/Projects/z0d1ak-writeups"
    @AppStorage("ctftimeTeamPageURL") private var ctftimeTeamPageURL = CTFTimeService.defaultTeamURL
    @AppStorage("showHistoryEvents") private var showHistoryEvents = true

    public init(store: EventStore) {
        self.store = store
    }

    public var body: some View {
        NavigationSplitView {
            SidebarView(store: store, showHistory: showHistoryEvents)
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        } detail: {
            if store.isShowingDashboard {
                DashboardView(store: store, teamPageURL: ctftimeTeamPageURL)
            } else if let event = store.selectedEvent {
                EventDetailView(store: store, event: event)
            } else {
                ContentUnavailableView(
                    "No Selection",
                    systemImage: "sidebar.left"
                )
            }
        }
        .searchable(text: $store.searchText, placement: .sidebar, prompt: "Search")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if store.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.9)
                }

                Button {
                    showHistoryEvents.toggle()
                } label: {
                    Label("History", systemImage: showHistoryEvents ? "archivebox.fill" : "archivebox")
                }

                Button {
                    Task {
                        await store.refresh(repoRootPath: writeupsRepoPath, teamPageURL: ctftimeTeamPageURL)
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(store.isLoading)

                Button {
                    store.showingAddSheet = true
                } label: {
                    Label("New Event", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }
        .sheet(isPresented: $store.showingAddSheet) {
            AddEventSheet(store: store)
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { store.errorMessage?.isEmpty == false },
                set: { if !$0 { store.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
        .task {
            await store.loadIfNeeded(repoRootPath: writeupsRepoPath, teamPageURL: ctftimeTeamPageURL)
        }
    }
}
