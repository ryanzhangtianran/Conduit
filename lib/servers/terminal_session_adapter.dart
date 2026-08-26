import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:super_context_menu/super_context_menu.dart';

Menu terminalContextMenu({
  required bool hasSelection,
  required bool canPaste,
  required VoidCallback onCopy,
  required VoidCallback onPaste,
  required VoidCallback onSelectAll,
  VoidCallback? onOpenFileManagement,
}) => Menu(
  children: [
    MenuAction(
      title: 'commonCopy'.tr(),
      image: MenuImage.icon(Symbols.content_copy),
      attributes: MenuActionAttributes(disabled: !hasSelection),
      callback: onCopy,
    ),
    MenuAction(
      title: 'fileManagerPaste'.tr(),
      image: MenuImage.icon(Symbols.content_paste),
      attributes: MenuActionAttributes(disabled: !canPaste),
      callback: onPaste,
    ),
    MenuSeparator(),
    MenuAction(
      title: 'commonSelectAll'.tr(),
      image: MenuImage.icon(Symbols.select_all),
      callback: onSelectAll,
    ),
    if (onOpenFileManagement != null) ...[
      MenuSeparator(),
      MenuAction(
        title: 'sessionsOpenFileManagement'.tr(),
        image: MenuImage.icon(Symbols.folder_open),
        callback: onOpenFileManagement,
      ),
    ],
  ],
);

/// Decodes an OSC 7 working-directory report such as `file:///work/project`
/// into a filesystem path, or null when the value is not a local path.
String? decodeTerminalWorkingDirectory(String value) {
  try {
    final uri = Uri.parse(value);
    if (uri.scheme == 'file') return Uri.decodeComponent(uri.path);
  } on FormatException {
    return null;
  }
  return value.startsWith('/') ? Uri.decodeComponent(value) : null;
}

/// A terminal emulator instance attached to one remote shell.
///
/// The adapter owns emulator-specific state and rendering. SSH transport code
/// only needs to forward byte streams and react to input and resize events.
abstract interface class TerminalSessionAdapter {
  /// Bytes produced by keyboard, paste, or mouse input in the terminal.
  Stream<Uint8List> get outgoingBytes;

  /// Terminal size changes requested by the renderer.
  Stream<TerminalResize> get resizeEvents;

  /// Fires after each chunk of remote output has been displayed.
  Stream<void> get outputChanges;

  /// Task activity, including a percentage when the terminal or its command
  /// reports one.
  ///
  /// This is informed by shell-integration/progress control sequences when
  /// available, with a conservative Enter-to-prompt fallback for ordinary
  /// interactive shells.
  Stream<TerminalTaskActivity> get taskActivity;

  /// Latest task activity value.
  TerminalTaskActivity get currentTaskActivity;

  /// Current shell directory reported through OSC 7, when available.
  String? get currentDirectory;

  /// Displays bytes received from the remote shell.
  void write(Uint8List bytes);

  /// Sends text or terminal control sequences to the remote shell.
  void sendInput(String text);

  /// Shows the platform software keyboard and focuses this terminal.
  void showKeyboard();

  /// Hides the platform software keyboard without dropping terminal focus.
  void hideKeyboard();

  /// Builds this adapter's terminal renderer.
  Widget buildView({
    bool autofocus = false,
    VoidCallback? onOpenFileManagement,
    FocusOnKeyEventCallback? onKeyEvent,
  });

  /// Finds all matches for [query] in the terminal buffer. Returns the count.
  int find(String query, {bool caseSensitive = false});

  /// Jumps to the match at [index] (0-based) and highlights it.
  void findJump(int index);

  /// Clears find highlights / selection produced by [find].
  void findClear();

  /// Releases emulator-specific resources.
  Future<void> dispose();
}

/// Answers OSC 52 clipboard *queries* (`ESC ] 52 ; <sel> ; ? ST`).
///
/// libghostty decodes OSC 52 *writes* itself and hands them to the adapter,
/// but it has no read-back callback, so the query form is recognised here.
/// The recogniser is byte-oriented because a sequence can straddle SSH
/// packets; it retains at most the few bytes of a candidate sequence.
class TerminalClipboardBridge {
  TerminalClipboardBridge({
    required this._getClipboard,
    required this._sendResponse,
  });

  static const _escape = 0x1b;
  static const _bel = 0x07;
  static const _selectionChars = 'cpqs01234567';

  /// `ESC ] 5 2 ;` followed by the selection, `; ?` and a terminator.
  static const _prefix = [0x1b, 0x5d, 0x35, 0x32, 0x3b];

  final Future<String?> Function() _getClipboard;
  final void Function(String text) _sendResponse;
  final _selection = StringBuffer();
  var _stage = 0;
  var _disposed = false;

  void add(Uint8List bytes) {
    if (_disposed) return;
    for (final byte in bytes) {
      _consume(byte);
    }
  }

  void _consume(int byte) {
    if (_stage < _prefix.length) {
      if (byte == _prefix[_stage]) {
        _stage++;
      } else {
        _reset(byte);
      }
      return;
    }
    switch (_stage) {
      // Selection characters up to the second `;`.
      case 5:
        if (byte == 0x3b) {
          _stage = 6;
        } else if (_selectionChars.codeUnits.contains(byte) &&
            _selection.length < _selectionChars.length) {
          _selection.writeCharCode(byte);
        } else {
          _reset(byte);
        }
      // Only a `?` payload matters here; anything else is a write that
      // libghostty already handles.
      case 6:
        if (byte == 0x3f) {
          _stage = 7;
        } else {
          _reset(byte);
        }
      case 7:
        if (byte == _bel) {
          _finish();
        } else if (byte == _escape) {
          _stage = 8;
        } else {
          _reset(byte);
        }
      case 8:
        if (byte == 0x5c) {
          _finish();
        } else {
          _reset(byte);
        }
    }
  }

  void _reset(int byte) {
    _stage = byte == _escape ? 1 : 0;
    _selection.clear();
  }

  void _finish() {
    final selection = _selection.isEmpty ? 'c' : _selection.toString();
    _reset(0);
    unawaited(_respond(selection));
  }

  Future<void> _respond(String selection) async {
    try {
      final text = await _getClipboard() ?? '';
      if (_disposed) return;
      final encoded = base64.encode(utf8.encode(text));
      _sendResponse('\x1b]52;$selection;$encoded\x1b\\');
    } catch (_) {
      // Clipboard access is optional on headless and restricted platforms.
    }
  }

  void dispose() {
    _disposed = true;
    _reset(0);
  }
}

/// A terminal resize notification from the renderer.
class TerminalResize {
  const TerminalResize({
    required this.columns,
    required this.rows,
    required this.pixelWidth,
    required this.pixelHeight,
  });

  final int columns;
  final int rows;
  final int pixelWidth;
  final int pixelHeight;
}

/// Tracks shell activity without interpreting terminal text as command output.
///
/// OSC 133 (FinalTerm/iTerm shell integration), OSC 633 (VS Code shell
/// integration), and OSC 9;4 (Windows Terminal progress) are established
/// terminal conventions. Regular shells rarely enable these by default, so
/// pressing Enter starts the indicator and a conventional prompt ends it.
class TerminalTaskActivity {
  const TerminalTaskActivity({required this.running, this.progress});

  final bool running;

  /// Completion fraction in the inclusive 0–1 range, if known.
  final double? progress;
}

class TerminalActivityTracker {
  /// One pass over new output finds both shell-integration markers
  /// (group 1) and Windows Terminal progress reports (groups 2 and 3).
  static final _markers = RegExp(
    r'\x1b\](?:133|633);([A-D])(?:;[^\x07\x1b]*)?(?:\x07|\x1b\\)'
    r'|\x1b\]9;4;([0-3])(?:;(\d+))?(?:\x07|\x1b\\)',
  );

  /// OSC strings, CSI sequences and two-byte escapes. Colored prompts end with
  /// SGR resets and mode toggles (e.g. `❯\x1b[0m \x1b[?2004h`), so these must
  /// be stripped or the prompt pattern never matches.
  static final _escapes = RegExp(
    r'\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b\[[0-9;?:]*[ -/]*[@-~]|\x1b[@-Z\\-_]',
  );

  /// A prompt-looking final line. Deliberately narrow so ordinary command
  /// output does not report false completion.
  static final _prompt = RegExp(r'[\$#%>❯➜]\s*$');

  /// Many CLI tools render a standalone percentage without emitting a
  /// terminal progress sequence. Limited to a line ending in `%` so incidental
  /// values such as CPU usage do not hijack the tab indicator.
  static final _percentage = RegExp(r'\b(\d{1,3})%\s*$');

  static const _maxLineLength = 160;
  static const _tailLength = 512;

  final _changes = StreamController<TerminalTaskActivity>.broadcast();
  var _running = false;
  double? _progress;

  /// Unconsumed tail of the previous chunk, so a marker or prompt split
  /// across SSH packets is still recognised.
  var _tail = '';

  Stream<TerminalTaskActivity> get changes => _changes.stream;
  TerminalTaskActivity get current =>
      TerminalTaskActivity(running: _running, progress: _progress);

  /// Input containing a line ending starts a task.
  void sentInput(Uint8List bytes) {
    for (final byte in bytes) {
      if (byte == 0x0a || byte == 0x0d) {
        _setActivity(running: true);
        return;
      }
    }
  }

  void receivedOutput(Uint8List bytes) {
    if (bytes.isEmpty) return;
    final text = _tail + utf8.decode(bytes, allowMalformed: true);

    var consumedUpTo = 0;
    for (final match in _markers.allMatches(text)) {
      consumedUpTo = match.end;
      final marker = match.group(1);
      if (marker != null) {
        // C = command execution started, A/D = prompt shown / command done.
        switch (marker) {
          case 'C':
            _setActivity(running: true);
          case 'A':
          case 'D':
            _setActivity(running: false);
        }
        continue;
      }
      final state = match.group(2)!;
      final percent = int.tryParse(match.group(3) ?? '');
      _setActivity(
        running: state != '0',
        progress: state == '1' && percent != null
            ? percent.clamp(0, 100) / 100
            : null,
      );
    }

    // Fallback for shells without integration: inspect the last visible line.
    final visible = text.replaceAll(_escapes, '');
    final lineStart =
        math.max(visible.lastIndexOf('\n'), visible.lastIndexOf('\r')) + 1;
    final line = visible.substring(lineStart);
    if (line.trimRight().length <= _maxLineLength) {
      // A bare `42%` also ends in a prompt character, so test it first.
      final value = int.tryParse(_percentage.firstMatch(line)?.group(1) ?? '');
      if (value != null && value <= 100) {
        _setActivity(running: true, progress: value / 100);
      } else if (_prompt.hasMatch(line)) {
        _setActivity(running: false);
      }
    }

    // Keep what could still complete a split marker, never a consumed one.
    _tail = text.substring(math.max(consumedUpTo, text.length - _tailLength));
  }

  void _setActivity({required bool running, double? progress}) {
    final normalizedProgress = running ? progress : null;
    if (_running == running && _progress == normalizedProgress) return;
    _running = running;
    _progress = normalizedProgress;
    if (!_changes.isClosed) _changes.add(current);
  }

  Future<void> dispose() => _changes.close();
}

abstract interface class TerminalSessionAdapterFactory {
  /// Creates an adapter whose emulator starts at the PTY size the transport
  /// requested, so output arriving before the first layout wraps correctly.
  TerminalSessionAdapter create({required int columns, required int rows});
}

/// Wires a terminal adapter to one shell's byte streams without coupling the
/// adapter contract to a specific SSH implementation.
class TerminalSessionBinding {
  TerminalSessionBinding({
    required this.adapter,
    required Stream<Uint8List> stdout,
    required Stream<Uint8List> stderr,
    required void Function(Uint8List bytes) send,
    required void Function(TerminalResize resize) resize,
    this.outputFlushDelay = const Duration(milliseconds: 8),
  }) : // Public parameter names preserve the adapter binding API.
       // ignore: prefer_initializing_formals
       _send = send,
       // ignore: prefer_initializing_formals
       _resize = resize,
       _subscriptions = [] {
    _subscriptions.addAll([
      stdout.listen(_queueTerminalOutput, onError: _ignoreTransportError),
      stderr.listen(_queueTerminalOutput, onError: _ignoreTransportError),
      adapter.outgoingBytes.listen(_sendTerminalInput),
      adapter.resizeEvents.listen(_resizeTerminal),
    ]);
  }

  final TerminalSessionAdapter adapter;
  final void Function(Uint8List bytes) _send;
  final void Function(TerminalResize resize) _resize;
  final List<StreamSubscription<Object?>> _subscriptions;
  final Duration outputFlushDelay;
  final _outputBuffer = BytesBuilder(copy: false);
  Timer? _outputFlushTimer;
  var _closed = false;

  // SSH channel streams can report an error while their terminal is being
  // closed. The owner observes shell completion and tears this binding down,
  // so forwarding that late error into Flutter's root zone would only crash
  // the app after a normal `exit`.
  void _ignoreTransportError(Object error, StackTrace stackTrace) {}

  void _sendTerminalInput(Uint8List bytes) {
    if (_closed) return;
    try {
      _send(bytes);
    } catch (_) {
      // The SSH channel can close between delivering input and teardown.
    }
  }

  void _resizeTerminal(TerminalResize resize) {
    if (_closed) return;
    try {
      _resize(resize);
    } catch (_) {
      // See [_sendTerminalInput].
    }
  }

  /// Batch high-frequency remote output without delaying local key presses.
  ///
  /// An 8ms cap keeps interactive echo effectively immediate while preventing
  /// a burst (for example, `cat` or a build log) from forcing one terminal
  /// update per SSH packet. Large bursts bypass the timer to bound memory.
  void _queueTerminalOutput(Uint8List bytes) {
    if (_closed || bytes.isEmpty) return;
    _outputBuffer.add(bytes);
    if (_outputBuffer.length >= 16 * 1024) {
      _flushTerminalOutput();
      return;
    }
    _outputFlushTimer ??= Timer(outputFlushDelay, _flushTerminalOutput);
  }

  void _flushTerminalOutput() {
    _outputFlushTimer?.cancel();
    _outputFlushTimer = null;
    if (_closed || _outputBuffer.length == 0) return;
    adapter.write(_outputBuffer.takeBytes());
  }

  /// Stops forwarding and disposes the adapter.
  Future<void> close() async {
    if (_closed) return;
    _flushTerminalOutput();
    _closed = true;
    _outputFlushTimer?.cancel();
    await Future.wait(
      _subscriptions.map((subscription) => subscription.cancel()),
    );
    await adapter.dispose();
  }
}
