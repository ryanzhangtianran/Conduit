import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The app's keychain storage.
///
/// macOS uses the legacy (login) keychain instead of the default
/// data-protection keychain: the latter needs the `keychain-access-groups`
/// entitlement backed by a provisioning profile, which this locally-signed
/// build does not carry. The legacy keychain works with plain Apple
/// Development signing.
const appSecureStorage = FlutterSecureStorage(
  mOptions: MacOsOptions(usesDataProtectionKeychain: false),
);
