import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:conduit/servers/icloud_backup_service.dart';

void main() {
  late Directory home;

  setUp(() async {
    home = await Directory.systemTemp.createTemp('icloud_backup_test');
  });

  tearDown(() => home.delete(recursive: true));

  test('reports iCloud Drive as unavailable without its folder', () async {
    final service = ICloudBackupService(home: home.path);
    expect(service.drivePath, isNull);
    expect(await service.list(), isEmpty);
    await expectLater(
      service.write(name: 'a.conduit', archive: 'x'),
      throwsStateError,
    );
  });

  test('writes archives newest first and prunes to the newest ten', () async {
    final drive = Directory(
      '${home.path}/Library/Mobile Documents/com~apple~CloudDocs',
    );
    await drive.create(recursive: true);
    final service = ICloudBackupService(home: home.path);
    expect(service.drivePath, drive.path);

    for (var i = 0; i < ICloudBackupService.keepNewest + 2; i++) {
      // Older releases wrote `.mkb`; both extensions are listed together.
      final name = i.isEven ? 'conduit-$i.conduit' : 'conduit-$i.mkb';
      await service.write(name: name, archive: '$i');
      // Distinct modification times so the order is deterministic.
      await File(
        '${drive.path}/Conduit/$name',
      ).setLastModified(DateTime(2026, 1, 1).add(Duration(minutes: i)));
    }

    final backups = await service.list();
    expect(backups, hasLength(ICloudBackupService.keepNewest));
    expect(backups.first.file.uri.pathSegments.last, 'conduit-11.mkb');
    expect(backups.last.file.uri.pathSegments.last, 'conduit-2.conduit');
  });
}
