import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'terminal_session_adapter.dart';

/// Wraps a [TerminalSessionAdapter] view with Cmd/Ctrl+F find UI and
/// terminal-level shortcut handling.
class TerminalFindHost extends StatefulWidget {
  const TerminalFindHost({
    super.key,
    required this.adapter,
    this.autofocus = false,
    this.onKeyEvent,
    this.onOpenFileManagement,
  });

  final TerminalSessionAdapter adapter;
  final bool autofocus;
  final FocusOnKeyEventCallback? onKeyEvent;
  final VoidCallback? onOpenFileManagement;

  @override
  State<TerminalFindHost> createState() => _TerminalFindHostState();
}

class _TerminalFindHostState extends State<TerminalFindHost> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  var _open = false;
  var _matchCount = 0;
  var _matchIndex = 0;
  var _caseSensitive = false;
  StreamSubscription<void>? _outputSubscription;
  Timer? _refreshTimer;

  /// Wait for a burst of output to settle before searching the buffer again.
  static const _refreshDelay = Duration(milliseconds: 150);

  @override
  void initState() {
    super.initState();
    _watchOutput();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _outputSubscription?.cancel();
    widget.adapter.findClear();
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TerminalFindHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.adapter, widget.adapter)) {
      oldWidget.adapter.findClear();
      _watchOutput();
      _rematch();
    }
  }

  void _watchOutput() {
    _outputSubscription?.cancel();
    _outputSubscription = widget.adapter.outputChanges.listen((_) {
      if (!_open || _query.text.isEmpty) return;
      _refreshTimer?.cancel();
      _refreshTimer = Timer(_refreshDelay, _refresh);
    });
  }

  void _openFind() {
    setState(() => _open = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
    _rematch();
  }

  void _closeFind() {
    _refreshTimer?.cancel();
    widget.adapter.findClear();
    setState(() {
      _open = false;
      _matchCount = 0;
      _matchIndex = 0;
    });
  }

  /// Searches from the first match, as after the query changed.
  void _rematch() => _search(0);

  /// Re-runs the current query after new output, keeping the position.
  void _refresh() {
    if (mounted && _open) _search(_matchIndex);
  }

  void _search(int preferredIndex) {
    final query = _query.text;
    if (query.isEmpty) {
      widget.adapter.findClear();
      setState(() {
        _matchCount = 0;
        _matchIndex = 0;
      });
      return;
    }
    final count = widget.adapter.find(query, caseSensitive: _caseSensitive);
    final index = count == 0 ? 0 : preferredIndex.clamp(0, count - 1);
    setState(() {
      _matchCount = count;
      _matchIndex = index;
    });
    if (count > 0) widget.adapter.findJump(index);
  }

  void _next() {
    if (_matchCount == 0) return;
    final next = (_matchIndex + 1) % _matchCount;
    setState(() => _matchIndex = next);
    widget.adapter.findJump(next);
  }

  void _previous() {
    if (_matchCount == 0) return;
    final previous = (_matchIndex - 1 + _matchCount) % _matchCount;
    setState(() => _matchIndex = previous);
    widget.adapter.findJump(previous);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): _openFind,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _openFind,
        // Only intercept navigation keys while find is open so Enter still
        // reaches the shell during normal session use.
        if (_open) ...{
          const SingleActivator(LogicalKeyboardKey.escape): _closeFind,
          const SingleActivator(LogicalKeyboardKey.enter): _next,
          const SingleActivator(LogicalKeyboardKey.enter, shift: true):
              _previous,
          const SingleActivator(LogicalKeyboardKey.f3): _next,
          const SingleActivator(LogicalKeyboardKey.f3, shift: true): _previous,
        },
      },
      child: Focus(
        autofocus: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_open)
              Material(
                color: scheme.surfaceContainerHigh,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
                  child: Row(
                    children: [
                      const Icon(Symbols.search, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _query,
                          focusNode: _focus,
                          autofocus: true,
                          style: Theme.of(context).textTheme.bodyMedium,
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: 'terminalFindInTerminal'.tr(),
                          ),
                          onChanged: (_) => _rematch(),
                          onSubmitted: (_) => _next(),
                        ),
                      ),
                      Text(
                        _matchCount == 0
                            ? 'terminalNoResults'.tr()
                            : '${_matchIndex + 1} / $_matchCount',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(width: 4),
                      FilterChip(
                        label: Text('terminalCaseSensitive'.tr()),
                        selected: _caseSensitive,
                        visualDensity: VisualDensity.compact,
                        onSelected: (value) {
                          setState(() => _caseSensitive = value);
                          _rematch();
                        },
                      ),
                      IconButton(
                        tooltip: 'terminalPreviousMatch'.tr(),
                        onPressed: _matchCount == 0 ? null : _previous,
                        icon: const Icon(Symbols.keyboard_arrow_up, size: 20),
                      ),
                      IconButton(
                        tooltip: 'terminalNextMatch'.tr(),
                        onPressed: _matchCount == 0 ? null : _next,
                        icon: const Icon(Symbols.keyboard_arrow_down, size: 20),
                      ),
                      IconButton(
                        tooltip: 'commonClose'.tr(),
                        onPressed: _closeFind,
                        icon: const Icon(Symbols.close, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: widget.adapter.buildView(
                autofocus: widget.autofocus,
                onOpenFileManagement: widget.onOpenFileManagement,
                onKeyEvent: widget.onKeyEvent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
