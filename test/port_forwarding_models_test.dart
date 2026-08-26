import 'package:flutter_test/flutter_test.dart';
import 'package:conduit/servers/port_forwarding_models.dart';

void main() {
  const base = ActivePortForward(
    id: 'forward-1',
    serverId: 1,
    serverName: 'server',
    direction: PortForwardDirection.local,
    kind: PortForwardKind.tcp,
    bindHost: '127.0.0.1',
    bindPort: 43123,
    targetHost: '127.0.0.1',
    targetPort: 8747,
  );

  test('copyWith keeps identity while rebinding the local port', () {
    final updated = base.copyWith(bindPort: 43125);
    expect(updated.id, 'forward-1');
    expect(updated.serverId, 1);
    expect(updated.direction, PortForwardDirection.local);
    expect(updated.kind, PortForwardKind.tcp);
    expect(updated.targetPort, 8747);
    expect(updated.bindPort, 43125);
  });
}
