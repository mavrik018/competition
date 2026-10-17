import 'dart:async';

import 'package:flutter/material.dart';

import '../01_design_system/app_tokens.dart';

/// One step of a long-running operation.
@immutable
class ProgressStep {
  const ProgressStep({required this.key, required this.label});

  /// Identifies the step, e.g. a `processing_stage` value from the server.
  final String key;

  /// What the user reads — a short present-tense phrase: "Reading your PDF".
  final String label;
}

/// Shows a long operation as a checklist of real steps plus a running clock,
/// instead of one indeterminate spinner.
///
/// Source: StudyBuddies `AiProgressView` / `AiProgressOverlay`
/// (`core/widgets/ai_progress.dart`). The source's reasoning is kept: a
/// minute-long AI job behind a bare spinner is indistinguishable from a
/// hang, and a clock is the cheapest proof of life. Nothing advances on a
/// timer — steps move only when [currentKey] changes. Generalised from
/// upload bytes to any 0..1 [progress] with a caption.
///
/// ```dart
/// StepProgressView(
///   steps: const [
///     ProgressStep(key: 'upload', label: 'Uploading your file'),
///     ProgressStep(key: 'read', label: 'Reading the document'),
///     ProgressStep(key: 'write', label: 'Writing your summary'),
///   ],
///   currentKey: job.stage,
///   progress: job.stage == 'upload' ? job.uploadFraction : null,
///   expectation: 'Usually takes about a minute.',
/// )
/// ```
class StepProgressView extends StatefulWidget {
  const StepProgressView({
    super.key,
    required this.steps,
    required this.currentKey,
    this.progress,
    this.progressLabel,
    this.expectation,
    this.showClock = true,
  });

  final List<ProgressStep> steps;

  /// The running step. Earlier steps show as done. An unknown or null key
  /// means "started, nothing reported yet", so the first step is active.
  final String? currentKey;

  /// Determinate progress (0..1) for the current step, if it is measurable.
  final double? progress;

  /// Caption under the bar, e.g. "3.2 MB of 8.0 MB".
  final String? progressLabel;

  /// One honest line about how long this usually takes.
  final String? expectation;
  final bool showClock;

  @override
  State<StepProgressView> createState() => _StepProgressViewState();
}

class _StepProgressViewState extends State<StepProgressView> {
  final _startedAt = DateTime.now();
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.showClock) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _elapsed = DateTime.now().difference(_startedAt));
        }
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final current = currentStepIndex(widget.steps, widget.currentKey);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < widget.steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.md - 2),
            child: _StepRow(
              label: widget.steps[i].label,
              done: i < current,
              active: i == current,
              progress: i == current ? widget.progress : null,
              progressLabel: i == current ? widget.progressLabel : null,
            ),
          ),
        if (widget.showClock || widget.expectation != null)
          Row(
            children: [
              if (widget.showClock) ...[
                Icon(Icons.schedule_rounded, size: 14, color: muted),
                const SizedBox(width: 6),
                Text(
                  formatClock(_elapsed),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: Gap.sm + 2),
              ],
              if (widget.expectation != null)
                Expanded(
                  child: Text(
                    widget.expectation!,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.done,
    required this.active,
    this.progress,
    this.progressLabel,
  });

  final String label;
  final bool done;
  final bool active;
  final double? progress;
  final String? progressLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final Widget marker = done
        ? Icon(Icons.check_circle_rounded, size: 20, color: scheme.primary)
        : active
        ? const Padding(
            padding: EdgeInsets.all(2),
            child: CircularProgressIndicator(strokeWidth: 2.2),
          )
        : Icon(Icons.circle_outlined, size: 18, color: scheme.outlineVariant);

    return Semantics(
      label:
          '$label, ${done
              ? 'done'
              : active
              ? 'in progress'
              : 'waiting'}',
      excludeSemantics: progress == null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox.square(dimension: 22, child: marker),
          const SizedBox(width: Gap.md - 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active || done
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                  ),
                ),
                if (progress != null) ...[
                  if (progressLabel != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      progressLabel!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress!.clamp(0.0, 1.0),
                      minHeight: 4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Index of the step named [key]; 0 when the key is null or unknown.
int currentStepIndex(List<ProgressStep> steps, String? key) {
  final index = steps.indexWhere((step) => step.key == key);
  return index < 0 ? 0 : index;
}

/// `mm:ss`, e.g. 75 seconds → "01:15".
String formatClock(Duration elapsed) {
  final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
  final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
