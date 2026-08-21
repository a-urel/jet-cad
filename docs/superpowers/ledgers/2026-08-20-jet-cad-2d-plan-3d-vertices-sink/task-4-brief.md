### Task 4: Joins — one walk, miter and bevel

Every segment is an independent quad today, so a polyline's corners have a
notch on the outside. This closes it, once, for both walks.

**A miter is two triangles.** The notch at a vertex is the quadrilateral
`(V, A, M, B)`: the vertex, the outer corner of the incoming segment, the miter
point, and the outer corner of the outgoing one. Filling it takes the **bevel
triangle `(V, A, B)`** and the **tip triangle `(A, M, B)`**. The tip alone
leaves a hairline crack along `AB` at every mitred corner — invisible to a test
that counts triangles, obvious in a golden at a visible lineweight.

**The run state lives in fields, not in an object.** A `_StrokeRun` allocated
per polyline would put an allocation back on the frame path, which Task 3 has
just finished measuring.

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart`
- Create: `packages/jet_cad_2d_flutter/test/vertices_join_test.dart`

**Interfaces:**
- Consumes: `_emitSegment` from the spike.
- Produces: `VerticesDrawSink.kMiterLimit`, `VerticesDrawSink.kMinMiterCosine`.
  Task 5 consumes `_beginRun` / `_runTo` / `_endRun`.

- [ ] **Step 1: Write the failing test**

`packages/jet_cad_2d_flutter/test/vertices_join_test.dart`:

```dart
// Joins. Every case here is at a lineweight where the corner is several pixels
// across, because a join is invisible at a hairline and most of a CAD drawing
// is hairlines — a fixture at the shipped corpus's widths would pass with the
// join code deleted.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/vertices_draw_sink.dart';

/// 1.0 mm at 4 px/mm is 4 logical pixels, so the half-width is 2 and every
/// expected coordinate below is exact in binary.
const _lw = 100;
const _pxPerMm = 4.0;
const _half = 2.0;

ResolvedStyle _style({int argb = 0xFF000000}) => ResolvedStyle(
      argb: argb,
      lineweightHundredths: _lw,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
    );

VerticesDrawSink _sink() => VerticesDrawSink(pixelsPerPaperMm: _pxPerMm);

Float64List _pts(List<double> xy) => Float64List.fromList(xy);

int _triangleCount(VerticesDrawSink s) => s.debugPositions().length ~/ 6;

/// Whether any emitted triangle contains the point.
bool _inked(VerticesDrawSink s, double px, double py) {
  final v = s.debugPositions();
  for (var i = 0; i + 5 < v.length ~/ 2; i += 3) {
    final ax = v[i * 2], ay = v[i * 2 + 1];
    final bx = v[i * 2 + 2], by = v[i * 2 + 3];
    final cx = v[i * 2 + 4], cy = v[i * 2 + 5];
    double edge(double x0, double y0, double x1, double y1) =>
        (x1 - x0) * (py - y0) - (y1 - y0) * (px - x0);
    final d1 = edge(ax, ay, bx, by);
    final d2 = edge(bx, by, cx, cy);
    final d3 = edge(cx, cy, ax, ay);
    const eps = 1e-2;
    final neg = d1 < -eps || d2 < -eps || d3 < -eps;
    final pos = d1 > eps || d2 > eps || d3 > eps;
    if (!(neg && pos)) return true;
  }
  return false;
}

void main() {
  test('the miter limit and its cosine are Impellers own', () {
    // painting.dart:1535 and stroke_path_geometry.cc:442. Written down as a
    // test so a change to either constant is a red test rather than a drawing
    // that quietly stops matching CanvasDrawSink.
    expect(VerticesDrawSink.kMiterLimit, 4.0);
    expect(VerticesDrawSink.kMinMiterCosine, closeTo(-0.875, 1e-12));
  });

  test('a right-angle corner is mitred out to the square corner', () {
    // P(0,0) -> V(10,0) -> Q(10,10) turns left, so the outer side is the right
    // one and the miter point is the outer corner of the square: (12, -2).
    //
    // MUTATION: take the miter on the inside of the turn and this reads (8, 2).
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..polyline(_pts([0, 0, 10, 0, 10, 10]), 3, _style(), closed: false)
      ..endResidual();

    expect(_inked(sink, 11.5, -1.5), isTrue, reason: 'the miter tip');
    expect(_inked(sink, 8.0, 2.0), isFalse, reason: 'the inside of the turn');
  });

  test('a mitred corner emits both the bevel and the tip triangle', () {
    // MUTATION: emit the tip triangle alone and the point just inside the
    // bevel wedge -- between the vertex and the chord AB -- goes uninked.
    // That is the hairline crack.
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..polyline(_pts([0, 0, 10, 0, 10, 10]), 3, _style(), closed: false)
      ..endResidual();

    // Two segments are 4 triangles; the join adds 2.
    expect(_triangleCount(sink), 6);
    // A = (10, -2), B = (12, 0), V = (10, 0). The wedge's centroid.
    expect(_inked(sink, 10.6, -0.6), isTrue, reason: 'the bevel wedge');
  });

  test('a corner past the miter limit is bevelled, one triangle', () {
    // A 170-degree direction change: dot = cos(170 deg) = -0.985, below
    // -0.875.
    //
    // MUTATION: miter every corner and this reads 6 triangles and a spike
    // reaching about 23 units out.
    const a = 170 * math.pi / 180;
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..polyline(
          _pts([0, 0, 10, 0, 10 + 10 * math.cos(a), 10 * math.sin(a)]), 3,
          _style(),
          closed: false)
      ..endResidual();

    expect(_triangleCount(sink), 5, reason: '4 for the segments, 1 bevel');
  });

  test('a corner just inside the limit is still mitred', () {
    // 150 degrees: dot = -0.866, above -0.875. The boundary is a real edge and
    // both sides of it are pinned.
    //
    // MUTATION: bevel every corner and this reads 5.
    const a = 150 * math.pi / 180;
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..polyline(
          _pts([0, 0, 10, 0, 10 + 10 * math.cos(a), 10 * math.sin(a)]), 3,
          _style(),
          closed: false)
      ..endResidual();

    expect(_triangleCount(sink), 6);
  });

  test('an open polyline gets no join between its ends', () {
    // MUTATION: join the first and last segment of an open run and this reads
    // 8 -- the L gets a phantom corner at the origin.
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..polyline(_pts([0, 0, 10, 0, 10, 10]), 3, _style(), closed: false)
      ..endResidual();
    expect(_triangleCount(sink), 6);
  });

  test('a zero-length step is skipped and the join spans it', () {
    // A repeated point carries no direction. Skipping it must not also skip
    // the corner it sits on.
    //
    // MUTATION: return early from the whole run on a zero-length step and the
    // second segment and its join both vanish.
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..polyline(_pts([0, 0, 10, 0, 10, 0, 10, 10]), 4, _style(), closed: false)
      ..endResidual();
    expect(_triangleCount(sink), 6);
    expect(_inked(sink, 11.5, -1.5), isTrue, reason: 'the miter still fires');
  });

  test('joins are emitted under the residual, not in local space', () {
    // Degenerate-fixture guard: every case above is at the identity, and a
    // join computed before the transform would pass all of them.
    //
    // MUTATION: compute the join from local-space directions and the miter
    // lands at (2, 12) instead.
    const t = Transform2(0, 1, -1, 0, 0, 0); // quarter turn
    final sink = _sink()
      ..beginResidual(t)
      ..polyline(_pts([0, 0, 10, 0, 10, 10]), 3, _style(), closed: false)
      ..endResidual();
    // (12, -2) rotated a quarter turn is (2, 12).
    expect(_inked(sink, 1.5, 11.5), isTrue);
  });

  test('a flattened curve joins its chords', () {
    // MUTATION: skip the join between two chords and a thick arc shows a notch
    // at every one of them. Sampled just outside the chord and inside the
    // stroke, at the arc's midpoint.
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..arc(0, 0, 40, 0, math.pi / 2, _style())
      ..endResidual();

    // The outer edge of the stroke at 45 degrees is at radius 42, and the
    // chord there falls short of it by the sag. Without joins that sliver is
    // uninked.
    final r = 40 + _half - 0.15;
    expect(_inked(sink, r * math.cos(math.pi / 4), r * math.sin(math.pi / 4)),
        isTrue);
  });
}
```

- [ ] **Step 2: Run the test and watch it fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/vertices_join_test.dart
```

Expected: `kMiterLimit` undefined, and the triangle-count assertions read 4
where they expect 6 — no joins exist yet.

- [ ] **Step 3: Add the constants**

In `vertices_draw_sink.dart`, beside `kMinStrokeDevicePixels`:

```dart
  /// Flutter's default miter limit (`painting.dart:1535`).
  static const double kMiterLimit = 4.0;

  /// The cosine of the direction change at which a miter becomes a bevel.
  ///
  /// Impeller's own conversion of the limit: `2 * (1 / limit)^2 - 1`
  /// (`stroke_path_geometry.cc:442`). At a limit of 4 that is -0.875, so a
  /// corner is mitred up to about a 151-degree turn and bevelled past it.
  static const double kMinMiterCosine =
      2.0 * (1.0 / kMiterLimit) * (1.0 / kMiterLimit) - 1.0;
```

- [ ] **Step 4: Add the run state and the shared walk**

Fields, beside the buffers:

```dart
  // Run state. Fields and not a per-run object, because a `_StrokeRun`
  // allocated per polyline would put an allocation back on the frame path
  // that `paint_allocation_test.dart` has just finished pinning at zero.
  double _runFirstX = 0, _runFirstY = 0;
  double _runFirstDx = 0, _runFirstDy = 0;
  double _runPrevX = 0, _runPrevY = 0;
  double _runPrevDx = 0, _runPrevDy = 0;
  bool _runHasDirection = false;
  int _runSegments = 0;
```

Methods:

```dart
  /// Starts a connected run at a device-space point.
  void _beginRun(double x, double y) {
    _runFirstX = x;
    _runFirstY = y;
    _runPrevX = x;
    _runPrevY = y;
    _runHasDirection = false;
    _runSegments = 0;
  }

  /// Extends the run to a device-space point, emitting the join first.
  ///
  /// The join comes before the segment so the buffer's order is the drawing's
  /// order: at a corner the ink nearer the start of the run is written first.
  void _runTo(double x, double y, double half, int argb) {
    final dx = x - _runPrevX, dy = y - _runPrevY;
    final length = math.sqrt(dx * dx + dy * dy);
    // A repeated point carries no direction. Skip the step, keep the previous
    // direction, and let the join span it — the corner is still there.
    if (length == 0) return;
    final ux = dx / length, uy = dy / length;

    if (_runHasDirection) {
      _emitJoin(_runPrevX, _runPrevY, _runPrevDx, _runPrevDy, ux, uy, half,
          argb);
    } else {
      _runFirstDx = ux;
      _runFirstDy = uy;
    }
    _emitQuad(_runPrevX, _runPrevY, x, y, ux, uy, half, argb);

    _runPrevX = x;
    _runPrevY = y;
    _runPrevDx = ux;
    _runPrevDy = uy;
    _runHasDirection = true;
    _runSegments++;
  }

  /// Ends the run.
  ///
  /// An open run gets butt caps, which is to say nothing at all. The closed
  /// case — a closing segment and a seam join — is Task 5; it asserts here so
  /// a caller that reaches it before then fails loudly rather than silently
  /// dropping the closing segment the spike used to emit.
  void _endRun({required bool closed, required double half, required int argb}) {
    assert(!closed, 'closed runs arrive in Task 5');
  }
```

- [ ] **Step 5: Add the join itself**

```dart
  /// Fills the notch at a vertex between two unit directions.
  ///
  /// The notch is the quadrilateral `(V, A, M, B)` — vertex, outer corner of
  /// the incoming segment, miter point, outer corner of the outgoing one — so
  /// a miter is **two** triangles: the bevel `(V, A, B)` and the tip
  /// `(A, M, B)`. The tip alone leaves a hairline crack along `AB`.
  void _emitJoin(double vx, double vy, double d0x, double d0y, double d1x,
      double d1y, double half, int argb) {
    final cross = d0x * d1y - d0y * d1x;
    // Collinear: either straight through, where the quads already meet, or a
    // reversal, where both the miter and the bevel are degenerate.
    if (cross == 0) return;

    // The outer side of the turn is the one away from it: a left turn
    // (cross > 0) opens a notch on the right.
    final s = cross > 0 ? -half : half;
    final n0x = -d0y * s, n0y = d0x * s;
    final n1x = -d1y * s, n1y = d1x * s;
    final ax = vx + n0x, ay = vy + n0y;
    final bx = vx + n1x, by = vy + n1y;

    _emitTriangle(vx, vy, ax, ay, bx, by, argb);

    if (d0x * d1x + d0y * d1y < kMinMiterCosine) return;

    var mx = n0x + n1x, my = n0y + n1y;
    final mlen = math.sqrt(mx * mx + my * my);
    if (mlen == 0) return;
    mx /= mlen;
    my /= mlen;
    // `n0` has length `half`, so this is the cosine of half the included angle.
    final cosHalf = (mx * n0x + my * n0y) / half;
    if (cosHalf <= 0) return;
    final reach = half / cosHalf;
    _emitTriangle(ax, ay, vx + mx * reach, vy + my * reach, bx, by, argb);
  }

  /// Writes one triangle, six floats and three colours.
  void _emitTriangle(double ax, double ay, double bx, double by, double cx,
      double cy, int argb) {
    _reserve(3);
    final v = _positions;
    var i = _vertices * 2;
    v[i++] = ax;
    v[i++] = ay;
    v[i++] = bx;
    v[i++] = by;
    v[i++] = cx;
    v[i++] = cy;
    final colors = _colors;
    for (var k = _vertices; k < _vertices + 3; k++) {
      colors[k] = argb;
    }
    _vertices += 3;
    _frameSegments++;
  }
```

- [ ] **Step 6: Split `_emitSegment` so the direction is computed once**

Rename the body that takes a precomputed unit direction to `_emitQuad`, and
keep `_emitSegment` as the wrapper `point()` still uses:

```dart
  /// Two triangles around a segment whose unit direction is already known.
  void _emitQuad(double x0, double y0, double x1, double y1, double ux,
      double uy, double half, int argb) {
    final nx = -uy * half, ny = ux * half;
    // ... the existing twelve writes, unchanged, using nx and ny ...
  }

  /// Two triangles around a segment, taking its direction from its endpoints.
  void _emitSegment(double x0, double y0, double x1, double y1, double half,
      int argb) {
    final dx = x1 - x0, dy = y1 - y0;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length == 0) return;
    _emitQuad(x0, y0, x1, y1, dx / length, dy / length, half, argb);
  }
```

- [ ] **Step 7: Route `polyline` through the run**

```dart
    var px = a * points[0] + c * points[1] + e;
    var py = b * points[0] + d * points[1] + f;
    _beginRun(px, py);
    for (var i = 1; i < count; i++) {
      final qx = a * points[i * 2] + c * points[i * 2 + 1] + e;
      final qy = b * points[i * 2] + d * points[i * 2 + 1] + f;
      _runTo(qx, qy, half, argb);
    }
    _endRun(closed: false, half: half, argb: argb);
    // The spike's closing segment moves to Task 5 with its seam join, so a
    // closed polyline draws one segment short until then. No caller reaches
    // it: `closed:` is `false` at all four of the painter's call sites, and
    // the one unit test that passes `closed: true` moves to Task 5 with it.
```

Delete the now-unused `px`/`py` reassignment and the old `if (closed)` line.
In `vertices_draw_sink_test.dart`, move the `closed: true` half of
`'a polyline of n points emits n-1 segments, and closed adds one more'` into a
skipped test named for Task 5, or delete that half and let Task 5 restore it —
whichever the implementer prefers, but say which in the commit.

- [ ] **Step 8: Route `_flatten` through the same run**

```dart
    var lx = cx + r * math.cos(start);
    var ly = cy + r * math.sin(start);
    _beginRun(t.a * lx + t.c * ly + t.e, t.b * lx + t.d * ly + t.f);
    for (var i = 1; i <= steps; i++) {
      final angle = start + step * i;
      lx = cx + r * math.cos(angle);
      ly = cy + r * math.sin(angle);
      _runTo(t.a * lx + t.c * ly + t.e, t.b * lx + t.d * ly + t.f, half, argb);
    }
    _endRun(closed: false, half: half, argb: argb);
```

A full sweep's last sample is its first point, so the run closes itself
geometrically and the seam is still unjoined. That is Task 5's, and
`closed: false` here says so rather than pretending otherwise. Keep the
existing `assert(!closed || (sweep - 2 * math.pi).abs() < 1e-9)` until Task 5
replaces it.

- [ ] **Step 9: Run the test and watch it pass**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/vertices_join_test.dart
```

Expected: 9 tests pass.

- [ ] **Step 10: Run the whole suite**

```sh
cd packages/jet_cad_2d_flutter && flutter test
```

`vertices_draw_sink_test.dart`'s segment-count assertions now include join
triangles. **Do not loosen them.** Update each to the new exact count and add
one sentence saying which of the triangles are joins, so the number still
describes something. `frameSegmentCount` counts triangles rather than segments
now — rename it to `frameTriangleCount`, update the two rig call sites in
`apps/dev_harness_2d/integration_test/frame_timing_test.dart`, and say so in
the accessor's doc comment.

- [ ] **Step 11: Run both suites green, then commit**

```sh
cd packages/jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd ../jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

```bash
git add packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart packages/jet_cad_2d_flutter/test
git commit -m "feat: miter and bevel joins, shared by both stroke walks

Every segment was an independent quad, so a corner had a notch on the outside.
The join is emitted by one run walk that both `polyline` and `_flatten` drive,
because a thick polyline with joins beside a thick arc without them is the
failure a second implementation invites.

A miter is two triangles. The notch is the quadrilateral (V, A, M, B), so it
takes the bevel triangle and the tip triangle; the tip alone leaves a hairline
crack along AB at every mitred corner, which no triangle count would catch.

The limit is Impeller's: 4.0, converted to a cosine of -0.875 by its own
formula, so a corner mitres up to about a 151-degree turn. Both sides of that
boundary are pinned.

Run state is fields rather than a per-run object; an object here would put an
allocation back on the frame path that the previous task just measured at zero."
```

---

