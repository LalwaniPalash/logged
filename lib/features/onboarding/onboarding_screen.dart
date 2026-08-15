import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_icons.dart';
import '../../core/domain/training_goal.dart';
import '../../data/providers.dart';
import '../home/home_shell.dart';

class OnboardingGate extends ConsumerStatefulWidget {
  const OnboardingGate({super.key, this.home = const HomeShell()});

  final Widget home;

  @override
  ConsumerState<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends ConsumerState<OnboardingGate> {
  late Future<bool> _complete;

  @override
  void initState() {
    super.initState();
    _complete = _readSafely();
  }

  Future<bool> _readSafely() async {
    try {
      return await ref
          .read(settingsRepositoryProvider)
          .readOnboardingComplete();
    } catch (error, stackTrace) {
      // A first-run preference must never prevent the workout database and
      // home UI from being usable.
      debugPrint('Could not read onboarding preference: $error\n$stackTrace');
      return true;
    }
  }

  Future<void> _finish() async {
    try {
      await ref.read(settingsRepositoryProvider).setOnboardingComplete();
    } catch (error, stackTrace) {
      debugPrint('Could not save onboarding preference: $error\n$stackTrace');
    }
    if (mounted) {
      setState(() {
        _complete = Future.value(true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _complete,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _OnboardingLoading();
        }
        if (snapshot.data ?? true) return widget.home;
        return OnboardingScreen(onComplete: _finish);
      },
    );
  }
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  final Future<void> Function() onComplete;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  var _index = 0;
  var _saving = false;
  var _goal = TrainingGoal.build;
  var _trainingDays = _defaultTrainingDays;

  static const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _defaultTrainingDays = {1, 3, 5};

  static const _pages = [
    _OnboardingPageData(
      icon: AppIcons.body,
      eyebrow: 'WELCOME TO LOGGED',
      title: 'Your training stays yours.',
      body:
          'No account, no cloud, no analytics. Every workout lives privately on this device.',
    ),
    _OnboardingPageData(
      icon: AppIcons.swap,
      eyebrow: 'LOG IT AS YOU LIFT IT',
      title: 'Units live on each exercise.',
      body:
          'Tap kg or lb right on a set. Per-hand and each-side values stay exactly as entered.',
    ),
    _OnboardingPageData(
      icon: AppIcons.cube,
      eyebrow: 'MEET YOUR COACH',
      title: 'Every working set lights up your body.',
      body:
          'The live 3D muscle model reacts this week, helping you see what is trained and what needs attention.',
    ),
    _OnboardingPageData(
      icon: AppIcons.calendarCheck,
      eyebrow: 'YOUR WEEKLY RHYTHM',
      title: 'Which days do you train?',
      body:
          'Pick your usual training days. Logged uses the other days as rest days so your streak matches your split.',
      kind: _OnboardingPageKind.trainingDays,
    ),
    _OnboardingPageData(
      icon: AppIcons.target,
      eyebrow: 'YOUR COACHING PROFILE',
      title: 'What are you training for?',
      body: 'Choose an intent now. You can change it any time in Settings.',
      kind: _OnboardingPageKind.goal,
    ),
  ];

  Future<void> _complete() async {
    if (_saving) return;
    setState(() => _saving = true);
    await ref.read(settingsRepositoryProvider).setTrainingGoal(_goal);
    await ref
        .read(settingsRepositoryProvider)
        .setRestWeekdays(_restWeekdaysForTrainingDays(_trainingDays));
    await widget.onComplete();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == _pages.length - 1;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12, top: 4),
                child: TextButton(
                  onPressed: _saving ? null : _complete,
                  child: const Text('Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) => _OnboardingPage(
                  data: _pages[index],
                  goal: _pages[index].kind == _OnboardingPageKind.goal
                      ? _goal
                      : null,
                  onGoalChanged: _pages[index].kind == _OnboardingPageKind.goal
                      ? (goal) => setState(() => _goal = goal)
                      : null,
                  trainingDays:
                      _pages[index].kind == _OnboardingPageKind.trainingDays
                      ? _trainingDays
                      : null,
                  onTrainingDaysChanged:
                      _pages[index].kind == _OnboardingPageKind.trainingDays
                      ? (day) => setState(() {
                          final next = {..._trainingDays};
                          if (!next.remove(day)) next.add(day);
                          _trainingDays = next;
                        })
                      : null,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < _pages.length; index++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: index == _index ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: index == _index
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _saving
                      ? null
                      : last
                      ? _complete
                      : () => _controller.nextPage(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                        ),
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(last ? 'Get started' : 'Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.data,
    this.goal,
    this.onGoalChanged,
    this.trainingDays,
    this.onTrainingDaysChanged,
  });

  final _OnboardingPageData data;
  final TrainingGoal? goal;
  final ValueChanged<TrainingGoal>? onGoalChanged;
  final Set<int>? trainingDays;
  final ValueChanged<int>? onTrainingDaysChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 132,
            width: 132,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(
              data.icon,
              size: 60,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 36),
          Text(
            data.eyebrow,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            data.body,
            textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          if (trainingDays != null) ...[
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var weekday = 1; weekday <= 7; weekday++)
                  _OnboardingDayToggle(
                    label: _OnboardingScreenState._weekdayLabels[weekday - 1],
                    selected: trainingDays!.contains(weekday),
                    onTap: () => onTrainingDaysChanged?.call(weekday),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Default: Mon, Wed, Fri. You can change this any time in Settings.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (goal != null) ...[
            const SizedBox(height: 24),
            SegmentedButton<TrainingGoal>(
              segments: [
                for (final value in TrainingGoal.values)
                  ButtonSegment(value: value, label: Text(value.label)),
              ],
              selected: {goal!},
              onSelectionChanged: (values) =>
                  onGoalChanged?.call(values.single),
            ),
            const SizedBox(height: 10),
            Text(
              switch (goal!) {
                TrainingGoal.maintain =>
                  'Lower volume targets and conservative progression.',
                TrainingGoal.build =>
                  'Balanced growth, progression, and recovery guidance.',
                TrainingGoal.push =>
                  'Higher volume targets with more aggressive progression.',
              },
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OnboardingLoading extends StatelessWidget {
  const _OnboardingLoading();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: SizedBox.square(
        dimension: 28,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
    ),
  );
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.body,
    this.kind = _OnboardingPageKind.info,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;
  final _OnboardingPageKind kind;
}

enum _OnboardingPageKind { info, trainingDays, goal }

class _OnboardingDayToggle extends StatelessWidget {
  const _OnboardingDayToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        width: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHigh,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            color: selected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

Set<int> _restWeekdaysForTrainingDays(Set<int> trainingDays) => {
  for (var weekday = 1; weekday <= 7; weekday++)
    if (!trainingDays.contains(weekday)) weekday,
};
