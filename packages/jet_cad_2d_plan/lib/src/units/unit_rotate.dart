// Turning a placed unit by a quarter (spec 2b S4, the unit section's ±90
// buttons), ported from jet_cad_floor_plan's tables/table_rotate.dart (spec
// 14a T16): about its base point, so the unit turns in place and its label
// does not move. The label system stamps the label upright in the same step.
//
// No Flutter import: this file is Dart over `package:jet_cad_2d` only.
import 'package:jet_cad_2d/jet_cad_2d.dart';

/// The command that turns [instance] by [quarterTurns] × 90° (positive is
/// counter-clockwise, on the world and on the screen alike) about its
/// definition's base point, or null when [instance] is not a live instance
/// of a live definition. One `TransformNodeCommand` in a `Rotate` compound.
///
/// The new linear part is exact: a quarter turn only swaps and negates the
/// entries, and `0.0` is stored for `−0.0`, so four turns return it bit for
/// bit. The translation keeps the base point's world position; it is exact
/// for a unit placed at integer coordinates and within rounding otherwise.
DraftCommand? rotateUnitCommand(
    DraftDocument doc, Handle instance, int quarterTurns) {
  final node = doc.tree[instance];
  if (node is! InstanceNode) return null;
  final definition = doc.tree.definition(node.definition);
  if (definition == null) return null;
  final t = node.transform;
  final bp = definition.basePoint;
  final worldX = t.a * bp.x + t.c * bp.y + t.e;
  final worldY = t.b * bp.x + t.d * bp.y + t.f;

  final q = ((quarterTurns % 4) + 4) % 4;
  // R(q · 90°) · L, written as swaps and negations.
  final (a, b, c, d) = switch (q) {
    0 => (t.a, t.b, t.c, t.d),
    1 => (-t.b, t.a, -t.d, t.c),
    2 => (-t.a, -t.b, -t.c, -t.d),
    _ => (t.b, -t.a, t.d, -t.c),
  };
  double clean(double v) => v == 0 ? 0.0 : v;
  final e = worldX - (a * bp.x + c * bp.y);
  final f = worldY - (b * bp.x + d * bp.y);
  return CompoundCommand([
    TransformNodeCommand(instance,
        Transform2(clean(a), clean(b), clean(c), clean(d), clean(e), clean(f))),
  ], label: 'Rotate');
}
