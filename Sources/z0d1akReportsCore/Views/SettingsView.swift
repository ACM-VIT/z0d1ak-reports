import SwiftUI

public struct SettingsView: View {
    public init() {}

    public var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
                .frame(width: 460)
        }
        .scenePadding()
    }
}

private struct GeneralSettings: View {
    @AppStorage("writeupsRepoPath") private var writeupsRepoPath = "/Users/ishaan/Projects/z0d1ak-writeups"
    @AppStorage("ctftimeTeamPageURL") private var ctftimeTeamPageURL = CTFTimeService.defaultTeamURL
    @AppStorage("showHistoryEvents") private var showHistoryEvents = true
    @AppStorage("preferMarkdownExports") private var preferMarkdownExports = true

    var body: some View {
        Form {
            TextField("Writeups repo", text: $writeupsRepoPath)
            TextField("Team page", text: $ctftimeTeamPageURL)
            Toggle("Show history in sidebar", isOn: $showHistoryEvents)
            Toggle("Export drafts as Markdown", isOn: $preferMarkdownExports)
        }
        .formStyle(.grouped)
    }
}
