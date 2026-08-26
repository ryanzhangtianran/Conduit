import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dartssh2/dartssh2.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:conduit/shared/presentation/foundation/foundation.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import 'package:conduit/data/local/app_database.dart';
import 'package:conduit/shared/formatters.dart';
import 'package:conduit/shared/presentation/conduit_alert.dart';
import 'package:conduit/theme.dart';
import 'file_editor_tab.dart';
import 'file_management_dialogs.dart';
import 'file_management_menus.dart';
import 'file_management_models.dart';
import 'file_management_widgets.dart';
import 'file_system_backend.dart';
import 'file_transfer_queue.dart';
import 'file_transfer_queue_provider.dart';
import 'server_connection_actions.dart';
import 'server_models.dart';
import 'server_providers.dart';
import 'terminal_tabs_provider.dart';

/// Dual-pane file manager: the left pane shows the local disk or another
/// server, the right pane the tab's server. Every operation is written once
/// against [FilePaneState] and a [FileSystemBackend]; transfers go through the
/// app-owned [FileTransferQueue].
///
/// Error reporting follows one rule: a pane that fails to list shows the error
/// in place ([FilePaneState.error]); a failed operation (rename, delete,
/// transfer…) shows one error snackbar; a file that cannot be opened in the
/// editor shows a blocking [showConduitErrorAlert].
class FileManagementTabView extends ConsumerStatefulWidget {
  const FileManagementTabView({required this.tab, super.key});

  final FileManagementTab tab;

  @override
  ConsumerState<FileManagementTabView> createState() =>
      _FileManagementTabViewState();
}

class _SftpListingSession {
  _SftpListingSession(this.owner, this.backend);

  final SSHClient owner;
  final Future<SftpFileSystemBackend> backend;
}

class _FileManagementTabViewState extends ConsumerState<FileManagementTabView>
    implements FileManagerMenuHost {
  late final FilePaneState _left;
  late final FilePaneState _right;
  final _local = LocalFileSystemBackend();

  /// SFTP channels used for listing and quick operations only. Transfers open
  /// their own channels in the queue, so disposing these never interrupts one.
  final _listingSessions = <int, _SftpListingSession>{};

  late final FocusNode _shortcutFocusNode;
  FileSide? _focusedSide;
  FileClipboard? _clipboard;
  FileSide? _dropTargetSide;
  var _draggingFiles = false;
  var _leftCollapsed = false;

  /// Below this content width only the remote pane is shown.
  static const _mobileBreakpoint = 900.0;

  @override
  void initState() {
    super.initState();
    _left = FilePaneState(
      side: FileSide.left,
      endpoint: const TransferEndpoint.local(),
      path: Directory.current.path,
    );
    _right = FilePaneState(
      side: FileSide.right,
      endpoint: TransferEndpoint.server(widget.tab.serverId),
      path: widget.tab.initialPath ?? '.',
    );
    _shortcutFocusNode = FocusNode(debugLabel: 'file-management-shortcuts');
    unawaited(refresh(_left));
    unawaited(refresh(_right));
  }

  @override
  void dispose() {
    for (final session in _listingSessions.values) {
      unawaited(_closeSession(session));
    }
    _listingSessions.clear();
    _left.dispose();
    _right.dispose();
    _shortcutFocusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Panes and backends

  @override
  FilePaneState paneFor(FileSide side) =>
      side == FileSide.left ? _left : _right;

  @override
  FilePaneState otherPane(FilePaneState pane) =>
      pane.side == FileSide.left ? _right : _left;

  @override
  int get tabServerId => widget.tab.serverId;

  @override
  String get tabServerName => widget.tab.serverName;

  Future<void> _closeSession(_SftpListingSession session) async {
    try {
      await (await session.backend).close();
    } catch (_) {}
  }

  void _releaseSession(int serverId) {
    final previous = _listingSessions.remove(serverId);
    if (previous != null) unawaited(_closeSession(previous));
  }

  Future<FileSystemBackend> _backendForEndpoint(
    TransferEndpoint endpoint,
  ) async {
    final serverId = endpoint.serverId;
    if (serverId == null) return _local;
    final owner = ref.read(connectionManagerProvider).clientFor(serverId);
    if (owner == null) {
      _releaseSession(serverId);
      throw const ServerConnectionRequiredException();
    }
    final cached = _listingSessions[serverId];
    if (cached != null && identical(cached.owner, owner)) {
      return cached.backend;
    }
    if (cached != null) unawaited(_closeSession(cached));
    final next = owner.sftp().then(SftpFileSystemBackend.new);
    _listingSessions[serverId] = _SftpListingSession(owner, next);
    return next;
  }

  Future<FileSystemBackend> _backendFor(FilePaneState pane) =>
      _backendForEndpoint(pane.endpoint);

  @override
  String serverNameFor(int serverId) =>
      _serverById(serverId)?.name ?? 'fileManagerAnotherServer'.tr();

  Server? _serverById(int serverId) =>
      (ref.read(serversProvider).asData?.value ?? const <Server>[])
          .where((server) => server.id == serverId)
          .firstOrNull;

  // ---------------------------------------------------------------------------
  // Listing and navigation

  @override
  Future<void> refresh(FilePaneState pane) async {
    setState(() {
      pane.loading = true;
      pane.error = null;
    });
    try {
      final backend = await _backendFor(pane);
      final absolutePath = await backend.absolute(pane.path);
      final entries = await backend.list(absolutePath);
      sortFileEntries(entries);
      if (!mounted) return;
      final paths = {for (final entry in entries) entry.path};
      setState(() {
        pane.path = absolutePath;
        pane.entries = entries;
        pane.selectedPaths = pane.selectedPaths.where(paths.contains).toSet();
      });
    } catch (error) {
      if (mounted) setState(() => pane.error = error.toString());
    } finally {
      if (mounted) setState(() => pane.loading = false);
    }
  }

  Future<void> _refreshAll() => Future.wait([refresh(_left), refresh(_right)]);

  /// Moves [pane] to [path] on its current endpoint.
  @override
  Future<void> openDirectory(FilePaneState pane, String path) async {
    final destination = path.trim();
    if (destination.isEmpty) return;
    setState(() {
      pane.navigate(pane.endpoint, destination);
      _focusedSide = pane.side;
    });
    pane.pathFocusNode.unfocus();
    await refresh(pane);
  }

  @override
  bool canGoUp(FilePaneState pane) =>
      pane.isLocal ? _local.parentOf(pane.path) != pane.path : pane.path != '/';

  @override
  Future<void> goUp(FilePaneState pane) async {
    if (!canGoUp(pane)) return;
    final parent = pane.isLocal
        ? _local.parentOf(pane.path)
        : parentRemotePath(pane.path);
    await openDirectory(pane, parent);
  }

  @override
  Future<void> chooseLocalDirectory() async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'fileManagerChooseLocalFolder'.tr(),
      initialDirectory: _left.isLocal ? _left.path : null,
    );
    if (path == null || !mounted) return;
    await openDirectory(_left, path);
  }

  Future<void> _chooseLeftSource() async {
    final servers = ref.read(serversProvider).asData?.value ?? const <Server>[];
    final choices = servers
        .where((server) => server.id != widget.tab.serverId)
        .toList();
    final choice = await showLeftPaneSourceDialog(choices);
    if (!mounted || choice == null) return;
    final serverId = choice.serverId;
    if (serverId == null) {
      setState(() {
        _left.navigate(const TransferEndpoint.local(), Directory.current.path);
      });
      await refresh(_left);
      return;
    }
    final server = servers.firstWhere((item) => item.id == serverId);
    final connected = await connectForStatistics(context, ref, server);
    if (!connected || !mounted) return;
    setState(() => _left.navigate(TransferEndpoint.server(server.id), '.'));
    await refresh(_left);
  }

  Future<void> _copyRemotePath() =>
      Clipboard.setData(ClipboardData(text: _right.path));

  Future<void> _openTerminalHere() async {
    final server = _serverById(widget.tab.serverId);
    if (server == null) {
      _showError(
        'fileManagerCouldNotOpenTerminal'.tr(),
        'fileManagerServerUnavailable'.tr(),
      );
      return;
    }
    await openTerminalSession(
      context,
      ref,
      server,
      initialDirectory: _right.path,
    );
  }

  // ---------------------------------------------------------------------------
  // Selection and focus

  bool get _isMultiModifierPressed =>
      HardwareKeyboard.instance.isMetaPressed ||
      HardwareKeyboard.instance.isControlPressed;

  bool get _isRangeModifierPressed => HardwareKeyboard.instance.isShiftPressed;

  void _requestShortcutFocus() {
    if (!_shortcutFocusNode.hasFocus) _shortcutFocusNode.requestFocus();
  }

  void _select(
    FilePaneState pane,
    FileEntry entry, {
    required int index,
    bool toggle = false,
    bool range = false,
  }) {
    _requestShortcutFocus();
    final other = otherPane(pane);
    setState(() {
      _focusedSide = pane.side;
      other.clearSelection();
      final anchor = pane.anchorIndex;
      if (range && anchor != null) {
        final start = math.min(anchor, index);
        final end = math.max(anchor, index);
        final displayed = pane.displayedEntries;
        pane.selectedPaths = {
          for (var i = start; i <= end && i < displayed.length; i++)
            displayed[i].path,
        };
      } else if (toggle) {
        final next = {...pane.selectedPaths};
        if (!next.add(entry.path)) next.remove(entry.path);
        pane.selectedPaths = next;
        pane.anchorIndex = index;
      } else {
        pane.selectedPaths = {entry.path};
        pane.anchorIndex = index;
      }
    });
  }

  /// Right-click on an unselected row selects it; on a selected row it keeps
  /// the multi-selection so the menu applies to all of it.
  @override
  void ensureContextSelection(FilePaneState pane, FileEntry entry, int index) {
    if (pane.selectedPaths.contains(entry.path)) {
      setState(() {
        _focusedSide = pane.side;
        otherPane(pane).clearSelection();
      });
      return;
    }
    _select(pane, entry, index: index);
  }

  void _focusSide(FileSide side) {
    _requestShortcutFocus();
    if (_focusedSide == side) return;
    setState(() => _focusedSide = side);
  }

  void _selectAllOnFocusedSide() {
    final side = _focusedSide;
    if (side == null) return;
    final pane = paneFor(side);
    final displayed = pane.displayedEntries;
    setState(() {
      pane.selectedPaths = {for (final entry in displayed) entry.path};
      pane.anchorIndex = displayed.isEmpty ? null : 0;
      otherPane(pane).clearSelection();
    });
  }

  /// Index of the selection anchor (or first selected entry) within the
  /// displayed entries of [pane], or null when nothing is selected.
  int? _selectionIndex(FilePaneState pane) {
    final displayed = pane.displayedEntries;
    final anchor = pane.anchorIndex;
    if (anchor != null && anchor >= 0 && anchor < displayed.length) {
      return anchor;
    }
    for (var i = 0; i < displayed.length; i++) {
      if (pane.selectedPaths.contains(displayed[i].path)) return i;
    }
    return null;
  }

  void _selectIndex(FilePaneState pane, int index, {bool range = false}) {
    final displayed = pane.displayedEntries;
    if (index < 0 || index >= displayed.length) return;
    _select(pane, displayed[index], index: index, range: range);
    _scrollToIndex(pane, index);
  }

  void _moveSelection(int delta, {required bool range}) {
    _requestShortcutFocus();
    final pane = paneFor(_focusedSide ?? FileSide.right);
    final length = pane.displayedEntries.length;
    if (length == 0) return;
    final current = _selectionIndex(pane);
    if (current == null) {
      _selectIndex(pane, delta > 0 ? 0 : length - 1);
      return;
    }
    final index = (current + delta).clamp(0, length - 1);
    if (!range && index == current) return;
    _selectIndex(pane, index, range: range);
  }

  void _selectBoundary({required bool first}) {
    _requestShortcutFocus();
    final pane = paneFor(_focusedSide ?? FileSide.right);
    final length = pane.displayedEntries.length;
    if (length == 0) return;
    _selectIndex(pane, first ? 0 : length - 1);
  }

  void _scrollToIndex(FilePaneState pane, int index) {
    final controller = pane.scrollController;
    if (!controller.hasClients) return;
    final position = controller.position;
    final top = index * kFileRowExtent;
    final bottom = top + kFileRowExtent;
    final viewport = position.viewportDimension;
    if (top < position.pixels) {
      position.jumpTo(top < 0 ? 0 : top);
    } else if (bottom > position.pixels + viewport) {
      position.jumpTo((bottom - viewport).clamp(0.0, position.maxScrollExtent));
    }
  }

  // ---------------------------------------------------------------------------
  // Search

  void _toggleSearch(FilePaneState pane) {
    final opening = !pane.searchOpen;
    setState(() {
      pane.searchOpen = opening;
      if (!opening) pane.searchController.clear();
      pane.anchorIndex = null;
    });
    if (opening) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) pane.searchFocusNode.requestFocus();
      });
    }
  }

  /// Opens the pane search and focuses it, ready to replace any query
  /// (used by the backslash shortcut).
  void _wakeSearch(FilePaneState pane) {
    setState(() {
      pane.searchOpen = true;
      pane.anchorIndex = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      pane.searchFocusNode.requestFocus();
      pane.searchController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: pane.searchController.text.length,
      );
    });
  }

  Widget _searchInput(FilePaneState pane) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            _toggleSearch(pane);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: pane.searchController,
          focusNode: pane.searchFocusNode,
          style: Theme.of(context).textTheme.bodySmall,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() => pane.anchorIndex = null),
          decoration: InputDecoration(
            hintText: 'fileManagerSearch'.tr(),
            isDense: true,
            prefixIcon: const Icon(Symbols.search, size: 16),
            suffixIcon: pane.searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'fileManagerClearSearch'.tr(),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    icon: const Icon(Symbols.close, size: 16),
                    onPressed: () =>
                        setState(() => pane.searchController.clear()),
                  ),
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Clipboard, drag data and paste

  @override
  FileClipboardEntry clipboardEntryFor(FilePaneState pane, FileEntry entry) =>
      FileClipboardEntry(
        side: pane.side,
        endpoint: pane.endpoint,
        path: entry.path,
        name: entry.name,
        isDirectory: entry.isDirectory,
        size: entry.size,
      );

  @override
  List<FileClipboardEntry> selectionEntries(FilePaneState pane) => [
    for (final entry in pane.selectedEntries) clipboardEntryFor(pane, entry),
  ];

  FileDragData _dragDataFor(FilePaneState pane, FileEntry entry) {
    final entries = pane.selectedPaths.contains(entry.path)
        ? selectionEntries(pane)
        : [clipboardEntryFor(pane, entry)];
    return FileDragData(side: pane.side, entries: entries);
  }

  @override
  void setClipboard(ClipboardMode mode) {
    final side = _focusedSide;
    if (side == null) return;
    final entries = selectionEntries(paneFor(side));
    if (entries.isEmpty) return;
    setState(() {
      _clipboard = FileClipboard(mode: mode, entries: entries);
    });
    showStyledSnackBar(
      message: _countLabel(entries),
      title: mode == ClipboardMode.copy
          ? 'fileManagerCopied'.tr()
          : 'fileManagerCut'.tr(),
      icon: mode == ClipboardMode.copy
          ? Symbols.content_copy
          : Symbols.content_cut,
      accentColor: Theme.of(context).colorScheme.primary,
    );
  }

  @override
  bool canPasteInto(FilePaneState pane) {
    final clipboard = _clipboard;
    return clipboard != null && clipboard.isNotEmpty && !pane.busy;
  }

  @override
  Future<void> pasteInto(FilePaneState target) async {
    final clipboard = _clipboard;
    if (clipboard == null || clipboard.isEmpty || !canPasteInto(target)) {
      return;
    }
    setState(() => _focusedSide = target.side);
    final isCut = clipboard.mode == ClipboardMode.cut;
    var queued = 0;
    try {
      for (final entry in clipboard.entries) {
        if (isCut && entry.endpoint == target.endpoint) {
          await _moveWithinEndpoint(entry, target);
        } else {
          await _transfer(entry, target, deleteSource: isCut, notify: false);
          queued += 1;
        }
      }
      if (!mounted) return;
      if (isCut) setState(() => _clipboard = null);
      if (queued == 0) await refresh(target);
      if (!mounted) return;
      showStyledSnackBar(
        message: queued > 0
            ? 'fileManagerTransferTasks'.plural(queued)
            : isCut
            ? 'fileManagerItemsMoved'.tr()
            : 'fileManagerItemsPasted'.tr(),
        title: queued > 0
            ? 'fileManagerTransferQueued'.tr()
            : 'fileManagerDone'.tr(),
        icon: queued > 0 ? Symbols.schedule : Symbols.check_circle,
        accentColor: Theme.of(context).colorScheme.primary,
      );
    } catch (error) {
      _showError('fileManagerPasteFailed'.tr(), error);
      if (mounted) await refresh(target);
    }
  }

  /// Cut & paste on the same backend is a true rename, so it stays a direct
  /// call rather than a streamed copy.
  Future<void> _moveWithinEndpoint(
    FileClipboardEntry entry,
    FilePaneState target,
  ) async {
    final backend = await _backendFor(target);
    if (backend.parentOf(entry.path) == target.path) return;
    final destination = await resolveDestination(
      backend,
      target.path,
      entry.name,
      mode: ref.read(transferConflictModeProvider),
      askConflict: showTransferConflictDialog,
    );
    if (destination == null) return;
    await removeTree(backend, destination);
    await backend.rename(entry.path, destination);
  }

  Future<void> _handleInternalDrop(FileDragData data, FileSide side) async {
    final target = paneFor(side);
    if (data.side == side || data.entries.isEmpty) return;
    setState(() {
      _focusedSide = side;
      _dropTargetSide = null;
    });
    try {
      for (final entry in data.entries) {
        await _transfer(entry, target, notify: false);
      }
      if (!mounted) return;
      showStyledSnackBar(
        message: _countLabel(data.entries),
        title: 'fileManagerTransferQueued'.tr(),
        icon: Symbols.schedule,
        accentColor: Theme.of(context).colorScheme.primary,
      );
    } catch (error) {
      _showError('fileManagerDropFailed'.tr(), error);
    }
  }

  /// Files dropped from the OS upload into the right pane.
  Future<void> _uploadDroppedFiles(List<DropItem> items) async {
    for (final item in items.whereType<DropItemFile>()) {
      final bookmark = item.extraAppleBookmark;
      final hasSecurityScopedAccess =
          bookmark != null &&
          await DesktopDrop.instance.startAccessingSecurityScopedResource(
            bookmark: bookmark,
          );
      final entry = await _local.stat(item.path);
      if (entry == null || !mounted) continue;
      await _transfer(
        FileClipboardEntry(
          side: FileSide.left,
          endpoint: const TransferEndpoint.local(),
          path: entry.path,
          name: entry.name,
          isDirectory: entry.isDirectory,
          size: entry.size,
        ),
        _right,
        onFinish: hasSecurityScopedAccess
            ? () => DesktopDrop.instance.stopAccessingSecurityScopedResource(
                bookmark: bookmark,
              )
            : null,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Transfers

  /// Queues a copy of [entry] into [target]'s directory and refreshes both
  /// panes when it ends. Never throws: the queue reports failures itself.
  Future<void> _transfer(
    FileClipboardEntry entry,
    FilePaneState target, {
    bool deleteSource = false,
    bool notify = true,
    Future<void> Function()? onFinish,
  }) async {
    var totalBytes = entry.isDirectory ? null : entry.size;
    if (!entry.isDirectory && totalBytes == null) {
      try {
        final backend = await _backendForEndpoint(entry.endpoint);
        totalBytes = (await backend.stat(entry.path))?.size;
      } catch (_) {
        // The queue surfaces connection problems when the transfer runs.
      }
    }
    final title = entry.endpoint.isLocal && !target.isLocal
        ? 'fileManagerUploading'.tr(args: [entry.name])
        : !entry.endpoint.isLocal && target.isLocal
        ? 'fileManagerDownloading'.tr(args: [entry.name])
        : entry.endpoint == target.endpoint
        ? 'fileManagerCopying'.tr(args: [entry.name])
        : 'fileManagerTransferring'.tr(args: [entry.name]);
    final done = ref
        .read(fileTransferQueueProvider)
        .enqueue(
          FileTransferRequest(
            title: title,
            source: entry.endpoint,
            sourcePath: entry.path,
            name: entry.name,
            isDirectory: entry.isDirectory,
            destination: target.endpoint,
            destinationDirectory: target.path,
            totalBytes: totalBytes,
            deleteSourceOnSuccess: deleteSource,
            notify: notify,
            onFinish: onFinish,
          ),
        );
    unawaited(
      done.then((_) {
        if (mounted) unawaited(_refreshAll());
      }),
    );
  }

  @override
  Future<void> transferSelection(FilePaneState pane) async {
    final target = otherPane(pane);
    for (final entry in selectionEntries(pane)) {
      await _transfer(entry, target);
    }
  }

  // ---------------------------------------------------------------------------
  // Quick operations (rename, new folder, delete, archive)

  void _showError(String title, Object error) {
    if (!mounted) return;
    showStyledSnackBar(
      message: error.toString(),
      title: title,
      icon: Symbols.error,
      accentColor: Theme.of(context).colorScheme.error,
    );
  }

  void _showDone(String title, String message, {IconData? icon}) {
    if (!mounted) return;
    showStyledSnackBar(
      message: message,
      title: title,
      icon: icon ?? Symbols.check_circle,
      accentColor: Theme.of(context).colorScheme.primary,
    );
  }

  /// Runs a short operation on [pane] with a busy indicator; failures show
  /// one snackbar titled [failureTitle]. Returns whether it succeeded.
  Future<bool> _runPaneOperation(
    FilePaneState pane, {
    required String label,
    required String failureTitle,
    required Future<void> Function() action,
  }) async {
    if (pane.busy) return false;
    setState(() => pane.busyLabel = label);
    try {
      await action();
      return true;
    } catch (error) {
      _showError(failureTitle, error);
      return false;
    } finally {
      if (mounted) setState(() => pane.busyLabel = null);
    }
  }

  @override
  Future<void> renameEntry(FileClipboardEntry entry) async {
    final pane = paneFor(entry.side);
    if (pane.busy) return;
    final name = await showFileNameDialog(
      title: 'fileManagerRename'.tr(),
      label: 'fileManagerName'.tr(),
      initialName: entry.name,
      actionLabel: 'fileManagerRename'.tr(),
    );
    if (name == null || name == entry.name || !mounted) return;
    final ok = await _runPaneOperation(
      pane,
      label: 'fileManagerRename'.tr(),
      failureTitle: 'fileManagerRenameFailed'.tr(),
      action: () async {
        final backend = await _backendFor(pane);
        final destination = backend.join(backend.parentOf(entry.path), name);
        await backend.rename(entry.path, destination);
        await refresh(pane);
      },
    );
    if (ok) _showDone('fileManagerRenamed'.tr(), name);
  }

  @override
  Future<void> createFolder(FilePaneState pane) async {
    if (pane.busy) return;
    final name = await showFileNameDialog(
      title: 'fileManagerCreateFolder'.tr(),
      label: 'fileManagerFolderName'.tr(),
      actionLabel: 'fileManagerCreate'.tr(),
    );
    if (name == null || !mounted) return;
    final ok = await _runPaneOperation(
      pane,
      label: 'fileManagerCreateFolder'.tr(),
      failureTitle: 'fileManagerCreateFolderFailed'.tr(),
      action: () async {
        final backend = await _backendFor(pane);
        await backend.mkdir(backend.join(pane.path, name));
        await refresh(pane);
      },
    );
    if (ok) _showDone('fileManagerFolderCreated'.tr(), name);
  }

  @override
  Future<void> deleteSelection() async {
    final side = _focusedSide;
    if (side == null) return;
    final entries = selectionEntries(paneFor(side));
    if (entries.isEmpty) return;
    await _deleteEntries(entries);
  }

  Future<void> _deleteEntries(List<FileClipboardEntry> entries) async {
    if (entries.isEmpty) return;
    final pane = paneFor(entries.first.side);
    if (pane.busy) return;
    final approved = await confirmDeleteEntries(
      count: entries.length,
      firstName: entries.first.name,
      firstIsDirectory: entries.first.isDirectory,
    );
    if (!approved || !mounted) return;
    final ok = await _runPaneOperation(
      pane,
      label: 'commonDelete'.tr(),
      failureTitle: 'fileManagerDeleteFailed'.tr(),
      action: () async {
        final backend = await _backendFor(pane);
        final deleted = <String>{};
        try {
          for (final entry in entries) {
            await removeTree(backend, entry.path);
            deleted.add(entry.path);
          }
        } finally {
          if (mounted) {
            setState(() {
              pane.selectedPaths = pane.selectedPaths.difference(deleted);
            });
            await refresh(pane);
          }
        }
      },
    );
    if (ok) {
      _showDone(
        'fileManagerDeleted'.tr(),
        _countLabel(entries),
        icon: Symbols.delete,
      );
    }
  }

  @override
  Future<void> extractArchive(FilePaneState pane, FileClipboardEntry entry) {
    final command = entry.name.toLowerCase().endsWith('.zip')
        ? 'unzip -o -- ${shellQuote(entry.name)}'
        : 'tar -xzf ${shellQuote(entry.name)}';
    return _runRemoteUtility(
      pane,
      title: 'fileManagerUnarchiving'.tr(args: [entry.name]),
      command: () async => 'cd ${shellQuote(pane.path)} && $command',
    );
  }

  @override
  Future<void> archiveEntries(
    FilePaneState pane,
    List<FileClipboardEntry> entries,
    ArchiveFormat format,
  ) async {
    if (entries.isEmpty) return;
    final extension = format == ArchiveFormat.zip ? '.zip' : '.tar.gz';
    final baseName = entries.length == 1
        ? '${entries.first.name}$extension'
        : 'archive$extension';
    final names = entries.map((entry) => shellQuote(entry.name)).join(' ');
    await _runRemoteUtility(
      pane,
      title: 'fileManagerArchiving'.tr(args: [baseName]),
      command: () async {
        final backend = await _backendFor(pane);
        final archivePath = await uniquePath(backend, pane.path, baseName);
        final archiveName = backend.nameOf(archivePath);
        final command = format == ArchiveFormat.zip
            ? 'zip -r -- ${shellQuote(archiveName)} $names'
            : 'tar -czf ${shellQuote(archiveName)} -- $names';
        return 'cd ${shellQuote(pane.path)} && $command';
      },
    );
  }

  Future<void> _runRemoteUtility(
    FilePaneState pane, {
    required String title,
    required Future<String> Function() command,
  }) async {
    final serverId = pane.serverId;
    if (serverId == null || pane.busy) return;
    String result = '';
    final ok = await _runPaneOperation(
      pane,
      label: title,
      failureTitle: 'fileManagerUtilityFailed'.tr(args: [title]),
      action: () async {
        final shell = await command();
        result = await ref.read(connectionManagerProvider).withClient(
          serverId,
          (client) async {
            final session = await client.execute(shell);
            final stdout = utf8.decoder.bind(session.stdout).join();
            final stderr = utf8.decoder.bind(session.stderr).join();
            await session.done;
            final error = (await stderr).trim();
            if (session.exitCode != 0) {
              throw StateError(
                error.isEmpty ? 'fileManagerRemoteCommandFailed'.tr() : error,
              );
            }
            return (await stdout).trim();
          },
        );
        await _refreshAll();
      },
    );
    if (ok) {
      _showDone(
        'fileManagerUtilityCompleted'.tr(),
        result.isEmpty ? title : result,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Editor

  @override
  Future<void> editEntry(FilePaneState pane, FileEntry entry) async {
    if (!entry.isFile) return;
    final server = pane.isLocal
        ? _serverById(widget.tab.serverId)
        : _serverById(pane.serverId!);
    if (server == null) {
      _showError(
        'fileManagerCouldNotOpen'.tr(args: [entry.name]),
        'fileManagerServerUnavailable'.tr(),
      );
      return;
    }
    try {
      final size = pane.isLocal
          ? (await _local.stat(entry.path))?.size
          : entry.size;
      validateEditableText(size, entry.path);
    } catch (error) {
      if (!mounted) return;
      showConduitErrorAlert(
        error,
        title: 'fileManagerCouldNotOpen'.tr(args: [entry.name]),
      );
      return;
    }
    ref
        .read(terminalTabsProvider.notifier)
        .openFileEditor(
          server: server,
          path: entry.path,
          fileName: entry.name,
          isRemote: !pane.isLocal,
        );
  }

  // ---------------------------------------------------------------------------
  // Keyboard

  /// True when a text field (path bar, search, etc.) should own typing.
  bool get _isTextInputFocused {
    if (_left.pathFocusNode.hasFocus || _right.pathFocusNode.hasFocus) {
      return true;
    }
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null || primary.context == null) return false;
    return primary.context!.widget is EditableText ||
        primary.context!.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  /// True when the left pane is rendered and can receive focus.
  bool get _canFocusLeftPane => !_leftCollapsed;

  FilePaneState get _focusedPane => paneFor(_focusedSide ?? FileSide.right);

  void _openFocusedSelection() {
    _requestShortcutFocus();
    final side = _focusedSide;
    if (side == null) return;
    final pane = paneFor(side);
    final selected = pane.selectedEntries;
    if (selected.length != 1) return;
    final entry = selected.first;
    if (entry.isDirectory) {
      unawaited(openDirectory(pane, entry.path));
    } else {
      unawaited(editEntry(pane, entry));
    }
  }

  void _renameFocusedSelection() {
    _requestShortcutFocus();
    final side = _focusedSide;
    if (side == null) return;
    final entries = selectionEntries(paneFor(side));
    if (entries.length != 1) return;
    unawaited(renameEntry(entries.first));
  }

  void _focusPathBar() {
    final pane = _focusedPane;
    if (pane.isLocal) return;
    pane.pathFocusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      pane.pathController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: pane.pathController.text.length,
      );
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    // Let path bar and other text fields handle select-all, delete, paste, etc.
    if (_isTextInputFocused) return KeyEventResult.ignored;

    final isMeta = _isMultiModifierPressed;
    final isShift = _isRangeModifierPressed;
    final logical = event.logicalKey;

    if (isMeta) {
      if (logical == LogicalKeyboardKey.keyA) {
        _selectAllOnFocusedSide();
        return KeyEventResult.handled;
      }
      if (logical == LogicalKeyboardKey.keyC) {
        setClipboard(ClipboardMode.copy);
        return KeyEventResult.handled;
      }
      if (logical == LogicalKeyboardKey.keyX) {
        setClipboard(ClipboardMode.cut);
        return KeyEventResult.handled;
      }
      if (logical == LogicalKeyboardKey.keyV) {
        final side = _focusedSide;
        if (side != null) unawaited(pasteInto(paneFor(side)));
        return KeyEventResult.handled;
      }
      if (logical == LogicalKeyboardKey.keyN) {
        unawaited(createFolder(_focusedPane));
        return KeyEventResult.handled;
      }
      if (logical == LogicalKeyboardKey.keyR) {
        unawaited(refresh(_focusedPane));
        return KeyEventResult.handled;
      }
      if (logical == LogicalKeyboardKey.keyL) {
        _focusPathBar();
        return KeyEventResult.handled;
      }
      if (logical == LogicalKeyboardKey.arrowUp) {
        _requestShortcutFocus();
        unawaited(goUp(_focusedPane));
        return KeyEventResult.handled;
      }
      if (logical == LogicalKeyboardKey.arrowDown) {
        _openFocusedSelection();
        return KeyEventResult.handled;
      }
      if (logical == LogicalKeyboardKey.arrowLeft) {
        if (_canFocusLeftPane) _focusSide(FileSide.left);
        return KeyEventResult.handled;
      }
      if (logical == LogicalKeyboardKey.arrowRight) {
        _focusSide(FileSide.right);
        return KeyEventResult.handled;
      }
    }
    if (logical == LogicalKeyboardKey.arrowUp ||
        logical == LogicalKeyboardKey.arrowDown) {
      _moveSelection(
        logical == LogicalKeyboardKey.arrowDown ? 1 : -1,
        range: isShift,
      );
      return KeyEventResult.handled;
    }
    if (logical == LogicalKeyboardKey.home) {
      _selectBoundary(first: true);
      return KeyEventResult.handled;
    }
    if (logical == LogicalKeyboardKey.end) {
      _selectBoundary(first: false);
      return KeyEventResult.handled;
    }
    if (logical == LogicalKeyboardKey.enter ||
        logical == LogicalKeyboardKey.numpadEnter) {
      _openFocusedSelection();
      return KeyEventResult.handled;
    }
    if (logical == LogicalKeyboardKey.f2) {
      _renameFocusedSelection();
      return KeyEventResult.handled;
    }
    if (logical == LogicalKeyboardKey.f5) {
      unawaited(refresh(_focusedPane));
      return KeyEventResult.handled;
    }
    if (logical == LogicalKeyboardKey.backslash) {
      _wakeSearch(_focusedPane);
      return KeyEventResult.handled;
    }
    if (logical == LogicalKeyboardKey.escape) {
      if (_left.searchOpen || _right.searchOpen) {
        if (_left.searchOpen) _toggleSearch(_left);
        if (_right.searchOpen) _toggleSearch(_right);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (logical == LogicalKeyboardKey.backspace ||
        logical == LogicalKeyboardKey.delete) {
      unawaited(deleteSelection());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---------------------------------------------------------------------------
  // Build

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pathTextStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontFamily: ConduitFonts.mono,
      color: scheme.onSurfaceVariant,
    );
    final leftPane = _buildPane(_left, pathTextStyle);
    final rightPane = _buildPane(_right, pathTextStyle);

    final content = LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _mobileBreakpoint;
        final showExpanded = wide && !_leftCollapsed;
        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
          tween: Tween<double>(end: showExpanded ? 1.0 : 0.0),
          builder: (context, factor, _) {
            if (!wide) return rightPane;
            final clamped = factor.clamp(0.0, 1.0);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (clamped > 0.001) ...[
                  ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: clamped,
                      child: SizedBox(
                        width: constraints.maxWidth / 2,
                        child: Opacity(opacity: clamped, child: leftPane),
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: clamped,
                    child: const VerticalDivider(width: 1),
                  ),
                ],
                Expanded(child: rightPane),
              ],
            );
          },
        );
      },
    );

    return Focus(
      focusNode: _shortcutFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: DropTarget(
        onDragEntered: (_) => setState(() => _draggingFiles = true),
        onDragExited: (_) => setState(() => _draggingFiles = false),
        onDragDone: (details) async {
          setState(() => _draggingFiles = false);
          await _uploadDroppedFiles(details.files);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            content,
            if (_draggingFiles)
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    border: Border.all(color: scheme.primary, width: 2),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Symbols.upload_file,
                          size: 32,
                          color: scheme.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'fileManagerDropToUpload'.tr(args: [_right.path]),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPane(FilePaneState pane, TextStyle? pathTextStyle) {
    final isLeft = pane.side == FileSide.left;
    final title = !isLeft
        ? 'fileManagerRemote'.tr()
        : pane.isLocal
        ? 'fileManagerLocal'.tr()
        : serverNameFor(pane.serverId!);
    return FilePane(
      title: title,
      path: pane.path,
      pathTextStyle: pathTextStyle,
      searchInput: pane.searchOpen ? _searchInput(pane) : null,
      focused: _focusedSide == pane.side,
      dropHighlighted: _dropTargetSide == pane.side,
      canGoUp: canGoUp(pane),
      onGoUp: () => unawaited(goUp(pane)),
      onPathTap: pane.isLocal ? chooseLocalDirectory : null,
      pathInput: pane.isLocal ? null : _pathInput(pane, pathTextStyle),
      onCopyPath: isLeft ? null : _copyRemotePath,
      onOpenTerminal: isLeft ? null : _openTerminalHere,
      onRefresh: () => unawaited(refresh(pane)),
      onFocus: () => _focusSide(pane.side),
      loading: pane.loading,
      busy: pane.busy,
      error: pane.error,
      clipboardHint: _clipboardHint(),
      backgroundMenu: () => buildPaneBackgroundMenu(this, pane),
      canAcceptDrop: (data) => data.side != pane.side,
      onDragEntered: () => setState(() => _dropTargetSide = pane.side),
      onDragExited: () {
        if (_dropTargetSide == pane.side) {
          setState(() => _dropTargetSide = null);
        }
      },
      onAcceptDrop: (data) => _handleInternalDrop(data, pane.side),
      headerActions: [
        PaneIconButton(
          tooltip: pane.searchOpen
              ? 'fileManagerCloseSearch'.tr()
              : 'fileManagerSearch'.tr(),
          onPressed: () => _toggleSearch(pane),
          icon: pane.searchOpen ? Symbols.close : Symbols.search,
        ),
        PaneIconButton(
          tooltip: 'fileManagerCreateFolder'.tr(),
          onPressed: pane.busy ? null : () => unawaited(createFolder(pane)),
          icon: Symbols.create_new_folder,
        ),
        if (isLeft) ...[
          PaneIconButton(
            tooltip: pane.isLocal
                ? 'fileManagerUseAnotherServer'.tr()
                : 'fileManagerChangeServer'.tr(),
            onPressed: () => unawaited(_chooseLeftSource()),
            icon: Symbols.swap_horiz,
          ),
          PaneIconButton(
            tooltip: pane.isLocal
                ? 'fileManagerHideLocal'.tr()
                : 'fileManagerHideLeftPane'.tr(),
            onPressed: () => setState(() {
              _leftCollapsed = true;
              if (_focusedSide == FileSide.left) _focusedSide = FileSide.right;
              if (_dropTargetSide == FileSide.left) _dropTargetSide = null;
            }),
            icon: Symbols.left_panel_close,
          ),
        ] else if (_leftCollapsed)
          PaneIconButton(
            tooltip: 'fileManagerShowLocal'.tr(),
            onPressed: () => setState(() => _leftCollapsed = false),
            icon: Symbols.left_panel_open,
          ),
      ],
      child: FileList(
        entries: pane.displayedEntries,
        scrollController: pane.scrollController,
        emptyMessage: pane.searchQuery.isEmpty
            ? null
            : 'fileManagerNoMatches'.tr(),
        selectedPaths: pane.selectedPaths,
        cutPaths: _cutPathsFor(pane),
        onTapEntry: (entry, index) => _select(
          pane,
          entry,
          index: index,
          toggle: _isMultiModifierPressed,
          range: _isRangeModifierPressed,
        ),
        onOpen: (entry) => unawaited(openDirectory(pane, entry.path)),
        onEdit: (entry) => unawaited(editEntry(pane, entry)),
        dragDataFor: (entry) => _dragDataFor(pane, entry),
        onContextPrepare: (entry, index) =>
            ensureContextSelection(pane, entry, index),
        menuProvider: (entry, index) =>
            buildEntryMenu(this, pane, entry, index),
      ),
    );
  }

  Widget _pathInput(FilePaneState pane, TextStyle? pathTextStyle) => TextField(
    controller: pane.pathController,
    focusNode: pane.pathFocusNode,
    style: pathTextStyle,
    maxLines: 1,
    textInputAction: TextInputAction.go,
    onTap: () {
      _focusSide(pane.side);
      pane.pathController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: pane.pathController.text.length,
      );
    },
    onSubmitted: (value) => unawaited(openDirectory(pane, value)),
    decoration: InputDecoration(
      hintText: 'fileManagerRemotePath'.tr(),
      isDense: true,
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
  );

  Set<String> _cutPathsFor(FilePaneState pane) {
    final clipboard = _clipboard;
    if (clipboard == null || clipboard.mode != ClipboardMode.cut) {
      return const {};
    }
    return {
      for (final entry in clipboard.entries)
        if (entry.side == pane.side && entry.endpoint == pane.endpoint)
          entry.path,
    };
  }

  String? _clipboardHint() {
    final clipboard = _clipboard;
    if (clipboard == null || clipboard.isEmpty) return null;
    final verb = clipboard.mode == ClipboardMode.cut
        ? 'fileManagerCut'.tr()
        : 'fileManagerCopied'.tr();
    final source = clipboard.entries.first.endpoint.isLocal
        ? 'fileManagerLocal'.tr()
        : 'fileManagerRemote'.tr();
    return 'fileManagerClipboardHint'.tr(
      args: [verb, '${clipboard.entries.length}', source],
    );
  }

  String _countLabel(List<FileClipboardEntry> entries) => entries.length == 1
      ? entries.first.name
      : 'fileManagerItems'.tr(args: ['${entries.length}']);
}
