import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:conduit/servers/server_providers.dart';
import 'package:conduit/shared/services/preference_store.dart';

void main() {
  test('reads typed values and removes entries written as null', () async {
    final store = PreferenceStore.inMemory({'connect_on_startup': true});
    expect(store.read<bool>('connect_on_startup'), isTrue);
    expect(store.read<int>('connect_on_startup'), isNull);

    await store.write('focused_detail_refresh_interval_seconds', 5);
    expect(store.read<int>('focused_detail_refresh_interval_seconds'), 5);

    await store.write('connect_on_startup', null);
    expect(store.read<bool>('connect_on_startup'), isNull);
    await expectLater(store.write('bad', const Object()), throwsArgumentError);
  });

  test('notifiers read defaults, stored values and persist changes', () async {
    final store = PreferenceStore.inMemory({
      'background_metrics_refresh_interval_seconds': 120,
      'workspace_tab_order': ['5', '4', '3', '2', '1', '0'],
    });
    final container = ProviderContainer(
      overrides: [preferenceStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    expect(container.read(connectOnStartupProvider), isFalse);
    expect(
      container.read(serverMetricsRefreshIntervalProvider),
      const Duration(minutes: 2),
    );
    expect(
      container.read(focusedServerRefreshIntervalProvider),
      const Duration(seconds: 3),
    );
    expect(container.read(navigationOrderProvider), [5, 4, 3, 2, 1, 0]);

    await container.read(connectOnStartupProvider.notifier).set(true);
    expect(store.read<bool>('connect_on_startup'), isTrue);

    await container.read(navigationOrderProvider.notifier).move(0, 5);
    expect(container.read(navigationOrderProvider), [4, 3, 2, 1, 0, 5]);
    expect(store.read<List<String>>('workspace_tab_order'), [
      '4',
      '3',
      '2',
      '1',
      '0',
      '5',
    ]);
  });

  test('a partial navigation order falls back to the default', () {
    final container = ProviderContainer(
      overrides: [
        preferenceStoreProvider.overrideWithValue(
          PreferenceStore.inMemory({
            'workspace_tab_order': ['0', '1', '2'],
          }),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(navigationOrderProvider), [0, 1, 2, 3, 4, 5]);
  });
}
