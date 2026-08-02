import 'package:flutter/material.dart';

import '../features/dex/dex_game_scope.dart';
import '../features/dex/dex_models.dart';
import '../features/dex/version_availability.dart';
import '../l10n/app_zh.dart';
import '../theme/secondary_typography.dart';
import '../theme/tito_colors.dart';
import 'dex_sprite_image.dart';
import 'sticker_card.dart';

class HeldItemReference {
  const HeldItemReference({
    required this.slug,
    required this.nameZh,
    this.spriteUrl,
  });

  final String slug;
  final String nameZh;
  final String? spriteUrl;

  factory HeldItemReference.fromJson(Map<String, dynamic> json) {
    final slug = json['slug'] as String? ?? '';
    return HeldItemReference(
      slug: slug,
      nameZh: json['nameZh'] as String? ?? _readableItemSlug(slug),
      spriteUrl: json['spriteUrl'] as String?,
    );
  }
}

Map<String, HeldItemReference> heldItemReferencesBySlug(
  Iterable<Map<String, dynamic>> entries,
) => {
  for (final entry in entries)
    if ((entry['slug'] as String? ?? '').isNotEmpty)
      entry['slug'] as String: HeldItemReference.fromJson(entry),
};

class HeldItemDisplayEntry {
  const HeldItemDisplayEntry({
    required this.item,
    required this.reference,
    required this.rarities,
  });

  final PokemonHeldItem item;
  final HeldItemReference reference;
  final Map<String, int> rarities;
}

List<HeldItemDisplayEntry> heldItemDisplayEntries({
  required Iterable<PokemonHeldItem> items,
  required Iterable<String> versionKeys,
  Map<String, HeldItemReference> references = const {},
}) {
  final keys = versionKeys.toSet();
  final result = <HeldItemDisplayEntry>[];
  for (final item in items) {
    final rarities = <String, int>{
      for (final entry in item.rarityByVersion.entries)
        if (keys.contains(entry.key) && entry.value > 0) entry.key: entry.value,
    };
    if (rarities.isEmpty) {
      continue;
    }
    result.add(
      HeldItemDisplayEntry(
        item: item,
        reference:
            references[item.slug] ??
            HeldItemReference(
              slug: item.slug,
              nameZh: _readableItemSlug(item.slug),
            ),
        rarities: rarities,
      ),
    );
  }
  result.sort((a, b) {
    final rarityCompare = b.item.maxRarity.compareTo(a.item.maxRarity);
    return rarityCompare != 0
        ? rarityCompare
        : a.reference.nameZh.compareTo(b.reference.nameZh);
  });
  return result;
}

class PokemonHeldItemsCard extends StatelessWidget {
  const PokemonHeldItemsCard({
    super.key,
    required this.items,
    required this.versionKeys,
    required this.referencesFuture,
  });

  final List<PokemonHeldItem> items;
  final List<String> versionKeys;
  final Future<Map<String, HeldItemReference>> referencesFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, HeldItemReference>>(
      future: referencesFuture,
      builder: (context, snapshot) {
        final entries = heldItemDisplayEntries(
          items: items,
          versionKeys: versionKeys,
          references: snapshot.data ?? const {},
        );
        if (entries.isEmpty) {
          return const SizedBox.shrink();
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const StickerCard(child: _HeldItemsLoading());
        }
        return StickerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppZh.dexWildHeldItems,
                style: SecondaryTypography.onCard.h15,
              ),
              const SizedBox(height: 4),
              Text(
                AppZh.dexWildHeldItemsHint,
                style: SecondaryTypography.onCard.small12.copyWith(
                  color: TitoColors.mutedInk,
                ),
              ),
              const SizedBox(height: 10),
              for (var index = 0; index < entries.length; index++) ...[
                if (index > 0) const Divider(height: 18),
                _HeldItemRow(entry: entries[index]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _HeldItemsLoading extends StatelessWidget {
  const _HeldItemsLoading();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        const SizedBox(width: 10),
        Text(
          AppZh.dexWildHeldItems,
          style: SecondaryTypography.onCard.body14.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _HeldItemRow extends StatelessWidget {
  const _HeldItemRow({required this.entry});

  final HeldItemDisplayEntry entry;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DexSpriteImage(
          source: entry.reference.spriteUrl,
          width: 40,
          height: 40,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.reference.nameZh,
                style: SecondaryTypography.onCard.body14.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  for (final rarity in entry.rarities.entries)
                    _InfoPill(
                      label:
                          '${flavorVersionLabelZh(rarity.key)} ${rarity.value}%',
                      color: TitoColors.skyBlue,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class VersionChainPlanningCard extends StatelessWidget {
  const VersionChainPlanningCard({
    super.key,
    required this.chain,
    required this.currentDetail,
    required this.versionGroup,
    required this.exactVersion,
    required this.detailsFuture,
  });

  final EvolutionNode chain;
  final PokemonDetail currentDetail;
  final String versionGroup;
  final String? exactVersion;
  final Future<Map<int, PokemonDetail>> detailsFuture;

  @override
  Widget build(BuildContext context) {
    final version = exactVersion;
    if (version == null) {
      return const StickerCard(
        variant: StickerVariant.softYellow,
        child: _PlanningPrompt(),
      );
    }
    return FutureBuilder<Map<int, PokemonDetail>>(
      future: detailsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData &&
            snapshot.connectionState != ConnectionState.done) {
          return const StickerCard(child: _PlanningLoading());
        }
        final details = snapshot.data;
        if (details == null) {
          return StickerCard(
            child: Text(
              AppZh.dexChainPlanningUnavailable,
              style: SecondaryTypography.onCard.body14,
            ),
          );
        }
        final accessible = accessibleEncounterVersions(version);
        final catchableIds = _catchableIdsForChain(chain, details, accessible);
        final plan = planChainCompletion(
          chain: chain,
          isCatchable: catchableIds.contains,
          supportsBreeding: supportsBreedingInVersionGroup(versionGroup),
        );
        final paired = pairedEncounterVersion(version);
        final exclusivity = paired == null
            ? null
            : _accessibleVersionExclusivity(
                currentDetail.obtainLocationsByVersion,
                accessible,
                accessibleEncounterVersions(paired),
              );
        return _VersionPlanBody(
          plan: plan,
          version: version,
          pairedVersion: paired,
          exclusivity: exclusivity,
        );
      },
    );
  }
}

class _PlanningPrompt extends StatelessWidget {
  const _PlanningPrompt();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.tune_rounded, size: 22),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            AppZh.dexChainPlanningPickVersion,
            style: SecondaryTypography.onCard.body14.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanningLoading extends StatelessWidget {
  const _PlanningLoading();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        const SizedBox(width: 10),
        Text(
          AppZh.dexChainPlanningLoading,
          style: SecondaryTypography.onCard.body14,
        ),
      ],
    );
  }
}

class _VersionPlanBody extends StatelessWidget {
  const _VersionPlanBody({
    required this.plan,
    required this.version,
    required this.pairedVersion,
    required this.exclusivity,
  });

  final ChainCompletionPlan plan;
  final String version;
  final String? pairedVersion;
  final VersionExclusivity? exclusivity;

  @override
  Widget build(BuildContext context) {
    final (icon, color, summary) = switch ((
      plan.selfContained,
      plan.completable,
    )) {
      (true, _) => (
        Icons.check_circle_rounded,
        TitoColors.mint,
        AppZh.dexChainSelfContained(flavorVersionLabelZh(version)),
      ),
      (false, true) => (
        Icons.swap_horiz_rounded,
        TitoColors.coral,
        AppZh.dexChainTradeRequired,
      ),
      _ => (
        Icons.info_rounded,
        TitoColors.softYellow,
        AppZh.dexChainUnavailable(flavorVersionLabelZh(version)),
      ),
    };
    return StickerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppZh.dexChainPlanningTitle,
            style: SecondaryTypography.onCard.h15,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(TitoRadii.sm),
              border: Border.all(color: TitoColors.ink, width: 2),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    summary,
                    style: SecondaryTypography.onCard.body14.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (exclusivity != null && pairedVersion != null) ...[
            const SizedBox(height: 8),
            Text(
              _exclusivityLabel(exclusivity!, version, pairedVersion!),
              style: SecondaryTypography.onCard.small12.copyWith(
                color: TitoColors.mutedInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 10),
          for (final stage in plan.stages) _ChainStageRow(stage: stage),
        ],
      ),
    );
  }
}

class _ChainStageRow extends StatelessWidget {
  const _ChainStageRow({required this.stage});

  final ChainStagePlan stage;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (stage.method) {
      ChainStageMethod.catchable => (
        Icons.place_rounded,
        TitoColors.mint,
        AppZh.dexChainMethodCatch,
      ),
      ChainStageMethod.evolve => (
        Icons.auto_awesome_rounded,
        TitoColors.skyBlue,
        stage.triggerZh ?? AppZh.dexChainMethodEvolve,
      ),
      ChainStageMethod.tradeRequired => (
        Icons.lock_rounded,
        TitoColors.coral,
        AppZh.dexChainMethodTrade,
      ),
      ChainStageMethod.breedRequired => (
        Icons.egg_alt_rounded,
        TitoColors.softYellow,
        AppZh.dexChainMethodBreed,
      ),
      ChainStageMethod.unavailable => (
        Icons.block_rounded,
        TitoColors.softYellow,
        AppZh.dexChainMethodUnavailable,
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, size: 15),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              stage.nameZh,
              style: SecondaryTypography.onCard.body14.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.end,
              style: SecondaryTypography.onCard.small12.copyWith(
                color: TitoColors.mutedInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Set<int> _catchableIdsForChain(
  EvolutionNode chain,
  Map<int, PokemonDetail> details,
  Set<String> versionKeys,
) {
  final catchable = <int>{};
  void walk(EvolutionNode node) {
    var detail = details[node.id];
    final formKey = node.formKey;
    if (detail != null && formKey != null) {
      for (final form in detail.forms) {
        if (form.key == formKey) {
          detail = detail!.forForm(form);
          break;
        }
      }
    }
    if (detail != null &&
        versionKeys.any(
          (version) =>
              hasEncountersInVersion(detail!.obtainLocationsByVersion, version),
        )) {
      catchable.add(node.id);
    }
    for (final child in node.children) {
      walk(child);
    }
  }

  walk(chain);
  return catchable;
}

VersionExclusivity _accessibleVersionExclusivity(
  Map<String, List<ObtainLocationEntry>> byVersion,
  Set<String> hereVersions,
  Set<String> thereVersions,
) {
  final here = hereVersions.any(
    (version) => hasEncountersInVersion(byVersion, version),
  );
  final there = thereVersions.any(
    (version) => hasEncountersInVersion(byVersion, version),
  );
  if (here && there) return VersionExclusivity.both;
  if (here) return VersionExclusivity.onlyThis;
  if (there) return VersionExclusivity.onlyOther;
  return VersionExclusivity.neither;
}

String _exclusivityLabel(
  VersionExclusivity exclusivity,
  String version,
  String paired,
) => switch (exclusivity) {
  VersionExclusivity.both => AppZh.dexVersionBoth,
  VersionExclusivity.onlyThis => AppZh.dexVersionOnlyThis(
    flavorVersionLabelZh(version),
  ),
  VersionExclusivity.onlyOther => AppZh.dexVersionOnlyOther(
    flavorVersionLabelZh(paired),
  ),
  VersionExclusivity.neither => AppZh.dexVersionNeither,
};

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: TitoColors.ink, width: 1.5),
      ),
      child: Text(
        label,
        style: SecondaryTypography.onCard.small12.copyWith(
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
    );
  }
}

String _readableItemSlug(String slug) => slug
    .split('-')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
