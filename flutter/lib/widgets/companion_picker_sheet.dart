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

class _CompanionPickerSheet extends StatefulWidget {
  const _CompanionPickerSheet();

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
    // Starters ship inside the APK — no download, keep instantly.
    if (!bundledCompanionIds.contains(summary.id)) {
      final ready = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            _CompanionMediaLoadingDialog(summary: summary),
      );
      if (ready != true || !mounted) {
        return; // Cancelled — keep the previous companion.
      }
    }
    final choice = CompanionChoice(
      pokemonId: summary.id,
      nameZh: summary.nameZh,
    );
    await companionRepository.save(choice);
    if (mounted) {
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
              AppZh.companionPickerTitle,
              style: SecondaryTypography.onCard.h15,
            ),
            const SizedBox(height: 4),
            Text(
              AppZh.companionPickerHint,
              style: SecondaryTypography.onCard.small12.copyWith(
                color: TitoColors.mutedInk,
              ),
            ),
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
  const _CompanionMediaLoadingDialog({required this.summary});

  final PokemonSummary summary;

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
    final id = widget.summary.id;
    await Future.wait([
      companionMediaCache.ensureGif(id).then((path) {
        _update(() {
          _gif = path != null
              ? _MediaLoadState.done
              : _MediaLoadState.failed;
        });
      }),
      companionMediaCache.ensureCry(id).then((path) {
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
    return Material(
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
    );
  }
}
