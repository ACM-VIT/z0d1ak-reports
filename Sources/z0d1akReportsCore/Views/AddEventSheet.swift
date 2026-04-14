import SwiftUI

private enum AddEventMode: String, CaseIterable, Identifiable {
    case ctftime
    case manual

    var id: Self { self }

    var title: String {
        switch self {
        case .ctftime: "CTFTime"
        case .manual: "Manual"
        }
    }
}

struct AddEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: EventStore

    @State private var mode: AddEventMode = .ctftime
    @State private var ctftimeURL = ""
    @State private var title = ""
    @State private var organizer = ""
    @State private var website = ""
    @State private var format = "Jeopardy"
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(86_400)
    @State private var description = ""
    @State private var isSubmitting = false

    private var canSubmit: Bool {
        switch mode {
        case .ctftime:
            return !ctftimeURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .manual:
            return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            form
            Divider()
            footer
        }
        .frame(width: 500)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var form: some View {
        Form {
            Section {
                Picker("Source", selection: $mode) {
                    ForEach(AddEventMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            switch mode {
            case .ctftime:
                Section {
                    TextField("URL", text: $ctftimeURL, prompt: Text("https://ctftime.org/event/…"))
                }
            case .manual:
                Section {
                    TextField("Title", text: $title)
                    TextField("Organizer", text: $organizer)
                    TextField("Website", text: $website)
                    TextField("Format", text: $format)
                }
                Section {
                    DatePicker("Start", selection: $startDate)
                    DatePicker("End", selection: $endDate)
                }
                Section("Description") {
                    TextEditor(text: $description)
                        .font(.body)
                        .frame(minHeight: 90)
                        .scrollContentBackground(.hidden)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minHeight: mode == .ctftime ? 170 : 420)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Spacer()
            Button("Cancel", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)

            Button(mode == .ctftime ? "Import" : "Add") {
                submit()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(!canSubmit || isSubmitting)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func submit() {
        isSubmitting = true
        switch mode {
        case .ctftime:
            Task {
                await store.importFromCTFTime(urlString: ctftimeURL)
                dismiss()
            }
        case .manual:
            store.addManualEvent(
                title: title,
                organizer: organizer,
                website: website,
                format: format,
                startDate: startDate,
                endDate: endDate,
                description: description
            )
            dismiss()
        }
    }
}
