### Task 4: The record grows to sixteen floats and reorders

**Files:**
- Modify: `lib/src/gpu/instance_record.dart`
- Modify: `lib/src/gpu/resident_geometry.dart` (the vertex layout only)
- Test: `test/gpu/instance_record_test.dart`
- Test: `test/gpu/resident_geometry_test.dart`

**Interfaces:**
- Produces: `kFloatsPerInstance = 16`; `InstanceFieldOffset` with
  `kind = 0, halfWidth = 1, x0 = 2 … a = 11, dashPeriod = 12, dashPhase = 13,
  dashFracStart = 14, dashFracEnd = 15`; `writeStroke`/`writeJoin`/`writePoint`
  each gaining four optional named dash arguments; `kInstanceVertexLayout` with
  eight attributes.
- Consumes: nothing new.

**Two changes in one commit, on purpose.** The reorder (Ruling C6) and the
widening both move `InstanceFieldOffset`, and splitting them would leave one
commit where the layout and the writers disagree.

- [ ] **Step 1: Write the failing tests**

In `test/gpu/instance_record_test.dart`:

```dart
  test('the record is sixteen floats and kind_half is adjacent', () {
    expect(kFloatsPerInstance, 16);
    expect(InstanceFieldOffset.halfWidth, InstanceFieldOffset.kind + 1,
        reason: 'the shader reads them as one vec2 attribute, which is what '
            'keeps the attribute count at ES 100\'s floor of eight');
  });

  test('a solid stroke writes zero into all four dash slots', () {
    final into = Float32List(kFloatsPerInstance);
    writeStroke(into, 0,
        x0: 1, y0: 2, x1: 3, y1: 4, halfWidth: 0.5, argb: 0xFF112233);
    expect(into[InstanceFieldOffset.dashPeriod], 0.0);
    expect(into[InstanceFieldOffset.dashPhase], 0.0);
    expect(into[InstanceFieldOffset.dashFracStart], 0.0);
    expect(into[InstanceFieldOffset.dashFracEnd], 0.0);
  });

  test('a dashed stroke carries its element extent and its phase', () {
    final into = Float32List(kFloatsPerInstance);
    writeStroke(into, 0,
        x0: 1, y0: 2, x1: 3, y1: 4, halfWidth: 0.5, argb: 0xFF112233,
        dashPeriod: 18.0, dashPhase: 4.0,
        dashFracStart: 0.0, dashFracEnd: 12.0 / 18.0);
    expect(into[InstanceFieldOffset.dashPeriod], 18.0);
    expect(into[InstanceFieldOffset.dashPhase], 4.0);
    expect(into[InstanceFieldOffset.dashFracEnd], closeTo(0.6667, 1e-4));
  });

  test('a negative period is preserved bit for bit -- it is the collapse '
      'representative marker, not a magnitude', () {
    final into = Float32List(kFloatsPerInstance);
    writeJoin(into, 0,
        vx: 0, vy: 0, prevX: -1, prevY: 0, nextX: 0, nextY: 1,
        halfWidth: 1, argb: 0xFF000000, dashPeriod: -18.0);
    expect(into[InstanceFieldOffset.dashPeriod], -18.0);
    expect(into[InstanceFieldOffset.dashPeriod].isNegative, isTrue);
  });

  test('a point is never dashed', () {
    // `VerticesDrawSink.point` does not consult a linetype, and neither does
    // the painter's point path -- `_emitScreenSpace` returns before
    // `_patternFor` is ever called. `writePoint` therefore takes no dash
    // arguments at all, so a caller cannot express something the reference
    // cannot draw.
    final into = Float32List(kFloatsPerInstance);
    writePoint(into, 0, x: 1, y: 2, halfWidth: 0.5, argb: 0xFF112233);
    expect(into[InstanceFieldOffset.dashPeriod], 0.0);
  });
```

In `test/gpu/resident_geometry_test.dart`:

```dart
  test('the vertex layout declares eight attributes, which is the ES 100 '
      'floor the shader header claims', () {
    final attributes = ResidentGeometry.kInstanceVertexLayout.buffers
        .expand((b) => b.attributes)
        .toList();
    expect(attributes, hasLength(8),
        reason: 'gl_MaxVertexAttribs is guaranteed to be at least 8 and no '
            'more; a ninth binds on every platform this project runs on '
            'today and falsifies the header');
    expect(attributes.map((a) => a.name), containsAll(<String>[
      'corner', 'join_weight', 'kind_half', 'p0', 'p1', 'p2', 'color', 'dash',
    ]));
  });

  test('every instance attribute offset is derived from InstanceFieldOffset', () {
    final instanceBuffer = ResidentGeometry.kInstanceVertexLayout.buffers[1];
    expect(instanceBuffer.strideInBytes, kFloatsPerInstance * 4);
    expect(
        instanceBuffer.attributes
            .firstWhere((a) => a.name == 'dash')
            .offsetInBytes,
        InstanceFieldOffset.dashPeriod * 4);
  });

  test('the buffer prices sixteen floats', () {
    expect(ResidentGeometry.byteLengthFor(1000), 1000 * 16 * 4);
  });
```

- [ ] **Step 2: Run and watch them fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/instance_record_test.dart test/gpu/resident_geometry_test.dart
```
Expected: `kFloatsPerInstance` is 12, `dashPeriod` is undefined.

- [ ] **Step 3: Rewrite `InstanceFieldOffset` and `kFloatsPerInstance`**

```dart
/// Floats per instance record.
///
/// `[kind, halfWidth, x0, y0, x1, y1, x2, y2, r, g, b, a,
///   dashPeriod, dashPhase, dashFracStart, dashFracEnd]`.
///
/// **Sixteen floats, none of them packed, because of the web.** ES 100 has
/// neither bitwise operators nor integer vertex attributes. 64 bytes per
/// record.
///
/// **Twelve became sixteen in Plan C**, and `kind` moved next to `halfWidth`
/// in the same change. The four new slots carry the dash: the period in
/// collection units, the phase at this instance's start, and the drawn
/// pattern element's own extent as a fraction of the cycle. The move is
/// Ruling C6: the shader reads `kind` and `half_width` as one `vec2`
/// attribute, because `gl_MaxVertexAttribs` is guaranteed to be no more than
/// 8 under GLSL ES 100 and the eighth slot is now the `dash` quad.
///
/// **`dashPeriod` is signed and the sign is data.** Zero means solid.
/// Negative marks the one instance per primitive that draws solid when the
/// live period falls under `kDashCollapsePx` -- see `cad_stroke.vert`'s
/// collapse branch, and Plan C's record section for why the alternative
/// (every instance of a collapsed primitive drawing solid) is visibly wrong
/// rather than merely wasteful.
const int kFloatsPerInstance = 16;

abstract final class InstanceFieldOffset {
  static const int kind = 0;
  static const int halfWidth = 1;
  static const int x0 = 2;
  static const int y0 = 3;
  static const int x1 = 4;
  static const int y1 = 5;
  static const int x2 = 6;
  static const int y2 = 7;
  static const int r = 8;
  static const int g = 9;
  static const int b = 10;
  static const int a = 11;
  static const int dashPeriod = 12;
  static const int dashPhase = 13;
  static const int dashFracStart = 14;
  static const int dashFracEnd = 15;
}
```

- [ ] **Step 4: Widen the writers**

`writeStroke` and `writeJoin` each gain four optional named arguments,
defaulting to solid. `writePoint` gains none — see the test above for why.

```dart
void writeStroke(
  Float32List into,
  int index, {
  required double x0,
  required double y0,
  required double x1,
  required double y1,
  required double halfWidth,
  required int argb,
  /// Collection units. 0 is solid; a negative value marks the collapse
  /// representative and its magnitude is the period.
  double dashPeriod = 0,
  double dashPhase = 0,
  double dashFracStart = 0,
  double dashFracEnd = 0,
}) {
  final o = index * kFloatsPerInstance;
  into[o + InstanceFieldOffset.kind] = kKindStroke;
  into[o + InstanceFieldOffset.halfWidth] = halfWidth;
  into[o + InstanceFieldOffset.x0] = x0;
  // ... y0, x1, y1, and x2/y2 = 0 ...
  _writeColor(into, o, argb);
  _writeDash(into, o, dashPeriod, dashPhase, dashFracStart, dashFracEnd);
}

void _writeDash(Float32List into, int o, double period, double phase,
    double fracStart, double fracEnd) {
  into[o + InstanceFieldOffset.dashPeriod] = period;
  into[o + InstanceFieldOffset.dashPhase] = phase;
  into[o + InstanceFieldOffset.dashFracStart] = fracStart;
  into[o + InstanceFieldOffset.dashFracEnd] = fracEnd;
}
```

- [ ] **Step 5: Rewrite the instance half of `kInstanceVertexLayout`**

Six attributes, offsets derived from `InstanceFieldOffset` as they already are:

```dart
        attributes: <gpu.VertexAttribute>[
          gpu.VertexAttribute(
              name: 'kind_half',
              format: gpu.VertexFormat.float32x2,
              offsetInBytes: InstanceFieldOffset.kind * 4),
          gpu.VertexAttribute(
              name: 'p0',
              format: gpu.VertexFormat.float32x2,
              offsetInBytes: InstanceFieldOffset.x0 * 4),
          gpu.VertexAttribute(
              name: 'p1',
              format: gpu.VertexFormat.float32x2,
              offsetInBytes: InstanceFieldOffset.x1 * 4),
          gpu.VertexAttribute(
              name: 'p2',
              format: gpu.VertexFormat.float32x2,
              offsetInBytes: InstanceFieldOffset.x2 * 4),
          gpu.VertexAttribute(
              name: 'color',
              format: gpu.VertexFormat.float32x4,
              offsetInBytes: InstanceFieldOffset.r * 4),
          gpu.VertexAttribute(
              name: 'dash',
              format: gpu.VertexFormat.float32x4,
              offsetInBytes: InstanceFieldOffset.dashPeriod * 4),
        ],
```

Update the doc comment above it: it currently narrates the twelve-float
record and its `[kind, x0, y0, ...]` order. A doc that describes the old order
beside the new offsets is worse than no doc.

- [ ] **Step 6: Run everything**

```sh
cd packages/jet_cad_2d_flutter && flutter test
```
Expected: `test/gpu/instance_expander_test.dart`,
`test/gpu/collector_differential_test.dart`,
`test/gpu/geometry_collector_test.dart` and
`test/gpu/resident_pixel_differential_test.dart` **all fail** — the expander
reads `InstanceFieldOffset` live and its arithmetic is fine, but anything
asserting a float count or a byte size moves. **Repair every one of them in
this task.** A widening that leaves the suite red is not a completed task, and
the shader is not touched yet, so nothing here is blocked on the bundle.

- [ ] **Step 7: Commit**

```sh
git add packages/jet_cad_2d_flutter/lib packages/jet_cad_2d_flutter/test
git commit -m "feat(gpu): sixteen floats, and kind beside half-width for ES 100's eighth attribute"
```

---

