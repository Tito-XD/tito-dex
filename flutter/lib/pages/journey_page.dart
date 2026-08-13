import 'package:flutter/material.dart';

import '../features/journey/journey_assistant.dart';
import '../features/parser/hgss_format.dart';
import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_buttons.dart';
import '../theme/tito_colors.dart';
import '../widgets/journey_timeline.dart';
import '../widgets/journey_assistant_panel.dart';
import '../widgets/secondary_page_scaffold.dart';
import '../widgets/sticker_card.dart';

class JourneyPage extends StatelessWidget {
  const JourneyPage({
    super.key,
    required this.journey,
    this.onLaunchEmulator,
    this.assistantFuture,
    this.askTitoDexEnabled = false,
    this.onAskTitoDex,
  });

  final CurrentJourney journey;
  final VoidCallback? onLaunchEmulator;
  final Future<JourneyAssistantSnapshot>? assistantFuture;
  final bool askTitoDexEnabled;
  final VoidCallback? onAskTitoDex;

  @override
  Widget build(BuildContext context) {
    return SecondaryPageScaffold(
      title: AppZh.navJourney,
      subtitle: localizeGame(journey.game),
      children: [
        if (onLaunchEmulator != null) ...[
          StickerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppZh.emulatorContinueHint,
                  style: SecondaryTypography.onCard.h15,
                ),
                const SizedBox(height: 12),
                TitoPrimaryButton(
                  label: AppZh.continueButton,
                  onPressed: onLaunchEmulator,
                  expanded: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        StickerCard(
          variant: StickerVariant.deep,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppZh.settingsLocation,
                style: SecondaryTypography.onGradient.small12.copyWith(
                  color: TitoColors.skyBlue,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                localizeLocation(journey.location),
                style: SecondaryTypography.onGradient.h15,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _SummaryMeta(
                      label: AppZh.settingsCurrentGame,
                      value: localizeGame(journey.game),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryMeta(
                      label: AppZh.settingsBadges,
                      value: journey.badgeProgressLabel,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          AppZh.journeyAssistantTitle,
          style: SecondaryTypography.onCard.h15,
        ),
        const SizedBox(height: 8),
        JourneyAssistantPanel(
          future: assistantFuture ?? journeyAssistantRepository.load(journey),
        ),
        if (askTitoDexEnabled && onAskTitoDex != null) ...[
          const SizedBox(height: 12),
          StickerCard(
            variant: StickerVariant.softYellow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppZh.askTitoDexEntryHint,
                  style: SecondaryTypography.onCard.small12.copyWith(
                    color: TitoColors.mutedInk,
                  ),
                ),
                const SizedBox(height: 10),
                TitoPrimaryButton(
                  key: const Key('ask-titodex-entry'),
                  label: AppZh.askTitoDexEntry,
                  onPressed: onAskTitoDex,
                  expanded: true,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        JourneyTimeline(
          entries: journey.timeline,
          nextReminder: journey.nextReminder,
        ),
        const SizedBox(height: 14),
        StickerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppZh.trainerCard, style: SecondaryTypography.onCard.h15),
              const SizedBox(height: 10),
              _StatRow(
                label: AppZh.settingsDisplayName,
                value: journey.trainerName,
              ),
              if (journey.saveTrainerId != null)
                _StatRow(
                  label: AppZh.settingsTrainerId,
                  value: journey.saveTrainerId!.toString().padLeft(5, '0'),
                ),
              if (journey.saveTrainerSecretId != null)
                _StatRow(
                  label: AppZh.settingsTrainerSecretId,
                  value: journey.saveTrainerSecretId!.toString().padLeft(
                    5,
                    '0',
                  ),
                ),
              if (journey.saveTrainerGender != null)
                _StatRow(
                  label: AppZh.settingsTrainerGender,
                  value: journey.saveTrainerGender!,
                ),
              if (journey.saveLanguage != null)
                _StatRow(
                  label: AppZh.settingsSaveLanguage,
                  value: journey.saveLanguage!,
                ),
              if (journey.saveMoney != null)
                _StatRow(
                  label: AppZh.settingsSaveMoney,
                  value: '₽ ${journey.saveMoney}',
                ),
              if (journey.saveMotherMoney != null)
                _StatRow(
                  label: AppZh.settingsMotherMoney,
                  value: '₽ ${journey.saveMotherMoney}',
                ),
              if (journey.saveStarterSpeciesId != null)
                _StatRow(
                  label: AppZh.settingsStarter,
                  value: localizeSpecies(
                    speciesNameFor(journey.saveStarterSpeciesId!),
                  ),
                ),
              if (journey.saveDexSeenIds.isNotEmpty ||
                  journey.saveDexCaughtIds.isNotEmpty)
                _StatRow(
                  label: AppZh.settingsDexProgress,
                  value:
                      '已见 ${journey.saveDexSeenIds.length} · 已捕 ${journey.saveDexCaughtIds.length}',
                ),
              if (journey.saveMapCoordinates.length == 3)
                _StatRow(
                  label: AppZh.settingsMapCoordinates,
                  value: journey.saveMapCoordinates.join(' / '),
                ),
              if (journey.saveAdventureStartedAt != null)
                _StatRow(
                  label: AppZh.settingsJourneyStarted,
                  value: _formatSaveDate(journey.saveAdventureStartedAt!),
                ),
              if (journey.saveLeagueChampionAt != null)
                _StatRow(
                  label: AppZh.settingsLeagueChampion,
                  value: _formatSaveDate(journey.saveLeagueChampionAt!),
                ),
              _StatRow(label: AppZh.settingsPlayTime, value: journey.playTime),
              _StatRow(
                label: AppZh.settingsBadges,
                value: journey.badgeProgressLabel,
              ),
              _StatRow(
                label: AppZh.settingsCurrentGame,
                value: localizeGame(journey.game),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _formatSaveDate(DateTime value) =>
    '${value.year}/${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}';

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: SecondaryTypography.onCard.team12.copyWith(
              color: TitoColors.mutedInk,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: SecondaryTypography.onCard.meta14,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMeta extends StatelessWidget {
  const _SummaryMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: TitoColors.deepBlue.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(TitoRadii.sm),
        border: Border.all(color: TitoColors.skyBlue, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: SecondaryTypography.onGradient.small12.copyWith(
                color: TitoColors.skyBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SecondaryTypography.onGradient.meta14,
            ),
          ],
        ),
      ),
    );
  }
}
