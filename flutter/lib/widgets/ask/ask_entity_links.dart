import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/journey/ask_titodex_entity_links.dart';
import '../../l10n/app_zh.dart';
import '../../theme/secondary_typography.dart';
import '../../theme/tito_colors.dart';

class AskEntityLinkCards extends StatefulWidget {
  const AskEntityLinkCards({
    super.key,
    required this.question,
    required this.answer,
    required this.resolver,
    this.animate = false,
    this.stableIds,
  });

  final String question;
  final String answer;
  final AskTitoDexEntityResolver resolver;
  final bool animate;
  final List<String>? stableIds;

  @override
  State<AskEntityLinkCards> createState() => _AskEntityLinkCardsState();
}

class _AskEntityLinkCardsState extends State<AskEntityLinkCards> {
  late Future<List<AskTitoDexEntityLink>> _links;

  @override
  void initState() {
    super.initState();
    _links = widget.resolver.resolve(
      question: widget.question,
      answer: widget.answer,
      stableIds: widget.stableIds,
    );
  }

  @override
  void didUpdateWidget(covariant AskEntityLinkCards oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question != widget.question ||
        oldWidget.answer != widget.answer ||
        oldWidget.resolver != widget.resolver ||
        oldWidget.stableIds != widget.stableIds) {
      _links = widget.resolver.resolve(
        question: widget.question,
        answer: widget.answer,
        stableIds: widget.stableIds,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AskTitoDexEntityLink>>(
      future: _links,
      builder: (context, snapshot) {
        final links = snapshot.data ?? const <AskTitoDexEntityLink>[];
        if (links.isEmpty) return const SizedBox.shrink();
        return Column(
          key: const Key('ask-titodex-entity-links'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppZh.askTitoDexContinueInApp,
              style: SecondaryTypography.onCard.small12.copyWith(
                color: TitoColors.mutedInk,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (var index = 0; index < links.length; index += 1)
                  _StaggeredEntityChip(
                    key: ValueKey(
                      'ask-entity-reveal-${links[index].kind.name}-${links[index].id}',
                    ),
                    animate: widget.animate,
                    index: index,
                    child: _EntityActionChip(link: links[index]),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _EntityActionChip extends StatelessWidget {
  const _EntityActionChip({required this.link});

  final AskTitoDexEntityLink link;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      key: ValueKey('ask-entity-${link.kind.name}-${link.id}'),
      visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      avatar: Icon(_entityIcon(link.kind), size: 15),
      label: Text('${link.nameZh} · ${_entityKindLabel(link.kind)}'),
      onPressed: () => context.push(link.route),
    );
  }
}

class _StaggeredEntityChip extends StatefulWidget {
  const _StaggeredEntityChip({
    super.key,
    required this.animate,
    required this.index,
    required this.child,
  });

  final bool animate;
  final int index;
  final Widget child;

  @override
  State<_StaggeredEntityChip> createState() => _StaggeredEntityChipState();
}

class _StaggeredEntityChipState extends State<_StaggeredEntityChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;
  var _prepared = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prepared) return;
    _prepared = true;
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      return;
    }
    final boundedIndex = widget.index < 4 ? widget.index : 4;
    Future<void>.delayed(Duration(milliseconds: 250 + (boundedIndex * 55)), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(_curve),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(_curve),
          child: widget.child,
        ),
      ),
    );
  }
}

IconData _entityIcon(AskTitoDexEntityKind kind) => switch (kind) {
  AskTitoDexEntityKind.pokemon => Icons.catching_pokemon_rounded,
  AskTitoDexEntityKind.item => Icons.backpack_rounded,
  AskTitoDexEntityKind.move => Icons.auto_awesome_rounded,
  AskTitoDexEntityKind.ability => Icons.bolt_rounded,
};

String _entityKindLabel(AskTitoDexEntityKind kind) => switch (kind) {
  AskTitoDexEntityKind.pokemon => AppZh.askTitoDexEntityPokemon,
  AskTitoDexEntityKind.item => AppZh.askTitoDexEntityItem,
  AskTitoDexEntityKind.move => AppZh.askTitoDexEntityMove,
  AskTitoDexEntityKind.ability => AppZh.askTitoDexEntityAbility,
};
