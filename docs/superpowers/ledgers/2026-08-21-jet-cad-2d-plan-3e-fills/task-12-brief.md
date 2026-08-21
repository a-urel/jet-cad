## Task 12: `VerticesDrawSink` fills

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart`
- Modify: `packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart`

**Interfaces:**
- Consumes: `fillPolygon` / `fillCircle` (Task 11).
- Produces: `frameTriangleCount` now includes fill triangles.

**Two invariants, both of which have a named mutant:**

1. **`_coveredArgb` must never see a fill's style.** It fades alpha in proportion to device *stroke* width, mirroring `Geometry::ComputeStrokeAlphaCoverage`. A fill entity's `ResolvedStyle` still carries `lineweightHundredths`, because the column is per-entity and shared. Route a fill through it and a filled room on a hairline layer fades **on the vertices backend only**, where the ink floor then hides the disagreement. Fills use `style.argb` directly.
2. **The circle fan uses the stroke's step count, not a similar one** — the identical expression, `(theta * math.sqrt(deviceRadius / (8 * kFlattenTolerance))).ceil()` clamped to `kMaxFlattenSegments`. A different count makes a filled circle's silhouette and its own outline disagree, and the disagreement changes with zoom.

- [ ] **Step 1: Write the failing tests**

```dart
test('a polygon fill emits exactly the triangles it was handed', () {
  final sink = harness();
  sink
    ..beginResidual(Transform2.identity)
    ..fillPolygon(square, 5, Int32List.fromList([0, 1, 2, 0, 2, 3]), opaque)
    ..endResidual();
  expect(sink.frameTriangleCount, 2);
});

test('a hairline fill keeps full alpha', () {
  // _coveredArgb fades a sub-pixel STROKE. A fill has no width, so a fill on a
  // hairline layer must not fade -- and it would fade on this backend only,
  // where the comparison harness's ink floor would then hide it.
  final sink = harness();
  const hairline = ResolvedStyle(argb: 0xFF3366CC, lineweightHundredths: 1);
  late Int32List colors;
  sink.observer = (_, c) => colors = Int32List.fromList(c);
  sink
    ..beginResidual(Transform2.identity)
    ..fillPolygon(square, 5, Int32List.fromList([0, 1, 2, 0, 2, 3]), hairline)
    ..endResidual();
  sink.flush();
  expect(colors.first.toUnsigned(32), 0xFF3366CC);
});

test('a filled circle and its own outline use the same step count', () {
  final filled = harness()
    ..beginResidual(Transform2.identity)
    ..fillCircle(0, 0, 90, opaque)
    ..endResidual();
  final stroked = harness()
    ..beginResidual(Transform2.identity)
    ..circle(0, 0, 90, opaque)
    ..endResidual();
  // A closed stroked run is 4 triangles per chord (quad + join); a fan is 1.
  expect(filled.frameTriangleCount * 4, stroked.frameTriangleCount,
      reason: 'a different step count makes the fill\'s silhouette and its '
          'outline disagree, and the disagreement changes with zoom');
});
```

- [ ] **Step 2: Run and watch them fail**

- [ ] **Step 3: Implement**

```dart
  @override
  void fillPolygon(Float64List points, int count, Int32List triangles,
      ResolvedStyle style) {
    if (triangles.isEmpty) return;
    final t = _residual;
    // `style.argb` directly, NOT `_coveredArgb`: that function fades a stroke
    // thinner than a device pixel, and a fill has no width. A fill entity's
    // ResolvedStyle still carries a lineweight because the column is shared,
    // so routing it through would fade a filled room on a hairline layer on
    // this backend only.
    final argb = style.argb;
    for (var i = 0; i < triangles.length; i += 3) {
      final a = triangles[i], b = triangles[i + 1], c = triangles[i + 2];
      _emitTriangle(
        t.a * points[a * 2] + t.c * points[a * 2 + 1] + t.e,
        t.b * points[a * 2] + t.d * points[a * 2 + 1] + t.f,
        t.a * points[b * 2] + t.c * points[b * 2 + 1] + t.e,
        t.b * points[b * 2] + t.d * points[b * 2 + 1] + t.f,
        t.a * points[c * 2] + t.c * points[c * 2 + 1] + t.e,
        t.b * points[c * 2] + t.d * points[c * 2 + 1] + t.f,
        argb,
      );
    }
  }

  @override
  void fillCircle(double cx, double cy, double r, ResolvedStyle style) {
    if (r <= 0) return;
    final t = _residual;
    final deviceRadius = r * t.scaleMagnitude;
    if (deviceRadius <= 0) return;
    // The SAME expression `_flatten` uses, not a similar one. A fill whose
    // silhouette is tessellated differently from its own outline shows a
    // sliver between them that changes with zoom.
    const theta = 2 * math.pi;
    final steps = (theta * math.sqrt(deviceRadius / (8 * kFlattenTolerance)))
        .ceil()
        .clamp(1, kMaxFlattenSegments);
    final argb = style.argb;
    final ccx = t.a * cx + t.c * cy + t.e;
    final ccy = t.b * cx + t.d * cy + t.f;
    var px = cx + r, py = cy;
    var dx = t.a * px + t.c * py + t.e, dy = t.b * px + t.d * py + t.f;
    for (var i = 1; i <= steps; i++) {
      final angle = theta * i / steps;
      px = cx + r * math.cos(angle);
      py = cy + r * math.sin(angle);
      final nx = t.a * px + t.c * py + t.e, ny = t.b * px + t.d * py + t.f;
      _emitTriangle(ccx, ccy, dx, dy, nx, ny, argb);
      dx = nx;
      dy = ny;
    }
  }
```

- [ ] **Step 4: Run and watch them pass**

- [ ] **Step 5: Run the named mutations**

```sh
cd packages/jet_cad_2d_flutter
F=lib/src/vertices_draw_sink.dart
cp "$F" /tmp/t12.dart
trap 'cp /tmp/t12.dart "$F"' EXIT
run() { flutter test test/vertices_draw_sink_test.dart >/dev/null 2>&1 && echo SURVIVED || echo KILLED; }

# T12a: route the fill through _coveredArgb
perl -0pi -e 's/    final argb = style\.argb;\n    for \(var i = 0; i < triangles\.length/    final argb = _coveredArgb(style.argb, style.lineweightHundredths);\n    for (var i = 0; i < triangles.length/' "$F"; run; cp /tmp/t12.dart "$F"
# T12b: give the fan its own step count
perl -0pi -e 's/    final steps = \(theta \* math\.sqrt\(deviceRadius \/ \(8 \* kFlattenTolerance\)\)\)\n        \.ceil\(\)\n        \.clamp\(1, kMaxFlattenSegments\);/    final steps = 32;/' "$F"; run; cp /tmp/t12.dart "$F"
# T12c: drop every third triangle
perl -0pi -e 's/    for \(var i = 0; i < triangles\.length; i \+= 3\) \{/    for (var i = 0; i < triangles.length; i += 6) {/' "$F"; run; cp /tmp/t12.dart "$F"
```

All three must print `KILLED`. **T12a is killed only by the hairline fixture.**

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart \
        packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart
git commit -m "feat: VerticesDrawSink fills, with the two invariants pinned"
```

---

