### Task 8: The shared shape helpers (K6)

**Files:**
- Create: `lib/src/authoring/shapes.dart`
- Modify: `lib/authoring.dart` (one export)
- Test: `test/authoring/shapes_test.dart`

**Interfaces:**
- Consumes: `CatalogPoint`, `CatalogShape`, `CatalogLine`, `CatalogPolyline`, `CatalogCircle` (Task 7).
- Produces (exported from `package:jet_cad_2d_kit/authoring.dart`): `const double chairSize = 450`, `chairTuck = 100`, `stoolRadius = 190`, `stoolTuck = 40`; `double cleanCoordinate(double v)`; `CatalogShape rect(double x, double y, double w, double h)`; `CatalogShape inset(double x, double y, double w, double h, double d)`; `CatalogShape poly(List<CatalogPoint> points)`; `List<CatalogShape> chairAt(double cx, double cy, double facing)`; `List<CatalogShape> chairsAround(double cx, double cy, double r, int count)`; `List<CatalogShape> stoolAt(double cx, double cy)`; `List<CatalogShape> stoolsAround(double cx, double cy, double r, int count)`.

Plan decision: every helper cleans every coordinate it returns (K6: "the cleaning of every coordinate"), `rect`, `inset` and `poly` included, which today's `shapes.dart` does not clean; for whole-millimetre inputs the result is unchanged. `cleanCoordinate` is public, so a kit author's own shapes can clean the same way.
Plan decision: `inset` takes the outline's corner, `inset(x, y, w, h, d)`, as the restaurant package's does; the furniture catalog's private `_inset(w, h, d)` is `inset(0, 0, w, h, d)`.

The helpers are ported from `packages/jet_cad_restaurant_symbols/lib/src/shapes.dart` (`FurnitureShape` → `CatalogShape`); their tests port the geometry rules of that package's RL11, RL16 and RL18 onto off-origin centres at non-axis angles.

- [ ] **Step 1: Write the failing test.** Create `test/authoring/shapes_test.dart`:

```dart
// Spec K6: the shared shape helpers. Every fixture is off the origin and,
// where a direction matters, at a non-axis angle; the cleaning test is the
// one place a coordinate lands on zero, because that is where rotation dust
// shows.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/authoring.dart';

List<CatalogPoint> pointsOf(CatalogShape s) => (s as CatalogPolyline).points;

/// The centroid of a chair's seat (four distinct corners).
(double, double) centreOf(CatalogShape seat) {
  final p = pointsOf(seat);
  return (
    p.fold(0.0, (a, q) => a + q.$1) / p.length,
    p.fold(0.0, (a, q) => a + q.$2) / p.length,
  );
}

(double, double) midOf(CatalogShape line) {
  final l = line as CatalogLine;
  return ((l.from.$1 + l.to.$1) / 2, (l.from.$2 + l.to.$2) / 2);
}

double dist((double, double) a, (double, double) b) =>
    math.sqrt(math.pow(a.$1 - b.$1, 2) + math.pow(a.$2 - b.$2, 2));

Iterable<double> coordinatesOf(List<CatalogShape> shapes) sync* {
  for (final s in shapes) {
    switch (s) {
      case CatalogLine(:final from, :final to):
        yield* [from.$1, from.$2, to.$1, to.$2];
      case CatalogPolyline(:final points):
        for (final p in points) {
          yield* [p.$1, p.$2];
        }
      case CatalogCircle(:final center):
        yield* [center.$1, center.$2];
      case CatalogArc(:final center):
        yield* [center.$1, center.$2];
    }
  }
}

void main() {
  test("H1 today's constants", () {
    expect(chairSize, 450);
    expect(chairTuck, 100);
    expect(stoolRadius, 190);
    expect(stoolTuck, 40);
  });

  test('H2 rect and inset are closed, off the origin', () {
    final r = rect(1200, -350, 800, 600) as CatalogPolyline;
    expect(r.closed, isTrue);
    // M-H2: swap w and h.
    expect(r.points, [(1200, -350), (2000, -350), (2000, 250), (1200, 250)]);
    expect(pointsOf(inset(1200, -350, 800, 600, 50)),
        [(1250, -300), (1950, -300), (1950, 200), (1250, 200)]);
    final p = poly([(10, 20), (30, 25), (15, 60)]) as CatalogPolyline;
    expect(p.closed, isTrue);
    expect(p.points, [(10, 20), (30, 25), (15, 60)]);
  });

  test('H3 a chair: a 450 square on its centre, the back 165 away from the '
      'table', () {
    const facing = 0.7;
    final chair = chairAt(2500, 1300, facing);
    expect(chair, hasLength(2));
    final (cx, cy) = centreOf(chair[0]);
    expect(cx, closeTo(2500, 1e-5));
    expect(cy, closeTo(1300, 1e-5));
    for (final corner in pointsOf(chair[0])) {
      expect(dist(corner, (2500, 1300)), closeTo(225 * math.sqrt2, 1e-5));
    }
    final back = chair[1] as CatalogLine;
    expect(dist(back.from, back.to), closeTo(450, 1e-5));
    final mid = midOf(back);
    // M-H3a: `_chairBack = 70` puts the back 155 from the centre.
    expect(dist(mid, (2500, 1300)), closeTo(165, 1e-5));
    // M-H3b: the back on the table's side (u = +h - 60): the dot is +1.
    final out = ((mid.$1 - 2500) / 165, (mid.$2 - 1300) / 165);
    expect(out.$1 * math.cos(facing) + out.$2 * math.sin(facing),
        closeTo(-1, 1e-6));
  });

  test('H4 chairs around a round top: the first straight below, each tucked '
      '100, each facing the top', () {
    const top = (3000.0, 2000.0);
    final shapes = chairsAround(top.$1, top.$2, 400, 5);
    expect(shapes, hasLength(10));
    final first = centreOf(shapes[0]);
    // M-H4a: start at angle 0 instead of -pi/2.
    expect(first.$1, closeTo(3000, 1e-6));
    expect(first.$2, lessThan(2000));
    for (var i = 0; i < 5; i++) {
      final c = centreOf(shapes[2 * i]);
      // M-H4b: `r + chairSize / 2 + chairTuck` puts them at 725.
      expect(dist(c, top), closeTo(400 + 225 - 100, 1e-5), reason: 'chair $i');
      // M-H4c: facing `a` instead of `a + pi`: the back is at 360, not 690.
      expect(dist(midOf(shapes[2 * i + 1]), top), closeTo(525 + 165, 1e-5),
          reason: 'chair $i');
    }
  });

  test('H5 a stool: the seat, then the footrest, on one centre', () {
    final stool = stoolAt(-700, 820);
    // M-H5: the footrest first.
    expect([for (final s in stool) (s as CatalogCircle).radius], [190, 150]);
    for (final s in stool) {
      expect((s as CatalogCircle).center, (-700, 820));
    }
  });

  test('H6 stools around a round top reach 40 under it, the first below', () {
    final shapes = stoolsAround(1000, 600, 300, 3);
    expect(shapes, hasLength(6));
    final centres = [for (var i = 0; i < 6; i += 2) (shapes[i] as CatalogCircle).center];
    expect(centres.first.$1, closeTo(1000, 1e-6));
    expect(centres.first.$2, closeTo(150, 1e-6));
    for (final c in centres) {
      // M-H6: `+ stoolTuck` puts them at 530.
      expect(dist(c, (1000, 600)), closeTo(300 + 190 - 40, 1e-5));
    }
  });

  test('H7 every coordinate is cleaned to 1e-6, and no zero is negative', () {
    // At (225, 225) facing +y, a corner's y is 225 - 225 plus the dust of
    // cos(pi/2) = 6e-17 times 225: -1.4e-14 before cleaning, 0 after.
    final shapes = chairAt(225, 225, math.pi / 2);
    final all = coordinatesOf(shapes).toList();
    // M-H7a: drop the cleaning; the dust survives.
    expect(all, contains(0.0));
    for (final c in all) {
      expect(c, cleanCoordinate(c));
      // M-H7b: return `r` without the `r == 0` fix; -0.0 survives.
      expect(c == 0 && c.isNegative, isFalse, reason: '$c');
    }
    // M-H7c: rect does not clean; 0.30000000000000004 survives.
    expect(pointsOf(rect(0.1, 0.2, 0.2, 0.1)),
        [(0.1, 0.2), (0.3, 0.2), (0.3, 0.3), (0.1, 0.3)]);
  });

  test('H8 cleanCoordinate', () {
    expect(cleanCoordinate(1.0000004), 1.0);
    expect(cleanCoordinate(1.0000006), 1.000001);
    expect(cleanCoordinate(2.5), 2.5);
    expect(cleanCoordinate(-1e-9), 0.0);
    expect(cleanCoordinate(-1e-9).isNegative, isFalse);
  });
}
```

- [ ] **Step 2: Run it to see it fail.** Run: `cd packages/jet_cad_2d_kit && flutter test test/authoring/shapes_test.dart`. Expected: compilation errors (`Undefined name 'chairSize'`).

- [ ] **Step 3: The helpers.** Create `lib/src/authoring/shapes.dart`:

```dart
// The shared shape helpers (spec K6): the chair, chairs around a round top,
// the stool, rectangles, as today's furniture and restaurant catalogs copy
// them. Ported from jet_cad_restaurant_symbols' shapes.dart. A helper is a
// convenience for kit authors, not the runtime contract: changing one never
// changes a published key@N (K7 holds every kit to its committed geometry).
//
// Pure Dart: no Flutter, no dart:io.
import 'dart:math' as math;

import 'catalog.dart';

/// A chair's side, in millimetres.
const double chairSize = 450;

/// How deep a chair sits under its table's edge.
const double chairTuck = 100;

/// A bar stool's seat radius (Ø 380).
const double stoolRadius = 190;

/// How far a stool's seat reaches under its top's edge.
const double stoolTuck = 40;

/// The back line's distance in from a chair's outer edge.
const double _chairBack = 60;

/// A bar stool's footrest ring radius (Ø 300).
const double _footrestRadius = 150;

/// [v] rounded to 1e-6 mm, with -0 made 0: the dust of a rotation (1e-13
/// off a whole millimetre) never reaches a library. A sub-micrometre value
/// is never meaningful in a symbol.
double cleanCoordinate(double v) {
  final r = (v * 1e6).roundToDouble() / 1e6;
  return r == 0 ? 0 : r;
}

CatalogPoint _p(double x, double y) => (cleanCoordinate(x), cleanCoordinate(y));

/// A closed axis-aligned rectangle from ([x], [y]), [w] wide and [h] tall.
CatalogShape rect(double x, double y, double w, double h) => CatalogPolyline(
    [_p(x, y), _p(x + w, y), _p(x + w, y + h), _p(x, y + h)],
    closed: true);

/// [rect] of a [w] x [h] outline at ([x], [y]), inset by [d] on every side.
CatalogShape inset(double x, double y, double w, double h, double d) =>
    rect(x + d, y + d, w - 2 * d, h - 2 * d);

/// A closed polyline through [points].
CatalogShape poly(List<CatalogPoint> points) =>
    CatalogPolyline([for (final (x, y) in points) _p(x, y)], closed: true);

/// A chair facing a table: its seat (a closed 450 x 450 square) centred at
/// ([cx], [cy]) and its back line, the table in direction [facing] (radians
/// from +x). The back line is 60 in from the edge away from the table.
List<CatalogShape> chairAt(double cx, double cy, double facing) {
  const h = chairSize / 2;
  // The chair's frame: u towards the table, v across it.
  final ux = math.cos(facing), uy = math.sin(facing);
  final vx = -uy, vy = ux;
  CatalogPoint at(double u, double v) =>
      _p(cx + u * ux + v * vx, cy + u * uy + v * vy);
  return [
    poly([at(-h, -h), at(h, -h), at(h, h), at(-h, h)]),
    CatalogLine(at(-h + _chairBack, -h), at(-h + _chairBack, h)),
  ];
}

/// The angle of the [i]th of [count] places around a round top, the first
/// straight below it.
double _around(int i, int count) => -math.pi / 2 + 2 * math.pi * i / count;

/// [count] chairs around a round top of radius [r] centred at ([cx], [cy]),
/// at equal angles from the bottom, each tucked [chairTuck] under the edge.
List<CatalogShape> chairsAround(double cx, double cy, double r, int count) {
  final d = r + chairSize / 2 - chairTuck;
  return [
    for (var i = 0; i < count; i++)
      ...chairAt(
          cleanCoordinate(cx + d * math.cos(_around(i, count))),
          cleanCoordinate(cy + d * math.sin(_around(i, count))),
          _around(i, count) + math.pi),
  ];
}

/// A bar stool at ([cx], [cy]): its seat (Ø 380), then a Ø 300 footrest.
List<CatalogShape> stoolAt(double cx, double cy) => [
      CatalogCircle(_p(cx, cy), stoolRadius),
      CatalogCircle(_p(cx, cy), _footrestRadius),
    ];

/// [count] stools around a round top of radius [r] centred at ([cx], [cy]),
/// at equal angles from the bottom, each reaching [stoolTuck] under the edge.
List<CatalogShape> stoolsAround(double cx, double cy, double r, int count) {
  final d = r + stoolRadius - stoolTuck;
  return [
    for (var i = 0; i < count; i++)
      ...stoolAt(cx + d * math.cos(_around(i, count)),
          cy + d * math.sin(_around(i, count))),
  ];
}
```

In `lib/authoring.dart`, the exports become:

```dart
export 'src/authoring/builder.dart';
export 'src/authoring/catalog.dart';
export 'src/authoring/shapes.dart';
export 'src/model/model.dart';
```

- [ ] **Step 4: Run the tests.** Run: `cd packages/jet_cad_2d_kit && flutter test test/authoring test/invariants`. Expected: `All tests passed!`.

- [ ] **Step 5: Mutation check** (on committed files; revert each with `git checkout -- <file>` and check `git diff --quiet`): M-H2 (swap `w` and `h` in `rect`) → H2 red; M-H3a (`_chairBack = 70`) → H3 red; M-H3b (`at(h - _chairBack, -h), at(h - _chairBack, h)`) → H3 red; M-H4a (`_around` returns `2 * math.pi * i / count`) → H4, H6 red; M-H4b (`r + chairSize / 2 + chairTuck`) → H4 red; M-H4c (`_around(i, count)` without `+ math.pi` as the facing) → H4 red; M-H5 (swap the two circles) → H5 red; M-H6 (`r + stoolRadius + stoolTuck`) → H6 red; M-H7a (`_p` returns `(x, y)` uncleaned) → H7 red; M-H7b (`return r;`) → H7, H8 red; M-H7c (`rect` builds its points without `_p`) → H7 red.

- [ ] **Step 6: The gate.** `cd packages/jet_cad_2d_kit && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — all exit 0.

- [ ] **Step 7: Commit.**

```bash
git add packages/jet_cad_2d_kit/lib/authoring.dart packages/jet_cad_2d_kit/lib/src/authoring/shapes.dart packages/jet_cad_2d_kit/test/authoring/shapes_test.dart
git commit -m "$(cat <<'EOF'
feat(kit): the shared shape helpers (K6)

rect, inset, poly, chairAt, chairsAround, stoolAt and stoolsAround with
today's constants, ported from the restaurant symbols as CatalogShapes.
Every coordinate they return is cleaned to 1e-6 with -0 made 0. Tests
hold the chair's back away from its table, the tuck and the first seat
straight below a round top, off the origin at non-axis angles.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---
