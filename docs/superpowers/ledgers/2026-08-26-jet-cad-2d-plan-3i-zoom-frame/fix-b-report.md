# Fix wave B — report

**Base:** `main` at `9206743`. **Commits, in order:**

| SHA | What |
|---|---|
| `93052db` | `fix(rig): the settle named the wrong frame, and the gesture the wrong 80` — the Blocking finding, the gesture-window Major, criterion 4's Major, and the Minor doc correction |
| `7567619` | `docs: M20 -- the settle reads the frame before the one that covered` |
| `45da407` | `feat(harness): ZOOM_MODE wires the interleaved arms criteria 4 and 8 name` — the `ZOOM_ARMS` Major |

Everything is inside `apps/dev_harness_2d/` and `docs/superpowers/notes/`. No
file in `packages/jet_cad_2d_flutter/` or `packages/jet_cad_2d/` was touched
(the `--stat` of all three commits is at the end of this report). No
`analysis_options.yaml` was staged. No `git checkout` was used: both mutations
were reverted by `cp` from a scratchpad copy with `diff` verified empty.

**No measurement figure appears anywhere in this work.** The device rig was not
run — it is blocked on machine power — so every number in the new tests is a
*chosen* frame cost fed to a fake frame driver, and the tests assert
attribution, not performance.

---

## BLOCKING — `settleMs` systematically named the wrong frame

**Confirmed as described.** `runTileZoomPhase`'s idle loop registered a fresh
`collectIdle` around a single `await pumpFrame()` and read `idleTimings.last`.
`pumpFrame` completes at `SchedulerBinding.endOfFrame`, before the scene
rasterises, and a `FrameTiming` is delivered only after rasterisation, so the
timings seen during idle frame *i* were frame *i-1*'s or none. With coverage
first reading true at idle frame 2 (Ruling 15), the published `settleMs` was
idle frame 1: the in-between composite blit, which draws nothing.

**Fixed the way the file's own comment at `:346-352` prescribes**, and further.
A new `FrameTimingLog` holds **one registration for the whole phase** and
attributes each delivered timing to a pumped frame **by ordinal** rather than
by arrival window:

- `arm()` registers once, `pump()` gives each frame the next ordinal,
  `msAt(ordinal)` reads that frame's `totalSpan`.
- `drain()` pumps up to four extra bare frames at the end of the settle, until
  the last real frame's timing has actually arrived. It is a bound, not a wait
  loop: a device that stops reporting returns rather than hanging, and the
  shortfall is counted.
- A frame that never reported is `null`, not `0.0`. Zero is a *fast frame*;
  publishing a hole as a zero is how a dropped sample becomes a good number.

The settle is now `runSettlePhase`, a separate function taking a
`bool Function()` coverage predicate. That extraction is what makes the
attribution testable at all: `runTileZoomPhase` opens with `refuseDebugMode()`
— correctly — and `flutter test` is a debug build, and a bare `TileCache`
cannot be made to cover a viewport without a painted widget. The production
call site passes `() => cache.viewportCovered`; nothing about the phase's
behaviour on device changed by the extraction.

**M20 fired and died.** Transcripts below, and the log entry is in
`docs/superpowers/notes/plan-3i-mutation-log.md`.

## MAJOR — the gesture window dropped its tail and charged the gesture for the warm-up

**Confirmed as described**, and fixed by the same mechanism rather than by a
second one. The `FrameTimingLog` is armed **before** the two `panBy(Offset
.zero)` warm-up pumps, so those frames take ordinals 0 and 1 and are excluded
by the gesture window instead of arriving after a later registration and taking
the first two gesture ordinals. The gesture window is
`msRange(gestureStart, gestureStart + 2 * kZoomSteps)`, read *after* the
settle's drain, so the tail is collected rather than dropped.

**The 80-entry claim is now enforced.** `ZoomReport.from` splits the ordinal
window into `gestureFrameMs` and a count of holes, so
`gestureFrameMs.length + gestureFramesMissing == 2 * kZoomSteps` holds by
construction, a test pins it, and `printZoomReport` prints a `!!! WARNING:
... SHORT SAMPLE ...` line whenever the count is short. A p95 over a silently
truncated list is no longer producible.

## MAJOR — criterion 4's numerator was never computed

**Confirmed.** Fixed by adding the figure the criterion actually names.
`ZoomReport` now carries:

- `settleWallMs` — **"wall clock to a covered viewport, from the first frame
  after the gesture ends to the frame that covers it"**, quoted at the field.
  The sum of `totalSpan` over idle frames 1..`settleFrames` inclusive; the idle
  frames after coverage are not in it. This is the only field criterion 4's
  ratio may be formed from.
- `settleCoveringFrameMs` — the old `settleMs`, **relabelled**, with its doc
  saying in as many words that it is one frame, that criterion 3 reads it, and
  that a ratio formed from it compares one frame against one frame, which is
  the straddle §4 exists to prevent.

Both print, on the same labelled line, each tagged with the criterion it
belongs to. `settleCovered` also prints, and a settle that never covered shouts
— `settleFrames` is then a floor and neither time figure is a settle.

## MAJOR — `ZOOM_ARMS` printed N arms that were not criterion 4's or 8's arms

**Confirmed.** `runInterleaved` had no production caller and neither flag was
set outside the tile cache and its own test. **Wired**, per the brief's
supersession of the earlier instruction.

- **`ZOOM_MODE`**, a `String.fromEnvironment` with an explicit throw — the rule
  `kBackend`, `kTilePx` and `kTileBake` follow and that Plan 3c lost a device
  run to by not following. Values: `plain` (default), `criterion4`,
  `criterion8`. Anything else stops the session.
- **`ZoomArm`** is an enum of four arms, each carrying its criterion number,
  its side (`A` numerator / `B` denominator), its exact flag state as a string,
  and a description. `applyTo(cache)` writes **both** flags on every arm, so an
  arm's label describes the cache completely and no leftover from another
  criterion's run can sit under a label that does not mention it.
- **`runZoomCriterionArms`** drives `runInterleaved` with the criterion's two
  arms, flipping the flag before each arm runs, labelling every emitted report
  with `zoomArmLabel`, and restoring both flags in a `finally`. Criterion 8's
  denominator label says **"(Plan 3h's M4)"** verbatim, because mutant numbering
  is per-plan and M4/M5 collide between the two logs.
- **Every printed line carries the arm's label.** `printZoomReport`'s
  continuation lines used to be indented under the heading; an indented line
  under the wrong heading is a number attributed to the wrong arm, which is this
  measurement's whole failure mode. A test pins that every line starts with the
  label.
- **No state reset between arms**, and none added: per the warmth investigation
  (`tile_zoom_warmth_test.dart`, `warmth-report.md`) a zoom round trip leaves no
  warm tiles, so both arms genuinely re-bake. `ZoomArm.applyTo`'s doc says so, so
  the next reader does not add one.

**The plain path: relabelled, not refused — and why.** Repeats of one
configuration are a real capability: criterion 2 is a p95 over the gesture
frames and wants repeats, not arms. Refusing would remove a measurement in order
to prevent a mislabelling, and this file already has a house rule against that
trade (`warnIfZoomViewportMismatch`: "refusing to run would trade a labelled
number for no number at all"). What made the old output dangerous was purely
that it *read* as the interleaved transcript. So `zoomPlainLabel` prints
`R2 tile zoom plain repeat 1/9 [debugRestBakeDisabled=false
debugFullViewportQuery=false] criterion 2 only, NOT an interleaved arm (50000)`
— the word "arm" survives only in the phrase denying it, both flag states print
though neither was flipped, and a header line before the loop says the mode is
criterion 2 only and names the two modes that are not. A test asserts the plain
label matches no `arm [AB0-9]` pattern and that the arm labels do.

## MINOR — the doc comment told the operator the wrong target

**Fixed.** `settleFrames`'s doc no longer says 1 is what criterion 3 asserts. It
states that correct code reads **2**, and carries Ruling 15's arithmetic in
brief: `kRestGateFrames` is 2, the last gesture frame changed the camera, so
idle frame 1 can only reach `_restGateSteps == 1` and takes `paintFrame`'s
moving-frame early return; idle frame 2 is the first that can bake. It also
points at `tile_zoom_warmth_test.dart`, which pins `settleFrames == 2`.

---

## New tests

`apps/dev_harness_2d/test/settle_attribution_test.dart` (9 tests). A
`_FrameDriver` pumps frames and reports each frame's timing **one frame late**,
through `SchedulerBinding.instance.platformDispatcher.onReportTimings`, which
is exactly the engine's lag. Costs are chosen, not measured.

- the covering frame is the one reported, not the frame before it
- the settle frame moves the reported figure (9 ms arm vs 900 ms arm)
- wall clock over the settle is the sum, not the last frame
- the idle frames after coverage are not charged to the settle
- the last idle frame is drained rather than dropped
- a settle that never covers says so
- a frame that never reports is a hole, not a zero
- the gesture window excludes the warm-up frames and keeps its tail
- a short sample is counted, and length plus missing is the script

`apps/dev_harness_2d/test/zoom_arm_wiring_test.dart` (8 tests). Drives
`runZoomCriterionArms` against a real `TileCache`, recording the flag state
observed **inside** each arm.

- criterion 4 alternates its arms and flips only its own flag
- criterion 8 alternates its arms and flips only its own flag
- every arm is labelled with the flag it actually ran at
- criterion 8's denominator names whose M4 it is
- no two arms of a run share a label
- a plain repeat cannot be read as an interleaved arm
- every printed line of a report carries its arm label
- a short sample and an uncovered settle both shout

**Spot-check mutation on the wiring tests** (not logged as a numbered mutant —
the brief named one mutation, M20, and this was run only to confirm the wiring
tests are not vacuous). Deleting `arm.applyTo(cache);` from
`runZoomCriterionArms`'s `tiled` branch:

```
00:00 +0: criterion 4 alternates its arms and flips only its own flag
00:00 +0 -1: criterion 4 alternates its arms and flips only its own flag [E]
  Expected: [false, true, false, true, false, true]
    Actual: [false, false, false, false, false, false]
     Which: at location [1] is <false> instead of <true>
  rest bake on for the numerator, off for the denominator, alternating -- never all of one arm and then all of the other

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/zoom_arm_wiring_test.dart 89:5                 main.<fn>

00:00 +0 -1: criterion 8 alternates its arms and flips only its own flag
00:00 +0 -2: criterion 8 alternates its arms and flips only its own flag [E]
  Expected: [false, true, false, true]
    Actual: [false, false, false, false]
     Which: at location [1] is <false> instead of <true>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/zoom_arm_wiring_test.dart 109:5                main.<fn>
```

Restored by `cp` from `rig_spot.bak`, `diff` empty, file re-run green (it is
part of the gate transcript below).

---

## M20 — the settle reads the frame before the one that covered

Full entry, with the diff, the procedure and both transcripts, is in
`docs/superpowers/notes/plan-3i-mutation-log.md` (commit `7567619`).

**Mutation** — a one-ordinal shift in `runSettlePhase`, which is precisely what
the old per-frame re-registration did:

```diff
-  final ms = log.msRange(firstOrdinal, firstOrdinal + frames);
+  final ms = log.msRange(firstOrdinal - 1, firstOrdinal + frames - 1);
```

**RED**, six of the nine tests. The named kill is the figure going inert: with
the covering frame made arbitrarily expensive, `coveringFrameMs` reads **4.0**
— the cheap frame before it — in both the 9 ms arm and the 900 ms arm.

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart
00:00 +0: the covering frame is the one reported, not the frame before it
00:00 +0 -1: the covering frame is the one reported, not the frame before it [E]
  Expected: <0>
    Actual: <1>
  both settle frames must have reported a timing
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/settle_attribution_test.dart 104:5             main.<fn>
  
00:00 +0 -1: the settle frame moves the reported figure
00:00 +0 -2: the settle frame moves the reported figure [E]
  Expected: a numeric value within <1e-9> of <9.0>
    Actual: <4.0>
     Which:  differs by <5.0>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/settle_attribution_test.dart 134:5             main.<fn>
  
00:00 +0 -2: wall clock over the settle is the sum, not the last frame
00:00 +0 -3: wall clock over the settle is the sum, not the last frame [E]
  Expected: a numeric value within <1e-9> of <90.0>
    Actual: <6.0>
     Which:  differs by <84.0>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/settle_attribution_test.dart 159:5             main.<fn>
  
00:00 +0 -3: the idle frames after coverage are not charged to the settle
00:00 +0 -4: the idle frames after coverage are not charged to the settle [E]
  Expected: a numeric value within <1e-9> of <11.0>
    Actual: <5.0>
     Which:  differs by <6.0>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/settle_attribution_test.dart 186:5             main.<fn>
  
00:00 +0 -4: the last idle frame is drained rather than dropped
00:00 +0 -5: the last idle frame is drained rather than dropped [E]
  Expected: <0>
    Actual: <1>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/settle_attribution_test.dart 211:5             main.<fn>
  
00:00 +0 -5: a settle that never covers says so
00:00 +0 -6: a settle that never covers says so [E]
  Expected: a numeric value within <1e-9> of <21.0>
    Actual: <14.0>
     Which:  differs by <7.0>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/settle_attribution_test.dart 234:5             main.<fn>
  
00:00 +0 -6: a frame that never reports is a hole, not a zero
00:00 +1 -6: the gesture window excludes the warm-up frames and keeps its tail
00:00 +2 -6: a short sample is counted, and length plus missing is the script
00:00 +3 -6: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: a settle that never covers says so
  /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: the covering frame is the one reported, not the frame before it
  /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: the idle frames after coverage are not charged to the settle
  /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: the last idle frame is drained rather than dropped
  ... and 2 more
```

**GREEN**, after `cp` from the scratchpad copy and a `diff` that produced
no output:

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart
00:00 +0: the covering frame is the one reported, not the frame before it
00:00 +1: the settle frame moves the reported figure
00:00 +2: wall clock over the settle is the sum, not the last frame
00:00 +3: the idle frames after coverage are not charged to the settle
00:00 +4: the last idle frame is drained rather than dropped
00:00 +5: a settle that never covers says so
00:00 +6: a frame that never reports is a hole, not a zero
00:00 +7: the gesture window excludes the warm-up frames and keeps its tail
00:00 +8: a short sample is counted, and length plus missing is the script
00:00 +9: All tests passed!
```

---

## Gate

Every command below was run at the tip (`45da407`) and its real output is
pasted. The `flutter pub get` preamble is trimmed; nothing else is.

### `cd apps/dev_harness_2d && CI=true flutter test --concurrency=1`

**40 tests, all passed** (baseline 23, +9 attribution, +8 wiring). Exit 0.

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/interleaved_arms_test.dart
00:00 +0: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/interleaved_arms_test.dart: three arms alternate, never block
00:00 +1: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/interleaved_arms_test.dart: zero arms calls neither
00:00 +2: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/interleaved_arms_test.dart: each callback is awaited before the next arm starts
00:00 +3: loading /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/zoom_arm_wiring_test.dart
00:00 +3: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/zoom_arm_wiring_test.dart: criterion 4 alternates its arms and flips only its own flag
00:00 +4: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/zoom_arm_wiring_test.dart: criterion 8 alternates its arms and flips only its own flag
00:00 +5: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/zoom_arm_wiring_test.dart: every arm is labelled with the flag it actually ran at
00:00 +6: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/zoom_arm_wiring_test.dart: criterion 8's denominator names whose M4 it is
00:00 +7: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/zoom_arm_wiring_test.dart: no two arms of a run share a label
00:00 +8: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/zoom_arm_wiring_test.dart: a plain repeat cannot be read as an interleaved arm
00:00 +9: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/zoom_arm_wiring_test.dart: every printed line of a report carries its arm label
00:00 +10: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/zoom_arm_wiring_test.dart: a short sample and an uncovered settle both shout
00:00 +11: loading /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/seam_corpus_test.dart
00:01 +11: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/seam_corpus_test.dart: the fan carries at least eight distinct slopes
00:01 +12: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/seam_corpus_test.dart: at least four of those slopes are shallow
00:01 +13: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/seam_corpus_test.dart: the corpus spans a real area on both axes
00:01 +14: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/seam_corpus_test.dart: the corpus sits far from the origin
00:01 +15: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/seam_corpus_test.dart: curves are present alongside the straight lines
00:01 +16: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/seam_corpus_test.dart: two lineweight regimes are on screen at once
00:01 +17: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/seam_corpus_test.dart: the corpus stays small enough to read by eye
00:01 +18: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/seam_corpus_test.dart: the corpus paints
00:01 +19: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/seam_corpus_test.dart: the corpus carries a measurer DraftCanvas will accept
00:01 +20: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/seam_corpus_test.dart: CORPUS accepts its two values and rejects anything else
00:01 +21: loading /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart
00:01 +21: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: the covering frame is the one reported, not the frame before it
00:01 +22: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: the settle frame moves the reported figure
00:01 +23: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: wall clock over the settle is the sum, not the last frame
00:01 +24: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: the idle frames after coverage are not charged to the settle
00:01 +25: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: the last idle frame is drained rather than dropped
00:01 +26: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: a settle that never covers says so
00:01 +27: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: a frame that never reports is a hole, not a zero
00:01 +28: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: the gesture window excludes the warm-up frames and keeps its tail
00:01 +29: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: a short sample is counted, and length plus missing is the script
00:01 +30: loading /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/pointer_zoom_test.dart
00:02 +30: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/pointer_zoom_test.dart: trackpad two-finger scroll up zooms in
00:04 +31: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/pointer_zoom_test.dart: trackpad two-finger scroll down zooms out
00:06 +32: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/pointer_zoom_test.dart: pinch open zooms in by the reported scale
00:07 +33: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/pointer_zoom_test.dart: pinch closed zooms out
00:09 +34: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/pointer_zoom_test.dart: a gesture reporting cumulative values does not compound
00:10 +35: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/pointer_zoom_test.dart: pan and scale on one event combine
00:12 +36: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/pointer_zoom_test.dart: a second gesture starts from a clean factor
00:14 +37: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/pointer_zoom_test.dart: mouse wheel still zooms through the signal path
00:15 +38: loading /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/zoom_script_test.dart
00:16 +38: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/zoom_script_test.dart: the pinned script is 40 in, 40 out, at 1.03
00:16 +39: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/zoom_script_test.dart: the focal point is off-centre
00:16 +40: All tests passed!
```

### `cd apps/dev_harness_2d && CI=true flutter analyze`

Exit 0.

```
Analyzing dev_harness_2d...                                     
No issues found! (ran in 1.3s)
```

### `cd apps/dev_harness_2d && dart format --output=none --set-exit-if-changed .`

Exit 0.

```
Formatted 11 files (0 changed) in 0.07 seconds.
```

### `cd packages/jet_cad_2d_flutter && CI=true flutter test`

**410 passed, 1 skipped, 1 FAILED.** Exit 1. Tail:

```
00:07 +408 ~1 -1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart: debugRestBakeDisabled slices nothing and still covers
00:07 +409 ~1 -1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart: debugFullViewportQuery grows the fallback walk to the whole viewport
00:07 +410 ~1 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart: the ceiling binds inside the rest frame, and eviction holds it
```

**This is the parallel wave's in-flight change, not mine, and I did not touch
it.** Evidence, not assertion:

1. All three of my commits touch only `apps/dev_harness_2d/` and
   `docs/superpowers/notes/` — `--stat` at the end of this report.
2. The failing file and the production file it exercises are both **dirty in
   the working tree**, uncommitted, and none of my commits contains either:

```
 M packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
 M packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart
 M packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart
 M packages/jet_cad_2d_flutter/test/support/tile_comparison.dart
 M packages/jet_cad_2d_flutter/test/support/tile_harness.dart
 M packages/jet_cad_2d_flutter/test/tile_grid_test.dart
 M packages/jet_cad_2d_flutter/test/tile_regime_test.dart
```

3. The failure itself is a non-vacuity guard in their own new assertion, and
   the test prints a `DEBUG` line that is plainly work in progress:

```
00:00 +2: the ceiling binds inside the rest frame, and eviction holds it
DEBUG held=190 slices=0 peak=0 cap=3325952 bakes=201 tiles=184 evict=0 covered=true inval=18
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: a value greater than <0>
  Actual: <0>
   Which: is not a value greater than <0>
non-vacuity: the rest bake must have run and cut tiles, or the ceiling was observed nowhere
```

`slices=0` with `bakes=201` is a rest bake that ran and cut no tiles — a
property of `tile_cache.dart` as it currently sits in their working tree. I did
not investigate further and did not fix it, per the brief.

Against the brief's baseline of **405 with 1 skip**, this run collected 412:
410 passing, 1 skipped, 1 failing. The parallel wave has therefore also added
tests to that package; the whole difference is theirs.

### Commit scope

```
93052db fix(rig): the settle named the wrong frame, and the gesture the wrong 80
 apps/dev_harness_2d/lib/measurement_rig.dart       | 463 +++++++++++++++++----
 .../test/settle_attribution_test.dart              | 341 +++++++++++++++
 2 files changed, 717 insertions(+), 87 deletions(-)
7567619 docs: M20 -- the settle reads the frame before the one that covered
 docs/superpowers/notes/plan-3i-mutation-log.md | 148 +++++++++++++++++++++++++
 1 file changed, 148 insertions(+)
45da407 feat(harness): ZOOM_MODE wires the interleaved arms criteria 4 and 8 name
 apps/dev_harness_2d/lib/main.dart                  |  86 +++++++-
 apps/dev_harness_2d/lib/measurement_rig.dart       | 181 ++++++++++++++++
 apps/dev_harness_2d/test/zoom_arm_wiring_test.dart | 233 +++++++++++++++++++++
 3 files changed, 496 insertions(+), 4 deletions(-)
```

---

## Concerns

1. **Ordinal attribution assumes one `FrameTiming` per pumped frame, in order.**
   That is what the engine does for frames driven by an explicit
   `scheduleFrame()` + `endOfFrame`, which is how `_pumpFrame` works, and it is
   what makes the fix exact rather than approximate. If a device ever coalesces
   or drops a report, every later ordinal shifts. It cannot fail *silently*: the
   drain's shortfall is counted per window and `printZoomReport` prints a
   `SHORT SAMPLE` warning naming how many frames of which window are missing. A
   `frameNumber`-keyed cross-check was considered and rejected: `FrameTiming
   .frameNumber` has no counterpart the Dart side can read for the frame it just
   pumped inside a widget test (`PlatformDispatcher.frameData` is not updated by
   the test binding), so it would have made the attribution untestable — and an
   untestable attribution is what this wave was fixing.

2. **`drain`'s bound is 4 extra frames.** Chosen as "more than the one frame the
   lag actually needs, few enough that a stuck device returns quickly". It is
   not measured, because the rig has not been run. If a device run reports
   missing settle frames, that bound is the first thing to raise.

3. **The plan document still sketches the old field.**
   `docs/superpowers/plans/2026-08-26-jet-cad-2d-plan-3i-zoom-frame.md:1472`
   shows `final double settleMs; // totalSpan of the rest frame` in its
   `ZoomReport` sketch. I did not edit a plan of record from a fix wave; the
   rename to `settleCoveringFrameMs` plus the new `settleWallMs` is a
   review-mandated deviation and is recorded here for the ledger.

4. **`runTileZoomPhase` itself is still only reachable on device.**
   `refuseDebugMode()` means no test executes the whole phase end to end; the
   settle, the gesture window, `ZoomReport.from` and the arm driver are each
   tested, and their composition inside `runTileZoomPhase` is read, not run. The
   composition is eleven lines and every seam in it is a named function, but it
   is the one thing in this wave a reviewer must check by reading.

5. **`ZOOM_MODE` is not exercised by any test**, because `main.dart`'s
   `_driveR2` needs a running app. `parseZoomMode` is a pure function and could
   be pinned the way `parseCorpus` is in `seam_corpus_test.dart`; I did not add
   that because it duplicates an existing pattern rather than gating anything
   new. Say the word and it is three lines.

6. **The interleaved arms have never been run.** Everything here makes the
   transcript attributable; whether the two arms actually differ on the device
   is criterion 4's and 8's own question and is still blocked on power.

---

## Controller's note — this report was cut off, and what happened after

The implementing run was terminated mid-sentence by the machine going to sleep,
while it was, in its own words, "updating the report with the fourth commit and
the refreshed gate transcript". Everything above this line is the implementer's;
this section is the controller's, added because the record would otherwise be
stale in two specific ways.

**A fourth commit exists that the sections above do not mention.** The wave
landed four commits, not three:

    93052db  fix(rig): the settle named the wrong frame, and the gesture the wrong 80
    7567619  docs: M20 -- the settle reads the frame before the one that covered
    45da407  feat(harness): ZOOM_MODE wires the interleaved arms criteria 4 and 8 name
    3ba7f05  test(harness): ZOOM_MODE rejects what it cannot parse

**Concern 5 above is closed, by the implementer itself, in that fourth commit.**
It reads "`ZOOM_MODE` is not exercised by any test … `parseZoomMode` is a pure
function and could be pinned the way `parseCorpus` is in `seam_corpus_test.dart`;
I did not add that … Say the word and it is three lines." It then went and added
it before being cut off. Read concern 5 as answered, not open.

**Gate, re-run by the controller at `3ba7f05` rather than read from this
report** — the transcript the interruption cost:

    cd apps/dev_harness_2d
    CI=true flutter test --concurrency=1   ->  08:31 +41: All tests passed!
    CI=true flutter analyze                ->  No issues found! (ran in 5.5s)
    dart format --output=none --set-exit-if-changed .
                                           ->  Formatted 11 files (0 changed)

41 tests, up from the baseline of 23. Analyze and format clean.

`packages/jet_cad_2d_flutter`'s suite is deliberately **not** reported here. A
parallel wave was mid-edit in that package at the time, so its state was neither
this wave's to report nor meaningful as a number.
