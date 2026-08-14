# PHASE 6 SPEC — Rest timer: persistent lock-screen countdown (standalone brief for Codex)

> **You have NO prior conversation context.** Everything you need is below. Every file path, symbol,
> line number, and plugin field named here was verified against the working tree at commit `3f41587`
> (branch `feat/set-editor-backup-ux`) on 2026-08-14, and against
> `~/.pub-cache/hosted/pub.dev/flutter_local_notifications-22.1.0/`. Line numbers drift as you edit —
> treat them as "look here first", and **always open the file and confirm the signature before using
> it.**
>
> Full audit evidence lives in `tasks/audit-2026-08-14.md`: findings **C1** (line 143), **C2**
> (line 150), and the design section at line 893. The summary in `tasks/spec-audit-fixes.md` under
> "PHASE 6" (line 577) is superseded by this document.

## Project in 20 seconds

Logged is a private, 100% local, no-account Flutter workout tracker (Android + iOS, Drift +
Riverpod, feature-first). No network, no analytics, no accounts — do not add any. Phases 1–5 of an
audit remediation have shipped. This is Phase 6 of 7; Phase 7 (deferrable polish) comes after.

Baseline you must preserve: **`flutter analyze` clean, `flutter test` 289/289 green.**

---

## GROUND RULES (non-negotiable — distilled from `tasks/lessons.md`, read it)

1. **Verify APIs before use.** Every symbol named below exists today. Still open the file and confirm
   the signature. Never assume a method shape. Never invent one. This rule has teeth in this phase —
   see the plugin-API warning below.
2. **No schema changes in this phase.** `schemaVersion` stays **12**. Nothing here touches the
   database at all.
3. **Root-cause, not call-site.** When you fix a shared function, grep every caller first.
4. **Never build a `DateTime` by adding a `Duration` of days.** DST makes `now.add(Duration(days: 1))`
   land on 23:00. Construct calendar-wise: `DateTime(y, m, d + 1)`. `lib/core/domain/streak.dart` is
   the reference. (Seconds-scale `Duration` arithmetic, which is all this phase needs, is fine.)
5. **Green tests are necessary, not sufficient.** Every finding in the source audit survived a green
   suite. Add tests that would have caught the bug, not tests that describe the new code.
6. **A green build proves nothing about a capability.** `lessons.md` records an entitlements plist
   that existed, built clean, and was completely inert. Notifications are the same class of thing:
   the only proof is a real, backgrounded device.
7. **Do not modify files outside a task's stated scope.** `git diff HEAD` must stay a clean review
   surface.
8. **Commit per task**, in the order given. Run `flutter analyze` and `flutter test` before each
   commit. Do not proceed on a red suite.

---

## ⚠️ PLUGIN API WARNING — READ BEFORE WRITING A LINE

`flutter_local_notifications` **22.1.0** takes **named** arguments where nearly every online example,
StackOverflow answer, and pre-22 tutorial uses **positional** ones. The in-repo calls are the truth:

```dart
await _plugin.show(id: id, title: title, body: body, notificationDetails: details);
await _plugin.cancel(id: id);
await _plugin.zonedSchedule(
  id: id, scheduledDate: ..., title: ..., body: ...,
  notificationDetails: ..., androidScheduleMode: ...,
);
await _plugin.initialize(settings: const InitializationSettings(android: ..., iOS: ...));
```

`AndroidNotificationDetails(channelId, channelName, ...)` keeps its first two positional. Copy the
shapes from `lib/core/services/notification_service.dart` rather than from memory.

**Verified present on `AndroidNotificationDetails` in 22.1.0** (checked in the package source, all
named constructor params): `ongoing`, `silent`, `onlyAlertOnce`, `when`, `usesChronometer`,
`chronometerCountDown`, `category`, `actions`. **Verified present on `DarwinNotificationDetails`:**
`interruptionLevel`. **Verified present on `initialize`:**
`onDidReceiveNotificationResponse` and `onDidReceiveBackgroundNotificationResponse`.

---

## ARCHITECTURE MAP (what exists today — all verified)

- **`NotificationClient`** (`lib/core/services/notification_service.dart:8`) — the injectable seam.
  Deliberately plugin-free: it exposes only `int`, `String`, `DateTime`. Methods today:
  `init()`, `requestPermission()`, `showNow({id, title, body, channelId, channelName})`,
  `schedule({id, at, title, body, channelId, channelName})`, `cancel(id)`.
- **`NotificationService`** (same file, line 37) implements it.
  `restTimerNotificationId = 1001` (line 41). `init()` at line 70 calls `_plugin.initialize` with
  **no response callbacks** (line 74) — that gap is task 6.1c. `schedule()` at line 143 is the C1
  bug: `AndroidScheduleMode.inexactAllowWhileIdle` at line 162. `_details(channelId, channelName)`
  at line 180 builds one fixed `NotificationDetails` for every notification.
  Every public method swallows `PlatformException` and returns — **preserve that**; notification
  failure must never break the in-app timer.
- **`RestTimerController`** (`lib/features/session/rest_timer_controller.dart:78`), a
  `Notifier<RestTimerState>` with `WidgetsBindingObserver`:
  - `RestTimerState` (line 41): `sessionId`, `remainingSeconds`, `running`, `endTime`, plus
    `display` and `copyWith`. `RestTimerState.idle` is the all-null/false constant.
  - `build()` (84) registers the observer and an `onDispose`.
  - `start({sessionId, seconds, notificationsEnabled})` (93) → `Future<bool>` (the bool is
    "notifications actually allowed"), `tick()` (122), `adjust(int seconds)` (135), `skip()` (150),
    `cancel({int? sessionId})` (152), `_finish()` (162).
  - `didChangeAppLifecycleState` (179) and `_syncBackgroundNotification` (187) — **both are the
    Phase 6 target.**
  - `_remainingAt` (211) is a pure top-level helper. `endTime`, not tick count, is authoritative on
    resume — the audit calls this out as correct (**C3, finding at line 155: no issue**). Keep it.
  - Injection seams already exist and the tests use them: `restTimerClockProvider`,
    `restTimerTickerFactoryProvider`, `restTimerFeedbackProvider` (lines 27–34).
- **`RestTimerBar`** (`lib/features/session/widgets/rest_timer_bar.dart`) — line **15** is the C2
  bug: `if (!state.running || state.sessionId != sessionId) return const SizedBox.shrink();`.
  Controls at 39–49: −15s, +15s, Skip. Note `FontFeature.tabularFigures()` at line 35 — carry it.
- **Session screen** (`lib/features/session/active_session_screen.dart`, ~1500 lines):
  `_startRestTimer(detail)` at **677** reads `RestTimerPreferences` and calls
  `controller.start(...)`; it is called from two places (513 and 671) when a set becomes complete.
  `RestTimerBar(sessionId: widget.sessionId)` is mounted at **1032**. `dispose()` (~64) cancels the
  timer for this session. `suggestNextSet(...)` is called at **1197** and yields a
  `ProgressionSuggestion?`.
- **`ProgressionSuggestion`** (`lib/core/domain/progression.dart:4`) — fields `weightValue`, `unit`,
  `reps`, and **`rationale`** (a `String`). That `rationale` is what task 6.3 must display.
- **`RestTimerPreferences`** (`lib/data/repositories/settings_repository.dart:14`) —
  `autoStartEnabled`, `defaultSeconds` (90), `notificationsEnabled`.
- **Tests**: `test/features/rest_timer_controller_test.dart` already builds a `ProviderContainer`
  with all four providers overridden and a `_FakeNotificationClient` (line 106) that records only
  `cancelled`. **Extend that fake; do not write a second one.**

---

# TASK 6.1 — C1: the Android alarm is inexact, so the timer is unreliable 🟠

### The bug
`NotificationService.schedule` (line 143) passes `AndroidScheduleMode.inexactAllowWhileIdle`
(line 162). Android may delay an inexact alarm by minutes. For a 90-second rest, the notification
*is* the feature; delayed by 60 s it is worse than nothing. Avoiding the `SCHEDULE_EXACT_ALARM`
permission is the right call — but the fix is to stop depending on an alarm at all.

### Decided fix — post a self-ticking notification instead of scheduling one

Android can render a countdown that **the system ticks**, with no Dart process and no alarm:
`usesChronometer: true` + `chronometerCountDown: true` + `when: endTime.millisecondsSinceEpoch`.
Post it with `show` at `start()`. Nothing has to fire at the right instant, because it is already on
screen counting down. Fire a separate, ordinary alert at zero.

**Do NOT add the `SCHEDULE_EXACT_ALARM` permission, and do not change `schedule()`'s existing
`AndroidScheduleMode`.** `schedule()` has another caller — grep it (`reminder_scheduler`) — and this
task must not change that caller's behaviour. Ground rule 3 cuts both ways: shared code, but a
different requirement.

### 6.1a — two new methods on `NotificationClient`

Keep the interface plugin-free. Add exactly two methods, both alongside the existing ones:

```dart
/// Posts (or updates) the ongoing rest countdown. Android renders a system-ticked
/// chronometer counting down to [endTime]; iOS has no equivalent, so it schedules a
/// one-shot alert at [endTime] instead.
Future<void> showRestCountdown({
  required int id,
  required DateTime endTime,
  required String title,
  required String body,
});

/// Replaces the countdown with a dismissible "rest is over" alert.
Future<void> showRestComplete({
  required int id,
  required String title,
  required String body,
});
```

Implement both on `NotificationService` in the same defensive style as the existing methods:
`await init(); if (!_initialized) return;` then a `try` that catches `PlatformException` and
`debugPrint`s.

Branch on `defaultTargetPlatform` exactly the way `requestPermission` (line 93) already does — a
`switch` expression, `_ => ` for anything that is not Android/iOS. On iOS, `showRestCountdown`
delegates to the existing `zonedSchedule` path; the inexact-alarm problem is Android-only, so iOS
keeps working as it does today.

### 6.1b — the channel split (this part is load-bearing, do not merge the channels)

**An Android notification channel's importance is fixed at creation and cannot be changed by the
app afterwards.** The existing `rest_timer` channel was created at `Importance.high` and already
exists at that importance on every current user's device. An ongoing countdown posted to it would
try to heads-up popup on every update.

So use **two** channels:

| Purpose | channelId | channelName | Importance | Key flags |
|---|---|---|---|---|
| Ongoing countdown | `rest_timer_progress` | `Rest timer countdown` | `Importance.low` | `ongoing: true`, `silent: true`, `onlyAlertOnce: true`, `usesChronometer: true`, `chronometerCountDown: true`, `when: endTime.millisecondsSinceEpoch`, `category: AndroidNotificationCategory.stopwatch` |
| Completion alert | `rest_timer` (existing) | `Rest timer` | `Importance.high` | default `_details`, plus iOS `interruptionLevel: InterruptionLevel.timeSensitive` |

`_details(channelId, channelName)` (line 180) is shared by every other notification in the app. **Do
not add parameters to it.** Write a separate private builder for the countdown details and leave
`_details` untouched, so the coaching reminders keep the exact behaviour they have today.

`interruptionLevel: InterruptionLevel.timeSensitive` goes on the **completion** notification only, so
it breaks through Focus modes. This is the interim iOS answer; Live Activities are explicitly out of
scope (see DO NOTs).

### 6.1c — notification actions (+15s / Skip), and the isolate trap

`init()` (line 70) currently calls `_plugin.initialize(settings: ...)` with **no callbacks**, so a
tap on a notification action goes nowhere.

Wire **`onDidReceiveNotificationResponse` only.** Expose the taps off `NotificationClient` as a
stream so the controller stays plugin-free:

```dart
/// Action ids from notification buttons, e.g. 'rest_add_15', 'rest_skip'.
/// Foreground-isolate only — see the note in the implementation.
Stream<String> get actionSelections;
```

`NotificationService` backs it with a `StreamController<String>.broadcast()` fed from the
`onDidReceiveNotificationResponse` callback (`response.actionId`).

**Do NOT register `onDidReceiveBackgroundNotificationResponse`.** That callback runs in a **separate
Dart isolate** with its own memory: it cannot see the Riverpod container, cannot read
`RestTimerState`, and cannot write it back. A handler there would compile, run, and silently do
nothing to the timer the user is looking at — a button that appears to work and does not. Write a
comment in `init()` saying exactly that, so the next person does not "fix" the omission.

The honest consequence, which you must also state in the comment: **if the app process has been
killed, the +15s / Skip buttons only bring the app back; they do not adjust the timer.** A rest
timer runs 60–180 s immediately after the user interacted with the app, so the process is alive for
effectively all real uses. Accept the edge case; do not build the isolate bridge.

Attach the actions to the countdown notification:

```dart
actions: const [
  AndroidNotificationAction('rest_add_15', '+15s', showsUserInterface: false, cancelNotification: false),
  AndroidNotificationAction('rest_skip', 'Skip', showsUserInterface: false, cancelNotification: false),
],
```

Confirm `AndroidNotificationAction`'s constructor before using it — it is declared at
`lib/src/platform_specifics/android/notification_details.dart:44` in the installed package, and its
first two arguments (`id`, `title`) are positional.

### Acceptance
- [ ] `start()` posts an ongoing notification immediately, on any lifecycle state.
- [ ] The Android countdown ticks without the Dart isolate running.
- [ ] `schedule()`'s existing behaviour and its other caller are unchanged.
- [ ] No new permission in `AndroidManifest.xml`. No new package in `pubspec.yaml`.

---

# TASK 6.2 — invert the controller, and give completion a state 🟠

### The bug (two of them)

**Inverted lifecycle logic.** `_syncBackgroundNotification` (line 187) **cancels** the notification
whenever the app is resumed and only posts while backgrounded. Once the notification is the ticking
countdown rather than a scheduled alarm, that is exactly backwards: the notification should be
posted for the whole rest period regardless of lifecycle.

**Lifecycle over-triggering.** `didChangeAppLifecycleState` (line 179) forwards **every** state,
including `AppLifecycleState.inactive` — which on iOS fires on every notification-centre pull, every
control-centre swipe, and every incoming call banner. Each one currently churns the notification.

**C2, no visual completion state.** `_finish()` (162) sets `running: false`, and `RestTimerBar`
line 15 then returns `SizedBox.shrink()`. The bar vanishes with a haptic. If the phone was in a
pocket, nothing on screen says rest finished or how long ago.

### Decided fix — controller

1. Replace `_syncBackgroundNotification` with `_postCountdownNotification()`: no `lifecycleState`
   parameter, no lifecycle gating. It posts `showRestCountdown` when
   `_notificationsAllowed && state.running && state.endTime != null`, and otherwise cancels.
2. Call it from `start()` (after the permission request, where the old call already is) and from
   `adjust()` (which already calls it at line 147 — the endTime changed, so the chronometer target
   must too).
3. `_finish()` (162): replace the `cancel(...)` at line 172 with `showRestComplete(...)`. That is
   C2's lock-screen half. Keep the `restTimerFeedbackProvider` haptic call at 175, and keep the
   existing `if (!state.running) return;` guard at 163 — a test depends on `_finish` being
   idempotent (`reaching zero fires feedback exactly once`).
4. `cancel()` (152) and `skip()` (150) keep cancelling the notification outright. Skipping a rest
   should not leave a "Rest complete" alert behind.
5. `didChangeAppLifecycleState` (179): act **only** on `paused` and `resumed`. On `resumed`, call
   `tick()` (it already does, line 182) and nothing else — the notification is already correct.
   Ignore `inactive`, `detached`, and `hidden` entirely.
6. Subscribe to `notifications.actionSelections` in `build()` (84), routing `'rest_add_15'` →
   `adjust(15)` and `'rest_skip'` → `skip()`. Cancel the subscription in the existing `ref.onDispose`
   at line 86. Guard both: if `!state.running`, no-op.

### Decided fix — `RestTimerState`

C2 needs the UI to tell "finished" apart from "never started". **Do not add a field** — the
distinction already exists in the data. `_finish()` keeps `sessionId` and clears `endTime`;
`cancel()` assigns `RestTimerState.idle`, whose `sessionId` is null. So add a getter next to
`display` (line 56):

```dart
/// Rest ran to zero and has not been acknowledged. Distinct from [RestTimerState.idle],
/// which is "no timer for this session at all" — `cancel()` and `skip()` produce idle.
bool get completed => !running && sessionId != null;
```

Add an `acknowledge()` method on the controller that assigns `RestTimerState.idle` and cancels the
notification, so the completion state can be dismissed.

### Decided fix — `RestTimerBar`

Replace line 15's blanket `SizedBox.shrink()`:

- `state.sessionId != sessionId` → `SizedBox.shrink()` (unchanged; another session's timer).
- `state.running` → today's countdown row (unchanged).
- `state.completed` → a **completion row**: `colors.primaryContainer`, "Rest complete", and a single
  "Done" button calling `acknowledge()`. Same height and padding as the countdown row so the layout
  does not jump.
- otherwise → `SizedBox.shrink()`.

Keep `FontFeature.tabularFigures()` (line 35) on any digits so they do not jitter.

### Acceptance
- [ ] The countdown notification is posted at `start()` and stays up while the app is foregrounded.
- [ ] An iOS notification-centre pull (`inactive`) does not cancel or repost anything.
- [ ] At zero, the notification becomes "Rest complete" and the bar shows a completion row.
- [ ] Skip cancels the notification and leaves no completion state.

---

# TASK 6.3 — a dedicated full-screen rest timer 🟡 (user-requested)

### Decided fix

New file `lib/features/session/rest_timer_screen.dart`. Push it from `_startRestTimer`
(`active_session_screen.dart:677`) **only when `start()` returned and the timer is actually
running** — respect `preferences.autoStartEnabled`, which already early-returns at line 683.

- **A full-screen route, not a dialog.** `Navigator.push(MaterialPageRoute(...))` so the system back
  gesture maps to minimise (pop), not kill.
- **Minimise ≠ dismiss.** A chevron-down pops the route; the timer keeps running and `RestTimerBar`
  is already mounted underneath at line 1032. A separate ✕ cancels the timer, confirming **only** if
  more than 30 s remain (under 30 s, just cancel — a confirm dialog costs more than the rest does).
- **Drive the animation from the data.** One `AnimationController` seeded from `state.endTime`, read
  through a single `AnimatedBuilder`. **Do not use `Timer.periodic` to rebuild text.** `endTime` is
  already authoritative on resume, so the ring resyncs after backgrounding for free.
- **Carry `FontFeature.tabularFigures()`** onto the large digits.
- **Show the next set**: exercise name, the set number that is coming, and the
  `ProgressionSuggestion.rationale` string. This is the one moment the user is idle and looking at
  the phone. `suggestNextSet` is already called on the session screen at line 1197 — pass the
  resulting `ProgressionSuggestion?` into the route rather than recomputing it here.
- **When the timer completes**, the screen shows the completion state in place and offers "Done"
  (calling `acknowledge()` and popping). Do not auto-pop — a route that vanishes on its own is the
  same disappearing-act as C2.
- **Every control on the full screen must also exist on the minimised bar** (−15s, +15s, Skip all
  already do). Do not let the new screen become the sole writer of anything — that is the F1 mistake
  repeated at the UI layer.

### Acceptance
- [ ] Completing a set with auto-start on opens the full screen.
- [ ] Back / chevron-down minimises; the bar keeps counting.
- [ ] ✕ with >30 s left confirms; with <30 s left it just cancels.
- [ ] No `Timer.periodic` anywhere in the new file.
- [ ] Backgrounding for 30 s and returning shows the correct remaining time, not a stale one.

---

# TESTS (required)

Extend `test/features/rest_timer_controller_test.dart`. Its `setUp` already overrides
`restTimerClockProvider`, `restTimerTickerFactoryProvider`, `restTimerFeedbackProvider`, and
`notificationServiceProvider` — reuse it.

**Extend `_FakeNotificationClient` (line 106)** to record posts, not just cancels: a list of
countdown posts (id + endTime), a list of completion posts, and a `StreamController<String>` backing
`actionSelections`. Every test below must be written so that it **fails against today's code** —
check that, do not assume it.

1. `start posts an ongoing countdown immediately` — catches C1. Today `start()` only reaches
   `schedule` when backgrounded, so this fails now.
2. `the countdown survives a resume` — send `AppLifecycleState.resumed`, assert the countdown was
   **not** cancelled. Today's line 196 cancels on resumed, so this fails now.
3. `inactive does not touch the notification` — send `AppLifecycleState.inactive`, assert no post and
   no cancel. Catches the iOS notification-centre churn.
4. `adjust reposts the countdown with the new end time` — assert the recorded `endTime` moved by 15 s.
5. `finish replaces the countdown with a completion notification` — catches C2's lock-screen half.
6. `skip cancels without posting a completion` — the inverse of 5.
7. `state.completed is true after finish and false after skip` — the getter's contract.
8. `a Skip action from the notification stops the timer` — push `'rest_skip'` into the fake's stream,
   pump, assert `running` is false.

Add a widget test for the bar's completion row (a new `test/features/rest_timer_bar_test.dart`, or
extend `test/features/set_completion_test.dart` if the harness there fits): pump `RestTimerBar` with
a completed state and assert "Rest complete" and the Done button render, and that a **different**
`sessionId` still renders nothing.

**Do not test wall-clock timing.** Everything above is driven by the injected clock and the fake
ticker. No `await Future.delayed(Duration(seconds: n))` in a test.

---

# PHASE 6 VERIFICATION

```bash
flutter analyze          # must be clean
flutter test             # must be green, and higher than 289
```

Then, because ground rule 6 applies to this whole phase:

```bash
flutter clean && flutter pub get && (cd ios && pod install)
```

Then **manually, on a real Android device, with the app backgrounded** — a green simulator build
proves nothing here:

1. Complete a set. The full-screen timer opens.
2. Minimise it, then background the app. The notification is in the shade **and on the lock screen**,
   counting down by itself.
3. Leave the phone alone through zero. The notification flips to "Rest complete" within a second or
   two of the actual zero — not a minute late.
4. Tap +15s on the notification while the app is backgrounded but alive. The countdown extends.
5. Reopen the app. The bar shows the completion state; Done dismisses it.
6. Pull down notification centre on iOS mid-rest. Nothing flickers or re-posts.

Record what you did and did **not** verify in `tasks/todo.md`, following the format of the Phase 5
entry already there. Be explicit about anything you skipped — an honest "not verified" is worth more
than an unverified checkmark. If you have no Android device, say so plainly; do not claim item 2–4.

---

# EXPLICIT DO NOTs

- **Do not** add a package. Everything here ships in `flutter_local_notifications ^22.1.0`, already
  in `pubspec.yaml` at line 18.
- **Do not** add `SCHEDULE_EXACT_ALARM` or any other permission to `AndroidManifest.xml`. The whole
  point of 6.1 is that a posted chronometer needs no alarm.
- **Do not** register `onDidReceiveBackgroundNotificationResponse` (see 6.1c — separate isolate,
  cannot reach the state, produces a button that lies).
- **Do not** attempt iOS Live Activities / ActivityKit. `NSSupportsLiveActivities` is absent from
  `Runner/Info.plist` and adding the `ActivityAttributes` struct, the extension view, and the method
  channel is its own phase. The `interruptionLevel: .timeSensitive` interim in 6.1b is the whole iOS
  scope of Phase 6.
- **Do not** change `schemaVersion` or `backup_service.dart`'s `_schemaVersion`.
- **Do not** change `NotificationService.schedule`'s `AndroidScheduleMode`, or `_details`'s
  signature — both are shared with the coaching reminders.
- **Do not** remove the `PlatformException` / `MissingPluginException` swallowing. A device that
  refuses notifications must still get a working in-app timer.
- **Do not** touch `_remainingAt` or the endTime-is-authoritative design. The audit reviewed it
  (C3, line 155) and found no issue.
- **Do not** use `Timer.periodic` to drive the new full-screen UI.
- **Do not** add network calls, analytics, crash reporting, or accounts. The local-only guarantee is
  the product.

---

# KNOWN, NOT IN SCOPE

Four small items from the Phase 5 review are logged at the end of `tasks/todo.md`. **Leave them
alone** — they are Phase 7 material and would muddy this diff:

1. `active_session_screen.dart` fires set move/insert through `unawaited(...)` with no error surface.
2. `SetRepository.insertSetAt` never passes `isWarmup`.
3. `SetRow`'s `PopupMenuButton` passes no `constraints`.
4. "Set details" is two taps where it was one.
