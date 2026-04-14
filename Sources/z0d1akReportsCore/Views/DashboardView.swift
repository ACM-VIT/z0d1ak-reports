import SwiftUI

struct DashboardView: View {
    @Bindable var store: EventStore
    let teamPageURL: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                hero
                metrics
                upcomingSection
                recentSection
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: 1020, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .navigationTitle("Dashboard")
        .navigationSubtitle(subtitleText)
        .task {
            await store.loadDashboardIfNeeded(teamPageURL: teamPageURL)
        }
    }

    private var subtitleText: String {
        guard let rating = store.teamInfo?.currentRating else { return "" }
        return "\(rating.year) season"
    }

    // MARK: - Hero

    private var hero: some View {
        HStack(alignment: .center, spacing: 14) {
            teamLogo
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(store.teamInfo?.name ?? "z0d1ak")
                    .font(.title2.weight(.semibold))

                HStack(spacing: 8) {
                    if let country = store.teamInfo?.country, !country.isEmpty {
                        Label(country, systemImage: "flag")
                    }
                    if store.teamInfo?.academic == true {
                        Label("Academic", systemImage: "graduationcap")
                    }
                    Label("ACM-VIT", systemImage: "person.3")
                }
                .labelStyle(.titleAndIcon)
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if store.isLoadingDashboard {
                ProgressView().controlSize(.small)
            }

            if let url = URL(string: teamPageURL) {
                Link("Team page", destination: url)
                    .font(.callout)
            }
        }
    }

    @ViewBuilder
    private var teamLogo: some View {
        if let logo = store.teamInfo?.logoURL, let url = URL(string: logo) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    fallbackLogo
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            fallbackLogo
        }
    }

    private var fallbackLogo: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(.quaternary)
            .overlay(
                Image(systemName: "shield.lefthalf.filled")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            )
    }

    // MARK: - Metrics

    private var metrics: some View {
        let rating = store.teamInfo?.currentRating
        let globalValue = rating?.ratingPlace.map { "#\($0)" } ?? "—"
        let nationalValue = rating?.countryPlace.map { "#\($0)" } ?? "—"
        let ratingValue = rating?.ratingPoints.map { String(format: "%.2f", $0) } ?? "—"
        let year = rating.map { "\($0.year)" } ?? "—"
        let country = store.teamInfo?.country ?? "—"

        return HStack(spacing: 12) {
            MetricTile(
                label: "Global",
                value: globalValue,
                caption: year,
                tint: .blue
            )
            MetricTile(
                label: "National",
                value: nationalValue,
                caption: country,
                tint: .green
            )
            MetricTile(
                label: "Rating",
                value: ratingValue,
                caption: "points",
                tint: .orange
            )
            MetricTile(
                label: "Upcoming",
                value: "\(store.upcomingEvents.count)",
                caption: "next 90 days",
                tint: .purple
            )
        }
    }

    // MARK: - Upcoming

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Upcoming CTFs") {
                if !store.upcomingEvents.isEmpty {
                    Text("\(store.upcomingEvents.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if store.upcomingEvents.isEmpty {
                emptyState("No upcoming events in the next 90 days.")
            } else {
                Table(store.upcomingEvents) {
                    TableColumn("Weight") { event in
                        WeightBadge(weight: event.weight)
                    }
                    .width(min: 56, ideal: 64, max: 72)

                    TableColumn("Title") { event in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(event.title)
                                .lineLimit(1)
                            if !event.organizers.isEmpty {
                                Text(event.organizers.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .width(min: 200, ideal: 320)

                    TableColumn("Format") { event in
                        Text(event.format.isEmpty ? "—" : event.format)
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 80, ideal: 110, max: 140)

                    TableColumn("Starts") { event in
                        if let start = event.start {
                            Text(upcomingDateLabel(for: start))
                                .monospacedDigit()
                        } else {
                            Text("—").foregroundStyle(.secondary)
                        }
                    }
                    .width(min: 120, ideal: 160, max: 200)

                    TableColumn("Mode") { event in
                        Text(event.onsite ? "On-site" : "Online")
                            .foregroundStyle(.secondary)
                    }
                    .width(min: 60, ideal: 70, max: 90)

                    TableColumn("") { event in
                        if let url = URL(string: event.ctftimeURL) {
                            Link(destination: url) {
                                Image(systemName: "arrow.up.right.square")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .width(28)
                }
                .tableStyle(.inset(alternatesRowBackgrounds: true))
                .frame(minHeight: 220, maxHeight: 440)
            }
        }
    }

    // MARK: - Recent results

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Recent Results") {
                if !store.recentResults.isEmpty {
                    Text("\(store.recentResults.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if store.recentResults.isEmpty {
                emptyState("No finished events with a standing yet.")
            } else {
                Table(Array(store.recentResults.prefix(8))) {
                    TableColumn("Place") { event in
                        if let place = event.teamResult?.place {
                            Text("#\(place)")
                                .font(.body.monospacedDigit().weight(.medium))
                                .foregroundStyle(place <= 3 ? .yellow : .primary)
                        }
                    }
                    .width(min: 48, ideal: 56, max: 72)

                    TableColumn("Event") { event in
                        Text(event.title).lineLimit(1)
                    }
                    .width(min: 180, ideal: 320)

                    TableColumn("Ended") { event in
                        if let end = event.endDate {
                            Text(DateFormatting.shortDate(end))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        } else {
                            Text("—").foregroundStyle(.secondary)
                        }
                    }
                    .width(min: 100, ideal: 120, max: 140)

                    TableColumn("CTF pts") { event in
                        if let points = event.teamResult?.ctfPoints {
                            Text(String(format: "%.2f", points))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        } else {
                            Text("—").foregroundStyle(.secondary)
                        }
                    }
                    .width(min: 72, ideal: 88, max: 110)

                    TableColumn("Rating") { event in
                        if let rating = event.teamResult?.ratingPoints {
                            Text(String(format: "%.3f", rating))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        } else {
                            Text("—").foregroundStyle(.secondary)
                        }
                    }
                    .width(min: 72, ideal: 88, max: 120)
                }
                .tableStyle(.inset(alternatesRowBackgrounds: true))
                .frame(minHeight: 180, maxHeight: 360)
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader<Trailing: View>(
        _ title: String,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
            Spacer()
            trailing()
        }
    }

    private func emptyState(_ text: String) -> some View {
        HStack {
            Text(text)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }

    private func upcomingDateLabel(for date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        if interval < 0 {
            return DateFormatting.shortDate(date)
        }
        if interval < 86_400 {
            return "Today · " + date.formatted(date: .omitted, time: .shortened)
        }
        if interval < 2 * 86_400 {
            return "Tomorrow · " + date.formatted(date: .omitted, time: .shortened)
        }
        if interval < 7 * 86_400 {
            return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
        }
        return date.formatted(.dateTime.day().month(.abbreviated).year().hour().minute())
    }
}

private struct MetricTile: View {
    let label: String
    let value: String
    let caption: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .textCase(.uppercase)
                .kerning(0.4)

            Text(value)
                .font(.system(size: 30, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(caption)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
}

private struct WeightBadge: View {
    let weight: Double?

    private var tint: Color {
        guard let weight else { return .secondary }
        if weight >= 70 { return .purple }
        if weight >= 40 { return .red }
        if weight >= 20 { return .orange }
        if weight >= 10 { return .blue }
        return .secondary
    }

    private var label: String {
        guard let weight else { return "—" }
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", weight)
        }
        return String(format: "%.1f", weight)
    }

    var body: some View {
        Text(label)
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(tint)
            .frame(minWidth: 36)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.14))
            )
    }
}
