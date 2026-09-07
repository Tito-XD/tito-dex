import 'package:flutter/material.dart';

import '../features/companion/companion_art.dart';
import '../features/companion/companion_repository.dart';
import '../features/companion/companion_media.dart';
import '../features/dex/sprite_generation_catalog.dart';
import '../l10n/app_zh.dart';
import '../models/journey.dart';
import '../theme/app_visual_style.dart';
import '../theme/device_layout.dart';
import '../theme/retro_style.dart';
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

  void _moveBy(Offset delta, Size size, Size handleSize) {
    // A degenerate box (0×0 during an early layout frame) would make the
    // divisions 0/0 = NaN, and clamp() passes NaN through — Alignment(NaN)
    // then throws in the render tree. Ignore the event until the box is laid.
    final travelWidth = size.width - handleSize.width;
    final travelHeight = size.height - handleSize.height;
    if (travelWidth <= 0 || travelHeight <= 0) {
      return;
    }
    setState(() {
      _offsetX = (_offsetX + delta.dx * 2 / travelWidth).clamp(-1.0, 1.0);
      _offsetY = (_offsetY + delta.dy * 2 / travelHeight).clamp(-1.0, 1.0);
    });
  }

  void _moveTo(Offset local, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    setState(() {
      _offsetX = (local.dx / size.width * 2 - 1).clamp(-1.0, 1.0);
      _offsetY = (local.dy / size.height * 2 - 1).clamp(-1.0, 1.0);
    });
  }

  void _commitOffset() {
    companionRepository.setOffset(_offsetX, _offsetY);
  }

  @override
  Widget build(BuildContext context) {
    final choice = companionRepository.choice;
    final speciesId =
        choice?.pokemonId ??
        speciesIdForName(widget.journey.companion) ??
        companionSpeciesIds[hgssDefaultCompanion]!;
    final pagePadding = DeviceLayout.pagePadding(context);
    final square = DeviceLayout.useSquareDashboard(context);
    final compact = !square && MediaQuery.sizeOf(context).shortestSide < 520;
    final companionPadding = EdgeInsets.only(
      right: square ? 8 : (compact ? 6 : 10),
      bottom: DeviceLayout.companionOverlayBottom(context),
    );
    final scheme = Theme.of(context).colorScheme;
    // The drag canvas is a faint frame over the page background; Flat UI uses
    // its own surface tones while the gradient themes keep the cream tint.
    final (canvasFill, canvasOutline) = appVisualStyle.usesFlatUi
        ? (scheme.surfaceContainerLow, scheme.outlineVariant)
        : (
            TitoColors.cream.withValues(alpha: 0.16),
            TitoColors.card.withValues(alpha: 0.35),
          );

    return Padding(
      padding: pagePadding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canvasSize = constraints.biggest;
          const handleDiameter = 72.0;
          final paddedHandleSize = Size(
            handleDiameter + companionPadding.right,
            handleDiameter + companionPadding.bottom,
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: canvasFill,
                  border: Border.all(
                    color: canvasOutline,
                    width: TitoBorders.element,
                  ),
                  borderRadius: BorderRadius.circular(
                    DeviceLayout.rMd(context),
                  ),
                ),
                child: GestureDetector(
                  key: const ValueKey('companion-position-canvas'),
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) =>
                      _moveTo(details.localPosition, canvasSize),
                  onTapUp: (_) => _commitOffset(),
                  onPanUpdate: (details) =>
                      _moveBy(details.delta, canvasSize, paddedHandleSize),
                  onPanEnd: (_) => _commitOffset(),
                  onPanCancel: _commitOffset,
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment(_offsetX, _offsetY),
                        child: Padding(
                          padding: companionPadding,
                          child: _PositionHandle(
                            diameter: handleDiameter,
                            speciesId: speciesId,
                            isShiny: choice?.isShiny ?? false,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: SecondaryPageAppBar(
                  title: AppZh.companionPositionTitle,
                  showSettings: false,
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: StickerCard(
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            AppZh.companionPositionHint,
                            style: SecondaryTypography.onCard.body14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () async {
                            await companionRepository.resetOffset();
                            if (!mounted) return;
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PositionHandle extends StatelessWidget {
  const _PositionHandle({
    required this.diameter,
    required this.speciesId,
    required this.isShiny,
  });

  final double diameter;
  final int speciesId;
  final bool isShiny;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color fill;
    final Color outline;
    final double outlineWidth;
    final List<BoxShadow> shadow;
    if (appVisualStyle.usesFlatUi) {
      fill = scheme.surfaceContainerHigh;
      outline = scheme.outlineVariant;
      outlineWidth = TitoBorders.element;
      shadow = TitoShadows.stickerSmall;
    } else if (appVisualStyle.usesSolidPlastic) {
      fill = Colors.white.withValues(alpha: 0.85);
      outline = Colors.white.withValues(alpha: 0.85);
      outlineWidth = TitoBorders.glass;
      shadow = SolidPlasticShadows.stickerSmall;
    } else {
      fill = TitoColors.card;
      outline = TitoColors.ink;
      outlineWidth = TitoBorders.element;
      shadow = TrainerJournalShadows.stickerSmall;
    }
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: outline, width: outlineWidth),
        boxShadow: retroStyle.enabled ? shadow : null,
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
