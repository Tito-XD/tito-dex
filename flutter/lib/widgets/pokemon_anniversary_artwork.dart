import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/dex/pokemon_anniversary_art.dart';
import '../theme/tito_colors.dart';

/// Loaded only after selecting the anniversary display in the artwork viewer.
class PokemonAnniversaryArtwork extends StatefulWidget {
  const PokemonAnniversaryArtwork({super.key, required this.nationalId});

  final int nationalId;

  @override
  State<PokemonAnniversaryArtwork> createState() =>
      _PokemonAnniversaryArtworkState();
}

class _PokemonAnniversaryArtworkState extends State<PokemonAnniversaryArtwork> {
  var _attempt = 0;

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
      )?.showSnackBar(const SnackBar(content: Text('暂时无法打开官方页面，请稍后重试。')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = pokemonAnniversaryArtUrl(widget.nationalId);
    if (source == null) return const SizedBox.shrink();
    return Column(
      children: [
        Expanded(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Center(
              child: Image.network(
                source,
                // The official image host does not provide CORS headers.
                // Use Flutter's HTML image renderer on Web; native is unchanged.
                webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                key: ValueKey('anniversary-${widget.nationalId}-$_attempt'),
                fit: BoxFit.contain,
                semanticLabel: '全国图鉴 ${widget.nationalId} · 30周年 Logo',
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.image_not_supported_outlined,
                      color: TitoColors.card,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '周年图片暂时无法加载',
                      style: TextStyle(color: TitoColors.card),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await NetworkImage(
                          source,
                          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                        ).evict();
                        if (mounted) setState(() => _attempt++);
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '按物种展示纪念 Logo，不改变当前形态或图鉴数据。',
          textAlign: TextAlign.center,
          style: TextStyle(color: TitoColors.card, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          '需联网加载 · 图片版权归原权利人所有',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: TitoColors.card.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
        TextButton(onPressed: _openSource, child: const Text('官方来源与使用条款')),
      ],
    );
  }
}
