import SwiftUI

struct DraftPanelView: View {
    @Bindable var store: EventStore
    let event: CTFEvent

    @AppStorage("preferMarkdownExports") private var preferMarkdownExports = true
    @State private var exportError: String?

    private var subject: String {
        DraftComposer.subject(for: store.selectedDraftKind, event: event)
    }

    private var content: String {
        DraftComposer.content(for: store.selectedDraftKind, event: event)
    }

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            Divider()
            draftBody
        }
        .alert(
            "Export failed",
            isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
    }

    private var controlBar: some View {
        HStack(spacing: 10) {
            Picker("Draft", selection: $store.selectedDraftKind) {
                ForEach(DraftKind.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 320)

            Spacer()

            Button("Copy Subject") {
                ClipboardService.copy(subject)
            }

            Button("Copy Draft") {
                ClipboardService.copy(DraftComposer.fullDraft(for: store.selectedDraftKind, event: event))
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])

            Button("Export…") {
                do {
                    try ExportService.export(
                        text: DraftComposer.fullDraft(for: store.selectedDraftKind, event: event),
                        suggestedFilename: DraftComposer.suggestedFilename(
                            for: store.selectedDraftKind,
                            event: event,
                            preferMarkdown: preferMarkdownExports
                        )
                    )
                } catch {
                    exportError = error.localizedDescription
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var draftBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(subject)
                    .font(.title3.weight(.semibold))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(content)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}
