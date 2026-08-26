import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// File name used for an optional user-provided workspace background image.
///
/// Keeping it in the application-support directory follows Island's approach
/// and avoids making a large image part of the app bundle.
const kConduitBackgroundImagePath = 'maidkit_app_background';
const _conduitBackgroundImageEnabledKey = 'maidkit_background_image_enabled';
const _conduitTransparentTerminalKey = 'maidkit_transparent_terminal';
const _conduitWindowOpacityKey = 'maidkit_window_opacity';

final conduitBackgroundImageProvider = FutureProvider<File?>((ref) async {
  final directory = await getApplicationSupportDirectory();
  final file = File('${directory.path}/$kConduitBackgroundImagePath');
  return file.existsSync() ? file : null;
});

final conduitBackgroundImageEnabledProvider = FutureProvider<bool>((ref) async {
  return await SharedPreferencesAsync().getBool(
        _conduitBackgroundImageEnabledKey,
      ) ??
      true;
});

final transparentTerminalBackgroundEnabledProvider = FutureProvider<bool>((
  ref,
) async {
  return await SharedPreferencesAsync().getBool(
        _conduitTransparentTerminalKey,
      ) ??
      false;
});

final transparentTerminalBackgroundProvider = Provider<bool>((ref) {
  final hasImage =
      ref.watch(conduitBackgroundImageProvider).asData?.value != null;
  final imageEnabled =
      ref.watch(conduitBackgroundImageEnabledProvider).asData?.value ?? true;
  final preference =
      ref.watch(transparentTerminalBackgroundEnabledProvider).asData?.value ??
      false;
  return hasImage && imageEnabled && preference;
});

final conduitWindowOpacityProvider = FutureProvider<double>((ref) async {
  return await loadConduitWindowOpacity();
});

Future<double> loadConduitWindowOpacity() async {
  final value = await SharedPreferencesAsync().getDouble(
    _conduitWindowOpacityKey,
  );
  return (value ?? 1.0).clamp(0.4, 1.0).toDouble();
}

Future<void> setConduitBackgroundImageEnabled(
  WidgetRef ref,
  bool enabled,
) async {
  await SharedPreferencesAsync().setBool(
    _conduitBackgroundImageEnabledKey,
    enabled,
  );
  ref.invalidate(conduitBackgroundImageEnabledProvider);
}

Future<void> setTransparentTerminalBackgroundEnabled(
  WidgetRef ref,
  bool enabled,
) async {
  await SharedPreferencesAsync().setBool(
    _conduitTransparentTerminalKey,
    enabled,
  );
  // A terminal tab can be building while this preference finishes writing.
  // Defer the notification in that case so Riverpod does not mark its scope
  // dirty during Flutter's build phase.
  if (SchedulerBinding.instance.schedulerPhase ==
      SchedulerPhase.persistentCallbacks) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.invalidate(transparentTerminalBackgroundEnabledProvider),
    );
  } else {
    ref.invalidate(transparentTerminalBackgroundEnabledProvider);
  }
}

Future<void> setConduitWindowOpacity(WidgetRef ref, double opacity) async {
  final value = opacity.clamp(0.4, 1.0).toDouble();
  await SharedPreferencesAsync().setDouble(_conduitWindowOpacityKey, value);
  if (DesktopWindowFrame.isPlatformDesktop) {
    await windowManager.setOpacity(value);
  }
  ref.invalidate(conduitWindowOpacityProvider);
}

Future<void> saveConduitBackgroundImage(WidgetRef ref, File source) async {
  final directory = await getApplicationSupportDirectory();
  await source.copy('${directory.path}/$kConduitBackgroundImagePath');
  await setConduitBackgroundImageEnabled(ref, true);
  ref.invalidate(conduitBackgroundImageProvider);
}

Future<void> clearConduitBackgroundImage(WidgetRef ref) async {
  final directory = await getApplicationSupportDirectory();
  final file = File('${directory.path}/$kConduitBackgroundImagePath');
  if (await file.exists()) await file.delete();
  ref.invalidate(conduitBackgroundImageProvider);
}

/// Paints the normal app surface, optionally softened by a user background.
///
/// The layer belongs inside a page scaffold rather than the root window shell,
/// so a route's safe-area and back-swipe transitions remain self-contained.
class ConduitAppBackground extends ConsumerWidget {
  const ConduitAppBackground({
    super.key,
    required this.child,
    required this.color,
    this.showBackgroundImage = true,
  });

  final Widget child;
  final Color color;
  final bool showBackgroundImage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(conduitBackgroundImageProvider).asData?.value;
    final isEnabled =
        ref.watch(conduitBackgroundImageEnabledProvider).asData?.value ?? true;

    // The solid page color is painted by the Scaffold itself; this box only
    // layers the optional background image. Keeping the color out of the
    // decoration (and providing a transparent Material above it) lets
    // ListTile ink and tile backgrounds paint on top instead of being
    // hidden underneath.
    return DecoratedBox(
      decoration: BoxDecoration(
        image: !showBackgroundImage || !isEnabled || image == null
            ? null
            : DecorationImage(
                image: FileImage(image),
                fit: BoxFit.cover,
                opacity: 0.18,
                colorFilter: ColorFilter.mode(
                  color.withValues(alpha: 0.48),
                  BlendMode.srcOver,
                ),
              ),
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

/// Standard page foundation for Conduit routes.
///
/// Unlike the former window-level safe-area shell, this keeps MediaQuery
/// insets intact until the page that owns the content decides to consume them.
/// The scaffold always paints an opaque Material surface, which keeps iOS
/// gesture-back transitions from revealing a transparent route underneath.
///
/// By default the scaffold consumes the top inset when there is no [appBar].
/// Shells that host other page scaffolds can pass `topSafeArea: false` so the
/// content pages manage the top inset themselves, which keeps their surface
/// painting edge-to-edge behind the status bar.
class ConduitAppScaffold extends StatelessWidget {
  const ConduitAppScaffold({
    super.key,
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.drawer,
    this.endDrawer,
    this.extendBody = false,
    this.useSafeArea = true,
    this.topSafeArea = true,
    this.backgroundColor,
    this.showBackgroundImage = true,
  });

  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;
  final Widget? drawer;
  final Widget? endDrawer;
  final bool extendBody;

  /// Master switch for the scaffold-level safe-area handling.
  final bool useSafeArea;

  /// Whether this scaffold consumes the top inset itself. Set to false for
  /// shells whose body hosts other page scaffolds, so those content pages
  /// control the top safe area.
  final bool topSafeArea;

  final Color? backgroundColor;
  final bool showBackgroundImage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pageColor = backgroundColor ?? scheme.surface;
    final bodyContent = body == null
        ? const SizedBox.shrink()
        : ConduitAppBackground(
            color: pageColor,
            showBackgroundImage: showBackgroundImage,
            child: useSafeArea
                ? SafeArea(
                    top: topSafeArea && appBar == null,
                    bottom: bottomNavigationBar == null,
                    child: body!,
                  )
                : body!,
          );

    return Scaffold(
      backgroundColor: pageColor,
      appBar: appBar,
      body: bodyContent,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      bottomSheet: bottomSheet,
      drawer: drawer,
      endDrawer: endDrawer,
      extendBody: extendBody,
    );
  }
}
