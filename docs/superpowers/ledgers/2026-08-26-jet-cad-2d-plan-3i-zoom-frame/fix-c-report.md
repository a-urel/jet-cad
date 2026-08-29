# Fix wave C — report

Territory: `apps/dev_harness_2d/` only, plus the shared mutation log.
`packages/jet_cad_2d_flutter/` was run as a regression check and not edited;
`packages/jet_cad_2d` was not touched.

Files changed:

- `apps/dev_harness_2d/lib/measurement_rig.dart`
- `apps/dev_harness_2d/lib/main.dart` (a comment at `runArm`, no behaviour)
- `apps/dev_harness_2d/test/settle_attribution_test.dart`
- `apps/dev_harness_2d/test/zoom_arm_wiring_test.dart` (one fixture field)
- `docs/superpowers/notes/plan-3i-mutation-log.md`

No measurement figure appears anywhere in this work. The device rig was not
run: the machine is on battery with Low Power Mode on, which invalidates frame
timing. Every number quoted below is a *chosen* fixture cost from a fake frame
driver, or a test count.

---

## BLOCKING — the ordinal scheme assumed a stream that starts at `arm()`

### What was wrong

`FrameTimingLog.msAt(ordinal)` indexes `_reported` directly, so ordinal *k* is
pumped frame *k* only if `_reported[0]` is the first frame pumped after
`arm()`. Two things broke that:

1. **A guaranteed shift of one.** `main.dart`'s `runArm` does
   `camera.value = fittedCamera; await _pumpFrame();` and *then* enters
   `runTileZoomPhase`, where the log is armed. `_pumpFrame` completes at
   `SchedulerBinding.endOfFrame`, before the frame rasterises, so that frame's
   `FrameTiming` is guaranteed to arrive after `arm()` and to land at
   `_reported[0]`.
2. **Engine batching.** Reporting neither starts nor stops at `arm()` —
   `SchedulerBinding.initInstances` registers its timings callback in
   `!kReleaseMode` and delivery is batched — so anything unflushed at that
   moment shifts the stream further.

Nothing detected it: `framesMissing` looks for holes *inside* a window, and a
window shifted whole has none.

### What I did, and why that option

I took **the baseline drain**, not `FrameTiming.frameNumber` reconciliation as
the primary mechanism — and I want to be explicit about why, because the
frameNumber option is the one that sounds more principled.

Tying an ordinal to the frame it names requires knowing the engine frame
number *of the frame the rig just pumped*. The only public surface that
carries a current frame number is `PlatformDispatcher.frameData.frameNumber`
(`FrameData`, `platform_dispatcher.dart:1410-1420` in the pinned Flutter
3.27.3). It is fed by an engine hook, defaults to `-1`, and I could find no
guarantee that it is updated per frame on macOS desktop or that it shares a
numbering space with `FrameTiming.frameNumber`. Building the attribution on it
would mean building it on an assumption I cannot test here — the one thing
this rig must not do. So `frameNumber` is used, but only where it is
*observed* rather than assumed: as a staleness filter on the drained stream.

`FrameTimingLog.establishBaseline` (called by `runTileZoomPhase` immediately
after `arm()`):

- pumps `kBaselineFramesPerRound` frames **back to back**, so no frame the app
  schedules for itself can slip in unpumped while the round runs;
- stops pumping and waits `kTimingBatchWindow`, then waits a second one and
  checks that `_reported` did not grow across it. A stream that stops growing
  while nothing is being pumped is a stream the engine owes nothing;
- on that condition, records `_reported.last.frameNumber` as the baseline and
  then **drops `_reported` and resets `_pumped` in the same synchronous
  step**, so the two cannot disagree;
- drops, from then on, any timing whose `frameNumber` is at or below the
  baseline — a straggler from before the rebase cannot take ordinal 0;
- throws if the stream never goes quiet inside `kBaselineMaxRounds`. There is
  no salvageable number in that state, only a wrong one to print.

`waitForBatch` is injectable so the whole thing is testable without sleeping.

### The invariant

`reportedFrames <= pumpedFrames` is latched in `_collect`, but only once the
baseline is established — before that a backlog is precisely what is being
drained. A violation makes **every read throw** (`msAt`, and so `msRange` and
every window built on it), with the excess in the message. `sawBacklog` is the
non-throwing getter so a test can ask.

Throwing rather than warning is deliberate, and it is the same argument the
reviewer made about the covering-frame field: a shifted stream is wrong by an
amount nothing downstream can recover, and the existing precedent — a printed
`SHORT SAMPLE` line next to the numbers it invalidates — is exactly the guard
that failed to stop a bad figure being published.

### The test fixture

`_FrameDriver` started `_delivered` at 0 and only ever delivered frames it had
pumped itself: it modelled a stream whose backlog is empty at `arm()`, the one
case the device never produces. It now takes `backlogMs` — timings for frames
pumped *before* arming, delivered in one batch at the head of the stream, with
engine frame numbers below every post-arm frame — and a `flush()` that stands
in for a batch flush while nothing is pumped. Frame numbers are one sequence
across both, and with no backlog the numbering is identical to what it was, so
the existing tests are untouched by the change.

Five tests added:

- `the baseline drains what arming did not, and rebases the ordinals`
- `a backlog reported after arming does not take the settle ordinals`
- `a backlog reported after arming does not pad the gesture window`
- `a backlog after the baseline is refused rather than published`
- `a stream that never goes quiet is refused, not measured`

## MINOR — a hole published as a fast frame

`SettleReport.coveringFrameMs` and `ZoomReport.settleCoveringFrameMs` are now
`double?`, filled from `ms.isEmpty ? null : ms.last`. `printZoomReport` prints
`coveringFrameMs=NONE` and adds its own warning line rather than `0.00`.
`zoom_arm_wiring_test.dart`'s deliberately empty `_emptyReport` now passes
`null` for that field, which is what it always meant.

## MINOR — the record-integrity slip

`docs/superpowers/notes/plan-3i-mutation-log.md:399` said the new ceiling arm's
mutant was **M20**; it is **M21**. Corrected. The parallel wave had not fixed
it when I got there.

## Numbering

`M22`, `M22b`, `M22c` were free when I wrote them (`grep '^## M2[2-9]'` on the
log returned nothing). **Collision risk to flag:** the parallel wave has an
untracked scratch file `packages/jet_cad_2d_flutter/test/zz_scratch_m24_probe_test.dart`
in the shared working tree, which suggests it intends to take M22-M24. The
sub-letter form keeps my claim to the single number M22.

---

## M22 — restore the direct-index attribution

Mutation applied to `FrameTimingLog.establishBaseline`, reconciliation removed,
direct index left as it was:

```diff
       // Quiet, and non-empty: everything the engine owed has landed. Rebase.
-      _baselineFrameNumber = _reported.last.frameNumber;
-      _reported.clear();
-      _pumped = 0;
       _sawBacklog = false;
       _worstExcess = 0;
-      _baselineEstablished = true;
       return;
```

Procedure: `cp` aside to the scratchpad (`measurement_rig_m22.bak`), edit,
run, restore by `cp`, `diff` empty. Never `git checkout`.

**RED — four of fourteen.** Verbatim (`flutter pub get` preamble trimmed):

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
00:00 +9: the baseline drains what arming did not, and rebases the ordinals
00:00 +9 -1: the baseline drains what arming did not, and rebases the ordinals [E]
  Expected: true
    Actual: <false>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/settle_attribution_test.dart 434:7             main.<fn>
  
00:00 +9 -1: a backlog reported after arming does not take the settle ordinals
00:00 +9 -2: a backlog reported after arming does not take the settle ordinals [E]
  Expected: a numeric value within <1e-9> of <90.0>
    Actual: <1.0>
     Which:  differs by <89.0>
  the covering frame. 333.0 is the backlog, 1.0 is a baseline frame, and 4.0 is the composite blit before it
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/settle_attribution_test.dart 488:5             main.<fn>
  
00:00 +9 -2: a backlog reported after arming does not pad the gesture window
00:00 +9 -3: a backlog reported after arming does not pad the gesture window [E]
  Expected: a numeric value within <1e-9> of <10.0>
    Actual: <1.0>
     Which:  differs by <9.0>
  the first gesture frame, not a backlog frame and not a baseline or warm-up frame
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/settle_attribution_test.dart 549:5             main.<fn>
  
00:00 +9 -3: a backlog after the baseline is refused rather than published
00:00 +9 -4: a backlog after the baseline is refused rather than published [E]
  Expected: true
    Actual: <false>
  two timings across zero pumped frames
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/settle_attribution_test.dart 581:7             main.<fn>
  
00:00 +9 -4: a stream that never goes quiet is refused, not measured
00:00 +10 -4: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: a backlog after the baseline is refused rather than published
  /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: a backlog reported after arming does not pad the gesture window
  /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: a backlog reported after arming does not take the settle ordinals
  /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: the baseline drains what arming did not, and rebases the ordinals
```

Under the mutant the covering frame reads **1.0** — a baseline frame, cheaper
than every gesture frame in the phase — where the frame coverage was actually
read at cost 90.0; and the gesture window's first entry reads **1.0** where the
first gesture frame cost 10.0. Both are chosen fixture costs, not measurements.

The two pre-existing gesture/hole tests survive M22 and are meant to: they are
written on drivers with no backlog, and a stream with no backlog is not shifted.
That is exactly the structural blindness the finding named.

**Restore, verified.** `diff` empty:

```
M22 DIFF EMPTY -- restored
```

## M22b — the baseline gives up quietly instead of refusing

```diff
-    throw StateError('FrameTimingLog.establishBaseline(): the timing stream '
-        'never went quiet in $maxRounds rounds of $framesPerRound frames and '
-        '$batchWindow -- $reportedFrames timing(s) across $pumpedFrames '
-        'pumped frames. Every ordinal below would be offset by an unknown '
-        'amount, so there is no figure to publish.');
+    return;
```

**RED — one test.** Verbatim:

```
00:00 +12: a backlog after the baseline is refused rather than published
00:00 +13: a stream that never goes quiet is refused, not measured
00:00 +13 -1: a stream that never goes quiet is refused, not measured [E]
  Expected: throws <Instance of 'StateError'>
    Actual: <Instance of 'Future<void>'>
     Which: emitted <null>
  
  package:matcher                                    expectLater
  package:flutter_test/src/widget_tester.dart 507:8  expectLater
  test/settle_attribution_test.dart 600:13           main.<fn>
  
00:00 +13 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: a stream that never goes quiet is refused, not measured
```

**Restore, verified.** `diff` empty:

```
M22b DIFF EMPTY -- restored
```

## M22c — the hole published as a fast frame (the Minor's gate)

```diff
-    coveringFrameMs: ms.isEmpty ? null : ms.last,
+    coveringFrameMs: ms.isEmpty ? 0.0 : (ms.last ?? 0.0),
```

**RED — one test.** Verbatim:

```
00:00 +6: a frame that never reports is a hole, not a zero
00:00 +6 -1: a frame that never reports is a hole, not a zero [E]
  Expected: null
    Actual: <0.0>
  the field carries the hole. `0.0` here is a *fast frame*, and a reader who takes this field without also reading framesMissing would publish the fastest number in the run as criterion 3's settle
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/settle_attribution_test.dart 328:5             main.<fn>
  
00:00 +6 -1: the gesture window excludes the warm-up frames and keeps its tail
00:00 +7 -1: a short sample is counted, and length plus missing is the script
00:00 +8 -1: the baseline drains what arming did not, and rebases the ordinals
00:00 +9 -1: a backlog reported after arming does not take the settle ordinals
00:00 +10 -1: a backlog reported after arming does not pad the gesture window
00:00 +11 -1: a backlog after the baseline is refused rather than published
00:00 +12 -1: a stream that never goes quiet is refused, not measured
00:00 +13 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: a frame that never reports is a hole, not a zero
```

**Restore, verified.** `diff` empty against its own backup *and* against the
pre-M22 copy:

```
M22c DIFF EMPTY -- restored
ALSO IDENTICAL TO THE PRE-M22 FILE
```

Green after all three restores:

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
00:00 +9: the baseline drains what arming did not, and rebases the ordinals
00:00 +10: a backlog reported after arming does not take the settle ordinals
00:00 +11: a backlog reported after arming does not pad the gesture window
00:00 +12: a backlog after the baseline is refused rather than published
00:00 +13: a stream that never goes quiet is refused, not measured
00:00 +14: All tests passed!
```

---

## Gate

```sh
cd apps/dev_harness_2d && CI=true flutter test --concurrency=1 && CI=true flutter analyze && dart format --output=none --set-exit-if-changed .
cd packages/jet_cad_2d_flutter && CI=true flutter test
```

### `apps/dev_harness_2d` — `CI=true flutter test --concurrency=1`

```
00:02 +36: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/pointer_zoom_test.dart: trackpad two-finger scroll up zooms in
00:04 +37: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/pointer_zoom_test.dart: trackpad two-finger scroll down zooms out
00:06 +38: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/pointer_zoom_test.dart: pinch open zooms in by the reported scale
00:08 +39: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/pointer_zoom_test.dart: pinch closed zooms out
00:09 +40: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/pointer_zoom_test.dart: a gesture reporting cumulative values does not compound
00:11 +41: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/pointer_zoom_test.dart: pan and scale on one event combine
00:13 +42: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/pointer_zoom_test.dart: a second gesture starts from a clean factor
00:14 +43: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/pointer_zoom_test.dart: mouse wheel still zooms through the signal path
00:16 +44: loading /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/zoom_script_test.dart
00:16 +44: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/zoom_script_test.dart: the pinned script is 40 in, 40 out, at 1.03
00:16 +45: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/zoom_script_test.dart: the focal point is off-centre
00:16 +46: All tests passed!
```

41 at `c5794d7`, 46 now: five new tests, no test removed or skipped.

### `apps/dev_harness_2d` — `CI=true flutter analyze`

```
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Analyzing dev_harness_2d...                                     
No issues found! (ran in 1.4s)
```

### `apps/dev_harness_2d` — `dart format --output=none --set-exit-if-changed .`

```
Formatted 11 files (0 changed) in 0.08 seconds.
```

### `packages/jet_cad_2d_flutter` — `CI=true flutter test` (regression only)

```
00:07 +409 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: a settled generation is identical to a live frame
00:07 +410 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: a settled generation is identical to a live frame
00:07 +411 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart: debugFullViewportQuery grows the fallback walk to the whole viewport
00:07 +412 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: and at a camera on a power-of-two rebase boundary
00:07 +413 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: and stays identical after a pan smaller than one tile
00:07 +414 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: and when a pan lands between the scale change and the bake
00:07 +415 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: tile boundaries carry no difference of their own
00:07 +416 ~1: All tests passed!
```

Green. The baseline given to me was 411 with 1 skip; the tree now runs 416
with 1 skip because the parallel wave has five new tests in flight in that
package (uncommitted, in the shared working tree). I did not edit anything
under `packages/`.

---

## Concerns

1. **The baseline's quiet window is the one place the rig is not pumping.**
   `establishBaseline` stops pumping for two `kTimingBatchWindow`s per round to
   see whether the stream goes quiet. `DraftCanvasState`'s settle notifier
   schedules its own frames for as long as the cache owes tiles, and any frame
   that renders during that window is an *unpumped* frame: the stream grows,
   the round repeats. It should converge once the cache covers — which the
   round's own pumped frames drive it towards — and it is bounded at
   `kBaselineMaxRounds`, so the worst case is a few seconds per arm and then a
   throw. I cannot confirm the convergence without the device rig, and the
   rig cannot be run here. This is the single thing in the fix I would most
   want a device run to check, before a long interleaved session is started on
   it.

2. **`kTimingBatchWindow = 150ms` and `kBaselineMaxRounds = 8` are chosen from
   the framework's own documented batch period (~100ms in debug and profile),
   not measured.** They are named constants, so they are cheap to retune once
   somebody can watch a real stream.

3. **A read on a shifted stream throws, and that aborts the arm and the run.**
   I chose that over a printed warning deliberately (see above), but it is a
   behaviour change for an operator mid-session: a rig that used to always
   print numbers can now stop. The alternative was publishing a number that is
   wrong by an unknown offset, which is the defect being fixed.

4. **`FrameTiming.frameNumber` is used as a staleness filter only.** Full
   frameNumber-anchored attribution needs the current frame number at pump
   time and I could not establish that `PlatformDispatcher.frameData` provides
   one reliably on this platform. If somebody can confirm it does, the
   baseline could be replaced by a straight lookup and the quiet window in
   concern 1 would go away entirely.

5. **Mutation-log numbering is shared and the parallel wave looks likely to
   collide.** M22/M22b/M22c were free when written; the other wave has an
   untracked `zz_scratch_m24_probe_test.dart`, implying it plans M22-M24.
   Whoever writes second should read the file first.
