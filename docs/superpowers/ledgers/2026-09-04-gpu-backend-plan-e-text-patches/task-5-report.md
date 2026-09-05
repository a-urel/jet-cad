# Task 5 report: The composited differential, and the order gate

## Fix round 2: every `Picture` disposed (resource-leak finding)

Coordinator finding, quality (not a spec-compliance defect):
`measureCompositedAgreement` created at least 5 `PictureRecorder`s per call
(`refRecorder`, `outRecorder`, plus one per `triangles()` invocation -- the
main buffer and each patch) and disposed none of the returned `Picture`
objects, only the derived `Image`s -- inconsistent with this same file's
three prior functions (`measureResidentAgreement`, `measurePaintedAgreement`,
`measureResidentColor`), which all call `recorder.endRecording().dispose()`.

**What changed**, in `test/support/gpu_comparison.dart`, at all four
recorder sites in `measureCompositedAgreement`:
1. Reference arm: `refRecorder.endRecording()` is held as `refPicture`,
   `.toImage(w, h)` awaited into `refImage`, then `refPicture.dispose()`.
2. The shared `triangles()` local helper (covers **both** the main buffer's
   image and every patch's image, since both call sites go through it):
   `recorder.endRecording()` held as `picture`, `.toImage(...)` awaited into
   `image`, `picture.dispose()`, then `image` returned. This required making
   `triangles` an `async` function (it previously returned the `Future`
   from `.toImage(...)` directly without an `await` inside its own body) --
   the signature's line wrap changed accordingly but the parameter list is
   unchanged.
3. Output/compositor arm: `outRecorder.endRecording()` held as `outPicture`,
   `.toImage(w, h)` awaited into `outImage`, then `outPicture.dispose()`.

No doc comment needed correction: the file's doc comments never asserted
that pictures were left undisposed (that observation lived only in this
report's "self-review" section for round 1, which is not code and needed no
edit).

**Covering tests and command**, `flutter test test/gpu/text_order_test.dart`:
```
00:00 +0: the composited picture matches the reference at scale 0.5
00:00 +1: the composited picture matches the reference at scale 0.8
00:00 +2: the composited picture matches the reference at scale 1.25
00:00 +3: the composited picture matches the reference at scale 2.0
00:00 +4: with level of detail on, both arms cull TINY the same way at scale 1
00:00 +5: drawing all text in one pass -- no patches -- changes the picture
00:00 +6: the label nothing later reaches is not a patch, and still matches
00:00 +7: All tests passed!
```
7/7, unchanged from before this fix.

**Measured numbers, re-captured to confirm the fix is disposal-only and
changes no pixel** (same throwaway debug test as before, run again and
deleted before this diff):

| row | union | withinTwo | overEight | referenceInk | patchCount | agreement |
|---|---|---|---|---|---|---|
| scale 0.5 | 2383 | 2383 | 0 | 2383 | 2 | 1.0 |
| scale 0.8 | 5128 | 5128 | 0 | 5128 | 2 | 1.0 |
| scale 1.25 | 11071 | 11071 | 0 | 11071 | 2 | 1.0 |
| scale 2.0 | 21891 | 21891 | 0 | 21891 | 2 | 1.0 |
| LOD-on, scale 1 | 7398 | 7398 | 0 | 7398 | 2 | 1.0 |
| no-patch seam | 7398 | 6453 | 941 | 7398 | 0 | 0.8722627737226277 |
| patchCount row (scale 1) | 7398 | 7398 | 0 | 7398 | 2 | 1.0 |

Byte-identical to the round-1 fix report's table, as expected: disposing a
`Picture` after its `Image` has already been produced does not change any
pixel the comparison reads.

**Full package gate:**
```
$ flutter test
...
00:07 +614 ~1: All tests passed!
```
614 passing, 1 skipped (pre-existing, unrelated).
```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)
```
Exit code 0.
```
$ dart format --output=none --set-exit-if-changed .
Formatted 99 files (0 changed) in 0.15 seconds.
```
Exit code 0, no reformat needed.

`git status --short` before committing showed only
` M packages/jet_cad_2d_flutter/test/support/gpu_comparison.dart` -- no
`analysis_options.yaml` touched.

Committed as `a51e744 test(gpu): the composited instrument disposes every
Picture it records`.

## Fix round 1: Ruling R5-1 (anti-vacuity floor is per row)

The coordinator upheld the scale-0.5 `referenceInk` miss as a real finding,
not a threshold to relax generally, and issued Ruling R5-1: the
`referenceInk > 5000` anti-vacuity floor is calibrated on the scale-1
picture, and the four-scale band rows -- which run the corpus at a quarter
of that picture's area at the band's floor (scale 0.5) -- get their own,
lower floor instead. The 0.995 agreement threshold, `patchCount >= 1`,
`patchCount == 2`, and the no-patch seam's `overEight > 200` / `agreement <
0.995` are untouched.

**What changed**, in `test/gpu/text_order_test.dart`:
1. The four-scale loop's assertion changed from
   `expect(m.referenceInk, greaterThan(5000), reason: 'anti-vacuity')` to
   `expect(m.referenceInk, greaterThan(1000), reason: 'anti-vacuity -- the
   scale-1 floor of 5000 lives on the LOD-on row; this corpus at 0.5 is a
   quarter of that picture')`.
2. Added one sentence to the four-scale test's existing comment naming
   Ruling R5-1: "Ruling R5-1: the anti-vacuity floor is per row, not one
   constant across the band -- the scale-1 calibration of 5000 lives on the
   LOD-on row below, and each scale here gets its own floor instead."
3. The LOD-on, scale-1 test gained
   `expect(m.referenceInk, greaterThan(5000), reason: 'anti-vacuity at the
   scale the floor was calibrated on')` -- the 5000 floor moved here, where
   it was originally calibrated, rather than being dropped.

**referenceInk at every scale** (re-measured via the same throwaway debug
test used in the original report, run again and deleted before this diff;
identical to the original numbers, since the instrument
(`measureCompositedAgreement`) itself was not touched -- only the test
assertions moved):

| row | referenceInk |
|---|---|
| scale 0.5 | 2383 |
| scale 0.8 | 5128 |
| scale 1.25 | 11071 |
| scale 2.0 | 21891 |
| LOD-on, scale 1 | 7398 |

Every one of these clears its assigned floor: 2383, 5128, 11071 and 21891
all exceed the four-scale rows' new floor of 1000; 7398 exceeds the LOD-on
row's floor of 5000 (the original scale-1 calibration).

**Covering tests and command**, `flutter test test/gpu/text_order_test.dart`:
```
00:00 +0: the composited picture matches the reference at scale 0.5
00:00 +1: the composited picture matches the reference at scale 0.8
00:00 +2: the composited picture matches the reference at scale 1.25
00:00 +3: the composited picture matches the reference at scale 2.0
00:00 +4: with level of detail on, both arms cull TINY the same way at scale 1
00:00 +5: drawing all text in one pass -- no patches -- changes the picture
00:00 +6: the label nothing later reaches is not a patch, and still matches
00:00 +7: All tests passed!
```
7/7, as the ruling expected.

**Full package gate:**
```
$ flutter test
...
00:08 +614 ~1: All tests passed!
```
614 passing, 1 skipped (pre-existing, unrelated).
```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)
```
Exit code 0.
```
$ dart format --output=none --set-exit-if-changed .
Formatted 99 files (0 changed) in 0.15 seconds.
```
Exit code 0, no reformat needed this round.

`git status --short` before committing showed only
` M packages/jet_cad_2d_flutter/test/gpu/text_order_test.dart` -- no
`analysis_options.yaml` touched.

Committed as `93c332a test(gpu): the anti-vacuity floor is per row (Ruling
R5-1)`.

## What was implemented

- `test/support/gpu_comparison.dart`: added `CompositedAgreement` and
  `measureCompositedAgreement`, exactly per the brief's Step 3, with two
  deviations from the literal sample, both required for correctness and
  described below:
  1. **No unconditional white-background fill.** The brief's "Two things to
     expect" note offered a *conditional* fix ("if refImage comes back with
     an opaque white ground... draw a white rect first on both") for a
     `CanvasDrawSink` quirk that might or might not occur. I ran the plain
     version first (per TDD: RED, then the simplest GREEN) and both arms
     came back transparent where nothing painted — the quirk did not occur
     on this corpus/camera combination. I did not add the white-rect
     mitigation, because doing so unconditionally would have broken the
     ink-detection algorithm itself: `measureCompositedAgreement`'s
     per-pixel loop uses `getUint8(o + 3) != 0` (the alpha channel) to
     decide whether a pixel is "ink" at all. Filling the whole canvas with
     opaque white first would make every pixel's alpha 255, so `union`
     would become the entire frame and `referenceInk` the frame's pixel
     count regardless of what was actually drawn — silently defeating the
     anti-vacuity check and diluting the no-patch-seam mutation's
     `overEight`/`agreement` signal under a flood of matching background
     pixels. I documented that both pictures are recorded transparent and
     stay transparent where nothing paints, instead of the not-needed
     mitigation.
  2. Added disposal calls (`index.dispose()`, `refImage.dispose()`,
     `mainImage.dispose()`, each `PatchImage.image.dispose()`,
     `outImage.dispose()`) that the brief's inline sample omitted, matching
     `paintFillFixture`'s existing `index.dispose()` pattern in this same
     file. Left the intermediate `Picture` objects returned by
     `recorder.endRecording()` undisposed before `.toImage(...)` — this
     matches the established precedent in `test/gpu/text_compositor_test.dart`
     `_image()` (Task 4's own helper), which does the same
     `recorder.endRecording().toImage(...)` without holding a reference to
     dispose the intermediate `Picture`.
- `test/gpu/text_order_test.dart`: created verbatim from the brief's Step 1
  sample (unchanged).

## MEASURED numbers, every row

Captured via a temporary, uncommitted debug test that called
`measureCompositedAgreement` directly and printed every field (deleted
before the final commit; not part of the diff).

| row | union | withinTwo | overEight | referenceInk | patchCount | agreement |
|---|---|---|---|---|---|---|
| scale 0.5 | 2383 | 2383 | 0 | **2383** | 2 | 1.0 |
| scale 0.8 | 5128 | 5128 | 0 | 5128 | 2 | 1.0 |
| scale 1.25 | 11071 | 11071 | 0 | 11071 | 2 | 1.0 |
| scale 2.0 | 21891 | 21891 | 0 | 21891 | 2 | 1.0 |
| LOD-on, scale 1 | 7398 | 7398 | 0 | 7398 | 2 | 1.0 |
| no-patch seam | 7398 | 6453 | 941 | 7398 | 0 | 0.8723 |
| patchCount row (scale 1) | 7398 | 7398 | 0 | 7398 | 2 | 1.0 |

**One row misses a pre-committed threshold: scale 0.5's `referenceInk`
(2383) is below the anti-vacuity floor of 5000.** Everything else about that
row is perfect — `agreement == 1.0`, `patchCount == 2` — the miss is purely
that at the band's floor scale (the whole document shrunk to half size
around the viewport centre), the fitted-and-halved camera draws less total
ink than the 5000-pixel anti-vacuity floor asks for. This is the band-edge
case the brief's amendment explicitly anticipates ("If the miss is only at
0.5 and/or 2.0 and small, that is the band edge and it is a number to
record, per the plan"). Per the brief's rule I did not touch the threshold,
the fixture, or the test's camera construction to make it pass — the
instrument and the `text_order_test.dart` gate are committed with the real
number, and this row's test goes red as a result.

Every other assertion in every other row is a clean pass, including the
mutation seam: with patches discarded (`mutatePatches: (_) => const []`),
`overEight` jumps from 0 to 941 (`>200`, as required) and `agreement` drops
to 0.8723 (`<0.995`, as required) — Task 3's overlap guard is proven real by
this instrument, not merely asserted.

## TDD evidence

**RED** (Step 2, before `measureCompositedAgreement` existed):
```
$ flutter test test/gpu/text_order_test.dart
test/gpu/text_order_test.dart:45:23: Error: Method not found: 'measureCompositedAgreement'.
...
00:00 +0 -1: loading .../test/gpu/text_order_test.dart [E]
  Failed to load ".../test/gpu/text_order_test.dart":
  Compilation failed for testPath=.../test/gpu/text_order_test.dart: ... Method not found: 'measureCompositedAgreement'.
00:00 +0 -1: Some tests failed.
```

**GREEN, then the real (expected) MISS** (Step 4, after implementation):
```
$ flutter test test/gpu/text_order_test.dart
00:00 +0: the composited picture matches the reference at scale 0.5
00:00 +0 -1: the composited picture matches the reference at scale 0.5 [E]
  Expected: a value greater than <5000>
    Actual: <2383>
     Which: is not a value greater than <5000>
  anti-vacuity
  ...
00:00 +0 -1: the composited picture matches the reference at scale 0.8
00:00 +1 -1: the composited picture matches the reference at scale 1.25
00:00 +2 -1: the composited picture matches the reference at scale 2.0
00:00 +3 -1: with level of detail on, both arms cull TINY the same way at scale 1
00:00 +4 -1: drawing all text in one pass -- no patches -- changes the picture
00:00 +5 -1: the label nothing later reaches is not a patch, and still matches
00:00 +6 -1: Some tests failed.

Failing tests:
  .../test/gpu/text_order_test.dart: the composited picture matches the reference at scale 0.5
```
6 of 7 tests pass; the 7th (scale 0.5) fails on exactly the one
pre-committed threshold documented above, as a real number, not a bug —
implementation code matches the brief's Step 3 sample essentially verbatim
(see the two documented deviations above, neither of which touches the
scale-0.5 row's arithmetic).

## Gate commands and output

**`flutter test`** (full package suite, run after the implementation and
before formatting fix-up):
```
$ flutter test
...
00:07 +612 ~1 -1: /.../test/tile_slice_differential_test.dart: tile boundaries carry no difference of their own
Some tests failed.

Failing tests:
  .../test/gpu/text_order_test.dart: the composited picture matches the reference at scale 0.5
```
612 passing, 1 skipped (`~1`, pre-existing, unrelated to this task), 1
failing — the scale-0.5 anti-vacuity miss documented above. No other test in
the suite regressed.

**`flutter analyze`**:
```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.3s)
```
Exit code 0.

**`dart format --output=none --set-exit-if-changed .`**:
First run flagged `test/support/gpu_comparison.dart` as needing formatting
(`Formatted 99 files (1 changed)`, exit 1). Ran `dart format
test/support/gpu_comparison.dart test/gpu/text_order_test.dart`, then
re-checked:
```
$ dart format --output=none --set-exit-if-changed .
Formatted 99 files (0 changed) in 0.15 seconds.
```
Exit code 0.

Re-ran `flutter test test/gpu/text_order_test.dart` after formatting to
confirm the reformat changed nothing semantically — same 6-pass/1-miss
result as above.

## Files changed

- `packages/jet_cad_2d_flutter/test/support/gpu_comparison.dart` — modified,
  `CompositedAgreement` + `measureCompositedAgreement` appended.
- `packages/jet_cad_2d_flutter/test/gpu/text_order_test.dart` — created.

`git status --short` before committing:
```
 M test/support/gpu_comparison.dart
?? test/gpu/text_order_test.dart
```
No `analysis_options.yaml` touched; nothing else staged.

## Self-review

- **Completeness:** every test in the brief's Step 1 sample is present
  verbatim; `CompositedAgreement`'s five fields and `agreement` getter, and
  `measureCompositedAgreement`'s every parameter (including `mutatePatches`
  and `minTextCapPixels`'s default) match the brief's Step 3 signature.
- **Quality:** doc comments describe the actual committed behaviour —
  in particular I did not leave the brief's "opaque white ground" caveat
  written as fact when the measured behaviour never needed it; I rewrote
  that paragraph to state what the code actually does (transparent ground
  both sides).
- **Discipline:** nothing beyond the brief's two files touched; no fixture,
  threshold, or camera-construction edit; the temporary debug test used to
  capture the numbers table above was deleted before this diff was
  finalised and is not part of the commit.
- **Testing:** every number in the table above is a real, measured run
  output (captured via a throwaway test, `flutter test`'d and printed, then
  discarded) — none synthesized. Thresholds are exactly the brief's:
  `agreement >= 0.995`, `referenceInk > 5000`, `patchCount >= 1` (four-scale
  rows), `patchCount == 2` (label-classification row), `overEight > 200` and
  `agreement < 0.995` (no-patch seam) — none moved.

## Concerns (original submission)

- **The scale-0.5 row misses the pre-committed `referenceInk > 5000`
  anti-vacuity threshold** (measured 2383). This is the band-floor edge the
  brief's amendment explicitly names as a recordable, non-blocking outcome
  ("If the miss is only at 0.5 and/or 2.0 and small, that is the band edge
  and it is a number to record, per the plan"). It is not an agreement
  failure — `agreement == 1.0` and `patchCount == 2` at that same scale —
  only the fixture's total ink at the halved-around-centre camera falls
  short of the anti-vacuity floor. I did not adjust the fixture, the camera
  construction, or the threshold. This is a controller-adjudication item,
  per the brief's own instruction.

**Resolved by Ruling R5-1** (see "Fix round 1" above): the concern was
upheld as a real finding, and the fix was a per-row anti-vacuity floor
(1000 for the four-scale band rows, 5000 kept on the LOD-on scale-1 row
where it was originally calibrated) rather than a blanket relaxation or a
fixture/camera change. No open concerns remain.
