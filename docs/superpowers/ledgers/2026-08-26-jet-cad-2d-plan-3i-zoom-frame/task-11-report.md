# Task 11 report: the rig's `tile zoom` phase

## What changed

- `apps/dev_harness_2d/lib/measurement_rig.dart`
  - `kZoomSteps` (40), `kZoomFactor` (1.03) and `zoomFocusFor(Size)` — the
    pinned script constants from the design spec §5, verbatim.
  - `class ZoomReport` with exactly the five fields the brief names
    (`gestureFrameMs`, `gestureBakes`, `gestureLiveDraws`, `settleMs`,
    `settleFrames`).
  - `Future<ZoomReport> runTileZoomPhase({required CameraController camera,
    required TileCache cache, required Future<void> Function() pumpFrame,
    required Size viewport})` — drives 40 zoom-in frames at `kZoomFactor`
    about `zoomFocusFor(viewport)`, then 40 zoom-out frames at
    `1 / kZoomFactor`, one camera change per frame; then 30 idle frames with
    **no** camera nudge at all.
  - `printZoomReport(String label, ZoomReport r)` — prints the gesture's
    p50/p95/max/mean the way `report()` does, plus the bake/live-draw/settle
    counters, with an inline caveat about `gestureBakes`' unit (see below).
- `apps/dev_harness_2d/lib/main.dart`
  - `kZoomArms`, a `ZOOM_ARMS` int define via `_intDefine`, default `0`
    (inert), matching the `_intDefine`/`_doubleDefine` pattern this file
    already uses for `TILE_PX`, `TILE_BAKE` and `PAN_STEP`. This exists so
    Task 12's device command line
    (`--dart-define=ZOOM_ARMS=4`) has something to bind to — Task 12's own
    file list is scoped to `measurement_rig.dart` and a results note, so the
    define has to already exist by the time it runs.
  - `_driveR2` now snapshots `fittedCamera = camera.value` right after the
    initial `ViewportTransform.fit(...)` (before `runR2Rig` touches the
    camera at all), runs `runR2Rig` exactly as before, then — only if
    `tileCache != null && kZoomArms > 0` — loops `kZoomArms` times,
    resetting `camera.value = fittedCamera` and pumping one frame before each
    call to `runTileZoomPhase`, printing each arm's `ZoomReport` via
    `printZoomReport('R2 tile zoom arm $arm ($kEntities)', ...)`.
  - This is the only place `runTileZoomPhase` is invoked from a real running
    app. At its default (`ZOOM_ARMS=0`) an ordinary `RUN_R2` session is
    byte-for-byte unaffected — no new frames, no new prints.
- `apps/dev_harness_2d/test/zoom_script_test.dart` — the brief's two tests,
  verbatim, asserting `kZoomSteps`, `kZoomFactor` and `zoomFocusFor`.

Task 11 does not run a measurement; `ZOOM_ARMS` defaults to off and nothing
in this commit was run outside `flutter test` / `flutter analyze` / `dart
format`.

## The 1600x1200 viewport: how it's established, and what a different real
window means

The pinned reference viewport (§5: 1600x1200 logical at `devicePixelRatio`
2, i.e. 3200x2400 physical) is **not** obtained by resizing the OS window
from inside the app — this repository has no window-sizing API call
anywhere (`grep` for `setWindowSize`/`Window(` in `apps/dev_harness_2d`
turns up nothing). Instead:

- `runTileZoomPhase` takes `viewport` as a plain parameter and only uses it
  for one thing: `zoomFocusFor(viewport)`, the screen-space anchor point.
  It does not read the real window size itself.
- `main.dart`'s wiring passes `const Size(1600, 1200)` for `viewport`
  **unconditionally**, regardless of what `view.physicalSize /
  view.devicePixelRatio` actually reads for the real running window. This
  mirrors `runR2Rig`'s own existing precedent: its internal zoom step
  already anchors at the hardcoded `Offset(800, 600)` — exactly half of
  1600x1200 — never at the real viewport's centre.
- The consequence, stated in `runTileZoomPhase`'s own doc comment: if the
  operator's actual OS window is not 1600x1200 logical at dpr 2 when Task 12
  or 13 runs this, the phase still runs without error (`zoomAt` accepts any
  finite positive factor at any screen point, on-screen or not), but the
  focal point then sits at a different fraction of the *real* viewport than
  the pinned 30%/70%, and the resulting numbers are not soundly comparable
  to another run or to the design spec's priced predictions until the
  window is confirmed to actually be the reference size. `main.dart`
  already prints the real window size once (`R2 app-run: window=...`) for
  exactly this class of caveat; Tasks 12/13 must check that line reads
  3200x2400 physical (1600x1200 at dpr 2) before trusting the absolute
  numbers, the same way they already have to for R2's own baseline.

## Which `bakeCount` unit this phase reports

`gestureBakes` (`ZoomReport.gestureBakes`) reads `TileCache.bakeCount`
**after `resetCounters()`, over the 80-frame gesture only.** Every one of
those 80 frames is a *moving* frame by construction (the camera changes
every single frame, one zoom step per frame) — `TileCache.paintFrame`'s
rest branch (`_restBake`, which counts once per band) only ever runs once
`_restGateSteps >= kRestGateFrames`, i.e. after **two consecutive frames
with an unchanged quantised camera**, which cannot happen while the script
is still zooming. So for the whole gesture window, `bakeCount` can only be
incremented by the ordinary budgeted per-tile loop (`_bake`, counted once
per tile) — never by `_restBake`. `gestureBakes` is therefore **always the
per-tile unit**, and criterion 1 expects it to read exactly zero (a moving
frame should bake nothing at all).

A reader tells which unit is in play by the same rule stated in
`ZoomReport.gestureBakes`'s doc comment and repeated in `printZoomReport`'s
own comment: **`gestureBakes` is scoped to a window where the rest path
provably never ran**, so it is safe to compare directly against a Plan
3g/3h transcript, where `bakeCount` always meant tiles. It is **not** safe
to compare `gestureBakes` against this same cache's `bakeCount` read again
after the 30 idle frames (where the rest bake, if criterion 3 holds, fires
and counts once per band) — `ZoomReport` deliberately has no field for that
post-settle reading, precisely so nothing invites that comparison by
accident. `settleMs`/`settleFrames` describe the settle instead, without
carrying a bake count at all.

## RED

```
$ cd apps/dev_harness_2d && CI=true flutter test test/zoom_script_test.dart
...
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/zoom_script_test.dart
test/zoom_script_test.dart:13:12: Error: Undefined name 'kZoomSteps'.
    expect(kZoomSteps, 40);
           ^^^^^^^^^^
test/zoom_script_test.dart:14:12: Error: Undefined name 'kZoomFactor'.
    expect(kZoomFactor, closeTo(1.03, 1e-12));
           ^^^^^^^^^^^
test/zoom_script_test.dart:17:21: Error: Undefined name 'kZoomFactor'.
    expect(math.pow(kZoomFactor, kZoomSteps), greaterThan(2.0));
                    ^^^^^^^^^^^
test/zoom_script_test.dart:17:34: Error: Undefined name 'kZoomSteps'.
    expect(math.pow(kZoomFactor, kZoomSteps), greaterThan(2.0));
                                 ^^^^^^^^^^
test/zoom_script_test.dart:22:12: Error: Method not found: 'zoomFocusFor'.
    expect(zoomFocusFor(viewport), const Offset(480, 840));
           ^^^^^^^^^^^^
00:00 +0 -1: loading /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/zoom_script_test.dart [E]
  Failed to load "/Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/zoom_script_test.dart":
  Compilation failed for testPath=.../test/zoom_script_test.dart: ... (same five errors)
00:00 +0 -1: Some tests failed.
```

## GREEN

```
$ cd apps/dev_harness_2d && CI=true flutter test test/zoom_script_test.dart
...
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/zoom_script_test.dart
00:00 +0: the pinned script is 40 in, 40 out, at 1.03
00:00 +1: the focal point is off-centre
00:00 +2: All tests passed!
```

## Both gates

```
$ cd apps/dev_harness_2d && CI=true flutter test --concurrency=1 test/
...
00:00 +0: loading .../test/seam_corpus_test.dart
00:00 +9: (9 seam_corpus_test.dart cases pass)
00:00 +10: loading .../test/pointer_zoom_test.dart
00:12 +17: (8 pointer_zoom_test.dart cases pass)
00:13 +18: loading .../test/zoom_script_test.dart
00:14 +18: the pinned script is 40 in, 40 out, at 1.03
00:14 +19: the focal point is off-centre
00:14 +20: All tests passed!

$ cd apps/dev_harness_2d && CI=true flutter analyze
Analyzing dev_harness_2d...
No issues found! (ran in 1.3s)

$ cd apps/dev_harness_2d && dart format --output=none --set-exit-if-changed lib test
Formatted 6 files (0 changed) in 0.01 seconds.
```

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test
...
00:06 +399 ~1: .../tile_slice_differential_test.dart: tile boundaries carry no difference of their own
00:06 +400 ~1: All tests passed!

$ cd packages/jet_cad_2d_flutter && CI=true flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)

$ cd packages/jet_cad_2d_flutter && dart format --output=none --set-exit-if-changed .
Formatted 71 files (0 changed) in 0.15 seconds.
```

`jet_cad_2d_flutter`'s 400 tests pass with 1 pre-existing skip, unrelated to
this task (that package's source was not touched here). `packages/jet_cad_2d`
was not touched, per the plan's constraint, and was not run.

## Surprising

**`flutter test` (bare, no path) and `flutter test test/` under the
default concurrency silently under-report which test names ran, even though
every test actually passed.** Both bare invocations printed exactly 20
"+N" lines and stopped at `zoom_script_test.dart` never appearing at all —
not even a `loading .../zoom_script_test.dart` line — while
`seam_corpus_test.dart`'s last two named tests ("the corpus carries a
measurer DraftCanvas will accept" / "CORPUS accepts its two values...")
were displayed instead as three repeated "the corpus paints" lines. Adding
`--concurrency=1` (forcing the three test files to run one after another
rather than in parallel worker processes) made `zoom_script_test.dart`
appear, load, and pass, and restored `seam_corpus_test.dart`'s correct test
names. Both runs reported `All tests passed!` with the same final count and
zero failures either way, so this reads as the compact reporter's line
buffer getting overwritten across concurrent worker processes rather than
any test genuinely failing to run or a file genuinely being skipped by the
runner — but it means **a bare `flutter test` transcript in this package is
not reliable evidence that a specific new test file executed**; the
verification above used `--concurrency=1` to get an unambiguous, named
account of every test, including this task's new ones, and that is the
form of the "both gates" transcript recorded above. Worth carrying into
Tasks 12/13 and any future verification here: prefer `--concurrency=1` (or
an explicit file path) when the claim being verified is "this specific test
ran," not just "the suite is green."

The other note worth flagging is intentional rather than surprising: the
`kZoomArms`/main.dart wiring is this implementer's own construction to make
Task 12's already-written `ZOOM_ARMS=4` device command line valid without
that task needing to touch `main.dart` (its file list is scoped to
`measurement_rig.dart` and the results note). Task 11's brief and the design
spec pin the phase's *script* precisely but say nothing about the exact
call-site wiring in `main.dart` beyond listing it as a file to modify; the
wiring implemented here is deliberately minimal — a loop that resets to
R2's fitted camera and calls `runTileZoomPhase` `kZoomArms` times, inert at
its default of zero — so that Task 12 can grow `runInterleaved`'s
rest/tiled arrangement inside `measurement_rig.dart` alone, without needing
to revisit this call site's shape.
