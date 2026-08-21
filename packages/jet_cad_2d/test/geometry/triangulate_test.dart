import 'dart:typed_data';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

/// A closed loop in store form: first point repeated as the last.
Float64List loop(List<double> xy) =>
    Float64List.fromList([...xy, xy[0], xy[1]]);

/// Twice the signed area of the triangle, so orientation is readable.
double cross(Float64List c, int a, int b, int d) =>
    (c[b * 2] - c[a * 2]) * (c[d * 2 + 1] - c[a * 2 + 1]) -
    (c[b * 2 + 1] - c[a * 2 + 1]) * (c[d * 2] - c[a * 2]);

double areaOf(Float64List c, Int32List t) {
  var sum = 0.0;
  for (var i = 0; i < t.length; i += 3) {
    sum += cross(c, t[i], t[i + 1], t[i + 2]).abs() / 2;
  }
  return sum;
}

void main() {
  test('a square yields two triangles covering its whole area', () {
    final c = loop([0, 0, 10, 0, 10, 10, 0, 10]);
    final t = triangulateSimplePolygon(c, c.length ~/ 2);
    expect(t.length, 6);
    expect(areaOf(c, t), closeTo(100.0, 1e-9));
  });

  test('an L-shape is triangulated, and the concave vertex is not an ear', () {
    // The product case. A fan from any vertex would leave the notch filled.
    final c = loop([0, 0, 20, 0, 20, 10, 10, 10, 10, 20, 0, 20]);
    final t = triangulateSimplePolygon(c, c.length ~/ 2);
    expect(t.length, 12, reason: 'six vertices reduce to four triangles');
    expect(areaOf(c, t), closeTo(300.0, 1e-9),
        reason: 'an L of 20x10 plus 10x10 is 300, not the 400 a naive fan '
            'across the notch would produce');
  });

  test('a clockwise loop is normalised, not rejected', () {
    // The degenerate fixture this repo keeps shipping: every fixture wound the
    // same way. DXF produces both windings.
    final ccw = loop([0, 0, 10, 0, 10, 10, 0, 10]);
    final cw = loop([0, 0, 0, 10, 10, 10, 10, 0]);
    final a = triangulateSimplePolygon(ccw, ccw.length ~/ 2);
    final b = triangulateSimplePolygon(cw, cw.length ~/ 2);
    expect(b.length, a.length);
    expect(areaOf(cw, b), closeTo(100.0, 1e-9));
    for (var i = 0; i < b.length; i += 3) {
      expect(cross(cw, b[i], b[i + 1], b[i + 2]), greaterThan(0),
          reason: 'every emitted triangle must be counter-clockwise whatever '
              'the input winding');
    }
  });

  test('collinear runs do not stall the clipper', () {
    final c = loop([0, 0, 5, 0, 10, 0, 10, 10, 0, 10]);
    final t = triangulateSimplePolygon(c, c.length ~/ 2);
    expect(areaOf(c, t), closeTo(100.0, 1e-9));
  });

  test('a self-intersecting loop returns empty rather than guessing', () {
    final c = loop([0, 0, 10, 10, 10, 0, 0, 10]); // a bow tie
    expect(triangulateSimplePolygon(c, c.length ~/ 2), isEmpty);
  });

  test('fewer than three distinct points returns empty', () {
    final c = loop([0, 0, 10, 0]);
    expect(triangulateSimplePolygon(c, c.length ~/ 2), isEmpty);
  });

  test('a loop that pinches itself at a shared vertex returns empty', () {
    // Two triangles joined at one point, stored as two distinct points at the
    // same coordinate -- self-touching, not a proper edge crossing. No edge
    // pair intersects, so this cannot be rejected by a crossing test; it can
    // only be caught by the clipper genuinely finding no ear anywhere.
    final c = loop([0, 0, 4, 0, 2, 2, 0, 4, 4, 4, 2, 2]);
    expect(triangulateSimplePolygon(c, c.length ~/ 2), isEmpty);
  });

  test(
      'a consecutive duplicate point right after the first vertex is '
      'tolerated, not rejected', () {
    // A 10x10 square with (10,0) stored twice in a row -- a plausible
    // snap-rounding artefact from a DXF import. The duplicate is not the
    // store's closing duplicate (that is the separate first-equals-last
    // convention, already stripped by count - 1); it is a second, genuinely
    // stored point sitting on top of its neighbour, elsewhere in the ring.
    final c = loop([0, 0, 10, 0, 10, 0, 10, 10, 0, 10]);
    final t = triangulateSimplePolygon(c, c.length ~/ 2);
    expect(t, isNotEmpty);
    expect(areaOf(c, t), closeTo(100.0, 1e-9));
  });

  test(
      'a consecutive duplicate point mid-ring is tolerated too, not just '
      'right after the first vertex', () {
    // Same square, but the doubled point is the third vertex, not the
    // second -- so a fix that only checks index 0/1 cannot pass this.
    final c = loop([0, 0, 10, 0, 10, 10, 10, 10, 0, 10]);
    final t = triangulateSimplePolygon(c, c.length ~/ 2);
    expect(t, isNotEmpty);
    expect(areaOf(c, t), closeTo(100.0, 1e-9));
  });
}
