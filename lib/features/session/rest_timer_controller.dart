import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/notification_service.dart';
import '../../data/providers.dart';

typedef RestTimerClock = DateTime Function();
typedef RestTimerTick = void Function();

abstract interface class RestTimerTicker {
  void cancel();
}

class _PeriodicRestTimerTicker implements RestTimerTicker {
  _PeriodicRestTimerTicker(RestTimerTick tick)
    : _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}

final restTimerClockProvider = Provider<RestTimerClock>((ref) => DateTime.now);
final restTimerTickerFactoryProvider =
    Provider<RestTimerTicker Function(RestTimerTick)>((ref) {
      return _PeriodicRestTimerTicker.new;
    });
final restTimerFeedbackProvider = Provider<Future<void> Function()>((ref) {
  return HapticFeedback.heavyImpact;
});

final restTimerControllerProvider =
    NotifierProvider<RestTimerController, RestTimerState>(
      RestTimerController.new,
    );

class RestTimerState {
  const RestTimerState({
    this.sessionId,
    this.remainingSeconds = 0,
    this.running = false,
    this.endTime,
  });

  final int? sessionId;
  final int remainingSeconds;
  final bool running;
  final DateTime? endTime;

  static const idle = RestTimerState();

  String get display {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  RestTimerState copyWith({
    int? sessionId,
    int? remainingSeconds,
    bool? running,
    DateTime? endTime,
    bool clearEndTime = false,
  }) => RestTimerState(
    sessionId: sessionId ?? this.sessionId,
    remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    running: running ?? this.running,
    endTime: clearEndTime ? null : endTime ?? this.endTime,
  );
}

/// App-scoped countdown. The absolute [RestTimerState.endTime], rather than the
/// number of elapsed Dart ticks, is authoritative when the app resumes.
class RestTimerController extends Notifier<RestTimerState>
    with WidgetsBindingObserver {
  RestTimerTicker? _ticker;
  bool _notificationsAllowed = false;

  @override
  RestTimerState build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _ticker?.cancel();
    });
    return RestTimerState.idle;
  }

  Future<bool> start({
    required int sessionId,
    required int seconds,
    required bool notificationsEnabled,
  }) async {
    if (seconds <= 0) {
      await cancel();
      return false;
    }
    _ticker?.cancel();
    final now = ref.read(restTimerClockProvider)();
    state = RestTimerState(
      sessionId: sessionId,
      remainingSeconds: seconds,
      running: true,
      endTime: now.add(Duration(seconds: seconds)),
    );
    _ticker = ref.read(restTimerTickerFactoryProvider)(tick);

    _notificationsAllowed = notificationsEnabled;
    if (notificationsEnabled) {
      _notificationsAllowed = await ref
          .read(notificationServiceProvider)
          .requestPermission();
    }
    await _syncBackgroundNotification();
    return _notificationsAllowed;
  }

  void tick() {
    if (!state.running || state.endTime == null) return;
    final remaining = _remainingAt(
      now: ref.read(restTimerClockProvider)(),
      endTime: state.endTime!,
    );
    if (remaining <= 0) {
      unawaited(_finish());
      return;
    }
    state = state.copyWith(remainingSeconds: remaining);
  }

  Future<void> adjust(int seconds) async {
    if (!state.running || state.endTime == null) return;
    final next = state.endTime!.add(Duration(seconds: seconds));
    final remaining = _remainingAt(
      now: ref.read(restTimerClockProvider)(),
      endTime: next,
    );
    if (remaining <= 0) {
      await _finish();
      return;
    }
    state = state.copyWith(endTime: next, remainingSeconds: remaining);
    await _syncBackgroundNotification();
  }

  Future<void> skip() => cancel();

  Future<void> cancel({int? sessionId}) async {
    if (sessionId != null && state.sessionId != sessionId) return;
    _ticker?.cancel();
    _ticker = null;
    state = RestTimerState.idle;
    await ref
        .read(notificationServiceProvider)
        .cancel(NotificationService.restTimerNotificationId);
  }

  Future<void> _finish() async {
    if (!state.running) return;
    _ticker?.cancel();
    _ticker = null;
    final sessionId = state.sessionId;
    state = RestTimerState(
      sessionId: sessionId,
      remainingSeconds: 0,
      running: false,
    );
    await ref
        .read(notificationServiceProvider)
        .cancel(NotificationService.restTimerNotificationId);
    await ref.read(restTimerFeedbackProvider)();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!this.state.running) return;
    if (state == AppLifecycleState.resumed) {
      tick();
    }
    unawaited(_syncBackgroundNotification(lifecycleState: state));
  }

  Future<void> _syncBackgroundNotification({
    AppLifecycleState? lifecycleState,
  }) async {
    final notifications = ref.read(notificationServiceProvider);
    final lifecycle = lifecycleState ?? WidgetsBinding.instance.lifecycleState;
    if (!_notificationsAllowed ||
        !state.running ||
        state.endTime == null ||
        lifecycle == null ||
        lifecycle == AppLifecycleState.resumed) {
      await notifications.cancel(NotificationService.restTimerNotificationId);
      return;
    }
    await notifications.schedule(
      id: NotificationService.restTimerNotificationId,
      at: state.endTime!,
      title: 'Rest complete',
      body: 'Time for your next set.',
      channelId: 'rest_timer',
      channelName: 'Rest timer',
    );
  }
}

int _remainingAt({required DateTime now, required DateTime endTime}) {
  final milliseconds = endTime.difference(now).inMilliseconds;
  if (milliseconds <= 0) return 0;
  return (milliseconds / Duration.millisecondsPerSecond).ceil();
}
