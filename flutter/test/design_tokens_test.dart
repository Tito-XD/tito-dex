import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/type_chart.dart';
import 'package:titodex/theme/app_visual_style.dart';
import 'package:titodex/theme/tito_colors.dart';
import 'package:titodex/theme/tito_surface_tokens.dart';
import 'package:titodex/theme/tito_theme.dart';
import 'package:titodex/widgets/sticker_card.dart';

void main() {
  test('shared JSON matches the registered runtime tokens', () {
    final table = {
      'schemaVersion': 1,
      'source': 'flutter/lib/theme/tito_surface_tokens.dart',
      'colorFormat': '#RRGGBBAA',
      'dimensionUnit': 'logical pixel / CSS px',
      'shell': {
        'journalTop': colorToken(TitoColors.shellGradientTop),
        'journalBottom': colorToken(TitoColors.shellGradientBottom),
        'plasticTop': colorToken(TitoColors.glassBackgroundTop),
        'plasticMid': colorToken(TitoColors.glassBackgroundMid),
        'plasticBottom': colorToken(TitoColors.glassBackgroundBottom),
      },
      'radii': {
        'sm': TitoRadii.sm,
        'md': TitoRadii.md,
        'lg': TitoRadii.lg,
        'xl': TitoRadii.xl,
      },
      'semantic': {
        'success': {
          'light': colorToken(TitoColors.success),
          'dark': colorToken(TitoColors.successDark),
        },
        'danger': {
          'light': colorToken(TitoColors.danger),
          'dark': colorToken(TitoColors.dangerDark),
        },
        'effectivenessResist': colorToken(TitoColors.effectivenessResist),
        'selectionInk': colorToken(TitoColors.selectionInk),
      },
      'typePalette': {
        'fallback': colorToken(typeTileColorFallback),
        for (final entry in typeTileColors.entries)
          entry.key: colorToken(entry.value),
      },
      'typeIcons': {
        'set': 'gen8',
        'slugScheme': 'type_icons/<slug>.png',
        'source': 'v5',
      },
      'themes': {
        for (final style in AppVisualStyle.values)
          style.family.name: buildTitoTheme(
            style,
          ).extension<TitoSurfaceTokens>()!.toJson(),
      },
    };
    final serialized = '${const JsonEncoder.withIndent('  ').convert(table)}\n';
    final file = File('../docs/design-tokens.json');
    if (const bool.fromEnvironment('EXPORT_DESIGN_TOKENS')) {
      file.writeAsStringSync(serialized);
    }
    expect(
      jsonDecode(file.readAsStringSync()),
      table,
      reason: 'Regenerate with --dart-define=EXPORT_DESIGN_TOKENS=true',
    );
  });

  test('surface tokens interpolate all roles and press depth', () {
    final a = buildTitoTheme().extension<TitoSurfaceTokens>()!;
    final b = buildTitoTheme(
      AppVisualStyle.solidPlastic,
    ).extension<TitoSurfaceTokens>()!;
    final mid = a.lerp(b, .5);
    expect(mid.pressSink, 2);
    expect(a.lerp(b, 0).toJson(), a.toJson());
    expect(a.lerp(b, 1).toJson(), b.toJson());
    expect(a.copyWith().toJson(), a.toJson());
    for (final role in TitoSurfaceRole.values) {
      expect(
        mid.surface(role).fill,
        Color.lerp(a.surface(role).fill, b.surface(role).fill, .5),
      );
    }
  });

  testWidgets(
    'local Theme extension owns card fill independently of preference',
    (tester) async {
      final theme = buildTitoTheme();
      final tokens = theme.extension<TitoSurfaceTokens>()!;
      final custom = tokens.copyWith(
        surfaces: {
          ...tokens.surfaces,
          TitoSurfaceRole.card: const TitoSurfaceRecipe(Colors.purple),
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme.copyWith(extensions: [custom]),
          home: const Scaffold(body: StickerCard(child: Text('local theme'))),
        ),
      );
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(StickerCard),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((box.decoration as BoxDecoration).color, Colors.purple);
    },
  );
}
