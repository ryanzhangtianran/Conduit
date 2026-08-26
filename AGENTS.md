# Conduit contributor guidance

Read `docs/ARCHITECTURE.md` before making structural changes; it lists which
file owns which responsibility. `docs/TERMINAL_EMU_ADAPTER.md` and
`docs/github_integration_design.md` describe those two subsystems.

## Tech stack rules

- Use Material 3 (`ThemeData.useMaterial3`) for standard controls and theming.
- Use `hooks_riverpod` for state management. Prefer `ConsumerWidget` for read-only reactive views and `HookConsumerWidget` only when hooks are needed. Long-lived services live in providers, never in widget `State`.
- Keep feature code directly under `lib/<feature>/`; do not introduce `presentation`, `domain`, or `data` folders. A subfolder is only for a self-contained page group (e.g. `lib/servers/settings/`).
- `lib/shared` must not import from feature folders (`lib/servers`, `lib/github`).
- Use `auto_route` for navigation. Add route annotations/configuration and regenerate code with `dart run build_runner build --delete-conflicting-outputs`; never edit generated `*.g.dart` or `*.gr.dart` files.
- Store persistent data in Drift and place app-wide schema changes in `lib/data/local/app_database.dart`. Migrations are ascending `from < N` blocks; drop columns in a migration rather than leaving them orphaned.
- Use `dartssh2` for SSH behavior. Secrets go into Drift only encrypted with the vault data key via `VaultService`; never store a clear-text credential, key, or token anywhere else.
- Non-secret preferences use `PreferenceStore` / `PreferenceNotifier<T>` (`lib/shared/services/preference_store.dart`); do not add interface + in-memory preference classes.
- Serialized formats are versioned; readers accept older versions and upgrade in place. Never add a strict `version != N` check.

## Reuse before writing

- Sizes, memory, uptime, remote paths, extensions: `lib/shared/formatters.dart`.
- Dialogs: `showConduitConfirmAlert`, `showConduitErrorAlert`, `showConduitChoiceDialog`, `showConduitOverlayDialog` (`conduit_alert.dart`); passwords: `showPasswordPrompt` (`password_prompt.dart`); single-choice pickers: `ConduitDropdown`. No bottom sheets for prompts on desktop.
- Snackbars: `showStyledSnackBar` only.
- Server ↔ JSON: `ServerRecordCodec`. Add/edit server: `showServerEditor`. Connect through jump hosts: `connectSavedServer` / `SshConnectionManager.connectJumpHosts`. ssh config: `syncServersToSshConfig` and the `ssh_config_bulk.dart` helpers.
- Tab navigation: `WorkspaceTab` enum, never raw indexes.
- Long-running work with progress: `taskProgressProvider` / `AppTaskProgress`; file copies: `FileTransferQueue`.
- Remote host metrics parsing: `metrics_parsers.dart` (pure functions with tests).

## Window and layout rules

- Keep the app wrapped in `ConduitWindowScaffold`, which uses `DesktopWindowFrame` (`lib/shared/presentation/foundation/`) for desktop-native chrome.
- Preserve desktop window initialization in `main.dart` when changing startup code.
- The main workspace uses an `AutoTabsRouter` shell: `NavigationRail` on wide layouts and Material `NavigationBar` on narrow layouts.
- Put tab content in its own route page. Do not replace nested tab routing (including the settings categories) with local selected-index state.

## UI guidelines

- Make the interface quiet, functional, and desktop-oriented. Prefer standard Material 3 components and the helpers in `lib/shared/presentation/foundation/` over custom chrome.
- Use the calm theme colors defined in `theme.dart`; do not introduce gradients, glows, glass effects, decorative hero sections, or fake dashboards.
- Avoid oversized rounded corners, pill-heavy navigation, large shadows, and unnecessary cards.
- Keep spacing on a simple 4/8/12/16/24/32 scale. Use borders and contrast for hierarchy rather than effects.
- Do not add a page-level app bar to the tab workspace unless there is a clear product requirement. The window title bar and tab navigation provide the surrounding chrome.
- Keep responsive behavior intentional: rail for widths above 768 logical pixels; bottom navigation below that breakpoint.
- Every user-visible string goes through `easy_localization` with a key in all three `assets/translations/*.json` files.

## Checks

Run formatting, code generation when annotations or Drift schema change, then `flutter analyze` and `flutter test`. Removed features must be removed completely: code, schema columns, translation keys, docs, and dependencies.
