import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:conduit/servers/vault_file_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final storage = VaultFileStorage();

  group('VaultFileStorage.createVaultPath', () {
    test('stores new vaults under application support', () async {
      final support = await Directory.systemTemp.createTemp(
        'conduit-vault-storage-',
      );
      final previous = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _FakePathProvider(support);
      addTearDown(() async {
        PathProviderPlatform.instance = previous;
        await support.delete(recursive: true);
      });

      final path = await storage.createVaultPath(name: 'Primary Vault');

      expect(
        storage.isInDirectory(
          path,
          '${support.path}${Platform.pathSeparator}vaults',
        ),
        isTrue,
      );
      expect(storage.fileName(path), startsWith('Primary Vault-'));
      expect(path, endsWith('.conduit'));
    });

    test(
      'resolves an old absolute path after the app container changes',
      () async {
        final support = await Directory.systemTemp.createTemp(
          'conduit-vault-update-',
        );
        final previous = PathProviderPlatform.instance;
        PathProviderPlatform.instance = _FakePathProvider(support);
        addTearDown(() async {
          PathProviderPlatform.instance = previous;
          await support.delete(recursive: true);
        });

        final directory = await Directory('${support.path}/vaults').create();
        final current = File('${directory.path}/primary.conduit');
        await current.writeAsString('vault');

        final resolved = await storage.resolvePersistedPath(
          '/var/mobile/Containers/Data/Application/old-id/Library/'
          'Application Support/vaults/primary.conduit',
        );

        expect(resolved, current.absolute.path);
        expect(await storage.persistentPath(resolved!), 'primary.conduit');
        expect(storage.vaultId(resolved), 'primary.conduit');
        expect(await storage.managedVaultPaths(), [current.absolute.path]);
      },
    );
  });
  group('VaultFileStorage external paths', () {
    test('classifies application-support vaults as internal', () async {
      final support = await Directory.systemTemp.createTemp(
        'conduit-vault-location-',
      );
      final previous = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _FakePathProvider(support);
      addTearDown(() async {
        PathProviderPlatform.instance = previous;
        await support.delete(recursive: true);
      });

      expect(
        await storage.isExternalPath(
          '${support.path}${Platform.pathSeparator}vaults/internal.conduit',
        ),
        isFalse,
      );
      expect(
        await storage.isExternalPath(
          '${support.path}${Platform.pathSeparator}Sync/external.conduit',
        ),
        isTrue,
      );
    });
  });

  group('VaultFileStorage.fileName', () {
    test('returns the basename for native Windows separators', () {
      expect(
        storage.fileName(r'C:\Users\Me\Documents\vaults\a.conduit'),
        'a.conduit',
      );
    });

    test('returns the basename for forward-slash managed paths', () {
      expect(
        storage.fileName('C:/Users/Me/Documents/vaults/a.conduit'),
        'a.conduit',
      );
    });

    test('returns the path itself when it has no separators', () {
      expect(storage.fileName('a.conduit'), 'a.conduit');
    });
  });

  group('VaultFileStorage.isInDirectory', () {
    test('recognizes a managed vault when separators differ', () {
      // path_provider reports Application Support with '\' on Windows while
      // managed vault paths are built with '/'; both must count as in-directory.
      expect(
        storage.isInDirectory(
          'C:/Users/Me/Application Support/vaults/a.conduit',
          r'C:\Users\Me\Application Support',
        ),
        isTrue,
      );
    });

    test('recognizes a managed vault with matching separators', () {
      expect(
        storage.isInDirectory(
          r'C:\Users\Me\Application Support\vaults\a.conduit',
          r'C:\Users\Me\Application Support',
        ),
        isTrue,
      );
      expect(
        storage.isInDirectory(
          'C:/Users/Me/Application Support/vaults/a.conduit',
          'C:/Users/Me/Application Support',
        ),
        isTrue,
      );
    });

    test('tolerates a trailing separator on the directory', () {
      expect(
        storage.isInDirectory(
          'C:/Users/Me/Application Support/vaults/a.conduit',
          r'C:\Users\Me\Application Support\',
        ),
        isTrue,
      );
    });

    test('rejects files outside the directory', () {
      expect(
        storage.isInDirectory(
          'C:/Users/Me/Other/a.conduit',
          'C:/Users/Me/Application Support',
        ),
        isFalse,
      );
    });

    test('rejects sibling paths that merely share a prefix', () {
      expect(
        storage.isInDirectory(
          'C:/Users/Me/Application SupportVaults/a.conduit',
          'C:/Users/Me/Application Support',
        ),
        isFalse,
      );
    });
  });
}

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this._support);

  final Directory _support;

  @override
  Future<String?> getApplicationSupportPath() async => _support.path;
}
