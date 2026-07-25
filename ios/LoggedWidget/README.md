# Logged iOS Widget Staging

These files are intentionally **not wired into Xcode yet**. They are safe to keep in the repo because `ios/Runner.xcodeproj/project.pbxproj` is unchanged, so `flutter build ios --simulator --debug` can still run without a widget target.

## Manual setup in Xcode

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Add a new target:
   `File > New > Target... > Widget Extension`
3. Name the extension target `LoggedWidget`.
4. When Xcode asks whether to activate the new scheme, choose either option; it does not affect the Flutter app target.
5. Add the App Group capability to both `Runner` and `LoggedWidget`:
   `group.com.palash.logged`
6. Add `ios/LoggedWidget/LoggedWidget.swift` to the new `LoggedWidget` target.
7. Keep the widget `kind` string as `LoggedWidget` so it matches the staged Dart service call.
8. If Xcode generated placeholder widget files, remove them from the target and keep this staged source instead.

## Also manual: the HealthKit entitlement

`ios/Runner/Runner.entitlements` exists and declares `com.apple.developer.healthkit`, but it is
**inert** — nothing references it, because wiring it means setting `CODE_SIGN_ENTITLEMENTS` in
`project.pbxproj`, which this change deliberately does not touch. Until you do the step below, the
Health export builds and runs but will be refused by iOS at permission time. It is fully working on
Android today.

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select the `Runner` target > `Signing & Capabilities` > `+ Capability` > **HealthKit**.
   Xcode will pick up the existing `Runner.entitlements` rather than creating a second one.
3. Confirm `Build Settings > Code Signing Entitlements` reads `Runner/Runner.entitlements`.

`NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` are already in `Info.plist`, so no
further plist work is needed.

## Notes

- The staged widget reads the values that `home_widget` stores in the shared app-group defaults.
- The app side is **not** calling `HomeWidget.setAppGroupId(...)` yet. Do that only when you are ready to finish the iOS wiring after the App Group entitlement is active on both targets.
- Use the same App Group id everywhere:
  `group.com.palash.logged`
