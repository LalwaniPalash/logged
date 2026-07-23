import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Narrow, injectable notification surface used by coaching features.
abstract interface class NotificationClient {
  Future<void> init();

  Future<bool> requestPermission();

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
  bool _initialized = false;

  static const _androidInitialization = AndroidInitializationSettings(
    '@mipmap/ic_launcher',
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
  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    try {
      tz_data.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: _androidInitialization,
          iOS: _darwinInitialization,
        ),
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
  Future<void> cancel(int id) async {
    await init();
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: id);
    } on PlatformException catch (error) {
      debugPrint('Could not cancel notification: $error');
    }
  }

  NotificationDetails _details(String channelId, String channelName) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: 'Logged workout reminders',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: true,
        ),
      );
}
