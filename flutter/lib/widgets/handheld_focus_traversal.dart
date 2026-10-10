import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'handheld_focus_geometry.dart';

/// Directional navigation based on this frame's control geometry. No cached
/// directional history survives a responsive layout or a collapsed section.
class HandheldFocusTraversalPolicy extends FocusTraversalPolicy {
  final _reading = ReadingOrderTraversalPolicy();
  final _anchors = <FocusScopeNode, Rect>{};

  void remember(FocusNode node, Rect bounds) {
    final scope = node.nearestScope;
    if (scope != null) _anchors[scope] = bounds;
  }

  @override
  Iterable<FocusNode> sortDescendants(
    Iterable<FocusNode> descendants,
    FocusNode currentNode,
  ) => _reading.sortDescendants(descendants, currentNode);

  @override
  FocusNode? findFirstFocusInDirection(
    FocusNode currentNode,
    TraversalDirection direction,
  ) => _reading.findFirstFocusInDirection(currentNode, direction);

  @override
  void invalidateScopeData(FocusScopeNode node) {
    super.invalidateScopeData(node);
    _anchors.remove(node);
  }

  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) {
    final scope = currentNode.nearestScope ?? FocusManager.instance.rootScope;
    final targets = <(FocusNode, HandheldFocusGeometry)>[];
    for (final node in scope.traversalDescendants) {
      if (!node.canRequestFocus || node.skipTraversal) continue;
      final geometry = HandheldFocusGeometry.of(node);
      if (geometry != null) targets.add((node, geometry));
    }
    final current = HandheldFocusGeometry.of(currentNode);
    final origin = current?.bounds ?? _anchors[scope];
    if (current != null) remember(currentNode, current.bounds);
    if (origin == null) {
      final visible = targets.where((target) => target.$2.isVisible).toList();
      if (visible.isEmpty) return false;
      visible.sort((a, b) {
        final row = a.$2.bounds.top.compareTo(b.$2.bounds.top);
        return row != 0 ? row : a.$2.bounds.left.compareTo(b.$2.bounds.left);
      });
      return _focus(visible.first.$1, visible.first.$2, direction);
    }
    final ahead = targets.where((target) {
      if (target.$1 == currentNode) return false;
      final bounds = target.$2.bounds;
      final delta = bounds.center - origin.center;
      final forward = switch (direction) {
        TraversalDirection.up => delta.dy < -1,
        TraversalDirection.down => delta.dy > 1,
        TraversalDirection.left => delta.dx < -1,
        TraversalDirection.right => delta.dx > 1,
      };
      if (!forward) return false;
      final vertical =
          direction == TraversalDirection.up ||
          direction == TraversalDirection.down;
      final crossGap = vertical
          ? math.max(
              0.0,
              math.max(bounds.left - origin.right, origin.left - bounds.right),
            )
          : math.max(
              0.0,
              math.max(bounds.top - origin.bottom, origin.top - bounds.bottom),
            );
      final alongGap = switch (direction) {
        TraversalDirection.up => math.max(0.0, origin.top - bounds.bottom),
        TraversalDirection.down => math.max(0.0, bounds.top - origin.bottom),
        TraversalDirection.left => math.max(0.0, origin.left - bounds.right),
        TraversalDirection.right => math.max(0.0, bounds.left - origin.right),
      };
      // At a row/column edge, do not reinterpret Right as a large Up jump.
      // Diagonal bridges are allowed only within the forward visual cone.
      return crossGap <= 1 || crossGap <= alongGap;
    }).toList();
    final visible = ahead.where((target) => target.$2.isVisible).toList();
    if (visible.isNotEmpty) {
      visible.sort(
        (a, b) => _compare(origin, a.$2.bounds, b.$2.bounds, direction),
      );
      return _focus(visible.first.$1, visible.first.$2, direction);
    }
    // At a viewport edge, reveal the next laid-out control before changing
    // focus. Cached list children cannot become an invisible selection.
    final scrollable = currentNode.context == null
        ? null
        : Scrollable.maybeOf(currentNode.context!);
    final outside = ahead
        .where(
          (target) =>
              scrollable != null &&
              Scrollable.maybeOf(target.$1.context!) == scrollable,
        )
        .toList();
    if (outside.isEmpty) return false;
    outside.sort(
      (a, b) => _compare(origin, a.$2.bounds, b.$2.bounds, direction),
    );
    return _focus(outside.first.$1, outside.first.$2, direction);
  }

  bool _focus(
    FocusNode node,
    HandheldFocusGeometry geometry,
    TraversalDirection direction,
  ) {
    remember(node, geometry.bounds);
    requestFocusCallback(
      node,
      duration: Duration.zero,
      alignmentPolicy:
          direction == TraversalDirection.up ||
              direction == TraversalDirection.left
          ? ScrollPositionAlignmentPolicy.keepVisibleAtStart
          : ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
    return true;
  }

  int _compare(Rect origin, Rect a, Rect b, TraversalDirection direction) {
    final vertical =
        direction == TraversalDirection.up ||
        direction == TraversalDirection.down;
    List<double> rank(Rect target) {
      final crossStart = vertical ? target.left : target.top;
      final crossEnd = vertical ? target.right : target.bottom;
      final originStart = vertical ? origin.left : origin.top;
      final originEnd = vertical ? origin.right : origin.bottom;
      final gap = math.max(
        0.0,
        math.max(crossStart - originEnd, originStart - crossEnd),
      );
      final along = switch (direction) {
        TraversalDirection.up => math.max(0.0, origin.top - target.bottom),
        TraversalDirection.down => math.max(0.0, target.top - origin.bottom),
        TraversalDirection.left => math.max(0.0, origin.left - target.right),
        TraversalDirection.right => math.max(0.0, target.left - origin.right),
      };
      final cross = vertical
          ? (target.center.dx - origin.center.dx).abs()
          : (target.center.dy - origin.center.dy).abs();
      return [
        gap > 1 ? 1 : 0,
        gap > 1 ? gap : along,
        cross,
        (target.center - origin.center).distanceSquared,
      ];
    }

    final ar = rank(a), br = rank(b);
    for (var i = 0; i < ar.length; i++) {
      final result = ar[i].compareTo(br[i]);
      if (result != 0) return result;
    }
    return 0;
  }
}
