import 'package:easy_localization/easy_localization.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:super_context_menu/super_context_menu.dart';

import 'package:conduit/shared/formatters.dart';
import 'file_management_models.dart';
import 'file_system_backend.dart';

/// Fixed row height of the file lists (matches [FileRow]'s intrinsic height)
/// so keyboard navigation can scroll items into view precisely.
const double kFileRowExtent = 44.0;

/// Header, optional search field, and body of one file-manager pane.
class FilePane extends StatelessWidget {
  const FilePane({
    super.key,
    required this.title,
    required this.path,
    required this.pathTextStyle,
    required this.focused,
    required this.dropHighlighted,
    required this.canGoUp,
    required this.onGoUp,
    required this.onRefresh,
    required this.onFocus,
    required this.loading,
    required this.busy,
    required this.error,
    required this.backgroundMenu,
    required this.canAcceptDrop,
    required this.onDragEntered,
    required this.onDragExited,
    required this.onAcceptDrop,
    required this.child,
    this.onPathTap,
    this.pathInput,
    this.searchInput,
    this.onCopyPath,
    this.onOpenTerminal,
    this.clipboardHint,
    this.headerActions = const [],
  });

  final String title;
  final String path;
  final TextStyle? pathTextStyle;
  final bool focused;
  final bool dropHighlighted;
  final bool canGoUp;
  final VoidCallback onGoUp;
  final VoidCallback? onPathTap;
  final VoidCallback onRefresh;
  final VoidCallback onFocus;
  final bool loading;

  /// A quick operation (rename, new folder, archive) is running on the pane.
  final bool busy;
  final String? error;
  final Menu Function() backgroundMenu;
  final bool Function(FileDragData data) canAcceptDrop;
  final VoidCallback onDragEntered;
  final VoidCallback onDragExited;
  final Future<void> Function(FileDragData data) onAcceptDrop;
  final Widget child;
  final Widget? pathInput;
  final Widget? searchInput;
  final Future<void> Function()? onCopyPath;
  final Future<void> Function()? onOpenTerminal;
  final String? clipboardHint;
  final List<Widget> headerActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ContextMenuWidget(
      menuProvider: (_) => backgroundMenu(),
      child: DragTarget<FileDragData>(
        onWillAcceptWithDetails: (details) {
          if (!canAcceptDrop(details.data)) return false;
          onDragEntered();
          return true;
        },
        onLeave: (_) => onDragExited(),
        onAcceptWithDetails: (details) => onAcceptDrop(details.data),
        builder: (context, candidate, rejected) {
          final highlighted = dropHighlighted || candidate.isNotEmpty;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onFocus,
            child: ColoredBox(
              color: highlighted
                  ? scheme.primary.withValues(alpha: 0.08)
                  : Colors.transparent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 2, 2, 2),
                    child: SizedBox(
                      height: 32,
                      child: Row(
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: focused || highlighted
                                  ? scheme.primary
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child:
                                pathInput ??
                                TextButton(
                                  onPressed: onPathTap,
                                  style: TextButton.styleFrom(
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 0,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: Text(
                                    path,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: pathTextStyle,
                                  ),
                                ),
                          ),
                          if (busy)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          if (clipboardHint != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Text(
                                clipboardHint!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                          ...headerActions,
                          PaneIconButton(
                            tooltip: 'fileManagerGoUp'.tr(),
                            onPressed: canGoUp ? onGoUp : null,
                            icon: Symbols.arrow_upward,
                          ),
                          if (onCopyPath != null)
                            PaneIconButton(
                              tooltip: 'fileManagerCopyRemotePath'.tr(),
                              onPressed: () => onCopyPath!(),
                              icon: Symbols.content_copy,
                            ),
                          if (onOpenTerminal != null)
                            PaneIconButton(
                              tooltip: 'fileManagerOpenTerminalHere'.tr(),
                              onPressed: () => onOpenTerminal!(),
                              icon: Symbols.terminal,
                            ),
                          PaneIconButton(
                            tooltip: 'commonRefresh'.tr(),
                            onPressed: loading ? null : onRefresh,
                            icon: Symbols.refresh,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ?searchInput,
                  Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: SelectableText(error!),
                            ),
                          )
                        : child,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Compact 28px icon button used across pane headers.
class PaneIconButton extends StatelessWidget {
  const PaneIconButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    onPressed: onPressed,
    icon: Icon(icon, size: 18),
  );
}

/// The scrolling list of one pane. Works for local and remote entries alike.
class FileList extends StatelessWidget {
  const FileList({
    super.key,
    required this.entries,
    required this.selectedPaths,
    required this.cutPaths,
    required this.onTapEntry,
    required this.onOpen,
    required this.onEdit,
    required this.dragDataFor,
    required this.onContextPrepare,
    required this.menuProvider,
    this.scrollController,
    this.emptyMessage,
  });

  final List<FileEntry> entries;
  final Set<String> selectedPaths;
  final Set<String> cutPaths;
  final String? emptyMessage;
  final ScrollController? scrollController;
  final void Function(FileEntry entry, int index) onTapEntry;
  final ValueChanged<FileEntry> onOpen;
  final ValueChanged<FileEntry> onEdit;
  final FileDragData Function(FileEntry entry) dragDataFor;
  final void Function(FileEntry entry, int index) onContextPrepare;
  final Menu Function(FileEntry entry, int index) menuProvider;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return EmptyPane(message: emptyMessage ?? 'fileManagerEmptyFolder'.tr());
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemExtent: kFileRowExtent,
      controller: scrollController,
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return ContextMenuWidget(
          menuProvider: (_) {
            onContextPrepare(entry, index);
            return menuProvider(entry, index);
          },
          child: DraggableFileRow(
            dragData: dragDataFor(entry),
            icon: entry.isDirectory ? Symbols.folder : Symbols.description,
            name: entry.name,
            detail: entry.isDirectory
                ? 'fileManagerFolder'.tr()
                : formatBytes(entry.size),
            selected: selectedPaths.contains(entry.path),
            dimmed: cutPaths.contains(entry.path),
            onTap: () => onTapEntry(entry, index),
            onDoubleTap: entry.isDirectory
                ? () => onOpen(entry)
                : () => onEdit(entry),
          ),
        );
      },
    );
  }
}

class DraggableFileRow extends StatelessWidget {
  const DraggableFileRow({
    super.key,
    required this.dragData,
    required this.icon,
    required this.name,
    required this.selected,
    required this.dimmed,
    required this.onTap,
    this.onDoubleTap,
    this.detail,
  });

  final FileDragData dragData;
  final IconData icon;
  final String name;
  final String? detail;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final count = dragData.entries.length;
    final feedbackLabel = count == 1
        ? name
        : 'fileManagerItems'.tr(args: ['$count']);
    return Draggable<FileDragData>(
      data: dragData,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(feedbackLabel),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: FileRow(
          icon: icon,
          name: name,
          detail: detail,
          selected: selected,
          dimmed: true,
          onTap: onTap,
          onDoubleTap: onDoubleTap,
        ),
      ),
      child: FileRow(
        icon: icon,
        name: name,
        detail: detail,
        selected: selected,
        dimmed: dimmed,
        onTap: onTap,
        onDoubleTap: onDoubleTap,
      ),
    );
  }
}

class FileRow extends StatelessWidget {
  const FileRow({
    super.key,
    required this.icon,
    required this.name,
    required this.selected,
    required this.dimmed,
    required this.onTap,
    this.onDoubleTap,
    this.detail,
  });

  final IconData icon;
  final String name;
  final String? detail;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: selected
          ? scheme.secondaryContainer.withValues(alpha: 0.55)
          : Colors.transparent,
      child: InkWell(
        // Desktop file managers select on mouse-down.
        onTapDown: (_) => onTap(),
        onDoubleTap: onDoubleTap,
        child: Opacity(
          opacity: dimmed ? 0.45 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: selected ? scheme.onSecondaryContainer : null,
                    ),
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    detail!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: selected
                          ? scheme.onSecondaryContainer.withValues(alpha: 0.8)
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EmptyPane extends StatelessWidget {
  const EmptyPane({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
