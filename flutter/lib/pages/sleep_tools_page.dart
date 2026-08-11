import 'package:flutter/material.dart';

import '../features/sleep/sleep_calculator.dart';
import '../l10n/app_zh.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../widgets/companion_tool_fields.dart';
import '../widgets/secondary_page_scaffold.dart';
import '../widgets/sticker_card.dart';

class SleepToolsPage extends StatefulWidget {
  const SleepToolsPage({super.key});

  @override
  State<SleepToolsPage> createState() => _SleepToolsPageState();
}

class _SleepToolsPageState extends State<SleepToolsPage> {
  TimeOfDay _bedtime = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _wakeup = const TimeOfDay(hour: 7, minute: 30);
  int _recipeLevel = 1;
  final _recipeBonusController = TextEditingController(text: '0');
  final Map<String, int> _quantities = {};

  @override
  void dispose() {
    _recipeBonusController.dispose();
    super.dispose();
  }

  int get _sleepDuration => sleepDurationMinutesBetween(
    bedtimeMinutes: _bedtime.hour * 60 + _bedtime.minute,
    wakeupMinutes: _wakeup.hour * 60 + _wakeup.minute,
  );

  int get _recipeBonus =>
      (int.tryParse(_recipeBonusController.text.trim()) ?? 0).clamp(0, 500);

  int get _recipeEnergy => calculateRecipeEnergy(
    quantities: _quantities,
    recipeLevel: _recipeLevel,
    recipeBonusPercent: _recipeBonus,
  );

  Future<void> _pickTime({required bool bedtime}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: bedtime ? _bedtime : _wakeup,
      helpText: bedtime ? AppZh.sleepBedtime : AppZh.sleepWakeup,
      cancelText: AppZh.cancel,
      confirmText: AppZh.confirm,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      if (bedtime) {
        _bedtime = picked;
      } else {
        _wakeup = picked;
      }
    });
  }

  void _changeQuantity(SleepIngredient ingredient, int delta) {
    setState(() {
      final next = ((_quantities[ingredient.slug] ?? 0) + delta).clamp(0, 99);
      if (next == 0) {
        _quantities.remove(ingredient.slug);
      } else {
        _quantities[ingredient.slug] = next;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final duration = _sleepDuration;
    final score = sleepScoreFromDurationMinutes(duration);
    final baseEnergy = ingredientBaseEnergy(_quantities);
    final selectedIngredients = sleepIngredients
        .where((ingredient) => (_quantities[ingredient.slug] ?? 0) > 0)
        .toList();

    return Material(
      type: MaterialType.transparency,
      child: SecondaryPageScaffold(
        title: AppZh.sleepToolsTitle,
        subtitle: AppZh.sleepToolsSubtitle,
        children: [
          CompanionSectionCard(
            title: AppZh.sleepScoreTitle,
            subtitle: AppZh.sleepScoreHint,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _TimeButton(
                      label: AppZh.sleepBedtime,
                      time: _bedtime,
                      onTap: () => _pickTime(bedtime: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TimeButton(
                      label: AppZh.sleepWakeup,
                      time: _wakeup,
                      onTap: () => _pickTime(bedtime: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _ResultBand(
                mainText: '$score / 100',
                detailText: AppZh.sleepDurationResult(
                  duration ~/ 60,
                  duration % 60,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CompanionSectionCard(
            title: AppZh.sleepRecipeTitle,
            subtitle: AppZh.sleepRecipeHint,
            children: [
              Text(
                AppZh.sleepIngredientAdd,
                style: SecondaryTypography.onCard.small12.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final ingredient in sleepIngredients)
                    ActionChip(
                      avatar: const Icon(Icons.add_rounded, size: 16),
                      label: Text(
                        '${ingredient.nameZh} · ${ingredient.baseEnergy}',
                      ),
                      onPressed: () => _changeQuantity(ingredient, 1),
                      backgroundColor: TitoColors.card,
                      side: const BorderSide(color: TitoColors.ink, width: 2),
                      labelStyle: SecondaryTypography.onCard.small12.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (selectedIngredients.isEmpty)
                Text(
                  AppZh.sleepIngredientEmpty,
                  style: SecondaryTypography.onCard.body14.copyWith(
                    color: TitoColors.mutedInk,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                for (final ingredient in selectedIngredients)
                  _IngredientQuantityRow(
                    ingredient: ingredient,
                    quantity: _quantities[ingredient.slug]!,
                    onDecrease: () => _changeQuantity(ingredient, -1),
                    onIncrease: () => _changeQuantity(ingredient, 1),
                  ),
              const SizedBox(height: 14),
              Text(
                AppZh.sleepRecipeLevel(_recipeLevel),
                style: SecondaryTypography.onCard.small12.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Slider(
                value: _recipeLevel.toDouble(),
                min: 1,
                max: 70,
                divisions: 69,
                label: 'Lv $_recipeLevel',
                onChanged: (value) =>
                    setState(() => _recipeLevel = value.round()),
              ),
              CompanionNumberField(
                label: AppZh.sleepRecipeBonus,
                controller: _recipeBonusController,
                max: 500,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              _ResultBand(
                mainText: AppZh.sleepRecipeEnergy(_recipeEnergy),
                detailText: AppZh.sleepRecipeBreakdown(
                  baseEnergy,
                  recipeLevelMultiplier(_recipeLevel),
                  _recipeBonus,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppZh.sleepRecipeCrit(
                  (_recipeEnergy * 2).round(),
                  (_recipeEnergy * 3).round(),
                ),
                style: SecondaryTypography.onCard.small12.copyWith(
                  color: TitoColors.mutedInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StickerCard(
            variant: StickerVariant.softYellow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppZh.sleepSourceTitle,
                  style: SecondaryTypography.onCard.h15,
                ),
                const SizedBox(height: 6),
                Text(
                  AppZh.sleepSourceBody,
                  style: SecondaryTypography.onCard.small12.copyWith(
                    color: TitoColors.mutedInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.time,
    required this.onTap,
  });

  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final value =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: SecondaryTypography.onCard.small12.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.schedule_rounded, size: 18),
          label: Text(value),
        ),
      ],
    );
  }
}

class _IngredientQuantityRow extends StatelessWidget {
  const _IngredientQuantityRow({
    required this.ingredient,
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
  });

  final SleepIngredient ingredient;
  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${ingredient.nameZh} · ${ingredient.baseEnergy}',
              style: SecondaryTypography.onCard.body14.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton.outlined(
            tooltip: AppZh.sleepIngredientDecrease,
            onPressed: onDecrease,
            icon: const Icon(Icons.remove_rounded, size: 18),
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 34,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: SecondaryTypography.onCard.body14.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton.outlined(
            tooltip: AppZh.sleepIngredientIncrease,
            onPressed: onIncrease,
            icon: const Icon(Icons.add_rounded, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _ResultBand extends StatelessWidget {
  const _ResultBand({required this.mainText, required this.detailText});

  final String mainText;
  final String detailText;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: TitoColors.mint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TitoColors.ink, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              mainText,
              style: SecondaryTypography.onCard.h15.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detailText,
              style: SecondaryTypography.onCard.small12.copyWith(
                color: TitoColors.mutedInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
