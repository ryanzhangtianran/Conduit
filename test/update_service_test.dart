import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:conduit/shared/services/update_service.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => handler(options);

  @override
  void close({bool force = false}) {}
}

UpdateService _service(
  Future<ResponseBody> Function(RequestOptions options) handler, {
  String currentVersion = '2.1.0',
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.github.com',
      headers: {'Accept': 'application/vnd.github+json'},
    ),
  );
  dio.httpClientAdapter = _FakeAdapter(handler);
  return UpdateService(
    dio: dio,
    currentVersion: () async => currentVersion,
    bundlePath: '/Applications/Conduit.app',
  );
}

ResponseBody _json(Object data, {int status = 200}) => ResponseBody.fromString(
  jsonEncode(data),
  status,
  headers: {
    'content-type': ['application/json'],
  },
);

Map<String, Object?> _release(
  String tag, {
  List<Map<String, Object?>> assets = const [],
}) => {
  'tag_name': tag,
  'html_url': 'https://github.com/ryanzhangtianran/Conduit/releases/tag/$tag',
  'body': 'Notes for $tag',
  'assets': assets,
};

Map<String, Object?> _asset(String name, {int size = 1024}) => {
  'name': name,
  'size': size,
  'browser_download_url':
      'https://github.com/ryanzhangtianran/Conduit/releases/download/v9/$name',
};

void main() {
  group('compareVersions', () {
    test('compares numerically per component', () {
      expect(compareVersions('1.10.0', '1.9.2'), greaterThan(0));
      expect(compareVersions('2.0.0', '10.0.0'), lessThan(0));
      expect(compareVersions('2.1.0', '2.1.0'), 0);
      expect(compareVersions('2.1', '2.1.0'), 0);
      expect(compareVersions('2.1.1', '2.1'), greaterThan(0));
    });

    test('ignores a v prefix and a build number', () {
      expect(compareVersions('v2.1.1', '2.1.0+36'), greaterThan(0));
      expect(compareVersions('2.1.0+40', 'v2.1.0'), 0);
    });

    test('ranks a prerelease below its release', () {
      expect(compareVersions('2.2.0-beta.1', '2.2.0'), lessThan(0));
      expect(compareVersions('2.2.0-beta.1', '2.1.9'), greaterThan(0));
      expect(compareVersions('2.2.0', '2.2.0-rc.1'), greaterThan(0));
    });
  });

  group('parseRelease', () {
    test('reads the tag, page, notes and the Conduit.dmg asset', () {
      final info = parseRelease(
        _release(
          'v2.2.0',
          assets: [
            _asset('Conduit.zip', size: 5),
            _asset('Conduit.dmg', size: 12345678),
          ],
        ),
      );
      expect(info, isNotNull);
      expect(info!.version, '2.2.0');
      expect(
        info.htmlUrl,
        'https://github.com/ryanzhangtianran/Conduit/releases/tag/v2.2.0',
      );
      expect(info.notes, 'Notes for v2.2.0');
      expect(info.downloadUrl, endsWith('/Conduit.dmg'));
      expect(info.size, 12345678);
      expect(info.canInstall, isTrue);
    });

    test('falls back to any dmg and tolerates a missing one', () {
      final other = parseRelease(
        _release('v2.2.0', assets: [_asset('Conduit-arm64.dmg')]),
      );
      expect(other!.downloadUrl, endsWith('/Conduit-arm64.dmg'));

      final none = parseRelease(
        _release('2.2.0', assets: [_asset('Conduit.zip')]),
      );
      expect(none!.version, '2.2.0');
      expect(none.downloadUrl, isNull);
      expect(none.size, isNull);
      expect(none.canInstall, isFalse);
    });

    test('returns null without a tag', () {
      expect(parseRelease({'html_url': 'x'}), isNull);
      expect(parseRelease({'tag_name': ''}), isNull);
    });
  });

  group('bundlePathOf', () {
    test('finds the enclosing app bundle', () {
      expect(
        bundlePathOf('/Applications/Conduit.app/Contents/MacOS/Conduit'),
        '/Applications/Conduit.app',
      );
      expect(
        bundlePathOf('/Users/me/Downloads/Conduit.app/Contents/MacOS/Conduit'),
        '/Users/me/Downloads/Conduit.app',
      );
    });

    test('is null outside a bundle', () {
      expect(bundlePathOf('/Users/me/conduit/build/conduit'), isNull);
    });
  });

  group('UpdateService.check', () {
    test('reports a newer release', () async {
      final service = _service((options) async {
        expect(options.path, '/repos/ryanzhangtianran/Conduit/releases/latest');
        expect(options.headers['Accept'], 'application/vnd.github+json');
        expect(options.headers.containsKey('Authorization'), isFalse);
        return _json(_release('v2.2.0', assets: [_asset('Conduit.dmg')]));
      });
      final result = await service.check();
      expect(result, isA<UpdateAvailable>());
      expect((result as UpdateAvailable).update.version, '2.2.0');
    });

    test('reports up to date for the same or an older release', () async {
      final same = await _service(
        (_) async => _json(_release('v2.1.0')),
      ).check();
      expect(same, isA<UpdateUpToDate>());
      expect((same as UpdateUpToDate).version, '2.1.0');

      final older = await _service(
        (_) async => _json(_release('v2.0.9')),
        currentVersion: '2.1.0+36',
      ).check();
      expect(older, isA<UpdateUpToDate>());
    });

    test('maps rate limits, other statuses and transport errors', () async {
      final limited = await _service(
        (_) async => _json({'message': 'rate limited'}, status: 403),
      ).check();
      expect(limited, isA<UpdateCheckFailed>());
      expect(
        (limited as UpdateCheckFailed).failure,
        UpdateCheckFailure.rateLimited,
      );

      final tooMany = await _service(
        (_) async => _json({'message': 'slow down'}, status: 429),
      ).check();
      expect(
        (tooMany as UpdateCheckFailed).failure,
        UpdateCheckFailure.rateLimited,
      );

      final missing = await _service(
        (_) async => _json({'message': 'not found'}, status: 404),
      ).check();
      expect(
        (missing as UpdateCheckFailed).failure,
        UpdateCheckFailure.badResponse,
      );
      expect(missing.detail, 'HTTP 404');

      final offline = await _service((options) async {
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        );
      }).check();
      expect(
        (offline as UpdateCheckFailed).failure,
        UpdateCheckFailure.network,
      );
    });

    test('treats a release without a tag as a bad response', () async {
      final result = await _service(
        (_) async => _json({'html_url': 'x'}),
      ).check();
      expect(
        (result as UpdateCheckFailed).failure,
        UpdateCheckFailure.badResponse,
      );
    });
  });

  test('the installer script waits, swaps the bundle and relaunches', () {
    final script = UpdateService.installerScript;
    expect(script, contains('while kill -0 "\$PID"'));
    expect(script, contains('hdiutil attach -nobrowse -readonly'));
    expect(script, contains('ditto "\$SRC" "\$STAGE"'));
    expect(script, contains('xattr -dr com.apple.quarantine'));
    expect(script, contains('hdiutil detach'));
    expect(script, contains('open -n "\$APP"'));
  });
}
