import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../server_providers.dart';
import 'settings_section.dart';

/// Vault unlock options: biometrics and the master password.
@RoutePage()
class SecuritySettingsPage extends ConsumerWidget {
  const SecuritySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final biometricEnabled = ref.watch(biometricUnlockEnabledProvider);
    return SettingsPageBody(
      children: [
        SettingsSection(
          titleKey: 'settingsSecurity',
          padding: EdgeInsets.zero,
          child: biometricEnabled.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'settingsBiometricError'.tr(args: [error.toString()]),
              ),
            ),
            data: (enabled) => Column(
              children: [
                SwitchListTile(
                  contentPadding: settingsTilePadding,
                  secondary: const Icon(Symbols.fingerprint),
                  title: const Text('settingsBiometricUnlock').tr(),
                  subtitle: const Text('settingsBiometricUnlockHint').tr(),
                  value: enabled,
                  onChanged: (value) => _setBiometricUnlock(ref, value),
                ),
                SettingsPasswordTile(
                  icon: Symbols.key,
                  titleKey: 'settingsVaultChangePassword',
                  hintKey: 'settingsVaultChangePasswordHint',
                  actionKey: 'commonSave',
                  onSubmit: (password) => _changeVaultPassword(ref, password),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _setBiometricUnlock(WidgetRef ref, bool enabled) async {
    final vault = ref.read(vaultServiceProvider);
    try {
      if (enabled) {
        // Prompt once during setup; only persist when authentication
        // succeeds.
        await vault.enableBiometricUnlock();
      } else {
        await vault.disableBiometricUnlock();
      }
    } catch (error) {
      // Leave the switch off if setup fails (e.g. cancelled or unavailable).
      try {
        await vault.disableBiometricUnlock();
      } catch (_) {
        // The keychain itself is unavailable; the message below says so.
      }
      showSettingsMessage(
        'settingsBiometricSetupFailed'.tr(args: [error.toString()]),
      );
    } finally {
      ref.invalidate(biometricUnlockEnabledProvider);
    }
  }

  Future<bool> _changeVaultPassword(WidgetRef ref, String password) async {
    try {
      await ref.read(vaultServiceProvider).changePassword(password);
      showSettingsMessage('settingsVaultPasswordChanged'.tr());
      return true;
    } catch (error) {
      showSettingsMessage('settingsBackupError'.tr(args: [error.toString()]));
      return false;
    }
  }
}
