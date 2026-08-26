import 'dart:io';

import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:conduit/shared/services/package_info_provider.dart';

/// The GitHub repository whose releases carry Conduit builds.
const conduitReleasesRepository = 'ryanzhangtianran/Conduit';

/// The disk image asset attached to every release.
const conduitDmgAssetName = 'Conduit.dmg';

/// A release newer than the running build.
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.htmlUrl,
    required this.notes,
    this.downloadUrl,
    this.size,
  });

  /// The release version without the `v` tag prefix.
  final String version;

  /// The release page on GitHub.
  final String htmlUrl;

  /// The release body (Markdown), possibly empty.
  final String notes;

  /// Direct download of the `Conduit.dmg` asset; null when the release has
  /// no disk image, in which case only the release page can be offered.
  final String? downloadUrl;

  /// Size of the disk image in bytes when GitHub reports it.
  final int? size;

  bool get canInstall => downloadUrl != null;
}

/// Why a check could not produce an answer.
enum UpdateCheckFailure {
  /// GitHub was unreachable or timed out.
  network,

  /// The unauthenticated API quota is exhausted (403/429).
  rateLimited,

  /// The response did not describe a release.
  badResponse,
}

sealed class UpdateCheckResult {
  const UpdateCheckResult();

  const factory UpdateCheckResult.upToDate(String version) = UpdateUpToDate;
  const factory UpdateCheckResult.available(UpdateInfo update) =
      UpdateAvailable;
  const factory UpdateCheckResult.failed(
    UpdateCheckFailure failure, {
    String? detail,
  }) = UpdateCheckFailed;
}

class UpdateUpToDate extends UpdateCheckResult {
  const UpdateUpToDate(this.version);

  /// The running version, which is also the latest release.
  final String version;
}

class UpdateAvailable extends UpdateCheckResult {
  const UpdateAvailable(this.update);

  final UpdateInfo update;
}

class UpdateCheckFailed extends UpdateCheckResult {
  const UpdateCheckFailed(this.failure, {this.detail});

  final UpdateCheckFailure failure;

  /// The transport or parser message, for the "Check failed" line.
  final String? detail;
}

/// Compares two dotted versions numerically (`1.10.0` > `1.9.2`); a leading
/// `v`, a `+build` suffix and non-numeric parts are ignored. A version with a
/// `-prerelease` suffix sorts below the same version without one.
int compareVersions(String a, String b) {
  final (coreA, preA) = _splitVersion(a);
  final (coreB, preB) = _splitVersion(b);
  final length = coreA.length > coreB.length ? coreA.length : coreB.length;
  for (var i = 0; i < length; i++) {
    final left = i < coreA.length ? coreA[i] : 0;
    final right = i < coreB.length ? coreB[i] : 0;
    if (left != right) return left.compareTo(right);
  }
  if (preA == preB) return 0;
  if (preA == null) return 1;
  if (preB == null) return -1;
  return preA.compareTo(preB);
}

(List<int>, String?) _splitVersion(String version) {
  var text = version.trim();
  if (text.startsWith('v') || text.startsWith('V')) text = text.substring(1);
  final build = text.indexOf('+');
  if (build >= 0) text = text.substring(0, build);
  String? prerelease;
  final dash = text.indexOf('-');
  if (dash >= 0) {
    prerelease = text.substring(dash + 1);
    text = text.substring(0, dash);
  }
  final core = [
    for (final part in text.split('.'))
      int.tryParse(part.replaceAll(RegExp(r'\D'), '')) ?? 0,
  ];
  return (core, prerelease);
}

/// Reads a GitHub release object into an [UpdateInfo]; null when it has no
/// tag. The `Conduit.dmg` asset is preferred; any other `.dmg` is accepted.
UpdateInfo? parseRelease(Map<String, dynamic> json) {
  final tag = json['tag_name'];
  if (tag is! String || tag.isEmpty) return null;
  final assets = json['assets'];
  Map<String, dynamic>? dmg;
  if (assets is List) {
    final candidates = assets.whereType<Map<String, dynamic>>().toList();
    dmg = candidates
        .where(
          (a) =>
              (a['name'] as String?)?.toLowerCase() ==
              conduitDmgAssetName.toLowerCase(),
        )
        .firstOrNull;
    dmg ??= candidates
        .where((a) => (a['name'] as String?)?.endsWith('.dmg') ?? false)
        .firstOrNull;
  }
  final version = tag.startsWith('v') ? tag.substring(1) : tag;
  return UpdateInfo(
    version: version,
    htmlUrl: json['html_url'] as String? ?? '',
    notes: json['body'] as String? ?? '',
    downloadUrl: dmg?['browser_download_url'] as String?,
    size: switch (dmg?['size']) {
      int size => size,
      num size => size.toInt(),
      _ => null,
    },
  );
}

/// The `.app` bundle that contains [executable], or null when the binary
/// does not run from inside a bundle (e.g. `flutter run`).
String? bundlePathOf(String executable) {
  final parts = executable.split('/');
  for (var i = parts.length - 1; i >= 0; i--) {
    if (parts[i].endsWith('.app')) return parts.sublist(0, i + 1).join('/');
  }
  return null;
}

/// Looks up the latest GitHub release and installs it in place.
///
/// Checks never throw: every failure comes back as [UpdateCheckFailed] so
/// the UI and the startup hook can show it without a try/catch.
class UpdateService {
  UpdateService({
    Dio? dio,
    Future<String> Function()? currentVersion,
    this.repository = conduitReleasesRepository,
    String? bundlePath,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: 'https://api.github.com',
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 20),
               headers: {
                 'Accept': 'application/vnd.github+json',
                 'User-Agent': 'conduit-updater',
               },
             ),
           ),
       _currentVersion = currentVersion ?? _installedVersion,
       _bundlePath =
           bundlePath ??
           bundlePathOf(Platform.resolvedExecutable) ??
           defaultBundlePath;

  /// Where the installer puts the app when the running binary is not
  /// inside a bundle.
  static const defaultBundlePath = '/Applications/Conduit.app';

  final Dio _dio;
  final String repository;
  final Future<String> Function() _currentVersion;
  final String _bundlePath;

  static Future<String> _installedVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  Future<UpdateCheckResult> check() async {
    final String current;
    try {
      current = await _currentVersion();
    } catch (e) {
      return UpdateCheckResult.failed(
        UpdateCheckFailure.badResponse,
        detail: '$e',
      );
    }
    final Map<String, dynamic> json;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/repos/$repository/releases/latest',
      );
      json = response.data ?? const {};
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 403 || status == 429) {
        return const UpdateCheckResult.failed(UpdateCheckFailure.rateLimited);
      }
      if (status != null) {
        return UpdateCheckResult.failed(
          UpdateCheckFailure.badResponse,
          detail: 'HTTP $status',
        );
      }
      return UpdateCheckResult.failed(
        UpdateCheckFailure.network,
        detail: e.message ?? e.error?.toString(),
      );
    } catch (e) {
      return UpdateCheckResult.failed(UpdateCheckFailure.network, detail: '$e');
    }
    final UpdateInfo? latest;
    try {
      latest = parseRelease(json);
    } catch (e) {
      return UpdateCheckResult.failed(
        UpdateCheckFailure.badResponse,
        detail: '$e',
      );
    }
    if (latest == null) {
      return const UpdateCheckResult.failed(UpdateCheckFailure.badResponse);
    }
    return compareVersions(latest.version, current) > 0
        ? UpdateCheckResult.available(latest)
        : UpdateCheckResult.upToDate(current);
  }

  /// Downloads the disk image of [update] and hands it to a detached
  /// installer that waits for this process to exit, swaps the bundle at
  /// [_bundlePath] for the new one and relaunches it. The caller must quit
  /// the app after this returns; the installer does nothing until it does.
  ///
  /// Throws on download failure; the installer's own progress goes to
  /// `~/Library/Logs/Conduit/update.log`.
  Future<void> downloadAndInstall(
    UpdateInfo update, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final url = update.downloadUrl;
    if (url == null) {
      throw StateError('The release has no $conduitDmgAssetName asset.');
    }
    if (!Platform.isMacOS) {
      throw UnsupportedError('In-app updates are only available on macOS.');
    }
    final workDir = await Directory.systemTemp.createTemp('conduit-update-');
    final dmg = File('${workDir.path}/$conduitDmgAssetName');
    try {
      await _dio.download(
        url,
        dmg.path,
        cancelToken: cancelToken,
        onReceiveProgress: onProgress,
        options: Options(
          headers: {'Accept': 'application/octet-stream'},
          receiveTimeout: const Duration(minutes: 10),
        ),
      );
      final expected = update.size;
      final actual = await dmg.length();
      if (expected != null && expected > 0 && actual != expected) {
        throw StateError(
          'Downloaded $actual bytes but the release lists $expected.',
        );
      }
      final log = File(
        '${Platform.environment['HOME'] ?? '/tmp'}/Library/Logs/Conduit/update.log',
      );
      await log.parent.create(recursive: true);
      final script = File('${workDir.path}/install.sh');
      await script.writeAsString(installerScript);
      await Process.start('/bin/sh', [
        script.path,
        '$pid',
        dmg.path,
        _bundlePath,
        log.path,
      ], mode: ProcessStartMode.detached);
    } catch (_) {
      await workDir.delete(recursive: true).catchError((_) => workDir);
      rethrow;
    }
  }

  /// The installer run by [downloadAndInstall]:
  /// `install.sh <pid> <dmg> <bundle> <log>`.
  ///
  /// The new bundle is copied to a staging directory beside the target and
  /// swapped in with two renames, so a failed copy never leaves a half
  /// replaced app; the previous bundle is restored if the swap fails.
  static const installerScript = r'''
#!/bin/sh
PID="$1"
DMG="$2"
APP="$3"
LOG="$4"
exec >>"$LOG" 2>&1
echo "[$(date '+%Y-%m-%d %H:%M:%S')] update: waiting for pid $PID to exit"
while kill -0 "$PID" 2>/dev/null; do sleep 0.5; done
sleep 1

MOUNT="$(mktemp -d "${TMPDIR:-/tmp}/conduit-update-mount.XXXXXX")"
STAGE="$APP.update-$$"
PREVIOUS="$APP.previous-$$"
DIR="$(dirname "$DMG")"

finish() {
  hdiutil detach "$MOUNT" -force >/dev/null 2>&1 || true
  rmdir "$MOUNT" 2>/dev/null || true
  rm -rf "$STAGE" "$PREVIOUS" "$DIR"
}

fail() {
  echo "update: $1"
  if [ ! -d "$APP" ] && [ -d "$PREVIOUS" ]; then
    mv "$PREVIOUS" "$APP" && echo "update: restored previous bundle"
  fi
  finish
  open -n "$APP" || true
  exit 1
}

echo "update: attaching $DMG"
hdiutil attach -nobrowse -readonly -noautoopen -mountpoint "$MOUNT" "$DMG" \
  || fail "could not attach the disk image"
SRC="$MOUNT/Conduit.app"
if [ ! -d "$SRC" ]; then
  SRC="$(find "$MOUNT" -maxdepth 1 -name '*.app' | head -n 1)"
fi
[ -d "$SRC" ] || fail "no app bundle in the disk image"

echo "update: copying $SRC to $STAGE"
rm -rf "$STAGE"
ditto "$SRC" "$STAGE" || fail "could not copy the new bundle"
xattr -dr com.apple.quarantine "$STAGE" 2>/dev/null || true

echo "update: replacing $APP"
if [ -d "$APP" ]; then
  mv "$APP" "$PREVIOUS" || fail "could not move the current bundle aside"
fi
mv "$STAGE" "$APP" || fail "could not move the new bundle into place"
rm -rf "$PREVIOUS"

finish
echo "update: relaunching $APP"
open -n "$APP"
echo "update: done"
''';
}

/// The updater. The running version comes from [packageInfoProvider].
final updateServiceProvider = Provider<UpdateService>(
  (ref) => UpdateService(
    currentVersion: () async =>
        (await ref.read(packageInfoProvider.future)).version,
  ),
);
