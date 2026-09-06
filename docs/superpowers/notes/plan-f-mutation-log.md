# Plan F's mutation log — Task 9

Fourteen mutations (M-F1..M-F14), plus the plan's original M-F10 (declared
equivalent, Ruling F7-a) and its replacement witness M-F10′, plus one
declared-equivalent spec mutation (E-F1), fired one at a time against the
Plan F tree on `plan-f/rebuild-and-band`, each from a `cp <file> <file>.bak`
backup made immediately before editing and restored the same way afterward.
No mutation was ever reverted with `git checkout --`. `git status --short`
was clean after every restore — this log is the only file this task's commit
carries.

All commands below ran from `packages/jet_cad_2d_flutter`, against widget or
unit test files as named per row (never the whole suite, except the final
gates).

Files mutated: `lib/src/gpu/resident_rebuilder.dart` (M-F1, M-F2, M-F3, M-F4,
M-F6, M-F7, M-F13), `lib/src/gpu/collection_frame.dart` (M-F5),
`lib/src/draft_canvas.dart` (M-F8, E-F1), `lib/src/gpu/text_patches.dart`
(M-F9, M-F10, M-F10′, M-F12), `lib/src/gpu/text_compositor.dart` (M-F11),
`lib/src/gpu/gpu_draw_backend.dart` (M-F14).

Two rulings made during execution supersede the brief's table and are
recorded inline at their rows: M-F6's witness is the `schedules` counter, not
`rebuilds`; M-F10 (the plan's original `.floor()` → `.round()` edit) is
EQUIVALENT and a replacement witness (M-F10′) is fired in its place.

---

## M-F1 — ignore the table revision counter

**File:** `lib/src/gpu/resident_rebuilder.dart`, `noteFrame`

**Diff applied:**

```diff
-    if (tablesRevision != c.tablesRevision) {
-      markDirty(RebuildTrigger.tables);
-    } else if (dpr != c.devicePixelRatio) {
+    if (dpr != c.devicePixelRatio) {
       markDirty(RebuildTrigger.devicePixelRatio);
     } else if (!banded) {
```

**Command:** `flutter test test/gpu/resident_rebuilder_test.dart test/gpu/draft_canvas_resident_test.dart`

**Verbatim output (tail):**

```
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: RebuildTrigger:<RebuildTrigger.tables>
  Actual: <null>
...
This was caught by the test expectation on the following line:
  .../test/gpu/resident_rebuilder_test.dart line 164
The test description was:
  the table revision counter triggers a rebuild, and the new collection carries the new revision
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: <2>
  Actual: <1>
...
This was caught by the test expectation on the following line:
  .../test/gpu/draft_canvas_resident_test.dart line 170
The test description was:
  a layer edit rebuilds, through the revision counter

Failing tests:
  .../test/gpu/draft_canvas_resident_test.dart: a layer edit rebuilds, through the revision counter
  .../test/gpu/resident_rebuilder_test.dart: the table revision counter triggers a rebuild, and the new collection carries the new revision
EXIT=1
```

**Restore:** `cp /tmp/mut.bak lib/src/gpu/resident_rebuilder.dart` — `git status --short` clean.

**Verdict: KILLED** — `pending` stays null where `tables` is expected
(`resident_rebuilder_test.dart`); `landed` reads 1 where 2 is expected
(`draft_canvas_resident_test.dart`), exactly as the brief predicts.

---

## M-F2 — ignore the `devicePixelRatio` trigger

**File:** `lib/src/gpu/resident_rebuilder.dart`, `noteFrame`

**Diff applied:**

```diff
     if (tablesRevision != c.tablesRevision) {
       markDirty(RebuildTrigger.tables);
-    } else if (dpr != c.devicePixelRatio) {
-      markDirty(RebuildTrigger.devicePixelRatio);
     } else if (!banded) {
```

**Command:** `flutter test test/gpu/resident_rebuilder_test.dart test/gpu/draft_canvas_resident_test.dart`

**Verbatim output (tail):**

```
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: RebuildTrigger:<RebuildTrigger.devicePixelRatio>
  Actual: <null>
...
This was caught by the test expectation on the following line:
  .../test/gpu/draft_canvas_resident_test.dart line 183
The test description was:
  a device pixel ratio change rebuilds, with the new ratio
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: RebuildTrigger:<RebuildTrigger.devicePixelRatio>
  Actual: <null>
...
This was caught by the test expectation on the following line:
  .../test/gpu/resident_rebuilder_test.dart line 179
The test description was:
  a device pixel ratio change triggers a rebuild whose half-widths follow it

Failing tests:
  .../test/gpu/draft_canvas_resident_test.dart: a device pixel ratio change rebuilds, with the new ratio
  .../test/gpu/resident_rebuilder_test.dart: a device pixel ratio change triggers a rebuild whose half-widths follow it
EXIT=1
```

**Restore:** `cp /tmp/mut.bak lib/src/gpu/resident_rebuilder.dart` — `git status --short` clean.

**Verdict: KILLED**, by exactly the named tests in both files: `pending`
stays null; `draft_canvas_resident_test.dart`'s `collection.devicePixelRatio`
would stay at the old ratio (unreached because `landed` itself never moves
past 1).

---

## M-F3 — read the watermark band against the reference scale, not the live scale

**File:** `lib/src/gpu/resident_rebuilder.dart`, `inBand`

**Diff applied:**

```diff
-    final ratio = camera.scale / c.collectionCamera.scale;
+    final ratio = c.collectionCamera.scale / c.collectionCamera.scale; // M-F3
```

**Command:** `flutter test test/gpu/resident_rebuilder_test.dart test/gpu/draft_canvas_resident_test.dart`

**Verbatim output (tail):**

```
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: RebuildTrigger:<RebuildTrigger.band>
  Actual: <null>
...
This was caught by the test expectation on the following line:
  .../test/gpu/draft_canvas_resident_test.dart line 203
The test description was:
  leaving the band rebuilds at the live scale; staying inside does not
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: RebuildTrigger:<RebuildTrigger.band>
  Actual: <null>
...
This was caught by the test expectation on the following line:
  .../test/gpu/resident_rebuilder_test.dart line 130
The test description was:
  the band is read as live over collection

Failing tests:
  .../test/gpu/draft_canvas_resident_test.dart: leaving the band rebuilds at the live scale; staying inside does not
  .../test/gpu/resident_rebuilder_test.dart: the band is read as live over collection
EXIT=1
```

**Restore:** `cp /tmp/mut.bak lib/src/gpu/resident_rebuilder.dart` — `git status --short` clean.

**Verdict: KILLED**, by exactly the named tests: `ratio` is forced to `1.0`
by construction, so no camera ever reads as out of band and `pending` stays
null where `band` is expected.

---

## M-F4 — leave the resident text list stale across a rebuild

**File:** `lib/src/gpu/resident_rebuilder.dart`, `rebuildNow`

**Diff applied:**

```diff
     rebuilds++;
     final total = Stopwatch()..start();
-    final next = ResidentCollection.collect(
+    final walked = ResidentCollection.collect(
         document: document,
         painter: painter,
         live: camera,
         devicePixelRatio: dpr,
         pixelsPerPaperMm: pixelsPerPaperMm,
         lineweightScale: lineweightScale,
         measurer: measurer,
         textStyleOf: textStyleOf,
         bandLowerScale: bandLowerScale);
+    // M-F4: the resident text list left stale across a rebuild.
+    final next = ResidentCollection(
+      data: walked.data,
+      instanceCount: walked.instanceCount,
+      texts: _collection?.texts ?? walked.texts,
+      patches: walked.patches,
+      collectionCamera: walked.collectionCamera,
+      collectionViewport: walked.collectionViewport,
+      devicePixelRatio: walked.devicePixelRatio,
+      tablesRevision: walked.tablesRevision,
+      skippedOps: walked.skippedOps,
+      walkMicros: walked.walkMicros,
+      classifyMicros: walked.classifyMicros,
+    );
     final upload = Stopwatch()..start();
```

**Command:** `flutter test test/gpu/resident_rebuilder_test.dart`

**Verbatim output (tail):**

```
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: contains 'EDITED'
  Actual: ['COVERED', 'UNDER', 'GRAZED', 'TINY']
   Which: does not contain 'EDITED'
...
This was caught by the test expectation on the following line:
  .../test/gpu/resident_rebuilder_test.dart line 207
The test description was:
  an edited label draws the new string: the text list is not stale across a rebuild

Failing tests:
  .../test/gpu/resident_rebuilder_test.dart: an edited label draws the new string: the text list is not stale across a rebuild
EXIT=1
```

**Restore:** `cp /tmp/mut.bak lib/src/gpu/resident_rebuilder.dart` — `git status --short` clean.

**Verdict: KILLED**, by exactly the named test: `texts` still contains
`'COVERED'` and lacks `'EDITED'`, exactly as ruled.

---

## M-F5 — cull the collection to the live viewport (panning reveals an empty buffer)

**File:** `lib/src/gpu/collection_frame.dart`, `collectionFrameFor`

**Diff applied:**

```diff
 CollectionFrame collectionFrameFor(ViewportTransform live, Aabb2 extents,
     {double margin = kScreenClipInflate}) {
+  return CollectionFrame(live, const Size(800, 600)); // M-F5
   if (extents.isEmpty) return CollectionFrame(live, const Size(1, 1));
```

**Command 1:** `flutter test test/gpu/resident_collection_test.dart`

**Verbatim output (tail):**

```
00:00 +1 -1: a collection at the corner zoom holds everything the fit one holds [E]
  Expected: <14>
    Actual: <0>
  this fixture has no curve, so the instance count is scale-free; a difference is culling

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/resident_collection_test.dart 71:5         main.<fn>

00:00 +1 -2: the collection camera differs from the live camera by a translation [E]
  Expected: a value greater than <800.0>
    Actual: <800.0>
     Which: is not a value greater than <800.0>
  at 8x the extents are wider than the live viewport

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/resident_collection_test.dart 89:5         main.<fn>

Failing tests:
  .../test/gpu/resident_collection_test.dart: a collection at the corner zoom holds everything the fit one holds
  .../test/gpu/resident_collection_test.dart: the collection camera differs from the live camera by a translation
EXIT=1
```

**Command 2:** `flutter test test/gpu/zoom_defect_test.dart`

**Verbatim output (tail):**

```
00:00 +1 -1: zoom out, twelve steps of 0.94 the resident arm leaves nothing uncovered at any frame [E]
  Expected: a value less than or equal to <4>
    Actual: <926>
     Which: is not a value less than or equal to <4>
  CompositedAgreement(agreement=0.95370 withinTwo=19074 union=20000 overEight=926 uncovered=926 referenceInk=20000 patches=0)

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/zoom_defect_test.dart 74:9                 main.<fn>.<fn>.frame

Failing tests:
  .../test/gpu/zoom_defect_test.dart: zoom out, twelve steps of 0.94 the resident arm leaves nothing uncovered at any frame
EXIT=1
```

**Command 3:** `flutter test test/gpu/band_sweep_test.dart`

**Verbatim output (tail):**

```
BAND reported: [1.0, 1.0] = 1.00x  (curves and text-lod limit it; straight: [0.25, 4.0])
00:00 +5: All tests passed!
EXIT=0
```

**Restore:** `cp /tmp/mut.bak lib/src/gpu/collection_frame.dart` — `git status --short` clean.

**Verdict: KILLED**, decisively, by the first two witnesses:
`resident_collection_test.dart`'s corner camera loses every instance
(14 → 0) and `zoom_defect_test.dart`'s resident zoom-out leaves 926 pixels
uncovered on the first step, both matching the ruling's prediction.

**Note on the third witness, `band_sweep_test.dart` (investigated, not
chased with a wider mutation):** it stays green under this mutation. Every
`sweep()` call in that file uses `_size = Size(800, 600)` both as the live
viewport passed to `measureCompositedAgreement` and, via
`collectionFrameFor`, as the collection's own viewport — under M-F5 the
mutated `collectionFrameFor` returns exactly `Size(800, 600)` too, so the
hardcoded mutant value coincides with this file's own fixture size. The
`collection` camera each test sweeps from is `ViewportTransform.fit(doc.extents,
_size)`, i.e. already sized so the whole document sits inside an 800x600
viewport at that scale; the mutation's dropped margin shift
(`kScreenClipInflate`) is a few logical pixels against a fitted drawing, not
enough to move any measured pixel past criterion 1's tolerance. So nothing in
this file's fixtures ever asks the frame to cull anything the un-mutated
frame would not also have included — the coincidence of the hardcoded size
with `_size`, plus every corpus here being viewed at its own fit camera,
masks the defect this witness was meant to catch. The other two witnesses
kill the mutation outright; this is recorded as a coincidental miss, the same
class of judgment call `plan-e-mutation-log.md` makes for M-E3/M-E4/M-E6/M-E10.

---

## M-F6 — coalescing: drop `markDirty`'s early return

**File:** `lib/src/gpu/resident_rebuilder.dart`, `markDirty`

**Corrected witness (Ruling, supersedes the brief):** the brief's table names
`rebuilds` 4 where 2; the actual counter this mutation moves is `schedules`
— `resident_rebuilder_test.dart`'s "three marks before the frame ends are one
rebuild" test asserts `r.schedules == 2`. Under the mutation, `schedules`
reads 4 while `rebuilds` stays 2 (`_run`'s own pending re-check absorbs the
extra callbacks).

**Diff applied:**

```diff
     if (_disposed || _uploadFailed) return;
     _pending ??= trigger;
-    if (_inFlightTrigger != null || _scheduled) return;
-    _schedule();
+    // M-F6: the coalescing early return removed.
+    _schedule();
```

**Command:** `flutter test test/gpu/resident_rebuilder_test.dart`

**Verbatim output (tail):**

```
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: <2>
  Actual: <4>
one schedule for initial, one for the three coalesced marks
...
This was caught by the test expectation on the following line:
  .../test/gpu/resident_rebuilder_test.dart line 87
The test description was:
  three marks before the frame ends are one rebuild, named for the first

Failing tests:
  .../test/gpu/resident_rebuilder_test.dart: three marks before the frame ends are one rebuild, named for the first
EXIT=1
```

**Restore:** `cp /tmp/mut.bak lib/src/gpu/resident_rebuilder.dart` — `git status --short` clean.

**Verdict: KILLED**, exactly on the corrected witness: `schedules` Expected
2, Actual 4.

---

## M-F7 — pull the rebuild onto the frame path

**File:** `lib/src/gpu/resident_rebuilder.dart`, `noteFrame`

**Diff applied:**

```diff
     final c = _collection;
     if (c == null) {
-      markDirty(RebuildTrigger.initial);
+      // M-F7: the rebuild pulled onto the frame path.
+      unawaited(rebuildNow(camera, viewport, dpr, RebuildTrigger.initial));
       return;
     }
```

**Command:** `flutter test test/gpu/resident_rebuilder_test.dart`

**Verbatim output (tail):**

```
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: RebuildTrigger:<RebuildTrigger.initial>
  Actual: <null>
...
This was caught by the test expectation on the following line:
  .../test/gpu/resident_rebuilder_test.dart line 59
The test description was:
  the first frame marks initial and does not walk; the post-frame callback does
════════════════════════════════════════════════════════════════════════════════════════════════════
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: true
  Actual: <false>
...
This was caught by the test expectation on the following line:
  .../test/gpu/resident_rebuilder_test.dart line 236
The test description was:
  a painter that lands after dispose is disposed, not installed

Failing tests:
  .../test/gpu/resident_rebuilder_test.dart: a painter that lands after dispose is disposed, not installed
  .../test/gpu/resident_rebuilder_test.dart: the first frame marks initial and does not walk; the post-frame callback does
  .../test/gpu/resident_rebuilder_test.dart: three marks before the frame ends are one rebuild, named for the first
EXIT=1
```

**Restore:** `cp /tmp/mut.bak lib/src/gpu/resident_rebuilder.dart` — `git status --short` clean.

**Verdict: KILLED**, by exactly the named test ("the first frame marks
initial and does not walk"): `pending` stays null (the walk already fired
synchronously) where `RebuildTrigger.initial` is expected, and `rebuilds` is
already 1 before the pump. Two further tests fail as a consequence of the
same pulled-forward walk.

---

## M-F8 — drop the once-per-process latch

**File:** `lib/src/draft_canvas.dart`, `_reportResidentFallback`

**Diff applied:**

```diff
   static void _reportResidentFallback(String message) {
-    if (_residentFallbackReported) return;
+    // M-F8: the once-per-process latch removed.
     _residentFallbackReported = true;
```

**Command:** `flutter test test/gpu/draft_canvas_fallback_test.dart`

**Verbatim output (tail):**

```
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: null
  Actual: FlutterError:<DraftCanvas was asked for RenderBackend.residentGpu, but this platform has
no Flutter GPU (gpuAvailable() is false). Drawing through VerticesDrawSink instead. Reported once
per process.>
once per process
...
This was caught by the test expectation on the following line:
  .../test/gpu/draft_canvas_fallback_test.dart line 76
The test description was:
  no GPU: two canvases, vertices both, one report

Failing tests:
  .../test/gpu/draft_canvas_fallback_test.dart: no GPU: two canvases, vertices both, one report
EXIT=1
```

**Restore:** `cp /tmp/mut.bak lib/src/draft_canvas.dart` — `git status --short` clean.

**Verdict: KILLED**, by exactly the named test: a second pending exception
surfaces on the second canvas, where `t.takeException()` is expected to
return null (once per process).

---

## M-F9 — skip the grid's overflow list

**File:** `lib/src/gpu/text_patches.dart`, `classifyTextPatches`

**Diff applied:**

```diff
-    for (final i in overflow) {
-      if (i < t.instanceIndex) continue;
-      if (stats != null) stats.candidatesTested++;
-      if (_reaches(data, i, t, unitsPerDevicePixel)) hits.add(i);
-    }
+    // M-F9: the overflow list skipped.
     if (hits.isEmpty) continue;
```

**Command:** `flutter test test/gpu/classify_grid_test.dart`

**Verbatim output (tail):**

```
00:00 +1 -1: ... and on a generated corpus with hundreds of labels, overflow included [E]
  Expected: <160>
    Actual: <75>
  patch count

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/classify_grid_test.dart 35:3               expectSamePatches
  test/gpu/classify_grid_test.dart 109:5              main.<fn>

Failing tests:
  .../test/gpu/classify_grid_test.dart: ... and on a generated corpus with hundreds of labels, overflow included
EXIT=1
```

**Restore:** `cp /tmp/mut.bak lib/src/gpu/text_patches.dart` — `git status --short` clean.

**Verdict: KILLED**, by the generated-corpus differential: patch count 160
(brute force) vs 75 (grid), the long wall's overflow-list candidates missing
from their labels' patches.

---

## M-F10 — `.floor()` → `.round()` in `cellX`/`cellY` (**declared EQUIVALENT, Ruling F7-a**)

**File:** `lib/src/gpu/text_patches.dart`, `cellX`/`cellY`

**Diff applied:**

```diff
-  int cellX(double x) => ((x - uMinX) / cellW).floor().clamp(0, nx - 1);
-  int cellY(double y) => ((y - uMinY) / cellH).floor().clamp(0, ny - 1);
+  int cellX(double x) => ((x - uMinX) / cellW).round().clamp(0, nx - 1); // M-F10
+  int cellY(double y) => ((y - uMinY) / cellH).round().clamp(0, ny - 1); // M-F10
```

**Command:** `flutter test test/gpu/classify_grid_test.dart`

**Verbatim output (tail, GREEN as predicted):**

```
00:00 +0: grid and brute force agree byte for byte on the text-overlap fixture
00:00 +1: ... and on a generated corpus with hundreds of labels, overflow included
CLASSIFY grid=14.891 ms brute=28.525 ms instances=46550 labels=160 binned=45275 overflow=1 skipped=1274 tested=30965 cells=18x12
00:00 +2: no labels: an empty list, no grid built
00:00 +3: All tests passed!
EXIT=0
```

**Restore:** `cp /tmp/mut.bak lib/src/gpu/text_patches.dart` — `git status --short` clean.

**Verdict: EQUIVALENT** — one closure pair (`cellX`/`cellY`) serves both
binning and lookup, so a monotone shift of the whole grid by rounding instead
of flooring still bins every instance and looks up every label under the
exact same shifted partition, and stays conservative by construction. Fired
and its green run recorded, not skipped (spec: "Removed as equivalent, and
recorded rather than deleted").

---

## M-F10′ — bin by the min corner only (`cx1 = cx0`), the replacement witness

**File:** `lib/src/gpu/text_patches.dart`, `classifyTextPatches`'s binning loop

**Diff applied:**

```diff
-    final cx0 = cellX(box[0]), cx1 = cellX(box[2]);
+    final cx0 = cellX(box[0]);
+    var cx1 = cellX(box[2]);
+    cx1 = cx0; // M-F10': bin by the min corner only.
     final cy0 = cellY(box[1]), cy1 = cellY(box[3]);
```

**Command:** `flutter test test/gpu/classify_grid_test.dart`

**Verbatim output (tail):**

```
00:00 +1 -1: ... and on a generated corpus with hundreds of labels, overflow included [E]
  Expected: <160>
    Actual: <80>
  patch count

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/classify_grid_test.dart 35:3               expectSamePatches
  test/gpu/classify_grid_test.dart 109:5              main.<fn>

Failing tests:
  .../test/gpu/classify_grid_test.dart: ... and on a generated corpus with hundreds of labels, overflow included
EXIT=1
```

**Restore:** `cp /tmp/mut.bak lib/src/gpu/text_patches.dart` — `git status --short` clean.

**Verdict: KILLED** — patch count 160 (brute force) vs 80 (grid): a
multi-cell instance is binned only into its min-corner cell, so a label whose
box overlaps its other cells never sees it as a candidate.

---

## M-F11 — invert the four-way viewport-rejection test

**File:** `lib/src/gpu/text_compositor.dart`, `paint`

**Diff applied:**

```diff
-        if (_bound[2] < 0 ||
-            _bound[0] > viewport.width ||
-            _bound[3] < 0 ||
-            _bound[1] > viewport.height) {
+        // M-F11: the four-way rejection inverted.
+        if (!(_bound[2] < 0 ||
+            _bound[0] > viewport.width ||
+            _bound[3] < 0 ||
+            _bound[1] > viewport.height)) {
```

**Command:** `flutter test test/gpu/text_compositor_viewport_test.dart test/gpu/text_order_test.dart`

**Verbatim output (tail, representative):**

```
00:00 +0 -1: /.../test/gpu/text_compositor_viewport_test.dart: labels outside the viewport are skipped on all four sides; inside and straddling are drawn [E]
  Expected: <2>
    Actual: <4>
  inside and straddleLeft

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/text_compositor_viewport_test.dart 107:5   main.<fn>

00:00 +1 -2: /.../test/gpu/text_order_test.dart: the composited picture matches the reference at scale 0.5 [E]
  Expected: a value greater than or equal to <0.995>
    Actual: <0.8913134704154427>
  spec criterion 1, per channel <= 2 on >= 99.5% of the union; scale 0.5: withinTwo=2124 union=2383 overEight=255
...
Failing tests:
  .../test/gpu/text_compositor_viewport_test.dart: labels outside the viewport are skipped on all four sides; inside and straddling are drawn
  .../test/gpu/text_order_test.dart: the composited picture matches the reference at scale 0.5
  .../test/gpu/text_order_test.dart: the composited picture matches the reference at scale 0.8
  .../test/gpu/text_order_test.dart: the composited picture matches the reference at scale 1.25
  ... and 2 more
EXIT=1
```

**Restore:** `cp /tmp/mut.bak lib/src/gpu/text_compositor.dart` — `git status --short` clean.

**Verdict: KILLED**, decisively — `drawParagraph` count moves 2 → 4 (the
wrong two draw, the right two are skipped) in
`text_compositor_viewport_test.dart`, and 5 of `text_order_test.dart`'s 7
composited-agreement rows drop well below 0.995.

---

## M-F12 — `patchRegionFor` ignores the region pool

**File:** `lib/src/gpu/text_patches.dart`, `patchRegionFor`

**Diff applied:**

```diff
-  if (out == null) return PatchRegion(x0, y0, w, h);
-  out
-    ..x = x0
-    ..y = y0
-    ..width = w
-    ..height = h;
-  return out;
+  // M-F12: the region pool ignored, always a fresh instance.
+  return PatchRegion(x0, y0, w, h);
```

**Command:** `flutter test test/gpu/text_patches_test.dart`

**Verbatim output (tail):**

```
00:00 +16 -1: patchRegionFor patchRegionFor writes into `out` and leaves it alone when off screen [E]
  Expected: true
    Actual: <false>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/text_patches_test.dart 317:7               main.<fn>.<fn>

Failing tests:
  .../test/gpu/text_patches_test.dart: patchRegionFor patchRegionFor writes into `out` and leaves it alone when off screen
EXIT=1
```

**Restore:** `cp /tmp/mut.bak lib/src/gpu/text_patches.dart` — `git status --short` clean.

**Verdict: KILLED**, by exactly the named test: `identical(onScreen, out)`
reads false.

---

## M-F13 — drop the reschedule at the end of `_run`

**File:** `lib/src/gpu/resident_rebuilder.dart`, `_run`

**Diff applied:**

```diff
       _inFlightTrigger = null;
     }
-    if (!_disposed && _pending != null && !_uploadFailed) _schedule();
+    // M-F13: a mark during flight is dropped -- no reschedule.
   }
```

**Command:** `flutter test test/gpu/resident_rebuilder_test.dart`

**Verbatim output (tail):**

```
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: <3>
  Actual: <2>
...
This was caught by the test expectation on the following line:
  .../test/gpu/resident_rebuilder_test.dart line 110
The test description was:
  a mark during an upload in flight queues exactly one more

Failing tests:
  .../test/gpu/resident_rebuilder_test.dart: a mark during an upload in flight queues exactly one more
EXIT=1
```

**Restore:** `cp /tmp/mut.bak lib/src/gpu/resident_rebuilder.dart` — `git status --short` clean.

**Verdict: KILLED**, by exactly the named test: `rebuilds` reads 2 where 3
is expected.

---

## M-F14 — `buildFrameInfo` ignores `out`

**File:** `lib/src/gpu/gpu_draw_backend.dart`, `buildFrameInfo`

**Diff applied:**

```diff
-  final data = out != null && out.lengthInBytes == 80 ? out : ByteData(80);
+  final data = ByteData(80); // M-F14: `out` ignored.
```

**Command:** `flutter test test/gpu/frame_info_test.dart`

**Verbatim output (tail):**

```
00:00 +2 -1: buildFrameInfo buildFrameInfo writes into `out` when given one of the right size [E]
  Expected: true
    Actual: <false>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/frame_info_test.dart 163:7                 main.<fn>.<fn>

Failing tests:
  .../test/gpu/frame_info_test.dart: buildFrameInfo buildFrameInfo writes into `out` when given one of the right size
EXIT=1
```

**Restore:** `cp /tmp/mut.bak lib/src/gpu/gpu_draw_backend.dart` — `git status --short` clean.

**Verdict: KILLED**, by exactly the named test: `identical(written, out)`
reads false.

---

## E-F1 — rebuild only when `touched` is non-empty (**declared EQUIVALENT**)

**File:** `lib/src/draft_canvas.dart`, the `onChange` closure `_attach` installs
on `DocChangeNotifier`

**Diff applied:**

```diff
     _changes = DocChangeNotifier(widget.document, onChange: (change) {
       tileCache?.applyChange(change, widget.document);
-      resident?.markDirty(RebuildTrigger.document);
+      // E-F1: rebuild only when `touched` is non-empty, or the change is a
+      // whole-document replacement (`DocumentLoaded`) or a slot compaction
+      // (`DocumentPurged`) -- declared equivalent (see the mutation log).
+      if (change.touched.isNotEmpty ||
+          change is DocumentLoaded ||
+          change is DocumentPurged) {
+        resident?.markDirty(RebuildTrigger.document);
+      }
     });
```

**Command:** `flutter test test/gpu/draft_canvas_resident_test.dart`

**Verbatim output (tail, GREEN as declared):**

```
00:00 +0: the first frame paints through vertices; the landed rebuild paints through the backend
00:00 +1: every DocChange is a rebuild; a pan and a resize are not
00:00 +2: a layer edit rebuilds, through the revision counter
00:00 +3: a device pixel ratio change rebuilds, with the new ratio
00:00 +4: leaving the band rebuilds at the live scale; staying inside does not
00:00 +5: a re-attach replaces the rebuilder and leaves one table listener; an unmount leaves none
00:00 +6: All tests passed!
EXIT=0
```

**Restore:** `cp /tmp/mut.bak lib/src/draft_canvas.dart` — `git status --short` clean.

**Verdict: EQUIVALENT.** `spatial_index.dart:2283-2287` states that an empty
`touched` on a command is "defensive, not currently reachable" — every
`CommandApplied`/`CommandUndone`/`CommandRedone` this codebase actually
produces carries a non-empty `touched`, so the guard's first disjunct is
always true on those three variants. `DocumentLoaded` and `DocumentPurged`
carry no `touched` at all (`DocChange`'s default is `const {}`) and are
routed on type instead, which is exactly what the guard's other two
disjuncts do. "Every DocChange is a rebuild" therefore stays green: nothing
in this codebase's `DocChange` stream can reach the guard's else branch.
Fired and its green run recorded, not skipped, per the same "recorded rather
than deleted" rule M-F10 follows.

---

## Summary

**14 named mutations (M-F1..M-F14) plus M-F10′ fired: 14 of 15 killed on the
first shot, one coincidental miss on a secondary witness (see M-F5's note,
not a survivor of the mutation as a whole — killed decisively by its other
two witnesses). Two mutations (the plan's original M-F10, and the spec's
E-F1) were declared equivalent ahead of time and fired to confirm and record
their green runs, per spec ("Removed as equivalent, and recorded rather than
deleted"). Zero true survivors.**

| id | verdict |
|---|---|
| M-F1 | KILLED — `pending` null where `tables` expected; `landed` 1 where 2 |
| M-F2 | KILLED — `pending` null where `devicePixelRatio` expected |
| M-F3 | KILLED — `pending` null where `band` expected |
| M-F4 | KILLED — `texts` still contains `'COVERED'`, lacks `'EDITED'` |
| M-F5 | KILLED — `resident_collection_test.dart` (14→0 instances at the corner) and `zoom_defect_test.dart` (926 pixels uncovered). `band_sweep_test.dart` did not additionally fire — see note above |
| M-F6 | KILLED — `schedules` Expected 2, Actual 4 (corrected witness, supersedes the brief's `rebuilds`) |
| M-F7 | KILLED — `pending` null and `rebuilds` already 1 before the pump |
| M-F8 | KILLED — a second pending exception where none is expected |
| M-F9 | KILLED — patch count 160 (brute force) vs 75 (grid) |
| M-F10 | EQUIVALENT (Ruling F7-a) — fired, green run recorded |
| M-F10′ | KILLED — patch count 160 (brute force) vs 80 (grid) |
| M-F11 | KILLED — `drawParagraph` count 2→4; 5 of 7 `text_order_test.dart` rows fail |
| M-F12 | KILLED — `identical(onScreen, out)` false |
| M-F13 | KILLED — `rebuilds` 2 where 3 expected |
| M-F14 | KILLED — `identical(written, out)` false |
| E-F1 | EQUIVALENT (spec-declared) — fired, green run recorded |

### M-F5's third witness, investigated rather than chased

`band_sweep_test.dart` stays green under M-F5 because every one of its
`sweep()` calls fits the whole document inside an 800x600 viewport at the
`collection` camera it sweeps from, and 800x600 is also the mutation's
hardcoded return size — the coincidence masks the cull the mutation actually
introduces. The other two named witnesses
(`resident_collection_test.dart`, `zoom_defect_test.dart`) kill the mutation
decisively and independently, so this is recorded as a coincidental miss on
one witness, not a survivor of M-F5 as a whole — the same class of judgment
call `plan-e-mutation-log.md` records for M-E3, M-E4, M-E6 and M-E10.

### The gate, on the fully restored tree

See Step 4's transcripts in the task report for the three packages'
`test` / `analyze` / `format` runs, all green on the restored tree.
