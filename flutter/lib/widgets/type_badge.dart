import 'package:flutter/material.dart';

import '../features/dex/type_chart.dart';
import '../theme/tito_colors.dart';
import '../theme/tito_typography.dart';

enum TypeBadgeSize { small, medium }

/// Sticker-style type badge: colored pill with symbol icon + Chinese label.
///
/// Replaces the old CDN English name-badge images (PokeAPI only provides
/// English `name_icon` sprites), matching 52poke's icon + text combo.
class TitoTypeBadge extends StatelessWidget {
  const TitoTypeBadge({
    super.key,
    required this.typeEn,
    this.size = TypeBadgeSize.medium,
  });

  final String typeEn;
  final TypeBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final small = size == TypeBadgeSize.small;
    final iconSize = small ? 11.0 : 14.0;
    final fontSize = small ? 10.0 : 12.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 5 : 8,
        vertical: small ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: typeTileColor(typeEn),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: TitoColors.ink, width: small ? 1.5 : 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            typeIconData(typeEn),
            size: iconSize,
            color: TitoColors.ink,
          ),
          SizedBox(width: small ? 2 : 4),
          Text(
            typeNameZh(typeEn),
            style: TitoTypography.style(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// One-line row of type badges; scales down instead of wrapping/overflowing.
class TitoTypeBadgeRow extends StatelessWidget {
  const TitoTypeBadgeRow({
    super.key,
    required this.typesEn,
    this.size = TypeBadgeSize.small,
    this.spacing = 4,
  });

  final List<String> typesEn;
  final TypeBadgeSize size;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (typesEn.isEmpty) {
      return const SizedBox.shrink();
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < typesEn.length; i++) ...[
            if (i > 0) SizedBox(width: spacing),
            TitoTypeBadge(typeEn: typesEn[i], size: size),
          ],
        ],
      ),
    );
  }
}
