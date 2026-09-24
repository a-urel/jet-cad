import 'dart:ui' show Offset, Paint, Path, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show SnapKind;
import 'package:jet_cad_2d_flutter/src/snap_marker.dart';

import 'support/spy_canvas.dart';

void main() {
  test(
      'each snap kind draws its own marker; the raw point draws nothing '
      '(spec D9, M-03ag)', () {
    const at = Offset(300, 200);
    final paint = Paint();
    List<RecordedCall> draw(SnapKind? kind, {bool grid = false}) {
      final spy = SpyCanvas();
      drawSnapMarker(spy, at, kind, grid: grid, paint: paint);
      return spy.calls;
    }

    List<String> names(List<RecordedCall> calls) =>
        [for (final c in calls) c.name];

    final endpoint = draw(SnapKind.endpoint);
    expect(names(endpoint), ['drawRect']);
    expect(endpoint.single.args[0],
        Rect.fromCenter(center: at, width: 10, height: 10));

    final midpoint = draw(SnapKind.midpoint);
    expect(names(midpoint), ['drawPath']);
    final triangle = midpoint.single.args[0] as Path;
    expect(triangle.contains(at + const Offset(0, 4)), isTrue,
        reason: 'the base is at the bottom');
    expect(triangle.contains(at + const Offset(-4, -4)), isFalse,
        reason: 'apex up: the top corners are outside');

    final center = draw(SnapKind.center);
    expect(names(center), ['drawCircle']);
    expect(center.single.args[1], 5.0);

    final quadrant = draw(SnapKind.quadrant);
    expect(names(quadrant), ['drawPath']);
    final diamond = quadrant.single.args[0] as Path;
    expect(diamond.contains(at), isTrue);
    expect(diamond.contains(at + const Offset(4, 4)), isFalse);

    expect(
        names(draw(SnapKind.insertion)), ['drawRect', 'drawLine', 'drawLine']);

    final x = draw(SnapKind.intersection);
    expect(names(x), ['drawLine', 'drawLine']);
    expect(x[0].args[0], at + const Offset(-5, -5));
    expect(x[0].args[1], at + const Offset(5, 5));

    final grid = draw(null, grid: true);
    expect(names(grid), ['drawLine', 'drawLine']);
    expect(((grid[0].args[1] as Offset) - (grid[0].args[0] as Offset)).distance,
        6.0);

    expect(draw(null), isEmpty, reason: 'nothing when the raw point won');
    for (final kind in [
      SnapKind.perpendicular,
      SnapKind.tangent,
      SnapKind.nearest,
    ]) {
      expect(draw(kind), isEmpty,
          reason: '${kind.name} is not in kDragSnapMask');
    }
  });
}
