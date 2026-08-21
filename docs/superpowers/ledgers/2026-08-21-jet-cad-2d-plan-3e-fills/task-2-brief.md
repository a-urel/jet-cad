## Task 2: The triangulator

**Files:**
- Create: `packages/jet_cad_2d/lib/src/geometry/triangulate.dart`
- Create: `packages/jet_cad_2d/test/geometry/triangulate_test.dart`
- Modify: `packages/jet_cad_2d/lib/jet_cad_2d.dart` (export)

**Interfaces:**
- Produces: `Int32List triangulateSimplePolygon(Float64List coords, int count)` — returns triple-indices into `coords`, counter-clockwise, or an **empty** `Int32List` when the loop cannot be reduced. Never throws.

**Contract.** `count` is the polyline's stored point count *including* the duplicated closing point, exactly as the store holds it. The function ignores the last point. It requires at least 3 distinct points after that; anything less returns empty.

- [ ] **Step 1: Write the failing tests**

`packages/jet_cad_2d/test/geometry/triangulate_test.dart`:

```dart
import 'dart:typed_data';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

/// A closed loop in store form: first point repeated as the last.
Float64List loop(List<double> xy) => Float64List.fromList([...xy, xy[0], xy[1]]);

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
}
```

- [ ] **Step 2: Run and watch it fail**

Run: `cd packages/jet_cad_2d && dart test test/geometry/triangulate_test.dart`
Expected: FAIL — `triangulateSimplePolygon` is not defined.

- [ ] **Step 3: Implement**

`packages/jet_cad_2d/lib/src/geometry/triangulate.dart`:

```dart
import 'dart:typed_data';

/// Triangulates one simple closed loop by ear clipping.
///
/// [coords] is the boundary's stored `coords` -- interleaved x, y, with the
/// first point repeated as the last, which is how this model records
/// closedness. [count] is the stored point count including that duplicate; the
/// last point is ignored.
///
/// Returns triple-indices into [coords]' point numbering, every triangle wound
/// counter-clockwise whatever the input winding. Returns an **empty** list --
/// never throws, never guesses -- when the loop has fewer than three distinct
/// points, is degenerate, or cannot be reduced, which is what a
/// self-intersecting loop looks like from inside the clipper.
///
/// O(n^2). Room boundaries are tens of points, and this runs once per edit,
/// off the frame path -- see the plan's global constraints.
Int32List triangulateSimplePolygon(Float64List coords, int count) {
  final n = count - 1; // drop the duplicated closing point
  if (n < 3) return Int32List(0);

  final index = List<int>.generate(n, (i) => i);
  if (_signedArea(coords, index) < 0) {
    // Normalised, not rejected: DXF produces both windings, and every ear test
    // below assumes counter-clockwise.
    index.setAll(0, index.reversed.toList());
  }

  final out = <int>[];
  var guard = n * n; // the clipper must strictly shrink; this bounds a stall
  while (index.length > 3 && guard-- > 0) {
    var clipped = false;
    for (var i = 0; i < index.length; i++) {
      final a = index[(i - 1 + index.length) % index.length];
      final b = index[i];
      final c = index[(i + 1) % index.length];
      if (!_isEar(coords, index, a, b, c)) continue;
      out..add(a)..add(b)..add(c);
      index.removeAt(i);
      clipped = true;
      break;
    }
    // No ear anywhere means the loop is not simple. Say so by returning
    // nothing rather than emitting a partial cover that looks like a drawing.
    if (!clipped) return Int32List(0);
  }
  if (index.length != 3) return Int32List(0);
  out..add(index[0])..add(index[1])..add(index[2]);
  return Int32List.fromList(out);
}

double _signedArea(Float64List c, List<int> index) {
  var sum = 0.0;
  for (var i = 0; i < index.length; i++) {
    final p = index[i], q = index[(i + 1) % index.length];
    sum += c[p * 2] * c[q * 2 + 1] - c[q * 2] * c[p * 2 + 1];
  }
  return sum / 2;
}

double _cross(Float64List c, int a, int b, int d) =>
    (c[b * 2] - c[a * 2]) * (c[d * 2 + 1] - c[a * 2 + 1]) -
    (c[b * 2 + 1] - c[a * 2 + 1]) * (c[d * 2] - c[a * 2]);

bool _isEar(Float64List c, List<int> index, int a, int b, int d) {
  final area = _cross(c, a, b, d);
  // Reflex or collinear: not an ear. `<= 0` rather than `< 0` so a collinear
  // run is skipped here and clipped from one of its neighbours instead, which
  // is why the collinear fixture does not stall.
  if (area <= 0) return false;
  for (final p in index) {
    if (p == a || p == b || p == d) continue;
    if (_cross(c, a, b, p) >= 0 &&
        _cross(c, b, d, p) >= 0 &&
        _cross(c, d, a, p) >= 0) {
      return false;
    }
  }
  return true;
}
```

Export it from `packages/jet_cad_2d/lib/jet_cad_2d.dart` beside the other
`src/geometry/` exports.

- [ ] **Step 4: Run and watch it pass**

Run: `cd packages/jet_cad_2d && dart test test/geometry/triangulate_test.dart`
Expected: PASS, six tests.

- [ ] **Step 5: Run the named mutations**

```sh
cd packages/jet_cad_2d
F=lib/src/geometry/triangulate.dart
cp "$F" /tmp/t2.dart
trap 'cp /tmp/t2.dart "$F"' EXIT
run() { dart test test/geometry/triangulate_test.dart >/dev/null 2>&1 && echo SURVIVED || echo KILLED; }

# T2a: drop winding normalisation
perl -0pi -e 's/  if \(_signedArea\(coords, index\) < 0\) \{/  if (false) {/' "$F"; run; cp /tmp/t2.dart "$F"
# T2b: emit a fan instead of clipping ears
perl -0pi -e 's/    if \(!_isEar\(coords, index, a, b, c\)\) continue;/    if (false) continue;/' "$F"; run; cp /tmp/t2.dart "$F"
# T2c: return a partial cover instead of nothing when no ear is found
perl -0pi -e 's/    if \(!clipped\) return Int32List\(0\);/    if (!clipped) break;/' "$F"; run; cp /tmp/t2.dart "$F"
# T2d: accept reflex vertices as ears
perl -0pi -e 's/  if \(area <= 0\) return false;/  if (area == 0) return false;/' "$F"; run; cp /tmp/t2.dart "$F"
```

All four must print `KILLED`. **T2a is killed only by the clockwise fixture** — if it survives, the fixture set is degenerate and the task is not done.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d/lib/src/geometry/triangulate.dart \
        packages/jet_cad_2d/lib/jet_cad_2d.dart \
        packages/jet_cad_2d/test/geometry/triangulate_test.dart
git commit -m "feat: ear-clipping triangulator for simple closed loops"
```

---

