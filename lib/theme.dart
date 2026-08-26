import 'package:material_ui/material_ui.dart';

/// Registered font families from `assets/fonts`.
abstract final class ConduitFonts {
  static const sans = 'IBM Plex Sans';
  static const mono = 'IBM Plex Mono';
}

/// The application-wide Material theme. Keep feature widgets dependent on this
/// shared foundation instead of creating local colour schemes or chrome.
ThemeData createConduitTheme(Brightness brightness, {Color? seedColor}) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor ?? const Color(0xFF0F766E),
    brightness: brightness,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    brightness: brightness,
    fontFamily: ConduitFonts.sans,
    appBarTheme: const AppBarTheme(centerTitle: false),
    navigationRailTheme: const NavigationRailThemeData(
      groupAlignment: -1,
      labelType: NavigationRailLabelType.all,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder()},
    ),
  );
}
