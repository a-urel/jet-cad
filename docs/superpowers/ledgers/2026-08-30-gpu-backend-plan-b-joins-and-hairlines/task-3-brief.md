### Task 3: `_coveredArgb` — the hairline fade

**Files:**
- Modify: `lib/src/gpu/geometry_collector.dart`
- Test: `test/gpu/geometry_collector_test.dart`

**Interfaces:**
- Consumes: `writeStroke` (Task 2).
- Produces: `GeometryCollector` colours now match `VerticesDrawSink`'s
  including alpha, which **Task 9's pixel differential depends on**.

**This discharges a Plan A ruling.** The Plan A ledger, Task 3: *"the collector
writes `style.argb` unmodified while `VerticesDrawSink` fades sub-pixel strokes
through `_coveredArgb` … Plan A's own decomposition assigns the `_coveredArgb`
hairline alpha to Plan B, so the divergence is by design here. It is a
constraint on TASK 8, which compares the two arms: Task 8's fixture must keep
every lineweight above the hairline floor so the arms agree on colour."* That
constraint is lifted by this task, and Task 9's fixture is required to violate
it deliberately.

- [ ] **Step 1: Write the failing test**

Append to `test/gpu/geometry_collector_test.dart`:

```dart
  test('a sub-pixel stroke keeps its pixel and gives up alpha', () {
    // 0.05 mm at 3.7795275590551185 px/mm and dpr 1 is 0.189 device pixels --
    // under the one-pixel floor, so the reference fades it. The collector
    // must fade it by the same factor or the two arms disagree on colour on
    // every hairline layer, which is exactly what Task 9 rasterises.
    const dpr = 1.0;
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: dpr);
    final style = const ResolvedStyle(argb: 0xFF204060, lineweightHundredths: 5);
    c.polyline(Float64List.fromList(<double>[0, 0, 40, 0]), 2, style,
        closed: false);

    final deviceWidth = 5 / 100.0 * kLogicalPixelsPerMm * dpr;
    expect(deviceWidth, lessThan(1.0),
        reason: 'the fixture must actually be sub-pixel or this asserts nothing');
    final coverage = (deviceWidth * 2).clamp(0.0, 1.0);
    final expectedAlpha = (0xFF * coverage).round();

    final r = c.data;
    expect(r[InstanceFieldOffset.a] * 255.0, closeTo(expectedAlpha, 0.51));
    // The colour channels are untouched: `_coveredArgb` gives up alpha, it
    // does not darken. A implementation that multiplied the channels instead
    // would pass an alpha-only assertion.
    expect(r[InstanceFieldOffset.r] * 255.0, closeTo(0x20, 0.51));
    expect(r[InstanceFieldOffset.g] * 255.0, closeTo(0x40, 0.51));
    expect(r[InstanceFieldOffset.b] * 255.0, closeTo(0x60, 0.51));
    // And the width still floors at one device pixel: the fade replaces the
    // missing width, it does not accompany a thinner quad.
    expect(r[InstanceFieldOffset.halfWidth],
        closeTo(GeometryCollector.kMinStrokeDevicePixels / 2, 1e-6));
  });

  test('a stroke at or above one device pixel keeps full alpha', () {
    // The other side of the branch. Without this, deleting the
    // `deviceWidth >= kMinStrokeDevicePixels` guard -- fading *every* stroke
    // -- goes unnoticed.
    const dpr = 2.0;
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: dpr);
    final style =
        const ResolvedStyle(argb: 0xC0204060, lineweightHundredths: 25);
    c.polyline(Float64List.fromList(<double>[0, 0, 40, 0]), 2, style,
        closed: false);
    final deviceWidth = 25 / 100.0 * kLogicalPixelsPerMm * dpr;
    expect(deviceWidth, greaterThan(1.0),
        reason: 'the fixture must actually be above the floor');
    expect(c.data[InstanceFieldOffset.a] * 255.0, closeTo(0xC0, 0.51));
  });

  test('a zero lineweight is the hairline case and keeps full alpha', () {
    // `_coveredArgb`'s first branch: `deviceWidth <= 0` returns argb
    // unchanged. That is deliberate in the reference -- "A width of exactly
    // zero is the hairline case and keeps full alpha -- that is the first
    // branch there, not an omission" -- and a collector that clamped
    // coverage from 0 would draw every hairline entity invisible.
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.polyline(
        Float64List.fromList(<double>[0, 0, 40, 0]),
        2,
        const ResolvedStyle(argb: 0xFF112233, lineweightHundredths: 0),
        closed: false);
    expect(c.data[InstanceFieldOffset.a] * 255.0, closeTo(0xFF, 0.51));
  });
```

The file's existing imports need `import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart';`
if it is not already there, and `kLogicalPixelsPerMm` from the package barrel.
If the existing test file uses a different name for the paper scale, use that
one — do not add a second constant.

- [ ] **Step 2: Run it and watch it fail**

```bash
cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
```

Expected: the first test fails with the alpha reading 255 instead of the faded
value. The other two pass already (the collector writes full alpha
unconditionally today), which is fine — they exist to keep the fix from
overshooting.

- [ ] **Step 3: Implement**

Add to `GeometryCollector`, directly under `_halfWidthFor`:

```dart
  /// The colour a stroke of this width is actually drawn in.
  ///
  /// Mirrors `VerticesDrawSink._coveredArgb`, which mirrors Impeller's
  /// `Geometry::ComputeStrokeAlphaCoverage`. A stroke thinner than one device
  /// pixel keeps its pixel — [_halfWidthFor] floors the width — and gives up
  /// alpha in proportion, so thinning a line fades it out instead of stopping
  /// at one pixel and staying there.
  ///
  /// **A width of exactly zero keeps full alpha.** That is the hairline case,
  /// and it is the first branch rather than an omission — the reference says
  /// so in as many words.
  ///
  /// **This must never reach a fill.** `fillPolygon` and `fillCircle` pass
  /// `style.argb` directly in the reference, because a fill entity's
  /// `ResolvedStyle` still carries a lineweight from the shared column and
  /// *"routing a fill through `_coveredArgb` would fade a filled room on a
  /// hairline layer"*. Plan D adds those two ops; it inherits that rule.
  int _coveredArgb(int argb, int lineweightHundredths) {
    final deviceWidth = lineweightHundredths /
        100.0 *
        pixelsPerPaperMm *
        lineweightScale *
        devicePixelRatio;
    if (!deviceWidth.isFinite ||
        deviceWidth <= 0 ||
        deviceWidth >= kMinStrokeDevicePixels) {
      return argb;
    }
    final coverage = (deviceWidth * 2).clamp(0.0, 1.0);
    final alpha = (((argb >> 24) & 0xFF) * coverage).round();
    return (alpha << 24) | (argb & 0x00FFFFFF);
  }
```

and in `polyline`, replace `style.argb` at both `_emit` call sites with a
hoisted local computed once:

```dart
    final half = _halfWidthFor(style.lineweightHundredths);
    final argb = _coveredArgb(style.argb, style.lineweightHundredths);
```

- [ ] **Step 4: Run the test**

```bash
cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
```

Expected: all pass.

- [ ] **Step 5: Fire the mutation and record it**

```bash
cd packages/jet_cad_2d_flutter
cp lib/src/gpu/geometry_collector.dart /tmp/gc.bak
# M-B1: drop _coveredArgb from strokes.
#   In `polyline`, change the hoisted `argb` back to `style.argb`.
flutter test test/gpu/geometry_collector_test.dart
cp /tmp/gc.bak lib/src/gpu/geometry_collector.dart
```

Expected: red on `a sub-pixel stroke keeps its pixel and gives up alpha`.
Paste the failure text and the restored-file `git diff --stat` (which must be
empty for that file) into the report.

- [ ] **Step 6: Correct the stale doc**

`geometry_collector.dart`'s `kMinStrokeDevicePixels` doc calls
`VerticesDrawSink.kMinStrokeDevicePixels` *"a private implementation detail"*.
It is public, and Plan A Task 8's fix relies on that by reading it live. The
Plan A ledger carries this as a deferred minor. Fix the sentence.

While in the file, update `skippedOps`' doc: after Tasks 4-6 the skipped set is
`fillPolygon`, `fillCircle` and `text` — not *"arcs, circles, fills, text,
points"*. Write it as the post-Plan-B set and note that this task is landing
ahead of them; Task 6 verifies the sentence is true.

- [ ] **Step 7: Gate and commit**

```bash
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
echo "exit=$?"
git add packages/jet_cad_2d_flutter
git commit -m "feat(gpu): the collector fades sub-pixel strokes the way the reference does"
```

---

