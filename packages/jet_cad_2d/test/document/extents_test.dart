import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

GeometryPayload payload(List<double> coords,
        [List<double> scalars = const []]) =>
    GeometryPayload(
      coords: Float64List.fromList(coords),
      scalars: Float64List.fromList(scalars),
    );

void main() {
  const measurer = InsertionPointMeasurer();

  test('line bounds its endpoints', () {
    final box = entityBounds(
      kind: EntityKind.line,
      payload: payload([0, 0, 10, -5]),
      measurer: measurer,
      textStyle: ReservedHandles.standardTextStyle,
    );
    expect(box.min, Vector2(0, -5));
    expect(box.max, Vector2(10, 0));
  });

  test('circle bounds centre plus radius, not just the centre point', () {
    final box = entityBounds(
      kind: EntityKind.circle,
      payload: payload([100, 50], [10]),
      measurer: measurer,
      textStyle: ReservedHandles.standardTextStyle,
    );
    expect(box.min, Vector2(90, 40));
    expect(box.max, Vector2(110, 60));
  });

  test('arc includes an axis extreme inside its sweep', () {
    // The same trap arcBounds exists to avoid, reached through the entity path.
    final box = entityBounds(
      kind: EntityKind.arc,
      payload: payload([0, 0], [1, -math.pi / 4, math.pi / 2]),
      measurer: measurer,
      textStyle: ReservedHandles.standardTextStyle,
    );
    expect(box.max.x, closeTo(1, 1e-12));
  });

  test('polyline bounds every vertex', () {
    final box = entityBounds(
      kind: EntityKind.polyline,
      payload: payload([0, 0, 5, 12, -3, 4]),
      measurer: measurer,
      textStyle: ReservedHandles.standardTextStyle,
    );
    expect(box.min, Vector2(-3, 0));
    expect(box.max, Vector2(5, 12));
  });

  test('text uses the injected measurer, so the engine needs no font stack',
      () {
    final box = entityBounds(
      kind: EntityKind.text,
      payload: payload([7, 8], [2.5]),
      measurer: measurer,
      textStyle: ReservedHandles.standardTextStyle,
      text: 'Table 12',
    );
    // The default measurer contributes the insertion point only; a real layout
    // arrives with the widget layer.
    expect(box.min, Vector2(7, 8));
    expect(box.max, Vector2(7, 8));
  });
}
