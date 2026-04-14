import SwiftUI

struct EventDetailView: View {
    @Bindable var store: EventStore
    let event: CTFEvent

    var body: some View {
        Group {
            switch store.selectedDetailTab {
            case .overview:
                overviewForm
            case .drafts:
                DraftPanelView(store: store, event: event)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .navigationTitle(event.title)
        .navigationSubtitle(event.timelineLabel)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("View", selection: $store.selectedDetailTab) {
                    Text("Overview").tag(DetailTab.overview)
                    Text("Drafts").tag(DetailTab.drafts)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                StatusChip(
                    title: event.permissionState.title,
                    systemImage: event.permissionState.systemImage,
                    tint: event.permissionState.tint
                )
                StatusChip(
                    title: event.reportState.title,
                    systemImage: event.reportState.systemImage,
                    tint: event.reportState.tint
                )
                if let place = event.teamResult?.place {
                    StatusChip(title: "#\(place)", systemImage: "trophy", tint: .yellow)
                }

                Spacer(minLength: 12)

                if !event.displayLinks.isEmpty {
                    HStack(spacing: 10) {
                        ForEach(event.displayLinks, id: \.url) { link in
                            if let url = URL(string: link.url) {
                                Link(link.title, destination: url)
                                    .font(.callout)
                            }
                        }
                    }
                    .lineLimit(1)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)

            Divider()
        }
        .background(.bar)
    }

    private var overviewForm: some View {
        Form {
            Section("Status") {
                Picker("Permission", selection: store.binding(for: event.id, \.permissionState)) {
                    ForEach(PermissionState.allCases) { Text($0.title).tag($0) }
                }
                Picker("Report", selection: store.binding(for: event.id, \.reportState)) {
                    ForEach(ReportState.allCases) { Text($0.title).tag($0) }
                }
                LabeledContent("Schedule", value: event.timelineLabel)
                if let deadline = event.reportDeadline {
                    LabeledContent("Report due", value: DateFormatting.dateTime(deadline))
                }
                if let certificate = event.extendedCertificateDeadline {
                    LabeledContent("Certificate follow-up", value: DateFormatting.shortDate(certificate))
                }
                LabeledContent("Source", value: event.origin.title)
            }

            Section("Details") {
                TextField("Title", text: store.binding(for: event.id, \.title))
                TextField("Organizer", text: store.binding(for: event.id, \.organizer))
                TextField("Website", text: store.binding(for: event.id, \.website))
                TextField("Format", text: store.binding(for: event.id, \.format))
                TextField("Restrictions", text: store.binding(for: event.id, \.restrictions))
                TextField("Location", text: store.binding(for: event.id, \.location))
                if !event.ctftimeURL.isEmpty {
                    LabeledContent("CTFTime") {
                        Text(event.ctftimeURL)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                if let repoPath = event.repoPath, !repoPath.isEmpty {
                    LabeledContent("Repo") {
                        Text(repoPath)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }

            Section("Result") {
                LabeledContent("Standing", value: event.resultSummary)
                if let points = event.teamResult?.ctfPoints {
                    LabeledContent("CTF points", value: String(format: "%.4f", points))
                }
                if let rating = event.teamResult?.ratingPoints {
                    LabeledContent("Rating", value: String(format: "%.3f", rating))
                }
                LabeledContent("Participants", value: event.participatingTeams.map(String.init) ?? "—")
                LabeledContent("Mode", value: event.onsite == true ? "On-site" : "Online")
                LabeledContent("CTFd", value: event.usesCTFd.map { $0 ? "Yes" : "No" } ?? "—")
            }

            Section("Attachments") {
                ForEach(event.attachments.filter { $0.kind.isRelevant(for: event) }) { attachment in
                    Picker(
                        selection: store.attachmentStatusBinding(for: event.id, kind: attachment.kind)
                    ) {
                        ForEach(AttachmentStatus.allCases) { Text($0.title).tag($0) }
                    } label: {
                        Label(attachment.kind.title, systemImage: attachment.kind.systemImage)
                    }
                }
            }

            Section("Description") {
                TextEditor(text: store.binding(for: event.id, \.description))
                    .font(.body)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                if !event.domains.isEmpty {
                    LabeledContent("Domains", value: event.domains.joined(separator: ", "))
                }
            }

            Section("Team") {
                TextEditor(text: store.teamMembersTextBinding(for: event.id))
                    .font(.body.monospaced())
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
            }

            Section("Notes") {
                TextEditor(text: store.binding(for: event.id, \.notes))
                    .font(.body)
                    .frame(minHeight: 90)
                    .scrollContentBackground(.hidden)
            }
        }
        .formStyle(.grouped)
    }
}
