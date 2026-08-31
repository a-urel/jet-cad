### Task 10: The gates — a declarative oracle, a pixel differential, and the one measurement that would have failed yesterday

**Files:**
- Create: `test/gpu/dash_differential_test.dart`
- Modify: `test/gpu/resident_pixel_differential_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 1–9.
- Produces: nothing. This task is the gate.

**The oracle must not be a transcription.** Plan B's Task 4 shipped an oracle
whose local variables were the collector's private field names minus the
underscore; it agreed with the implementation because it *was* the
implementation. The rule this task follows: **the expected instance list is
generated from indices and the pattern, with no run state machine, no
`hasDirection` flag and no "previous point" variable.**

```dart
/// What the collector must have written, derived from the inputs rather than
/// from the collector.
///
/// **No bookkeeping.** Transform the points, drop the zero-length steps, and
/// then read the answer off the indices: for a dashed open polyline of `n`
/// surviving points the instance list is
///
///     for i in 0 .. n-2:  for k in 0 .. D-1:  Stroke(p[i], p[i+1], k)
///
/// with no joins at all (Ruling C3), every phase 0 (`dasher.dart:94-96`) and
/// element k's extent taken from the cumulative sums of `|dashes|`. A dashed
/// arc is the same shape with joins interleaved and a running phase. Nothing
/// here can share a state-machine defect with the collector, because there is
/// no state machine.
List<_ExpectedInstance> expectedDashInstances(...) { ... }
```

- [ ] **Step 1: The record-level differential**

```dart
  test('the collector writes exactly the instances the rule produces, in '
      'order, for every dashed entity in the corpus', () {
    final doc = shadedDashFixture();
    final collector = GeometryCollector(
        pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    DraftPainter(
            document: doc, index: index, resolver: DocumentStyleResolver(doc))
        .paint(collector, camera, kViewport);

    final expected = expectedDashInstances(doc, camera);
    expect(collector.instanceCount, expected.length,
        reason: 'neither dropping nor duplicating an element');
    for (var i = 0; i < expected.length; i++) {
      expectInstanceMatches(collector.data, i, expected[i]);
    }
  });
```

**Before writing the implementation side of anything in this task, confirm this
test can fail.** Disable the dash fan in `_emit` (emit one instance regardless
of *D*), run it, and paste the *expected N vs actual M* line into the report. A
first-try green here proves nothing — Plan B lost a task to exactly that.

- [ ] **Step 2: Emission order, including the new axis**

```dart
  test('a primitive\'s elements are consecutive and in ascending cycle '
      'position', () {
    // Not merely "all D are present": a fan emitted in descending order, or
    // interleaved across primitives, draws the same pixels today and stops
    // doing so the moment a translucent dashed layer exists.
    for (final run in primitiveRuns(collector.data)) {
      expect(run.map((i) => fracStartOf(i)), isSorted);
    }
  });

  test('on a dashed arc the join still precedes its segment', () {
    // Plan B's ordering rule survives the fan: J(v)xD then S(i)xD.
  });

  test('order survives undo, redo, save, load and purge', () {
    // The same buffer, byte for byte, after each. This is the spec's
    // criterion 3 with a dashed corpus, which `differentialFixture` cannot
    // give it (Ruling C5).
    for (final mutate in <void Function(DraftDocument)>[...]) {
      expect(collectAfter(mutate), byteEquals(baseline));
    }
  });
```

- [ ] **Step 3: The pixel differential, with its vacuity control**

```dart
  test('the resident arm draws the dashed corpus the way the reference does', () {
    final r = measurePaintedAgreement(shadedDashFixture(),
        camera: camera,
        size: kViewport,
        devicePixelRatio: 2.0,
        pixelsPerPaperMm: 3.78);
    expect(r.differing, lessThan(r.referenceInk * 0.01));
    // The absolute floor matters as much as the ratio. Plan B shipped a gate
    // budgeting 81 differing pixels against a corpus whose entire join ink
    // was 26 -- a gate that could not fail. Record the corpus's DASH ink
    // here and require the budget to be a fraction of it.
    expect(r.differing, lessThan(dashGapPixels * 0.1),
        reason: 'the gap pixels are what this plan changed; a budget larger '
            'than them is a budget the change cannot fail');
  });

  test('the control: with the fragment dash test disabled, the same '
      'measurement blows the budget by more than 4x', () {
    // The gate above is only evidence if the instrument can see the defect
    // it is aimed at. This arm is the proof, run in the same test file, not
    // a claim in a report.
    final r = measurePaintedAgreement(..., debugDisableDashTest: true);
    expect(r.differing, greaterThan(dashGapPixels * 0.4));
  });
```

**`debugDisableDashTest` is a test-only flag on the rasterizer**, not on `lib/`.
Plan 3i's Ruling 14 is the precedent: an interleaved control arm that cannot be
switched on is an arm that reads 1.00 and proves nothing.

- [ ] **Step 4: The measurement that would have failed before this plan**

This is the criterion the whole plan exists for, and it is worth its own test
with its own name:

```dart
  test('the dash count follows the camera: four scales, four counts, each '
      'matching the reference painted at that same scale', () {
    // Before Plan C the resident arm drew the same number of dashes at every
    // scale, because the spans were cut once. This test fails on a buffer
    // built by Plan B's collector and passes on this one, which is the whole
    // claim, measured rather than argued.
    for (final ratio in <double>[0.5, 1.0, 2.0, 4.0]) {
      final live = cameraScaledBy(ratio);
      final reference = referenceInkAt(live);   // VerticesDrawSink, painted live
      final resident = residentInkAt(live);     // ONE buffer, collected at 1.0
      expect(drawnRunCount(resident), drawnRunCount(reference),
          reason: 'at ratio $ratio');
    }
  });
```

`drawnRunCount` counts maximal inked runs along the dashed entity's
centreline — a count of dashes, not a pixel total, so it fails loudly on a
pattern that stretched and only marginally on one that is a fraction of a pixel
out of phase.

**Note what this test does NOT gate: the arc chording divergence (Ruling C4).**
At ratios other than 1.0 the resident arc's sagitta grows as `0.25 × ratio` px
and its dash edges move with it. Run this test on the dashed **polyline** and
report the arc's numbers without a threshold — the band that would bound them
is Plan F's.

- [ ] **Step 5: Run everything, then commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git add packages/jet_cad_2d_flutter/test
git commit -m "test(gpu): the dash gates, and the control that proves they can fail"
```

---

