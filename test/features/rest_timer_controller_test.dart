import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logged/core/services/notification_service.dart';
import 'package:logged/data/providers.dart';
import 'package:logged/features/session/rest_timer_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  late _FakeNotificationClient notifications;
  late int feedbackCount;
  late ProviderContainer container;

  setUp(() {
    now = DateTime(2026, 7, 23, 18);
    notifications = _FakeNotificationClient();
    feedbackCount = 0;
    container = ProviderContainer(
      overrides: [
        restTimerClockProvider.overrideWithValue(() => now),
        restTimerTickerFactoryProvider.overrideWithValue((_) => _FakeTicker()),
        restTimerFeedbackProvider.overrideWithValue(() async {
          feedbackCount++;
        }),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(notifications.actions.close);
  });

  test('ticks from the absolute end time and formats the countdown', () async {
    final controller = container.read(restTimerControllerProvider.notifier);
    await controller.start(
      sessionId: 7,
      seconds: 90,
      notificationsEnabled: false,
    );

    expect(container.read(restTimerControllerProvider).display, '1:30');
    now = now.add(const Duration(seconds: 31));
    controller.tick();

    final state = container.read(restTimerControllerProvider);
    expect(state.remainingSeconds, 59);
    expect(state.display, '0:59');
    expect(state.running, isTrue);
  });

  test('adjust and skip update state without a real timer', () async {
    final controller = container.read(restTimerControllerProvider.notifier);
    await controller.start(
      sessionId: 1,
      seconds: 60,
      notificationsEnabled: false,
    );

    await controller.adjust(15);
    expect(container.read(restTimerControllerProvider).remainingSeconds, 75);
    await controller.adjust(-15);
    expect(container.read(restTimerControllerProvider).remainingSeconds, 60);
    await controller.skip();
    expect(container.read(restTimerControllerProvider).running, isFalse);
    expect(notifications.cancelled, contains(1001));
  });

  test('total tracks the original rest, adjusted alongside +15/-15', () async {
    final controller = container.read(restTimerControllerProvider.notifier);
    await controller.start(
      sessionId: 1,
      seconds: 60,
      notificationsEnabled: false,
    );
    expect(container.read(restTimerControllerProvider).totalSeconds, 60);

    await controller.adjust(15);
    expect(container.read(restTimerControllerProvider).totalSeconds, 75);

    now = now.add(const Duration(seconds: 30));
    controller.tick();
    // Ticking down must not touch the total — only remainingSeconds moves.
    expect(container.read(restTimerControllerProvider).totalSeconds, 75);
  });

  test('start posts an ongoing countdown immediately', () async {
    final controller = container.read(restTimerControllerProvider.notifier);
    await controller.start(
      sessionId: 42,
      seconds: 75,
      notificationsEnabled: true,
    );

    expect(notifications.countdownPosts, hasLength(1));
    expect(
      notifications.countdownPosts.single,
      _CountdownPost(
        id: NotificationService.restTimerNotificationId,
        endTime: DateTime(2026, 7, 23, 18, 1, 15),
      ),
    );
  });

  test('the countdown survives a resume', () async {
    final controller = container.read(restTimerControllerProvider.notifier);
    await controller.start(
      sessionId: 3,
      seconds: 45,
      notificationsEnabled: true,
    );

    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);

    expect(notifications.cancelled, isEmpty);
    expect(notifications.countdownPosts, hasLength(1));
  });

  test('inactive does not touch the notification', () async {
    final controller = container.read(restTimerControllerProvider.notifier);
    await controller.start(
      sessionId: 4,
      seconds: 45,
      notificationsEnabled: true,
    );
    final postCount = notifications.countdownPosts.length;
    final cancelCount = notifications.cancelled.length;

    controller.didChangeAppLifecycleState(AppLifecycleState.inactive);

    expect(notifications.countdownPosts, hasLength(postCount));
    expect(notifications.cancelled, hasLength(cancelCount));
  });

  test('adjust reposts the countdown with the new end time', () async {
    final controller = container.read(restTimerControllerProvider.notifier);
    await controller.start(
      sessionId: 5,
      seconds: 60,
      notificationsEnabled: true,
    );

    await controller.adjust(15);

    expect(notifications.countdownPosts, hasLength(2));
    expect(
      notifications.countdownPosts.last,
      _CountdownPost(
        id: NotificationService.restTimerNotificationId,
        endTime: DateTime(2026, 7, 23, 18, 1, 15),
      ),
    );
  });

  test('reaching zero fires feedback exactly once', () async {
    final controller = container.read(restTimerControllerProvider.notifier);
    await controller.start(
      sessionId: 2,
      seconds: 10,
      notificationsEnabled: false,
    );

    now = now.add(const Duration(seconds: 10));
    controller.tick();
    await Future<void>.delayed(Duration.zero);
    controller.tick();

    expect(container.read(restTimerControllerProvider).running, isFalse);
    expect(container.read(restTimerControllerProvider).remainingSeconds, 0);
    expect(feedbackCount, 1);
  });

  test(
    'finish replaces the countdown with a completion notification',
    () async {
      final controller = container.read(restTimerControllerProvider.notifier);
      await controller.start(
        sessionId: 6,
        seconds: 10,
        notificationsEnabled: true,
      );

      now = now.add(const Duration(seconds: 10));
      controller.tick();
      await Future<void>.delayed(Duration.zero);

      expect(
        notifications.completionPosts,
        contains(NotificationService.restTimerNotificationId),
      );
      expect(container.read(restTimerControllerProvider).completed, isTrue);
    },
  );

  test('skip cancels without posting a completion', () async {
    final controller = container.read(restTimerControllerProvider.notifier);
    await controller.start(
      sessionId: 8,
      seconds: 30,
      notificationsEnabled: true,
    );

    await controller.skip();

    expect(
      notifications.cancelled,
      contains(NotificationService.restTimerNotificationId),
    );
    expect(notifications.completionPosts, isEmpty);
  });

  test('notifications disabled posts nothing at zero', () async {
    final controller = container.read(restTimerControllerProvider.notifier);
    await controller.start(
      sessionId: 12,
      seconds: 30,
      notificationsEnabled: false,
    );
    now = now.add(const Duration(seconds: 31));
    controller.tick();
    await Future<void>.delayed(Duration.zero);

    expect(container.read(restTimerControllerProvider).completed, isTrue);
    expect(feedbackCount, 1);
    expect(notifications.completionPosts, isEmpty);
    expect(notifications.countdownPosts, isEmpty);
  });

  test('the completed state clears itself after the dismiss window', () async {
    final controller = container.read(restTimerControllerProvider.notifier);
    await controller.start(
      sessionId: 21,
      seconds: 30,
      notificationsEnabled: true,
    );
    now = now.add(const Duration(seconds: 31));
    controller.tick();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(restTimerControllerProvider).completed, isTrue);

    // Still inside the window.
    now = now.add(RestTimerController.autoDismissAfter - const Duration(seconds: 1));
    controller.tick();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(restTimerControllerProvider).completed, isTrue);

    now = now.add(const Duration(seconds: 2));
    controller.tick();
    await Future<void>.delayed(Duration.zero);

    final state = container.read(restTimerControllerProvider);
    expect(state.completed, isFalse);
    expect(state.sessionId, isNull);
    expect(
      notifications.cancelled,
      contains(NotificationService.restTimerNotificationId),
    );
  });

  test('state.completed is true after finish and false after skip', () async {
    final controller = container.read(restTimerControllerProvider.notifier);
    await controller.start(
      sessionId: 9,
      seconds: 5,
      notificationsEnabled: true,
    );

    now = now.add(const Duration(seconds: 5));
    controller.tick();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(restTimerControllerProvider).completed, isTrue);

    await controller.acknowledge();
    expect(container.read(restTimerControllerProvider).completed, isFalse);

    await controller.start(
      sessionId: 9,
      seconds: 5,
      notificationsEnabled: true,
    );
    await controller.skip();
    expect(container.read(restTimerControllerProvider).completed, isFalse);
  });

  test('leaving another session cannot cancel the active timer', () async {
    final controller = container.read(restTimerControllerProvider.notifier);
    await controller.start(
      sessionId: 12,
      seconds: 90,
      notificationsEnabled: false,
    );

    await controller.cancel(sessionId: 99);
    expect(container.read(restTimerControllerProvider).running, isTrue);

    await controller.cancel(sessionId: 12);
    expect(container.read(restTimerControllerProvider).running, isFalse);
  });

  test('a Skip action from the notification stops the timer', () async {
    final controller = container.read(restTimerControllerProvider.notifier);
    await controller.start(
      sessionId: 13,
      seconds: 60,
      notificationsEnabled: true,
    );

    notifications.actions.add('rest_skip');
    await Future<void>.delayed(Duration.zero);

    expect(container.read(restTimerControllerProvider).running, isFalse);
    expect(notifications.completionPosts, isEmpty);
  });
}

class _FakeTicker implements RestTimerTicker {
  @override
  void cancel() {}
}

class _FakeNotificationClient implements NotificationClient {
  final cancelled = <int>[];
  final countdownPosts = <_CountdownPost>[];
  final completionPosts = <int>[];
  final actions = StreamController<String>.broadcast();

  @override
  Stream<String> get actionSelections => actions.stream;

  @override
  Future<void> cancel(int id) async => cancelled.add(id);

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> showRestComplete({
    required int id,
    required String title,
    required String body,
  }) async {
    completionPosts.add(id);
  }

  @override
  Future<void> showRestCountdown({
    required int id,
    required DateTime endTime,
    required String title,
    required String body,
  }) async {
    countdownPosts.add(_CountdownPost(id: id, endTime: endTime));
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
  }) async {}

  @override
  Future<void> scheduleWeekly({
    required int id,
    required DateTime firstAt,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
  }) async {}

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
  }) async {}
}

class _CountdownPost {
  const _CountdownPost({required this.id, required this.endTime});

  final int id;
  final DateTime endTime;

  @override
  bool operator ==(Object other) {
    return other is _CountdownPost &&
        other.id == id &&
        other.endTime == endTime;
  }

  @override
  int get hashCode => Object.hash(id, endTime);
}
