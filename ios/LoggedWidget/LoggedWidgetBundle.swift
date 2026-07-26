import Foundation
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

/// Exists only to give `NSExtensionPrincipalClass` something that
/// `NSClassFromString` can actually resolve. See `Info.plist` for why the key is
/// set at all.
///
/// It must be a CLASS, not a struct: `LoggedWidgetBundle` above is a SwiftUI
/// struct, so it has no Objective-C class metadata and the lookup returns nil.
/// A nil principal class still installs (installd only checks that the key is
/// present) but leaves the extension unable to launch when WidgetKit probes it
/// for the gallery, so no widget is ever offered.
///
/// `@objc` pins the runtime name, so the key does not depend on the module name.
/// Nothing instantiates this — WidgetKit enters through `@main` above.
@objc(LoggedWidgetPrincipal)
final class LoggedWidgetPrincipal: NSObject {}
