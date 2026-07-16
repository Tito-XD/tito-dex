import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/tito_colors.dart';

/// Renders the first loadable source from [sources] (network / asset / file),
/// advancing to the next candidate on load error. Used for animated sprites
/// where coverage differs per source (Showdown gif → BW gif → static PNG).
class FallbackSpriteImage extends StatefulWidget {
  const FallbackSpriteImage({
    super.key,
    required this.sources,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  final List<String> sources;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  State<FallbackSpriteImage> createState() => _FallbackSpriteImageState();
}

class _FallbackSpriteImageState extends State<FallbackSpriteImage> {
  var _index = 0;

  @override
  void didUpdateWidget(covariant FallbackSpriteImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sources.length != widget.sources.length ||
        oldWidget.sources.isNotEmpty &&
            widget.sources.isNotEmpty &&
            oldWidget.sources.first != widget.sources.first) {
      _index = 0;
    }
  }

  void _advance() {
    if (!mounted || _index >= widget.sources.length) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _index += 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_index >= widget.sources.length) {
      return _placeholder();
    }

    final source = widget.sources[_index];
    Widget onError(BuildContext _, Object __, StackTrace? ___) {
      _advance();
      return _placeholder();
    }

    if (source.startsWith('assets/')) {
      return Image.asset(
        source,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: onError,
      );
    }

    final uri = Uri.tryParse(source);
    if (uri != null && uri.hasScheme && uri.scheme.startsWith('http')) {
      return Image.network(
        source,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: onError,
      );
    }

    return Image.file(
      File(source),
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: onError,
    );
  }

  Widget _placeholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: TitoColors.card.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(TitoRadii.sm),
      ),
    );
  }
}
