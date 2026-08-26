import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:system_fonts/system_fonts.dart';

import 'package:conduit/shared/presentation/conduit_dropdown.dart';
import '../server_providers.dart';
import '../terminal_appearance_preferences.dart';
import '../terminal_color_scheme.dart';
import 'settings_section.dart';
import 'terminal_theme_dialog.dart';

/// Font, size, line height, palettes and cursor animation for new terminals.
@RoutePage()
class TerminalSettingsPage extends ConsumerWidget {
  const TerminalSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsPageBody(
      children: [
        SettingsSection(
          titleKey: 'settingsTerminal',
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _TerminalFontDropdown(),
                    const SizedBox(height: 16),
                    _TerminalFontSizeSlider(
                      fontSize: ref.watch(terminalFontSizeProvider),
                    ),
                    const SizedBox(height: 8),
                    _TerminalLineHeightSlider(
                      lineHeight: ref.watch(terminalLineHeightProvider),
                    ),
                    const SizedBox(height: 16),
                    _TerminalThemeTile(
                      mode: Brightness.light,
                      theme: ref.watch(terminalLightThemeProvider),
                      onEdit: () => _editTerminalTheme(
                        context,
                        ref,
                        brightness: Brightness.light,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _TerminalThemeTile(
                      mode: Brightness.dark,
                      theme: ref.watch(terminalDarkThemeProvider),
                      onEdit: () => _editTerminalTheme(
                        context,
                        ref,
                        brightness: Brightness.dark,
                      ),
                    ),
                  ],
                ),
              ),
              SwitchListTile(
                contentPadding: settingsTilePadding,
                title: const Text('settingsAnimateCursor').tr(),
                subtitle: const Text('settingsAnimateCursorHint').tr(),
                value: ref.watch(cursorAnimationEnabledProvider),
                onChanged: (enabled) => ref
                    .read(cursorAnimationEnabledProvider.notifier)
                    .setEnabled(enabled),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editTerminalTheme(
    BuildContext context,
    WidgetRef ref, {
    required Brightness brightness,
  }) async {
    final isLight = brightness == Brightness.light;
    final updated = await showTerminalThemeDialog(
      context,
      brightness: brightness,
      initialScheme: isLight
          ? ref.read(terminalLightThemeProvider)
          : ref.read(terminalDarkThemeProvider),
    );
    if (updated == null) return;
    if (isLight) {
      await ref.read(terminalLightThemeProvider.notifier).save(updated);
    } else {
      await ref.read(terminalDarkThemeProvider.notifier).save(updated);
    }
  }
}

/// Whole-point font size slider for new terminals.
class _TerminalFontSizeSlider extends ConsumerWidget {
  const _TerminalFontSizeSlider({required this.fontSize});

  final double fontSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'settingsTerminalFontSize'.tr(),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Text('${fontSize.round()} pt', style: theme.textTheme.labelLarge),
          ],
        ),
        Slider(
          value: fontSize.clamp(kTerminalFontSizeMin, kTerminalFontSizeMax),
          min: kTerminalFontSizeMin,
          max: kTerminalFontSizeMax,
          divisions: (kTerminalFontSizeMax - kTerminalFontSizeMin).round(),
          label: '${fontSize.round()}',
          onChanged: (value) => ref
              .read(terminalFontSizeProvider.notifier)
              .setFontSize(value.roundToDouble()),
        ),
        Text(
          'settingsTerminalFontSizeHint',
          style: theme.textTheme.bodySmall,
        ).tr(),
      ],
    );
  }
}

class _TerminalLineHeightSlider extends ConsumerWidget {
  const _TerminalLineHeightSlider({required this.lineHeight});

  final double lineHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'settingsTerminalLineHeight'.tr(),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Text(
              '${lineHeight.toStringAsFixed(2)}×',
              style: theme.textTheme.labelLarge,
            ),
          ],
        ),
        Slider(
          value: lineHeight.clamp(
            kTerminalLineHeightMin,
            kTerminalLineHeightMax,
          ),
          min: kTerminalLineHeightMin,
          max: kTerminalLineHeightMax,
          divisions: 12,
          label: lineHeight.toStringAsFixed(2),
          onChanged: (value) => ref
              .read(terminalLineHeightProvider.notifier)
              .setLineHeight((value * 20).roundToDouble() / 20),
        ),
        Text(
          'settingsTerminalLineHeightHint',
          style: theme.textTheme.bodySmall,
        ).tr(),
      ],
    );
  }
}

class _TerminalFontDropdown extends HookConsumerWidget {
  const _TerminalFontDropdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fonts = ref.watch(availableTerminalFontsProvider);
    final monoOnly = ref.watch(monospaceTerminalFontsOnlyProvider);
    final current = ref.watch(terminalFontFamilyProvider);

    final all = fonts.value ?? const <TerminalFontOption>[];
    final filtered = <TerminalFontOption>[
      for (final option in all)
        if (!monoOnly || option.label.toLowerCase().contains('mono')) option,
    ];
    if (!filtered.any((option) => option.family == current)) {
      filtered.insert(0, TerminalFontOption(label: current, family: current));
    }

    final loaded = useState<Set<String>>(const {});
    useEffect(
      () {
        var cancelled = false;
        final missing = filtered
            .map((option) => option.family)
            .where((family) => !loaded.value.contains(family))
            .toList();
        if (missing.isEmpty) return null;

        Future<void> loadMissingFonts() async {
          for (final family in missing) {
            if (cancelled) return;
            try {
              await SystemFonts().loadFont(family);
            } on Object {
              // Bundled or unavailable fonts need no engine loading.
            }
            if (cancelled) return;
            loaded.value = {...loaded.value, family};
          }
        }

        unawaited(loadMissingFonts());
        return () => cancelled = true;
      },
      [
        monoOnly,
        filtered.map((option) => option.family).join(','),
        fonts.value,
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final fontHint = Text(
          'settingsTerminalFontHint',
          style: Theme.of(context).textTheme.bodySmall,
        ).tr();
        final monospaceToggle = constraints.maxWidth < 420
            ? Row(
                children: [
                  Flexible(
                    child: Text(
                      'settingsTerminalFontMonospaceOnly'.tr(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Switch(
                    value: monoOnly,
                    onChanged: (value) => ref
                        .read(monospaceTerminalFontsOnlyProvider.notifier)
                        .setEnabled(value),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'settingsTerminalFontMonospaceOnly'.tr(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 4),
                  Switch(
                    value: monoOnly,
                    onChanged: (value) => ref
                        .read(monospaceTerminalFontsOnlyProvider.notifier)
                        .setEnabled(value),
                  ),
                ],
              );

        void setFontFamily(String? family) {
          if (family != null) {
            ref.read(terminalFontFamilyProvider.notifier).setFontFamily(family);
          }
        }

        // Filterable: the system font list is long enough to type into.
        final fontDropdown = ConduitDropdown<String>(
          value: current,
          filterable: true,
          label: 'settingsTerminalFont'.tr(),
          onChanged: setFontFamily,
          entries: [
            for (final option in filtered)
              DropdownMenuEntry(
                value: option.family,
                label: option.label,
                labelWidget: Text(
                  option.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: option.family),
                ),
              ),
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            fontDropdown,
            const SizedBox(height: 4),
            if (constraints.maxWidth < 420)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [fontHint, monospaceToggle],
              )
            else
              Row(
                children: [
                  Expanded(child: fontHint),
                  const SizedBox(width: 8),
                  monospaceToggle,
                ],
              ),
          ],
        );
      },
    );
  }
}

class _TerminalThemeTile extends StatelessWidget {
  const _TerminalThemeTile({
    required this.mode,
    required this.theme,
    required this.onEdit,
  });

  final Brightness mode;
  final TerminalColorScheme theme;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final titleKey = mode == Brightness.light
        ? 'settingsTerminalThemeLight'
        : 'settingsTerminalThemeDark';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: TerminalPalettePreview(theme: theme),
      title: Text(titleKey.tr()),
      subtitle: const Text('settingsTerminalThemeHint').tr(),
      trailing: IconButton(
        tooltip: 'settingsTerminalThemeEdit'.tr(),
        onPressed: onEdit,
        icon: const Icon(Symbols.edit),
      ),
      onTap: onEdit,
    );
  }
}
