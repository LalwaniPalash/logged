import SwiftUI
import WidgetKit

private enum LoggedWidgetKeys {
    static let appGroupId = "group.com.palash.logged"
    static let streakKind = "LoggedStreakWidget"
    static let kind = "LoggedWidget"
    static let summaryKind = "LoggedSummaryWidget"
    static let streakText = "logged_widget_streak_text"
    static let setsText = "logged_widget_sets_text"
    static let volumeText = "logged_widget_weekly_volume_text"
    static let lastWorkoutTitle = "logged_widget_last_workout_title"
    static let lastWorkoutDate = "logged_widget_last_workout_date"
    static let lastWorkoutDetail = "logged_widget_last_workout_detail"
}

private enum LoggedWidgetPalette {
    static let accent = Color(red: 0.79, green: 0.51, blue: 0.12)
    static let background = LinearGradient(
        colors: [
            Color(red: 0.97, green: 0.95, blue: 0.92),
            Color(red: 0.94, green: 0.91, blue: 0.87)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct LoggedWidgetEntry: TimelineEntry {
    let date: Date
    let streakText: String
    let setsText: String
    let volumeText: String
    let lastWorkoutTitle: String
    let lastWorkoutDate: String
    let lastWorkoutDetail: String

    static let placeholder = LoggedWidgetEntry(
        date: Date(),
        streakText: "0 days",
        setsText: "0 sets",
        volumeText: "0 kg",
        lastWorkoutTitle: "No workouts yet",
        lastWorkoutDate: "Open Logged to refresh",
        lastWorkoutDetail: "Log a set to get started"
    )

    static let preview = LoggedWidgetEntry(
        date: Date(),
        streakText: "6 days",
        setsText: "18 sets",
        volumeText: "12.4k kg",
        lastWorkoutTitle: "Upper A",
        lastWorkoutDate: "Jul 25",
        lastWorkoutDetail: "18 sets · 6 exercises"
    )
}

/// Every variant reads the same App Group values, so one provider serves them
/// all — only the view differs per widget kind.
struct LoggedWidgetTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> LoggedWidgetEntry {
        LoggedWidgetEntry.placeholder
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
        let fallback = LoggedWidgetEntry.placeholder
        func text(_ key: String, _ fallbackValue: String) -> String {
            defaults?.string(forKey: key) ?? fallbackValue
        }
        return LoggedWidgetEntry(
            date: Date(),
            streakText: text(LoggedWidgetKeys.streakText, fallback.streakText),
            setsText: text(LoggedWidgetKeys.setsText, fallback.setsText),
            volumeText: text(LoggedWidgetKeys.volumeText, fallback.volumeText),
            lastWorkoutTitle: text(LoggedWidgetKeys.lastWorkoutTitle, fallback.lastWorkoutTitle),
            lastWorkoutDate: text(LoggedWidgetKeys.lastWorkoutDate, fallback.lastWorkoutDate),
            lastWorkoutDetail: text(LoggedWidgetKeys.lastWorkoutDetail, fallback.lastWorkoutDetail)
        )
    }
}

// MARK: - Shared pieces

private struct LoggedMetric: View {
    let label: String
    let value: String
    var accent: Color = .primary
    var valueFont: Font = .title3.weight(.bold)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(valueFont)
                .foregroundColor(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LoggedLastWorkout: View {
    let title: String
    let date: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Last workout")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
            Text(date)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension View {
    /// iOS 17 removed the implicit widget background and asks widgets to declare
    /// their own; earlier versions still need it painted behind the content.
    @ViewBuilder
    func loggedWidgetCard() -> some View {
        if #available(iOS 17.0, *) {
            padding(4)
                .containerBackground(LoggedWidgetPalette.background, for: .widget)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LoggedWidgetPalette.background)
                self.padding(16)
            }
        }
    }
}

// MARK: - Small: streak

struct LoggedStreakWidgetEntryView: View {
    var entry: LoggedWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LoggedMetric(
                label: "Streak",
                value: entry.streakText,
                accent: LoggedWidgetPalette.accent,
                valueFont: .title.weight(.bold)
            )
            Divider()
            LoggedMetric(
                label: "This week",
                value: entry.setsText,
                valueFont: .headline.weight(.bold)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .loggedWidgetCard()
    }
}

struct LoggedStreakWidget: Widget {
    let kind: String = LoggedWidgetKeys.streakKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LoggedWidgetTimelineProvider()) { entry in
            LoggedStreakWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Logged · Streak")
        .description("Your training streak and the sets you have logged this week.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Medium: stats

struct LoggedWidgetEntryView: View {
    var entry: LoggedWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                LoggedMetric(
                    label: "Streak",
                    value: entry.streakText,
                    accent: LoggedWidgetPalette.accent
                )
                LoggedMetric(label: "This week", value: entry.setsText)
            }

            Divider()

            LoggedLastWorkout(title: entry.lastWorkoutTitle, date: entry.lastWorkoutDate)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .loggedWidgetCard()
    }
}

struct LoggedWidget: Widget {
    let kind: String = LoggedWidgetKeys.kind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LoggedWidgetTimelineProvider()) { entry in
            LoggedWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Logged · Stats")
        .description("Training streak, weekly sets, and your latest workout.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Large: summary

struct LoggedSummaryWidgetEntryView: View {
    var entry: LoggedWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                LoggedMetric(
                    label: "Streak",
                    value: entry.streakText,
                    accent: LoggedWidgetPalette.accent,
                    valueFont: .title2.weight(.bold)
                )
                LoggedMetric(
                    label: "This week",
                    value: entry.setsText,
                    valueFont: .title2.weight(.bold)
                )
            }

            Divider()

            HStack(alignment: .firstTextBaseline) {
                Text("Volume")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                Spacer(minLength: 8)
                Text(entry.volumeText)
                    .font(.headline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Divider()

            LoggedLastWorkout(
                title: entry.lastWorkoutTitle,
                date: entry.lastWorkoutDate,
                detail: entry.lastWorkoutDetail
            )

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .loggedWidgetCard()
    }
}

struct LoggedSummaryWidget: Widget {
    let kind: String = LoggedWidgetKeys.summaryKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LoggedWidgetTimelineProvider()) { entry in
            LoggedSummaryWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Logged · Summary")
        .description("Streak, weekly sets and volume, and the shape of your last workout.")
        .supportedFamilies([.systemLarge])
    }
}

struct LoggedWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LoggedStreakWidgetEntryView(entry: .preview)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
            LoggedWidgetEntryView(entry: .preview)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
            LoggedSummaryWidgetEntryView(entry: .preview)
                .previewContext(WidgetPreviewContext(family: .systemLarge))
        }
    }
}
