import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flterm/flterm.dart' as flterm;
import 'package:conduit/servers/ghostty_terminal_session_adapter.dart';
import 'package:conduit/servers/server_providers.dart';
import 'package:conduit/servers/terminal_appearance_preferences.dart';
import 'package:conduit/servers/terminal_color_scheme.dart';
import 'package:super_context_menu/super_context_menu.dart';
import 'package:conduit/servers/terminal_session_adapter.dart';

final _escape = String.fromCharCode(0x1b);
final _delete = String.fromCharCode(0x7f);

void main() {
  test('clamps and holds the terminal font size', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(terminalFontSizeProvider), kTerminalFontSizeDefault);

    await container.read(terminalFontSizeProvider.notifier).setFontSize(18);
    expect(container.read(terminalFontSizeProvider), 18);

    // Out-of-range values are clamped rather than stored raw.
    await container.read(terminalFontSizeProvider.notifier).setFontSize(99);
    expect(container.read(terminalFontSizeProvider), kTerminalFontSizeMax);
  });

  test('keeps separate light and dark terminal themes', () async {
    final container = ProviderContainer(
      overrides: [
        terminalAppearancePreferencesProvider.overrideWithValue(
          const TerminalAppearancePreferences(
            lightTheme: TerminalColorSchemes.catppuccinLatte,
            darkTheme: TerminalColorSchemes.nord,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(terminalLightThemeProvider),
      TerminalColorSchemes.catppuccinLatte,
    );
    expect(
      container.read(terminalDarkThemeProvider),
      TerminalColorSchemes.nord,
    );

    await container
        .read(terminalDarkThemeProvider.notifier)
        .save(TerminalColorSchemes.dracula);

    expect(
      container.read(terminalDarkThemeProvider),
      TerminalColorSchemes.dracula,
    );
    expect(
      container.read(terminalLightThemeProvider),
      TerminalColorSchemes.catppuccinLatte,
    );
  });

  test('resolves the terminal palette from the app brightness', () async {
    const settings = TerminalAppearancePreferences(
      lightTheme: TerminalColorSchemes.catppuccinLatte,
      darkTheme: TerminalColorSchemes.nord,
    );
    for (final (brightness, expected) in [
      (Brightness.light, TerminalColorSchemes.catppuccinLatte),
      (Brightness.dark, TerminalColorSchemes.nord),
    ]) {
      final container = ProviderContainer(
        overrides: [
          terminalAppearancePreferencesProvider.overrideWithValue(settings),
          appBrightnessProvider.overrideWithValue(brightness),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(terminalColorSchemeProvider), expected);
    }
  });

  test('clamps the terminal line height', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(terminalLineHeightProvider),
      kTerminalLineHeightDefault,
    );

    await container
        .read(terminalLineHeightProvider.notifier)
        .setLineHeight(1.25);
    expect(container.read(terminalLineHeightProvider), 1.25);

    await container.read(terminalLineHeightProvider.notifier).setLineHeight(9);
    expect(container.read(terminalLineHeightProvider), kTerminalLineHeightMax);
  });

  test('holds the terminal font family', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(terminalFontFamilyProvider),
      TerminalFonts.defaultFamily,
    );

    await container
        .read(terminalFontFamilyProvider.notifier)
        .setFontFamily('Fira Code');

    expect(container.read(terminalFontFamilyProvider), 'Fira Code');
  });

  test('dedupes font variants into a single regular entry per family', () {
    final options = TerminalFonts.dedupe(const [
      'SFMono-Regular',
      'SFMono-Bold',
      'SFMono-Light',
      'Menlo',
      'JetBrainsMono-Regular',
      'JetBrainsMono-BoldItalic',
      'JetBrainsMono-Medium',
      'AndaleMono',
    ]);

    final byLabel = {for (final option in options) option.label: option};
    expect(byLabel['SFMono']?.family, 'SFMono-Regular');
    expect(byLabel['JetBrainsMono']?.family, 'JetBrainsMono-Regular');
    expect(byLabel['Menlo']?.family, 'Menlo');
    expect(byLabel['AndaleMono']?.family, 'AndaleMono');
    expect(options, hasLength(4));
  });

  test('strips only the trailing variant from multi-dash family names', () {
    final options = TerminalFonts.dedupe(const [
      'MapleMono-NF-CN-Regular',
      'MapleMono-NF-CN-ExtraLight',
      'MapleMono-NF-CN-ExtraLightItalic',
      'MapleMono-NF-CN-Bold',
      'MapleMono-NF-Regular',
      'MapleMono-NF-Bold',
    ]);

    final byLabel = {for (final option in options) option.label: option};
    expect(byLabel['MapleMono-NF-CN']?.family, 'MapleMono-NF-CN-Regular');
    expect(byLabel['MapleMono-NF']?.family, 'MapleMono-NF-Regular');
    expect(options, hasLength(2));
  });

  test('collapses compound and width/style variants', () {
    final options = TerminalFonts.dedupe(const [
      'FiraCodeNerdFont-Regular',
      'FiraCodeNerdFont-Retina',
      'CaskaydiaMonoNerdFont-Regular',
      'CaskaydiaMonoNerdFont-SemiLight',
      'CaskaydiaMonoNerdFont-SemiLightItalic',
      'MartianMonoNerdFont-Regular',
      'MartianMonoNerdFont-CondensedBold',
      'MartianMonoNerdFont-CondensedRegular',
      'BlexMonoNerdFont-Regular',
      'BlexMonoNerdFont-Text',
      'BlexMonoNerdFont-TextItalic',
      'BlexMonoNerdFont-ExtraLightItalic',
    ]);

    final byLabel = {for (final option in options) option.label: option};
    expect(byLabel['FiraCodeNerdFont']?.family, 'FiraCodeNerdFont-Regular');
    expect(
      byLabel['CaskaydiaMonoNerdFont']?.family,
      'CaskaydiaMonoNerdFont-Regular',
    );
    expect(
      byLabel['MartianMonoNerdFont']?.family,
      'MartianMonoNerdFont-Regular',
    );
    expect(byLabel['BlexMonoNerdFont']?.family, 'BlexMonoNerdFont-Regular');
    expect(options, hasLength(4));
  });

  test('prefers a plain family file when no regular variant exists', () {
    final options = TerminalFonts.dedupe(const [
      'CascadiaCode-Bold',
      'CascadiaCode-Black',
    ]);
    expect(options, hasLength(1));
    expect(options.single.label, 'CascadiaCode');
    expect(options.single.family, 'CascadiaCode-Black');
  });

  test('a colour scheme round-trips through the flterm theme', () {
    for (final scheme in TerminalColorSchemes.all) {
      final theme = scheme.toTerminalTheme();
      expect(theme.background, scheme.background);
      expect(theme.foreground, scheme.foreground);
      expect(theme.cursor.color?.fixedColor, scheme.cursor);
      expect(theme.selection.background?.fixedColor, scheme.selection);
      expect(
        TerminalColorScheme.fromTerminalTheme(
          theme,
          id: scheme.id,
          label: scheme.label,
        ),
        scheme,
      );
    }
  });

  testWidgets('open terminals follow appearance changes live', (tester) async {
    final container = ProviderContainer(
      overrides: [appBrightnessProvider.overrideWithValue(Brightness.dark)],
    );
    addTearDown(container.dispose);
    final adapter = GhosttyTerminalSessionAdapter();
    addTearDown(adapter.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: SizedBox(width: 800, height: 600, child: adapter.buildView()),
        ),
      ),
    );
    await tester.pump();

    flterm.TerminalTheme theme() => tester
        .widget<flterm.TerminalView>(find.byType(flterm.TerminalView))
        .theme!;
    expect(theme().background, TerminalColorSchemes.defaultScheme.background);
    expect(theme().cursorMotionDuration, const Duration(milliseconds: 90));
    expect(adapter.cursorAnimationEnabled, isTrue);

    await container
        .read(terminalDarkThemeProvider.notifier)
        .save(TerminalColorSchemes.nord);
    await container.read(terminalFontSizeProvider.notifier).setFontSize(18);
    await container
        .read(terminalLineHeightProvider.notifier)
        .setLineHeight(1.3);
    await container
        .read(cursorAnimationEnabledProvider.notifier)
        .setEnabled(false);
    await tester.pump();

    expect(theme().background, TerminalColorSchemes.nord.background);
    expect(theme().foreground, TerminalColorSchemes.nord.foreground);
    expect(theme().fontSize, 18);
    expect(theme().lineHeight, 1.3);
    expect(theme().cursorMotionDuration, Duration.zero);
    expect(adapter.cursorAnimationEnabled, isFalse);
  });

  test('tracks the shell directory reported through OSC 7', () async {
    final adapter = GhosttyTerminalSessionAdapter();
    addTearDown(adapter.dispose);

    adapter.write(
      Uint8List.fromList(
        utf8.encode('$_escape]7;file:///tmp/project%20folder\x07'),
      ),
    );

    expect(adapter.currentDirectory, '/tmp/project folder');
  });

  test('terminal context menu exposes file management', () {
    var opened = false;
    final menu = terminalContextMenu(
      hasSelection: false,
      canPaste: true,
      onCopy: () {},
      onPaste: () {},
      onSelectAll: () {},
      onOpenFileManagement: () => opened = true,
    );

    final action = menu.children.whereType<MenuAction>().last;
    action.callback();
    expect(opened, isTrue);
  });

  test('Ghostty adapter encodes cursor keys for the remote shell', () async {
    final adapter = GhosttyTerminalSessionAdapter();
    final output = adapter.outgoingBytes.first;

    adapter.sendKey(flterm.Key.arrowUp);

    expect(utf8.decode(await output), '$_escape[A');
    await adapter.dispose();
  });

  test('Ghostty adapter encodes backspace for the remote shell', () async {
    final adapter = GhosttyTerminalSessionAdapter();
    final output = adapter.outgoingBytes.first;

    adapter.sendKey(flterm.Key.backspace);

    expect(utf8.decode(await output), _delete);
    await adapter.dispose();
  });

  testWidgets('Ghostty adapter renders with flterm and reports its grid size', (
    tester,
  ) async {
    // Starts at the PTY size so a differing layout always reports a resize.
    final adapter = GhosttyTerminalSessionAdapter(columns: 120, rows: 36);
    final resizes = <TerminalResize>[];
    final subscription = adapter.resizeEvents.listen(resizes.add);
    addTearDown(subscription.cancel);
    addTearDown(adapter.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: SizedBox(width: 800, height: 600, child: adapter.buildView()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(flterm.TerminalView), findsOneWidget);
    expect(resizes, isNotEmpty);
    final resize = resizes.last;
    expect(resize.columns, greaterThan(0));
    expect(resize.rows, greaterThan(0));
    // Pixel sizes come from the measured cell metrics, not a fixed estimate.
    final metrics = tester
        .state<flterm.TerminalViewState>(find.byType(flterm.TerminalView))
        .cellMetrics;
    expect(resize.pixelWidth, (resize.columns * metrics.cellWidth).round());
    expect(resize.pixelHeight, (resize.rows * metrics.cellHeight).round());
  });

  testWidgets('a disposed adapter keeps its view alive until unmounted', (
    tester,
  ) async {
    final adapter = GhosttyTerminalSessionAdapter();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: SizedBox(width: 800, height: 600, child: adapter.buildView()),
        ),
      ),
    );
    await tester.pump();

    // Tear the adapter down while the view is still mounted, as happens when
    // a shell exits; the next frame must not touch a freed terminal.
    await adapter.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('terminal key callback preempts shell input shortcuts', (
    tester,
  ) async {
    final adapter = GhosttyTerminalSessionAdapter();
    var shortcutCalls = 0;
    addTearDown(adapter.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: SizedBox(
            width: 800,
            height: 600,
            child: adapter.buildView(
              autofocus: true,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent ||
                    event.logicalKey != LogicalKeyboardKey.equal) {
                  return KeyEventResult.ignored;
                }
                shortcutCalls++;
                return KeyEventResult.handled;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(flterm.TerminalView));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    expect(shortcutCalls, 1);
  });

  test('Ghostty adapter sends terminal control sequences', () async {
    final adapter = GhosttyTerminalSessionAdapter();
    final output = adapter.outgoingBytes.first;

    adapter.sendInput('\t');

    expect(utf8.decode(await output), '\t');
    await adapter.dispose();
  });

  test('OSC 52 answers clipboard queries split across packets', () async {
    final responses = <String>[];
    final bridge = TerminalClipboardBridge(
      getClipboard: () async => 'host clipboard',
      sendResponse: responses.add,
    );
    addTearDown(bridge.dispose);

    final query = Uint8List.fromList(utf8.encode('$_escape]52;c;?$_escape\\'));
    bridge.add(query.sublist(0, 6));
    bridge.add(query.sublist(6));
    await Future<void>.delayed(Duration.zero);

    final encoded = base64.encode(utf8.encode('host clipboard'));
    expect(responses, ['$_escape]52;c;$encoded$_escape\\']);
  });

  test('OSC 52 writes are left to the emulator', () async {
    final responses = <String>[];
    final bridge = TerminalClipboardBridge(
      getClipboard: () async => 'host clipboard',
      sendResponse: responses.add,
    );
    addTearDown(bridge.dispose);

    bridge.add(Uint8List.fromList(utf8.encode('$_escape]52;c;aGVsbG8=\x07')));
    await Future<void>.delayed(Duration.zero);

    expect(responses, isEmpty);
  });

  test(
    'the terminal adapter synchronizes OSC 52 with host clipboard',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final copied = <String>[];
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') {
          return <String, String>{'text': 'host clipboard'};
        }
        if (call.method == 'Clipboard.setData') {
          copied.add(
            (call.arguments as Map<Object?, Object?>)['text']! as String,
          );
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final adapter = GhosttyTerminalSessionAdapter();
      final output = adapter.outgoingBytes.first;
      adapter.write(Uint8List.fromList(utf8.encode('$_escape]52;c;?\x07')));
      expect(
        utf8.decode(await output),
        '$_escape]52;c;aG9zdCBjbGlwYm9hcmQ=$_escape\\',
      );

      // A write decoded by libghostty, split across two SSH packets.
      final sequence = Uint8List.fromList(
        utf8.encode(
          '$_escape]52;c;${base64.encode(utf8.encode('from TUI'))}\x07',
        ),
      );
      adapter.write(sequence.sublist(0, 9));
      adapter.write(sequence.sublist(9));
      await Future<void>.delayed(Duration.zero);
      await adapter.dispose();
      expect(copied, ['from TUI']);
    },
  );

  test('a colored prompt without shell integration clears activity', () async {
    final adapter = GhosttyTerminalSessionAdapter();
    addTearDown(adapter.dispose);

    // Connecting runs initial scripts, which marks a task as running.
    adapter.sendInput('export FOO=1\n');
    expect(adapter.currentTaskActivity.running, isTrue);

    // A zsh-style prompt: colored arrow, SGR reset, bracketed-paste enable.
    adapter.write(
      Uint8List.fromList(
        utf8.encode('\r\n$_escape[1;32m❯$_escape[0m $_escape[?2004h'),
      ),
    );
    expect(adapter.currentTaskActivity.running, isFalse);
  });

  test('terminal activity follows shell integration markers', () async {
    final adapter = GhosttyTerminalSessionAdapter();
    addTearDown(adapter.dispose);
    final states = <bool>[];
    final subscription = adapter.taskActivity
        .map((activity) => activity.running)
        .listen(states.add);
    addTearDown(subscription.cancel);

    // The start marker arrives split across two packets.
    adapter.write(Uint8List.fromList(utf8.encode('$_escape]13')));
    adapter.write(Uint8List.fromList(utf8.encode('3;C\x07')));
    adapter.write(Uint8List.fromList(utf8.encode('$_escape]133;D;0\x07')));
    await Future<void>.delayed(Duration.zero);

    expect(states, [true, false]);
    expect(adapter.currentTaskActivity.running, isFalse);
  });

  test('terminal activity exposes reported progress percentages', () async {
    final adapter = GhosttyTerminalSessionAdapter();
    addTearDown(adapter.dispose);
    final activities = <TerminalTaskActivity>[];
    final subscription = adapter.taskActivity.listen(activities.add);
    addTearDown(subscription.cancel);

    adapter.write(Uint8List.fromList(utf8.encode('$_escape]9;4;1;42\x07')));
    await Future<void>.delayed(Duration.zero);

    expect(adapter.currentTaskActivity.running, isTrue);
    expect(adapter.currentTaskActivity.progress, 0.42);
    expect(activities.last.progress, 0.42);
  });

  test('a bare percentage line reports progress until the prompt', () {
    final tracker = TerminalActivityTracker();
    addTearDown(tracker.dispose);

    tracker.receivedOutput(Uint8List.fromList(utf8.encode('Downloading 37%')));
    expect(tracker.current.running, isTrue);
    expect(tracker.current.progress, 0.37);

    tracker.receivedOutput(
      Uint8List.fromList(utf8.encode('\r\nuser@host \$ ')),
    );
    expect(tracker.current.running, isFalse);
    expect(tracker.current.progress, isNull);
  });

  test('forwards shell output, terminal input, and resize events', () async {
    final stdout = StreamController<Uint8List>();
    final stderr = StreamController<Uint8List>();
    final adapter = _FakeTerminalSessionAdapter();
    final sent = <Uint8List>[];
    final resizes = <TerminalResize>[];
    final binding = TerminalSessionBinding(
      adapter: adapter,
      stdout: stdout.stream,
      stderr: stderr.stream,
      send: sent.add,
      resize: resizes.add,
    );

    stdout.add(Uint8List.fromList([1, 2]));
    stderr.add(Uint8List.fromList([3]));
    adapter.emitInput(Uint8List.fromList([4]));
    const resize = TerminalResize(
      columns: 120,
      rows: 36,
      pixelWidth: 960,
      pixelHeight: 720,
    );
    adapter.emitResize(resize);
    await Future<void>.delayed(const Duration(milliseconds: 12));

    expect(adapter.received, [
      Uint8List.fromList([1, 2, 3]),
    ]);
    expect(sent, [
      Uint8List.fromList([4]),
    ]);
    expect(resizes, [resize]);

    await binding.close();
    expect(adapter.disposed, isTrue);
    await stdout.close();
    await stderr.close();
  });

  test(
    'closing a shell binding stops forwarding and disposes the adapter',
    () async {
      final stdout = StreamController<Uint8List>();
      final stderr = StreamController<Uint8List>();
      final adapter = _FakeTerminalSessionAdapter();
      var sent = 0;
      final binding = TerminalSessionBinding(
        adapter: adapter,
        stdout: stdout.stream,
        stderr: stderr.stream,
        send: (_) => sent++,
        resize: (_) {},
      );

      await binding.close();
      stdout.add(Uint8List.fromList([1]));
      await Future<void>.delayed(Duration.zero);

      expect(adapter.received, isEmpty);
      expect(sent, 0);
      expect(adapter.disposed, isTrue);
      await stdout.close();
      await stderr.close();
    },
  );
}

class _FakeTerminalSessionAdapter implements TerminalSessionAdapter {
  final received = <Uint8List>[];
  final _outgoing = StreamController<Uint8List>.broadcast();
  final _resizes = StreamController<TerminalResize>.broadcast();
  var disposed = false;

  @override
  Stream<Uint8List> get outgoingBytes => _outgoing.stream;

  @override
  Stream<TerminalResize> get resizeEvents => _resizes.stream;

  @override
  Stream<void> get outputChanges => const Stream.empty();

  @override
  Stream<TerminalTaskActivity> get taskActivity => const Stream.empty();

  @override
  TerminalTaskActivity get currentTaskActivity =>
      const TerminalTaskActivity(running: false);

  @override
  String? get currentDirectory => null;

  @override
  Widget buildView({
    bool autofocus = false,
    VoidCallback? onOpenFileManagement,
    FocusOnKeyEventCallback? onKeyEvent,
  }) => const SizedBox();

  @override
  int find(String query, {bool caseSensitive = false}) => 0;

  @override
  void findJump(int index) {}

  @override
  void findClear() {}

  @override
  Future<void> dispose() async {
    disposed = true;
    await _outgoing.close();
    await _resizes.close();
  }

  void emitInput(Uint8List bytes) => _outgoing.add(bytes);

  void emitResize(TerminalResize resize) => _resizes.add(resize);

  @override
  void write(Uint8List bytes) => received.add(bytes);

  @override
  void sendInput(String text) =>
      _outgoing.add(Uint8List.fromList(utf8.encode(text)));

  @override
  void showKeyboard() {}

  @override
  void hideKeyboard() {}
}
