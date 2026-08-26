# Conduit

<p align="center">
  <img src="assets/icons/icon-padded.png" width="120" alt="Conduit Logo">
</p>

<p align="center">
  <b>An SSH server manager for macOS</b>
</p>

<p align="center">
  <a href="LICENSE.txt"><img src="https://img.shields.io/badge/license-AGPL--3.0-blue" alt="License"></a>
  <a href="https://github.com/ryanzhangtianran/Conduit/releases"><img src="https://img.shields.io/github/v/release/ryanzhangtianran/Conduit" alt="Release"></a>
</p>

<p align="center">
  English · <a href="README_ZH.md">简体中文</a>
</p>

Connections, terminals, file management, monitoring and port forwarding for
your SSH servers in one native macOS window. Everything works over plain SSH —
nothing is installed on the server.

## Install

Download `Conduit.dmg` from the
[latest release](https://github.com/ryanzhangtianran/Conduit/releases/latest),
open it and drag Conduit into **Applications**.

The build is not notarized: on first launch right-click the app and choose
**Open**.

## Usage

**Vault** — On first launch create a vault password. Every credential is
stored encrypted; unlock with the password or Touch ID
(*Settings → Security*).

**Servers** — *Dashboard → Add server*: host, user, password or private key,
optional jump host and HTTP/SOCKS5 proxy. The dashboard shows latency, load,
memory, GPU and uptime for connected servers. Generate a key pair and install
it on the server from the editor's *SSH key* section. *Connections* lists
servers alongside your `~/.ssh/config` hosts and syncs both ways.

**Terminal** — *Terminal* tab, pick a server. Tabs, sidebar, ⌘F find,
⌘-click links, native copy/paste. *Shift+Tab* opens the command palette. Font,
size, line height and colour schemes live in *Settings → Terminal*.

**Files** — Open a server's file manager from the terminal sidebar or the
palette: dual pane (local or another server on the left, the server on the
right), drag and drop, copy/cut/paste across panes, archive/unarchive, and an
in-app editor for text/JSON/YAML/TOML. Transfers run in the background with
pause and cancel.

**Monitor** — Live CPU, memory, GPU, network and disk charts plus a process
list with kill.

**Port forwarding** — Local, remote and SOCKS5 tunnels. Save presets that
auto-start on connect and keep themselves alive; the table shows traffic per
forward.

**GitHub** — Sign in with the device flow, pin repositories and watch
Actions runs; failures show as a badge on the tab.

**Backups** — *Settings → Sync*: export/import connections as a Conduit file
or CSV, write an encrypted `.conduit` backup of the whole vault, or keep the
ten newest backups in iCloud Drive.

**Menu bar** — The tray icon shows connection status and lets you connect,
open a terminal, toggle forwards and quit. Closing the window hides it;
sessions keep running.

**Updates** — *Settings → About* checks GitHub Releases for a newer
version (also shortly after launch, at most every six hours; switchable
off) and can download the DMG, replace the app in place and relaunch.

## Build from source

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d macos
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the code layout.

## License

[AGPL-3.0](LICENSE.txt). Conduit started from
[MaidKit](https://github.com/Solsynth/MaidKit) by LittleSheep / Solsynth;
that attribution is retained as the license requires.
