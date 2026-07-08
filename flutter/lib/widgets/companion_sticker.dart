import 'package:flutter/material.dart';

import '../l10n/game_zh.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';

class CompanionSticker extends StatelessWidget {
  const CompanionSticker({
    super.key,
    required this.name,
    this.message,
  });

  final String name;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message ?? '欢迎回来，训练家！';

    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              style: context.tito.companionBubble,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: TitoColors.skyBlue,
              shape: BoxShape.circle,
              border: Border.all(color: TitoColors.ink, width: 3),
            ),
            alignment: Alignment.center,
            child: const Text('🐾', style: TextStyle(fontSize: 32)),
          ),
          const SizedBox(height: 6),
          Text(
            localizeCompanion(name),
            style: context.tito.companionName,
          ),
        ],
      ),
    );
  }
}
