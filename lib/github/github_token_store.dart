import 'package:drift/drift.dart';

import 'package:conduit/data/local/app_database.dart';
import 'package:conduit/servers/vault_service.dart';

/// Storage for GitHub access tokens. Tokens are encrypted with the vault data
/// key and stored inside the vault database, so they sync with the vault and
/// survive vault migration instead of rendering a synced connection as
/// signed-out.
abstract interface class GitHubTokenStorage {
  Future<String?> read(String login);

  Future<void> write(String login, String token);

  Future<void> delete(String login);
}

/// Vault-backed token storage. The token is encrypted with the vault key and
/// kept in [GitHubTokens], mirroring how SSH credentials are stored; only the
/// ciphertext ever touches the database.
class VaultGitHubTokenStorage implements GitHubTokenStorage {
  VaultGitHubTokenStorage(this._database, this._vault);

  final AppDatabase _database;
  final VaultService _vault;

  static const _context = 'github-token';

  @override
  Future<String?> read(String login) async {
    final row = await (_database.select(
      _database.gitHubTokens,
    )..where((table) => table.accountLogin.equals(login))).getSingleOrNull();
    if (row == null) return null;
    return _vault.decrypt(
      EncryptedValue(bytes: row.encryptedToken, nonce: row.tokenNonce),
      context: _context,
    );
  }

  @override
  Future<void> write(String login, String token) async {
    final encrypted = await _vault.encrypt(token, context: _context);
    await _database
        .into(_database.gitHubTokens)
        .insert(
          GitHubTokensCompanion.insert(
            accountLogin: login,
            encryptedToken: encrypted.bytes,
            tokenNonce: encrypted.nonce,
            updatedAt: DateTime.now().toUtc(),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  @override
  Future<void> delete(String login) async {
    await (_database.delete(
      _database.gitHubTokens,
    )..where((table) => table.accountLogin.equals(login))).go();
  }
}

/// In-memory token storage for tests.
class InMemoryGitHubTokenStorage implements GitHubTokenStorage {
  final Map<String, String> _tokens = {};

  @override
  Future<String?> read(String login) async => _tokens[login];

  @override
  Future<void> write(String login, String token) async =>
      _tokens[login] = token;

  @override
  Future<void> delete(String login) async => _tokens.remove(login);
}
