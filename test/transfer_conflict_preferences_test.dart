import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:conduit/servers/server_providers.dart';
import 'package:conduit/servers/transfer_conflict_preferences.dart';
import 'package:conduit/shared/services/preference_store.dart';

void main() {
  test('defaults to renaming conflicting files', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(transferConflictModeProvider),
      TransferConflictMode.rename,
    );
  });

  test('restores and saves the transfer conflict mode', () async {
    final store = PreferenceStore.inMemory({
      'transfer_conflict_mode': 'overwrite',
    });
    final container = ProviderContainer(
      overrides: [preferenceStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(transferConflictModeProvider),
      TransferConflictMode.overwrite,
    );

    await container
        .read(transferConflictModeProvider.notifier)
        .set(TransferConflictMode.ask);

    expect(store.read<String>('transfer_conflict_mode'), 'ask');
    expect(
      container.read(transferConflictModeProvider),
      TransferConflictMode.ask,
    );
  });

  test('an unknown stored mode falls back to the default', () {
    final container = ProviderContainer(
      overrides: [
        preferenceStoreProvider.overrideWithValue(
          PreferenceStore.inMemory({'transfer_conflict_mode': 'bogus'}),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(
      container.read(transferConflictModeProvider),
      TransferConflictMode.rename,
    );
  });
}
