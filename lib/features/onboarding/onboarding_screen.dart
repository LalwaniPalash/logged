import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_icons.dart';
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

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  final Future<void> Function() onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  var _index = 0;
  var _saving = false;

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
      icon: AppIcons.play,
      eyebrow: 'READY WHEN YOU ARE',
      title: 'Walk in and start.',
      body:
          'Begin an empty workout and add exercises as you go, or launch a full day from a template.',
    ),
  ];

  Future<void> _complete() async {
    if (_saving) return;
    setState(() => _saving = true);
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
                itemBuilder: (context, index) =>
                    _OnboardingPage(data: _pages[index]),
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
  const _OnboardingPage({required this.data});

  final _OnboardingPageData data;

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
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;
}
