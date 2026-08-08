import 'package:flutter/material.dart';

import '../features/companion/companion_art.dart';
import '../features/companion/companion_repository.dart';
import '../features/companion/companion_media.dart';
import '../features/dex/sprite_generation_catalog.dart';
import '../l10n/app_zh.dart';
import '../models/journey.dart';
import '../theme/device_layout.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../widgets/fallback_sprite_image.dart';
import '../widgets/secondary_page_scaffold.dart';

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
                  color: TitoColors.cream.withValues(alpha: 0.16),
                  border: Border.all(
                    color: TitoColors.card.withValues(alpha: 0.35),
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
                child: SafeArea(
                  top: false,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                    decoration: BoxDecoration(
                      color: TitoColors.card.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(
                        DeviceLayout.rMd(context),
                      ),
                      border: Border.all(color: TitoColors.ink, width: 1.5),
                    ),
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
    return Container(
      width: diameter,
      height: diameter,
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
