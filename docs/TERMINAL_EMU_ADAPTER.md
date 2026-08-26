# Terminal emulation

## Overview

Conduit renders remote shells with one terminal emulator: Ghostty
(`libghostty-vt`) through the vendored `packages/flterm` fork. `dartssh2`
provides the SSH transport. The two meet at a small adapter contract in
`lib/servers/terminal_session_adapter.dart`; nothing above that contract
imports an emulator package, and the transport layer knows nothing about
rendering.

## Transport / adapter boundary

```
SshConnectionManager.openTerminal()  ->  TerminalTransport (bytes in/out,
                                          resize, done, close)
TerminalTabsNotifier.open()          ->  TerminalSessionAdapterFactory.create()
                                          + TerminalSessionBinding(adapter, transport)
TerminalTab.terminal                 ->  adapter.buildView() inside TerminalFindHost
```

- `SshConnectionManager` is transport-only. `openTerminal` authenticates,
  opens a `xterm-256color` PTY at 120x36 and returns a `TerminalTransport`:
  `stdout`/`stderr` streams, `write(bytes)`, `resize(cols, rows, px, py)`, a
  `done` future that completes when the shell ends, and `close()`. The
  manager releases the SSH client when the shell ends or `close()` is called;
  it never creates or disposes an adapter and does not import the adapter
  file.
- `TerminalTabsNotifier` (`terminal_tabs_provider.dart`) owns terminal
  lifetime. It creates the adapter through
  `terminalSessionAdapterFactoryProvider`, sized like the PTY, and wires it
  to the transport with `TerminalSessionBinding`, which batches output in
  8 ms windows and forwards input and resize events.
- `TerminalSessionAdapter` is the emulator contract: `write`, `sendInput`,
  `outgoingBytes`, `resizeEvents`, `outputChanges`, task activity, the OSC 7
  working directory, keyboard show/hide, find, `buildView` and `dispose`.

### Teardown order

Both a user close and a shell ending (`exit`, logout, SSH drop) go through
`TerminalTabsNotifier._closeTerminal`: the tab is removed from state first,
the frame that unmounts its view is allowed to finish, then the binding is
closed (disposing the adapter) and the transport is closed. The Ghostty
adapter additionally defers releasing the native terminal until its view has
unmounted, so a still-visible view never paints from a freed controller.
`closeAll()` closes every tab the same way and is what the quit path calls.

## The Ghostty adapter

`GhosttyTerminalSessionAdapter` wraps a flterm `TerminalController`:

- **Scrollback** is a byte budget (`scrollbackLimit`, 10 MiB), not a line
  count.
- **Appearance** is applied by the adapter's view, a `ConsumerStatefulWidget`
  that watches the colour-scheme, font family/size, line-height and
  cursor-animation providers. Settings changes and the OS light/dark switch
  therefore reach open terminals immediately; flterm's `TerminalView`
  re-measures cell metrics on font changes. `TerminalColorScheme` (the
  persisted, Settings-editable palette) converts with `toTerminalTheme()`.
- **Resize** events carry the grid size plus pixel sizes computed from the
  measured cell metrics. The emulator starts at the PTY size so output that
  arrives before the first layout wraps correctly.
- **Clipboard**: libghostty decodes OSC 52 / iTerm2 copy requests and hands
  them to `TerminalController.onClipboardWrite` (a small fork addition). Only
  the OSC 52 *query* form (`?`), which libghostty cannot answer, is recognised
  by `TerminalClipboardBridge`.
- **Activity indicator**: `TerminalActivityTracker` makes one pass over each
  output chunk with precompiled patterns for OSC 133/633 and OSC 9;4, then
  checks the last visible line for a prompt or a bare percentage. Input
  containing a line ending marks a task as started.
- **Find** searches the plain-text buffer, highlights via the controller's
  selection and scrolls by the real row height. `TerminalFindHost` re-runs the
  query (debounced) when output arrives while the find bar is open.

flterm itself handles keyboard encoding, IME composition, bracketed paste,
mouse tracking and reporting, selection and copy shortcuts, cursor blink and
motion, and scrollback rendering.

## flterm fork notes

`packages/flterm` is a local fork kept close to upstream. Conduit's additions
are: `TerminalController.onClipboardWrite`, `TerminalViewState.cellMetrics`,
and `lineHeight` participating in `TerminalTheme` equality/`copyWith` and in
the view's metric re-measure. The link-detection subsystem (`src/links/`) is
wired up by the Ghostty adapter: OSC 8 and plain-text URLs are highlighted
on hover with ⌘ held and ⌘-click opens `http`/`https`/`mailto` links in the
browser (file paths are ignored — they refer to the remote host). Kitty
graphics rendering is unused but deliberately kept so the fork stays
mergeable with upstream.

## Tests

`terminalSessionAdapterFactoryProvider` and `connectionManagerProvider` are
overridden in tests to substitute a fake adapter and a fake transport
(`test/terminal_tabs_provider_test.dart`). Adapter behaviour (key encoding,
OSC 52, activity, live appearance, resize metrics, dispose ordering) is
covered in `test/terminal_session_adapter_test.dart`. Appearance settings
tests use `TerminalAppearancePreferences` without a backing store.
