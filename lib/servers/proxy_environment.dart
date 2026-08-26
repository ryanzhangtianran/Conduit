import 'dart:io';

/// Probes Surge's default listener ports on loopback. Returns the first port
/// that accepts a TCP connection, preferring the HTTP listener, or null when
/// nothing is listening.
Future<int?> detectLocalProxyPort() async {
  const candidates = <int>[6152, 6153];
  for (final port in candidates) {
    try {
      final socket = await Socket.connect(
        '127.0.0.1',
        port,
        timeout: const Duration(milliseconds: 600),
      );
      socket.destroy();
      return port;
    } catch (_) {
      // Not listening; try the next candidate.
    }
  }
  return null;
}
