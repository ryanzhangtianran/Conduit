import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:conduit/shared/presentation/relative_time.dart';
import 'github_models.dart';

/// Status icon and color shared by the run tiles, run detail, and the
/// dashboard workflow card.
({IconData icon, Color color}) githubRunStatusVisual(
  BuildContext context,
  WorkflowRunStatus status,
  WorkflowRunConclusion? conclusion,
) {
  final scheme = Theme.of(context).colorScheme;
  return switch (status) {
    WorkflowRunStatus.queued => (
      icon: Symbols.hourglass_top,
      color: scheme.onSurfaceVariant,
    ),
    WorkflowRunStatus.inProgress => (
      icon: Symbols.play_arrow,
      color: scheme.primary,
    ),
    WorkflowRunStatus.completed => switch (conclusion) {
      WorkflowRunConclusion.success => (
        icon: Symbols.check_circle,
        color: const Color(0xFF2E7D32),
      ),
      WorkflowRunConclusion.failure => (
        icon: Symbols.error,
        color: scheme.error,
      ),
      WorkflowRunConclusion.timedOut => (
        icon: Symbols.error,
        color: const Color(0xFFE65100),
      ),
      WorkflowRunConclusion.actionRequired => (
        icon: Symbols.error,
        color: const Color(0xFF6A1B9A),
      ),
      WorkflowRunConclusion.cancelled => (
        icon: Symbols.cancel,
        color: scheme.onSurfaceVariant,
      ),
      _ => (
        icon: Symbols.remove_circle_outline,
        color: scheme.onSurfaceVariant,
      ),
    },
    WorkflowRunStatus.unknown => (
      icon: Symbols.help,
      color: scheme.onSurfaceVariant,
    ),
  };
}

/// Compact relative time label ("just now", "5m ago", …).
String githubTimeAgo(BuildContext context, DateTime? time) =>
    time == null ? '' : relativeTimeLabel(time);

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Absolute timestamp for a run: "Aug 5 · 14:32" in the current year,
/// "Aug 5, 2026" otherwise. Shown alongside [githubTimeAgo].
String githubRunDateTime(BuildContext context, DateTime? time) {
  if (time == null) return '';
  final now = DateTime.now();
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  final date = '${_months[time.month - 1]} ${time.day}';
  return time.year == now.year
      ? '$date · $hour:$minute'
      : '$date, ${time.year}';
}

/// Status icon of a run, job or step.
class GithubRunStatusIcon extends StatelessWidget {
  const GithubRunStatusIcon({
    super.key,
    required this.status,
    this.conclusion,
    this.size = 20,
  });

  final WorkflowRunStatus status;
  final WorkflowRunConclusion? conclusion;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (:icon, :color) = githubRunStatusVisual(context, status, conclusion);
    return Icon(icon, size: size, color: color);
  }
}

/// Pill naming a finished run's conclusion.
class GithubConclusionChip extends StatelessWidget {
  const GithubConclusionChip({super.key, required this.conclusion});

  final WorkflowRunConclusion conclusion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (background, foreground, label) = switch (conclusion) {
      WorkflowRunConclusion.success => (
        const Color(0xFF2E7D32),
        Colors.white,
        'githubConclusionSuccess',
      ),
      WorkflowRunConclusion.failure => (
        theme.colorScheme.error,
        theme.colorScheme.onError,
        'githubConclusionFailure',
      ),
      WorkflowRunConclusion.timedOut => (
        const Color(0xFFE65100),
        Colors.white,
        'githubConclusionTimedOut',
      ),
      WorkflowRunConclusion.cancelled => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurfaceVariant,
        'githubConclusionCancelled',
      ),
      WorkflowRunConclusion.actionRequired => (
        const Color(0xFF6A1B9A),
        Colors.white,
        'githubConclusionActionRequired',
      ),
      _ => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurfaceVariant,
        'githubConclusionUnknown',
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.tr(),
        style: theme.textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}

/// Clock time of [time] ("14:32") for rate-limit and "since" labels.
String githubClockTime(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
