import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// The visible control represented by one handheld focus stop.
class HandheldFocusTarget extends SingleChildRenderObjectWidget {
  const HandheldFocusTarget({
    super.key,
    required this.radius,
    required super.child,
  });
  final BorderRadius radius;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFocusTarget(radius);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderProxyBox renderObject,
  ) {
    (renderObject as _RenderFocusTarget).radius = radius;
  }
}

class _RenderFocusTarget extends RenderProxyBox {
  _RenderFocusTarget(this.radius);
  BorderRadius radius;
}

class HandheldFocusGeometry {
  const HandheldFocusGeometry(this.bounds, this.visible, this.radius);
  final Rect bounds;
  final Rect visible;
  final BorderRadius radius;
  bool get isVisible => visible.width > 1 && visible.height > 1;

  static HandheldFocusGeometry? of(FocusNode node) {
    final context = node.context;
    if (context == null || !context.mounted || node is FocusScopeNode) {
      return null;
    }
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return null;
    var target = context.findRenderObject();
    if (target is! RenderBox || !target.attached || !target.hasSize) {
      return null;
    }
    var radius = BorderRadius.circular(8);
    RenderObject? ancestor = target;
    var marked = false;
    while (ancestor != null) {
      if (ancestor is _RenderFocusTarget) {
        target = ancestor;
        radius = ancestor.radius;
        marked = true;
        break;
      }
      ancestor = ancestor.parent;
    }
    if (!marked) {
      // A field's editable text is smaller than its visible input surface.
      context.visitAncestorElements((element) {
        if (element.widget is InputDecorator) {
          final object = element.findRenderObject();
          if (object is RenderBox && object.hasSize) target = object;
          return false;
        }
        return true;
      });
    } else {
      // Sticker presses translate the painted card, not its outer layout box.
      RenderBox? proxy = target as RenderBox;
      while (proxy is RenderProxyBox) {
        if (proxy is RenderTransform && proxy.child != null) {
          target = proxy.child!;
          break;
        }
        proxy = proxy.child;
      }
    }
    final box = target as RenderBox;
    if (!box.attached || !box.hasSize || box.size.isEmpty) return null;
    final bounds = MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
    if (!bounds.isFinite || bounds.isEmpty) return null;
    var visible = bounds;
    RenderObject child = box;
    RenderObject? parent = box.parent;
    while (parent != null) {
      if ((parent is RenderOffstage && parent.offstage) ||
          (parent is RenderIgnorePointer && parent.ignoring) ||
          (parent is RenderAbsorbPointer && parent.absorbing) ||
          (parent is RenderOpacity && parent.opacity <= 0.01) ||
          (parent is RenderAnimatedOpacity && parent.opacity.value <= 0.01)) {
        return null;
      }
      final clip = parent.describeApproximatePaintClip(child);
      if (clip != null) {
        visible = visible.intersect(
          MatrixUtils.transformRect(parent.getTransformTo(null), clip),
        );
      }
      child = parent;
      parent = parent.parent;
    }
    final media = MediaQuery.maybeOf(context);
    if (media != null) visible = visible.intersect(Offset.zero & media.size);
    return HandheldFocusGeometry(bounds, visible, radius);
  }
}
