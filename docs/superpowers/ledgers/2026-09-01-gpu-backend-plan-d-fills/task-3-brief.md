### Task 3: The collector fills a circle at its outline's step count

**Files:**
- Modify: `lib/src/gpu/geometry_collector.dart:633-637`
- Test: `test/gpu/geometry_collector_test.dart`

**Interfaces:**
- Consumes: `writeFill`, `_flattenSteps`, `_residual`.
- Produces: `GeometryCollector.fillCircle` writing `steps` instances.

- [ ] **Step 1: Write the failing tests**

```dart
  test('a filled circle is a fan at the same step count as its own outline',
      () {
    // The fill and the stroke of the same circle must tessellate
    // identically, or the fill peeks out from under its own boundary at
    // some zoom. Both go through _flattenSteps; this asserts they agree
    // rather than that either equals a hardcoded number.
    const style = ResolvedStyle(
        argb: 0xFF224466,
        lineweightHundredths: 25,
        linetype: Handle.none,
        linetypeScale: 1);
    final residual = Transform2.translation(300, 90)
        .multiply(Transform2.rotation(-0.6))
        .multiply(Transform2.scale(1.35, 1.35));

    final outline = GeometryCollector(
        pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0)
      ..beginResidual(residual)
      ..circle(12, -5, 7.5, style)
      ..endResidual();
    // A closed run: `steps` segments and `steps` joins (the seam included).
    final chords = outline.instanceCount ~/ 2;

    final fill = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0)
      ..beginResidual(residual)
      ..fillCircle(12, -5, 7.5, style)
      ..endResidual();

    expect(fill.instanceCount, chords,
        reason: 'the fan and the outline must use one step count');
    expect(fill.skippedOps, 0);
  });

  test('the fan shares one centre and walks the rim in ascending angle', () {
    const style = ResolvedStyle(
        argb: 0xFF224466,
        lineweightHundredths: 25,
        linetype: Handle.none,
        linetypeScale: 1);
    final t = Transform2.translation(300, 90).multiply(Transform2.scale(2, 3));
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0)
      ..beginResidual(t)
      ..fillCircle(12, -5, 7.5, style)
      ..endResidual();

    final data = c.data;
    final centreX = t.a * 12 + t.c * -5 + t.e;
    final centreY = t.b * 12 + t.d * -5 + t.f;
    for (var i = 0; i < c.instanceCount; i++) {
      final o = i * kFloatsPerInstance;
      expect(data[o + InstanceFieldOffset.kind], kKindFill);
      expect(data[o + InstanceFieldOffset.x0], closeTo(centreX, 1e-3),
          reason: 'every triangle of a fan starts at the centre');
      expect(data[o + InstanceFieldOffset.y0], closeTo(centreY, 1e-3));
    }
    // Triangle 0's second corner is the rim at angle 0: (cx + r, cy).
    expect(data[InstanceFieldOffset.x1],
        closeTo(t.a * (12 + 7.5) + t.c * -5 + t.e, 1e-3));
    // Consecutive triangles share an edge: triangle i's third corner is
    // triangle i+1's second. A fan written out of order fails here.
    final o1 = kFloatsPerInstance;
    expect(data[o1 + InstanceFieldOffset.x1],
        closeTo(data[InstanceFieldOffset.x2], 1e-6));
    expect(data[o1 + InstanceFieldOffset.y1],
        closeTo(data[InstanceFieldOffset.y2], 1e-6));
  });

  test('a zero or negative radius fills nothing', () {
    const style = ResolvedStyle(
        argb: 0xFF224466,
        lineweightHundredths: 25,
        linetype: Handle.none,
        linetypeScale: 1);
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 1.0)
      ..beginResidual(Transform2.translation(3, 4))
      ..fillCircle(1, 1, 0, style)
      ..fillCircle(1, 1, -2, style)
      ..endResidual();
    expect(c.instanceCount, 0);
  });
```

- [ ] **Step 2: Run and watch them fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
```
Expected: `Expected: <N> Actual: <0>`.

- [ ] **Step 3: Implement**

```dart
  /// A triangle fan around the circle's centre, at the same step count
  /// [_flatten] would give the circle's own outline.
  ///
  /// **The shared `_flattenSteps` call is the point** (Ruling D5): a filled
  /// circle's silhouette is tessellated by the same expression as its own
  /// boundary stroke, so the two never disagree at any zoom. The rim starts
  /// at angle 0, i.e. `(cx + r, cy)`, exactly as
  /// `VerticesDrawSink.fillCircle` does.
  @override
  void fillCircle(double cx, double cy, double r, ResolvedStyle style) {
    if (r <= 0) return;
    final t = _residual;
    final deviceRadius = r * t.scaleMagnitude;
    if (deviceRadius <= 0) return;
    const theta = 2 * math.pi;
    final steps = _flattenSteps(deviceRadius, theta);
    // `style.argb` directly, never `_coveredArgb` -- Ruling D3.
    final argb = style.argb;
    final ccx = t.a * cx + t.c * cy + t.e;
    final ccy = t.b * cx + t.d * cy + t.f;
    var px = cx + r, py = cy;
    var dx = t.a * px + t.c * py + t.e, dy = t.b * px + t.d * py + t.f;
    _reserve(_instances + steps);
    for (var i = 1; i <= steps; i++) {
      final angle = theta * i / steps;
      px = cx + r * math.cos(angle);
      py = cy + r * math.sin(angle);
      final nx = t.a * px + t.c * py + t.e, ny = t.b * px + t.d * py + t.f;
      writeFill(_buffer, _instances,
          x0: ccx, y0: ccy, x1: dx, y1: dy, x2: nx, y2: ny, argb: argb);
      _instances++;
      dx = nx;
      dy = ny;
    }
  }
```

- [ ] **Step 4: Run**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
```
Expected: PASS.

- [ ] **Step 5: Full gate and commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git status --short
git add lib/src/gpu/geometry_collector.dart test/gpu/geometry_collector_test.dart
git commit -m "feat(gpu): the collector fans a filled circle at the outline's step count"
```

---

