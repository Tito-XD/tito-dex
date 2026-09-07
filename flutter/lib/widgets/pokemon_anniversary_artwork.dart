import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/dex/pokemon_anniversary_art.dart';
import '../l10n/app_zh.dart';
import '../theme/tito_colors.dart';
import 'tito_skeleton.dart';

/// Loaded only after selecting the anniversary display in the artwork viewer.
class PokemonAnniversaryArtwork extends StatefulWidget {
  const PokemonAnniversaryArtwork({
    super.key,
    required this.nationalId,
    this.nameEn,
    this.spriteResourceId,
  });

  final int nationalId;
  final String? nameEn;
  final int? spriteResourceId;

  @override
  State<PokemonAnniversaryArtwork> createState() =>
      _PokemonAnniversaryArtworkState();
}

class _PokemonAnniversaryArtworkState extends State<PokemonAnniversaryArtwork> {
  var _attempt = 0;
  String? _selectedFile;

  @override
  void didUpdateWidget(covariant PokemonAnniversaryArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nationalId != widget.nationalId ||
        oldWidget.nameEn != widget.nameEn ||
        oldWidget.spriteResourceId != widget.spriteResourceId) {
      _selectedFile = null;
      _attempt = 0;
    }
  }

  Future<void> _openSource() async {
    try {
      final opened = await launchUrl(
        Uri.parse(pokemonAnniversarySourceUrl),
        mode: LaunchMode.externalApplication,
      );
      if (opened || !mounted) return;
    } catch (_) {
      if (!mounted) return;
    }
    if (mounted) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(
        SnackBar(content: Text(AppZh.anniversarySourceOpenFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selection = selectPokemonAnniversaryArt(
      widget.nationalId,
      nameEn: widget.nameEn,
      spriteResourceId: widget.spriteResourceId,
    );
    if (selection == null) return const SizedBox.shrink();
    final arts = pokemonAnniversaryArts(widget.nationalId);
    final art = arts.firstWhere(
      (art) => art.file == _selectedFile,
      orElse: () => selection.art,
    );
    final source = art.url;
    return Column(
      children: [
        if (arts.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DropdownButtonFormField<String>(
              key: ValueKey(
                'anniversary-picker-${widget.nationalId}-${widget.nameEn}-${widget.spriteResourceId}',
              ),
              initialValue: art.file,
              isExpanded: true,
              menuMaxHeight: 280,
              dropdownColor: TitoColors.ink,
              style: const TextStyle(color: TitoColors.card, fontSize: 14),
              decoration: InputDecoration(
                labelText: AppZh.anniversaryPickLogo,
                labelStyle: TextStyle(color: TitoColors.card),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: [
                for (final option in arts)
                  DropdownMenuItem(
                    value: option.file,
                    child: Text(option.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (file) => setState(() {
                _selectedFile = file;
                _attempt = 0;
              }),
            ),
          ),
        Text(
          AppZh.anniversaryCurrentLabel(
            art.label,
            formMismatch: _selectedFile == null && !selection.matchesForm,
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(color: TitoColors.card, fontSize: 12),
        ),
        Text(
          art.officialLabel,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: TitoColors.card.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: InteractiveViewer(
            key: ValueKey('anniversary-zoom-${art.file}'),
            minScale: 0.8,
            maxScale: 4,
            child: Center(
              child: Image.network(
                source,
                // The official image host does not provide CORS headers.
                // Use Flutter's HTML image renderer on Web; native is unchanged.
                webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                key: ValueKey('anniversary-${art.file}-$_attempt'),
                fit: BoxFit.contain,
                semanticLabel: AppZh.anniversaryImageSemantics(
                  widget.nationalId,
                  art.label,
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  // Image placeholder: the same skeleton block the sprite
                  // slots use, sized like the artwork it stands in for.
                  return const Center(
                    child: TitoSkeletonBox(
                      height: 180,
                      width: 180,
                      radius: TitoRadii.lg,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) =>
                    SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.image_not_supported_outlined,
                            color: TitoColors.card,
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            AppZh.anniversaryImageLoadFailed,
                            style: TextStyle(color: TitoColors.card),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              await NetworkImage(
                                source,
                                webHtmlElementStrategy:
                                    WebHtmlElementStrategy.prefer,
                              ).evict();
                              if (mounted) setState(() => _attempt++);
                            },
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(AppZh.retry),
                          ),
                        ],
                      ),
                    ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          AppZh.anniversaryDisplayOnlyNote,
          textAlign: TextAlign.center,
          style: TextStyle(color: TitoColors.card, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          AppZh.anniversaryCopyrightNote,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: TitoColors.card.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
        TextButton(
          onPressed: _openSource,
          child: Text(AppZh.anniversarySourceLink),
        ),
      ],
    );
  }
}
