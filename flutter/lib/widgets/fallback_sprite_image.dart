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
    this.showLoadingProgress = false,
    this.filterQuality = FilterQuality.low,
  });

  final List<String> sources;
  final double? width;
  final double? height;
  final BoxFit fit;

  /// Upscale filtering — pass [FilterQuality.none] for crisp pixel art.
  final FilterQuality filterQuality;

  /// Show a small progress ring while a network source downloads
  /// (with real byte progress when the server reports content length).
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
                final total = progress.expectedTotalBytes;
                return _loadingRing(
                  total == null || total == 0
                      ? null
                      : progress.cumulativeBytesLoaded / total,
                );
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
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: TitoColors.card.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(TitoRadii.sm),
      ),
    );
  }

  Widget _loadingRing(double? value) {
    final side = widget.width ?? widget.height ?? 40.0;
    final ring = (side * 0.42).clamp(14.0, 26.0);
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Center(
        child: SizedBox(
          width: ring,
          height: ring,
          child: CircularProgressIndicator(
            value: value,
            strokeWidth: 2.5,
            color: TitoColors.deepBlue,
            backgroundColor: TitoColors.deepBlue.withValues(alpha: 0.15),
          ),
        ),
      ),
    );
  }
}
