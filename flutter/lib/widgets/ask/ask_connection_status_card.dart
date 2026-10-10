import 'package:flutter/material.dart';

import '../../features/game/game_edition.dart';
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
    this.sessionTitle,
    this.onShowSessions,
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
  final String? sessionTitle;
  final VoidCallback? onShowSessions;
  final VoidCallback? onChangeEdition;
  final VoidCallback? onManagePacks;
  final VoidCallback? onRemoveLocation;
  final VoidCallback? onRemoveBadges;

  @override
  Widget build(BuildContext context) {
    final editionLabel = edition.selectedLabel;
    final sessionMode = sessionTitle != null || onShowSessions != null;
    final title = sessionTitle?.trim() ?? '';
    final sessionLabel = title.isEmpty ? AppZh.askTitoDexCurrentSession : title;
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
    final showContext =
        !sessionMode || showSaveContext || onManagePacks != null;
    final statusColor = switch (status.availability) {
      AskTitoDexAvailability.checking => TitoColors.skyBlue,
      AskTitoDexAvailability.online => TitoColors.mint,
      AskTitoDexAvailability.disabled => TitoColors.softYellow,
      AskTitoDexAvailability.unavailable => TitoColors.coral,
    };
    final statusLabel = switch (status.availability) {
      AskTitoDexAvailability.checking => AppZh.askTitoDexStatusChecking,
      AskTitoDexAvailability.online => AppZh.askTitoDexStatusOnlineReady,
      AskTitoDexAvailability.disabled ||
      AskTitoDexAvailability.unavailable => AppZh.askTitoDexStatusLocalOnly,
    };
    return AssistantSurface(
      key: const Key('ask-titodex-connection-status'),
      padding: EdgeInsets.zero,
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
              key: const Key('ask-titodex-status-segments'),
              height: 44,
              child: Row(
                children: [
                  Expanded(
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
                        onRefresh: onRefresh,
                      ),
                    ),
                  ),
                  const _StatusDivider(),
                  Expanded(
                    child: _StatusSegment(
                      key: sessionMode
                          ? const Key('ask-titodex-session-summary')
                          : const Key('ask-titodex-history-summary'),
                      leading: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: TitoColors.deepBlue,
                        size: 18,
                      ),
                      label: sessionMode
                          ? sessionLabel
                          : AppZh.askTitoDexHistoryEntries(historyCount),
                      semanticsLabel: sessionMode
                          ? AppZh.askTitoDexSessionSemantics(sessionLabel)
                          : AppZh.askTitoDexHistoryEntriesSemantics(
                              historyCount,
                            ),
                      onTap: sessionMode ? onShowSessions : onShowHistory,
                      truncateLabel: sessionMode,
                      tooltip: sessionMode ? sessionLabel : null,
                      trailing: sessionMode
                          ? const Icon(
                              Icons.expand_more_rounded,
                              color: TitoColors.deepBlue,
                              size: 16,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            if (showContext)
              Divider(
                height: 1,
                thickness: 1,
                indent: 11,
                endIndent: 11,
                color: TitoColors.deepBlue.withValues(alpha: 0.12),
              ),
            if (showContext)
              Builder(
                key: const Key('ask-titodex-save-context-size'),
                builder: (context) {
                  final chips = Padding(
                    key: showSaveContext
                        ? const Key('ask-titodex-save-context')
                        : null,
                    padding: const EdgeInsets.fromLTRB(11, 6, 11, 7),
                    child: Wrap(
                      key: const Key('ask-titodex-context-row'),
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        if (!sessionMode)
                          _ContextChip(
                            key: const Key('ask-titodex-edition-summary'),
                            icon: Icons.shield_outlined,
                            label: editionLabel,
                            textKey: const Key('ask-titodex-current-edition'),
                            semanticsLabel: AppZh.askTitoDexEditionSemantics(
                              editionLabel,
                            ),
                            onPressed: onChangeEdition,
                          ),
                        if (showLocation)
                          _ContextChip(
                            key: const Key('ask-titodex-location-context'),
                            icon: Icons.place_outlined,
                            label: localizeLocation(value.locationLabel!),
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
                        if (onManagePacks != null)
                          IconButton(
                            key: const Key('ask-titodex-packs-entry'),
                            tooltip: AppZh.manageJourneyPacks,
                            onPressed: onManagePacks,
                            constraints: const BoxConstraints.tightFor(
                              width: 32,
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
                      ],
                    ),
                  );
                  if (TitoMotion.disabled(context)) return chips;
                  return AnimatedSize(
                    duration: TitoMotion.standard,
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: chips,
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
    this.trailing,
    this.truncateLabel = false,
    this.tooltip,
  });

  final Widget leading;
  final String label;
  final String semanticsLabel;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool truncateLabel;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: SecondaryTypography.onCard.body14.copyWith(
        color: TitoColors.deepBlue,
        fontWeight: FontWeight.w900,
        height: 1,
      ),
    );
    final segment = Semantics(
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
                child: truncateLabel
                    ? text
                    : FittedBox(fit: BoxFit.scaleDown, child: text),
              ),
              if (trailing != null) ...[const SizedBox(width: 4), trailing!],
            ],
          ),
        ),
      ),
    );
    return SizedBox(
      height: 44,
      child: tooltip == null
          ? segment
          : Tooltip(message: tooltip!, child: segment),
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
  required VoidCallback onRefresh,
}) async {
  final workerOnline = status.availability == AskTitoDexAvailability.online;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const Key('ask-titodex-connection-dialog'),
      title: Text(AppZh.askTitoDexConnectionsTitle),
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

List<(String, bool)> _connectionCapabilities(AskTitoDexWorkerStatus status) {
  final models = [
    if (status.qwenConfigured) 'Qwen',
    if (status.textFallbackConfigured) AppZh.askTitoDexTextFallbackShort,
  ].join(' · ');
  final providers = status.webSearchProviders
      .toSet()
      .map(_webSearchProviderLabel)
      .join(' · ');
  return [
    (
      AppZh.askTitoDexCapOnlineService,
      status.availability == AskTitoDexAvailability.online,
    ),
    (
      models.isEmpty
          ? AppZh.askTitoDexCapAnswerGeneric
          : AppZh.askTitoDexCapAnswerComposition(models),
      status.qwenConfigured || status.textFallbackConfigured,
    ),
    (
      providers.isEmpty
          ? AppZh.askTitoDexCapSearchGeneric
          : AppZh.askTitoDexCapSearchSources(providers),
      status.webSearchEnabled,
    ),
    (AppZh.askTitoDexCapDexFacts, status.dexBundleEnabled),
    (AppZh.askTitoDexCapReviewedHints, status.aiSearchEnabled),
  ];
}

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
    this.onPressed,
    this.textKey,
    this.semanticsLabel,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onDeleted;
  final VoidCallback? onPressed;
  final Key? textKey;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    // Colours come from chipTheme; only the corner family is pinned so the
    // chips match the status surface they live in.
    return Semantics(
      label: semanticsLabel,
      button: onPressed != null,
      child: InputChip(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(askAssistantContextChipRadius),
        ),
        clipBehavior: Clip.antiAlias,
        visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        avatar: Icon(icon, size: 14),
        label: Text(
          label,
          key: textKey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        deleteIcon: const Icon(Icons.close_rounded, size: 14),
        onDeleted: onDeleted,
        onPressed: onPressed,
      ),
    );
  }
}

String _webSearchProviderLabel(String value) => switch (value) {
  'exa' => 'Exa',
  'tavily' => 'Tavily',
  'deepseek-native' => AppZh.askTitoDexSourceDeepseekNativeShort,
  'brave' => 'Brave',
  _ => value,
};
