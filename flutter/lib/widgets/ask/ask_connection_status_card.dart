import 'package:flutter/material.dart';

import '../../features/game/game_edition.dart';
import '../../features/journey/ask_titodex_history.dart';
import '../../features/journey/ask_titodex_service.dart';
import '../../features/journey/progression_hints.dart';
import '../../l10n/app_zh.dart';
import '../../l10n/game_zh.dart';
import '../../theme/app_visual_style.dart';
import '../../theme/secondary_typography.dart';
import '../../theme/tito_colors.dart';
import '../../theme/tito_motion.dart';
import '../assistant_surface.dart';
import 'ask_paper_style.dart';

class AskConnectionStatusCard extends StatelessWidget {
  const AskConnectionStatusCard({
    super.key,
    required this.status,
    required this.historyCount,
    required this.contextValue,
    required this.edition,
    required this.onRefresh,
    required this.onShowHistory,
    required this.onChangeEdition,
    this.onManagePacks,
    required this.onRemoveLocation,
    required this.onRemoveBadges,
  });

  final AskTitoDexWorkerStatus status;
  final int historyCount;
  final AskTitoDexContext? contextValue;
  final GameEdition edition;
  final VoidCallback onRefresh;
  final VoidCallback onShowHistory;
  final VoidCallback? onChangeEdition;
  final VoidCallback? onManagePacks;
  final VoidCallback? onRemoveLocation;
  final VoidCallback? onRemoveBadges;

  @override
  Widget build(BuildContext context) {
    final online = status.availability == AskTitoDexAvailability.online;
    final capabilities = _connectionCapabilities(status);
    final enabledCount = online
        ? capabilities.where((capability) => capability.$2).length
        : 0;
    final capabilityCount = capabilities.length;
    final editionLabel = edition.selectedLabel;
    final value = contextValue;
    final showLocation = value != null && value.hasVerifiedLocationContext;
    final showVerifiedBadges =
        value != null &&
        value.hasVerifiedBadgeContext &&
        value.badgesReliability == 'save_verified' &&
        value.badgeIds.isNotEmpty;
    final showBadgeCount =
        value != null &&
        value.hasVerifiedBadgeContext &&
        value.badgesReliability == 'count_only' &&
        value.badgeCount != null;
    final showSaveContext =
        showLocation || showVerifiedBadges || showBadgeCount;
    final statusColor = switch (status.availability) {
      AskTitoDexAvailability.checking => TitoColors.skyBlue,
      AskTitoDexAvailability.online => TitoColors.mint,
      AskTitoDexAvailability.disabled => TitoColors.softYellow,
      AskTitoDexAvailability.unavailable => TitoColors.coral,
    };
    final statusLabel = switch (status.availability) {
      AskTitoDexAvailability.checking => AppZh.askTitoDexStatusChecking,
      AskTitoDexAvailability.online => AppZh.askTitoDexStatusOnlineCount(
        enabledCount,
        capabilityCount,
      ),
      AskTitoDexAvailability.disabled => AppZh.askTitoDexStatusClosed,
      AskTitoDexAvailability.unavailable => AppZh.askTitoDexStatusLocalOnly,
    };
    return AssistantSurface(
      key: const Key('ask-titodex-connection-status'),
      padding: EdgeInsets.zero,
      // Use one explicit continuous-corner family for both the expandable
      // status surface and its context chips. An adaptive 999px stadium became
      // visually over-rounded as the second row arrived, while InputChip kept
      // its unrelated theme radius.
      radius: askAssistantStatusRadius,
      color: usesAskPaperLook
          ? Color.alphaBlend(
              TitoColors.skyBlue.withValues(alpha: 0.18),
              TitoColors.card,
            )
          : null,
      borderColor: askPaperOutline(0.55),
      borderWidth: TitoBorders.element,
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: _StatusSegment(
                      key: const Key('ask-titodex-connection-summary'),
                      leading: _StatusDot(
                        color: statusColor,
                        checking:
                            status.availability ==
                            AskTitoDexAvailability.checking,
                      ),
                      label: statusLabel,
                      semanticsLabel: AppZh.askTitoDexConnectionSemantics(
                        statusLabel,
                      ),
                      onTap: () => _showConnectionDetails(
                        context,
                        status: status,
                        enabledCount: enabledCount,
                        capabilityCount: capabilityCount,
                        historyCount: historyCount,
                        onRefresh: onRefresh,
                      ),
                    ),
                  ),
                  const _StatusDivider(),
                  Expanded(
                    flex: 4,
                    child: _StatusSegment(
                      key: const Key('ask-titodex-history-summary'),
                      leading: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: TitoColors.deepBlue,
                        size: 18,
                      ),
                      label: AppZh.askTitoDexHistoryCount(
                        historyCount,
                        askTitoDexHistoryLimit,
                      ),
                      semanticsLabel: AppZh.askTitoDexHistoryCountSemantics(
                        historyCount,
                        askTitoDexHistoryLimit,
                      ),
                      onTap: onShowHistory,
                    ),
                  ),
                  const _StatusDivider(),
                  Expanded(
                    flex: 5,
                    child: _StatusSegment(
                      key: const Key('ask-titodex-edition-summary'),
                      leading: const Icon(
                        Icons.shield_outlined,
                        color: TitoColors.deepBlue,
                        size: 19,
                      ),
                      label: editionLabel,
                      textKey: const Key('ask-titodex-current-edition'),
                      semanticsLabel: AppZh.askTitoDexEditionSemantics(
                        editionLabel,
                      ),
                      onTap: onChangeEdition,
                      trailing: onManagePacks == null
                          ? null
                          : IconButton(
                              key: const Key('ask-titodex-packs-entry'),
                              tooltip: AppZh.manageJourneyPacks,
                              onPressed: onManagePacks,
                              constraints: const BoxConstraints.tightFor(
                                width: 28,
                                height: 32,
                              ),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.download_for_offline_outlined,
                                color: TitoColors.deepBlue,
                                size: 18,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Builder(
              key: const Key('ask-titodex-save-context-size'),
              builder: (context) {
                final saveContextChild = showSaveContext
                    ? Column(
                        key: const ValueKey('save-context-visible'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Divider(
                            height: 1,
                            thickness: 1,
                            indent: 11,
                            endIndent: 11,
                            color: TitoColors.deepBlue.withValues(alpha: 0.12),
                          ),
                          Padding(
                            key: const Key('ask-titodex-save-context'),
                            padding: const EdgeInsets.fromLTRB(11, 6, 11, 7),
                            child: Wrap(
                              spacing: 5,
                              runSpacing: 4,
                              children: [
                                if (showLocation)
                                  _ContextChip(
                                    key: const Key(
                                      'ask-titodex-location-context',
                                    ),
                                    icon: Icons.place_outlined,
                                    label: localizeLocation(
                                      value.locationLabel!,
                                    ),
                                    onDeleted: onRemoveLocation,
                                  ),
                                if (showVerifiedBadges)
                                  _ContextChip(
                                    key: const Key('ask-titodex-badge-context'),
                                    icon: Icons.military_tech,
                                    label: AppZh.askTitoDexBadgeContext(
                                      value.badgeIds.length,
                                    ),
                                    onDeleted: onRemoveBadges,
                                  ),
                                if (showBadgeCount)
                                  _ContextChip(
                                    key: const Key('ask-titodex-badge-context'),
                                    icon: Icons.military_tech,
                                    label: AppZh.askTitoDexSaveBadgeCount(
                                      value.badgeCount!,
                                    ),
                                    onDeleted: onRemoveBadges,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : const SizedBox(key: ValueKey('save-context-hidden'));
                if (TitoMotion.disabled(context)) {
                  return saveContextChild;
                }
                return AnimatedSize(
                  duration: TitoMotion.standard,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: saveContextChild,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusSegment extends StatelessWidget {
  const _StatusSegment({
    super.key,
    required this.leading,
    required this.label,
    required this.semanticsLabel,
    required this.onTap,
    this.textKey,
    this.trailing,
  });

  final Widget leading;
  final String label;
  final String semanticsLabel;
  final VoidCallback? onTap;
  final Key? textKey;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      label: semanticsLabel,
      child: InkWell(
        borderRadius: BorderRadius.circular(askAssistantStatusRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              leading,
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    key: textKey,
                    maxLines: 1,
                    style: SecondaryTypography.onCard.body14.copyWith(
                      color: TitoColors.deepBlue,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
              if (trailing case final trailing?) trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusDivider extends StatelessWidget {
  const _StatusDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 24,
    color: TitoColors.deepBlue.withValues(alpha: 0.16),
  );
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color, required this.checking});

  final Color color;
  final bool checking;

  @override
  Widget build(BuildContext context) => Container(
    width: 13,
    height: 13,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(
        color: TitoColors.deepBlue,
        width: appVisualStyle.usesTrainerJournal
            ? TitoBorders.journalHairline
            : TitoBorders.element,
      ),
    ),
    child: checking
        ? const Padding(
            padding: EdgeInsets.all(2),
            child: CircularProgressIndicator(strokeWidth: 1),
          )
        : null,
  );
}

Future<void> _showConnectionDetails(
  BuildContext context, {
  required AskTitoDexWorkerStatus status,
  required int enabledCount,
  required int capabilityCount,
  required int historyCount,
  required VoidCallback onRefresh,
}) async {
  final workerOnline = status.availability == AskTitoDexAvailability.online;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const Key('ask-titodex-connection-dialog'),
      title: Text(
        AppZh.askTitoDexConnectionDialogTitle(
          enabledCount,
          capabilityCount,
          historyCount,
          askTitoDexHistoryLimit,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final capability in _connectionCapabilities(status))
              _CapabilityDetail(
                label: capability.$1,
                enabled: workerOnline && capability.$2,
              ),
            if (status.experimentalAnswers) ...[
              const SizedBox(height: 6),
              Text(
                AppZh.askTitoDexBroadTrialHint,
                key: const Key('ask-titodex-experimental-policy'),
                style: SecondaryTypography.onCard.small12.copyWith(
                  color: TitoColors.deepBlue,
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              switch (status.availability) {
                AskTitoDexAvailability.online =>
                  AppZh.askTitoDexStatusOnlineHint,
                AskTitoDexAvailability.disabled =>
                  AppZh.askTitoDexStatusDisabledHint,
                AskTitoDexAvailability.unavailable =>
                  AppZh.askTitoDexStatusUnavailableHint,
                AskTitoDexAvailability.checking =>
                  AppZh.askTitoDexWorkerChecking,
              },
              style: SecondaryTypography.onCard.small12.copyWith(
                color: TitoColors.mutedInk,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          key: const Key('ask-titodex-refresh-connection'),
          onPressed: status.availability == AskTitoDexAvailability.checking
              ? null
              : () {
                  Navigator.of(dialogContext).pop();
                  onRefresh();
                },
          icon: const Icon(Icons.refresh_rounded),
          label: Text(AppZh.askTitoDexWorkerRefresh),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(AppZh.gotIt),
        ),
      ],
    ),
  );
}

List<(String, bool)> _connectionCapabilities(AskTitoDexWorkerStatus status) => [
  ('Journey Worker', status.availability == AskTitoDexAvailability.online),
  (AppZh.askTitoDexCapQwen, status.qwenConfigured),
  (AppZh.askTitoDexCapAiSearch, status.aiSearchEnabled),
  (AppZh.askTitoDexCapBundle, status.dexBundleEnabled),
  (AppZh.askTitoDexCapEncyclopedia, status.curatedSourcesEnabled),
  for (final provider in status.webSearchProviders)
    (
      AppZh.askTitoDexCapWebSearch(_webSearchProviderLabel(provider)),
      status.webSearchEnabled,
    ),
  if (status.webSearchProviders.isEmpty)
    (AppZh.askTitoDexCapWebSearchGeneric, false),
];

class _CapabilityDetail extends StatelessWidget {
  const _CapabilityDetail({required this.label, required this.enabled});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.check_circle_rounded : Icons.remove_circle_outline,
            size: 18,
            color: enabled ? TitoColors.deepBlue : TitoColors.mutedInk,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: SecondaryTypography.onCard.body14),
          ),
          Text(
            enabled
                ? AppZh.askTitoDexCapAvailable
                : AppZh.askTitoDexCapDisconnected,
            style: SecondaryTypography.onCard.small12.copyWith(
              color: enabled ? TitoColors.deepBlue : TitoColors.mutedInk,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextChip extends StatelessWidget {
  const _ContextChip({
    super.key,
    required this.icon,
    required this.label,
    this.onDeleted,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    // Colours come from chipTheme; only the corner family is pinned so the
    // chips match the status surface they live in.
    return InputChip(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(askAssistantContextChipRadius),
      ),
      clipBehavior: Clip.antiAlias,
      visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      avatar: Icon(icon, size: 14),
      label: Text(label),
      deleteIcon: const Icon(Icons.close_rounded, size: 14),
      onDeleted: onDeleted,
    );
  }
}

String _webSearchProviderLabel(String value) => switch (value) {
  'tavily' => 'Tavily',
  'deepseek-native' => AppZh.askTitoDexSourceDeepseekNativeShort,
  'brave' => 'Brave',
  _ => value,
};
