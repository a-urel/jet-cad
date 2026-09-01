### Task 2: The collector fills a polygon

**Files:**
- Modify: `lib/src/gpu/geometry_collector.dart:625-631`
- Test: `test/gpu/geometry_collector_test.dart`

**Interfaces:**
- Consumes: `writeFill` and `kKindFill` from Task 1; `_reserve`, `_residual`.
- Produces: `GeometryCollector.fillPolygon` writing `triangles.length ~/ 3`
  instances; `skippedOps` no longer counts it.

**The reference, which this transcribes** (`vertices_draw_sink.dart:745-768`):
`triangles` triple-indexes into `points`' own point numbering, so each index
is doubled to reach the coordinate pair; each of the three points is
transformed by the residual as it is read; `triangles.isEmpty` returns; the
colour is `style.argb` directly.

- [ ] **Step 1: Write the failing tests**

Append to `test/gpu/geometry_collector_test.dart`:

```dart
  test('a fill polygon is one instance per triangle, in triangulation order',
      () {
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    // A non-identity, non-uniform, off-origin residual: the identity would
    // hide a transposed matrix element, which is the defect Plan A's
    // post-mortem names.
    c.beginResidual(Transform2.translation(120, -35)
        .multiply(Transform2.rotation(0.4))
        .multiply(Transform2.scale(1.7, 0.6)));
    c.fillPolygon(
        Float64List.fromList(<double>[0, 0, 10, 0, 10, 6, 0, 6]),
        4,
        Int32List.fromList(<int>[0, 1, 2, 0, 2, 3]),
        const ResolvedStyle(
            argb: 0xFF3366CC,
            lineweightHundredths: 25,
            linetype: Handle.none,
            linetypeScale: 1));
    c.endResidual();

    expect(c.instanceCount, 2);
    expect(c.skippedOps, 0, reason: 'a fill is drawn now, not counted');

    final data = c.data;
    for (var i = 0; i < 2; i++) {
      expect(data[i * kFloatsPerInstance + InstanceFieldOffset.kind],
          kKindFill);
      expect(data[i * kFloatsPerInstance + InstanceFieldOffset.halfWidth], 0.0);
    }

    // The residual, applied by hand to point 1 (10, 0), against the first
    // triangle's second corner. Computed here rather than read from the
    // collector so the assertion is an independent derivation.
    final t = Transform2.translation(120, -35)
        .multiply(Transform2.rotation(0.4))
        .multiply(Transform2.scale(1.7, 0.6));
    expect(data[InstanceFieldOffset.x1],
        closeTo(t.a * 10 + t.c * 0 + t.e, 1e-3));
    expect(data[InstanceFieldOffset.y1],
        closeTo(t.b * 10 + t.d * 0 + t.f, 1e-3));

    // Triangulation order: the second instance is (0, 2, 3), so its second
    // corner is point 2 (10, 6) and its third is point 3 (0, 6). A
    // collector that walked the triangle list backwards, or that sorted it,
    // fails here -- and draw order is emission order.
    final o = kFloatsPerInstance;
    expect(data[o + InstanceFieldOffset.x1],
        closeTo(t.a * 10 + t.c * 6 + t.e, 1e-3));
    expect(data[o + InstanceFieldOffset.x2],
        closeTo(t.a * 0 + t.c * 6 + t.e, 1e-3));
  });

  test('a fill keeps its own colour on a hairline layer', () {
    // The lineweight is sub-pixel, which is exactly what `_coveredArgb`
    // fades for a stroke. A fill must not fade: routing it through that
    // function would fade a filled room on a hairline layer.
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 1.0);
    c.beginResidual(Transform2.translation(5, 7));
    c.fillPolygon(
        Float64List.fromList(<double>[0, 0, 8, 0, 4, 9]),
        3,
        Int32List.fromList(<int>[0, 1, 2]),
        const ResolvedStyle(
            argb: 0xFF884422,
            lineweightHundredths: 1,
            linetype: Handle.none,
            linetypeScale: 1));
    c.endResidual();

    final data = c.data;
    expect(data[InstanceFieldOffset.a], closeTo(1.0, 1e-6),
        reason: 'a fill never goes through _coveredArgb');
    expect(data[InstanceFieldOffset.r], closeTo(0x88 / 255.0, 1e-6));
  });

  test('an empty triangulation writes nothing', () {
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 1.0);
    c.beginResidual(Transform2.translation(5, 7));
    c.fillPolygon(
        Float64List.fromList(<double>[0, 0, 8, 0, 4, 9]),
        3,
        Int32List(0),
        const ResolvedStyle(
            argb: 0xFF884422,
            lineweightHundredths: 25,
            linetype: Handle.none,
            linetypeScale: 1));
    c.endResidual();
    expect(c.instanceCount, 0);
  });

  test('a degenerate triangle is written, not dropped', () {
    // `VerticesDrawSink._emitTriangle` has no zero-area test, so neither
    // does this: matching the formula rather than the intention is what
    // keeps the two arms' instance lists identical. Both rasterisers drop
    // it at raster time instead.
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 1.0);
    c.beginResidual(Transform2.translation(5, 7));
    c.fillPolygon(
        Float64List.fromList(<double>[0, 0, 8, 0, 4, 9]),
        3,
        Int32List.fromList(<int>[0, 1, 1]),
        const ResolvedStyle(
            argb: 0xFF884422,
            lineweightHundredths: 25,
            linetype: Handle.none,
            linetypeScale: 1));
    c.endResidual();
    expect(c.instanceCount, 1);
  });
```

- [ ] **Step 2: Run them and watch them fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
```
Expected: `Expected: <2> Actual: <0>` on the first — `fillPolygon` still only
increments `_skipped`.

- [ ] **Step 3: Implement**

Replace `fillPolygon`'s body in `geometry_collector.dart`:

```dart
  /// One instance per triangle, in the triangulation's own order.
  ///
  /// **Read, never computed** — the triangulation was materialised by the
  /// command, the codec or undo, and `DraftPainter._drawFill` passes it
  /// through. This transcribes `VerticesDrawSink.fillPolygon`, including
  /// that `triangles` triple-indexes into `points`' *point* numbering, so
  /// each index is doubled to reach a coordinate pair.
  ///
  /// **`style.argb` directly, NOT `_coveredArgb`** (Ruling D3): a fill has no
  /// width to fade, and a fill entity's `ResolvedStyle` still carries a
  /// lineweight because the column is shared with strokes.
  ///
  /// **No degenerate-triangle test** (Ruling D6): the reference's
  /// `_emitTriangle` has none, and adding one here would make the two arms'
  /// instance lists differ on a triangulation that contains one.
  @override
  void fillPolygon(
      Float64List points, int count, Int32List triangles, ResolvedStyle style) {
    if (triangles.isEmpty) return;
    final t = _residual;
    final argb = style.argb;
    _reserve(_instances + triangles.length ~/ 3);
    for (var i = 0; i + 2 < triangles.length; i += 3) {
      final a = triangles[i], b = triangles[i + 1], c = triangles[i + 2];
      final ax = points[a * 2], ay = points[a * 2 + 1];
      final bx = points[b * 2], by = points[b * 2 + 1];
      final cx = points[c * 2], cy = points[c * 2 + 1];
      writeFill(_buffer, _instances,
          x0: t.a * ax + t.c * ay + t.e,
          y0: t.b * ax + t.d * ay + t.f,
          x1: t.a * bx + t.c * by + t.e,
          y1: t.b * bx + t.d * by + t.f,
          x2: t.a * cx + t.c * cy + t.e,
          y2: t.b * cx + t.d * cy + t.f,
          argb: argb);
      _instances++;
    }
  }
```

Update `skippedOps`' doc, which today names three ops:

```dart
  /// Ops this plan does not draw yet — `text` alone, since Plan D.
  ///
  /// Counted rather than ignored so a corpus that needs Plan E is visible as
  /// a number instead of as a missing picture.
  ///
  /// `circle` and `arc` stopped counting here in Plan B's Task 5; `point` in
  /// its Task 6; `fillPolygon` and `fillCircle` in Plan D's Tasks 2 and 3.
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
git commit -m "feat(gpu): the collector writes a pre-triangulated fill"
```

Expected during Step 5: `test/gpu/geometry_collector_test.dart`'s existing
*"the collector counts what it cannot draw"* test (if one asserts
`skippedOps == 3` on a corpus with a fill) goes red. Update its expectation
and its comment in the same commit — the number it asserts is now the text ops
alone.

---

