import 'package:flutter/material.dart';

import '../features/game/game_edition.dart';
import '../features/journey/ask_titodex_service.dart';
import '../features/journey/ask_titodex_settings.dart';
import '../features/journey/progression_hints.dart';
import '../l10n/app_zh.dart';
import '../l10n/game_zh.dart';
import '../models/journey.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../widgets/retro_forms.dart';
import '../widgets/secondary_page_scaffold.dart';
import '../widgets/sticker_card.dart';

class AskTitoDexPage extends StatefulWidget {
  const AskTitoDexPage({
    super.key,
    required this.journey,
    required this.edition,
    this.service,
  });

  final CurrentJourney journey;
  final GameEdition edition;
  final AskTitoDexService? service;

  @override
  State<AskTitoDexPage> createState() => _AskTitoDexPageState();
}

class _AskTitoDexPageState extends State<AskTitoDexPage> {
  late final TextEditingController _questionController;
  late final AskTitoDexService _service;
  AskTitoDexContext? _context;
  AskTitoDexResult? _result;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController();
    _service = widget.service ?? askTitoDexService;
    _prepareContext();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !askTitoDexSettings.noticeAcknowledged) {
        _showOnlineNotice();
      }
    });
  }

  Future<void> _prepareContext() async {
    final initial = AskTitoDexContext.fromJourney(
      widget.journey,
      widget.edition,
    );
    final resolved = await _service.buildContext(initial);
    if (mounted) setState(() => _context = resolved);
  }

  Future<void> _showOnlineNotice() async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppZh.askTitoDexNoticeTitle),
        content: const Text(AppZh.askTitoDexNoticeBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(AppZh.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(AppZh.askTitoDexNoticeAccept),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await askTitoDexSettings.acknowledgeNotice();
    }
  }

  Future<void> _submit() async {
    final contextValue = _context;
    final question = _questionController.text.trim();
    if (contextValue == null || question.isEmpty || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _result = null;
    });
    final result = await _service.ask(question, contextValue);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _result = result;
    });
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contextValue = _context;
    return SecondaryPageScaffold(
      title: AppZh.askTitoDexTitle,
      subtitle: AppZh.askTitoDexSubtitle,
      children: [
        StickerCard(
          variant: StickerVariant.softYellow,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppZh.askTitoDexContextTitle,
                style: SecondaryTypography.onCard.h15,
              ),
              const SizedBox(height: 4),
              Text(
                AppZh.askTitoDexContextHint,
                style: SecondaryTypography.onCard.small12.copyWith(
                  color: TitoColors.mutedInk,
                ),
              ),
              const SizedBox(height: 10),
              if (contextValue == null)
                const LinearProgressIndicator()
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    InputChip(
                      avatar: const Icon(Icons.sports_esports, size: 18),
                      label: Text(
                        contextValue.game == null
                            ? AppZh.askTitoDexGameUnknown
                            : localizeFlavorVersion(contextValue.game!),
                      ),
                    ),
                    if (contextValue.includeLocation &&
                        contextValue.locationId != null &&
                        contextValue.locationLabel != null)
                      InputChip(
                        avatar: const Icon(Icons.place_outlined, size: 18),
                        label: Text(
                          localizeLocation(contextValue.locationLabel!),
                        ),
                        onDeleted: () => setState(
                          () => _context = contextValue.copyWith(
                            includeLocation: false,
                          ),
                        ),
                      ),
                    if (contextValue.includeLocation &&
                        contextValue.locationLabel != null &&
                        contextValue.locationId == null)
                      const Text(AppZh.askTitoDexLocationNotSent),
                    if (contextValue.includeBadges)
                      InputChip(
                        avatar: const Icon(Icons.military_tech, size: 18),
                        label: Text(
                          AppZh.askTitoDexBadgeContext(
                            contextValue.badgeIds.length,
                          ),
                        ),
                        onDeleted: () => setState(
                          () => _context = contextValue.copyWith(
                            includeBadges: false,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        StickerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('ask-titodex-question'),
                controller: _questionController,
                minLines: 2,
                maxLines: 4,
                maxLength: 240,
                textInputAction: TextInputAction.send,
                decoration: retroInsetDecoration(
                  labelText: AppZh.askTitoDexQuestionLabel,
                  hintText: AppZh.askTitoDexQuestionHint,
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const Key('ask-titodex-submit'),
                onPressed: _loading || contextValue == null ? null : _submit,
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_outlined),
                label: Text(
                  _loading ? AppZh.askTitoDexLoading : AppZh.askTitoDexSubmit,
                ),
              ),
            ],
          ),
        ),
        if (_result != null) ...[
          const SizedBox(height: 14),
          _AnswerCard(result: _result!, onRetry: _submit),
        ],
      ],
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.result, required this.onRetry});

  final AskTitoDexResult result;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (result.status == AskTitoDexStatus.failed) {
      return StickerCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              result.errorCode == 'upstream_timeout'
                  ? AppZh.askTitoDexTimeout
                  : AppZh.askTitoDexNetworkFailed,
              style: SecondaryTypography.onCard.body14,
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              key: const Key('ask-titodex-retry'),
              onPressed: onRetry,
              child: const Text(AppZh.retry),
            ),
          ],
        ),
      );
    }
    if (result.status == AskTitoDexStatus.needsClarification ||
        result.status == AskTitoDexStatus.noMatch) {
      return StickerCard(
        variant: StickerVariant.softYellow,
        child: Text(
          result.followUp ?? AppZh.askTitoDexNeedsClarification,
          key: const Key('ask-titodex-follow-up'),
          style: SecondaryTypography.onCard.body14,
        ),
      );
    }
    return StickerCard(
      variant: StickerVariant.mint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const StickerIconPlate(
                icon: Icons.fact_check_outlined,
                color: TitoColors.mint,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.onlineComposed
                      ? AppZh.askTitoDexOnlineAnswerLabel
                      : AppZh.askTitoDexLocalAnswerLabel,
                  style: SecondaryTypography.onCard.h15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            result.answer ?? '',
            key: const Key('ask-titodex-answer'),
            style: SecondaryTypography.onCard.body14.copyWith(height: 1.45),
          ),
          if (result.unknowns.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              AppZh.askTitoDexUnknownWarning,
              style: SecondaryTypography.onCard.small12.copyWith(
                color: TitoColors.deepBlue,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (result.sources.isNotEmpty) ...[
            const Divider(height: 22),
            Text(
              '${AppZh.askTitoDexSources}：${result.sources.map((source) => source.title).join(' · ')}',
              style: SecondaryTypography.onCard.small12.copyWith(
                color: TitoColors.mutedInk,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
