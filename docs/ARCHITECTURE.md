# Conduit architecture

Conduit is a desktop-first (macOS) Flutter application for managing SSH
servers: a live dashboard, terminals, a dual-pane SFTP file manager, process
and activity monitoring, port forwarding, GitHub Actions monitoring, and an
encrypted credential vault.

## Stack

- **Flutter + Material 3** for the application UI.
- **Riverpod 3** (`hooks_riverpod`) for state, lifecycle-aware UI state, and
  dependency wiring. Long-lived services (connection manager, port-forward
  supervisor, metrics scheduler, transfer queue) are plain classes owned by
  a `Provider` with `ref.onDispose`.
- **auto_route** for declarative, nested navigation. Generated route files
  live beside their router and must not be edited manually.
- **Drift** for the local SQLite vault database (one file per vault).
- **dartssh2** for SSH transport, remote command execution and SFTP.
- **flterm / libghostty-vt** (vendored in `packages/flterm`) for terminal
  emulation and rendering; see `TERMINAL_EMU_ADAPTER.md`.
- **window_manager** plus the vendored desktop foundation in
  `lib/shared/presentation/foundation/` (window frame, overlay registry,
  styled snackbar, sheet scaffold) for the desktop window chrome.
- **easy_localization** with `assets/translations/{en-US,zh-CN,zh-TW}.json`.

## Source layout

Features are flat and live directly under `lib/<feature>/`. A feature only
gets a subfolder when it is a self-contained group of pages (currently
`lib/servers/settings/`).

```
lib/
  main.dart                        # Bootstrap: preferences, window, ProviderScope
  app.dart                         # MaterialApp.router, vault gate, global shortcuts
  app_tray_controller.dart         # Menu-bar item and its actions (connect, quit, ...)
  theme.dart                       # Light/dark ThemeData
  data/local/app_database.dart     # Drift schema + migrations (single database class)
  routing/app_router.dart          # Route tree; `*.gr.dart` is generated
  github/                          # GitHub Actions monitoring (device-flow auth, API, pages)
  servers/                         # Everything about servers, sessions and the vault
    settings/                      # One page per settings category + shell helpers
  shared/
    formatters.dart                # formatBytes / formatUptime / path helpers (use these)
    presentation/                  # App-wide widgets: scaffold, alerts, dropdown,
                                   #   password prompt, task-progress bar
    services/                      # Tray wrapper, PreferenceStore, keychain, package info
```

`lib/shared` must not import from `lib/servers` or `lib/github`.

### `lib/servers` by responsibility

| Area | Files |
|---|---|
| Transport | `ssh_connection_manager.dart` (connect/disconnect, stats client, terminals, forwards, remote commands), `ssh_proxy_connect.dart`, `socks5_protocol.dart`, `buffered_socket_reader.dart`, `proxy_environment.dart` |
| Metrics | `metrics_parsers.dart` (pure parsers, one per OS section), `server_metrics_collector.dart`, `server_metrics_refresh_scheduler.dart`, `activity_history_provider.dart` |
| Persistence | `server_repository.dart`, `server_models.dart`, `server_record_codec.dart` (the one `Server` ↔ JSON mapping used by export, import and backup) |
| Vault & secrets | `vault_service.dart`, `vault_gate.dart`, `vault_create_page.dart`, `vault_file_storage.dart`, `vault_import.dart`, `database_backup_service.dart`, `icloud_backup_service.dart` |
| SSH keys & ssh config | `ssh_key_service.dart`, `ssh_key_setup_service.dart`, `ssh_key_setup_dialog.dart`, `ssh_config_sync.dart`, `ssh_config_bulk.dart`, `ssh_key_preferences.dart` |
| Import / export | `connection_export_service.dart`, `connection_import_service.dart`, `connection_import_adapters.dart`, `connection_import_sheet.dart` |
| Port forwarding | `port_forward_supervisor.dart` (keep-alive presets, per-preset status), `port_forwarding_models.dart`, `port_forwarding_page.dart` |
| Terminal | `terminal_session_adapter.dart` (adapter contract, activity tracker, OSC 52), `ghostty_terminal_session_adapter.dart`, `terminal_tabs_provider.dart`, `terminal_appearance_preferences.dart`, `terminal_color_scheme.dart`, `terminal_find_host.dart`, `terminal_command_palette.dart`, `sessions_page.dart` |
| File manager | `file_system_backend.dart` (local + SFTP behind one interface), `file_transfer_queue.dart` (+ `_provider`), `file_management_models.dart`, `file_management_tab.dart`, `file_management_widgets.dart`, `file_management_menus.dart`, `file_management_dialogs.dart`, `file_editor_tab.dart`, `structured_document.dart` |
| Pages | `server_workspace_page.dart` (tab shell, `WorkspaceTab` enum), `servers_page.dart` (dashboard), `server_editor_dialog.dart`, `connections_page.dart`, `monitor_page.dart` + `server_detail_page.dart` + `activity_tab.dart` + `server_processes_provider.dart`, `settings_page.dart` + `settings/` |
| Wiring | `server_providers.dart` (repositories, services, preference notifiers), `server_connection_actions.dart` (UI-level connect/open helpers and auth-failure prose), `startup_connection_bootstrap.dart` |

## Navigation

`AppRouter` owns the top-level routes. `ServerWorkspacePage` is an
`AutoTabsRouter` shell whose tabs are enumerated by `WorkspaceTab`
(dashboard, terminal, monitor, connections, github, portForwarding,
settings) — never use raw tab indexes. Tabs that push detail pages
(dashboard, connections, github) are `EmptyShellRoute`s so the pushed page
stays inside the tab's stack. `SettingsRoute` is itself a nested
`AutoTabsRouter` with one child route per category.

When changing routes:

1. Add `@RoutePage()` to the page.
2. Update `lib/routing/app_router.dart`.
3. Run `dart run build_runner build --delete-conflicting-outputs`.
4. Never hand-edit `*.g.dart` or `*.gr.dart` files.

## Persistence and secrets

`AppDatabase` is the single Drift database; one SQLite file per vault. Keep
tables and migrations there and bump `schemaVersion` with an ascending
`from < N` block per step. Repositories expose feature-focused queries;
providers construct repositories and expose UI-friendly streams.

Secrets (server passwords/private keys, proxy passwords, GitHub tokens) are
stored in Drift **only** encrypted with the vault data key
(`VaultService.encrypt/decrypt` with a per-purpose context). The data key is
wrapped by a PBKDF2-derived key from the vault password; biometric unlock
keeps a copy of the data key in the keychain. Nothing else may be written to
disk in clear text except the derived `~/.ssh/conduit_*` key files that
`SshKeyService` manages (the vault copy is the source of truth).

Preferences that are not secrets (font, intervals, startup behaviour) go
through `PreferenceStore` / `PreferenceNotifier<T>` in
`lib/shared/services/preference_store.dart`; do not add another
`*_preferences.dart` interface/in-memory pair.

Serialized formats (`.conduit` backups, which still read the legacy `.mkb`
files; Conduit JSON/CSV exports; portable secrets envelopes) are versioned; readers accept every version up to the
current one and upgrade in place. Never reject an older version outright.

## Long-running work

- SSH connect/disconnect is race-safe per server (a second `connect` joins
  the in-flight one; `disconnect` cancels it). Terminals own their own
  transport; the stats client dropping does not close them.
- File transfers run in the app-owned `FileTransferQueue` and report to the
  global `taskProgressProvider`; closing a file-manager tab does not cancel
  them.
- `PortForwardSupervisor` restarts keep-alive presets and exposes
  `statusOf(configId)`; pages must read that instead of inferring status.
- Terminal adapters are created by `TerminalTabsNotifier`, not by the
  connection manager, and are torn down only after their view unmounts.
- Updates: `UpdateService` (`lib/shared/services/update_service.dart`)
  reads the latest GitHub release (`/releases/latest`, unauthenticated) and
  compares it with the running `PackageInfo.version`; `availableUpdateProvider`
  holds the result, the checking flag and download progress for both the
  About page and the launch-time hook in `StartupConnectionBootstrap`
  (5 s after the workspace shows, when `autoCheckUpdates` is on and no check
  ran in the last 6 hours). Installing downloads `Conduit.dmg` to a temp
  directory, spawns a detached `/bin/sh` script that waits for this pid to
  exit, mounts the image, copies the bundle beside the current one and swaps
  it in, strips quarantine and relaunches (log:
  `~/Library/Logs/Conduit/update.log`), then quits through
  `AppTrayController.quit()` so sessions and forwards close cleanly.

## Validation

Run these before handing off changes:

```sh
dart format lib test
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```
