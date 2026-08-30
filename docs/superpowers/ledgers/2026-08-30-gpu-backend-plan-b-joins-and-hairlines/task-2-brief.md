### Task 2: The record grows to twelve floats and three kinds

**Files:**
- Modify: `lib/src/gpu/instance_record.dart`
- Modify: `lib/src/gpu/resident_geometry.dart`
- Test: `test/gpu/instance_record_test.dart`, `test/gpu/resident_geometry_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `const int kFloatsPerInstance = 12`; `const double kKindStroke = 0`,
  `kKindJoin = 1`, `kKindPoint = 2`; `abstract final class InstanceFieldOffset`
  with `kind, x0, y0, x1, y1, x2, y2, halfWidth, r, g, b, a`;
  `void writeStroke(Float32List, int, {double x0, y0, x1, y1, halfWidth, int argb})`;
  `void writeJoin(Float32List, int, {double vx, vy, prevX, prevY, nextX, nextY, halfWidth, int argb})`;
  `void writePoint(Float32List, int, {double x, y, halfWidth, int argb})`;
  `ResidentGeometry.kCornerVertices` at **six floats per vertex**;
  `ResidentGeometry.kInstanceVertexLayout` (renamed from `kStrokeVertexLayout`).

**Why twelve and not ten.** A join needs a vertex and its two neighbours — six
coordinates — where a stroke needs four. The two extra floats are 8 bytes per
instance; Task 11 prices the total against the spec's 8 MB budget.

**Why the neighbours and not two unit directions.** A unit direction in
collection space is only a unit direction in device space under a conformal
transform, and nothing guarantees the camera is one. The reference computes its
directions in **device** space, after the residual (`_runTo`: `dx = x -
_runPrevX` on already-transformed points). Storing the three points and
normalising in the shader **after** the mvp puts both arms in the same space
by construction, and it is what the stroke branch already does.

- [ ] **Step 1: Write the failing test**

Replace `test/gpu/instance_record_test.dart` with:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart';

void main() {
  test('the field offsets are contiguous and cover the stride', () {
    // The offsets are read by three independent consumers -- the writers
    // below, `ResidentGeometry.kInstanceVertexLayout`, and (as a fourth,
    // uncheckable copy) `cad_stroke.vert`'s attribute list. A gap or an
    // overlap here is silent on every one of them until a device run.
    const offsets = <int>[
      InstanceFieldOffset.kind,
      InstanceFieldOffset.x0,
      InstanceFieldOffset.y0,
      InstanceFieldOffset.x1,
      InstanceFieldOffset.y1,
      InstanceFieldOffset.x2,
      InstanceFieldOffset.y2,
      InstanceFieldOffset.halfWidth,
      InstanceFieldOffset.r,
      InstanceFieldOffset.g,
      InstanceFieldOffset.b,
      InstanceFieldOffset.a,
    ];
    expect(offsets, List<int>.generate(kFloatsPerInstance, (i) => i),
        reason: 'offsets must be 0..kFloatsPerInstance-1 with no gaps');
  });

  test('the three kind tags are distinct and ordered for the shader', () {
    // `cad_stroke.vert` dispatches with `kind < 0.5` then `kind < 1.5`, so
    // the tags must be 0, 1, 2 in that order -- not merely distinct.
    expect(kKindStroke, 0.0);
    expect(kKindJoin, 1.0);
    expect(kKindPoint, 2.0);
  });

  test('writeStroke fills every slot and leaves p2 zeroed', () {
    final b = Float32List(kFloatsPerInstance * 2);
    // Index 1, not 0: writing at a non-zero index is the only way to catch a
    // writer that ignores its `index` argument, and the zero-fill of a fresh
    // Float32List would hide it at index 0.
    writeStroke(b, 1,
        x0: 3, y0: -4, x1: 11, y1: 6, halfWidth: 1.25, argb: 0x80402010);
    final r = b.sublist(kFloatsPerInstance);
    expect(r[InstanceFieldOffset.kind], kKindStroke);
    expect(r[InstanceFieldOffset.x0], 3);
    expect(r[InstanceFieldOffset.y0], -4);
    expect(r[InstanceFieldOffset.x1], 11);
    expect(r[InstanceFieldOffset.y1], 6);
    expect(r[InstanceFieldOffset.x2], 0);
    expect(r[InstanceFieldOffset.y2], 0);
    expect(r[InstanceFieldOffset.halfWidth], 1.25);
    expect(r[InstanceFieldOffset.r], closeTo(0x40 / 255.0, 1e-6));
    expect(r[InstanceFieldOffset.g], closeTo(0x20 / 255.0, 1e-6));
    expect(r[InstanceFieldOffset.b], closeTo(0x10 / 255.0, 1e-6));
    expect(r[InstanceFieldOffset.a], closeTo(0x80 / 255.0, 1e-6));
    // The first record is untouched: a writer that ignored `index` would
    // have written here instead.
    expect(b.sublist(0, kFloatsPerInstance).every((v) => v == 0), isTrue);
  });

  test('writeJoin puts the vertex first and the neighbours after it', () {
    // Order matters and is not symmetric: the shader takes the incoming
    // direction as `p0 - p1` and the outgoing as `p2 - p0`. Swapping p1 and
    // p2 reverses the turn and mirrors the wedge onto the wrong side.
    final b = Float32List(kFloatsPerInstance);
    writeJoin(b, 0,
        vx: 10,
        vy: 20,
        prevX: 4,
        prevY: 20,
        nextX: 10,
        nextY: 33,
        halfWidth: 2,
        argb: 0xFF010203);
    expect(b[InstanceFieldOffset.kind], kKindJoin);
    expect(b[InstanceFieldOffset.x0], 10);
    expect(b[InstanceFieldOffset.y0], 20);
    expect(b[InstanceFieldOffset.x1], 4);
    expect(b[InstanceFieldOffset.y1], 20);
    expect(b[InstanceFieldOffset.x2], 10);
    expect(b[InstanceFieldOffset.y2], 33);
    expect(b[InstanceFieldOffset.halfWidth], 2);
  });

  test('writePoint carries one position and zeroes the unused slots', () {
    final b = Float32List(kFloatsPerInstance);
    writePoint(b, 0, x: -7, y: 2.5, halfWidth: 0.5, argb: 0xFFFFFFFF);
    expect(b[InstanceFieldOffset.kind], kKindPoint);
    expect(b[InstanceFieldOffset.x0], -7);
    expect(b[InstanceFieldOffset.y0], 2.5);
    expect(b[InstanceFieldOffset.x1], 0);
    expect(b[InstanceFieldOffset.y1], 0);
    expect(b[InstanceFieldOffset.x2], 0);
    expect(b[InstanceFieldOffset.y2], 0);
    expect(b[InstanceFieldOffset.halfWidth], 0.5);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd packages/jet_cad_2d_flutter && flutter test test/gpu/instance_record_test.dart
```

Expected: compile errors — `InstanceFieldOffset`, `kKindJoin`, `kKindPoint`,
`writeJoin` and `writePoint` are undefined.

- [ ] **Step 3: Rewrite `instance_record.dart`**

```dart
import 'dart:typed_data';

/// Floats per instance record.
///
/// `[kind, x0, y0, x1, y1, x2, y2, halfWidth, r, g, b, a]`.
///
/// **Twelve floats, and none of them packed, because of the web.** The shader
/// bundle must carry an OpenGL ES 100 stage — `flutter_scene`'s web loader
/// reads `entry.openglEs` and transpiles it to ES 300 — and ES 100 has neither
/// bitwise operators nor integer vertex attributes, so a `uint32` colour could
/// not be unpacked in the shader. 48 bytes per record.
///
/// **Ten became twelve in Plan B**, because a join carries a vertex and both
/// its neighbours where a stroke carries two endpoints. The third point is
/// stored rather than a pair of unit directions: a unit direction is only
/// unit-length after a *conformal* transform, and nothing promises the camera
/// is one. The reference takes its directions in device space, after the
/// residual (`vertices_draw_sink.dart`, `_runTo`), so storing points and
/// normalising in the shader after the mvp puts both arms in the same space
/// by construction instead of by coincidence.
const int kFloatsPerInstance = 12;

/// The kind tag, in slot 0 of every record.
///
/// **One buffer and one draw call carry every kind**, because separate
/// pipelines are separate draw calls and three draw calls submit as "all
/// strokes, then all joins, then all fills" — not walk order.
/// `vertices_draw_sink.dart:41-57` records that defect being shipped and
/// reverted once already, partitioned by colour rather than by kind.
///
/// **The values are 0, 1, 2 and the order is load-bearing**, not merely
/// distinct: `cad_stroke.vert` dispatches with `kind < 0.5` then
/// `kind < 1.5`, because ES 100 has no integer attributes and no `switch` on
/// one. Renumbering these without editing that shader silently draws every
/// join as a stroke.
const double kKindStroke = 0;

/// A corner between two segments. `(x0, y0)` is the vertex, `(x1, y1)` the
/// previous point and `(x2, y2)` the next one; the shader builds the bevel
/// and, where the turn is shallow enough, the miter tip.
const double kKindJoin = 1;

/// A `point()` op: a square of the stroke's own width centred on
/// `(x0, y0)`. `(x1, y1)` and `(x2, y2)` are unused.
///
/// **Not a zero-length capped stroke, and not a tiny horizontal segment
/// either.** The reference draws it as a horizontal segment from `px - half`
/// to `px + half` — but it computes that offset in **device** space, where
/// its residual has already been applied. This record holds *collection*
/// space, and the shader expands `halfWidth` in device pixels after the mvp,
/// so a `± half` baked into `x0`/`x1` here would scale with the camera on one
/// axis while the other stayed fixed: the square would shear under zoom. Its
/// own kind is what keeps both axes in the same space.
const double kKindPoint = 2;

/// The record's field layout, as an offset in **floats** from the record's
/// start — the writers below index by float, not byte.
///
/// **The one place this order is declared for Dart.**
/// `ResidentGeometry.kInstanceVertexLayout` derives its `offsetInBytes`
/// values from these same constants (`* 4`), so reordering a field here moves
/// the writers and the vertex layout together instead of leaving one behind.
/// `cad_stroke.vert`'s attribute list is a third, independent copy — GLSL
/// cannot read a Dart constant — and `test/support/instance_expander.dart` is
/// a fourth. The expander is the one that is *gated*: it reads these same
/// constants, and `test/gpu/expander_differential_test.dart` compares its
/// output against the reference sink, so a drift between this file and the
/// expander goes red in `flutter test`. A drift between either and the GLSL
/// still needs a device run or a hand-check against `impellerc`'s reflection.
abstract final class InstanceFieldOffset {
  static const int kind = 0;
  static const int x0 = 1;
  static const int y0 = 2;
  static const int x1 = 3;
  static const int y1 = 4;
  static const int x2 = 5;
  static const int y2 = 6;
  static const int halfWidth = 7;
  static const int r = 8;
  static const int g = 9;
  static const int b = 10;
  static const int a = 11;
}

/// Writes the four colour slots at record base [o]. [argb] is `0xAARRGGBB`.
void _writeColor(Float32List into, int o, int argb) {
  into[o + InstanceFieldOffset.r] = ((argb >> 16) & 0xFF) / 255.0;
  into[o + InstanceFieldOffset.g] = ((argb >> 8) & 0xFF) / 255.0;
  into[o + InstanceFieldOffset.b] = (argb & 0xFF) / 255.0;
  into[o + InstanceFieldOffset.a] = ((argb >> 24) & 0xFF) / 255.0;
}

/// Writes the stroke record at [index]. [argb] is `0xAARRGGBB`.
void writeStroke(
  Float32List into,
  int index, {
  required double x0,
  required double y0,
  required double x1,
  required double y1,
  required double halfWidth,
  required int argb,
}) {
  final o = index * kFloatsPerInstance;
  into[o + InstanceFieldOffset.kind] = kKindStroke;
  into[o + InstanceFieldOffset.x0] = x0;
  into[o + InstanceFieldOffset.y0] = y0;
  into[o + InstanceFieldOffset.x1] = x1;
  into[o + InstanceFieldOffset.y1] = y1;
  into[o + InstanceFieldOffset.x2] = 0;
  into[o + InstanceFieldOffset.y2] = 0;
  into[o + InstanceFieldOffset.halfWidth] = halfWidth;
  _writeColor(into, o, argb);
}

/// Writes the join record at [index].
///
/// The three points are **not interchangeable**: the shader takes the
/// incoming direction as `vertex - previous` and the outgoing as
/// `next - vertex`, and swapping the neighbours reverses the turn, which
/// puts the wedge on the inside of the corner where there is no notch to
/// fill.
void writeJoin(
  Float32List into,
  int index, {
  required double vx,
  required double vy,
  required double prevX,
  required double prevY,
  required double nextX,
  required double nextY,
  required double halfWidth,
  required int argb,
}) {
  final o = index * kFloatsPerInstance;
  into[o + InstanceFieldOffset.kind] = kKindJoin;
  into[o + InstanceFieldOffset.x0] = vx;
  into[o + InstanceFieldOffset.y0] = vy;
  into[o + InstanceFieldOffset.x1] = prevX;
  into[o + InstanceFieldOffset.y1] = prevY;
  into[o + InstanceFieldOffset.x2] = nextX;
  into[o + InstanceFieldOffset.y2] = nextY;
  into[o + InstanceFieldOffset.halfWidth] = halfWidth;
  _writeColor(into, o, argb);
}

/// Writes the point record at [index].
void writePoint(
  Float32List into,
  int index, {
  required double x,
  required double y,
  required double halfWidth,
  required int argb,
}) {
  final o = index * kFloatsPerInstance;
  into[o + InstanceFieldOffset.kind] = kKindPoint;
  into[o + InstanceFieldOffset.x0] = x;
  into[o + InstanceFieldOffset.y0] = y;
  into[o + InstanceFieldOffset.x1] = 0;
  into[o + InstanceFieldOffset.y1] = 0;
  into[o + InstanceFieldOffset.x2] = 0;
  into[o + InstanceFieldOffset.y2] = 0;
  into[o + InstanceFieldOffset.halfWidth] = halfWidth;
  _writeColor(into, o, argb);
}
```

- [ ] **Step 4: Run the record test**

```bash
cd packages/jet_cad_2d_flutter && flutter test test/gpu/instance_record_test.dart
```

Expected: 4 tests pass. `geometry_collector.dart` and `resident_geometry.dart`
will still fail to compile against `StrokeFieldOffset` — that is Step 5.

- [ ] **Step 5: Update `resident_geometry.dart`**

Three edits, all in that file:

1. Rename `kStrokeVertexLayout` → `kInstanceVertexLayout`, keeping its whole
   doc comment and replacing `StrokeFieldOffset` with `InstanceFieldOffset`
   throughout.
2. Add the `p2` attribute to the instance buffer's attribute list, between
   `p1` and `half_width`:
   ```dart
             gpu.VertexAttribute(
                 name: 'p2',
                 format: gpu.VertexFormat.float32x2,
                 offsetInBytes: InstanceFieldOffset.x2 * 4),
   ```
3. Replace the corner buffer — both `kCornerVertices` and buffer 0's
   descriptor:

```dart
  /// The six per-vertex records: two triangles, not a triangle strip, because
  /// a strip cannot mix kinds and Plans C and D add kinds to this same buffer.
  ///
  /// **Six floats per vertex: `corner.xy` then `join_weight.xyzw`.**
  ///
  /// `corner` is the quad parameterisation Plan A shipped — `x` picks the
  /// endpoint (0 = p0, 1 = p1), `y` picks the side (-1 or +1) — and the
  /// stroke and point branches still read only it.
  ///
  /// `join_weight` exists because the join branch needs **six distinct
  /// vertex roles** and `corner` alone offers only four: `(1,-1)` and `(0,1)`
  /// each appear twice, since the two triangles share the quad's diagonal.
  /// A join's two triangles are the bevel `(V, A, B)` and the miter tip
  /// `(A, M, B)` — four distinct points across six vertices, and the
  /// duplicated corners need *different* roles in each triangle, so they
  /// cannot be told apart by `corner`. The weight vector selects one of
  /// `(V, A, B, M)` per vertex, and the shader reads the position as
  /// `w.x*V + w.y*A + w.z*B + w.w*M` — no float-equality test on an index,
  /// which ES 100 makes unpleasant.
  ///
  /// Triangle 0 is `(V, A, B)` and triangle 1 is `(A, M, B)`. Both wind
  /// **either way** depending on the turn direction, because `_emitJoin`
  /// flips the outer side with the sign of the cross product — which is why
  /// `GpuDrawBackend.render` pins `CullMode.none`.
  ///
  /// `@visibleForTesting`: no test can reach this data through `create`
  /// itself (it runs only with a real GPU context), so it is hoisted here to
  /// be asserted directly by a plain `flutter test`.
  @visibleForTesting
  static const List<double> kCornerVertices = <double>[
    // corner.x corner.y | join_weight V, A, B, M
    0, -1, /*  */ 1, 0, 0, 0, // triangle 0, vertex 0 -> V
    0, 1, /*   */ 0, 1, 0, 0, // triangle 0, vertex 1 -> A
    1, -1, /*  */ 0, 0, 1, 0, // triangle 0, vertex 2 -> B
    1, -1, /*  */ 0, 1, 0, 0, // triangle 1, vertex 0 -> A
    0, 1, /*   */ 0, 0, 0, 1, // triangle 1, vertex 1 -> M
    1, 1, /*   */ 0, 0, 1, 0, // triangle 1, vertex 2 -> B
  ];

  /// Floats per entry in the corner buffer: `corner` (2) + `join_weight` (4).
  static const int kFloatsPerCorner = 6;
```

and buffer 0's descriptor becomes:

```dart
      gpu.VertexBuffer(
          strideInBytes: kFloatsPerCorner * 4,
          attributes: <gpu.VertexAttribute>[
            gpu.VertexAttribute(
                name: 'corner',
                format: gpu.VertexFormat.float32x2,
                offsetInBytes: 0),
            gpu.VertexAttribute(
                name: 'join_weight',
                format: gpu.VertexFormat.float32x4,
                offsetInBytes: 8),
          ]),
```

- [ ] **Step 6: Extend `resident_geometry_test.dart`**

Add these two tests to the existing file (keep everything already there, and
update any assertion that referenced `kStrokeVertexLayout` or a stride of 8):

```dart
  test('the corner buffer is six vertices of six floats', () {
    expect(ResidentGeometry.kCornerVertices.length,
        6 * ResidentGeometry.kFloatsPerCorner);
  });

  test('every join weight selects exactly one of the four points', () {
    // A weight vector that summed to anything but 1 would put the vertex
    // somewhere between two roles, which draws a wedge of the wrong shape
    // rather than failing loudly. A weight vector that was all zeroes would
    // collapse it onto the origin.
    for (var v = 0; v < 6; v++) {
      final base = v * ResidentGeometry.kFloatsPerCorner + 2;
      final w = ResidentGeometry.kCornerVertices.sublist(base, base + 4);
      expect(w.reduce((a, b) => a + b), 1.0, reason: 'vertex $v weights $w');
      expect(w.where((x) => x == 1.0).length, 1, reason: 'vertex $v weights $w');
    }
  });

  test('the two join triangles are (V, A, B) and (A, M, B)', () {
    // Named so a reordering of kCornerVertices is a test failure with the
    // role in the message, not a silently different wedge.
    const v = 0, a = 1, b = 2, m = 3;
    int roleOf(int vertex) {
      final base = vertex * ResidentGeometry.kFloatsPerCorner + 2;
      return ResidentGeometry.kCornerVertices
          .sublist(base, base + 4)
          .indexOf(1.0);
    }

    expect(<int>[roleOf(0), roleOf(1), roleOf(2)], <int>[v, a, b]);
    expect(<int>[roleOf(3), roleOf(4), roleOf(5)], <int>[a, m, b]);
  });
```

- [ ] **Step 7: Pin cull mode**

In `lib/src/gpu/gpu_draw_backend.dart`, immediately after
`pass.setPrimitiveType(gpu.PrimitiveType.triangle);`:

```dart
    // **Load-bearing from Plan B on, and it was not before.** A stroke quad's
    // winding is invariant under reversing the segment — the direction and
    // the normal flip together — so Plan A never had to think about this. A
    // join's is not: `_emitJoin` picks the outer side with
    // `s = cross > 0 ? -half : half` (`vertices_draw_sink.dart`), so a left
    // turn and a right turn wind opposite ways and any culling would drop
    // half the corners in a drawing. `CullMode.none` is also the enum's zero
    // value, so this is pinning a default rather than changing behaviour —
    // pinned because a default that becomes load-bearing and stays implicit
    // is the kind of thing that changes under you in a package upgrade.
    pass.setCullMode(gpu.CullMode.none);
```

- [ ] **Step 8: Update the collector's references and gate**

`geometry_collector.dart` references `StrokeFieldOffset` only indirectly
through `writeStroke`, so it should compile unchanged. Run the gate:

```bash
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
echo "exit=$?"
```

Fix whatever the record widening broke in the existing tests — notably any
assertion on `kFloatsPerInstance`, on a record's slot indices, or on
`byteLengthFor`. **Report every such change and why**: a test that had to be
edited to keep passing is either correctly following the widening or was
asserting the old layout by accident, and the reviewer needs to be able to
tell which.

- [ ] **Step 9: Commit**

```bash
git add packages/jet_cad_2d_flutter/lib/src/gpu packages/jet_cad_2d_flutter/test/gpu
git commit -m "feat(gpu): the instance record carries three kinds and twelve floats"
```

---

