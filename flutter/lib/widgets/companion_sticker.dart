import 'package:flutter/material.dart';

import '../features/companion/companion_art.dart';
import '../theme/device_layout.dart';
import '../theme/tito_colors.dart';
import 'dex_sprite_image.dart';

class CompanionSticker extends StatelessWidget {
  const CompanionSticker({
    super.key,
    required this.name,
    this.compact = false,
    this.onTap,
  });

  final String name;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final square = DeviceLayout.useSquareDashboard(context);
    final spriteSize = square
        ? DeviceLayout.dim(context, 52.0)
        : (compact ? DeviceLayout.dim(context, 52.0) : 72.0);

    return Semantics(
      button: onTap != null,
      label: '切换同行宝可梦',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: spriteSize,
            height: spriteSize,
            decoration: BoxDecoration(
              color: TitoColors.card,
              shape: BoxShape.circle,
              border: Border.all(
                color: TitoColors.ink,
                width: TitoBorders.element,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2818283B),
                  offset: Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: DexSpriteImage(
              source: companionSpriteSource(name),
              height: spriteSize,
              width: spriteSize,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

class FloatingCompanion extends StatelessWidget {
  const FloatingCompanion({
    super.key,
    required this.name,
    this.onTap,
  });

  final String name;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final square = DeviceLayout.useSquareDashboard(context);
    final compact = !square && MediaQuery.sizeOf(context).shortestSide < 520;

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: EdgeInsets.only(
            right: square ? 8 : (compact ? 6 : 10),
            bottom: DeviceLayout.companionOverlayBottom(context),
          ),
          child: CompanionSticker(
            name: name,
            compact: compact,
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}
