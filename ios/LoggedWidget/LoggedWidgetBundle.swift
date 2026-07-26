import SwiftUI
import WidgetKit

@main
struct LoggedWidgetBundle: WidgetBundle {
    /// Each entry is a separate choice in the widget gallery. Kinds must match
    /// the iOS names in `HomeWidgetService._widgetVariants`.
    var body: some Widget {
        LoggedStreakWidget()
        LoggedWidget()
        LoggedSummaryWidget()
    }
}
