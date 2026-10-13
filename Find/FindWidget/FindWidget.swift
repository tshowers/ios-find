import SwiftUI
import WidgetKit

/// What the widget shows, written by the app (FindWatchStore) into the
/// shared App Group whenever the Watching list changes.
struct FindWidgetEntry: TimelineEntry {
    let date: Date
    let changedCount: Int
    let latestTitle: String
    let latestSummary: String
    let latestAt: Date?
}

struct FindWidgetProvider: TimelineProvider {
    static let groupID = "group.tech.taliferro.find"

    func placeholder(in context: Context) -> FindWidgetEntry {
        FindWidgetEntry(date: Date(), changedCount: 1, latestTitle: "Tree Runner", latestSummary: "Price dropped from $100.00 to $85.00", latestAt: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (FindWidgetEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FindWidgetEntry>) -> Void) {
        // The app reloads the widget when watches change; this is a backstop.
        completion(Timeline(entries: [currentEntry()], policy: .after(Date().addingTimeInterval(60 * 60))))
    }

    private func currentEntry() -> FindWidgetEntry {
        let shared = UserDefaults(suiteName: Self.groupID)
        let at = shared?.double(forKey: "widget.latestAt") ?? 0
        return FindWidgetEntry(
            date: Date(),
            changedCount: shared?.integer(forKey: "widget.changedCount") ?? 0,
            latestTitle: shared?.string(forKey: "widget.latestTitle") ?? "",
            latestSummary: shared?.string(forKey: "widget.latestSummary") ?? "",
            latestAt: at > 0 ? Date(timeIntervalSince1970: at) : nil
        )
    }
}

private let findBlue = Color(red: 0x2f / 255, green: 0x6b / 255, blue: 1)

struct FindWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FindWidgetEntry

    var body: some View {
        Group {
            if family == .systemSmall {
                small
            } else {
                medium
            }
        }
        .containerBackground(for: .widget) { Color(.systemBackground) }
    }

    private var searchPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
            Text("Search")
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Color(.secondarySystemBackground), in: Capsule())
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Find").font(.system(size: 22, weight: .heavy))
                Spacer()
                if entry.changedCount > 0 {
                    Text("\(entry.changedCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(Color.red, in: Circle())
                }
            }
            Spacer(minLength: 0)
            if entry.changedCount > 0 {
                Text(entry.latestSummary)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(findBlue)
                    .lineLimit(2)
            }
            searchPill
        }
        .widgetURL(URL(string: entry.changedCount > 0 ? "find://watching" : "find://search"))
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Find").font(.system(size: 22, weight: .heavy))
                Spacer()
                Link(destination: URL(string: "find://search")!) {
                    searchPill.frame(width: 170)
                }
            }
            Link(destination: URL(string: "find://watching")!) {
                VStack(alignment: .leading, spacing: 3) {
                    if entry.latestTitle.isEmpty {
                        Text("WATCHING").font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)
                        Text("Tap Watch on a result and changes show up here.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    } else {
                        Text(entry.changedCount > 0 ? "CHANGED" : "LATEST CHANGE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(entry.changedCount > 0 ? findBlue : .secondary)
                        Text(entry.latestTitle)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Text(entry.latestSummary).lineLimit(1)
                            if let at = entry.latestAt {
                                Text("· \(at, style: .relative) ago").lineLimit(1)
                            }
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct FindWidget: Widget {
    let kind = "FindWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FindWidgetProvider()) { entry in
            FindWidgetView(entry: entry)
        }
        .configurationDisplayName("Find")
        .description("Search Find, and see when something you're watching changes.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
