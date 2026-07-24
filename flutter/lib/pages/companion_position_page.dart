import 'package:flutter/material.dart';

import '../features/companion/companion_art.dart';
import '../features/companion/companion_repository.dart';
import '../features/companion/companion_media.dart';
import '../features/dex/sprite_generation_catalog.dart';
import '../l10n/app_zh.dart';
import '../models/journey.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../widgets/fallback_sprite_image.dart';
import '../widgets/secondary_page_scaffold.dart';
import '../widgets/sticker_card.dart';

/// Drag-to-position page for the home standby companion.
///
/// The preview box uses the same alignment coordinate system as the home
/// overlay, so the handle's dragged position maps 1:1 to the real location.
class CompanionPositionPage extends StatefulWidget {
  const CompanionPositionPage({super.key, required this.journey});

  final CurrentJourney journey;

  @override
  State<CompanionPositionPage> createState() => _CompanionPositionPageState();
}

class _CompanionPositionPageState extends State<CompanionPositionPage> {
  late double _offsetX;
  late double _offsetY;

  @override
  void initState() {
    super.initState();
    _offsetX = companionRepository.offsetX;
    _offsetY = companionRepository.offsetY;
  }

  void _updateOffset(Offset local, Size size) {
    final x = (local.dx / size.width * 2 - 1).clamp(-1.0, 1.0);
    final y = (local.dy / size.height * 2 - 1).clamp(-1.0, 1.0);
    setState(() {
      _offsetX = x;
      _offsetY = y;
    });
    companionRepository.setOffset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    final choice = companionRepository.choice;
    final speciesId = choice?.pokemonId ??
        speciesIdForName(widget.journey.companion) ??
        companionSpeciesIds[hgssDefaultCompanion]!;

    return SecondaryPageScaffold(
      title: AppZh.companionPositionTitle,
      children: [
        StickerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppZh.companionPositionHint,
                style: SecondaryTypography.onCard.body14,
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = width * 1.2;
                  return Container(
                    width: width,
                    height: height,
                    decoration: BoxDecoration(
                      color: TitoColors.cream.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(TitoRadii.md),
                      border: Border.all(
                        color: TitoColors.ink.withValues(alpha: 0.25),
                        width: 2,
                      ),
                    ),
                    child: GestureDetector(
                      onTapDown: (details) => _updateOffset(
                        details.localPosition,
                        Size(width, height),
                      ),
                      onPanUpdate: (details) => _updateOffset(
                        details.localPosition,
                        Size(width, height),
                      ),
                      behavior: HitTestBehavior.opaque,
                      child: Stack(
                        children: [
                          Align(
                            alignment: Alignment(_offsetX, _offsetY),
                            child: _PositionHandle(
                              speciesId: speciesId,
                              isShiny: choice?.isShiny ?? false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () async {
                  await companionRepository.resetOffset();
                  setState(() {
                    _offsetX = companionRepository.offsetX;
                    _offsetY = companionRepository.offsetY;
                  });
                },
                child: Text(AppZh.companionPositionReset),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PositionHandle extends StatelessWidget {
  const _PositionHandle({required this.speciesId, required this.isShiny});

  final int speciesId;
  final bool isShiny;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: TitoColors.card,
        shape: BoxShape.circle,
        border: Border.all(color: TitoColors.ink, width: 2),
        boxShadow: [
          BoxShadow(
            color: TitoColors.ink.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(4),
      child: FallbackSpriteImage(
        sources: [
          if (isShiny) ...animatedShinySpriteCandidatesFor(speciesId),
          if (bundledCompanionGifAsset(speciesId) != null)
            bundledCompanionGifAsset(speciesId)!,
          ...animatedSpriteCandidatesFor(speciesId),
        ],
        showLoadingProgress: false,
      ),
    );
  }
}
