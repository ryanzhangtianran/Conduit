import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:conduit/data/local/app_database.dart';
import 'package:conduit/servers/server_providers.dart';

/// drift_flutter resolves its native database directory through
/// path_provider; point it at the system temp directory in tests.
void _mockPathProvider() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        return Directory.systemTemp.path;
      });
}

void main() {
  _mockPathProvider();
  SharedPreferences.setMockInitialValues({});

  test('manager and supervisor providers wire without a cycle', () async {
    final directory = Directory.systemTemp.createTempSync('connection_hook');
    final database = AppDatabase(filePath: '${directory.path}/test.sqlite');
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });
    final manager = container.read(connectionManagerProvider);
    // The supervisor depends on the manager, never the reverse: it follows
    // the same stream a successful SSH connect feeds.
    expect(
      () => container.read(portForwardSupervisorProvider),
      returnsNormally,
    );
    expect(manager.connectedServerIds.isBroadcast, isTrue);
    // The scheduler hook keeps the supervisor alive and listens for deleted
    // servers; reading it must not rebuild anything.
    expect(
      () => container.read(serverMetricsRefreshSchedulerProvider),
      returnsNormally,
    );
    await pumpEventQueue();
  });
}
