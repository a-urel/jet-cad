import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

/// Every fixture below sits under this placement rather than at the identity
/// transform: translate, rotate 30°, then scale 1.5x uniformly. A predicate
/// that silently assumed axis alignment or unit scale would still pass every
/// assertion at the identity, which is exactly the degenerate fixture this
/// package's testing bar rules out.
final placement = Transform2.translation(300, -200)
    .multiply(Transform2.rotation(math.pi / 6))
    .multiply(Transform2.scale(1.5, 1.5));

GeometryPayload pl(List<double> coords, [List<double> scalars = const []]) =>
    GeometryPayload(
        coords: Float64List.fromList(coords),
        scalars: Float64List.fromList(scalars));

Vector2 w(double x, double y) => placement.transformPoint(Vector2(x, y));

/// A band around [centre] with half-size [h], in world space.
Aabb2 bandAt(Vector2 centre, double h) =>
    Aabb2.raw(centre.x - h, centre.y - h, centre.x + h, centre.y + h);

/// A fake measurer returning fixed metrics, independent of the string or
/// style — the fixed values the text test below builds its box arithmetic
/// against.
class _FakeMeasurer implements TextMeasurer {
  const _FakeMeasurer();

  @override
  TextMetrics measure({required String text, required TextStyleRecord style}) =>
      const TextMetrics(advanceWidth: 20, ascent: 8, descent: 2, capHeight: 7);
}

void main() {
  test(
      'a line is touched when the band crosses it and not when it sits beside it',
      () {
    final payload = pl([0, 0, 10, 0]);
    expect(
        leafTouchedByBandT(
            EntityKind.line, payload, placement, bandAt(w(5, 0), 1)),
        isTrue);
    // The band's own AABB overlaps nothing there under rotation either: the
    // world segment runs at 30° through w(5,0), and w(5,3) sits well off
    // that line even after the rotation is accounted for.
    expect(
        leafTouchedByBandT(
            EntityKind.line, payload, placement, bandAt(w(5, 3), 1)),
        isFalse);
  });

  test('a band fully inside a closed polyline touches nothing', () {
    final payload = pl([0, 0, 10, 0, 10, 10, 0, 10, 0, 0]);
    expect(
        leafTouchedByBandT(
            EntityKind.polyline, payload, placement, bandAt(w(5, 5), 1)),
        isFalse,
        reason: 'a band inside the fill touches no stroke (spec D8 is a '
            'crossing test, not containment)');
    expect(
        leafTouchedByBandT(
            EntityKind.polyline, payload, placement, bandAt(w(0, 5), 1)),
        isTrue,
        reason: 'the left edge runs through (0, 5)');
  });

  test('a circle is touched on its rim, not in its interior', () {
    final payload = pl([0, 0], [10]);
    expect(
        leafTouchedByBandT(
            EntityKind.circle, payload, placement, bandAt(w(0, 0), 2)),
        isFalse,
        reason: 'deep in the interior, nowhere near the rim');
    expect(
        leafTouchedByBandT(
            EntityKind.circle, payload, placement, bandAt(w(10, 0), 2)),
        isTrue,
        reason: 'w(10, 0) sits on the rim: the circle has local radius 10');
    expect(
        leafTouchedByBandT(
            EntityKind.circle, payload, placement, bandAt(w(0, 0), 30)),
        isTrue,
        reason: 'a band enclosing the whole circle counts as touched '
            '(circleClipWindows == -1)');
  });

  test('an arc is touched only on its sweep', () {
    final payload = pl([0, 0], [10, 0, math.pi / 2]);
    expect(
        leafTouchedByBandT(
            EntityKind.arc, payload, placement, bandAt(w(10, 0), 1)),
        isTrue,
        reason: 'w(10, 0) is the sweep\'s own start point (angle 0)');
    expect(
        leafTouchedByBandT(
            EntityKind.arc, payload, placement, bandAt(w(-10, 0), 1)),
        isFalse,
        reason: 'angle pi is outside the 0..pi/2 sweep; the full circle '
            'would hit here, the arc must not');
  });

  test('a point is touched when inside', () {
    final payload = pl([3, 4]);
    expect(
        leafTouchedByBandT(
            EntityKind.point, payload, placement, bandAt(w(3, 4), 0.5)),
        isTrue);
    expect(
        leafTouchedByBandT(
            EntityKind.point, payload, placement, bandAt(w(6, 4), 0.5)),
        isFalse);
  });

  test('a text is touched on its oriented box edges, through textBoxOf', () {
    const style = TextStyleRecord(
      handle: Handle(1),
      name: 'FAKE',
      fontFamily: 'fake',
      fixedHeight: 0,
    );
    // Payload point (0, 0), height 5 (scalars[0]); rotation, width-factor and
    // oblique overrides all default (left/baseline, textAttrs 0).
    final payload = pl([0, 0], [5]);
    const measurer = _FakeMeasurer();
    final metrics = measurer.measure(text: 'x', style: style);
    final box = textBoxOf(payload, 0, style, metrics);
    expect(box, isNotNull);
    final tb = box!;

    // The glyph box in the text's own space is x in [0, 20], y in [-2, 8]
    // (advanceWidth, -descent..ascent); textLocalTransform scales it
    // uniformly by height/capHeight = 5/7 about the anchor (0, 0), with no
    // rotation or justification offset (left/baseline). So the box, laid
    // out in the leaf's own space (before [placement] is applied), runs
    // x in [0, 100/7], y in [-10/7, 40/7].
    Vector2 leaf(double bx, double by) =>
        tb.local.transformPoint(Vector2(bx, by));
    final topRight = leaf(tb.maxX, tb.minY); // (100/7, -10/7)
    final bottomRight = leaf(tb.maxX, tb.maxY); // (100/7, 40/7)
    final rightMid = Vector2(
        (topRight.x + bottomRight.x) / 2, (topRight.y + bottomRight.y) / 2);
    final centre = leaf((tb.minX + tb.maxX) / 2, (tb.minY + tb.maxY) / 2);
    final left = Vector2(leaf(tb.minX, 0).x - 2, rightMid.y);

    expect(
        leafTouchedByBandT(EntityKind.text, payload, placement,
            bandAt(placement.transformPoint(rightMid), 1),
            textBox: tb),
        isTrue,
        reason: 'the band sits on the box\'s right edge');
    expect(
        leafTouchedByBandT(EntityKind.text, payload, placement,
            bandAt(placement.transformPoint(centre), 1),
            textBox: tb),
        isFalse,
        reason: 'well inside the box, far from every edge');
    expect(
        leafTouchedByBandT(EntityKind.text, payload, placement,
            bandAt(placement.transformPoint(left), 1),
            textBox: tb),
        isFalse,
        reason: 'left of the box entirely');
  });

  test('boxEnclosedByBand is inclusive on the edge and false when straddling',
      () {
    final box = Aabb2.raw(0, 0, 10, 10);
    expect(boxEnclosedByBand(box, Aabb2.raw(0, 0, 10, 10)), isTrue,
        reason: 'a box exactly meeting the band is fully enclosed');
    expect(boxEnclosedByBand(box, Aabb2.raw(5, 5, 15, 15)), isFalse,
        reason: 'the band only covers the box\'s upper-right quadrant');
  });
}
