import 'dart:io';

/// Protocol a local proxy app speaks on its listening port.
enum ProxyScheme { http, socks5 }

/// A local proxy discovered by [detectLocalProxy].
typedef LocalProxyDetection = ({ProxyScheme scheme, int port});

/// Probes Surge's default listener ports on loopback. Returns the first port
/// that accepts a TCP connection, preferring the HTTP listener, or null when
/// nothing is listening.
Future<LocalProxyDetection?> detectLocalProxy() async {
  const candidates = <LocalProxyDetection>[
    (scheme: ProxyScheme.http, port: 6152),
    (scheme: ProxyScheme.socks5, port: 6153),
  ];
  for (final candidate in candidates) {
    try {
      final socket = await Socket.connect(
        '127.0.0.1',
        candidate.port,
        timeout: const Duration(milliseconds: 600),
      );
      socket.destroy();
      return candidate;
    } catch (_) {
      // Not listening; try the next candidate.
    }
  }
  return null;
}
