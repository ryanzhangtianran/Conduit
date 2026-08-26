# Web server adapters

Conduit manages remote reverse proxies / web servers through a small adapter
contract. Adapters are selected automatically from what is installed on the
host (currently Nginx and Caddy).

## Contract

Introduce adapters under `lib/servers/`:

- `WebServerAdapter` owns product-specific CLI commands and output parsing.
- `WebServerRemote` is the SSH command surface. Adapters never import dartssh2.
- `WebServerStatus` / `WebServerSite` are the UI-facing models.

`SshConnectionManager` detects adapters, constructs a privileged remote runner,
and forwards lifecycle / config / log operations to the selected adapter.

## Current adapters

### Nginx (`NginxWebServerAdapter`)

- Detects `nginx` on PATH and `nginx.service`.
- Lists sites from `/etc/nginx/sites-enabled` and `/etc/nginx/conf.d`.
- Validates with `nginx -t`, reloads via systemctl, logs via journalctl (with
  `/var/log/nginx` fallback).
- Writes configs with privileged `tee` (sudo-safe).

### Caddy (`CaddyWebServerAdapter`)

- Detects `caddy` on PATH and `caddy.service`.
- Resolves the Caddyfile from the unit `ExecStart` or common install paths.
- Parses top-level site addresses from the Caddyfile.
- Prefers `caddy reload --config` for reload; falls back to systemctl.

## Tasks and config editing

Lifecycle, validate, and save flows return a `WebServerTaskResult` with
step-level success/failure so the UI can show a banner without opening logs.

- **Validate** and **start/stop/restart/reload** run through the same deploy
  terminal used by containers (`runWithDeployTerminal`).
- **Reload** always pre-checks config; a failed check aborts the reload.
- **Edit config** reuses the file-manager code editor modal. Save modes:
  - Save only
  - Save & check
  - Save, check & reload

## Adding an adapter

1. Implement `WebServerAdapter` (optionally with `WebServerSystemdHelpers`),
   including `writeConfig`.
2. Register the instance in `builtInWebServerAdapters` in
   `web_server_adapters.dart`.
3. Add parse helpers with unit tests under `test/web_server_adapter_test.dart`.

The Web tab on the server detail page lists every installed adapter and loads
sites for the selection automatically.
