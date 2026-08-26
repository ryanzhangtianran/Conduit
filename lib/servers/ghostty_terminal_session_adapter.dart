import 'dart:async';
import 'dart:convert';

import 'package:flterm/flterm.dart' as flterm;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:conduit/shared/presentation/app_context_menu.dart';
import 'server_providers.dart';
import 'terminal_session_adapter.dart';

/// Terminal adapter backed by flterm's libghostty-vt renderer.
///
/// flterm owns terminal rendering and interaction while this adapter bridges
/// its controller to Conduit's SSH transport and terminal-find host.
class GhosttyTerminalSessionAdapterFactory
    implements TerminalSessionAdapterFactory {
  const GhosttyTerminalSessionAdapterFactory();

  @override
  TerminalSessionAdapter create({required int columns, required int rows}) =>
      GhosttyTerminalSessionAdapter(columns: columns, rows: rows);
}

class GhosttyTerminalSessionAdapter implements TerminalSessionAdapter {
  /// [columns] and [rows] should match the PTY size requested from the
  /// remote shell so early output wraps correctly before the first layout.
  GhosttyTerminalSessionAdapter({
    int columns = 80,
    int rows = 24,
    bool cursorAnimationEnabled = true,
  }) : _lastColumns = columns,
       _lastRows = rows,
       _cursorAnimationEnabled = cursorAnimationEnabled,
       _controller = flterm.TerminalController(
         config: flterm.TerminalConfig(
           cols: columns,
           rows: rows,
           scrollbackLimit: 10 * 1024 * 1024,
           cursorBlink: cursorAnimationEnabled,
         ),
       ) {
    _clipboard = TerminalClipboardBridge(
      getClipboard: _getHostClipboard,
      sendResponse: sendInput,
    );
    _controller.onOutput = (bytes) {
      if (_disposed) return;
      _activity.sentInput(bytes);
      _outgoingBytes.add(Uint8List.fromList(bytes));
    };
    _controller.onResize = _onResize;
    _controller.onClipboardWrite = _onClipboardWrite;
  }

  static const _cursorMotionDuration = Duration(milliseconds: 90);

  final flterm.TerminalController _controller;
  late final TerminalClipboardBridge _clipboard;
  final _terminalViewKey = GlobalKey<flterm.TerminalViewState>();
  final _scrollController = flterm.TerminalScrollController();
  final _outgoingBytes = StreamController<Uint8List>.broadcast();
  final _resizeEvents = StreamController<TerminalResize>.broadcast();
  final _outputChanges = StreamController<void>.broadcast();
  final _matches = <_FltermMatch>[];
  final _activity = TerminalActivityTracker();

  bool _cursorAnimationEnabled;
  var _disposed = false;
  var _controllerReleased = false;
  var _mountedViews = 0;
  int _lastColumns;
  int _lastRows;

  /// Whether the cursor blinks and eases between cells.
  bool get cursorAnimationEnabled => _cursorAnimationEnabled;

  @override
  Stream<Uint8List> get outgoingBytes => _outgoingBytes.stream;

  @override
  Stream<TerminalResize> get resizeEvents => _resizeEvents.stream;

  @override
  Stream<void> get outputChanges => _outputChanges.stream;

  @override
  Stream<TerminalTaskActivity> get taskActivity => _activity.changes;

  @override
  TerminalTaskActivity get currentTaskActivity => _activity.current;

  @override
  String? get currentDirectory =>
      decodeTerminalWorkingDirectory(_controller.pwd);

  @override
  void write(Uint8List bytes) {
    if (_disposed) return;
    _clipboard.add(bytes);
    _activity.receivedOutput(bytes);
    _controller.write(bytes);
    _outputChanges.add(null);
  }

  @override
  void sendInput(String text) {
    if (!_disposed && text.isNotEmpty) _controller.sendText(text);
  }

  @override
  void showKeyboard() {
    if (!_disposed) _controller.showKeyboard();
  }

  @override
  void hideKeyboard() {
    if (!_disposed) _controller.hideKeyboard();
  }

  /// Exposes flterm's key encoder for the adapter integration tests and for
  /// callers that need to send a non-text terminal key programmatically.
  void sendKey(flterm.Key key) {
    if (!_disposed) _controller.sendKey(key);
  }

  /// Applies the cursor-animation setting to the live terminal.
  void setCursorAnimation(bool enabled) {
    if (_disposed || _cursorAnimationEnabled == enabled) return;
    _cursorAnimationEnabled = enabled;
    _controller.config = _controller.config.copyWith(cursorBlink: enabled);
  }

  flterm.CellMetrics? get _cellMetrics =>
      _terminalViewKey.currentState?.cellMetrics;

  void _onResize(int columns, int rows) {
    if (_disposed || (columns == _lastColumns && rows == _lastRows)) return;
    _lastColumns = columns;
    _lastRows = rows;
    // Pixel sizes follow the renderer's measured cell metrics; zero means
    // "unknown" to the remote PTY when no view has laid out yet.
    final metrics = _cellMetrics;
    _resizeEvents.add(
      TerminalResize(
        columns: columns,
        rows: rows,
        pixelWidth: metrics == null ? 0 : (columns * metrics.cellWidth).round(),
        pixelHeight: metrics == null ? 0 : (rows * metrics.cellHeight).round(),
      ),
    );
  }

  flterm.ClipboardWriteResult _onClipboardWrite(flterm.ClipboardWrite write) {
    if (_disposed) return flterm.ClipboardWriteResult.denied;
    final content =
        write.contents.where((c) => c.mime.startsWith('text/')).firstOrNull ??
        write.contents.firstOrNull;
    final text = content == null
        ? ''
        : utf8.decode(content.data, allowMalformed: true);
    unawaited(_setHostClipboard(text).catchError((_) {}));
    return flterm.ClipboardWriteResult.success;
  }

  static Future<void> _setHostClipboard(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  static Future<String?> _getHostClipboard() async =>
      (await Clipboard.getData(Clipboard.kTextPlain))?.text;

  @override
  Widget buildView({
    bool autofocus = false,
    VoidCallback? onOpenFileManagement,
    FocusOnKeyEventCallback? onKeyEvent,
  }) => _GhosttyTerminalView(
    adapter: this,
    autofocus: autofocus,
    onOpenFileManagement: onOpenFileManagement,
    onKeyEvent: onKeyEvent,
  );

  Widget _buildTerminal({
    required flterm.TerminalTheme theme,
    required bool autofocus,
    required VoidCallback? onOpenFileManagement,
    required FocusOnKeyEventCallback? onKeyEvent,
  }) {
    // The terminal has its own selection; keep the app-wide SelectionArea
    // from competing for its drags.
    final terminal = SelectionContainer.disabled(
      child: flterm.TerminalView(
        key: _terminalViewKey,
        controller: _controller,
        scrollController: _scrollController,
        autofocus: autofocus,
        onKeyEvent: onKeyEvent,
        theme: theme,
        linkSettings: flterm.LinkSettings(
          types: const {flterm.LinkType.osc8, flterm.LinkType.text},
          onActivate: _activateLink,
        ),
      ),
    );
    return AppContextMenuRegion(
      menuBuilder: () => terminalContextMenu(
        onOpenFileManagement: onOpenFileManagement,
        hasSelection: _controller.hasSelection,
        canPaste: true,
        onCopy: _copySelectionToClipboard,
        onPaste: () => unawaited(_pasteFromClipboard()),
        onSelectAll: _controller.selectAll,
      ),
      child: terminal,
    );
  }

  /// Opens a Cmd-clicked link in the system browser. Only web and mail
  /// schemes are launched: a file path detected in remote output refers to
  /// the server's file system, and anything else (`ssh:`, custom schemes)
  /// must not be handed to arbitrary local handlers.
  void _activateLink(flterm.ActivatedLink link) {
    final uri = link.uri;
    if (uri == null) return;
    const allowed = {'http', 'https', 'mailto'};
    if (!allowed.contains(uri.scheme.toLowerCase())) return;
    unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
  }

  void _copySelectionToClipboard() {
    if (_disposed) return;
    final text = _controller.selectedText();
    if (text.isNotEmpty) {
      unawaited(Clipboard.setData(ClipboardData(text: text)));
    }
  }

  Future<void> _pasteFromClipboard() async {
    if (_disposed) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.isNotEmpty && !_disposed) {
      _controller.paste(text);
    }
  }

  @override
  int find(String query, {bool caseSensitive = false}) {
    findClear();
    if (_disposed || query.isEmpty) return 0;

    final formatter = _controller.createFormatter(
      format: flterm.FormatterFormat.plain,
      unwrap: false,
      trim: false,
    );
    try {
      final needle = caseSensitive ? query : query.toLowerCase();
      final lines = formatter.format().split('\n');
      for (var row = 0; row < lines.length; row++) {
        final line = lines[row];
        final haystack = caseSensitive ? line : line.toLowerCase();
        var from = 0;
        while (true) {
          final start = haystack.indexOf(needle, from);
          if (start < 0) break;
          _matches.add(_FltermMatch(row, start, start + needle.length));
          from = start + 1;
        }
      }
    } finally {
      formatter.dispose();
    }
    return _matches.length;
  }

  @override
  void findJump(int index) {
    if (_disposed || _matches.isEmpty) return;
    final match = _matches[index.clamp(0, _matches.length - 1)];
    _controller.selectRange(
      start: flterm.Position(row: match.row, col: match.start),
      end: flterm.Position(row: match.row, col: match.end - 1),
    );
    final rowHeight = _cellMetrics?.cellHeight ?? 0;
    if (rowHeight > 0 && _scrollController.hasClients) {
      _scrollController.jumpTo(
        (match.row * rowHeight).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        ),
      );
    }
  }

  @override
  void findClear() {
    _matches.clear();
    if (!_disposed) _controller.clearSelection();
  }

  /// Stops accepting input and output. The native terminal is released once
  /// no view is mounted any more, so a still-visible view never paints from
  /// a freed controller during the frame that unmounts it.
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _clipboard.dispose();
    _matches.clear();
    await _outgoingBytes.close();
    await _resizeEvents.close();
    await _outputChanges.close();
    await _activity.dispose();
    if (_mountedViews == 0) _releaseController();
  }

  void _viewMounted() => _mountedViews++;

  void _viewUnmounted() {
    _mountedViews--;
    if (_disposed && _mountedViews == 0) _releaseController();
  }

  void _releaseController() {
    if (_controllerReleased) return;
    _controllerReleased = true;
    _controller.dispose();
    _scrollController.dispose();
  }
}

/// The adapter's renderer, following the terminal appearance settings live
/// so a font, colour-scheme or OS light/dark change reaches open terminals.
class _GhosttyTerminalView extends ConsumerStatefulWidget {
  const _GhosttyTerminalView({
    required this.adapter,
    required this.autofocus,
    required this.onOpenFileManagement,
    required this.onKeyEvent,
  });

  final GhosttyTerminalSessionAdapter adapter;
  final bool autofocus;
  final VoidCallback? onOpenFileManagement;
  final FocusOnKeyEventCallback? onKeyEvent;

  @override
  ConsumerState<_GhosttyTerminalView> createState() =>
      _GhosttyTerminalViewState();
}

class _GhosttyTerminalViewState extends ConsumerState<_GhosttyTerminalView> {
  @override
  void initState() {
    super.initState();
    widget.adapter._viewMounted();
    widget.adapter.setCursorAnimation(ref.read(cursorAnimationEnabledProvider));
  }

  @override
  void dispose() {
    widget.adapter._viewUnmounted();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      cursorAnimationEnabledProvider,
      (_, enabled) => widget.adapter.setCursorAnimation(enabled),
    );
    final animateCursor = ref.watch(cursorAnimationEnabledProvider);
    final theme = ref
        .watch(terminalColorSchemeProvider)
        .toTerminalTheme()
        .copyWith(
          fontFamily: ref.watch(terminalFontFamilyProvider),
          fontSize: ref.watch(terminalFontSizeProvider),
          lineHeight: ref.watch(terminalLineHeightProvider),
          cursorMotionDuration: animateCursor
              ? GhosttyTerminalSessionAdapter._cursorMotionDuration
              : Duration.zero,
        );
    return widget.adapter._buildTerminal(
      theme: theme,
      autofocus: widget.autofocus,
      onOpenFileManagement: widget.onOpenFileManagement,
      onKeyEvent: widget.onKeyEvent,
    );
  }
}

class _FltermMatch {
  const _FltermMatch(this.row, this.start, this.end);

  final int row;
  final int start;
  final int end;
}
