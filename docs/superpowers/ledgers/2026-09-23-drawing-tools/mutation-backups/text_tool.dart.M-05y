import 'dart:ui' show Canvas;

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/widgets.dart' show TextEditingController;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tool.dart';
import 'placement_tool.dart';

/// Where a pending text will go, and how tall (spec 05 D9).
final class TextPlacement {
  const TextPlacement(this.point, this.heightMm);
  final Vector2 point;
  final double heightMm;
}

/// Spec 05 D9. A click sets [pending]; the app's field edits [controller].
///
/// **The rule, stated once.** Enter, or a canvas click, commits a non-empty
/// string. Escape, a tool switch, or any other loss of focus cancels. The
/// tool owns the text, so a canvas click commits synchronously, before the
/// layer's focus request takes effect.
class TextTool extends PlacementTool {
  TextTool();

  final TextEditingController controller = TextEditingController();
  final ValueNotifier<TextPlacement?> _pending =
      ValueNotifier<TextPlacement?>(null);

  ValueListenable<TextPlacement?> get pending => _pending;

  @override
  String get name => 'Text';

  @override
  bool get isPending => _pending.value != null;

  @override
  Vector2? get orthoBase => null;

  @override
  void accept(Vector2 point, ToolContext ctx) {
    if (_pending.value != null) {
      commitText(controller.text, ctx);
      return;
    }
    controller.clear();
    _pending.value = TextPlacement(point, textHeightMm(ctx.page?.value));
  }

  @override
  void finish(ToolContext ctx) => commitText(controller.text, ctx);

  void commitText(String s, ToolContext ctx) {
    final placed = _pending.value;
    if (placed == null) return;
    if (s.isNotEmpty) {
      commit(
          ctx,
          () => addDrafted(ctx.document, EntityKind.text,
              textPayload(placed.point, placed.heightMm),
              text: s));
    }
    cancel(ctx);
  }

  void cancelText(ToolContext ctx) => cancel(ctx);

  @override
  void clearShape() {
    super.clearShape();
    _pending.value = null;
    controller.clear();
  }

  /// A small insertion cross at the pending point, 6 screen px per arm.
  @override
  void paintRubberBand(Canvas canvas, Vector2 origin, double scale) {
    final placed = _pending.value;
    if (placed == null) return;
    final x = placed.point.x - origin.x, y = placed.point.y - origin.y;
    final arm = 6 / scale;
    band
      ..reset()
      ..moveTo(x - arm, y)
      ..lineTo(x + arm, y)
      ..moveTo(x, y - arm)
      ..lineTo(x, y + arm);
    canvas.drawPath(band, bandPaint);
  }

  @override
  void dispose() {
    controller.dispose();
    _pending.dispose();
    super.dispose();
  }
}
