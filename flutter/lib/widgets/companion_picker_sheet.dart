import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../features/companion/companion_animation_catalog.dart';
import '../features/companion/companion_media.dart';
import '../features/companion/companion_repository.dart';
import '../features/dex/dex_models.dart';
import '../features/dex/dex_repository.dart';
import '../features/dex/online_media_catalog.dart';
import '../features/dex/sprite_generation_catalog.dart';
import '../l10n/app_zh.dart';
import '../l10n/localized_names.dart';
import '../navigation/tito_page_transition.dart';
import '../theme/app_visual_style.dart';
import '../theme/device_layout.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import '../theme/trainer_journal.dart';
import 'dex_sprite_image.dart';
import 'fallback_sprite_image.dart';
import 'sticker_pressable.dart';
import 'tito_loading_panel.dart';

/// Pick the standby companion from the full national dex. The selection is
/// saved to [companionRepository]; only its animated sprite is fetched later,
/// on demand.
Future<CompanionChoice?> showCompanionPickerSheet(BuildContext context) {
  return showTitoModalBottomSheet<CompanionChoice>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _CompanionPickerSheet(),
  );
}

/// Generic full-dex species picker (same grid + search as the companion
/// picker) — returns the chosen summary without any side effects.
Future<PokemonSummary?> showSpeciesPickerSheet(
  BuildContext context, {
  String? title,
}) {
  return showTitoModalBottomSheet<PokemonSummary>(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        _CompanionPickerSheet(title: title, returnSummaryOnly: true),
  );
}

/// Adopt [summary] as the standby companion, optionally with a specific form
/// and shiny state. Non-bundled species go through the cancellable media
/// preload dialog first. Returns the saved choice, or null when cancelled.
Future<CompanionChoice?> adoptCompanion(
  BuildContext context,
  PokemonSummary summary, {
  String? formKey,
  bool isShiny = false,
  String? animationSourceUrl,
  String? animationLabel,
  CompanionAnimationAsset? animationAsset,
  String? crySourceUrl,
  String? cryLabel,
  bool useGenericAnimation = true,
  List<String> formArtCandidates = const [],
  bool formArtIsShiny = false,
  CompanionMediaCache? mediaCache,
}) async {
  final cache = mediaCache ?? companionMediaCache;
  if (animationAsset != null) {
    if (!animationAsset.matches(summary.id, formKey, isShiny)) return null;
    final cached = await cache.cachedAnimationPath(animationAsset);
    if (!context.mounted) return null;
    if (cached == null) {
      final ready = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _CompanionAnimationDownloadDialog(
          asset: animationAsset,
          cache: cache,
        ),
      );
      if (ready != true || !context.mounted) return null;
    }
  } else if (!bundledCompanionIds.contains(summary.id)) {
    final ready = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CompanionMediaLoadingDialog(
        summary: summary,
        formKey: formKey,
        isShiny: isShiny,
        animationSourceUrl: animationSourceUrl,
        crySourceUrl: crySourceUrl,
        useGenericAnimation: useGenericAnimation,
        formArtCandidates: formArtCandidates,
        formArtIsShiny: formArtIsShiny,
      ),
    );
    if (ready != true || !context.mounted) {
      return null; // Cancelled — keep the previous companion.
    }
  }
  final choice = CompanionChoice(
    pokemonId: summary.id,
    nameZh: summary.nameZh,
    formKey: formKey,
    isShiny: isShiny,
    animationSourceUrl: animationAsset?.url ?? animationSourceUrl,
    animationAssetId: animationAsset?.id,
    animationLabel: animationAsset?.label ?? animationLabel,
    crySourceUrl: crySourceUrl,
    cryLabel: cryLabel,
  );
  await companionRepository.save(choice);
  return choice;
}

/// Pick a form and shiny state for [summary] before adopting it as the
/// standby companion. Returns the saved choice, or null when cancelled.
Future<CompanionChoice?> showCompanionFormPickerSheet(
  BuildContext context,
  PokemonSummary summary, {
  Future<(PokemonDetail, OnlineMediaEntry?)>? data,
  CompanionAnimationCatalog? animationCatalog,
  CompanionMediaCache? mediaCache,
}) {
  return showTitoModalBottomSheet<CompanionChoice>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _CompanionFormPickerSheet(
      summary: summary,
      data: data,
      animationCatalog: animationCatalog,
      mediaCache: mediaCache,
    ),
  );
}

class _CompanionPickerSheet extends StatefulWidget {
  const _CompanionPickerSheet({this.title, this.returnSummaryOnly = false});

  /// Optional title override (defaults to the companion picker copy).
  final String? title;

  /// When true the sheet just pops the tapped summary — no companion save,
  /// no media preload dialog.
  final bool returnSummaryOnly;

  @override
  State<_CompanionPickerSheet> createState() => _CompanionPickerSheetState();
}

class _CompanionPickerSheetState extends State<_CompanionPickerSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<PokemonSummary> _filtered(List<PokemonSummary> all) {
    final query = _query.trim();
    if (query.isEmpty) {
      return all;
    }
    final lower = query.toLowerCase();
    final numeric = int.tryParse(query);
    return [
      for (final entry in all)
        if ((numeric != null && entry.id == numeric) ||
            entry.nameZh.contains(query) ||
            entry.nameEn.toLowerCase().contains(lower))
          entry,
    ];
  }

  Future<void> _select(PokemonSummary summary) async {
    if (widget.returnSummaryOnly) {
      Navigator.of(context).pop(summary);
      return;
    }
    final choice = await showCompanionFormPickerSheet(context, summary);
    if (choice != null && mounted) {
      Navigator.of(context).pop(choice);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.72;

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title ?? AppZh.companionPickerTitle,
              style: SecondaryTypography.onCard.h15,
            ),
            if (!widget.returnSummaryOnly) ...[
              const SizedBox(height: 4),
              Text(
                AppZh.companionPickerHint,
                style: SecondaryTypography.onCard.small12.copyWith(
                  color: TitoColors.mutedInk,
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              onChanged: (value) => setState(() => _query = value),
              spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
              decoration: InputDecoration(
                hintText: AppZh.companionPickerSearchHint,
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<List<PokemonSummary>>(
                future: dexRepository.getAllSummaries(),
                builder: (context, snapshot) {
                  final all = snapshot.data;
                  if (all == null) {
                    return const Align(
                      alignment: Alignment.topCenter,
                      child: TitoLoadingPanel(onLightSurface: true),
                    );
                  }
                  final entries = _filtered(all);
                  if (entries.isEmpty) {
                    return Center(
                      child: Text(
                        AppZh.searchNoResults,
                        style: SecondaryTypography.onCard.body14,
                      ),
                    );
                  }
                  return GridView.builder(
                    itemCount: entries.length,
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: DeviceLayout.isCompact(context)
                          ? 84
                          : 96,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.8,
                    ),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _CompanionPickTile(
                        summary: entry,
                        onTap: () => _select(entry),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _MediaLoadState { loading, done, failed }

/// Starts only after the user confirms the candidate, including for starters.
class _CompanionAnimationDownloadDialog extends StatefulWidget {
  const _CompanionAnimationDownloadDialog({
    required this.asset,
    required this.cache,
  });
  final CompanionAnimationAsset asset;
  final CompanionMediaCache cache;
  @override
  State<_CompanionAnimationDownloadDialog> createState() =>
      _CompanionAnimationDownloadDialogState();
}

class _CompanionAnimationDownloadDialogState
    extends State<_CompanionAnimationDownloadDialog> {
  CompanionDownloadCancellation? _cancellation;
  var _received = 0;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    final cancellation = CompanionDownloadCancellation();
    _cancellation = cancellation;
    setState(() {
      _received = 0;
      _failed = false;
    });
    final path = await widget.cache.ensureAnimation(
      widget.asset,
      cancellation: cancellation,
      onProgress: (received, _) {
        if (mounted && !cancellation.isCancelled) {
          setState(() => _received = received);
        }
      },
    );
    if (!mounted || cancellation.isCancelled) return;
    if (path != null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _cancellation?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(AppZh.companionAnimationDownload),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.asset.label),
        const SizedBox(height: 8),
        Text('${widget.asset.dimensionsLabel} · ${widget.asset.sizeLabel}'),
        const SizedBox(height: 12),
        if (_failed)
          Text(AppZh.companionAnimationFailed)
        else ...[
          LinearProgressIndicator(value: _received / widget.asset.sizeBytes),
          const SizedBox(height: 8),
          Text(
            _received == widget.asset.sizeBytes
                ? AppZh.companionAnimationVerify
                : '${(_received * 100 / widget.asset.sizeBytes).round()}%',
          ),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: () {
          _cancellation?.cancel();
          Navigator.of(context).pop(false);
        },
        child: Text(AppZh.cancel),
      ),
      if (_failed)
        TextButton(
          onPressed: _download,
          child: Text(AppZh.companionAnimationRetry),
        ),
    ],
  );
}

/// Cancellable preload dialog — downloads the animated GIF and cry to the
/// disk cache before the choice is committed, so the home standby and the
/// first pat are instant. Failures still proceed (static fallback works).
class _CompanionMediaLoadingDialog extends StatefulWidget {
  const _CompanionMediaLoadingDialog({
    required this.summary,
    this.formKey,
    this.isShiny = false,
    this.animationSourceUrl,
    this.crySourceUrl,
    this.useGenericAnimation = true,
    this.formArtCandidates = const [],
    this.formArtIsShiny = false,
  });

  final PokemonSummary summary;
  final String? formKey;
  final bool isShiny;
  final String? animationSourceUrl;
  final String? crySourceUrl;
  final bool useGenericAnimation;
  final List<String> formArtCandidates;
  final bool formArtIsShiny;

  @override
  State<_CompanionMediaLoadingDialog> createState() =>
      _CompanionMediaLoadingDialogState();
}

class _CompanionMediaLoadingDialogState
    extends State<_CompanionMediaLoadingDialog> {
  var _gif = _MediaLoadState.loading;
  var _cry = _MediaLoadState.loading;
  var _cancelled = false;

  bool get _settled =>
      _gif != _MediaLoadState.loading && _cry != _MediaLoadState.loading;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final mediaId = widget.summary.spriteResourceId ?? widget.summary.id;
    final speciesId = widget.summary.id;
    final gifFuture = widget.useGenericAnimation
        ? (widget.isShiny
                  ? companionMediaCache.ensureShinyGif(
                      mediaId,
                      candidates: widget.animationSourceUrl == null
                          ? null
                          : [
                              if (shinySpriteVariantUrl(
                                    widget.animationSourceUrl!,
                                  )
                                  case final shinyUrl?)
                                shinyUrl,
                              ...animatedShinySpriteCandidatesFor(mediaId),
                            ],
                    )
                  : companionMediaCache.ensureGif(
                      mediaId,
                      candidates: widget.animationSourceUrl == null
                          ? null
                          : [
                              widget.animationSourceUrl!,
                              ...companionGifDownloadCandidates(mediaId),
                            ],
                    ))
              .then((path) {
                _update(() {
                  _gif = path != null
                      ? _MediaLoadState.done
                      : _MediaLoadState.failed;
                });
              })
        : widget.formKey != null && widget.formArtCandidates.isNotEmpty
        ? companionMediaCache
              .ensureFormArt(
                speciesId,
                widget.formKey!,
                shiny: widget.formArtIsShiny,
                candidates: widget.formArtCandidates,
              )
              .then((path) {
                _update(() {
                  _gif = path != null
                      ? _MediaLoadState.done
                      : _MediaLoadState.failed;
                });
              })
        : Future<void>.value().then((_) {
            _update(() => _gif = _MediaLoadState.done);
          });
    await Future.wait([
      gifFuture,
      companionMediaCache
          .ensureCry(
            speciesId,
            candidates: widget.crySourceUrl == null
                ? null
                : [widget.crySourceUrl!, ...cryCandidatesFor(speciesId)],
          )
          .then((path) {
            _update(() {
              _cry = path != null
                  ? _MediaLoadState.done
                  : _MediaLoadState.failed;
            });
          }),
    ]);
    if (_cancelled || !mounted) {
      return;
    }
    // Let the checkmarks land before the dialog closes itself.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (mounted && !_cancelled) {
      Navigator.of(context).pop(true);
    }
  }

  void _update(VoidCallback change) {
    if (mounted && !_cancelled) {
      setState(change);
    }
  }

  @override
  Widget build(BuildContext context) {
    final anyFailed =
        _gif == _MediaLoadState.failed || _cry == _MediaLoadState.failed;

    return AlertDialog(
      title: Text(AppZh.companionMediaTitle(widget.summary.nameZh)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MediaLoadRow(label: AppZh.companionMediaGif, state: _gif),
          const SizedBox(height: 10),
          _MediaLoadRow(label: AppZh.companionMediaCry, state: _cry),
          if (_settled && anyFailed) ...[
            const SizedBox(height: 10),
            Text(
              AppZh.companionMediaFailedHint,
              style: SecondaryTypography.onCard.small12.copyWith(
                color: TitoColors.mutedInk,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _cancelled = true;
            Navigator.of(context).pop(false);
          },
          child: Text(AppZh.cancel),
        ),
      ],
    );
  }
}

class _MediaLoadRow extends StatelessWidget {
  const _MediaLoadRow({required this.label, required this.state});

  final String label;
  final _MediaLoadState state;

  @override
  Widget build(BuildContext context) {
    // 16px inline status dot — the one place a bare spinner is allowed (D10).
    final indicator = switch (state) {
      _MediaLoadState.loading => const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
      _MediaLoadState.done => const Icon(
        Icons.check_circle_rounded,
        size: 18,
        color: TitoColors.mint,
      ),
      _MediaLoadState.failed => const Icon(
        Icons.error_outline_rounded,
        size: 18,
        color: TitoColors.coral,
      ),
    };

    return Row(
      children: [
        indicator,
        const SizedBox(width: 10),
        Text(label, style: SecondaryTypography.onCard.body14),
      ],
    );
  }
}

class _CompanionPickTile extends StatelessWidget {
  const _CompanionPickTile({required this.summary, required this.onTap});

  final PokemonSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tile = _pickerTileStyle(context, selected: false);
    return StickerPressable(
      borderRadius: BorderRadius.circular(TitoRadii.md),
      ownShadow: false,
      child: Material(
        color: tile.fill,
        borderRadius: BorderRadius.circular(TitoRadii.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(TitoRadii.md),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TitoRadii.md),
              border: Border.all(color: tile.outline, width: tile.outlineWidth),
            ),
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: DexSpriteImage(
                    source: summary.displaySpritePath,
                    height: null,
                    width: null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  summary.nameZh,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: SecondaryTypography.onCard.small12.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Second-step form + shiny picker for the standby companion.
class _CompanionFormPickerSheet extends StatefulWidget {
  const _CompanionFormPickerSheet({
    required this.summary,
    this.data,
    this.animationCatalog,
    this.mediaCache,
  });

  final PokemonSummary summary;
  final Future<(PokemonDetail, OnlineMediaEntry?)>? data;
  final CompanionAnimationCatalog? animationCatalog;
  final CompanionMediaCache? mediaCache;

  @override
  State<_CompanionFormPickerSheet> createState() =>
      _CompanionFormPickerSheetState();
}

class _CompanionFormPickerSheetState extends State<_CompanionFormPickerSheet> {
  late final Future<(PokemonDetail, OnlineMediaEntry?)> _dataFuture;
  final _previewPlayer = AudioPlayer();
  String? _selectedFormKey;
  String? _selectedAnimationUrl;
  String? _selectedAnimationLabel;
  String? _selectedAnimationAssetId;
  CompanionAnimationCatalog? _animationCatalog;
  Map<String, CachedMediaFile> _cachedFiles = const {};
  bool _catalogFailed = false;
  bool _confirming = false;
  String? _selectedCryUrl;
  String? _selectedCryLabel;
  var _isShiny = false;

  @override
  void initState() {
    super.initState();
    final current = companionRepository.choice;
    if (current?.pokemonId == widget.summary.id) {
      _selectedFormKey = current?.formKey;
      _isShiny = current?.isShiny ?? false;
      _selectedAnimationAssetId = current?.animationAssetId;
      _selectedAnimationUrl = _selectedAnimationAssetId == null
          ? current?.animationSourceUrl
          : null;
      _selectedAnimationLabel = current?.animationLabel;
      _selectedCryUrl = current?.crySourceUrl;
      _selectedCryLabel = current?.cryLabel;
    }
    _dataFuture = _loadData();
  }

  CompanionAnimationAsset? get _selectedAsset =>
      _animationCatalog?.entry(_selectedAnimationAssetId);

  String? _cachedAssetPath(CompanionAnimationAsset asset) {
    final file = _cachedFiles[asset.cacheFileName];
    return file?.sizeBytes == asset.sizeBytes ? file?.path : null;
  }

  Future<void> _loadAnimationCatalog() async {
    try {
      _animationCatalog =
          widget.animationCatalog ?? await CompanionAnimationCatalog.load();
      final files = await (widget.mediaCache ?? companionMediaCache)
          .listCached();
      _cachedFiles = {for (final file in files) file.name: file};
      if (_selectedAnimationAssetId != null &&
          !(_selectedAsset?.matches(
                widget.summary.id,
                _selectedFormKey,
                _isShiny,
              ) ??
              false)) {
        _selectedAnimationAssetId = null;
        _selectedAnimationLabel = null;
      }
    } catch (_) {
      _catalogFailed = true;
    }
  }

  Future<(PokemonDetail, OnlineMediaEntry?)> _loadData() async {
    final supplied = widget.data;
    if (supplied != null) {
      final values = await (supplied, _loadAnimationCatalog()).wait;
      return values.$1;
    }
    final values = await Future.wait<Object?>([
      dexRepository.getDetail(widget.summary.id),
      onlineMediaCatalog.entryFor(widget.summary.id),
      _loadAnimationCatalog(),
    ]);
    return (values[0] as PokemonDetail, values[1] as OnlineMediaEntry?);
  }

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
  }

  List<_LabeledMediaSource> _animationChoices(
    PokemonSummary summary, {
    required PokemonFormDetail? form,
  }) {
    final mediaId = summary.spriteResourceId ?? summary.id;
    final generic =
        form == null ||
        companionFormUsesIdAnimation(
          speciesId: summary.id,
          mediaId: mediaId,
          isDefault: form.isDefault,
        );
    final options = generic
        ? spriteEditionOptionsForPokemon(
            mediaId,
            cdnUrlsByVersion: summary.spriteUrlsByVersion,
            fallbackSpriteUrl: summary.displaySpritePath,
          )
        : const <SpriteEditionOption>[];
    final seen = <String>{};
    return [
      for (final option in options)
        if (option.animatedUrl case final url?)
          if ((!_isShiny || shinySpriteVariantUrl(url) != null) &&
              seen.add(url))
            _LabeledMediaSource(
              url: url,
              label: option.generation == spriteGenerationUniversal
                  ? option.editionLabelZh
                  : '${generationRomanLabel(option.generation)} · '
                        '${option.editionLabelZh}',
            ),
      for (final asset
          in _animationCatalog?.forForm(
                summary.id,
                formKey: form?.key,
                shiny: _isShiny,
              ) ??
              const <CompanionAnimationAsset>[])
        if (seen.add(asset.url))
          _LabeledMediaSource(
            url: asset.url,
            label: asset.label,
            animation: asset,
          ),
    ];
  }

  List<_LabeledMediaSource> _cryChoices(
    int speciesId,
    OnlineMediaEntry? entry,
  ) {
    final seen = <String>{};
    return [
      for (final cry in entry?.cries ?? const <OnlineCry>[])
        if (seen.add(cry.url))
          _LabeledMediaSource(url: cry.url, label: cry.labelZh),
      if (seen.add(cryUrlFor(speciesId)))
        _LabeledMediaSource(
          url: cryUrlFor(speciesId),
          label: AppZh.companionPickerCryLatest,
        ),
      if (legacyCryUrlFor(speciesId) case final legacy?)
        if (seen.add(legacy))
          _LabeledMediaSource(
            url: legacy,
            label: AppZh.companionPickerCryLegacy,
          ),
    ];
  }

  Future<void> _previewCry(int speciesId, OnlineMediaEntry? entry) async {
    final url =
        _selectedCryUrl ??
        entry?.bestCryUrl(formKey: _selectedFormKey) ??
        cryUrlFor(speciesId);
    try {
      await _previewPlayer.stop();
      await _previewPlayer.play(UrlSource(url), volume: 0.6);
    } catch (_) {
      // Preview failure should not block saving; runtime still has fallbacks.
    }
  }

  Future<void> _confirm(
    PokemonFormDetail? form,
    OnlineMediaEntry? media,
  ) async {
    final formKey = form?.key;
    final summary = form?.summaryFor(widget.summary) ?? widget.summary;
    final shinyArt =
        media?.artCandidatesFor(formKey, shiny: _isShiny) ?? const [];
    final normalArt = media?.artCandidatesFor(formKey) ?? const [];
    final formArtCandidates = shinyArt.isNotEmpty ? shinyArt : normalArt;
    if (!mounted || _confirming) {
      return;
    }
    final selectedValue = _selectedAnimationAssetId ?? _selectedAnimationUrl;
    final selection = _animationChoices(summary, form: form)
        .cast<_LabeledMediaSource?>()
        .firstWhere(
          (choice) => choice?.value == selectedValue,
          orElse: () => null,
        );
    setState(() => _confirming = true);
    try {
      final choice = await adoptCompanion(
        context,
        summary,
        formKey: formKey,
        isShiny: _isShiny,
        animationSourceUrl: selection?.animation == null
            ? selection?.url
            : null,
        animationLabel: selection == null
            ? null
            : _selectedAnimationLabel ?? selection.label,
        animationAsset: selection?.animation,
        mediaCache: widget.mediaCache,
        crySourceUrl: _selectedCryUrl,
        cryLabel: _selectedCryLabel,
        useGenericAnimation:
            form == null ||
            companionFormUsesIdAnimation(
              speciesId: widget.summary.id,
              mediaId: form.pokemonId,
              isDefault: form.isDefault,
            ),
        formArtCandidates: formArtCandidates,
        formArtIsShiny: shinyArt.isNotEmpty,
      );
      if (choice != null && mounted) Navigator.of(context).pop(choice);
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return SizedBox(
      height: size.height * 0.82,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: FutureBuilder<(PokemonDetail, OnlineMediaEntry?)>(
          future: _dataFuture,
          builder: (context, snapshot) {
            final detail = snapshot.data?.$1;
            final media = snapshot.data?.$2;
            final forms = detail?.forms ?? [];
            final hasForms = forms.length > 1;
            final selectedForm = forms.cast<PokemonFormDetail?>().firstWhere(
              (f) => f?.key == _selectedFormKey,
              orElse: () => null,
            );
            final previewSummary =
                selectedForm?.summaryFor(widget.summary) ?? widget.summary;
            final animationChoices = _animationChoices(
              previewSummary,
              form: selectedForm,
            );
            final cryChoices = _cryChoices(widget.summary.id, media);
            final previewMediaId =
                previewSummary.spriteResourceId ?? previewSummary.id;
            final useGenericAnimation =
                selectedForm == null ||
                companionFormUsesIdAnimation(
                  speciesId: widget.summary.id,
                  mediaId: previewMediaId,
                  isDefault: selectedForm.isDefault,
                );
            final shinyFormArt =
                media?.artCandidatesFor(_selectedFormKey, shiny: _isShiny) ??
                const [];
            final normalFormArt =
                media?.artCandidatesFor(_selectedFormKey) ?? const [];
            final asset = _selectedAsset;
            final cachedAsset = asset == null ? null : _cachedAssetPath(asset);
            // Selecting/browsing a source does not fetch its remote animation.
            // Preview an already downloaded file or exact static artwork.
            final previewSources = <String>[
              if (cachedAsset != null) cachedAsset,
              if (_isShiny) ...[
                ...shinyFormArt,
                if (useGenericAnimation)
                  if (shinySpriteVariantUrl(defaultSpriteUrlFor(previewMediaId))
                      case final source?)
                    source,
              ] else ...[
                ...normalFormArt,
                if (previewSummary.displayArtworkPath case final source?)
                  source,
                if (previewSummary.displaySpritePath case final source?) source,
                if (useGenericAnimation) defaultSpriteUrlFor(previewMediaId),
              ],
            ];
            final selectedValue =
                _selectedAnimationAssetId ?? _selectedAnimationUrl ?? '';
            final dropdownValue =
                animationChoices.any((choice) => choice.value == selectedValue)
                ? selectedValue
                : '';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppZh.companionPickerFormAppearance,
                        style: SecondaryTypography.onCard.h15,
                      ),
                    ),
                    FilterChip(
                      selected: _isShiny,
                      onSelected:
                          hasForms ||
                              snapshot.connectionState == ConnectionState.done
                          ? (value) => setState(() {
                              _isShiny = value;
                              _selectedAnimationAssetId = null;
                              _selectedAnimationUrl = null;
                              _selectedAnimationLabel = null;
                            })
                          : null,
                      avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
                      label: Text(AppZh.companionPickerShiny),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  previewSummary.displayName,
                  style: SecondaryTypography.onCard.body14.copyWith(
                    color: TitoColors.mutedInk,
                  ),
                ),
                const SizedBox(height: 10),
                if (snapshot.connectionState != ConnectionState.done)
                  const Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: TitoLoadingPanel(
                        onLightSurface: true,
                        compact: true,
                      ),
                    ),
                  )
                else if (!hasForms)
                  Expanded(
                    child: Center(child: Text(AppZh.companionPickerNoForms)),
                  )
                else
                  Flexible(
                    flex: 3,
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 0.92,
                          ),
                      itemCount: forms.length,
                      itemBuilder: (context, index) {
                        final form = forms[index];
                        final selected = form.key == _selectedFormKey;
                        return _CompanionFormTile(
                          form: form,
                          species: widget.summary,
                          artCandidates: [
                            ...(media?.artCandidatesFor(
                                  form.key,
                                  shiny: _isShiny,
                                ) ??
                                const []),
                            if (_isShiny)
                              ...(media?.artCandidatesFor(form.key) ??
                                  const []),
                          ],
                          selected: selected,
                          onTap: () => setState(() {
                            _selectedFormKey = form.key;
                            _selectedAnimationUrl = null;
                            _selectedAnimationAssetId = null;
                            _selectedAnimationLabel = null;
                            _selectedCryUrl = null;
                            _selectedCryLabel = null;
                          }),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Builder(
                      builder: (context) {
                        final tile = _pickerTileStyle(context, selected: false);
                        return Container(
                          width: 72,
                          height: 72,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: tile.fill,
                            borderRadius: BorderRadius.circular(TitoRadii.md),
                            border: Border.all(
                              color: tile.outline,
                              width: tile.outlineWidth,
                            ),
                          ),
                          child: FallbackSpriteImage(sources: previewSources),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            key: ValueKey(
                              'animation-${previewSummary.spriteResourceId}'
                              '-$_isShiny-$dropdownValue',
                            ),
                            initialValue: dropdownValue,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: AppZh.companionPickerGifSource,
                              isDense: true,
                            ),
                            items: [
                              DropdownMenuItem(
                                value: '',
                                child: Text(AppZh.companionPickerGifAuto),
                              ),
                              for (final choice in animationChoices)
                                DropdownMenuItem(
                                  value: choice.value,
                                  child: Text(
                                    '${choice.label}${choice.animation != null && _cachedAssetPath(choice.animation!) != null ? ' · ${AppZh.companionAnimationCached}' : ''}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (value) => setState(() {
                              final choice = animationChoices
                                  .cast<_LabeledMediaSource?>()
                                  .firstWhere(
                                    (choice) => choice?.value == value,
                                    orElse: () => null,
                                  );
                              _selectedAnimationAssetId = choice?.animation?.id;
                              _selectedAnimationUrl = choice?.animation == null
                                  ? choice?.url
                                  : null;
                              _selectedAnimationLabel = choice?.label;
                            }),
                          ),
                          if (asset != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '${asset.dimensionsLabel} · ${asset.sizeLabel}\n${cachedAsset != null ? AppZh.companionAnimationCached : AppZh.companionAnimationOnDemand}',
                                style: SecondaryTypography.onCard.small12,
                              ),
                            ),
                          if (_catalogFailed)
                            Text(
                              AppZh.companionAnimationUnavailable,
                              style: SecondaryTypography.onCard.small12,
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  key: ValueKey(
                                    'cry-${widget.summary.id}'
                                    '-${_selectedCryUrl ?? 'auto'}',
                                  ),
                                  initialValue: _selectedCryUrl ?? '',
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: AppZh.companionPickerCrySource,
                                    isDense: true,
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: '',
                                      child: Text(AppZh.companionPickerCryAuto),
                                    ),
                                    for (final choice in cryChoices)
                                      DropdownMenuItem(
                                        value: choice.url,
                                        child: Text(
                                          choice.label,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: (value) => setState(() {
                                    _selectedCryUrl =
                                        value == null || value.isEmpty
                                        ? null
                                        : value;
                                    _selectedCryLabel = cryChoices
                                        .cast<_LabeledMediaSource?>()
                                        .firstWhere(
                                          (choice) => choice?.url == value,
                                          orElse: () => null,
                                        )
                                        ?.label;
                                  }),
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    _previewCry(widget.summary.id, media),
                                tooltip: AppZh.companionPickerPreviewCry,
                                icon: const Icon(Icons.volume_up_rounded),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                StickerPressable(
                  borderRadius: BorderRadius.circular(TitoRadii.md),
                  ownShadow: false,
                  child: FilledButton(
                    onPressed:
                        snapshot.connectionState == ConnectionState.done &&
                            !_confirming
                        ? () => _confirm(selectedForm, media)
                        : null,
                    child: Text(
                      asset == null
                          ? AppZh.confirm
                          : cachedAsset == null
                          ? AppZh.companionAnimationDownload
                          : AppZh.companionAnimationUse,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LabeledMediaSource {
  const _LabeledMediaSource({
    required this.url,
    required this.label,
    this.animation,
  });

  final String url;
  final String label;
  final CompanionAnimationAsset? animation;
  String get value => animation?.id ?? url;
}

/// Per-theme fill/outline for the picker's grid tiles and preview slot. They
/// sit on the sheet surface, so Flat uses container tones, Solid Plastic a
/// milky plate and Trainer's Journal the cream sticker with an ink stroke.
({Color fill, Color outline, double outlineWidth}) _pickerTileStyle(
  BuildContext context, {
  required bool selected,
}) {
  final scheme = Theme.of(context).colorScheme;
  if (appVisualStyle.usesFlatUi) {
    return (
      fill: selected ? scheme.secondaryContainer : scheme.surfaceContainerHigh,
      outline: selected ? scheme.primary : scheme.outlineVariant,
      outlineWidth: TitoBorders.element,
    );
  }
  if (appVisualStyle.usesSolidPlastic) {
    return (
      fill: selected
          ? TitoColors.softYellow.withValues(alpha: 0.85)
          : Colors.white.withValues(alpha: 0.8),
      outline: Colors.white.withValues(alpha: 0.85),
      outlineWidth: TitoBorders.glass,
    );
  }
  return (
    fill: selected
        ? TitoColors.softYellow.withValues(alpha: 0.22)
        : TrainerJournal.paper,
    outline: selected ? TrainerJournal.selectedEdge : TrainerJournal.smallEdge,
    outlineWidth: selected
        ? TitoBorders.journalCard
        : TitoBorders.journalElement,
  );
}

class _CompanionFormTile extends StatelessWidget {
  const _CompanionFormTile({
    required this.form,
    required this.species,
    required this.artCandidates,
    required this.selected,
    required this.onTap,
  });

  final PokemonFormDetail form;
  final PokemonSummary species;
  final List<String> artCandidates;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final summary = form.summaryFor(species);
    final tile = _pickerTileStyle(context, selected: selected);
    return StickerPressable(
      borderRadius: BorderRadius.circular(TitoRadii.md),
      ownShadow: false,
      child: Material(
        color: tile.fill,
        borderRadius: BorderRadius.circular(TitoRadii.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(TitoRadii.md),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TitoRadii.md),
              border: Border.all(color: tile.outline, width: tile.outlineWidth),
            ),
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: FallbackSpriteImage(
                    sources: [
                      ...artCandidates,
                      if (summary.displayArtworkPath case final source?) source,
                      if (summary.displaySpritePath case final source?) source,
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  form.nameZh,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: SecondaryTypography.onCard.small12.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
