### Task 6: `point()`

**Files:**
- Modify: `lib/src/gpu/geometry_collector.dart`
- Test: `test/gpu/geometry_collector_test.dart`

**Interfaces:**
- Consumes: `writePoint` (Task 2), `_coveredArgb` (Task 3).
- Produces: `GeometryCollector.point` emits one `kKindPoint` instance;
  `skippedOps` counts only `fillPolygon`, `fillCircle` and `text`.

- [ ] **Step 1: Write the failing test**

```dart
  test('a point is one instance of its own kind, at the transformed position',
      () {
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    // A general residual, so a collector that dropped the off-diagonal terms
    // lands somewhere else: (2*4 + 0.5*(-1) + 10, ...) is not (2*4 + 10, ...).
    c.beginResidual(const Transform2(2, 0.5, -1, 3, 10, 10));
    c.point(4, -1,
        const ResolvedStyle(argb: 0xFF336699, lineweightHundredths: 25));
    expect(c.instanceCount, 1);
    expect(c.skippedOps, 0);
    final r = c.data;
    expect(r[InstanceFieldOffset.kind], kKindPoint);
    // x = a*4 + c*(-1) + e = 8 + 1 + 10 = 19
    // y = b*4 + d*(-1) + f = 2 - 3 + 10 = 9
    expect(r[InstanceFieldOffset.x0], closeTo(19, 1e-4));
    expect(r[InstanceFieldOffset.y0], closeTo(9, 1e-4));
    // The unused slots stay zero: a point that reused x1/y1 as a second
    // endpoint would be a stroke wearing the wrong tag.
    expect(r[InstanceFieldOffset.x1], 0);
    expect(r[InstanceFieldOffset.y1], 0);
    expect(r[InstanceFieldOffset.x2], 0);
    expect(r[InstanceFieldOffset.y2], 0);
  });

  test('a point takes the hairline fade like a stroke', () {
    // `point()` routes through `_coveredArgb` in the reference. A dot on a
    // hairline layer fades with everything else on it.
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 1.0);
    c.point(0, 0,
        const ResolvedStyle(argb: 0xFF000000, lineweightHundredths: 5));
    expect(c.data[InstanceFieldOffset.a] * 255.0, lessThan(0xFF));
  });

  test('after Plan B, only fills and text are skipped', () {
    // The sentence in `skippedOps`' doc, asserted. It goes red the day
    // another op is silently dropped -- or the day Plan D lands and forgets
    // to update the doc.
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.identity());
    const style = ResolvedStyle(argb: 0xFF000000, lineweightHundredths: 25);
    c.polyline(Float64List.fromList(<double>[0, 0, 10, 10]), 2, style,
        closed: false);
    c.circle(0, 0, 20, style);
    c.arc(0, 0, 20, 0, 1, style);
    c.point(1, 1, style);
    expect(c.skippedOps, 0, reason: 'four ops Plan B draws');
    c.fillPolygon(Float64List.fromList(<double>[0, 0, 1, 0, 0, 1]), 3,
        Int32List.fromList(<int>[0, 1, 2]), style);
    c.fillCircle(0, 0, 5, style);
    c.text('x', Handle.none, style);
    expect(c.skippedOps, 3, reason: 'three ops Plans D and E draw');
  });
```

- [ ] **Step 2: Run and watch them fail**

```bash
cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
```

- [ ] **Step 3: Implement**

```dart
  /// A dot the width of the stroke.
  ///
  /// The reference draws it as a horizontal segment of the stroke's own
  /// width, which is a square of it (`vertices_draw_sink.dart`, `point`);
  /// here it is [kKindPoint] instead, because that `± half` is a **device**
  /// quantity and this record holds collection space. See [kKindPoint]'s doc.
  @override
  void point(double x, double y, ResolvedStyle style) {
    final t = _residual;
    _reserve(_instances + 1);
    writePoint(_buffer, _instances,
        x: t.a * x + t.c * y + t.e,
        y: t.b * x + t.d * y + t.f,
        halfWidth: _halfWidthFor(style.lineweightHundredths),
        argb: _coveredArgb(style.argb, style.lineweightHundredths));
    _instances++;
  }
```

- [ ] **Step 4: Run, gate, commit**

```bash
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
echo "exit=$?"
git add packages/jet_cad_2d_flutter
git commit -m "feat(gpu): point() is its own kind, not a baked horizontal stroke"
```

---

