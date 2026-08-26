import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:conduit/data/local/app_database.dart';
import 'package:conduit/servers/server_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('onConnected hook does not hit a circular provider dependency', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final manager = container.read(connectionManagerProvider);
    const server = Server(
      id: 1,
      name: 'test',
      host: 'example.com',
      port: 22,
      username: 'root',
      collectStats: false,
      collectSystemInfo: false,
      connectionType: 'ssh',
    );
    // Fires the same hook a successful SSH connect fires.
    expect(() => manager.onConnected!(server), returnsNormally);
  });
}
