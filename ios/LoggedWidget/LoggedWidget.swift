import SwiftUI
import WidgetKit

private enum LoggedWidgetKeys {
    static let appGroupId = "group.com.palash.logged"
    static let kind = "LoggedWidget"
    static let streakText = "logged_widget_streak_text"
    static let setsText = "logged_widget_sets_text"
    static let lastWorkoutTitle = "logged_widget_last_workout_title"
    static let lastWorkoutDate = "logged_widget_last_workout_date"
}

struct LoggedWidgetEntry: TimelineEntry {
    let date: Date
    let streakText: String
    let setsText: String
    let lastWorkoutTitle: String
    let lastWorkoutDate: String
}

struct LoggedWidgetTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> LoggedWidgetEntry {
        LoggedWidgetEntry(
            date: Date(),
            streakText: "0 days",
            setsText: "0 sets",
            lastWorkoutTitle: "No workouts yet",
            lastWorkoutDate: "Open Logged to refresh"
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (LoggedWidgetEntry) -> Void
    ) {
        completion(loadEntry())
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<LoggedWidgetEntry>) -> Void
    ) {
        let entry = loadEntry()
        let nextRefresh = Calendar.current.date(
            byAdding: .hour,
            value: 6,
            to: Date()
        ) ?? Date().addingTimeInterval(21_600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func loadEntry() -> LoggedWidgetEntry {
        let defaults = UserDefaults(suiteName: LoggedWidgetKeys.appGroupId)
        return LoggedWidgetEntry(
            date: Date(),
            streakText: defaults?.string(forKey: LoggedWidgetKeys.streakText) ?? "0 days",
            setsText: defaults?.string(forKey: LoggedWidgetKeys.setsText) ?? "0 sets",
            lastWorkoutTitle: defaults?.string(forKey: LoggedWidgetKeys.lastWorkoutTitle) ?? "No workouts yet",
            lastWorkoutDate: defaults?.string(forKey: LoggedWidgetKeys.lastWorkoutDate) ?? "Open Logged to refresh"
        )
    }
}

struct LoggedWidgetEntryView: View {
    var entry: LoggedWidgetTimelineProvider.Entry

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.97, green: 0.95, blue: 0.92),
                            Color(red: 0.94, green: 0.91, blue: 0.87)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    metric(label: "Streak", value: entry.streakText, accent: Color(red: 0.79, green: 0.51, blue: 0.12))
                    metric(label: "This week", value: entry.setsText, accent: Color.primary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Last workout")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Text(entry.lastWorkoutTitle)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                    Text(entry.lastWorkoutDate)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private func metric(label: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LoggedWidget: Widget {
    let kind: String = LoggedWidgetKeys.kind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LoggedWidgetTimelineProvider()) { entry in
            LoggedWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Logged widget")
        .description("Training streak, weekly sets, and your latest workout.")
        .supportedFamilies([.systemMedium])
    }
}

struct LoggedWidget_Previews: PreviewProvider {
    static var previews: some View {
        LoggedWidgetEntryView(
            entry: LoggedWidgetEntry(
                date: Date(),
                streakText: "6 days",
                setsText: "18 sets",
                lastWorkoutTitle: "Upper A",
                lastWorkoutDate: "Jul 25"
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
