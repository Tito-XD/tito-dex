import 'package:flutter/material.dart';

import '../../theme/app_visual_style.dart';
import '../../theme/tito_colors.dart';
import '../../theme/trainer_journal.dart';
import '../assistant_surface.dart';

// Ask TitoDex "paper" tones. They are part of the Trainer's Journal look
// only (D12); the other themes leave every surface to AssistantSurface and
// the Material colour scheme.
const askAssistantPaper = AssistantSurface.paper;
const askAssistantCanvas = Color(0xFFF5F6F3);
const askAssistantSkeleton = Color(0xFFDCE5E5);
const askAssistantStatusRadius = 32.0;
const askAssistantContextChipRadius = TitoRadii.lg;

bool get usesAskPaperLook => appVisualStyle.usesTrainerJournal;

/// The conversation viewport behind the answer cards.
BoxDecoration askAnswerViewportDecoration(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  final radius = BorderRadius.circular(TitoRadii.lg);
  if (appVisualStyle.usesFlatUi) {
    return BoxDecoration(
      color: scheme.surfaceContainerLow,
      borderRadius: radius,
      border: Border.all(color: scheme.outlineVariant),
    );
  }
  if (appVisualStyle.usesSolidPlastic) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.7),
      borderRadius: radius,
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.85),
        width: TitoBorders.glass,
      ),
    );
  }
  return BoxDecoration(
    color: askAssistantCanvas.withValues(alpha: 0.94),
    borderRadius: radius,
    border: Border.all(color: TitoColors.deepBlue.withValues(alpha: 0.12)),
  );
}

/// Paper fill for answer cards — null lets [AssistantSurface] pick its
/// theme default outside Trainer's Journal.
Color? get askPaperColor => usesAskPaperLook ? askAssistantPaper : null;

/// Ink outline tint for paper surfaces, again Trainer's Journal only.
Color? askPaperOutline(double alpha) =>
    usesAskPaperLook ? TrainerJournal.edge.withValues(alpha: alpha) : null;

/// Fill and outline for the small "paper" tiles (history rows, source
/// references) that sit on a themed sheet or card surface.
({Color fill, Color outline, double outlineWidth}) askPaperTileStyle(
  BuildContext context, {
  required Color paper,
  required double outlineAlpha,
}) {
  final scheme = Theme.of(context).colorScheme;
  if (appVisualStyle.usesFlatUi) {
    return (
      fill: scheme.surfaceContainerHigh,
      outline: scheme.outlineVariant,
      outlineWidth: TitoBorders.element,
    );
  }
  if (appVisualStyle.usesSolidPlastic) {
    return (
      fill: Colors.white.withValues(alpha: 0.8),
      outline: Colors.white.withValues(alpha: 0.85),
      outlineWidth: TitoBorders.glass,
    );
  }
  return (
    fill: paper,
    outline: TrainerJournal.edge.withValues(alpha: outlineAlpha),
    outlineWidth: TitoBorders.journalElement,
  );
}
