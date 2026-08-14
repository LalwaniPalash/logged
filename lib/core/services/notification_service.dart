import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Narrow, injectable notification surface used by coaching features.
abstract interface class NotificationClient {
  Future<void> init();

  Future<bool> requestPermission();

  /// Action ids from notification buttons, e.g. 'rest_add_15', 'rest_skip'.
  /// Foreground-isolate only — see [NotificationService.init].
  Stream<String> get actionSelections;

  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
  });

  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
  });

  /// Posts (or updates) the ongoing rest countdown. Android renders a
  /// system-ticked chronometer counting down to [endTime]; iOS has no
  /// equivalent, so it schedules a one-shot alert at [endTime] instead.
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

  Future<void> cancel(int id);
}

/// Keeps plugin and platform-channel details out of widgets and controllers.
///
/// Permission denial and unsupported platforms deliberately become no-ops:
/// the in-app coaching feature must continue to work without notifications.
class NotificationService implements NotificationClient {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const restTimerNotificationId = 1001;

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<String> _actionSelections =
      StreamController<String>.broadcast();
  bool _initialized = false;

  /// Android keeps only the alpha channel of a small icon and paints the result
  /// white, so the launcher icon (an opaque square) showed up as a blank block
  /// in the shade. This is a transparent-backgrounded silhouette of the mark.
  static const _androidNotificationIcon = 'ic_stat_logged';

  /// Tints the silhouette and the app name in the shade. Matches the streak
  /// amber in [AppTheme] rather than the mark's green, which is the accent the
  /// rest of the app actually leads with.
  static const _androidNotificationAccent = Color(0xFFC9821F);

  static const _androidInitialization = AndroidInitializationSettings(
    _androidNotificationIcon,
  );
  static const _darwinInitialization = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
    defaultPresentAlert: false,
    defaultPresentBanner: false,
    defaultPresentList: false,
    defaultPresentSound: false,
  );

  @override
  Stream<String> get actionSelections => _actionSelections.stream;

  @override
  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    try {
      tz_data.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: _androidInitialization,
          iOS: _darwinInitialization,
        ),
        onDidReceiveNotificationResponse: (response) {
          final actionId = response.actionId;
          if (actionId == null || actionId.isEmpty) return;
          _actionSelections.add(actionId);
        },
        // Do not register the background callback here: it runs in a separate
        // Dart isolate with no access to the Riverpod container or live timer
        // state, so +15s / Skip would compile, run, and silently fail to
        // adjust the timer the user is looking at. If the app process has been
        // killed, those actions can only bring the app back; they cannot
        // mutate the timer without an isolate bridge, which is out of scope.
      );
      _initialized = true;
    } on PlatformException catch (error) {
      debugPrint('Notification initialization unavailable: $error');
    } on MissingPluginException catch (error) {
      debugPrint('Notification plugin unavailable: $error');
    } on ArgumentError catch (error) {
      // The app ships only on Android/iOS, but desktop-hosted tests and tooling
      // can still instantiate this service.
      debugPrint('Notifications unsupported on this platform: $error');
    }
  }

  @override
  Future<bool> requestPermission() async {
    await init();
    if (!_initialized) return false;
    try {
      return switch (defaultTargetPlatform) {
        TargetPlatform.android =>
          await _plugin
                  .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin
                  >()
                  ?.requestNotificationsPermission() ??
              true,
        TargetPlatform.iOS =>
          await _plugin
                  .resolvePlatformSpecificImplementation<
                    IOSFlutterLocalNotificationsPlugin
                  >()
                  ?.requestPermissions(alert: true, sound: true) ??
              false,
        _ => false,
      };
    } on PlatformException catch (error) {
      debugPrint('Notification permission unavailable: $error');
      return false;
    }
  }

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
  }) async {
    await init();
    if (!_initialized) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _details(channelId, channelName),
      );
    } on PlatformException catch (error) {
      debugPrint('Could not show notification: $error');
    }
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
  }) async {
    await init();
    if (!_initialized || !at.isAfter(DateTime.now())) return;
    try {
      // UTC preserves the exact instant without adding another native plugin
      // merely to discover the device's IANA timezone.
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
        title: title,
        body: body,
        notificationDetails: _details(channelId, channelName),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } on PlatformException catch (error) {
      debugPrint('Could not schedule notification: $error');
    }
  }

  @override
  Future<void> showRestCountdown({
    required int id,
    required DateTime endTime,
    required String title,
    required String body,
  }) async {
    await init();
    if (!_initialized) return;
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          await _plugin.show(
            id: id,
            title: title,
            body: body,
            notificationDetails: _countdownDetails(endTime),
          );
        case TargetPlatform.iOS:
          if (!endTime.isAfter(DateTime.now())) return;
          await _plugin.zonedSchedule(
            id: id,
            scheduledDate: tz.TZDateTime.from(endTime.toUtc(), tz.UTC),
            title: title,
            body: body,
            notificationDetails: _completionDetails('rest_timer', 'Rest timer'),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
        default:
          return;
      }
    } on PlatformException catch (error) {
      debugPrint('Could not show rest countdown: $error');
    }
  }

  @override
  Future<void> showRestComplete({
    required int id,
    required String title,
    required String body,
  }) async {
    await init();
    if (!_initialized) return;
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
        case TargetPlatform.iOS:
          await _plugin.show(
            id: id,
            title: title,
            body: body,
            notificationDetails: _completionDetails('rest_timer', 'Rest timer'),
          );
        default:
          return;
      }
    } on PlatformException catch (error) {
      debugPrint('Could not show rest completion notification: $error');
    }
  }

  @override
  Future<void> cancel(int id) async {
    await init();
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: id);
    } on PlatformException catch (error) {
      debugPrint('Could not cancel notification: $error');
    }
  }

  NotificationDetails _countdownDetails(DateTime endTime) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          'rest_timer_progress',
          'Rest timer countdown',
          channelDescription: 'Logged rest timer countdown',
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
          icon: _androidNotificationIcon,
          color: _androidNotificationAccent,
          colorized: false,
          ongoing: true,
          silent: true,
          onlyAlertOnce: true,
          when: endTime.millisecondsSinceEpoch,
          usesChronometer: true,
          chronometerCountDown: true,
          category: AndroidNotificationCategory.stopwatch,
          actions: const [
            AndroidNotificationAction(
              'rest_add_15',
              '+15s',
              showsUserInterface: false,
              cancelNotification: false,
            ),
            AndroidNotificationAction(
              'rest_skip',
              'Skip',
              showsUserInterface: false,
              cancelNotification: false,
            ),
          ],
        ),
      );

  NotificationDetails _completionDetails(
    String channelId,
    String channelName,
  ) => NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Logged workout reminders',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      icon: _androidNotificationIcon,
      color: _androidNotificationAccent,
      colorized: false,
    ),
    iOS: const DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    ),
  );

  NotificationDetails _details(String channelId, String channelName) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: 'Logged workout reminders',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
          // Set per-notification as well as at init: a notification posted
          // before init ran would otherwise fall back to the launcher icon.
          icon: _androidNotificationIcon,
          color: _androidNotificationAccent,
          colorized: false,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: true,
        ),
      );
}
