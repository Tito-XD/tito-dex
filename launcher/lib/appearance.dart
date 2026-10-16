import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';

const navy = Color(0xff2f4361),
    cream = Color(0xfffff7e6),
    coral = Color(0xffff8f6a),
    yellow = Color(0xfff7d977);
const styleLabels = ['训练家手帐', '固态塑料', '扁平贴纸'];
const wallpaperLabels = ['无壁纸', '海岸', '暮色', '森林', '我的照片'];
const effectLabels = ['原图', '柔焦模糊', '暗色遮罩', '复古扫描线'];
Color backgroundInk(LauncherSettings settings) =>
    (settings.wallpaper == Wallpaper.none &&
            settings.style == LauncherStyle.plastic) ||
        settings.effect == WallpaperEffect.dim ||
        settings.wallpaper == Wallpaper.dusk ||
        settings.wallpaper == Wallpaper.photo
    ? cream
    : navy;

ThemeData launcherTheme(LauncherStyle style) {
  final scheme = ColorScheme.fromSeed(
    seedColor: navy,
    primary: navy,
    secondary: coral,
    surface: style == LauncherStyle.flat ? const Color(0xfff9f9ff) : cream,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Nunito',
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 14, color: navy),
      titleLarge: TextStyle(
        fontSize: 23,
        fontWeight: FontWeight.w800,
        color: navy,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: .7),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: navy,
    ),
  );
}

class LauncherBackground extends StatelessWidget {
  const LauncherBackground({super.key, required this.settings});
  final LauncherSettings settings;
  @override
  Widget build(BuildContext context) {
    final colors = switch (settings.wallpaper) {
      Wallpaper.coast => [const Color(0xff8ec5c6), const Color(0xffdbe8d4)],
      Wallpaper.dusk => [const Color(0xff65688b), const Color(0xffd8a899)],
      Wallpaper.forest => [const Color(0xff8ab09b), const Color(0xffc8d8b6)],
      _ => switch (settings.style) {
        LauncherStyle.journal => [
          const Color(0xffa9becd),
          const Color(0xffd9e2df),
        ],
        LauncherStyle.plastic => [
          const Color(0xff344d6b),
          const Color(0xff758fa2),
        ],
        LauncherStyle.flat => [
          const Color(0xffe3e6ef),
          const Color(0xffeef0f6),
        ],
      },
    };
    Widget backdrop = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: settings.wallpaper == Wallpaper.photo && settings.photo != null
          ? Image.file(
              File(settings.photo!),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              cacheWidth: 1200,
              errorBuilder: (_, _, _) => const SizedBox.expand(),
            )
          : CustomPaint(
              painter: LandscapePainter(settings.wallpaper),
              child: const SizedBox.expand(),
            ),
    );
    if (settings.effect == WallpaperEffect.frost) {
      backdrop = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: 12,
          sigmaY: 12,
          tileMode: TileMode.clamp,
        ),
        child: backdrop,
      );
    }
    return ExcludeSemantics(
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(child: backdrop),
          if (settings.wallpaper == Wallpaper.photo)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xb3001020),
                    Color(0x99001020),
                    Color(0x22001020),
                  ],
                  stops: [0, .23, .5],
                ),
              ),
            ),
          if (settings.effect == WallpaperEffect.dim)
            const ColoredBox(color: Color(0x660b2036)),
          if (settings.effect == WallpaperEffect.scanlines)
            CustomPaint(painter: ScanlinePainter()),
        ],
      ),
    );
  }
}

class LandscapePainter extends CustomPainter {
  LandscapePainter(this.wallpaper);
  final Wallpaper wallpaper;
  @override
  void paint(Canvas canvas, Size size) {
    if (wallpaper == Wallpaper.photo) return;
    final w = size.width, h = size.height;
    final paint = Paint();
    if (wallpaper == Wallpaper.none) {
      // A quiet contour in the theme background, no external wallpaper required.
      paint
        ..color = Colors.white.withValues(alpha: .16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      for (var i = 0; i < 4; i++) {
        final path = Path()..moveTo(w * .43, h * (.25 + i * .04));
        path.cubicTo(
          w * .6,
          h * (.14 + i * .04),
          w * .8,
          h * (.4 + i * .04),
          w * 1.1,
          h * (.27 + i * .04),
        );
        canvas.drawPath(path, paint);
      }
      return;
    }
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(
        0xffffe4ab,
      ).withValues(alpha: wallpaper == Wallpaper.dusk ? .6 : .5);
    canvas.drawCircle(Offset(w * .78, h * .27), w * .085, paint);
    for (var i = 0; i < 3; i++) {
      paint.color =
          (wallpaper == Wallpaper.forest ? const Color(0xff255d55) : navy)
              .withValues(alpha: .09 + i * .055);
      final path = Path()..moveTo(0, h * (.43 + i * .17));
      path.cubicTo(
        w * .25,
        h * (.36 + i * .13),
        w * .65,
        h * (.68 + i * .1),
        w,
        h * (.39 + i * .17),
      );
      path.lineTo(w, h);
      path.lineTo(0, h);
      path.close();
      canvas.drawPath(path, paint);
    }
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = cream.withValues(alpha: .32);
    for (var i = 0; i < 3; i++) {
      final path = Path()..moveTo(w * .5, h * (.35 + i * .025));
      path.quadraticBezierTo(
        w * .7,
        h * (.42 + i * .025),
        w,
        h * (.31 + i * .025),
      );
      canvas.drawPath(path, paint);
    }
    if (wallpaper == Wallpaper.dusk) {
      paint
        ..style = PaintingStyle.fill
        ..color = cream.withValues(alpha: .5);
      for (final point in [
        const Offset(.64, .16),
        const Offset(.88, .12),
        const Offset(.94, .33),
      ]) {
        canvas.drawCircle(Offset(w * point.dx, h * point.dy), 1.4, paint);
      }
    }
    if (wallpaper == Wallpaper.forest) {
      paint
        ..style = PaintingStyle.fill
        ..color = const Color(0xff29574f).withValues(alpha: .32);
      for (var i = 0; i < 5; i++) {
        final x = w * (.6 + i * .07), y = h * (.42 + (i % 2) * .035);
        canvas.drawPath(
          Path()
            ..moveTo(x, y - 17)
            ..lineTo(x - 8, y + 5)
            ..lineTo(x + 8, y + 5)
            ..close(),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(LandscapePainter old) => old.wallpaper != wallpaper;
}

class ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x18000000);
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(ScanlinePainter old) => false;
}

class Surface extends StatelessWidget {
  const Surface({
    super.key,
    required this.style,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(16),
  });
  final LauncherStyle style;
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color:
          color ??
          (style == LauncherStyle.flat ? const Color(0xfff9f9ff) : cream),
      borderRadius: BorderRadius.circular(
        style == LauncherStyle.plastic ? 28 : 22,
      ),
      border: Border.all(
        color: style == LauncherStyle.journal
            ? navy
            : Colors.white.withValues(alpha: .65),
        width: style == LauncherStyle.journal ? 2 : 1,
      ),
      boxShadow: switch (style) {
        LauncherStyle.journal => [
          const BoxShadow(color: Color(0x382f4361), offset: Offset(0, 4)),
        ],
        LauncherStyle.plastic => [
          const BoxShadow(
            color: Color(0x30203040),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
        LauncherStyle.flat => [],
      },
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
}

/// Small bounded blur surfaces; never blur an entire scrolling application list.
class AirPanel extends StatelessWidget {
  const AirPanel({
    super.key,
    required this.settings,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.accent = false,
  });
  final LauncherSettings settings;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool accent;
  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(
      settings.style == LauncherStyle.flat ? 18 : 23,
    );
    final base = accent
        ? const Color(0xffe8c98c)
        : switch (settings.style) {
            LauncherStyle.flat => const Color(0xfff6f8ff),
            LauncherStyle.plastic => const Color(0xffeaf3f5),
            LauncherStyle.journal => cream,
          };
    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            base.withValues(alpha: (settings.opacity + .12).clamp(0, 1)),
            base.withValues(alpha: settings.opacity),
          ],
        ),
        borderRadius: radius,
        border: Border.all(
          color: settings.style == LauncherStyle.journal
              ? navy.withValues(alpha: .2)
              : Colors.white.withValues(alpha: .65),
          width: .8,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(padding: padding, child: child),
      ),
    );
    if (settings.blurPanels && settings.opacity < 1) {
      content = BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 9, sigmaY: 9),
        child: content,
      );
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: navy.withValues(
              alpha: settings.style == LauncherStyle.flat ? .04 : .1,
            ),
            blurRadius: settings.style == LauncherStyle.journal ? 0 : 16,
            offset: Offset(0, settings.style == LauncherStyle.journal ? 3 : 6),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: radius, child: content),
    );
  }
}

class DesktopButton extends StatefulWidget {
  const DesktopButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.onOptions,
    this.focusNode,
    this.autofocus = false,
    this.radius = 20,
    this.foreground = navy,
    this.label,
    this.onFocus,
  });
  final Widget child;
  final VoidCallback onPressed;
  final VoidCallback? onOptions;
  final FocusNode? focusNode;
  final bool autofocus;
  final double radius;
  final Color foreground;
  final String? label;
  final ValueChanged<bool>? onFocus;
  @override
  State<DesktopButton> createState() => _DesktopButtonState();
}

class _DesktopButtonState extends State<DesktopButton> {
  bool focused = false, pressed = false;
  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    button: true,
    child: CallbackShortcuts(
      bindings: {
        if (widget.onOptions != null)
          const SingleActivator(LogicalKeyboardKey.gameButtonX):
              widget.onOptions!,
        if (widget.onOptions != null)
          const SingleActivator(LogicalKeyboardKey.contextMenu):
              widget.onOptions!,
      },
      child: AnimatedScale(
        scale: pressed && !MediaQuery.disableAnimationsOf(context) ? .975 : 1,
        duration: const Duration(milliseconds: 100),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(
              color: focused ? coral : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              focusNode: widget.focusNode,
              autofocus: widget.autofocus,
              onFocusChange: (v) {
                setState(() => focused = v);
                widget.onFocus?.call(v);
              },
              onHighlightChanged: (v) => setState(() => pressed = v),
              onTap: widget.onPressed,
              onLongPress: widget.onOptions,
              borderRadius: BorderRadius.circular(widget.radius),
              focusColor: widget.foreground.withValues(alpha: .08),
              child: widget.child,
            ),
          ),
        ),
      ),
    ),
  );
}

Widget appArtwork(LaunchApp app, double size) => app.icon.isEmpty
    ? SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            app.label.isEmpty
                ? '?'
                : String.fromCharCode(app.label.runes.first),
            style: TextStyle(fontSize: size * .5, fontWeight: FontWeight.w800),
          ),
        ),
      )
    : Image.memory(
        app.icon,
        width: size,
        height: size,
        errorBuilder: (_, _, _) => SizedBox(
          width: size,
          height: size,
          child: const Icon(Icons.apps_rounded),
        ),
      );
