import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/tito_colors.dart';
import 'tito_skeleton.dart';
import 'tito_pokeball_loading.dart';
import 'tito_delayed_loading.dart';

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

  /// Show a pale rotating ball only when a network source takes time to load.
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

  /// Brief reads use a quiet placeholder; slow downloads get one steady ball.
  Widget _loadingBox() {
    return TitoDelayedLoading(
      placeholder: _placeholder(),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Center(
          child: TitoPokeballLoading(
            size: ((widget.height ?? 56) * .4).clamp(12.0, 28.0),
            onLight: true,
          ),
        ),
      ),
    );
  }
}
