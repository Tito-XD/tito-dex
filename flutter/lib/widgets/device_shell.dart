import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_visual_style.dart';
import '../theme/device_layout.dart';
import '../theme/tito_colors.dart';
import 'liquid_glass.dart';

class DeviceShell extends StatelessWidget {
  const DeviceShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final handheldChrome = DeviceLayout.useHandheldChrome(context);
    final scheme = Theme.of(context).colorScheme;
    final flatUi = appVisualStyle.usesFlatUi;
    final solidPlastic = appVisualStyle.usesSolidPlastic;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (flatUi ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light)
          .copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: flatUi
                ? Brightness.dark
                : Brightness.light,
            systemNavigationBarColor: flatUi
                ? scheme.surface
                : solidPlastic
                ? TitoColors.glassBackgroundTop
                : TitoColors.deepBlue,
            systemNavigationBarIconBrightness: flatUi
                ? Brightness.dark
                : Brightness.light,
            systemNavigationBarDividerColor: flatUi
                ? scheme.surface
                : solidPlastic
                ? TitoColors.glassBackgroundTop
                : TitoColors.deepBlue,
          ),
      child: MediaQuery(
        data: mq.copyWith(textScaler: DeviceLayout.clampedTextScaler(context)),
        child: handheldChrome
            ? _HandheldNativeShell(child: child)
            : (DeviceLayout.isNativeTarget
                  ? _RegularNativeShell(child: child)
                  : _PreviewShell(child: child)),
      ),
    );
  }
}

/// RG 1:1 / 3:4 / 4:3 — immersive, no system bar insets on top/bottom.
class _HandheldNativeShell extends StatelessWidget {
  const _HandheldNativeShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final size = MediaQuery.sizeOf(context);

    return _ThemeBackdrop(
      child: Padding(
        padding: EdgeInsets.only(left: padding.left, right: padding.right),
        // RG immersive shell strips top/bottom safe padding — without an
        // explicit height, route ListViews see unbounded max height and
        // behave like an infinitely growing scroll surface.
        child: SizedBox(
          height: size.height,
          width: size.width - padding.left - padding.right,
          child: child,
        ),
      ),
    );
  }
}

/// Phone / non-handheld native — edge-to-edge, system status + nav bars.
///
/// No SafeArea here on purpose: routes paint full-bleed so Android's
/// predictive-back gesture retracts the whole screen (Telegram-style) instead
/// of starting below the status bar. Content insets live in
/// [TitoPageContainer]'s own SafeArea. The backdrop reuses the page gradient
/// (not the old light skyBlue ramp) so anything revealed behind a
/// transitioning route — rounded corners, commit gaps — blends in seamlessly.
class _RegularNativeShell extends StatelessWidget {
  const _RegularNativeShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _ThemeBackdrop(child: child);
  }
}

class _ThemeBackdrop extends StatelessWidget {
  const _ThemeBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (appVisualStyle.usesSolidPlastic) {
      return LiquidGlassBackground(child: child);
    }
    if (appVisualStyle.usesFlatUi) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: child,
      );
    }
    return ColoredBox(
      color: TitoColors.deepBlue,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF5D728A), TitoColors.slateBlue],
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Legacy alias — kept for references.
class _PreviewShell extends StatelessWidget {
  const _PreviewShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainer,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Material(
                color: scheme.surface,
                elevation: 3,
                surfaceTintColor: scheme.surfaceTint,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(TitoRadii.xl),
                  side: BorderSide(color: scheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    const _StatusStrip(),
                    Expanded(child: child),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: scheme.surfaceContainerHigh,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'TitoDex',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const Row(
            children: [_StatusDot(), SizedBox(width: 6), _BatteryIcon()],
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
    );
  }
}

class _BatteryIcon extends StatelessWidget {
  const _BatteryIcon();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 18,
      height: 10,
      decoration: BoxDecoration(
        border: Border.all(color: scheme.onSurfaceVariant, width: 1.5),
        borderRadius: BorderRadius.circular(2),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.all(1),
      child: Container(
        width: 11,
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}
