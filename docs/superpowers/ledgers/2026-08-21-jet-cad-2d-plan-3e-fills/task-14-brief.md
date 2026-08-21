## Task 14: Goldens and the opaque agreement floor

**Files:**
- Create: `packages/jet_cad_2d_flutter/test/golden/fill_ladder_golden_test.dart`
- Create: `packages/jet_cad_2d_flutter/test/golden/fill_ladder_*.png` and `vertices/fill_ladder_*.png`
- Modify: `packages/jet_cad_2d_flutter/test/support/sink_comparison.dart` (fill fixtures)
- Modify: `packages/jet_cad_2d_flutter/test/sink_comparison_test.dart`

**Interfaces:**
- Consumes: everything through Task 13.
- Produces: three fill goldens per backend, and one opaque agreement row.

**The fixture is the deliverable, not the PNGs.** It must carry, in one drawing: an **L-shaped** boundary (concave — a fan would fill the notch), a **clockwise** boundary (winding normalisation), a **circle** boundary (the un-cached path), a fill whose colour **differs** from its boundary's (so covering is visible), and a fill on a **hairline** layer (so `_coveredArgb` cannot hide). Every one of those is a mutant from an earlier task that a normal-looking fixture would let through.

**The opaque agreement threshold, declared:**

> `strayVerticesPixels` and `uncoveredCanvasPixels` must each be **at most 1 %** of `canvasInkPixels`, and `canvasInkPixels` must exceed **4000** so the row cannot pass against a near-blank surface.

- [ ] **Step 1: Write the fixture and the failing golden test**

Follow `dash_ladder_golden_test.dart` exactly — `_at()` plus `matchesGoldenFile`
for canvas, `TriangleRasterizer` at **device** resolution plus
`matchesGoldenFile` on the image for vertices, and the
`key.currentState!.vertices!.devicePixelRatio == dpr` assertion, which
`--update-goldens` cannot absorb.

Three rungs at half-spans `60.0`, `400.0`, `4000.0`.

- [ ] **Step 2: Run and watch it fail**

Run: `cd packages/jet_cad_2d_flutter && flutter test --tags golden`
Expected: FAIL — no golden files exist yet.

- [ ] **Step 3: Generate the goldens and look at them**

```sh
flutter test --tags golden --update-goldens
```

**Open all six PNGs.** A golden accepted without being looked at pins whatever
the code did, including nothing — Plan 3d shipped two blank goldens that passed
under a renderer emitting no geometry. The non-vacuity assertion
(`rasterizer.pixels.any((p) => p != 0)`) is required, not optional.

- [ ] **Step 4: Add the opaque agreement row**

```dart
testWidgets('the two sinks agree on an opaque fill', (tester) async {
  final report = await measureAgreement(tester, fillComparisonDoc(), drawAll);
  expect(report.canvasInkPixels, greaterThan(4000),
      reason: 'non-vacuity: this row must not pass against a near-blank '
          'surface');
  expect(report.strayVerticesPixels,
      lessThanOrEqualTo(report.canvasInkPixels ~/ 100));
  expect(report.uncoveredCanvasPixels,
      lessThanOrEqualTo(report.canvasInkPixels ~/ 100));
});
```

- [ ] **Step 5: Run the named mutations**

```sh
# T14a: fan the polygon from vertex 0 instead of ear-clipping
#       -> the L-shaped rung must red on BOTH backends
# T14b: skip winding normalisation
#       -> the clockwise rung must red
# T14c: route the fill through _coveredArgb
#       -> the hairline rung must red on the vertices backend only
```

If T14a reds only the vertices rung, the canvas golden is not exercising the
notch and the fixture is wrong.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d_flutter/test/golden packages/jet_cad_2d_flutter/test/support \
        packages/jet_cad_2d_flutter/test/sink_comparison_test.dart
git commit -m "test: fill goldens on both backends, and the opaque floor"
```

---

