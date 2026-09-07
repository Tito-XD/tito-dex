import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/tito_colors.dart';
import 'tito_skeleton.dart';

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
    this.showLoadingProgress = false,
    this.filterQuality = FilterQuality.low,
  });

  final List<String> sources;
  final double? width;
  final double? height;
  final BoxFit fit;

  /// Upscale filtering — pass [FilterQuality.none] for crisp pixel art.
  final FilterQuality filterQuality;

  /// Show a pulsing skeleton box while a network source downloads.
  final bool showLoadingProgress;

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
        filterQuality: widget.filterQuality,
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
        filterQuality: widget.filterQuality,
        errorBuilder: onError,
        loadingBuilder: widget.showLoadingProgress
            ? (context, child, progress) {
                if (progress == null) {
                  return child;
                }
                return _loadingBox();
              }
            : null,
      );
    }

    return Image.file(
      File(source),
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      filterQuality: widget.filterQuality,
      errorBuilder: onError,
    );
  }

  Widget _placeholder() {
    return TitoSkeletonBox(
      width: widget.width,
      height: widget.height,
      radius: TitoRadii.sm,
    );
  }

  /// Image slots show a pulsing skeleton, not a spinner (D10). Byte progress
  /// is intentionally not drawn: sprites are tiny and the ring only flickered.
  Widget _loadingBox() {
    return TitoSkeletonBox(
      width: widget.width,
      height: widget.height,
      radius: TitoRadii.sm,
      shimmer: true,
    );
  }
}
