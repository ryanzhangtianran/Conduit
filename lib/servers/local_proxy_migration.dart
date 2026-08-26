import 'package:shared_preferences/shared_preferences.dart';

import 'port_forwarding_models.dart';
import 'server_repository.dart';

/// Vault-scoped marker so the conversion runs once per vault.
const _migratedKey = 'local_proxy_forwards_migrated';

const _kindKey = 'local_proxy_kind';
const _localPortKey = 'local_proxy_local_port';
const _remotePortKey = 'local_proxy_remote_port';
const _injectEnvironmentKey = 'local_proxy_inject_environment';
const _enabledServersKey = 'local_proxy_enabled_servers';

/// Converts the old standalone local-proxy tunnel settings into ordinary saved
/// forwards.
///
/// The tunnel was a remote forward from each enabled server's
/// 127.0.0.1:remotePort back to the proxy app on 127.0.0.1:localPort, kept
/// alive by its own supervisor and (optionally) exported into new terminals.
/// All three of those are preset properties now, so one row per enabled server
/// reproduces the previous behavior exactly.
///
/// Best-effort: a failure here must never block startup, and the preferences
/// are only cleared once the rows are in.
Future<void> migrateLocalProxyForwards(
  ServerRepository repository, {
  SharedPreferencesAsync? preferences,
}) async {
  try {
    if (await repository.getAppSetting(_migratedKey) == 'true') return;
    final store = preferences ?? SharedPreferencesAsync();
    final enabled = await store.getStringList(_enabledServersKey);
    if (enabled != null && enabled.isNotEmpty) {
      final localPort = await store.getInt(_localPortKey) ?? 6152;
      final remotePort = await store.getInt(_remotePortKey) ?? 16152;
      for (final raw in enabled) {
        final serverId = int.tryParse(raw);
        if (serverId == null) continue;
        await repository.savePortForwardConfig(
          serverId: serverId,
          direction: PortForwardDirection.remote,
          kind: PortForwardKind.tcp,
          bindHost: '127.0.0.1',
          bindPort: remotePort,
          targetHost: '127.0.0.1',
          targetPort: localPort,
          autoStart: true,
          keepAlive: true,
        );
      }
    }
    await repository.setAppSetting(_migratedKey, 'true');
    for (final key in const [
      _kindKey,
      _localPortKey,
      _remotePortKey,
      _injectEnvironmentKey,
      _enabledServersKey,
    ]) {
      await store.remove(key);
    }
  } catch (_) {
    // Leaving the marker unset means the next launch tries again.
  }
}
