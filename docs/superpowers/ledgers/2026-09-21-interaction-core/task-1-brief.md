### Task 1: The branch point, and the band predicates

**Files:**
- Create: `lib/src/geometry/band_predicates.dart`
- Modify: `lib/jet_cad_2d.dart` (one export)
- Test: `test/geometry/band_predicates_test.dart`

**Interfaces:**
- Consumes: `GeometryPayload` (`coords`, `scalars`, `pointCount`), `Aabb2`,
  `clipSegment`, `circleClipWindows`, `angleInSweep`, `EntityKind`,
  `resolveTextAttributes`, `textLocalTransform`, `textLocalBounds`,
  `TextMetrics`, `TextStyleRecord`.
- Produces, for Task 2 and Task 7:

```dart
/// Some point of the stroke lies inside [band] (spec D8, crossing).
bool leafTouchedByBand(EntityKind kind, GeometryPayload payload,
    double ta, double tb, double tc, double td, double te, double tf,
    Aabb2 band, {TextBox? textBox});

/// Every point of the leaf's world AABB lies inside [band] (spec D8, window).
/// [worldBox] is `boxOfLeaf(slot) ?? dirty.boxOf(slot)` — the caller reads it.
bool boxEnclosedByBand(Aabb2 worldBox, Aabb2 band);

/// The four oriented corners of a text or attrib in the leaf's own space,
/// laid out as `_considerLeaf` does. Null when the box is degenerate.
TextBox? textBoxOf(GeometryPayload payload, int textAttrs,
    TextStyleRecord style, TextMetrics metrics);

final class TextBox { final double minX, minY, maxX, maxY; final Transform2 local; }

/// Transform2-taking wrapper for tests and the differential arm.
bool leafTouchedByBandT(EntityKind kind, GeometryPayload payload,
    Transform2 toWorld, Aabb2 band, {TextBox? textBox});
```

- [ ] **Step 1: Branch point and baselines**

```sh
git -C /Users/ahmeturel/Projects/oss/jet-cad log --oneline -1   # expect 76b5a2e or later
git rev-parse --abbrev-ref HEAD                                   # plan-02/interaction-core
cd packages/jet_cad_2d && CI=true dart test 2>&1 | tail -3        # record the count in the ledger (798 at main)
cd ../../apps/dev_harness_2d && CI=true flutter test --concurrency=1 2>&1 | tail -3   # 82
```

Write both counts into the ledger.

- [ ] **Step 2: Write the failing predicate tests**

`test/geometry/band_predicates_test.dart`. Every fixture is transformed by
a non-identity placement — `Transform2.translation(300, -200)
.multiply(Transform2.rotation(math.pi / 6)).multiply(Transform2.scale(1.5, 1.5))`
— and every band is placed in **world** space where the transformed geometry
lands. Helper:

```dart
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
```

Tests (each a `test(...)`):

1. `'a line is touched when the band crosses it and not when it sits beside it'`:
   line `[0,0, 10,0]`; band at `w(5,0)` half 1 → true; band at `w(5,3)` half 1
   → false (the band's own AABB overlaps nothing there under rotation either
   — check the assertion by computing `bandAt(w(5,3),1)`).
2. `'a band fully inside a closed polyline touches nothing'`: square
   `[0,0, 10,0, 10,10, 0,10, 0,0]`; band at `w(5,5)` half 1 → false; band at
   `w(0,5)` half 1 → true.
3. `'a circle is touched on its rim, not in its interior'`: circle `[0,0]`
   scalars `[10]`; band at `w(0,0)` half 2 → false; band at `w(10,0)` half 2
   → true; band enclosing the whole circle → true (`circleClipWindows == -1`).
4. `'an arc is touched only on its sweep'`: arc `[0,0]` scalars
   `[10, 0, math.pi/2]` (quarter, 0..90°); band at `w(10,0)` half 1 → true;
   band at `w(-10,0)` half 1 → false (the full circle would hit).
5. `'a point is touched when inside'`: point `[3,4]`; band at `w(3,4)` half
   0.5 → true; band at `w(6,4)` half 0.5 → false.
6. `'a text is touched on its oriented box edges, through textBoxOf'`: use
   `resolveTextAttributes`-driven `textBoxOf` with the `InsertionPointMeasurer`
   replaced by a fake `TextMeasurer` returning `advanceWidth 20, ascent 8,
   descent 2, capHeight 7` and a `TextStyleRecord` with `fixedHeight: 0`;
   payload `[0,0]` scalars `[5]` (height 5), rotation 0; band on the box's
   right edge → true; band well inside the box → false; band left of the
   box → false.
7. `'boxEnclosedByBand is inclusive on the edge and false when straddling'`.

Under the ×10-widen or swapped-predicate mutants of Task 2 these are the
leaf-level truth; keep the assertions tight (half-sizes of 1–2 units).

- [ ] **Step 3: Run, expect compile failure**

```sh
cd packages/jet_cad_2d && CI=true dart test test/geometry/band_predicates_test.dart
```

- [ ] **Step 4: Implement `band_predicates.dart`**

```dart
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import '../document/tables.dart' show TextStyleRecord;
import '../document/text_geometry.dart';
import '../document/text_metrics.dart';
import '../store/entity_store.dart' show EntityKind;
import '../store/geometry_store.dart';
import 'aabb2.dart';
import 'primitives.dart' show angleInSweep;
import 'segment_clip.dart';
import 'transform2.dart';

/// The oriented glyph box of a text or attrib in the leaf's own space.
final class TextBox {
  const TextBox(this.minX, this.minY, this.maxX, this.maxY, this.local);
  final double minX, minY, maxX, maxY;
  /// Box space → leaf space (`textLocalTransform`).
  final Transform2 local;
}

TextBox? textBoxOf(GeometryPayload payload, int textAttrs,
    TextStyleRecord style, TextMetrics metrics) {
  final attrs = resolveTextAttributes(payload, textAttrs, style);
  final box = textLocalBounds(attrs, metrics);
  if (box.maxX <= box.minX || box.maxY <= box.minY) return null;
  final local = textLocalTransform(attrs, metrics, payload.pointAt(0));
  return TextBox(box.minX, box.minY, box.maxX, box.maxY, local);
}

bool boxEnclosedByBand(Aabb2 worldBox, Aabb2 band) =>
    !worldBox.isEmpty &&
    worldBox.minX >= band.minX &&
    worldBox.maxX <= band.maxX &&
    worldBox.minY >= band.minY &&
    worldBox.maxY <= band.maxY;

/// Scratch for [clipSegment]'s `t` pair and [circleClipWindows]'s windows.
final Float64List _t = Float64List(2);
final Float64List _windows = Float64List(8);

bool _segmentTouches(double x0, double y0, double x1, double y1, Aabb2 band) =>
    clipSegment(x0, y0, x1, y1, band, _t);

bool leafTouchedByBand(EntityKind kind, GeometryPayload payload, double ta,
    double tb, double tc, double td, double te, double tf, Aabb2 band,
    {TextBox? textBox}) {
  final c = payload.coords;
  final n = payload.pointCount;
  if (n == 0 && kind != EntityKind.text && kind != EntityKind.attrib) {
    return false; // a fill has no coordinates and is never picked (spec D8)
  }
  switch (kind) {
    case EntityKind.point:
      final wx = ta * c[0] + tc * c[1] + te, wy = tb * c[0] + td * c[1] + tf;
      return wx >= band.minX && wx <= band.maxX && wy >= band.minY && wy <= band.maxY;
    case EntityKind.line:
    case EntityKind.polyline:
      if (n == 1) {
        final wx = ta * c[0] + tc * c[1] + te, wy = tb * c[0] + td * c[1] + tf;
        return band.containsPoint(Vector2(wx, wy));
      }
      var px = ta * c[0] + tc * c[1] + te, py = tb * c[0] + td * c[1] + tf;
      for (var i = 1; i < n; i++) {
        final lx = c[i * 2], ly = c[i * 2 + 1];
        final qx = ta * lx + tc * ly + te, qy = tb * lx + td * ly + tf;
        if (_segmentTouches(px, py, qx, qy, band)) return true;
        px = qx; py = qy;
      }
      return false;
    case EntityKind.circle:
      final cx = ta * c[0] + tc * c[1] + te, cy = tb * c[0] + td * c[1] + tf;
      final r = payload.scalars[0] * _scaleMagnitude(ta, tb, tc, td);
      return circleClipWindows(cx, cy, r, band, _windows) != 0;
    case EntityKind.arc:
      final cx = ta * c[0] + tc * c[1] + te, cy = tb * c[0] + td * c[1] + tf;
      final r = payload.scalars[0] * _scaleMagnitude(ta, tb, tc, td);
      // World start angle from the transformed start point; a mirror flips
      // the turning sense — the same rule `_considerLeaf` uses for arcs.
      final s0 = payload.scalars[1], sweep0 = payload.scalars[2];
      final lsx = c[0] + payload.scalars[0] * math.cos(s0);
      final lsy = c[1] + payload.scalars[0] * math.sin(s0);
      final wsx = ta * lsx + tc * lsy + te, wsy = tb * lsx + td * lsy + tf;
      final start = math.atan2(wsy - cy, wsx - cx);
      final sweep = (ta * td - tb * tc) < 0 ? -sweep0 : sweep0;
      final count = circleClipWindows(cx, cy, r, band, _windows);
      if (count == -1) return true;
      for (var i = 0; i < count; i++) {
        final a = _windows[i * 2], b = _windows[i * 2 + 1];
        // A window intersects the sweep when an endpoint of either lies in
        // the other, or the window contains the sweep's start.
        if (angleInSweep(a, start, sweep) ||
            angleInSweep(b, start, sweep) ||
            _angleInWindow(start, a, b)) {
          return true;
        }
      }
      return false;
    case EntityKind.text:
    case EntityKind.attrib:
      final box = textBox;
      if (box == null) return false;
      // Compose leaf→world with box→leaf, then walk the four edges.
      final l = box.local;
      final ma = ta * l.a + tc * l.b, mb = tb * l.a + td * l.b;
      final mc = ta * l.c + tc * l.d, md = tb * l.c + td * l.d;
      final me = ta * l.e + tc * l.f + te, mf = tb * l.e + td * l.f + tf;
      double xOf(double x, double y) => ma * x + mc * y + me;
      double yOf(double x, double y) => mb * x + md * y + mf;
      final xs = [box.minX, box.maxX, box.maxX, box.minX];
      final ys = [box.minY, box.minY, box.maxY, box.maxY];
      for (var i = 0; i < 4; i++) {
        final j = (i + 1) % 4;
        if (_segmentTouches(xOf(xs[i], ys[i]), yOf(xs[i], ys[i]),
            xOf(xs[j], ys[j]), yOf(xs[j], ys[j]), band)) {
          return true;
        }
      }
      return false;
    case EntityKind.fill:
      return false;
  }
}

bool _angleInWindow(double angle, double a, double b) {
  const twoPi = 2 * math.pi;
  var d = (angle - a) % twoPi;
  if (d < 0) d += twoPi;
  return d <= b - a;
}

double _scaleMagnitude(double a, double b, double c, double d) =>
    math.sqrt((a * d - b * c).abs());

bool leafTouchedByBandT(EntityKind kind, GeometryPayload payload,
        Transform2 t, Aabb2 band, {TextBox? textBox}) =>
    leafTouchedByBand(kind, payload, t.a, t.b, t.c, t.d, t.e, t.f, band,
        textBox: textBox);
```

(`import 'dart:math' as math;` at the top.) The four `List<double>`s in the
text branch allocate; that branch runs at pointer-up rate, which the spec
allows. If `flutter analyze` on the flutter package later flags the
`hide Aabb2` import as unused here, drop the `hide`.

Add to `lib/jet_cad_2d.dart`: `export 'src/geometry/band_predicates.dart';`.

- [ ] **Step 5: Run the tests, then the package gate line**

```sh
cd packages/jet_cad_2d && CI=true dart test test/geometry/band_predicates_test.dart
CI=true dart test && dart analyze && dart format --output=none --set-exit-if-changed .
```

- [ ] **Step 6: Commit**

```sh
git add lib/src/geometry/band_predicates.dart lib/jet_cad_2d.dart test/geometry/band_predicates_test.dart
git commit -m "feat(geometry): band predicates, exact per entity kind"
```

---

