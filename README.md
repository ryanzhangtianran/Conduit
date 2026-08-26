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

---

Conduit is a native macOS app for managing SSH servers: connections, terminals,
port forwarding, file management, and system monitoring in one place.
Day-to-day management is 100% SSH-based — nothing is installed on your servers.

Based on [Solsynth MaidKit](https://github.com/Solsynth/MaidKit).

---

## Features

### Connections

- Server dashboard with live status, SSH round-trip latency, load, memory, GPU, and uptime
- Credentials stored inside each server: password or private key, never echoed back
- **Jump hosts** (chainable) and per-server **HTTP CONNECT / SOCKS5 proxies**
- Two-way sync with the local `~/.ssh/config`: manage Host entries in a table,
  write saved servers into the config, or import hosts from it
- Import/export as Conduit files; whole-vault encrypted `.conduit` backups

### SSH Keys

- One-click key pair generation (`ed25519` / `rsa` / `ecdsa`) with the public
  key installed on the server over the live session — works through jump hosts
- Idempotent per server and type: regenerating replaces the pair locally and
  drops the stale line from the server's `authorized_keys`
- Configurable local/remote storage paths with correct permissions (600/644/700)

### Terminal

- libghostty-vt renderer with per-app font, font size, and line height
- Session sidebar, activity indicator, working-directory tracking
- Full Nerd Font glyph rendering
- ⌘-click URLs (plain text or OSC 8 hyperlinks) to open them in the browser

### Port Forwarding

- Local, remote, and SOCKS5 tunnels
- Presets that auto-start on connect and are supervised back to life when they drop
- A single manager table: status, active connections, and live traffic per forward

### Monitoring

- Live activity charts: CPU, memory, GPU (via `nvidia-smi`), network, disk
- Per-server processes, file management (dual-pane SFTP with in-app editor)

### Security

- AES-GCM 256-bit encrypted credential vault, PBKDF2 key derivation
- Touch ID unlock
- Encrypted backups to iCloud Drive, restorable on any of your Macs

---

## Installation

Download `Conduit.dmg` from the
[latest release](https://github.com/ryanzhangtianran/Conduit/releases), mount
it, and drag Conduit into Applications.

> On first launch macOS may warn about an unverified developer — right-click
> the app and choose **Open** (this build is not notarized).

---

## Building from Source

Requires the [Flutter SDK](https://flutter.dev) (^3.12.2) on macOS.

```bash
flutter pub get
flutter run -d macos          # debug
flutter build macos --release # release build
```

After changing route annotations or the Drift schema:

```bash
dart run build_runner build
```

Checks before committing:

```bash
dart format lib test
flutter analyze
flutter test
```

---

## Architecture

Features live flat under `lib/<feature>/`:

- **Riverpod** for state management
- **auto_route** for navigation
- **Drift** (SQLite) for persistence
- **dartssh2** for SSH
- **flterm / libghostty-vt** for the terminal (vendored in `packages/`)

---

## Licensing

This project is licensed under the GNU Affero General Public License v3.0
(AGPL-3.0). If you deploy, fork, or redistribute modified versions, you must
comply with its terms, including preserving copyright notices and providing
corresponding source code.

Conduit is based on MaidKit; original authorship and copyright attribution to
LittleSheep, Solsynth, and that project's contributors are retained where
applicable. See [LICENSE.txt](./LICENSE.txt) for the full text.
