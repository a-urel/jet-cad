### Task 8: The vertex shader, in Dart

**Files:**
- Create: `test/support/instance_expander.dart`
- Test: `test/gpu/instance_expander_test.dart`

**Interfaces:**
- Consumes: `InstanceFieldOffset`, the kind constants,
  `ResidentGeometry.kCornerVertices`.
- Produces:
  ```dart
  class ExpandedTriangles {
    final Float32List positions;  // 2 floats per vertex, 6 vertices per instance
    final Int32List colors;       // 1 per vertex, 0xAARRGGBB
  }
  ExpandedTriangles expandInstances(
      Float32List data, int instanceCount, Transform2 collectionToDevice);
  ```
  Task 9 consumes both.

**Why this file exists.** `flutter test` has no GPU, so every line of
`cad_stroke.vert` is unreachable by this package's suite. Plan A lived with
that because its shader was four statements. Plan B's is fifty, and the miter
arithmetic is the part most likely to be wrong. This is that shader
transcribed into Dart, driven by the same instance buffer and the same corner
table, producing the triangle list the GPU would produce — which
`TriangleRasterizer` can then rasterise.

**It is a second copy, and that is stated rather than hidden.** The copy is
worth it because it converts an untestable file into a tested one, and because
the divergence it can hide is one file diff away. The one thing it must never
do is read the collector: it takes a `Float32List` and a transform, nothing
else.

- [ ] **Step 1: Write the failing test**

`test/gpu/instance_expander_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart';

import '../support/instance_expander.dart';

void main() {
  test('the miter cosine matches the reference constant', () {
    // `cad_stroke.vert` restates -0.875 as a literal because GLSL cannot
    // read a Dart constant. This is the assertion that keeps the literal
    // honest if the reference's miter limit ever moves.
    expect(kExpanderMinMiterCosine, VerticesDrawSink.kMinMiterCosine);
  });

  test('a horizontal stroke expands to the quad the reference builds', () {
    final data = Float32List(kFloatsPerInstance);
    writeStroke(data, 0,
        x0: 0, y0: 0, x1: 100, y1: 0, halfWidth: 4, argb: 0xFF112233);
    final out = expandInstances(data, 1, Transform2.identity());

    expect(out.positions.length, 12, reason: 'six vertices, two floats each');
    // Corner (0,-1) -> (0, -4); (0,1) -> (0, 4); (1,-1) -> (100, -4).
    // The normal of a +x direction is (0, +1), so corner.y = -1 is y = -4.
    expect(out.positions[0], closeTo(0, 1e-4));
    expect(out.positions[1], closeTo(-4, 1e-4));
    expect(out.positions[2], closeTo(0, 1e-4));
    expect(out.positions[3], closeTo(4, 1e-4));
    expect(out.positions[4], closeTo(100, 1e-4));
    expect(out.positions[5], closeTo(-4, 1e-4));
    expect(out.colors.every((c) => c == 0xFF112233), isTrue);
  });

  test('a right-angle join is mitred, and the tip is at the outer corner',
      () {
    // Incoming +x, outgoing +y: a left turn, so the notch is on the right
    // (negative y / positive x side). At 90 degrees the half-angle is 45,
    // cos is sqrt(1/2), and the miter reach is half / cos = 4 * sqrt(2).
    final data = Float32List(kFloatsPerInstance);
    writeJoin(data, 0,
        vx: 100,
        vy: 0,
        prevX: 0,
        prevY: 0,
        nextX: 100,
        nextY: 100,
        halfWidth: 4,
        argb: 0xFF000000);
    final out = expandInstances(data, 1, Transform2.identity());

    // Vertex 4 of the six is M, the miter tip.
    final mx = out.positions[8], my = out.positions[9];
    // d0 = (1,0), d1 = (0,1), cross = 1 > 0, so s = -4.
    // n0 = (-0,1)*-4 = (0,-4); n1 = (-1,0)*-4 = (4,0).
    // sum = (4,-4), mu = (1,-1)/sqrt2, cos_half = dot(mu,n0)/4
    //     = ((0*1 + -4*-1)/sqrt2)/4 = (4/sqrt2)/4 = 1/sqrt2.
    // reach = 4 / (1/sqrt2) = 4*sqrt2. m = v + mu*reach = (100+4, 0-4).
    expect(mx, closeTo(104, 1e-3));
    expect(my, closeTo(-4, 1e-3));
  });

  test('a hairpin turn is bevelled: the tip triangle has zero area', () {
    // Incoming +x, outgoing very nearly -x. dot is below -0.875, so the
    // reference bails before the miter and emits the bevel alone.
    final data = Float32List(kFloatsPerInstance);
    writeJoin(data, 0,
        vx: 100,
        vy: 0,
        prevX: 0,
        prevY: 0,
        nextX: 0,
        nextY: 1,
        halfWidth: 4,
        argb: 0xFF000000);
    final out = expandInstances(data, 1, Transform2.identity());
    final ax = out.positions[6], ay = out.positions[7];
    final mx = out.positions[8], my = out.positions[9];
    expect(mx, closeTo(ax, 1e-4),
        reason: 'M collapses onto A, so (A, M, B) has no area');
    expect(my, closeTo(ay, 1e-4));
  });

  test('a collinear join collapses onto its vertex', () {
    final data = Float32List(kFloatsPerInstance);
    writeJoin(data, 0,
        vx: 50,
        vy: 50,
        prevX: 0,
        prevY: 50,
        nextX: 100,
        nextY: 50,
        halfWidth: 4,
        argb: 0xFF000000);
    final out = expandInstances(data, 1, Transform2.identity());
    for (var i = 0; i < 6; i++) {
      expect(out.positions[i * 2], closeTo(50, 1e-4));
      expect(out.positions[i * 2 + 1], closeTo(50, 1e-4));
    }
  });

  test('a point expands to a square of the stroke width', () {
    final data = Float32List(kFloatsPerInstance);
    writePoint(data, 0, x: 10, y: 20, halfWidth: 3, argb: 0xFF000000);
    final out = expandInstances(data, 1, Transform2.identity());
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (var i = 0; i < 6; i++) {
      final x = out.positions[i * 2], y = out.positions[i * 2 + 1];
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    expect(maxX - minX, closeTo(6, 1e-4));
    expect(maxY - minY, closeTo(6, 1e-4));
    expect((minX + maxX) / 2, closeTo(10, 1e-4));
    expect((minY + maxY) / 2, closeTo(20, 1e-4));
  });

  test('half-width does not scale with the transform', () {
    // The whole reason joins and quads are built in the shader. Under a 5x
    // camera the centreline moves five times as far and the quad stays four
    // device pixels wide.
    final data = Float32List(kFloatsPerInstance);
    writeStroke(data, 0,
        x0: 0, y0: 0, x1: 100, y1: 0, halfWidth: 4, argb: 0xFF000000);
    final out = expandInstances(data, 1, Transform2.scale(5, 5));
    expect(out.positions[4], closeTo(500, 1e-3), reason: 'the centreline scaled');
    expect(out.positions[3] - out.positions[1], closeTo(8, 1e-3),
        reason: 'the width did not');
  });
}
```

- [ ] **Step 2: Run and watch it fail**

```bash
cd packages/jet_cad_2d_flutter && flutter test test/gpu/instance_expander_test.dart
```

Expected: `Target of URI doesn't exist: '../support/instance_expander.dart'`.

- [ ] **Step 3: Write the expander**

`test/support/instance_expander.dart`:

```dart
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart';

/// `cad_stroke.vert`, in Dart, so `flutter test` can reach it.
///
/// **This is a deliberate second copy of a file no test can run.** The suite
/// has no GPU, so every line of the vertex shader is otherwise unreachable —
/// including the miter arithmetic, which is the part most likely to be
/// wrong. Transcribing it here converts an untestable file into a tested one
/// and reduces the risk to a single file diff.
///
/// **Read it beside the GLSL and keep the statement order.** Where the
/// shader writes `dot(d0, d1) >= kMinMiterCosine`, so does this; where it
/// collapses a corner onto the vertex, so does this. A "cleaner" Dart
/// rewrite is worth nothing here — the value of this file is that a reader
/// can diff it against the shader line by line.
///
/// It takes an instance buffer and a transform. It must never read the
/// collector: the collector's output is the input, which is exactly what the
/// GPU sees.
library;

/// The shader's `kMinMiterCosine` literal, mirrored so a test can assert it
/// against `VerticesDrawSink.kMinMiterCosine`.
const double kExpanderMinMiterCosine = -0.875;

/// The corner table's six entries, `(corner.xy, join_weight.xyzw)`.
///
/// Read from [ResidentGeometry.kCornerVertices] rather than restated, so a
/// reordering there is a change here too.
class _Corner {
  const _Corner(this.x, this.y, this.wv, this.wa, this.wb, this.wm);
  final double x, y, wv, wa, wb, wm;
}

List<_Corner> _corners() {
  const stride = ResidentGeometry.kFloatsPerCorner;
  final src = ResidentGeometry.kCornerVertices;
  return List<_Corner>.generate(
      6,
      (i) => _Corner(src[i * stride], src[i * stride + 1], src[i * stride + 2],
          src[i * stride + 3], src[i * stride + 4], src[i * stride + 5]));
}

/// The triangle list the GPU would produce, in the shape
/// `TriangleRasterizer.observe` takes.
class ExpandedTriangles {
  ExpandedTriangles(this.positions, this.colors);

  /// Two floats per vertex, six vertices per instance, in instance order.
  final Float32List positions;

  /// One `0xAARRGGBB` per vertex.
  final Int32List colors;

  int get vertexCount => colors.length;
}

/// Expands [instanceCount] records of [data] under [collectionToDevice].
///
/// [collectionToDevice] stands in for the shader's `mvp` composed with
/// `half_viewport`: the shader maps collection space to device pixels in two
/// steps because a `mat4` is what a uniform block carries, and the
/// composition is the same affine map. Feeding it directly here removes a
/// clip-space round trip that has no observable effect and would only add a
/// place for the two copies to disagree.
ExpandedTriangles expandInstances(
    Float32List data, int instanceCount, Transform2 collectionToDevice) {
  final corners = _corners();
  final positions = Float32List(instanceCount * 6 * 2);
  final colors = Int32List(instanceCount * 6);
  final t = collectionToDevice;

  double toX(double x, double y) => t.a * x + t.c * y + t.e;
  double toY(double x, double y) => t.b * x + t.d * y + t.f;

  for (var i = 0; i < instanceCount; i++) {
    final o = i * kFloatsPerInstance;
    final kind = data[o + InstanceFieldOffset.kind];
    final halfWidth = data[o + InstanceFieldOffset.halfWidth];
    final argb = _argbOf(data, o);

    final x0 = data[o + InstanceFieldOffset.x0];
    final y0 = data[o + InstanceFieldOffset.y0];
    final x1 = data[o + InstanceFieldOffset.x1];
    final y1 = data[o + InstanceFieldOffset.y1];
    final x2 = data[o + InstanceFieldOffset.x2];
    final y2 = data[o + InstanceFieldOffset.y2];

    for (var v = 0; v < 6; v++) {
      final c = corners[v];
      double px, py;

      if (kind < 0.5) {
        final ax = toX(x0, y0), ay = toY(x0, y0);
        final bx = toX(x1, y1), by = toY(x1, y1);
        final dx = bx - ax, dy = by - ay;
        final len = math.sqrt(dx * dx + dy * dy);
        final dirX = len > 0 ? dx / len : 1.0;
        final dirY = len > 0 ? dy / len : 0.0;
        final nx = -dirY, ny = dirX;
        px = ax + (bx - ax) * c.x + nx * halfWidth * c.y;
        py = ay + (by - ay) * c.x + ny * halfWidth * c.y;
      } else if (kind < 1.5) {
        final vx = toX(x0, y0), vy = toY(x0, y0);
        final pxp = toX(x1, y1), pyp = toY(x1, y1);
        final nxp = toX(x2, y2), nyp = toY(x2, y2);

        final inX = vx - pxp, inY = vy - pyp;
        final outX = nxp - vx, outY = nyp - vy;
        final inLen = math.sqrt(inX * inX + inY * inY);
        final outLen = math.sqrt(outX * outX + outY * outY);
        final d0x = inLen > 0 ? inX / inLen : 1.0;
        final d0y = inLen > 0 ? inY / inLen : 0.0;
        final d1x = outLen > 0 ? outX / outLen : d0x;
        final d1y = outLen > 0 ? outY / outLen : d0y;

        final crossZ = d0x * d1y - d0y * d1x;
        if (crossZ == 0 || inLen == 0 || outLen == 0) {
          px = vx;
          py = vy;
        } else {
          final s = crossZ > 0 ? -halfWidth : halfWidth;
          final n0x = -d0y * s, n0y = d0x * s;
          final n1x = -d1y * s, n1y = d1x * s;
          final ax = vx + n0x, ay = vy + n0y;
          final bx = vx + n1x, by = vy + n1y;

          var mx = ax, my = ay;
          if (d0x * d1x + d0y * d1y >= kExpanderMinMiterCosine) {
            final sumX = n0x + n1x, sumY = n0y + n1y;
            final sumLen = math.sqrt(sumX * sumX + sumY * sumY);
            if (sumLen > 0 && halfWidth > 0) {
              final muX = sumX / sumLen, muY = sumY / sumLen;
              final cosHalf = (muX * n0x + muY * n0y) / halfWidth;
              if (cosHalf > 0) {
                final reach = halfWidth / cosHalf;
                mx = vx + muX * reach;
                my = vy + muY * reach;
              }
            }
          }

          px = c.wv * vx + c.wa * ax + c.wb * bx + c.wm * mx;
          py = c.wv * vy + c.wa * ay + c.wb * by + c.wm * my;
        }
      } else {
        final cx = toX(x0, y0), cy = toY(x0, y0);
        px = cx + (c.x * 2.0 - 1.0) * halfWidth;
        py = cy + c.y * halfWidth;
      }

      final vi = (i * 6 + v);
      positions[vi * 2] = px;
      positions[vi * 2 + 1] = py;
      colors[vi] = argb;
    }
  }

  return ExpandedTriangles(positions, colors);
}

/// Reads the record's four colour floats back to `0xAARRGGBB`.
///
/// Exact round trip: the writer stored `channel / 255.0` and an 8-bit value
/// divided by 255 then multiplied by 255 is that value again in float32,
/// with the round only guarding against a representation surprise.
int _argbOf(Float32List data, int o) {
  int ch(int offset) =>
      (data[o + offset] * 255.0).round().clamp(0, 255).toInt();
  return (ch(InstanceFieldOffset.a) << 24) |
      (ch(InstanceFieldOffset.r) << 16) |
      (ch(InstanceFieldOffset.g) << 8) |
      ch(InstanceFieldOffset.b);
}
```

- [ ] **Step 4: Run the tests**

```bash
cd packages/jet_cad_2d_flutter && flutter test test/gpu/instance_expander_test.dart
```

Expected: 7 tests pass. **Recompute the miter test's numbers by hand before
accepting them** — the whole point of that test is that it was derived
independently of the code.

- [ ] **Step 5: Fire two mutations against the expander**

```bash
cd packages/jet_cad_2d_flutter
cp test/support/instance_expander.dart /tmp/ie.bak

# M-B5: expand the quad at collection scale -- multiply halfWidth by
#   t.scaleMagnitude before using it.
flutter test test/gpu/instance_expander_test.dart
cp /tmp/ie.bak test/support/instance_expander.dart

# M-B6: always miter -- delete the `>= kExpanderMinMiterCosine` guard.
flutter test test/gpu/instance_expander_test.dart
cp /tmp/ie.bak test/support/instance_expander.dart
```

Expected: M-B5 red on `half-width does not scale with the transform`; M-B6 red
on `a hairpin turn is bevelled`.

- [ ] **Step 6: Gate and commit**

```bash
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
echo "exit=$?"
git add packages/jet_cad_2d_flutter/test
git commit -m "test(gpu): the vertex shader, transcribed into Dart and gated"
```

---

