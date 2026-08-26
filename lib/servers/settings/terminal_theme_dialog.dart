import 'package:easy_localization/easy_localization.dart';
import 'package:material_ui/material_ui.dart';

import 'package:conduit/shared/presentation/conduit_dropdown.dart';
import '../terminal_color_scheme.dart';

/// Edits one of the terminal palettes; pops the new [TerminalColorScheme].
Future<TerminalColorScheme?> showTerminalThemeDialog(
  BuildContext context, {
  required Brightness brightness,
  required TerminalColorScheme initialScheme,
}) => showDialog<TerminalColorScheme>(
  context: context,
  builder: (context) =>
      TerminalThemeDialog(brightness: brightness, initialScheme: initialScheme),
);

/// A swatch of a terminal palette: background, foreground sample and the
/// sixteen ANSI colours.
class TerminalPalettePreview extends StatelessWidget {
  const TerminalPalettePreview({
    super.key,
    required this.theme,
    this.large = false,
  });

  final TerminalColorScheme theme;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: large ? 120 : 64,
      height: large ? 88 : 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aa',
            style: TextStyle(
              color: theme.foreground,
              fontSize: large ? 16 : 11,
              height: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: GridView.count(
              crossAxisCount: 8,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              mainAxisSpacing: 1,
              crossAxisSpacing: 1,
              children: [
                for (final color in theme.ansiColors)
                  Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TerminalThemeDialog extends StatefulWidget {
  const TerminalThemeDialog({
    super.key,
    required this.brightness,
    required this.initialScheme,
  });

  final Brightness brightness;
  final TerminalColorScheme initialScheme;

  @override
  State<TerminalThemeDialog> createState() => TerminalThemeDialogState();
}

class TerminalThemeDialogState extends State<TerminalThemeDialog> {
  static const _ansiBaseLabels = [
    'terminalColorBlack',
    'terminalColorRed',
    'terminalColorGreen',
    'terminalColorYellow',
    'terminalColorBlue',
    'terminalColorMagenta',
    'terminalColorCyan',
    'terminalColorWhite',
  ];

  late TerminalColorScheme _scheme;

  @override
  void initState() {
    super.initState();
    _scheme = widget.initialScheme;
  }

  Future<void> _editColor(
    String label,
    Color current,
    ValueChanged<Color> apply,
  ) async {
    final updated = await showDialog<Color>(
      context: context,
      builder: (context) =>
          _ColorEditDialog(title: label, initialColor: current),
    );
    if (updated != null) setState(() => apply(updated));
  }

  void _setAnsi(int index, Color color) {
    final ansi = List<Color>.of(_scheme.ansiColors);
    ansi[index] = color;
    _scheme = _scheme.copyWith(ansiColors: ansi);
  }

  void _save() => Navigator.of(context).pop(_scheme);

  @override
  Widget build(BuildContext context) {
    final titleKey = widget.brightness == Brightness.light
        ? 'settingsTerminalThemeLight'
        : 'settingsTerminalThemeDark';
    final presetId = TerminalColorSchemes.all
        .where((scheme) => scheme.id == _scheme.id)
        .firstOrNull
        ?.id;

    return AlertDialog(
      title: Text(titleKey.tr()),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The floating label rises above the field; without this gap the
              // scroll view clips it to its bottom half.
              const SizedBox(height: 8),
              ConduitDropdown<String>(
                value: presetId ?? 'custom',
                label: 'settingsTerminalThemePreset'.tr(),
                entries: [
                  for (final scheme in TerminalColorSchemes.all)
                    DropdownMenuEntry(value: scheme.id, label: scheme.label),
                  DropdownMenuEntry(
                    value: 'custom',
                    label: 'settingsTerminalThemeCustom'.tr(),
                  ),
                ],
                onChanged: (id) {
                  if (id == null || id == 'custom') return;
                  setState(() => _scheme = TerminalColorSchemes.byId(id));
                },
              ),
              const SizedBox(height: 16),
              Center(
                child: TerminalPalettePreview(theme: _scheme, large: true),
              ),
              const SizedBox(height: 16),
              _TerminalColorRow(
                label: 'settingsTerminalThemeBackground'.tr(),
                color: _scheme.background,
                onTap: () => _editColor(
                  'settingsTerminalThemeBackground'.tr(),
                  _scheme.background,
                  (color) => _scheme = _scheme.copyWith(background: color),
                ),
              ),
              _TerminalColorRow(
                label: 'settingsTerminalThemeForeground'.tr(),
                color: _scheme.foreground,
                onTap: () => _editColor(
                  'settingsTerminalThemeForeground'.tr(),
                  _scheme.foreground,
                  (color) => _scheme = _scheme.copyWith(foreground: color),
                ),
              ),
              _TerminalColorRow(
                label: 'settingsTerminalThemeCursor'.tr(),
                color: _scheme.cursor,
                onTap: () => _editColor(
                  'settingsTerminalThemeCursor'.tr(),
                  _scheme.cursor,
                  (color) => _scheme = _scheme.copyWith(cursor: color),
                ),
              ),
              _TerminalColorRow(
                label: 'settingsTerminalThemeSelection'.tr(),
                color: _scheme.selection,
                onTap: () => _editColor(
                  'settingsTerminalThemeSelection'.tr(),
                  _scheme.selection,
                  (color) => _scheme = _scheme.copyWith(selection: color),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'settingsTerminalThemeNormal'.tr(),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (var i = 0; i < 8; i++)
                _TerminalColorRow(
                  label: _ansiBaseLabels[i].tr(),
                  color: _scheme.ansiColors[i],
                  onTap: () => _editColor(
                    _ansiBaseLabels[i].tr(),
                    _scheme.ansiColors[i],
                    (color) => _setAnsi(i, color),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'settingsTerminalThemeBright'.tr(),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (var i = 0; i < 8; i++)
                _TerminalColorRow(
                  label: 'terminalColorBright'.tr(
                    args: [_ansiBaseLabels[i].tr()],
                  ),
                  color: _scheme.ansiColors[i + 8],
                  onTap: () => _editColor(
                    'terminalColorBright'.tr(args: [_ansiBaseLabels[i].tr()]),
                    _scheme.ansiColors[i + 8],
                    (color) => _setAnsi(i + 8, color),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('commonCancel'.tr()),
        ),
        FilledButton(onPressed: _save, child: Text('settingsThemeSave'.tr())),
      ],
    );
  }
}

class _TerminalColorRow extends StatelessWidget {
  const _TerminalColorRow({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      title: Text(label),
      trailing: Text(
        _hexFor(color),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: onTap,
    );
  }
}

class _ColorEditDialog extends StatefulWidget {
  const _ColorEditDialog({required this.title, required this.initialColor});

  final String title;
  final Color initialColor;

  @override
  State<_ColorEditDialog> createState() => _ColorEditDialogState();
}

class _ColorEditDialogState extends State<_ColorEditDialog> {
  late final TextEditingController _hexController;
  late int _red;
  late int _green;
  late int _blue;
  String? _colorError;

  @override
  void initState() {
    super.initState();
    final color = widget.initialColor;
    _red = color.r.toInt();
    _green = color.g.toInt();
    _blue = color.b.toInt();
    _hexController = TextEditingController(text: _hexFor(_color));
  }

  Color get _color => Color.fromARGB(255, _red, _green, _blue);

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _updateFromHex(String value) {
    final color = _colorFromHex(value);
    setState(() {
      _colorError = color == null ? 'settingsThemeInvalidColor'.tr() : null;
      if (color != null) {
        _red = color.r.toInt();
        _green = color.g.toInt();
        _blue = color.b.toInt();
      }
    });
  }

  void _updateColor(void Function() update) {
    setState(() {
      update();
      _colorError = null;
      _hexController.text = _hexFor(_color);
    });
  }

  void _save() {
    final color = _colorFromHex(_hexController.text);
    if (color == null) {
      setState(() => _colorError = 'settingsThemeInvalidColor'.tr());
      return;
    }
    Navigator.of(context).pop(color);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _hexController,
                      maxLength: 7,
                      onChanged: _updateFromHex,
                      decoration: InputDecoration(
                        labelText: 'settingsThemeColor'.tr(),
                        hintText: '#0F766E',
                        errorText: _colorError,
                        counterText: '',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'settingsThemeColorHint'.tr(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              _ColorChannelSlider(
                label: 'R',
                value: _red,
                onChanged: (value) => _updateColor(() => _red = value),
              ),
              _ColorChannelSlider(
                label: 'G',
                value: _green,
                onChanged: (value) => _updateColor(() => _green = value),
              ),
              _ColorChannelSlider(
                label: 'B',
                value: _blue,
                onChanged: (value) => _updateColor(() => _blue = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('commonCancel'.tr()),
        ),
        FilledButton(onPressed: _save, child: Text('settingsThemeSave'.tr())),
      ],
    );
  }
}

class _ColorChannelSlider extends StatelessWidget {
  const _ColorChannelSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 20, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 255,
            divisions: 255,
            label: '$value',
            onChanged: (value) => onChanged(value.round()),
          ),
        ),
        SizedBox(width: 28, child: Text('$value')),
      ],
    );
  }
}

String _hexFor(Color color) =>
    '#${color.r.toInt().toRadixString(16).padLeft(2, '0').toUpperCase()}${color.g.toInt().toRadixString(16).padLeft(2, '0').toUpperCase()}${color.b.toInt().toRadixString(16).padLeft(2, '0').toUpperCase()}';

Color? _colorFromHex(String value) {
  final hex = value.trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
  return Color(int.parse('FF$hex', radix: 16));
}
