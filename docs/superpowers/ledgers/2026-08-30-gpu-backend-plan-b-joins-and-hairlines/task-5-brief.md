### Task 5: `circle()` and `arc()`

**Files:**
- Modify: `lib/src/gpu/geometry_collector.dart`
- Test: `test/gpu/geometry_collector_test.dart`

**Interfaces:**
- Consumes: the run state machine (Task 4).
- Produces: `GeometryCollector.circle` and `.arc` emit flattened runs;
  `skippedOps` no longer counts them.

Ruling B1 above is the authority for this task being here. Two further facts an
implementer needs:

- **Flattening happens in the residual's *local* space, and only the chord
  *count* is a device-space decision.** The reference's `_flatten` doc says
  why: *"the residual may be non-uniform, and the arc that `Canvas` would draw
  under it is an ellipse. Flattening here and transforming each point
  reproduces that ellipse; flattening a device-space circle would not."*
- **This is the first op in the collector that receives a general-affine
  residual.** `draft_painter.dart:568` pushes `camera ∘ placement` for circles
  and arcs, where polylines get only a translation. Plan A's transposition
  test was written for exactly this path.

- [ ] **Step 1: Write the failing tests**

```dart
  test('a circle is a closed run: N chords, N joins, seam last', () {
    // The chord count comes from the reference's own formula, recomputed
    // here rather than hardcoded, so the test tracks a tolerance change
    // instead of pinning today's number.
    const r = 50.0;
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.identity());
    c.circle(0, 0, r, const ResolvedStyle(argb: 0xFF000000, lineweightHundredths: 25));

    final steps = (2 *
            math.pi *
            math.sqrt(r / (8 * VerticesDrawSink.kFlattenTolerance)))
        .ceil()
        .clamp(1, VerticesDrawSink.kMaxFlattenSegments);
    // A closed run of `steps` chords: `steps` segments, `steps - 1` interior
    // joins, and the seam. 2 * steps instances.
    expect(c.instanceCount, 2 * steps);
    expect(c.skippedOps, 0, reason: 'a circle is no longer skipped');
    expect(
        c.data[(2 * steps - 1) * kFloatsPerInstance +
            InstanceFieldOffset.kind],
        kKindJoin,
        reason: 'the seam join is the last instance');
  });

  test('an arc is an open run and has no seam', () {
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.identity());
    c.arc(0, 0, 50, 0, math.pi / 2,
        const ResolvedStyle(argb: 0xFF000000, lineweightHundredths: 25));
    // An open run of `steps` chords is `steps` segments and `steps - 1`
    // joins: odd, and ending on a segment.
    expect(c.instanceCount.isOdd, isTrue);
    expect(
        c.data[(c.instanceCount - 1) * kFloatsPerInstance +
            InstanceFieldOffset.kind],
        kKindStroke,
        reason: 'an open run ends on a segment -- butt caps, no seam');
  });

  test('a non-uniform residual makes an ellipse, not a scaled circle', () {
    // The degenerate-fixture guard for this op. Under `scale(3, 1)` a circle
    // of radius 10 spans 60 in x and 20 in y; a collector that flattened in
    // device space and transformed the CENTRE only would give a circle of
    // some single radius, and every x-extent assertion below would fail.
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.beginResidual(const Transform2(3, 0, 0, 1, 0, 0));
    c.circle(0, 0, 10, const ResolvedStyle(argb: 0xFF000000, lineweightHundredths: 25));
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (var i = 0; i < c.instanceCount; i++) {
      final o = i * kFloatsPerInstance;
      if (c.data[o + InstanceFieldOffset.kind] != kKindStroke) continue;
      final x = c.data[o + InstanceFieldOffset.x0];
      final y = c.data[o + InstanceFieldOffset.y0];
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    expect(maxX - minX, closeTo(60, 0.5));
    expect(maxY - minY, closeTo(20, 0.5));
  });

  test('a zero or negative radius draws nothing', () {
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.identity());
    const style = ResolvedStyle(argb: 0xFF000000, lineweightHundredths: 25);
    c.circle(0, 0, 0, style);
    c.arc(0, 0, 10, 0, 0, style);
    expect(c.instanceCount, 0);
  });
```

Add `import 'dart:math' as math;` and the `VerticesDrawSink` import to the test
file if absent.

- [ ] **Step 2: Run and watch them fail**

```bash
cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
```

Expected: instance counts of 0 — `circle` and `arc` still only increment
`_skipped`.

- [ ] **Step 3: Implement**

Replace the `circle` and `arc` overrides and add the flattener:

```dart
  /// The chord error a flattened arc is allowed, in device pixels. The
  /// reference's own value, copied for the same reason
  /// [kMinStrokeDevicePixels] is: two independent implementations that agree
  /// are a differential test; one shared field is not.
  static const double kFlattenTolerance = 0.25;

  /// The chord ceiling, likewise copied.
  static const int kMaxFlattenSegments = 512;

  @override
  void circle(double cx, double cy, double r, ResolvedStyle style) =>
      _flatten(cx, cy, r, 0, 2 * math.pi, style, closed: true);

  @override
  void arc(double cx, double cy, double r, double start, double sweep,
          ResolvedStyle style) =>
      _flatten(cx, cy, r, start, sweep, style, closed: false);

  /// Walks a circular arc in the residual's **local** space, emitting a chord
  /// per step.
  ///
  /// Local space, not collection space, on purpose: the residual may be
  /// non-uniform, and the arc that `Canvas` would draw under it is an
  /// ellipse. Flattening here and transforming each point reproduces that
  /// ellipse; flattening a collection-space circle would not. Only the
  /// *count* is a scale decision, because the chord error the viewer sees is
  /// a pixel quantity.
  ///
  /// **This is the op that turns on the general-affine residual.**
  /// `draft_painter.dart:568` pushes `camera ∘ placement` here, where a
  /// polyline gets only a translation — the path Plan A's transposition test
  /// was written to guard and no Plan A fixture could reach.
  void _flatten(double cx, double cy, double r, double start, double sweep,
      ResolvedStyle style,
      {required bool closed}) {
    if (r <= 0 || sweep == 0) return;
    final t = _residual;
    final deviceRadius = r * t.scaleMagnitude;
    if (deviceRadius <= 0) return;

    final steps = _flattenSteps(deviceRadius, sweep.abs());
    final half = _halfWidthFor(style.lineweightHundredths);
    final argb = _coveredArgb(style.argb, style.lineweightHundredths);
    final step = sweep / steps;

    var lx = cx + r * math.cos(start);
    var ly = cy + r * math.sin(start);
    _beginRun(t.a * lx + t.c * ly + t.e, t.b * lx + t.d * ly + t.f);
    // A closed sweep stops one sample short: its last chord is the segment
    // `_endRun` draws back to the first point, so closing here would draw
    // that chord twice and leave the seam a duplicated point instead of a
    // join.
    final last = closed ? steps - 1 : steps;
    for (var i = 1; i <= last; i++) {
      final angle = start + step * i;
      lx = cx + r * math.cos(angle);
      ly = cy + r * math.sin(angle);
      _runTo(t.a * lx + t.c * ly + t.e, t.b * lx + t.d * ly + t.f, half, argb);
    }
    _endRun(closed: closed, half: half, argb: argb);
  }

  int _flattenSteps(double deviceRadius, double theta) {
    final ideal =
        (theta * math.sqrt(deviceRadius / (8 * kFlattenTolerance))).ceil();
    return ideal.clamp(1, kMaxFlattenSegments);
  }
```

- [ ] **Step 4: Run the tests**

```bash
cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
```

- [ ] **Step 5: Fire the mutation**

```bash
cd packages/jet_cad_2d_flutter
cp lib/src/gpu/geometry_collector.dart /tmp/gc.bak
# M-B4: flatten in collection space -- transform the centre, then walk the
# circle around it in collection space:
#   final ccx = t.a * cx + t.c * cy + t.e;
#   final ccy = t.b * cx + t.d * cy + t.f;
#   ... _runTo(ccx + deviceRadius * cos(angle), ccy + deviceRadius * sin(angle), ...)
flutter test test/gpu/geometry_collector_test.dart
cp /tmp/gc.bak lib/src/gpu/geometry_collector.dart
```

Expected: red on `a non-uniform residual makes an ellipse, not a scaled
circle` — both extents read 60.

- [ ] **Step 6: Gate and commit**

```bash
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
echo "exit=$?"
git add packages/jet_cad_2d_flutter
git commit -m "feat(gpu): the collector flattens circles and arcs, seam join included"
```

---

