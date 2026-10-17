import 'package:flutter/material.dart';

import '../01_design_system/app_tokens.dart';

/// One page of an [OnboardingPager].
class OnboardingSlide {
  const OnboardingSlide({
    required this.title,
    required this.body,
    this.icon,
    this.image,
  });

  final String title;
  final String body;

  /// Shown large above the title when [image] is null.
  final IconData? icon;

  /// Any widget (an `Image.asset`, a Lottie animation…). Wins over [icon].
  final Widget? image;
}

/// A swipeable first-run walkthrough: slides, animated page dots, Skip, and a
/// Next button that becomes "Get started" on the last slide.
///
/// Source: Couple `onboarding_walkthrough.dart` — the smallest of the four
/// apps' onboarding flows and the only one not tied to app-specific data.
/// The dot indicator grows into a pill for the current page, as in the
/// StudyBuddies and Cookly onboarding screens.
///
/// Persist "seen" yourself in [onFinish] (e.g. with `PrefsStore`) and ask for
/// permissions there, in context, rather than on bare launch.
///
/// ```dart
/// OnboardingPager(
///   slides: const [
///     OnboardingSlide(icon: Icons.bolt, title: 'Fast', body: 'Capture ideas in seconds.'),
///     OnboardingSlide(icon: Icons.cloud_done, title: 'Synced', body: 'On every device.'),
///   ],
///   onFinish: () async {
///     await prefs.setBool('onboarding_done', true);
///     if (context.mounted) Navigator.of(context).pushReplacement(…);
///   },
/// )
/// ```
class OnboardingPager extends StatefulWidget {
  const OnboardingPager({
    super.key,
    required this.slides,
    required this.onFinish,
    this.skipLabel = 'Skip',
    this.nextLabel = 'Next',
    this.doneLabel = 'Get started',
  }) : assert(slides.length > 0);

  final List<OnboardingSlide> slides;

  /// Called by both Skip and the final button.
  final VoidCallback onFinish;
  final String skipLabel;
  final String nextLabel;
  final String doneLabel;

  @override
  State<OnboardingPager> createState() => _OnboardingPagerState();
}

class _OnboardingPagerState extends State<OnboardingPager> {
  final _controller = PageController();
  int _page = 0;

  bool get _isLast => _page == widget.slides.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      widget.onFinish();
    } else {
      _controller.nextPage(duration: Motion.medium, curve: Motion.standard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: AnimatedOpacity(
                opacity: _isLast ? 0 : 1,
                duration: Motion.short,
                child: TextButton(
                  onPressed: _isLast ? null : widget.onFinish,
                  child: Text(widget.skipLabel),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.slides.length,
                onPageChanged: (page) => setState(() => _page = page),
                itemBuilder: (context, index) {
                  final slide = widget.slides[index];
                  return Padding(
                    padding: const EdgeInsets.all(Gap.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        slide.image ??
                            Icon(slide.icon, size: 80, color: scheme.primary),
                        const SizedBox(height: Gap.lg),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: Gap.md - 4),
                        Text(
                          slide.body,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Semantics(
              label: 'Page ${_page + 1} of ${widget.slides.length}',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.slides.length; i++)
                    AnimatedContainer(
                      duration: Motion.short,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? scheme.primary
                            : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(_isLast ? widget.doneLabel : widget.nextLabel),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
