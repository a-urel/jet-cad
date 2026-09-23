import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'box.dart';

/// Spec 06 D13: two opposite corners, world-axis aligned, committed as a
/// parametric box — a group at the lower-left corner carrying [BoxParams].
/// The expander generates its lines. Fill does not apply.
class BoxTool extends RectangleTool {
  BoxTool();

  @override
  String get name => 'Box';

  @override
  void accept(Vector2 point, ToolContext ctx) {
    if (points.isEmpty) {
      points.add(point);
      return;
    }
    final c1 = points.first;
    if (isDegenerateRectangle(c1, point)) return;
    commit(ctx, () {
      final doc = ctx.document;
      final h = doc.handleSeed.next();
      final minX = c1.x < point.x ? c1.x : point.x;
      final minY = c1.y < point.y ? c1.y : point.y;
      return CompoundCommand([
        AddNodeCommand(GroupNode(
            handle: h,
            parent: doc.rootHandle,
            transform: Transform2.translation(minX, minY),
            children: const [])),
        SetComponentCommand<BoxParams>(
            h, BoxParams((point.x - c1.x).abs(), (point.y - c1.y).abs())),
      ], label: 'Add box');
    }, needs: const {
      Capability.structure,
      Capability.components,
      Capability.geometry,
    });
    clearShape();
  }
}
