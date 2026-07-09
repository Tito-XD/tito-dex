import 'dart:io';

import 'package:flutter/material.dart';

import '../features/dex/dex_artwork_service.dart';
import '../theme/tito_colors.dart';

Future<void> showPokemonArtworkViewer(
  BuildContext context, {
  required int pokemonId,
  required String nameZh,
  String? artworkUrl,
  String? thumbSource,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.88),
    builder: (context) => _PokemonArtworkViewer(
      pokemonId: pokemonId,
      nameZh: nameZh,
      artworkUrl: artworkUrl,
      thumbSource: thumbSource,
    ),
  );
}

class _PokemonArtworkViewer extends StatefulWidget {
  const _PokemonArtworkViewer({
    required this.pokemonId,
    required this.nameZh,
    this.artworkUrl,
    this.thumbSource,
  });

  final int pokemonId;
  final String nameZh;
  final String? artworkUrl;
  final String? thumbSource;

  @override
  State<_PokemonArtworkViewer> createState() => _PokemonArtworkViewerState();
}

class _PokemonArtworkViewerState extends State<_PokemonArtworkViewer> {
  String? _source;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _source = widget.thumbSource;
    _loadArtwork();
  }

  Future<void> _loadArtwork() async {
    final resolved = await dexArtworkService.resolveArtworkSource(
      pokemonId: widget.pokemonId,
      artworkUrl: widget.artworkUrl,
      thumbSource: widget.thumbSource,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _source = resolved;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: SafeArea(
        child: Stack(
          children: [
            Center(
              child: _source == null
                  ? const Icon(Icons.image_not_supported_outlined,
                      color: TitoColors.card, size: 48)
                  : InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: _ArtworkImage(source: _source!),
                      ),
                    ),
            ),
            if (_loading)
              const Center(
                child: CircularProgressIndicator(color: TitoColors.card),
              ),
            Positioned(
              top: 8,
              left: 16,
              child: Text(
                widget.nameZh,
                style: const TextStyle(
                  color: TitoColors.card,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: TitoColors.card),
                tooltip: '关闭',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtworkImage extends StatelessWidget {
  const _ArtworkImage({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(source);
    if (uri != null && uri.hasScheme && uri.scheme.startsWith('http')) {
      return Image.network(source, fit: BoxFit.contain);
    }
    return Image.file(File(source), fit: BoxFit.contain);
  }
}
