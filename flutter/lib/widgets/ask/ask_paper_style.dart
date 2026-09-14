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

/// Ink outline tint for paper surfaces, again Trainer's Journal only.
Color? askPaperOutline(double alpha) =>
    usesAskPaperLook ? TrainerJournal.edge.withValues(alpha: alpha) : null;

/// Shared outline geometry for history rows and source references. Callers
/// retain their own container so source links keep Material ink feedback.
class AskPaperTileStyle {
  const AskPaperTileStyle({required this.fill, required this.border});

  final Color fill;
  final BorderSide border;

  BorderRadius get borderRadius => BorderRadius.circular(TitoRadii.md);

  BoxDecoration get decoration => BoxDecoration(
    color: fill,
    borderRadius: borderRadius,
    border: Border.fromBorderSide(border),
  );

  RoundedRectangleBorder get shape =>
      RoundedRectangleBorder(borderRadius: borderRadius, side: border);
}

/// Fill and outline for the small "paper" tiles (history rows, source
/// references) that sit on a themed sheet or card surface.
AskPaperTileStyle askPaperTileStyle(
  BuildContext context, {
  required Color paper,
  required double outlineAlpha,
}) {
  final scheme = Theme.of(context).colorScheme;
  if (appVisualStyle.usesFlatUi) {
    return AskPaperTileStyle(
      fill: scheme.surfaceContainerHigh,
      border: BorderSide(
        color: scheme.outlineVariant,
        width: TitoBorders.element,
      ),
    );
  }
  if (appVisualStyle.usesSolidPlastic) {
    return AskPaperTileStyle(
      fill: Colors.white.withValues(alpha: 0.8),
      border: BorderSide(
        color: Colors.white.withValues(alpha: 0.85),
        width: TitoBorders.glass,
      ),
    );
  }
  return AskPaperTileStyle(
    fill: paper,
    border: BorderSide(
      color: TrainerJournal.edge.withValues(alpha: outlineAlpha),
      width: TitoBorders.journalElement,
    ),
  );
}
