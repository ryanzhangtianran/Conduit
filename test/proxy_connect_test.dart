import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:dartssh2/dartssh2.dart';

import 'package:conduit/servers/server_models.dart';
import 'package:conduit/servers/ssh_proxy_connect.dart';

/// Minimal SOCKS5 (RFC 1928) and HTTP CONNECT servers on loopback used to
/// verify the client's handshake bytes and tunnel behavior.
void main() {
  test('SOCKS5 connects without authentication and tunnels data', () async {
    final proxy = await _ProxyHarness.bind();
    addTearDown(proxy.close);
    final server = proxy.server.listen((socket) async {
      try {
        final reader = await _socks5Handshake(
          socket,
          expectedHost: 'example.test',
          expectedPort: 22,
        );
        final payload = await reader.read(4);
        expect(utf8.decode(payload), 'ping');
        socket.add(utf8.encode('pong'));
        await socket.flush();
      } catch (_) {
        socket.destroy();
        rethrow;
      }
    });
    addTearDown(server.cancel);

    final tunnel = await connectThroughProxy(
      ServerProxy(
        type: ServerProxyType.socks5,
        host: '127.0.0.1',
        port: proxy.port,
      ),
      'example.test',
      22,
    );
    addTearDown(tunnel.destroy);
    await _writeTunnel(tunnel, 'ping');
    expect(utf8.decode(await _TestReader(tunnel.stream).read(4)), 'pong');
  });

  test('SOCKS5 authenticates with username and password (RFC 1929)', () async {
    final proxy = await _ProxyHarness.bind();
    addTearDown(proxy.close);
    final server = proxy.server.listen((socket) async {
      try {
        await _socks5Handshake(
          socket,
          expectedHost: 'db.internal',
          expectedPort: 22022,
          expectedUser: 'alice',
          expectedPass: 's3cret',
        );
      } catch (_) {
        socket.destroy();
        rethrow;
      }
    });
    addTearDown(server.cancel);

    final tunnel = await connectThroughProxy(
      ServerProxy(
        type: ServerProxyType.socks5,
        host: '127.0.0.1',
        port: proxy.port,
        username: 'alice',
        password: 's3cret',
      ),
      'db.internal',
      22022,
    );
    addTearDown(tunnel.destroy);
    expect(tunnel, isNotNull);
  });

  test('SOCKS5 surfaces a proxy rejection', () async {
    final proxy = await _ProxyHarness.bind();
    addTearDown(proxy.close);
    final server = proxy.server.listen((socket) async {
      try {
        await _socks5Handshake(
          socket,
          expectedHost: 'example.test',
          expectedPort: 22,
          replyCode: 0x04, // host unreachable
        );
      } catch (_) {
        socket.destroy();
        rethrow;
      }
    });
    addTearDown(server.cancel);

    await expectLater(
      connectThroughProxy(
        ServerProxy(
          type: ServerProxyType.socks5,
          host: '127.0.0.1',
          port: proxy.port,
        ),
        'example.test',
        22,
      ),
      throwsA(
        isA<ProxyConnectException>().having(
          (error) => error.message,
          'message',
          contains('host unreachable'),
        ),
      ),
    );
  });

  test(
    'HTTP CONNECT opens a tunnel and reports the request authority',
    () async {
      final proxy = await _ProxyHarness.bind();
      addTearDown(proxy.close);
      final requestLine = Completer<String>();
      final server = proxy.server.listen((socket) async {
        try {
          final reader = _TestReader(socket);
          final headers = await reader.readHttpHeaders();
          requestLine.complete(headers.split('\r\n').first);
          socket.add(
            utf8.encode('HTTP/1.1 200 Connection established\r\n\r\n'),
          );
          await socket.flush();
          final payload = await reader.read(4);
          socket.add(payload); // echo
          await socket.flush();
        } catch (_) {
          socket.destroy();
          rethrow;
        }
      });
      addTearDown(server.cancel);

      final tunnel = await connectThroughProxy(
        ServerProxy(
          type: ServerProxyType.http,
          host: '127.0.0.1',
          port: proxy.port,
        ),
        'web.example.com',
        443,
      );
      addTearDown(tunnel.destroy);
      expect(await requestLine.future, 'CONNECT web.example.com:443 HTTP/1.1');
      await _writeTunnel(tunnel, 'ping');
      expect(utf8.decode(await _TestReader(tunnel.stream).read(4)), 'ping');
    },
  );

  test('HTTP CONNECT brackets IPv6 targets', () async {
    final proxy = await _ProxyHarness.bind();
    addTearDown(proxy.close);
    final requestLine = Completer<String>();
    final server = proxy.server.listen((socket) async {
      try {
        final headers = await _TestReader(socket).readHttpHeaders();
        requestLine.complete(headers.split('\r\n').first);
        socket.add(utf8.encode('HTTP/1.1 200 Connection established\r\n\r\n'));
        await socket.flush();
      } catch (_) {
        socket.destroy();
        rethrow;
      }
    });
    addTearDown(server.cancel);

    final tunnel = await connectThroughProxy(
      ServerProxy(
        type: ServerProxyType.http,
        host: '127.0.0.1',
        port: proxy.port,
      ),
      '::1',
      22,
    );
    addTearDown(tunnel.destroy);
    expect(await requestLine.future, 'CONNECT [::1]:22 HTTP/1.1');
  });

  test(
    'HTTP CONNECT sends Proxy-Authorization when credentials are set',
    () async {
      final proxy = await _ProxyHarness.bind();
      addTearDown(proxy.close);
      final authorization = Completer<String?>();
      final server = proxy.server.listen((socket) async {
        try {
          final headers = await _TestReader(socket).readHttpHeaders();
          authorization.complete(
            headers
                .split('\r\n')
                .where((line) => line.startsWith('Proxy-Authorization: '))
                .firstOrNull,
          );
          socket.add(
            utf8.encode('HTTP/1.1 200 Connection established\r\n\r\n'),
          );
          await socket.flush();
        } catch (_) {
          socket.destroy();
          rethrow;
        }
      });
      addTearDown(server.cancel);

      final tunnel = await connectThroughProxy(
        ServerProxy(
          type: ServerProxyType.http,
          host: '127.0.0.1',
          port: proxy.port,
          username: 'alice',
          password: 's3cret',
        ),
        'example.test',
        22,
      );
      addTearDown(tunnel.destroy);
      final header = await authorization.future;
      expect(header, isNotNull);
      final token = header!.substring('Proxy-Authorization: Basic '.length);
      expect(utf8.decode(base64Decode(token)), 'alice:s3cret');
    },
  );

  test('HTTP CONNECT surfaces a proxy rejection', () async {
    final proxy = await _ProxyHarness.bind();
    addTearDown(proxy.close);
    final server = proxy.server.listen((socket) async {
      try {
        await _TestReader(socket).readHttpHeaders();
        socket.add(
          utf8.encode('HTTP/1.1 407 Proxy Authentication Required\r\n\r\n'),
        );
        await socket.flush();
      } catch (_) {
        socket.destroy();
        rethrow;
      }
    });
    addTearDown(server.cancel);

    await expectLater(
      connectThroughProxy(
        ServerProxy(
          type: ServerProxyType.http,
          host: '127.0.0.1',
          port: proxy.port,
        ),
        'example.test',
        22,
      ),
      throwsA(
        isA<ProxyConnectException>().having(
          (error) => error.message,
          'message',
          contains('407'),
        ),
      ),
    );
  });

  test('fails when nothing listens on the proxy address', () async {
    // Bind and close so the port is guaranteed free.
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    await probe.close();
    await expectLater(
      connectThroughProxy(
        ServerProxy(
          type: ServerProxyType.socks5,
          host: '127.0.0.1',
          port: port,
        ),
        'example.test',
        22,
      ),
      throwsA(isA<SocketException>()),
    );
  });
}

class _ProxyHarness {
  _ProxyHarness._(this.server);

  final ServerSocket server;

  int get port => server.port;

  static Future<_ProxyHarness> bind() async =>
      _ProxyHarness._(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0));

  Future<void> close() => server.close();
}

/// Writes through the tunnel and flushes the underlying socket.
Future<void> _writeTunnel(SSHSocket tunnel, String text) async {
  tunnel.sink.add(utf8.encode(text));
  await (tunnel.sink as Socket).flush();
}

/// Buffered sequential reader over a socket, mirroring how the production
/// handshake consumes proxy responses.
class _TestReader {
  _TestReader(this._stream);

  final Stream<List<int>> _stream;
  final _buffer = BytesBuilder(copy: false);
  StreamIterator<List<int>>? _iterator;

  Future<Uint8List> read(int count) async {
    while (_buffer.length < count) {
      _buffer.add(await _nextChunk());
    }
    final bytes = _buffer.takeBytes();
    final result = Uint8List.fromList(bytes.sublist(0, count));
    if (bytes.length > count) _buffer.add(bytes.sublist(count));
    return result;
  }

  Future<String> readHttpHeaders() async {
    const marker = [13, 10, 13, 10];
    while (_indexOf(_buffer.toBytes(), marker) == null) {
      _buffer.add(await _nextChunk());
    }
    final bytes = _buffer.takeBytes();
    final end = _indexOf(bytes, marker)! + marker.length;
    final result = utf8.decode(bytes.sublist(0, end));
    if (bytes.length > end) _buffer.add(bytes.sublist(end));
    return result;
  }

  Future<List<int>> _nextChunk() async {
    final iterator = _iterator ??= StreamIterator(_stream);
    if (!await iterator.moveNext().timeout(const Duration(seconds: 5))) {
      throw StateError('Socket closed before the expected bytes arrived.');
    }
    return iterator.current;
  }

  static int? _indexOf(List<int> haystack, List<int> needle) {
    outer:
    for (var i = 0; i + needle.length <= haystack.length; i++) {
      for (var j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) continue outer;
      }
      return i;
    }
    return null;
  }
}

Future<_TestReader> _socks5Handshake(
  Socket socket, {
  required String expectedHost,
  required int expectedPort,
  String? expectedUser,
  String? expectedPass,
  int replyCode = 0x00,
}) async {
  final reader = _TestReader(socket);
  final greeting = await reader.read(2);
  expect(greeting[0], 0x05);
  expect(greeting[1], inInclusiveRange(1, 2));
  final methods = await reader.read(greeting[1]);
  if (expectedUser == null) {
    expect(methods, contains(0x00));
    socket.add(const [0x05, 0x00]);
  } else {
    expect(methods, contains(0x02));
    socket.add(const [0x05, 0x02]);
    await socket.flush();
    final authHeader = await reader.read(2);
    expect(authHeader[0], 0x01);
    final username = await reader.read(authHeader[1]);
    expect(utf8.decode(username), expectedUser);
    final passwordLength = await reader.read(1);
    final password = await reader.read(passwordLength[0]);
    expect(utf8.decode(password), expectedPass);
    socket.add(const [0x01, 0x00]);
  }
  await socket.flush();

  final request = await reader.read(4);
  expect(request[0], 0x05);
  expect(request[1], 0x01, reason: 'CONNECT command');
  expect(request[2], 0x00, reason: 'reserved byte');
  expect(request[3], 0x03, reason: 'domain address type (proxy-side DNS)');
  final hostLength = await reader.read(1);
  final host = await reader.read(hostLength[0]);
  expect(utf8.decode(host), expectedHost);
  final portBytes = await reader.read(2);
  expect(portBytes[0] << 8 | portBytes[1], expectedPort);

  socket.add([0x05, replyCode, 0x00, 0x01, 127, 0, 0, 1, 0, 0]);
  await socket.flush();
  return reader;
}
