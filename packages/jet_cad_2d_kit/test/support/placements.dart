// Two placements, copied for the label tests ported in 2b Task 3: today's
// fixture placement (jet_cad_floor_plan/test/tables/table_fixture.dart:
// 72-78) and the placer's quarter-turn form (jet_cad_floor_plan/lib/src/
// symbols/symbol_placer.dart:51-78, the `rotation` form left out). The kit
// depends on neither package.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// `translate(at) · R(theta) · (mirror x) · translate(-base)`.
Transform2 placementAt(double x, double y, double theta,
        {bool mirrored = false, double baseX = 900, double baseY = 700}) =>
    Transform2.translation(x, y)
        .multiply(Transform2.rotation(theta))
        .multiply(Transform2.scale(mirrored ? -1 : 1, 1))
        .multiply(Transform2.translation(-baseX, -baseY));

/// `translation(at) · rotation · scale(mirrored ? -1 : 1, 1) ·
/// translation(-basePoint)`, the rotation [quarterTurns] counter-clockwise
/// with exact cosine and sine, and no stored `-0.0`.
Transform2 placementTransform({
  required Vector2 at,
  required Vector2 basePoint,
  int quarterTurns = 0,
  bool mirrored = false,
}) {
  final (cos, sin) = const [
    (1.0, 0.0),
    (0.0, 1.0),
    (-1.0, 0.0),
    (0.0, -1.0)
  ][((quarterTurns % 4) + 4) % 4];
  final m = Transform2.translation(at.x, at.y)
      .multiply(Transform2(cos, sin, -sin, cos, 0, 0))
      .multiply(Transform2.scale(mirrored ? -1 : 1, 1))
      .multiply(Transform2.translation(-basePoint.x, -basePoint.y));
  double clean(double v) => v == 0 ? 0.0 : v;
  return Transform2(
      clean(m.a), clean(m.b), clean(m.c), clean(m.d), clean(m.e), clean(m.f));
}
