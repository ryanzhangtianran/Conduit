import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:conduit/shared/presentation/foundation/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:conduit/routing/app_router.dart';
import 'package:conduit/shared/formatters.dart';
import 'package:conduit/shared/presentation/task_progress_model.dart';

export 'package:conduit/shared/presentation/task_progress_model.dart';
import 'package:conduit/theme.dart';

class TaskProgressBar extends ConsumerWidget {
  const TaskProgressBar({super.key});

  static const _showDuration = Duration(milliseconds: 220);
  static const _hideDuration = Duration(milliseconds: 180);
  static const _barHeight = 36.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskProgressProvider);
    final activeTasks = tasks.where((task) => task.isActive).toList();
    final visibleTasks = activeTasks.isEmpty ? tasks : activeTasks;
    final primaryTask = visibleTasks.isEmpty
        ? null
        : visibleTasks.where((task) => !task.isQueued).firstOrNull ??
              visibleTasks.first;
    final progress = primaryTask?.progress;
    final hasTask = primaryTask != null;

    return AnimatedSwitcher(
      duration: _showDuration,
      reverseDuration: _hideDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return ClipRect(
          child: SizeTransition(
            sizeFactor: curved,
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.35),
                end: Offset.zero,
              ).animate(curved),
              child: FadeTransition(opacity: curved, child: child),
            ),
          ),
        );
      },
      child: hasTask
          ? SizedBox(
              key: const ValueKey('task-progress-visible'),
              height: _barHeight,
              width: double.infinity,
              child: _TaskProgressBarContent(
                task: primaryTask,
                progress: progress,
              ),
            )
          : const SizedBox.shrink(key: ValueKey('task-progress-hidden')),
    );
  }
}

class _TaskProgressBarContent extends StatelessWidget {
  const _TaskProgressBarContent({required this.task, required this.progress});

  final AppTaskProgress task;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final label = _taskLabel(task);
    final color = _taskColor(task, colorScheme);
    final icon = _taskIcon(task);
    final details = _transferDetails(task);
    final trackColor = colorScheme.surfaceContainerHighest;
    final fillColor = color.withValues(alpha: 0.18);

    return Material(
      color: colorScheme.surfaceContainerHigh,
      child: InkWell(
        onTap: () => _showTaskProgressSheet(context),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Soft determinate fill behind the content.
              if (progress != null)
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        width: constraints.maxWidth * progress!.clamp(0.0, 1.0),
                        height: double.infinity,
                        color: fillColor,
                      ),
                    );
                  },
                )
              else if (task.status == TaskProgressStatus.inProgress ||
                  task.status == TaskProgressStatus.queued)
                LinearProgressIndicator(
                  minHeight: TaskProgressBar._barHeight,
                  color: fillColor,
                  backgroundColor: Colors.transparent,
                ),
              // Thin accent track along the top edge for hierarchy.
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  height: 2,
                  width: double.infinity,
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 2,
                    color: color,
                    backgroundColor: trackColor,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (details != null) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                details,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (progress != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${(progress! * 100).round()}%',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                    _TaskProgressActions(task: task),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskProgressActions extends ConsumerWidget {
  const _TaskProgressActions({required this.task});

  final AppTaskProgress task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!task.isActive) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (task.canPause) ...[
          const SizedBox(width: 4),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            tooltip: task.isPaused
                ? 'taskProgressResume'.tr()
                : 'taskProgressPause'.tr(),
            iconSize: 18,
            onPressed: () {
              final notifier = ref.read(taskProgressProvider.notifier);
              if (task.isPaused) {
                unawaited(notifier.resume(task.id));
              } else {
                unawaited(notifier.pause(task.id));
              }
            },
            icon: Icon(task.isPaused ? Symbols.play_arrow : Symbols.pause),
          ),
        ],
        if (task.canCancel) ...[
          const SizedBox(width: 2),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            tooltip: 'taskProgressCancel'.tr(),
            iconSize: 18,
            onPressed: () {
              unawaited(
                ref.read(taskProgressProvider.notifier).cancel(task.id),
              );
            },
            icon: const Icon(Symbols.close),
          ),
        ],
      ],
    );
  }
}

class _TaskProgressSheet extends ConsumerWidget {
  const _TaskProgressSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskProgressProvider);
    final activeCount = tasks.where((task) => task.isActive).length;
    final title = activeCount == 0
        ? 'taskProgressTransfers'.tr()
        : 'taskProgressTransfersCount'.tr(args: ['$activeCount']);
    final colorScheme = Theme.of(context).colorScheme;

    return SheetScaffold(
      titleText: title,
      heightFactor: 0.56,
      child: tasks.isEmpty
          ? Center(
              child: Text(
                'taskProgressNoTransfers'.tr(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: tasks.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) =>
                  _TaskProgressListTile(task: tasks[index]),
            ),
    );
  }
}

class _TaskProgressListTile extends StatelessWidget {
  const _TaskProgressListTile({required this.task});

  final AppTaskProgress task;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = task.progress;
    final details = _transferDetails(task, includeFinished: true);
    final color = _taskColor(task, colorScheme);

    return ListTile(
      leading: Icon(_taskIcon(task), color: color),
      title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _taskStatusText(task),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (details != null) ...[
            const SizedBox(height: 2),
            Text(
              details,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: ConduitFonts.mono,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (progress != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              color: color,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (progress != null)
            Text(
              '${(progress * 100).round()}%',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          _TaskProgressActions(task: task),
        ],
      ),
    );
  }
}

void _showTaskProgressSheet(BuildContext context) {
  // TaskProgressBar lives in ConduitWindowScaffold (outside the router
  // Navigator), so prefer the app navigator key when available.
  final navigatorContext =
      conduitNavigatorKey.currentContext ??
      (Navigator.maybeOf(context) != null ? context : null);
  if (navigatorContext == null) return;

  showModalBottomSheet<void>(
    context: navigatorContext,
    showDragHandle: false,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => const _TaskProgressSheet(),
  );
}

String _taskLabel(AppTaskProgress task) {
  return switch (task.status) {
    TaskProgressStatus.queued => 'taskProgressQueued'.tr(args: [task.title]),
    TaskProgressStatus.inProgress => task.title,
    TaskProgressStatus.paused => 'taskProgressPaused'.tr(args: [task.title]),
    TaskProgressStatus.completed => 'taskProgressComplete'.tr(
      args: [task.title],
    ),
    TaskProgressStatus.failed => 'taskProgressFailed'.tr(args: [task.title]),
    TaskProgressStatus.canceled => 'taskProgressCanceled'.tr(
      args: [task.title],
    ),
  };
}

String _taskStatusText(AppTaskProgress task) {
  return switch (task.status) {
    TaskProgressStatus.queued => 'taskProgressStatusQueued'.tr(),
    TaskProgressStatus.inProgress => 'taskProgressStatusRunning'.tr(),
    TaskProgressStatus.paused => 'taskProgressStatusPaused'.tr(),
    TaskProgressStatus.completed => 'taskProgressStatusCompleted'.tr(),
    TaskProgressStatus.failed => 'taskProgressStatusFailed'.tr(),
    TaskProgressStatus.canceled => 'taskProgressStatusCanceled'.tr(),
  };
}

Color _taskColor(AppTaskProgress task, ColorScheme colorScheme) {
  return switch (task.status) {
    TaskProgressStatus.queued => colorScheme.secondary,
    TaskProgressStatus.inProgress => colorScheme.primary,
    TaskProgressStatus.paused => colorScheme.secondary,
    TaskProgressStatus.completed => colorScheme.primary,
    TaskProgressStatus.failed => colorScheme.error,
    TaskProgressStatus.canceled => colorScheme.onSurfaceVariant,
  };
}

IconData _taskIcon(AppTaskProgress task) {
  return switch (task.status) {
    TaskProgressStatus.queued => Symbols.schedule,
    TaskProgressStatus.inProgress => Symbols.sync,
    TaskProgressStatus.paused => Symbols.pause_circle,
    TaskProgressStatus.completed => Symbols.check_circle,
    TaskProgressStatus.failed => Symbols.error,
    TaskProgressStatus.canceled => Symbols.cancel,
  };
}

String? _transferDetails(AppTaskProgress task, {bool includeFinished = false}) {
  if (!task.isActive && !includeFinished) return null;
  final showLiveDetails = task.isActive && !task.isPaused && !task.isQueued;
  final speed = task.speedBytesPerSecond == null
      ? null
      : formatBytes(task.speedBytesPerSecond!.round());
  final eta = task.eta == null ? null : _formatDuration(task.eta!);
  final size = task.totalBytes == null
      ? formatBytes(task.transferredBytes)
      : '${formatBytes(task.transferredBytes)} / ${formatBytes(task.totalBytes!)}';
  final parts = [
    size,
    if (speed != null && showLiveDetails) '$speed/s',
    if (eta != null && showLiveDetails) 'ETA $eta',
  ];
  return parts.join(' · ');
}

String _formatDuration(Duration duration) {
  if (duration.inSeconds <= 0) return 'now';
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m';
  if (minutes > 0) return '${minutes}m ${seconds}s';
  return '${seconds}s';
}
