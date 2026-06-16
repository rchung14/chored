import WidgetKit
import SwiftUI

/// One timeline entry: a snapshot of today's incomplete tasks plus the assignee
/// display names needed to render them (resolved up front so the views stay
/// dependency-free).
struct ChoreEntry: TimelineEntry {
    let date: Date
    let tasks: [ChoreTask]
    let assigneeNames: [String: String]   // recordName -> display name

    static let placeholder = ChoreEntry(
        date: Date(),
        tasks: [],
        assigneeNames: [:]
    )
}

struct ChoreTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> ChoreEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (ChoreEntry) -> Void) {
        Task { @MainActor in completion(makeEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ChoreEntry>) -> Void) {
        Task { @MainActor in
            let entry = makeEntry()
            // Reload at the next midnight; explicit reloads happen on data change.
            let nextMidnight = Calendar.current.startOfDay(for: Date().adding(days: 1))
            completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
        }
    }

    @MainActor
    private func makeEntry() -> ChoreEntry {
        let store = WidgetDataStore()
        let tasks = store.todaysIncompleteTasks(limit: 5)
        var names: [String: String] = [:]
        for task in tasks {
            names[task.assigneeRecordName] = store.displayName(for: task.assigneeRecordName)
        }
        return ChoreEntry(date: Date(), tasks: tasks, assigneeNames: names)
    }
}

struct ChoreWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ChoreEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        default:
            MediumWidgetView(entry: entry)
        }
    }
}

@main
struct ChoreWidget: Widget {
    let kind = "ChoreWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ChoreTimelineProvider()) { entry in
            ChoreWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today's Chores")
        .description("See and complete today's chores.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget-local palette

/// The widget cannot import the app's DesignSystem (separation rule), so it
/// carries its own copy of the six preset hex values from DESIGN.md.
enum WidgetPalette {
    private static let hexes = ["A8C5A0", "E8B4B8", "C3B1E1", "A8C8E8", "F5C5A3", "9BB5C8"]

    static func color(for preset: Int, scheme: ColorScheme) -> Color {
        let hex = hexes[min(max(preset, 0), hexes.count - 1)]
        let base = Color(hex: hex)
        return scheme == .dark ? base.opacity(0.70) : base
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)
        self.init(
            .sRGB,
            red: Double((value & 0xFF0000) >> 16) / 255,
            green: Double((value & 0x00FF00) >> 8) / 255,
            blue: Double(value & 0x0000FF) / 255,
            opacity: 1
        )
    }
}
