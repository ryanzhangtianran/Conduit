# Terminal emulator adapters

## Purpose

Conduit uses `dartssh2` for SSH transport and a selectable terminal-emulator
adapter for rendering. Ghostty (`libghostty-vt`) is the default adapter; xterm
remains available as a fallback in Settings. The selected adapter is saved in
`shared_preferences` and applies to newly opened terminals.

## Target boundary

Introduce a small terminal adapter contract in `lib/servers/`:

- `TerminalSessionAdapter` owns one terminal emulator instance for one SSH
  shell.
- It accepts incoming bytes from `SSHSession.stdout` and `stderr`.
- It exposes outgoing terminal bytes for `SSHSession.write`.
- It reports column/row and pixel resize events for
  `SSHSession.resizeTerminal`.
- It owns terminal-specific cleanup and exposes a renderer widget or render
  state to the Sessions UI.

`SshConnectionManager` remains transport-only: it opens the authenticated
`SSHSession`, wires its streams to an adapter, and closes all shells when the
parent SSH client disconnects. `SessionsPage` receives an adapter-backed view
and must not import a concrete emulator package.

## Current adapters

### Ghostty (default)

`GhosttyTerminalSessionAdapter` uses libghostty for VT parsing, screen state,
10,000-line scrollback, PTY callbacks, and resize handling. Its Flutter grid
renderer uses a desktop monospace stack, reserves content padding, and renders
the terminal cursor plus per-cell ANSI and truecolor foreground/background
styles. It supports wheel scrollback, pointer text selection, Cmd/Ctrl+C copy,
Cmd/Ctrl+V paste, and native IME composition/commit.

It is not feature-parity complete: terminal mouse reporting, bracketed paste,
and full keyboard-protocol support remain to be implemented and evaluated.

### xterm (fallback)

`XtermTerminalSessionAdapter` preserves the established Flutter xterm
renderer, `xterm-256color` PTY type, UTF-8 decoding, and 10,000-line
scrollback. Select it in Settings → Terminal renderer before opening a new
terminal.

## Adding an adapter

Implement `TerminalSessionAdapter`, create a `TerminalSessionAdapterFactory`,
and register a `TerminalSessionAdapterOption` in
`terminalSessionAdapterOptionsProvider`. The option appears in Settings
automatically. Adapter factories can also be overridden in Riverpod tests.

## Acceptance criteria for the extraction

- Connecting, disconnecting, host-key verification, and saved-server behavior
  are unchanged.
- A terminal adapter can be replaced through provider overrides in tests.
- Terminal integration tests cover output forwarding, keyboard input, resize,
  shell closure, and cleanup on SSH disconnect.
- The Sessions UI contains no emulator-specific imports.
