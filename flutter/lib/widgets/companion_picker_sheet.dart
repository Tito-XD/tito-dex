import 'dart:async';

import 'package:flutter/material.dart';

import '../features/companion/companion_media.dart';
import '../features/companion/companion_repository.dart';
import '../features/dex/dex_models.dart';
import '../features/dex/dex_repository.dart';
import '../l10n/app_zh.dart';
import '../navigation/tito_page_transition.dart';
import '../theme/device_layout.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import 'dex_sprite_image.dart';
import 'sticker_pressable.dart';

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
}) async {
  if (!bundledCompanionIds.contains(summary.id)) {
    final ready = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CompanionMediaLoadingDialog(
        summary: summary,
        formKey: formKey,
        isShiny: isShiny,
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
  );
  await companionRepository.save(choice);
  return choice;
}

/// Pick a form and shiny state for [summary] before adopting it as the
/// standby companion. Returns the saved choice, or null when cancelled.
Future<CompanionChoice?> showCompanionFormPickerSheet(
  BuildContext context,
  PokemonSummary summary,
) {
  return showTitoModalBottomSheet<CompanionChoice>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _CompanionFormPickerSheet(summary: summary),
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
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(TitoRadii.md),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<List<PokemonSummary>>(
                future: dexRepository.getAllSummaries(),
                builder: (context, snapshot) {
                  final all = snapshot.data;
                  if (all == null) {
                    return const Center(child: CircularProgressIndicator());
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

/// Cancellable preload dialog — downloads the animated GIF and cry to the
/// disk cache before the choice is committed, so the home standby and the
/// first pat are instant. Failures still proceed (static fallback works).
class _CompanionMediaLoadingDialog extends StatefulWidget {
  const _CompanionMediaLoadingDialog({
    required this.summary,
    this.formKey,
    this.isShiny = false,
  });

  final PokemonSummary summary;
  final String? formKey;
  final bool isShiny;

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
    await Future.wait([
      (widget.isShiny
              ? companionMediaCache.ensureShinyGif(mediaId)
              : companionMediaCache.ensureGif(mediaId))
          .then((path) {
        _update(() {
          _gif = path != null ? _MediaLoadState.done : _MediaLoadState.failed;
        });
      }),
      companionMediaCache.ensureCry(speciesId).then((path) {
        _update(() {
          _cry = path != null ? _MediaLoadState.done : _MediaLoadState.failed;
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
      backgroundColor: TitoColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TitoRadii.md),
        side: const BorderSide(color: TitoColors.ink, width: 2),
      ),
      title: Text(
        AppZh.companionMediaTitle(widget.summary.nameZh),
        style: SecondaryTypography.onCard.h15,
      ),
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
          child: const Text(AppZh.cancel),
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
    final indicator = switch (state) {
      _MediaLoadState.loading => const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: TitoColors.deepBlue,
        ),
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
    return StickerPressable(
      borderRadius: BorderRadius.circular(TitoRadii.md),
      ownShadow: false,
      child: Material(
        color: TitoColors.cream,
        borderRadius: BorderRadius.circular(TitoRadii.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(TitoRadii.md),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TitoRadii.md),
              border: Border.all(
                color: TitoColors.ink.withValues(alpha: 0.35),
                width: 2,
              ),
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
  const _CompanionFormPickerSheet({required this.summary});

  final PokemonSummary summary;

  @override
  State<_CompanionFormPickerSheet> createState() =>
      _CompanionFormPickerSheetState();
}

class _CompanionFormPickerSheetState
    extends State<_CompanionFormPickerSheet> {
  late final Future<PokemonDetail> _detailFuture;
  String? _selectedFormKey;
  var _isShiny = false;

  @override
  void initState() {
    super.initState();
    _detailFuture = dexRepository.getDetail(widget.summary.id);
  }

  Future<void> _confirm(PokemonFormDetail? form) async {
    final formKey = form?.key;
    final summary = form?.summaryFor(widget.summary) ?? widget.summary;
    if (!mounted) {
      return;
    }
    final choice = await adoptCompanion(
      context,
      summary,
      formKey: formKey,
      isShiny: _isShiny,
    );
    if (choice != null && mounted) {
      Navigator.of(context).pop(choice);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return SizedBox(
      height: size.height * 0.6,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: FutureBuilder<PokemonDetail>(
          future: _detailFuture,
          builder: (context, snapshot) {
            final detail = snapshot.data;
            final forms = detail?.forms ?? [];
            final hasForms = forms.length > 1;
            final selectedForm = forms.cast<PokemonFormDetail?>().firstWhere(
                  (f) => f?.key == _selectedFormKey,
                  orElse: () => null,
                );
            final previewSummary =
                selectedForm?.summaryFor(widget.summary) ?? widget.summary;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '选择形态与外观',
                        style: SecondaryTypography.onCard.h15,
                      ),
                    ),
                    FilterChip(
                      selected: _isShiny,
                      onSelected: hasForms || snapshot.connectionState == ConnectionState.done
                          ? (value) => setState(() => _isShiny = value)
                          : null,
                      showCheckmark: false,
                      selectedColor: TitoColors.softYellow,
                      backgroundColor: TitoColors.card,
                      side: const BorderSide(
                        color: TitoColors.ink,
                        width: TitoBorders.element,
                      ),
                      avatar: const Icon(
                        Icons.auto_awesome_rounded,
                        size: 16,
                      ),
                      label: const Text('闪光'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  previewSummary.nameZh,
                  style: SecondaryTypography.onCard.body14.copyWith(
                    color: TitoColors.mutedInk,
                  ),
                ),
                const SizedBox(height: 10),
                if (snapshot.connectionState != ConnectionState.done)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (!hasForms)
                  Expanded(
                    child: Center(
                      child: Text(
                        '该宝可梦没有其他形态',
                        style: SecondaryTypography.onCard.body14,
                      ),
                    ),
                  )
                else
                  Expanded(
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
                          selected: selected,
                          onTap: () => setState(() => _selectedFormKey = form.key),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 10),
                StickerPressable(
                  borderRadius: BorderRadius.circular(TitoRadii.md),
                  ownShadow: false,
                  child: FilledButton(
                    onPressed: snapshot.connectionState == ConnectionState.done
                        ? () => _confirm(selectedForm)
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: TitoColors.coral,
                      foregroundColor: TitoColors.card,
                      disabledBackgroundColor: TitoColors.card.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(TitoRadii.md),
                        side: const BorderSide(
                          color: TitoColors.ink,
                          width: TitoBorders.element,
                        ),
                      ),
                    ),
                    child: const Text('确定'),
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

class _CompanionFormTile extends StatelessWidget {
  const _CompanionFormTile({
    required this.form,
    required this.species,
    required this.selected,
    required this.onTap,
  });

  final PokemonFormDetail form;
  final PokemonSummary species;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final summary = form.summaryFor(species);
    return StickerPressable(
      borderRadius: BorderRadius.circular(TitoRadii.md),
      ownShadow: false,
      child: Material(
        color: selected
            ? TitoColors.softYellow.withValues(alpha: 0.22)
            : TitoColors.cream,
        borderRadius: BorderRadius.circular(TitoRadii.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(TitoRadii.md),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TitoRadii.md),
              border: Border.all(
                color: selected ? TitoColors.softYellow : TitoColors.ink,
                width: TitoBorders.element,
              ),
            ),
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: DexSpriteImage(
                    source: summary.displayArtworkPath,
                    height: null,
                    width: null,
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
