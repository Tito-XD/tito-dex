import 'package:flutter/material.dart';

import '../features/companion/companion_art.dart';
import '../l10n/game_zh.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';
import 'dex_sprite_image.dart';

class CompanionSticker extends StatelessWidget {
  const CompanionSticker({
    super.key,
    required this.name,
    this.message,
    this.compact = false,
  });

  final String name;
  final String? message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = message ?? '欢迎回来，训练家！';
    final spriteSize = compact ? 64.0 : 88.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: compact ? 150 : 190),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: TitoColors.card,
            borderRadius: BorderRadius.circular(TitoRadii.md),
            border: Border.all(color: TitoColors.ink, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3818283B),
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Text(
            text,
            style: compact
                ? context.tito.caption.copyWith(fontWeight: FontWeight.w700)
                : context.tito.companionBubble,
          ),
        ),
        SizedBox(height: compact ? 6 : 8),
        Container(
          width: spriteSize,
          height: spriteSize,
          decoration: BoxDecoration(
            color: TitoColors.card,
            shape: BoxShape.circle,
            border: Border.all(color: TitoColors.ink, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2818283B),
                offset: Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: DexSpriteImage(
            source: companionSpriteUrl(name),
            height: spriteSize,
            width: spriteSize,
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(height: compact ? 4 : 6),
        Text(
          localizeCompanion(name),
          style: compact
              ? context.tito.caption.copyWith(fontWeight: FontWeight.w800)
              : context.tito.companionName,
        ),
      ],
    );
  }
}

class FloatingCompanion extends StatelessWidget {
  const FloatingCompanion({
    super.key,
    required this.name,
    this.message,
  });

  final String name;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).shortestSide < 520;

    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: EdgeInsets.only(
            right: compact ? 4 : 8,
            bottom: compact ? 4 : 8,
          ),
          child: CompanionSticker(
            name: name,
            message: message,
            compact: compact,
          ),
        ),
      ),
    );
  }
}
