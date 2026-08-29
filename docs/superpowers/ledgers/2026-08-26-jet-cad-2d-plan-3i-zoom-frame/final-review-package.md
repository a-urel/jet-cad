# Plan 3i — whole-branch review package

## Commits (468e310..HEAD)
9206743 docs: Plan 3i's in-flight record -- Rulings 14 and 15, counts at 863b359
863b359 fix(tiles): five deferred Minors from Plan 3i's second review pass
ec6fe18 test(tiles): whether a zoom round trip leaves the next settle trivially covered
50445e4 test(harness): runInterleaved alternates whole arms, never blocks them
2f90f15 feat(tiles): runtime seams for criterion 4's and criterion 8's interleaved arms
0cca785 fix(tests): six deferred Minor findings from Plan 3i's task reviews
63e8cc1 docs: Plan 3i in flight, 11 of 14, blocked on the machine
1aafb39 feat(harness): a pinned tile zoom phase, 40 in and 40 out
faf31b2 test(tiles): an edit after a sliced settle must condemn the slices
1e2f891 test(tiles): differential arms for the slice, the overhang and the pan
6c7e2a0 fix(tiles): pin the states the split test drifted from, and observe _band
715b630 feat(tiles): a resting frame bakes in bands and slices them into tiles
d1bd0dc feat(tiles): slice a band into tiles with band-local integral rects
8007bed feat(tiles): walk one band into one image, padded query and hard clip
e7868f2 feat(tiles): group the visible keys into tile-row bands
527babd fix(tiles): give four tests the frame the two-frame rest gate now needs
ccc7da2 feat(tiles): the byte meter sees a resident band image
9494e99 fix(tiles): Task 3 review findings — add hasCarryOver assertion, M4b mutation
2eebb1a feat(tiles): a rest bake needs two unchanged frames, for the wheel
31399ed fix(tiles): a moving frame with no composite falls through, not blank
d0f39c6 feat(tiles): a moving frame draws the composite and nothing else
6043800 feat(tiles): compare a whole quantised camera, not only its scale

## Stat
```
 STATUS.md                                          |  128 +-
 apps/dev_harness_2d/lib/main.dart                  |   45 +
 apps/dev_harness_2d/lib/measurement_rig.dart       |  288 ++++
 .../dev_harness_2d/test/interleaved_arms_test.dart |   61 +
 apps/dev_harness_2d/test/zoom_script_test.dart     |   24 +
 docs/superpowers/notes/plan-3i-mutation-log.md     | 1632 ++++++++++++++++++++
 .../jet_cad_2d_flutter/lib/src/tile_cache.dart     |  700 ++++++++-
 .../test/invariants/tile_budget_test.dart          |  145 +-
 .../test/invariants/tile_bytes_test.dart           |   63 +
 .../jet_cad_2d_flutter/test/support/fixtures.dart  |   14 +-
 .../test/support/tile_comparison.dart              |  213 ++-
 .../test/support/tile_fixture.dart                 |  135 ++
 .../test/support/tile_harness.dart                 |  203 +++
 .../jet_cad_2d_flutter/test/tile_band_test.dart    |  279 ++++
 .../jet_cad_2d_flutter/test/tile_cache_test.dart   |   91 +-
 .../test/tile_invalidation_test.dart               |   69 +
 .../test/tile_measurement_seam_test.dart           |  245 +++
 .../jet_cad_2d_flutter/test/tile_regime_test.dart  |  167 ++
 .../jet_cad_2d_flutter/test/tile_settle_test.dart  |   47 +-
 .../test/tile_slice_differential_test.dart         |  143 ++
 .../test/tile_zoom_warmth_test.dart                |  232 +++
 21 files changed, 4864 insertions(+), 60 deletions(-)
```

## Diff (-U10)
```diff
diff --git a/STATUS.md b/STATUS.md
index a7d9978..7ab7e86 100644
--- a/STATUS.md
+++ b/STATUS.md
@@ -1,14 +1,14 @@
 # jet-cad — project status
 
 **Last updated:** 2026-08-26
-**Verified against:** `main` at `967fa3b` — the tile-settle fix, landed after
+**Verified against:** `main` at `1aafb39` — the tile-settle fix, landed after
 Plan 3h from looking at the running window rather than from any plan. Plan 3h
 itself ends at `122b6e3`. **Plan 3h ran directly on `main`,
 `f642202..122b6e3`, eight tasks (the eighth split into 8a and 8b), nothing in
 flight** — no worktree, on the human's standing consent, the same as Plans
 3e, 3f, 3f.1 and 3g. The tree is clean apart from the three files the traps
 below say never to commit. Every suite count below was produced by running
 that suite on this tree on 2026-08-25 or 2026-08-26, not by reading a
 report — with the one exception the table marks as not re-run.
 
 ---
@@ -420,23 +420,143 @@ yet archived.~~ **Done**, at
 with 3g's and 3f.1's beside it. The git-ignored workspace is gone. **No ledger
 chore is outstanding.** The ordering is still the lesson every archive note in
 this file records: archive onto the branch before the workspace is deleted,
 never after.
 
 **Since Plan 3h, four findings came out of running the harness by hand** —
 two fixed (`fc05076`, `967fa3b`), two measured and deliberately left for 3i.
 Read them before writing 3i's spec:
 [After Plan 3h](#after-plan-3h--what-the-window-showed-2026-08-26).
 
-**Next: Plan 3i, then Plan 3j.** Plan 3h did not choose an order and each is
-independent of the other; **the human chose 3i on 2026-08-26**, after the
-zoom measurements below landed in its scope.
+**Plan 3i is IN FLIGHT on `main`, 12 of 14 tasks done plus the code halves of
+12 and 13.** Only the *device* halves of Tasks 12 and 13 are left, and they are
+blocked on the machine and not on the code — see
+[Plan 3i in flight](#plan-3i--in-flight-11-of-14) immediately below. **Read
+that before touching the tile cache**: the spec declined level-of-detail
+geometry, so the paragraph after it, written before 3i's spec existed, no
+longer describes what 3i is doing.
+
+**Then Plan 3j.** Plan 3h did not choose an order and each is independent of
+the other; **the human chose 3i on 2026-08-26**, after the zoom measurements
+below landed in its scope.
+
+---
+
+## Plan 3i — in flight, 12 of 14 plus two code halves
+
+**Spec:** [2026-08-26-jet-cad-2d-plan-3i-zoom-frame-design.md](docs/superpowers/specs/2026-08-26-jet-cad-2d-plan-3i-zoom-frame-design.md),
+written 2026-08-26 and revised twice against five external reviews.
+**Plan:** [2026-08-26-jet-cad-2d-plan-3i-zoom-frame.md](docs/superpowers/plans/2026-08-26-jet-cad-2d-plan-3i-zoom-frame.md).
+**Range:** `468e310..863b359`, twenty-one commits, directly on `main`, no
+worktree, on the human's standing consent — the arrangement of 3e through 3h.
+Executed with subagent-driven development: a fresh implementer per task, an
+independent reviewer after each, and the controller running the full gate
+itself after every task.
+
+**G3 is NOT this plan's subject, and the spec says why.** The human chose a
+map-application target — *the gesture stays smooth even if what it shows is
+stale, and the drawing snaps to full resolution when the gesture ends* — and
+under that target a correct frame during a pinch is never drawn, so the
+32.06 ms it costs stops blocking. **G3 becomes necessary the day the target
+changes to correct geometry while the fingers are still moving.**
+
+**What landed.** A tiled frame now has two regimes. A **moving** frame — one
+whose quantised camera changed, or that has not yet seen two unchanged frames
+— draws the carry-over composite and nothing else: no bake, and no live walk.
+A **resting** frame walks the visible region **one tile row at a time** into a
+band image and cuts tiles out of it, one walk per band instead of one per
+tile. Bands rather than one image because the union of visible keys has the
+tile set's own area — `visibleKeys` yields a full rectangle — so a single
+source plus the tiles sliced from it peaks at exactly `kTileCacheBytes` with
+no headroom.
+
+**Blocked, and it is the machine.** At `863b359` the laptop reads
+`lowpowermode 1` and "Now drawing from 'Battery Power'". Either alone
+invalidates a frame-timing measurement and Plan 3h's record documents losing
+time to each separately. **Tasks 12 and 13 resume when `pmset -g | grep
+lowpowermode` reads 0 and `pmset -g ps` says AC Power.** Nothing about the
+code is waiting.
+
+**Suites at `863b359`,** each run by the controller rather than read from a
+report: **797** engine, **405** widget with 1 pre-existing skip, **23**
+harness. Analyze and format clean in all three.
+
+**Sixteen mutants fired so far.** M1, M2, M3, M4, M4b, M5, M6, M6b, M7, M9,
+M9b, M10, M12, M13, M14, M15 and M16 killed. **Mutant numbering is per-plan:
+`M4` and `M5` name different mutations in Plan 3h's log and Plan 3i's, so any
+citation must name the plan.** **M8 survived as declared** — with integral source
+rectangles a bilinear and a nearest sample read the same texels, and it was
+written down as a survivor before it was fired, the way Plan 3h recorded its
+own M6. **M11 turned out to be unreachable by pixels**: the rebase origin
+cancels in `float64` before anything reaches `float32`, about 1e-13 device
+pixels, so its gate of record is Task 6's direct origin-argument test rather
+than a differential arm.
+
+**Two defects were found in this plan's own instruments, both of the
+vacuous-gate class this repository exists to catch, and both found by firing a
+mutant and noticing it did not die.**
+
+1. **`captureLive` was returning the tiled image byte for byte.**
+   `shouldRepaint` is unconditionally false, so the "live" capture was the
+   tiled one. Six mutants read zero differing pixels until a distinct
+   `ValueKey` forced a separate element. A differential instrument was
+   comparing a frame with itself.
+2. **`pumpTiled`'s canvas was never the viewport it claimed.** A `SizedBox`
+   under `pumpWidget`'s tight constraints is inert, so every test built on that
+   helper since Task 2 ran at 800x600 logical rather than 400x300 — 475 tiles,
+   not 130 — and the fixture left 38% of each frame blank. No assertion value
+   moved when it was fixed; several comments became true.
+
+**Two rulings a later reader must not mistake for drift.**
+
+- **Ruling 14 — the plan pinned two interleaved measurements and built no way
+  to run either.** Criterion 4 alternates a rest-bake arm with a "rest bake
+  disabled" arm; criterion 8 alternates a narrow arm with Plan **3h**'s M4
+  mutation. Both arrangements are *same session, interleaved*, and two
+  binaries cannot interleave — so both arms need a runtime switch, and neither
+  existed. `TileCache.debugRestBakeDisabled` and
+  `TileCache.debugFullViewportQuery` were added for exactly this, default
+  `false`, no `lib/` writer, each proved to actually change an observable
+  counter by its own mutant (M13, M14) and the second one's narrow clip — what
+  makes it 3h's M4 rather than its M5 — pinned by `debugLastClip` and M16.
+  **The second switch ships a known defect behind a flag**, which is stated at
+  the field. Without both switches, both arms of each ratio run identical code
+  and every reading is 1.00 — the degenerate fixture, landed in a document of
+  record.
+- **Ruling 15 — criterion 3 is scored as `settleFrames == 2`, not `== 1`, and
+  this is a spec contradiction rather than a moved threshold.** The criteria
+  table says the settle completes in **one** frame; `kRestGateFrames = 2` is
+  pinned separately in the same spec, for its own reason (a pan straight after
+  a zoom finds an empty generation and would otherwise arm the gate mid-pan).
+  The last gesture frame changes the camera, so idle frame 1 can only reach
+  `_restGateSteps == 1` and takes the moving-frame early return; idle frame 2
+  is the first that can bake. **On correct code `settleFrames` is always 2**,
+  so criterion 3 as literally written is a gate only broken code could pass.
+  The correction is derived from a pinned constant and was recorded **before
+  any device run**, so there is no result it could have been fitted to; the
+  results note must carry the reading and the arithmetic so a reader can
+  disagree without re-deriving it.
+
+**Two findings for the record that are not this plan's to fix.**
+
+- **`DraftPainter` queries the index unslacked** (`draft_painter.dart:338`
+  sets `_worldRect` from `camera.visibleWorld(viewport)`) while a bake pads by
+  `kTileSlack`, so an untiled reference drops strokes centred just outside a
+  viewport edge — **measured 1,767 stray pixels**. Fixing it is a production
+  change that could move goldens, so Task 9 left it and routed its arms' ink
+  away from the blind window instead, saying so at the assertion.
+- **`bakeCount` now mixes units**: once per band on the rest path, once per
+  tile on the budgeted path. A reader comparing against Plan 3g and 3h
+  transcripts, where it meant tiles, will be misled unless the phase's own
+  label is read.
+
+---
 
 1. **Plan 3i — zoom, G3, and level-of-detail geometry**, assigned by Plan 3g
    and confirmed here (2026-08-25's memory measurement showed zoom's cost is
    not a caching problem, which is what licensed finishing the pan frame
    without settling it first). **G3 has a number**: 32.06 ms at 500,000
    entities with tiles on. **No caching scheme touches it** — the triangles
    are genuinely being drawn — so the answer is level-of-detail geometry, and
    the tile cache can already hold it: a generation is keyed by scale, so a
    coarser bake can never outlive the scale it was simplified for. **Plan 3h
    adds one more thing for 3i to carry**: settling criterion 3 needs
diff --git a/apps/dev_harness_2d/lib/main.dart b/apps/dev_harness_2d/lib/main.dart
index 39b9cca..94092b0 100644
--- a/apps/dev_harness_2d/lib/main.dart
+++ b/apps/dev_harness_2d/lib/main.dart
@@ -258,20 +258,36 @@ double _doubleDefine(String name, String raw, double fallback,
 /// `sqrt(58)` = 7.615773; `PAN_STEP=7.6` would scale it by 0.99793 and make
 /// the arm incomparable with every row already recorded at it. `NaN` is the
 /// sentinel for unset because zero is a legal magnitude to ask about.
 ///
 /// It reaches the **tile phase only**. R2's own pan keeps `Offset(-7, -3)`
 /// unconditionally, or every prior plan's R2 row becomes incomparable.
 final double kPanStep = _doubleDefine(
     'PAN_STEP', const String.fromEnvironment('PAN_STEP'), double.nan,
     minimum: 0);
 
+/// How many times `RUN_R2` repeats the `tile zoom` phase
+/// ([runTileZoomPhase]) after `runR2Rig` finishes, each run starting fresh
+/// from R2's own fitted camera. Zero means the phase never runs at all.
+///
+/// **An `int.fromEnvironment` would be wrong here for [_intDefine]'s
+/// standing reason**: it silently reads anything it cannot parse as the
+/// default, and `ZOOM_ARMS=4` mistyped as `ZOOM_ARMS=4x` would run zero arms
+/// while looking like a run that asked for four.
+///
+/// Inert at its default of zero: an ordinary `RUN_R2` session is unaffected,
+/// and this is additive to `runR2Rig`'s own pan and zoom phases, not a
+/// replacement for either.
+final int kZoomArms = _intDefine(
+    'ZOOM_ARMS', const String.fromEnvironment('ZOOM_ARMS'), 0,
+    minimum: 0);
+
 /// The one measurer the harness document is built with, reachable from
 /// `_HarnessState.dispose` so the native paragraphs it holds are released.
 ///
 /// A field rather than an inline argument because `DraftCanvas` no longer
 /// disposes the cache: the document owns it and the application releases it.
 final FlutterTextMeasurer harnessMeasurer = FlutterTextMeasurer();
 
 /// The corpus the rigs measure on: the same shape as R1's, so the two sets of
 /// numbers describe one drawing.
 ///
@@ -474,35 +490,64 @@ Future<void> _driveR2(
   final view = WidgetsBinding.instance.platformDispatcher.views.first;
   final viewport = view.physicalSize / view.devicePixelRatio;
   camera.value = ViewportTransform.fit(
       Aabb2(Vector2(cx - 1500, cy - 1125), Vector2(cx + 1500, cy + 1125)),
       viewport);
   await _pumpFrame();
 
   print('R2 app-run: window=${viewport.width.toStringAsFixed(0)}x'
       '${viewport.height.toStringAsFixed(0)} dpr=${view.devicePixelRatio}');
 
+  // R2's fitted camera, held so the `tile zoom` phase below can restart from
+  // it — [runR2Rig] moves `camera` through its own 240-frame script, and by
+  // the time it returns the fitted state above is long gone.
+  final fittedCamera = camera.value;
+
   await runR2Rig(
     entities: kEntities,
     lineweightScale: kLineweightScale,
     textCorpus: kTextCorpus,
     drawText: kDrawText,
     camera: camera,
     painter: painter,
     sink: sink,
     vertices: vertices,
     resolvedBackend: resolvedBackend,
     tileCache: tileCache,
     pumpFrame: _pumpFrame,
     settle: _settle,
     panStep: kPanStep,
   );
+
+  // The `tile zoom` phase (Plan 3i, Task 11): `ZOOM_ARMS` repeats of the
+  // pinned script, each starting fresh from the same fitted camera `runR2Rig`
+  // itself started from, so this arm and Plan 3h's tile-pan arm inside
+  // `runR2Rig` describe the same starting state. Off by default -- see
+  // [kZoomArms].
+  if (tileCache != null && kZoomArms > 0) {
+    // The pinned reference viewport (§5), not `viewport` above -- see
+    // `runTileZoomPhase`'s doc comment for what a differently sized real
+    // window means for these numbers.
+    const zoomViewport = Size(1600, 1200);
+    warnIfZoomViewportMismatch(viewport, zoomViewport);
+    for (var arm = 0; arm < kZoomArms; arm++) {
+      camera.value = fittedCamera;
+      await _pumpFrame();
+      final zoomReport = await runTileZoomPhase(
+        camera: camera,
+        cache: tileCache,
+        pumpFrame: _pumpFrame,
+        viewport: zoomViewport,
+      );
+      printZoomReport('R2 tile zoom arm $arm ($kEntities)', zoomReport);
+    }
+  }
   print('R2 app-run: done');
 }
 
 /// Renders exactly one frame and completes after it.
 ///
 /// This is called from inside `_HarnessAppState`'s own post-frame callback —
 /// [SchedulerBinding.instance.schedulerPhase] is `postFrameCallbacks`, not
 /// `idle`, at that point, and [SchedulerBinding.endOfFrame] only calls
 /// [SchedulerBinding.scheduleFrame] for you when the phase is idle. Relying
 /// on `camera.value = ...`'s listener chain to schedule the next frame as a
diff --git a/apps/dev_harness_2d/lib/measurement_rig.dart b/apps/dev_harness_2d/lib/measurement_rig.dart
index b982709..2f7e973 100644
--- a/apps/dev_harness_2d/lib/measurement_rig.dart
+++ b/apps/dev_harness_2d/lib/measurement_rig.dart
@@ -630,10 +630,298 @@ void _probeBake(TileCache cache, CameraController camera, DraftPainter painter,
       'liveLeaves=$liveLeaves '
       'tileLeaves=$tileLeaves '
       'overdraw=${(tileLeaves / liveLeaves).toStringAsFixed(3)} '
       'areaFactor=${areaFactor.toStringAsFixed(3)}');
   print(
       '    liveWalkMs=${(liveWatch.elapsedMicroseconds / 1000.0).toStringAsFixed(2)} '
       'tileWalkMsTotal=${walkMs.toStringAsFixed(2)} '
       'walkMsPerTile=${(walkMs / tiles).toStringAsFixed(3)} '
       'visibleSetBytes=${tiles * cache.tileDevicePixels * cache.tileDevicePixels * 4}');
 }
+
+/// Steps in each direction of the `tile zoom` phase's script. See Plan 3i's
+/// Task 11 for why 40 and not fewer: `kZoomFactor ^ kZoomSteps` = 3.26x,
+/// which cannot sit inside one power-of-two rebase step
+/// ([rebaseOriginFor] in `camera_controller.dart`) -- a script that stays
+/// inside one step never re-quantises and the anti-degenerate rule (clause
+/// 3) is unmet.
+///
+/// Pinned by the spec, §5. Not the implementer's to adjust -- see the task
+/// brief and the design spec before changing either constant.
+const int kZoomSteps = 40;
+
+/// Per-step zoom factor, matching what one trackpad update delivers. Pinned
+/// alongside [kZoomSteps].
+const double kZoomFactor = 1.03;
+
+/// The `tile zoom` phase's focal point: deliberately off-centre, at 30%/70%
+/// of the viewport.
+///
+/// A focal point at the viewport's centre is the degenerate case -- the
+/// anchor would coincide with [rebaseOriginFor]'s own centre and half the
+/// residual arithmetic the zoom exercises would never run (anti-degenerate
+/// rule, clause 5).
+///
+/// [viewport] is the size the script's own numbers are priced against --
+/// the pinned **1600x1200 logical at `devicePixelRatio` 2** reference
+/// viewport (§5), not necessarily whatever the real window happens to be.
+/// See [runTileZoomPhase]'s doc comment for what that means for a caller.
+Offset zoomFocusFor(Size viewport) =>
+    Offset(viewport.width * 0.30, viewport.height * 0.70);
+
+/// Warns, loudly, when the window a caller is about to run [runTileZoomPhase]
+/// against is not [pinned] -- the 1600x1200 logical reference every number in
+/// design spec §5, and every figure in this plan's measurement notes, is
+/// priced against.
+///
+/// **A warning, not a throw.** [runTileZoomPhase] accepts any finite viewport
+/// and still produces a report -- refusing to run would trade a labelled
+/// number for no number at all, which is worse for an operator mid-session
+/// than a number they have to read the label on. Before this check, the only
+/// way to notice a mismatch was the unrelated `R2 app-run: window=...` print
+/// upstream -- easy to have scrolled past by the time the zoom arm's numbers
+/// print. This check sits at the call site itself, so the warning lands right
+/// next to the numbers it is warning about.
+void warnIfZoomViewportMismatch(Size real, Size pinned) {
+  if (real == pinned) return;
+  print('  !!! WARNING: tile zoom phase run at window='
+      '${real.width.toStringAsFixed(0)}x${real.height.toStringAsFixed(0)}, '
+      'not the pinned reference ${pinned.width.toStringAsFixed(0)}x'
+      '${pinned.height.toStringAsFixed(0)} -- the numbers below are measured '
+      'at the WRONG VIEWPORT and are not comparable to design spec §5 or to '
+      'any run at the pinned size !!!');
+}
+
+/// What [runTileZoomPhase] reports: the gesture's frame times and the
+/// cache's counters over it, then the settle that follows.
+class ZoomReport {
+  ZoomReport({
+    required this.gestureFrameMs,
+    required this.gestureBakes,
+    required this.gestureLiveDraws,
+    required this.settleMs,
+    required this.settleFrames,
+  });
+
+  /// `totalSpan`, one entry per gesture frame -- 80 entries at the pinned
+  /// script (`2 * kZoomSteps`). p95 over this list is criterion 2.
+  final List<double> gestureFrameMs;
+
+  /// [TileCache.bakeCount] since the counters were reset at the start of the
+  /// gesture, read at the gesture's end.
+  ///
+  /// **This is the budgeted path's unit: once per tile, not once per band.**
+  /// Every frame in the 80-frame gesture is a *moving* frame -- the camera
+  /// changes every frame by construction -- so [TileCache.paintFrame]'s rest
+  /// branch (`_restBake`, counted once per band) never runs during the
+  /// gesture; only the ordinary budgeted tile loop could contribute here.
+  /// Criterion 1 expects this at zero. A reader comparing this figure
+  /// against a settle-phase bake count (band-counted) would be comparing two
+  /// different units -- see `TileCache.bakeCount`'s own doc comment.
+  final int gestureBakes;
+
+  /// [TileCache.liveDrawCount] over the same window as [gestureBakes].
+  /// Criterion 1 expects this at zero too.
+  final int gestureLiveDraws;
+
+  /// `totalSpan` of the one idle frame at which [TileCache.viewportCovered]
+  /// first became true, or of the last idle frame pumped if 30 idle frames
+  /// never reached coverage. Criterion 3 reads this.
+  final double settleMs;
+
+  /// How many idle frames elapsed before [TileCache.viewportCovered] first
+  /// read true (1 if the very first idle frame after the gesture already
+  /// covers, which is what criterion 3 asserts), or 30 if coverage was never
+  /// reached within the pinned idle-frame budget.
+  final int settleFrames;
+}
+
+/// The `tile zoom` phase, pinned by the design spec (§5) and not the
+/// implementer's to choose: [kZoomSteps] frames zooming in at [kZoomFactor]
+/// about [zoomFocusFor], then [kZoomSteps] zooming back out at
+/// `1 / kZoomFactor` about the same point -- one camera change per frame,
+/// matching what a trackpad delivers -- then 30 idle frames, where the
+/// settle is read.
+///
+/// **[camera] must already be at R2's fitted camera** (the same
+/// `ViewportTransform.fit` the caller's R2 rig used, before that rig's own
+/// scripted motion), so the zoom arm and Plan 3h's tile-pan arm are
+/// comparable measurements of the same starting state, not of two different
+/// cameras.
+///
+/// **[viewport] is the pinned reference size, 1600x1200 logical at
+/// `devicePixelRatio` 2 -- not necessarily the real window.** Every number
+/// in the design spec's §5 is priced against that size; [zoomFocusFor] turns
+/// it into a screen-space anchor the same way `runR2Rig`'s own zoom step
+/// anchors at the fixed `Offset(800, 600)` (that phase's viewport centre)
+/// regardless of what window the app is actually running in. A caller on a
+/// real window of a different size gets a phase that still runs -- `zoomAt`
+/// accepts any finite, positive factor at any screen point -- but the
+/// focal point then sits at a different fraction of the *real* viewport than
+/// 30%/70%, and comparing its numbers against another run's figures, or
+/// against the design spec's priced predictions, is only sound once the
+/// window is confirmed to actually be the reference size. `main.dart`'s
+/// `RUN_R2` mode prints the real window size for exactly this reason; a
+/// caller of this phase should do the same.
+///
+/// The idle frames drive no camera change at all -- unlike the forced
+/// no-op `panBy(Offset.zero)` this file's other phases use to force a final
+/// repaint once nothing is dirty, an idle frame here is a bare [pumpFrame]
+/// call. `DraftCanvasState`'s own settle notifier
+/// (`draft_canvas.dart:_requestSettleFrame`) is what keeps requesting a real
+/// frame for as long as the cache owes tiles; forcing one artificially would
+/// measure a phase this rig does not actually drive on a real trackpad
+/// gesture's tail.
+Future<ZoomReport> runTileZoomPhase({
+  required CameraController camera,
+  required TileCache cache,
+  required Future<void> Function() pumpFrame,
+  required Size viewport,
+}) async {
+  refuseDebugMode();
+  final focus = zoomFocusFor(viewport);
+
+  // Two throwaway frames before the counters reset, the same boundary slack
+  // `runTilePhases`'s own `phase()` helper takes: a `FrameTiming` is reported
+  // after its frame rasterises, so the phase boundary needs a frame or two of
+  // slack the gesture itself must not be charged for.
+  for (var i = 0; i < 2; i++) {
+    camera.panBy(Offset.zero);
+    await pumpFrame();
+  }
+
+  final gestureTimings = <FrameTiming>[];
+  void collectGesture(List<FrameTiming> t) => gestureTimings.addAll(t);
+  SchedulerBinding.instance.addTimingsCallback(collectGesture);
+  // Warm-up excluded: reset only after the fitted camera has settled (the
+  // two throwaway frames above), per §5.
+  cache.resetCounters();
+  try {
+    for (var i = 0; i < kZoomSteps; i++) {
+      camera.zoomAt(focus, kZoomFactor);
+      await pumpFrame();
+    }
+    for (var i = 0; i < kZoomSteps; i++) {
+      camera.zoomAt(focus, 1 / kZoomFactor);
+      await pumpFrame();
+    }
+  } finally {
+    SchedulerBinding.instance.removeTimingsCallback(collectGesture);
+  }
+  final gestureBakes = cache.bakeCount;
+  final gestureLiveDraws = cache.liveDrawCount;
+  final gestureFrameMs = [
+    for (final t in gestureTimings) t.totalSpan.inMicroseconds / 1000.0
+  ];
+
+  // 30 idle frames. No camera nudge -- see the doc comment above for why a
+  // bare pumpFrame is the honest idle frame here. Tracks the first frame at
+  // which the viewport becomes covered, which is what criterion 3 reads;
+  // still pumps the full 30 so a cache that keeps asking for frames after
+  // coverage (which it must not) is exercised the same way a real trackpad
+  // gesture's tail would exercise it.
+  const idleFrames = 30;
+  var settleFrames = idleFrames;
+  var settleMs = 0.0;
+  var covered = false;
+  for (var i = 0; i < idleFrames; i++) {
+    final idleTimings = <FrameTiming>[];
+    void collectIdle(List<FrameTiming> t) => idleTimings.addAll(t);
+    SchedulerBinding.instance.addTimingsCallback(collectIdle);
+    try {
+      await pumpFrame();
+    } finally {
+      SchedulerBinding.instance.removeTimingsCallback(collectIdle);
+    }
+    final frameMs = idleTimings.isEmpty
+        ? 0.0
+        : idleTimings.last.totalSpan.inMicroseconds / 1000.0;
+    if (!covered && cache.viewportCovered) {
+      covered = true;
+      settleFrames = i + 1;
+      settleMs = frameMs;
+    } else if (!covered) {
+      // Not yet covered: keep the running "last frame pumped" figure, so a
+      // script that never reaches coverage within the idle budget still
+      // reports something rather than 0.0.
+      settleMs = frameMs;
+    }
+  }
+
+  return ZoomReport(
+    gestureFrameMs: gestureFrameMs,
+    gestureBakes: gestureBakes,
+    gestureLiveDraws: gestureLiveDraws,
+    settleMs: settleMs,
+    settleFrames: settleFrames,
+  );
+}
+
+/// Prints a [ZoomReport] the way [report] prints a plain frame-timing list,
+/// plus the counters [report] alone cannot see.
+///
+/// **`gestureBakes` is the budgeted, per-tile unit of [TileCache.bakeCount],
+/// not the per-band unit the rest bake counts in.** See [ZoomReport
+/// .gestureBakes]'s own doc comment for why: every gesture frame is moving,
+/// so the rest path never contributes to it. A reader comparing this figure
+/// against a Plan 3g or 3h transcript, where `bakeCount` always meant tiles,
+/// is comparing like with like here -- but comparing it against this same
+/// cache's post-settle `bakeCount` would not be, because a rest bake (if one
+/// fired during the idle frames this report also covers) counts bands.
+void printZoomReport(String label, ZoomReport r) {
+  if (r.gestureFrameMs.isEmpty) {
+    print('$label: no gesture frames recorded');
+  } else {
+    final sorted = [...r.gestureFrameMs]..sort();
+    var sum = 0.0;
+    for (final v in sorted) {
+      sum += v;
+    }
+    print('$label gestureFrames=${sorted.length} '
+        'p50=${sorted[(sorted.length * 0.5).floor()].toStringAsFixed(2)}ms '
+        'p95=${sorted[(sorted.length * 0.95).floor()].toStringAsFixed(2)}ms '
+        'max=${sorted.last.toStringAsFixed(2)}ms '
+        'mean=${(sum / sorted.length).toStringAsFixed(2)}ms');
+  }
+  print('  gestureBakes=${r.gestureBakes}(tiles, budgeted path) '
+      'gestureLiveDraws=${r.gestureLiveDraws}');
+  print('  settleFrames=${r.settleFrames} '
+      'settleMs=${r.settleMs.toStringAsFixed(2)}');
+}
+
+/// Runs [rest] and [tiled] alternately — `rest, tiled, rest, tiled, …` — for
+/// [arms] repeats of each, awaiting every callback before starting the next.
+///
+/// **The interleaved unit is one whole arm, not one frame.** An arm is a
+/// complete phase — a zoom script, its settle and its report — and splitting
+/// it finer would interleave two half-measured caches into each other's
+/// generations. What is refused here is the *blocked* ordering: all of one arm
+/// and then all of the other.
+///
+/// **Why it matters, in this repository's own numbers.** A measurement session
+/// drifts: the machine warms, other processes come and go, the shader cache
+/// fills. Under a blocked ordering every bit of that drift lands on whichever
+/// arm ran last, and the ratio reports the drift as if it were the effect.
+/// `docs/superpowers/notes/2026-08-25-plan-3h-results.md` records exactly that
+/// happening — its M4 arm ran last, in a visibly noisier session, on a phase
+/// M4 is inert on, so the ordering and not the mutation moved the numbers.
+/// Alternating puts the same drift on both arms, where a ratio divides it out.
+///
+/// It reports nothing itself and holds no state: each callback owns its own
+/// configuration and its own printing, so the two arms of criterion 4 (the
+/// rest bake against `TileCache.debugRestBakeDisabled`) and the two arms of
+/// criterion 8 (the narrowed query against `TileCache.debugFullViewportQuery`)
+/// can share this one driver without it knowing which switch it is driving.
+///
+/// `arms: 0` calls neither, rather than running one of each — the count is a
+/// number of repeats, and an off-by-one here would silently publish an n=1
+/// row under an n=0 heading.
+Future<void> runInterleaved({
+  required int arms,
+  required Future<void> Function() rest,
+  required Future<void> Function() tiled,
+}) async {
+  for (var i = 0; i < arms; i++) {
+    await rest();
+    await tiled();
+  }
+}
diff --git a/apps/dev_harness_2d/test/interleaved_arms_test.dart b/apps/dev_harness_2d/test/interleaved_arms_test.dart
new file mode 100644
index 0000000..2941324
--- /dev/null
+++ b/apps/dev_harness_2d/test/interleaved_arms_test.dart
@@ -0,0 +1,61 @@
+// `runInterleaved`'s ordering, which is the entire content of the function
+// and the entire reason it exists.
+//
+// Plan 3i's Tasks 12 and 13 both score a ratio between two arms run **in one
+// session**. A driver that ran all of one arm and then all of the other would
+// satisfy "both arms ran" and still carry the bias those tasks exist to
+// remove — session and thermal drift landing on whichever arm ran last. So
+// the assertion here is on the *sequence*, recorded by the callbacks
+// themselves, and not on the call counts: three rests and three tileds is
+// true of the blocked ordering too.
+
+import 'package:dev_harness_2d/measurement_rig.dart';
+import 'package:flutter_test/flutter_test.dart';
+
+void main() {
+  test('three arms alternate, never block', () async {
+    final order = <String>[];
+    await runInterleaved(
+      arms: 3,
+      rest: () async => order.add('rest'),
+      tiled: () async => order.add('tiled'),
+    );
+    expect(order, <String>['rest', 'tiled', 'rest', 'tiled', 'rest', 'tiled']);
+  });
+
+  test('zero arms calls neither', () async {
+    final order = <String>[];
+    await runInterleaved(
+      arms: 0,
+      rest: () async => order.add('rest'),
+      tiled: () async => order.add('tiled'),
+    );
+    expect(order, isEmpty);
+  });
+
+  test('each callback is awaited before the next arm starts', () async {
+    // Without the `await`s a `for` loop over async callbacks still produces
+    // the right *call* order and the wrong *completion* order: every arm
+    // would be in flight at once, and two measurement phases sharing one
+    // engine would interleave their frames rather than their arms. Each
+    // callback below records on both sides of a real suspension, so the
+    // transcript can tell the two apart.
+    final order = <String>[];
+    Future<void> Function() phase(String name) => () async {
+          order.add('$name:start');
+          await Future<void>.delayed(Duration.zero);
+          order.add('$name:end');
+        };
+    await runInterleaved(arms: 2, rest: phase('rest'), tiled: phase('tiled'));
+    expect(order, <String>[
+      'rest:start',
+      'rest:end',
+      'tiled:start',
+      'tiled:end',
+      'rest:start',
+      'rest:end',
+      'tiled:start',
+      'tiled:end',
+    ]);
+  });
+}
diff --git a/apps/dev_harness_2d/test/zoom_script_test.dart b/apps/dev_harness_2d/test/zoom_script_test.dart
new file mode 100644
index 0000000..5d35e43
--- /dev/null
+++ b/apps/dev_harness_2d/test/zoom_script_test.dart
@@ -0,0 +1,24 @@
+// The `tile zoom` phase's script is pinned by the spec (§5) and is not the
+// implementer's to choose. These are unit tests of the script's *shape* --
+// the constants and the focal-point formula -- not a measurement. Tasks 12
+// and 13 drive the phase itself on a real device.
+import 'dart:math' as math;
+
+import 'package:dev_harness_2d/measurement_rig.dart';
+import 'package:flutter/widgets.dart';
+import 'package:flutter_test/flutter_test.dart';
+
+void main() {
+  test('the pinned script is 40 in, 40 out, at 1.03', () {
+    expect(kZoomSteps, 40);
+    expect(kZoomFactor, closeTo(1.03, 1e-12));
+    // The span each way, and the reason clause 3 is satisfied: a 3.26x span
+    // cannot sit inside one power-of-two rebase step.
+    expect(math.pow(kZoomFactor, kZoomSteps), greaterThan(2.0));
+  });
+
+  test('the focal point is off-centre', () {
+    const viewport = Size(1600, 1200);
+    expect(zoomFocusFor(viewport), const Offset(480, 840));
+  });
+}
diff --git a/docs/superpowers/notes/plan-3i-mutation-log.md b/docs/superpowers/notes/plan-3i-mutation-log.md
new file mode 100644
index 0000000..722ffeb
--- /dev/null
+++ b/docs/superpowers/notes/plan-3i-mutation-log.md
@@ -0,0 +1,1632 @@
+# Plan 3i — mutation log
+
+> **Note: mutant numbering is per-plan, and `M4`/`M5` collide with
+> `plan-3h-mutation-log.md`.** This file's own `M4` (§"M4 — the wheel clause")
+> and `M5` name different mutations from Plan 3h's `M4` ("narrow the clip but
+> not the query") and `M5` ("grow the query and leave the clip untouched").
+> `TileCache.debugFullViewportQuery`, its doc comment and this file's `M14`
+> entry all say "Plan 3h's M4" explicitly for exactly this reason. Any
+> citation of `M4` or `M5` from either log must name the plan it belongs to.
+
+> **Note, added once the batch-minors pass understood the discrepancy below:**
+> M2, M6 and M6b were all measured under Task 8, before Task 9's `Center` fix
+> to `pumpTiled` (`support/tile_harness.dart`, commit `1e2f891`) landed.
+> Before that fix, `pumpWidget` handed the canvas its surface's *tight*
+> constraints and the un-centred `SizedBox` was inert against them, so the
+> canvas those three mutants ran on was 800x600 logical -- 1600x1200 device
+> pixels at `kTileDpr`, 25 x 19 = 475 tiles, ~19 one-tile-row bands -- not the
+> 400x300 logical / 130 tile / ~10 band canvas the fix made every later entry
+> in this file true of. The kills stand and are **not re-run**: each mutation
+> still produces exactly the failure its own entry describes, on whatever
+> canvas the suite ran against that day, and a canvas size does not decide
+> whether a band image leaks or a slice loop drops eleven tiles. What the note
+> is for is the raw counts those three entries print -- `475`, `513`, `38`,
+> `19 bands`, and the `800x600`/`BoxConstraints(w=800.0, h=600.0)` seen in one
+> stack trace -- so a reader does not mistake them for the fixed canvas's
+> figures (130 tiles, ~10 bands) or wonder why they disagree with every later
+> entry.
+
+## M1
+
+**Task:** Task 2, "A moving frame draws the composite and nothing else."
+
+**Mutation:** In `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`'s
+`paintFrame`, deleted the guard block
+
+```dart
+    if (!resting) {
+      // Nothing else this frame. The composite is already down; a zoom out
+      // leaves its ring as background until the gesture ends (spec D3).
+      return;
+    }
+```
+
+leaving `resting` computed but unused, and the visible-key loop (and
+therefore the bake and the live walk) running on every frame regardless of
+whether the frame is moving.
+
+**Procedure:** copied `tile_cache.dart` aside to the scratchpad, edited the
+working file to delete the block above, ran the test, then restored the
+working file from the copy. **Never `git checkout`.**
+
+**Result:** red, as expected — the moving-frame test in
+`test/tile_regime_test.dart` fails because baking resumes on every frame.
+
+**Verbatim output:**
+
+```
+00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart
+00:00 +0: the same camera compares same
+00:00 +1: a scale change compares different
+00:00 +2: a translation change compares different
+00:00 +3: the skew terms are compared too
+00:00 +4: a moving frame bakes nothing and walks nothing
+══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
+The following TestFailure was thrown running a test:
+Expected: <0>
+  Actual: <512>
+a moving frame must bake nothing
+
+When the exception was thrown, this was the stack:
+#4      main.<anonymous closure> (file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart:108:5)
+<asynchronous suspension>
+#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
+<asynchronous suspension>
+#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
+<asynchronous suspension>
+<asynchronous suspension>
+(elided one frame from package:stack_trace)
+
+This was caught by the test expectation on the following line:
+  file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart line 108
+The test description was:
+  a moving frame bakes nothing and walks nothing
+════════════════════════════════════════════════════════════════════════════════════════════════════
+00:00 +4 -1: a moving frame bakes nothing and walks nothing [E]
+  Test failed. See exception logs above.
+  The test description was: a moving frame bakes nothing and walks nothing
+  
+00:00 +4 -1: Some tests failed.
+
+Failing tests:
+  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart: a moving frame bakes nothing and walks nothing
+```
+
+`bakeCount` is 512 rather than the brief's illustrative "8, one per frame" —
+with the guard gone, every one of the 8 zoom frames bakes as many tiles as
+its budget permits over a viewport this size, not one each — but the failure
+mode (baking resumes on a moving frame) is exactly the one the test is
+chartered to catch.
+
+## M4
+
+**Task:** Task 3, "The wheel clause — two unchanged frames, not one."
+
+**Mutation:** In `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`'s
+`paintFrame`, replaced the `resting` guard:
+
+```dart
+    final resting = previous == null || _carryOver == null || _restGateSteps >= kRestGateFrames;
+```
+
+with:
+
+```dart
+    final resting = !_viewportCovered;
+```
+
+This breaks the rest gate and causes the cache to bake on every frame where
+the viewport is not fully covered, even if the camera is moving.
+
+**Procedure:** copied `tile_cache.dart` aside to the scratchpad, edited the
+working file to replace the resting expression with `!_viewportCovered`, ran
+the test, then restored the working file from the copy. **Never `git checkout`.**
+
+**Result:** red, as expected — both "a moving frame bakes nothing and walks
+nothing" and "a steadily spun wheel never arms the rest gate" tests fail:
+
+**Verbatim output:**
+
+```
+00:00 +4 -1: a moving frame bakes nothing and walks nothing [E]
+  Test failed. See exception logs above.
+Expected: <0>
+  Actual: <512>
+a moving frame must bake nothing
+
+00:00 +5 -2: a steadily spun wheel never arms the rest gate [E]
+  Test failed. See exception logs above.
+Expected: <0>
+  Actual: <768>
+a wheel that keeps turning must never reach two consecutive unchanged frames, so it must never bake
+```
+
+## M4b — the rest gate at one frame instead of two
+
+**Task:** Task 3, "The wheel clause — two unchanged frames, not one."
+
+**Mutation:** In `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`,
+changed the constant:
+
+```dart
+const int kRestGateFrames = 1;
+```
+
+(instead of 2)
+
+This tests whether the threshold itself is correct, independent of the guard's
+other terms. M4 proved the gate is load-bearing; M4b proves the threshold must
+be 2.
+
+**Procedure:** copied `tile_cache.dart` aside, edited the constant from 2 to 1,
+ran the tests, then restored from the copy. **Never `git checkout`.**
+
+**Result:** red, as expected — both affected tests fail:
+
+**Verbatim output:**
+
+```
+00:00 +6 -1: a steadily spun wheel never arms the rest gate [E]
+Expected: <0>
+  Actual: <384>
+a wheel that keeps turning must never reach two consecutive unchanged frames,
+so it must never bake
+
+00:00 +6 -2: the gate needs two unchanged frames, not one [E]
+Expected: <2>
+  Actual: <1>
+```
+
+With kRestGateFrames = 1, the wheel test bakes on every other notch (384 tiles
+instead of 0), confirming the threshold of 2 is necessary to meet the spec.
+
+---
+
+## M2 — the slice loop emits only the first tile of each band
+
+> Measured at the pre-fix 800x600-logical canvas -- see the note at the top
+> of this file. The kill stands; it is not re-run.
+
+**Task 8.** A band is walked and rasterised in full, but only its leftmost tile
+is cut out of it. Every other visible key is left to the budgeted tile loop, so
+a resting frame no longer covers the viewport in one frame — which is the whole
+claim Task 8 lands.
+
+**Mutation:**
+
+```diff
+--- a/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
++++ b/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
+@@ -1172,7 +1172,7 @@
+       // band-coarse, which is right because a band is exactly the unit a
+       // rebake walks.
+       final record = Uint32List.fromList(visited);
+-      for (final key in band.keys) {
++      for (final key in band.keys.take(1)) {
+         // A key this frame's tile map already serves keeps its own image and
+         // its own, narrower record. Overwriting it would leak the image it
+         // replaced -- `_tiles[key] = tile` disposes nothing -- and a pan
+```
+
+**Procedure:** copied `tile_cache.dart` aside, applied the edit, ran
+`CI=true flutter test test/tile_settle_test.dart`, then restored from the copy.
+**Never `git checkout`.**
+
+**Result:** red, as expected.
+
+**Verbatim output:**
+
+```
+00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_settle_test.dart
+00:00 +0: a frame that left tiles unbaked asks for another
+00:00 +1: the settle finishes, and then stops asking
+00:00 +2: the settle completes in one frame
+══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
+The following TestFailure was thrown running a test:
+Expected: true
+  Actual: <false>
+one rest frame covers the viewport; the tiled fill it replaces took one frame per tile
+
+When the exception was thrown, this was the stack:
+#4      main.<anonymous closure> (file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_settle_test.dart:101:5)
+<asynchronous suspension>
+#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
+<asynchronous suspension>
+#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
+<asynchronous suspension>
+<asynchronous suspension>
+(elided one frame from package:stack_trace)
+
+This was caught by the test expectation on the following line:
+  file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_settle_test.dart line 101
+The test description was:
+  the settle completes in one frame
+════════════════════════════════════════════════════════════════════════════════════════════════════
+00:00 +2 -1: the settle completes in one frame [E]
+  Test failed. See exception logs above.
+  The test description was: the settle completes in one frame
+  
+00:00 +2 -1: Some tests failed.
+
+Failing tests:
+  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_settle_test.dart: the settle completes in one frame
+```
+
+---
+
+## M6 — the band image is never disposed
+
+> Measured at the pre-fix 800x600-logical canvas -- see the note at the top
+> of this file. `475`, `513` and `19 bands` below are that canvas's counts,
+> not the fixed canvas's 130 tiles / ~10 bands. The kill stands; it is not
+> re-run.
+
+**Task 8.** The band image is dropped from `_band` but its native memory is
+never released. The brief spells this mutation as deleting `image.dispose();`
+and the `_imagesAlive--;` beside it; the shipped code routes both through
+`_disposeImage`, "the single door every `ui.Image` this cache owns leaves by",
+so deleting that one call is exactly the same mutation — it removes the
+`dispose()` and the decrement together.
+
+**Mutation:**
+
+```diff
+--- a/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
++++ b/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
+@@ -1193,7 +1193,6 @@
+         _lastUsedFrame[key] = _frameSerial;
+       }
+       _band = null;
+-      _disposeImage(image);
+       _bakes++;
+     }
+   }
+```
+
+**Procedure:** copied `tile_cache.dart` aside, applied the edit, ran
+`CI=true flutter test test/invariants/tile_bytes_test.dart`, then restored from
+the copy. **Never `git checkout`.**
+
+**Result:** red, as expected — 38 leaked band images (19 bands across the two
+rest frames this test drives) show up as `debugImagesAlive` exceeding
+`liveTileCount`.
+
+**Verbatim output:**
+
+```
+00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart
+00:00 +0: a live band image is counted in liveBytes
+00:00 +1: the ceiling holds at every point inside the rest frame
+══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
+The following TestFailure was thrown running a test:
+Expected: <475>
+  Actual: <513>
+no band image outlives its band, and the composite was dropped before the bake
+
+When the exception was thrown, this was the stack:
+#4      main.<anonymous closure> (file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart:47:5)
+<asynchronous suspension>
+#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
+<asynchronous suspension>
+#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
+<asynchronous suspension>
+<asynchronous suspension>
+(elided one frame from package:stack_trace)
+
+This was caught by the test expectation on the following line:
+  file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart line 47
+The test description was:
+  the ceiling holds at every point inside the rest frame
+════════════════════════════════════════════════════════════════════════════════════════════════════
+00:00 +1 -1: the ceiling holds at every point inside the rest frame [E]
+  Test failed. See exception logs above.
+  The test description was: the ceiling holds at every point inside the rest frame
+  
+00:00 +1 -1: Some tests failed.
+
+Failing tests:
+  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart: the ceiling holds at every point inside the rest frame
+```
+
+---
+
+## M6b — the band image is never assigned to `_band`
+
+> Measured at the pre-fix 800x600-logical canvas -- see the note at the top
+> of this file (the `BoxConstraints(w=800.0, h=600.0)` in the transcript
+> below is that canvas). The kill stands; it is not re-run.
+
+**Task 8, fix round 1.** The band is baked, sliced and disposed correctly, but
+`_band` is never set, so `liveBytes` cannot see the one image the whole banding
+design exists to bound.
+
+**Why it needed its own mutant.** Task 4 landed `_band` and `debugSetBand` and
+proved `liveBytes` counts a band *handed to the seam*. It could not prove the
+production path puts one there. Task 8 assigns `_band` on the real path, but
+the ceiling assertion it shipped with -- `liveBytes <= kTileCacheBytes` inside
+the slice -- is one-sided: with `_band` unassigned `liveBytes` reads the tile
+sum, which is smaller still and satisfies it, and
+`debugImagesAlive == liveTileCount` is indifferent to `_band` either way. The
+gap Task 4 opened therefore stayed open through Task 8's first round, closed
+only by reading. The lower bound added in this round is what closes it, and
+this mutant is what proves the lower bound is load-bearing.
+
+**Mutation:**
+
+```diff
+@@ -1176,7 +1176,6 @@
+       final visited = <int>[];
+       final image = _bakeBand(
+           band, grid, quantised, painter, sink, vertices, origin, visited);
+-      _band = image;
+       // [_bakeBand]'s `onVisit` records only what the painter visited
+       // directly; [_bake]'s climbs owners so that a *container's* transform
+       // reaches the tile through invalidation's direction one. This is where
+```
+
+**Procedure:** copied `tile_cache.dart` aside, applied the edit, ran
+`CI=true flutter test test/invariants/tile_bytes_test.dart`, then restored from
+the copy. **Never `git checkout`.**
+
+**Result:** red, as expected. The new lower bound fires on the first slice of
+the first band, where `liveTileCount` is still 0 and `liveBytes` reads 0
+instead of the resident band's bytes. The second failure in the transcript is a
+knock-on and not an independent signal: the assertion throws out of the slice
+loop, so `_disposeImage(image)` never runs and one band image is left alive.
+
+**Verbatim output:**
+
+```
+00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart
+00:00 +0: a live band image is counted in liveBytes
+00:00 +1: the ceiling holds at every point inside the rest frame
+══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
+The following TestFailure was thrown during paint():
+Expected: a value greater than <0>
+  Actual: <0>
+   Which: is not a value greater than <0>
+the band image is in the total, not merely permitted by it: a rest frame that never assigned _band
+would read exactly the tile sum here
+
+The relevant error-causing widget was:
+  CustomPaint
+  CustomPaint:file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart:359:16
+
+When the exception was thrown, this was the stack:
+#0      fail (package:matcher/src/expect/expect.dart:187:31)
+#1      _expect (package:matcher/src/expect/expect.dart:182:3)
+#2      expect (package:matcher/src/expect/expect.dart:65:3)
+#3      expect (package:flutter_test/src/widget_tester.dart:473:18)
+#4      main.<anonymous closure>.<anonymous closure> (file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart:47:7)
+#5      TileCache._restBake (package:jet_cad_2d_flutter/src/tile_cache.dart:1204:30)
+#6      TileCache.paintFrame (package:jet_cad_2d_flutter/src/tile_cache.dart:983:7)
+#7      _DraftCustomPainter.paint (package:jet_cad_2d_flutter/src/draft_canvas.dart:427:13)
+#8      RenderCustomPaint._paintWithPainter (package:flutter/src/rendering/custom_paint.dart:593:13)
+#9      RenderCustomPaint.paint (package:flutter/src/rendering/custom_paint.dart:641:7)
+#10     RenderObject._paintWithContext (package:flutter/src/rendering/object.dart:3580:7)
+#11     PaintingContext.paintChild (package:flutter/src/rendering/object.dart:265:13)
+#12     RenderProxyBoxMixin.paint (package:flutter/src/rendering/proxy_box.dart:143:13)
+#13     RenderObject._paintWithContext (package:flutter/src/rendering/object.dart:3580:7)
+#14     PaintingContext._repaintCompositedChild (package:flutter/src/rendering/object.dart:180:11)
+#15     PaintingContext.repaintCompositedChild (package:flutter/src/rendering/object.dart:125:5)
+#16     PipelineOwner.flushPaint (package:flutter/src/rendering/object.dart:1325:31)
+#17     PipelineOwner.flushPaint (package:flutter/src/rendering/object.dart:1335:15)
+#18     AutomatedTestWidgetsFlutterBinding.drawFrame (package:flutter_test/src/binding.dart:2438:31)
+#19     RendererBinding._handlePersistentFrameCallback (package:flutter/src/rendering/binding.dart:558:5)
+#20     SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1430:15)
+#21     SchedulerBinding.handleDrawFrame (package:flutter/src/scheduler/binding.dart:1345:9)
+#22     AutomatedTestWidgetsFlutterBinding.pump.<anonymous closure> (package:flutter_test/src/binding.dart:2261:9)
+#25     TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
+#26     AutomatedTestWidgetsFlutterBinding.pump (package:flutter_test/src/binding.dart:2250:27)
+#27     WidgetTester.pump.<anonymous closure> (package:flutter_test/src/widget_tester.dart:652:53)
+#30     TestAsyncUtils.guard (package:flutter_test/src/test_async_utils.dart:74:41)
+#31     WidgetTester.pump (package:flutter_test/src/widget_tester.dart:652:27)
+#32     main.<anonymous closure> (file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart:57:13)
+<asynchronous suspension>
+#33     testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
+<asynchronous suspension>
+#34     TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
+<asynchronous suspension>
+<asynchronous suspension>
+(elided 5 frames from dart:async and package:stack_trace)
+
+The following RenderObject was being processed when the exception was fired: RenderCustomPaint#2342a:
+  creator: CustomPaint ← RepaintBoundary ← DraftCanvas ← SizedBox ← Directionality ← MediaQuery ←
+    _FocusInheritedScope ← _FocusScopeWithExternalFocusNode ← _FocusInheritedScope ← Focus ←
+    FocusTraversalGroup ← MediaQuery ← ⋯
+  parentData: <none> (can use size)
+  constraints: BoxConstraints(w=800.0, h=600.0)
+  size: Size(800.0, 600.0)
+  painter: _DraftCustomPainter#c6044(Listenable.merge([CameraController#36307(Instance of
+    'ViewportTransform'), Instance of 'DocChangeNotifier', Instance of '_TableListenableAdapter',
+    Instance of '_SettleNotifier']))
+  preferredSize: Size(Infinity, Infinity)
+This RenderObject has no descendants.
+════════════════════════════════════════════════════════════════════════════════════════════════════
+══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
+The following TestFailure was thrown running a test:
+Expected: <0>
+  Actual: <1>
+no band image outlives its band, and the composite was dropped before the bake
+
+When the exception was thrown, this was the stack:
+#4      main.<anonymous closure> (file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart:59:5)
+<asynchronous suspension>
+#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
+<asynchronous suspension>
+#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
+<asynchronous suspension>
+<asynchronous suspension>
+(elided one frame from package:stack_trace)
+
+This was caught by the test expectation on the following line:
+  file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart line 59
+The test description was:
+  the ceiling holds at every point inside the rest frame
+════════════════════════════════════════════════════════════════════════════════════════════════════
+══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
+The following message was thrown:
+Multiple exceptions (2) were detected during the running of the current test, and at least one was
+unexpected.
+════════════════════════════════════════════════════════════════════════════════════════════════════
+00:00 +1 -1: the ceiling holds at every point inside the rest frame [E]
+  Test failed. See exception logs above.
+  The test description was: the ceiling holds at every point inside the rest frame
+  
+00:00 +1 -1: Some tests failed.
+
+Failing tests:
+  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart: the ceiling holds at every point inside the rest frame
+```
+
+## M3 — the slice rectangle is always the band's first tile
+
+**Task 9.** `TileGrid.sliceSourceRect` returns `Rect.fromLTWH(0, 0, tile, tile)`
+whatever key it is asked about, so every tile in a band is cut from the band's
+leftmost 64 device pixels.
+
+**Mutation:**
+
+```diff
+@@ -339,7 +339,7 @@
+   /// numbered. Integral by construction -- [deviceDeltaFrom] rounds, and a
+   /// tile side is `tileDevicePixels` exactly.
+   Rect sliceSourceRect(TileBand band, TileKey key) => Rect.fromLTWH(
+-        key.x * tileDevicePixels.toDouble() - band.deviceRect.left,
++        0,
+         0,
+         tileDevicePixels.toDouble(),
+         tileDevicePixels.toDouble(),
+```
+
+**Procedure:** copied `tile_cache.dart` aside, applied the edit, ran the
+whole package suite with `CI=true flutter test`, then restored from the copy.
+**Never `git checkout`.**
+
+**Result:** red on **four of the five differential arms** and on Task 7's
+`sliceSourceRect` unit test. The counts are the whole point: 58,424 to 78,387
+differing pixels out of 480,000 on the three whole-frame arms, and 10,684 on
+the tile-edge sweep alone. Arm 3's number (68,370) is smaller than arm 1's
+because its band's first key is `-3`, so a fixed `(0, 0)` source happens to be
+right for that one column.
+
+**Verbatim output:**
+
+```
+The following TestFailure was thrown running a test:
+Expected: <0>
+  Actual: <58424>
+a band is queried with a pad and clipped without one, and the tiles cut out of it have to hold what
+the live frame draws
+
+  [stack trace elided]
+The test description was:
+  a settled generation is identical to a live frame
+
+The following TestFailure was thrown running a test:
+Expected: <0>
+  Actual: <68370>
+rebasing is frame-global: every band must be walked against the frame origin, not one it derived for
+itself
+
+  [stack trace elided]
+The test description was:
+  and at a camera on a power-of-two rebase boundary
+
+The following TestFailure was thrown running a test:
+Expected: <0>
+  Actual: <59892>
+an edge tile sliced from a viewport-sized source blits its transparent overhang here, and costs the
+same as an opaque one, so no timing gate can see it
+
+  [stack trace elided]
+The test description was:
+  and stays identical after a pan smaller than one tile
+
+The following TestFailure was thrown running a test:
+Expected: <0>
+  Actual: <78387>
+a grid-space slice rectangle reads off the wrong part of the band image as soon as the visible key
+range moves
+
+  [stack trace elided]
+The test description was:
+  and when a pan lands between the scale change and the bake
+
+The following TestFailure was thrown running a test:
+Expected: <0>
+  Actual: <10684>
+a seam lives on the boundary, and a whole-frame count buries it under 62 interior columns out of
+every 64
+
+  [stack trace elided]
+The test description was:
+  tile boundaries carry no difference of their own
+
+00:06 +392 ~1 -7: Some tests failed.
+Failing tests:
+  test/tile_band_test.dart: the band bake a slice rectangle is band-local and integral
+  test/tile_cache_test.dart: criterion 1: a settled frame equals the live frame after a zoom
+  test/tile_slice_differential_test.dart: a settled generation is identical to a live frame
+  test/tile_slice_differential_test.dart: and at a camera on a power-of-two rebase boundary
+  ... and 3 more
+```
+
+## M7 — `bandsFor` clamps its band rectangles to the viewport
+
+**Task 9.** A band is cut to the viewport instead of to the tiles it holds, so
+the last row's band image is 24 device pixels tall where its tiles are 64. The
+slice then reads 40 rows that are not in the image and gets transparency.
+
+**Why arm 2 is its only pixel gate, and why that mattered.** Task 5's overhang
+test asserts `greaterThanOrEqualTo`, so a band truncated exactly *to* the
+viewport edge satisfies it. The truncated rows also sit outside the viewport at
+the camera the band was cut at, so arm 1 cannot see them either: a transparent
+blit costs exactly what an opaque one costs, which is why Plan 3h's p95 pan
+gate is blind to this as well. It takes a pan smaller than one tile -- 7
+logical, 14 device pixels here -- to drag those rows inside the viewport, and
+that is arm 2.
+
+**Mutation:**
+
+```diff
+@@ -368,11 +368,18 @@
+             row * tileDevicePixels.toDouble(),
+             byRow[row]!.length * tileDevicePixels.toDouble(),
+             tileDevicePixels.toDouble(),
+-          ),
++          ).intersect(_viewportDeviceRect(camera, viewport)),
+         ),
+     ];
+   }
+ 
++  /// M7: the viewport in the grid's own device space.
++  Rect _viewportDeviceRect(ViewportTransform camera, Size viewport) {
++    final (dx, dy) = deviceDeltaFrom(camera);
++    return Rect.fromLTWH(-dx.toDouble(), -dy.toDouble(),
++        viewport.width * devicePixelRatio, viewport.height * devicePixelRatio);
++  }
++
+   /// Floor division that stays correct for negative numerators.
+   ///
+   /// Dart's `~/` truncates toward zero, so `-1 ~/ 64` is `0` and the tile to
+```
+
+**Procedure:** copied `tile_cache.dart` aside, applied the edit, ran the
+whole package suite with `CI=true flutter test`, then restored from the copy.
+**Never `git checkout`.**
+
+**Result:** red on arm 2 (3,780 differing pixels -- 14 device rows across 270
+columns of the bottom edge) and on arm 3 (8,692). Arm 1, arm 5 and the tile-edge
+sweep are all green under it, which is the measurement Task 5's `>=` bound
+predicted.
+
+**Verbatim output:**
+
+```
+The following TestFailure was thrown running a test:
+Expected: <0>
+  Actual: <8692>
+an edge tile sliced from a viewport-sized source blits its transparent overhang here, and costs the
+same as an opaque one, so no timing gate can see it
+
+  [stack trace elided]
+The test description was:
+  and stays identical after a pan smaller than one tile
+
+The following TestFailure was thrown running a test:
+Expected: <0>
+  Actual: <3780>
+a grid-space slice rectangle reads off the wrong part of the band image as soon as the visible key
+range moves
+
+  [stack trace elided]
+The test description was:
+  and when a pan lands between the scale change and the bake
+
+00:07 +395 ~1 -4: Some tests failed.
+Failing tests:
+  test/tile_band_test.dart: a band is one tile tall and the full union width
+  test/tile_band_test.dart: the band bake a slice rectangle is band-local and integral
+  test/tile_slice_differential_test.dart: and stays identical after a pan smaller than one tile
+  test/tile_slice_differential_test.dart: and when a pan lands between the scale change and the bake
+```
+
+## M9 — the band query is not padded
+
+**Task 9.** `const pad = 0.0` in `_bakeBand`, so the band walks exactly its own
+rectangle and drops every entity whose *bounds* fall outside it. A stroke is
+wider than its geometry: an entity whose centreline sits just outside a band
+still inks pixels inside it, and the painter's index query is an exact rect
+intersection on bounds -- measured, a line 0.1 world units outside a query rect
+is not returned.
+
+**The fixture is what makes this visible, and its first arrangement did not.**
+`bandCrossingGrid` places one 2.00 mm stroke (3.780 logical pixels of
+half-width) one logical pixel outside each band boundary, so it inks 2.780
+logical pixels -- 5.56 device rows -- into the band on the far side. The
+arrangement that shipped first placed a stroke on *both* sides of every
+boundary; those two centrelines are 2 logical pixels apart against a 3.780
+half-width, so the inner stroke's ink covers exactly what the outer one's loss
+would have exposed and **M9 changed zero pixels at `tileCamera`**. One stroke a
+boundary, alternating sides, is what makes the loss reachable. Recorded on
+`_sideFor` in `tile_fixture.dart`.
+
+**Mutation:**
+
+```diff
+@@ -2006,7 +2006,7 @@
+     // uses -- padding one alone makes them disagree. The canvas is pulled back
+     // by the same amount, so the padded viewport's origin lands where the
+     // band's own origin was.
+-    const pad = kTileSlack;
++    const pad = 0.0;
+     into.save();
+     into.translate(-pad, -pad);
+```
+
+**Procedure:** copied `tile_cache.dart` aside, applied the edit, ran the
+whole package suite with `CI=true flutter test`, then restored from the copy.
+**Never `git checkout`.**
+
+**Result:** red on all five differential arms and on both of Task 6's band-query
+unit tests. 30,160 differing pixels on arms 1 and 5, 8,196 and 9,170 on arms 2
+and 3, 3,475 on the tile-edge sweep.
+
+**Verbatim output:**
+
+```
+The following TestFailure was thrown running a test:
+Expected: <0>
+  Actual: <30160>
+a band is queried with a pad and clipped without one, and the tiles cut out of it have to hold what
+the live frame draws
+
+  [stack trace elided]
+The test description was:
+  a settled generation is identical to a live frame
+
+The following TestFailure was thrown running a test:
+Expected: <0>
+  Actual: <3475>
+rebasing is frame-global: every band must be walked against the frame origin, not one it derived for
+itself
+
+  [stack trace elided]
+The test description was:
+  and at a camera on a power-of-two rebase boundary
+
+The following TestFailure was thrown running a test:
+Expected: <0>
+  Actual: <30160>
+an edge tile sliced from a viewport-sized source blits its transparent overhang here, and costs the
+same as an opaque one, so no timing gate can see it
+
+  [stack trace elided]
+The test description was:
+  and stays identical after a pan smaller than one tile
+
+The following TestFailure was thrown running a test:
+Expected: <0>
+  Actual: <9170>
+a grid-space slice rectangle reads off the wrong part of the band image as soon as the visible key
+range moves
+
+  [stack trace elided]
+The test description was:
+  and when a pan lands between the scale change and the bake
+
+The following TestFailure was thrown running a test:
+Expected: <0>
+  Actual: <8196>
+a seam lives on the boundary, and a whole-frame count buries it under 62 interior columns out of
+every 64
+
+  [stack trace elided]
+The test description was:
+  tile boundaries carry no difference of their own
+
+00:06 +391 ~1 -8: Some tests failed.
+Failing tests:
+  test/tile_band_test.dart: the band bake the band camera puts a world point at the band-local pixel
+  test/tile_band_test.dart: the band bake the padded query reaches kTileSlack past the band on every side
+  test/tile_cache_test.dart: criterion 1: a settled frame equals the live frame after a zoom
+  test/tile_slice_differential_test.dart: a settled generation is identical to a live frame
+  ... and 4 more
+```
+
+## M9b — the band pad is applied to the camera but not to the canvas
+
+**Task 9.** `into.translate(-pad, -pad)` is dropped from `_bakeBand` while the
+band camera keeps its `+pad`. The query still reaches `kTileSlack` past the
+band on every side -- Task 6's two unit tests both stay green -- but every pixel
+the band draws lands 32 logical pixels down and right of where it belongs.
+
+**Why it needs its own mutant beside M9.** M9 removes the pad from both halves
+at once, which is a *consistent* mistake: the band is then simply narrower than
+it should be. This one is the inconsistent half, and it is the failure mode the
+pad's own comment warns about ("The canvas is pulled back by the same amount, so
+the padded viewport's origin lands where the band's own origin was"). No
+query-side assertion can see it.
+
+**Mutation:**
+
+```diff
+@@ -2008,7 +2008,6 @@
+     // band's own origin was.
+     const pad = kTileSlack;
+     into.save();
+-    into.translate(-pad, -pad);
+ 
+     final m = grid.anchor.worldToScreenMatrix;
+     final bandCamera = ViewportTransform(
+```
+
+**Procedure:** copied `tile_cache.dart` aside, applied the edit, ran the
+whole package suite with `CI=true flutter test`, then restored from the copy.
+**Never `git checkout`.**
+
+**Result:** red on all five differential arms, at the largest counts of any
+mutant here -- 140,032 to 227,695 differing pixels of 480,000, because every
+band's whole content is displaced rather than a few rows of it lost.
+
+**Verbatim output:**
+
+```
+The following TestFailure was thrown running a test:
+Expected: <0>
+  Actual: <140032>
+a band is queried with a pad and clipped without one, and the tiles cut out of it have to hold what
+the live frame draws
+
+  [stack trace elided]
+The test description was:
+  a settled generation is identical to a live frame
+
+The following TestFailure was thrown running a test:
+Expected: <0>
+  Actual: <192258>
+rebasing is frame-global: every band must be walked against the frame origin, not one it derived for
+itself
+
+  [stack trace elided]
+The test description was:
+  and at a camera on a power-of-two rebase boundary
+
+The following TestFailure was thrown running a test:
+Expected: <0>
+  Actual: <140060>
+an edge tile sliced from a viewport-sized source blits its transparent overhang here, and costs the
+same as an opaque one, so no timing gate can see it
+
+  [stack trace elided]
+The test description was:
+  and stays identical after a pan smaller than one tile
+
+The following TestFailure was thrown running a test:
+Expected: <0>
+  Actual: <227695>
+a grid-space slice rectangle reads off the wrong part of the band image as soon as the visible key
+range moves
+
+  [stack trace elided]
+The test description was:
+  and when a pan lands between the scale change and the bake
+
+The following TestFailure was thrown running a test:
+Expected: <0>
+  Actual: <8469>
+a seam lives on the boundary, and a whole-frame count buries it under 62 interior columns out of
+every 64
+
+  [stack trace elided]
+The test description was:
+  tile boundaries carry no difference of their own
+
+00:07 +393 ~1 -6: Some tests failed.
+Failing tests:
+  test/tile_cache_test.dart: criterion 1: a settled frame equals the live frame after a zoom
+  test/tile_slice_differential_test.dart: a settled generation is identical to a live frame
+  test/tile_slice_differential_test.dart: and at a camera on a power-of-two rebase boundary
+  test/tile_slice_differential_test.dart: and stays identical after a pan smaller than one tile
+  ... and 2 more
+```
+
+## M10 — the slice rectangle is measured in grid space, not band space
+
+**Task 9.** `sliceSourceRect` drops `- band.deviceRect.left`, so a key's source
+rectangle is measured from the generation's anchor rather than from the band
+image's own origin.
+
+**Why arm 3 is its only pixel gate.** `TileBand.deviceRect.left` is
+`keys.first.x * tileDevicePixels` by definition, so it is **zero exactly when
+the visible key range starts at column 0** -- and then band-local and
+grid-space arithmetic are the same arithmetic and this mutation is the identity.
+Every arm that does not move the key range is therefore blind to it, and the
+plan's pinned pure-zoom script never moves it: a zoom re-anchors the grid on the
+camera it zoomed to, so the range starts at 0 again. Arm 3 takes the pan
+**between** the scale change and the rest bake -- `Offset(90, 60)`, 180 x 120
+device pixels -- which drives the range to `x0 = -3`, `y0 = -2` and
+`deviceRect.left` to -192. Verified on the shipped code, not assumed:
+`bands.first.keys.first.x = -3`, `deviceRect = Rect.fromLTRB(-192.0, -128.0,
+640.0, -64.0)`.
+
+**Mutation:**
+
+```diff
+@@ -339,7 +339,7 @@
+   /// numbered. Integral by construction -- [deviceDeltaFrom] rounds, and a
+   /// tile side is `tileDevicePixels` exactly.
+   Rect sliceSourceRect(TileBand band, TileKey key) => Rect.fromLTWH(
+-        key.x * tileDevicePixels.toDouble() - band.deviceRect.left,
++        key.x * tileDevicePixels.toDouble(),
+         0,
+         tileDevicePixels.toDouble(),
+         tileDevicePixels.toDouble(),
+```
+
+**Procedure:** copied `tile_cache.dart` aside, applied the edit, ran the
+whole package suite with `CI=true flutter test`, then restored from the copy.
+**Never `git checkout`.**
+
+**Result:** red on arm 3 (132,650 differing pixels) and on Task 7's
+`sliceSourceRect` unit test. Green on arms 1, 2, 4 and 5, exactly as the
+`deviceRect.left == 0` degeneracy predicts.
+
+**Verbatim output:**
+
+```
+The following TestFailure was thrown running a test:
+Expected: <0>
+  Actual: <132650>
+a grid-space slice rectangle reads off the wrong part of the band image as soon as the visible key
+range moves
+
+  [stack trace elided]
+The test description was:
+  and when a pan lands between the scale change and the bake
+
+00:07 +397 ~1 -2: Some tests failed.
+Failing tests:
+  test/tile_band_test.dart: the band bake a slice rectangle is band-local and integral
+  test/tile_slice_differential_test.dart: and when a pan lands between the scale change and the bake
+```
+
+## M11 — the band derives its own rebase origin — **survives every pixel arm**
+
+**Task 9.** `_bakeBand` calls `rebaseOriginFor` on its own padded band viewport
+instead of using the frame-global origin handed in. Killed by Task 6's
+`every band is rebased against the origin handed in`, which observes the origin
+directly. **Not killed by any of the five differential arms, including the one
+built for it**, and that is a measurement rather than an omission.
+
+**The arm that was supposed to kill it, and why it cannot.**
+`rebaseBoundaryCamera` puts the view span at 133.333 world units -- `floor(log2)
+= 7`, step 128 -- with the view centre at 128.1667, one device pixel past the
+128 cell boundary, and the visible world y running 78.167 to 178.167 so that
+bands genuinely fall on both sides of it. Under M11 the bands therefore *do*
+take different origins from the frame: `(128, 128)` for some rows, `(128, 0)`
+for others. The frame still comes out **pixel-identical** -- `differingPixels`
+reads 0 -- and the reason is in `DraftPainter._emitScreenSpace`: it computes
+`p_screen - _screenOrigin` in `float64` and hands the sink
+`beginResidual(translation(_screenOrigin))`, and `VerticesDrawSink` adds the
+residual back in `float64` before storing an **absolute** screen coordinate in
+its `Float32List`. The origin cancels algebraically before anything is rounded
+to `float32`, so at this fixture's magnitudes the residual difference is around
+`1e-13` device pixels -- fourteen orders of magnitude below the `1.1e-05` that
+Task 6a measured as the threshold for flipping a single pixel on a near-axis
+slope, and this fixture is axis-aligned by construction.
+
+**What this means for the origin argument.** A pixel comparison is the wrong
+instrument for it at ordinary world magnitudes; the direct observation Task 6
+ships is the right one, and it is the gate of record. The origin's value is
+paid for at 4.5e6-scale coordinates (`large_coordinate_test.dart`), where the
+`float64` cancellation above is no longer exact -- a fixture at those
+magnitudes could plausibly make a pixel arm see it, and none of this plan's
+fixtures is at those magnitudes.
+
+**Mutation:**
+
+```diff
+@@ -1988,6 +1988,7 @@
+         grid.matchesScale(quantised),
+         'a band belongs to one generation, so the frame camera and the grid '
+         'anchor must agree on scale');
++    assert(origin.x == origin.x);
+     final dpr = grid.devicePixelRatio;
+     final width = band.deviceRect.width / dpr;
+     final height = band.deviceRect.height / dpr;
+@@ -2029,11 +2030,9 @@
+       painter,
+       sink,
+       vertices,
+-      // **The viewport's origin, never the band's.** Rebasing is frame-global
+-      // by construction: a per-band origin gives each band its own
+-      // quantisation step and `float32` residuals the live frame does not
+-      // have, and can cross a power-of-two step between one row and the next.
+-      origin,
++      // ignore: dead_code
++      rebaseOriginFor(bandCamera
++          .visibleWorld(Size(width + 2 * pad, height + 2 * pad))),
+       (handle) => visitedInto.add(handle.value),
+     );
+     into.restore();
+```
+
+**Procedure:** copied `tile_cache.dart` aside, applied the edit, ran the
+whole package suite with `CI=true flutter test`, then restored from the copy.
+**Never `git checkout`.**
+
+**Result:** red on Task 6's origin test only. The differential arms are green.
+
+**Verbatim output:**
+
+```
+00:06 +398 ~1 -1: Some tests failed.
+Failing tests:
+  test/tile_band_test.dart: the band bake every band is rebased against the origin handed in
+```
+
+## M8 — the slice blits through a `FilterQuality.low` paint — **a declared survivor**
+
+**Task 9, and green by design.** `_sliceTile` blits through a paint with
+`filterQuality = FilterQuality.low` instead of `none`. Recorded here as a
+**declared survivor**, not as a gate's failure: `sliceSourceRect` is integral by
+construction and the destination is the same size, so a bilinear sample and a
+nearest sample read the same texels and the only difference is that a sampler
+was paid for. Plan 3h's M6 had this shape and was recorded as gap H6.
+
+**It dying would have been the finding.** A death here would mean the source
+rectangles are *not* integral -- that a slice is resampling -- and the whole
+"texture copy, not a raster" claim would be wrong. The full suite is green under
+it, which is the positive statement the mutation makes: the rectangles are
+integral.
+
+**Mutation:**
+
+```diff
+@@ -2080,6 +2080,9 @@
+   /// from the rejected Approach B. `FilterQuality.none`: the source rectangle
+   /// is integral and the destination is the same size, so there is nothing to
+   /// interpolate and a sampler would be pure cost.
++  final Paint _sliceFilterPaint = Paint()
++    ..filterQuality = FilterQuality.low;
++
+   Image _sliceTile(Image band, TileBand from, TileKey key, TileGrid grid) {
+     final recorder = PictureRecorder();
+     final into = Canvas(recorder);
+@@ -2088,7 +2091,7 @@
+       grid.sliceSourceRect(from, key),
+       Rect.fromLTWH(
+           0, 0, tileDevicePixels.toDouble(), tileDevicePixels.toDouble()),
+-      _blitPaint,
++      _sliceFilterPaint,
+     );
+     final picture = recorder.endRecording();
+     final image = picture.toImageSync(tileDevicePixels, tileDevicePixels);
+```
+
+**Procedure:** copied `tile_cache.dart` aside, applied the edit, ran the
+whole package suite with `CI=true flutter test`, then restored from the copy.
+**Never `git checkout`.**
+
+**Result:** green, as declared. 399 passed, 1 skipped.
+
+**Verbatim output:**
+
+```
+00:06 +399 ~1: All tests passed!
+```
+
+---
+
+## M5 — the sliced tile is never given the band's `_baked` record
+
+**Task 10.** `_invalidateTouched` condemns tiles by iterating `_baked` in both
+directions: what a handle *was* baked into, and what its new geometry
+*reaches*. A tile sliced out of a band shares one `Uint32List` record with
+every other tile the band cut, written by `_baked[key] = record;` inside the
+slice loop. Deleting that one line leaves every sliced tile absent from
+`_baked` entirely — invisible to both directions of invalidation — while the
+tile's pixels stay resident and keep blitting.
+
+**Fixture note.** The test drives its first settle through
+`settleFromBands`, not a plain `settle`. Measured directly: at this harness's
+budget (`kBakeBudgetDevicePixels`, 64 tiles of 64 device pixels per frame) a
+plain `settle` over `bandCrossingGrid` bakes 128 of the viewport's 130 tiles
+through the ordinary per-tile `_bake` path across its first two frames, before
+the rest gate ever arms, and slices only the 2 tiles the rest bake finds
+missing — confirmed by instrumenting `debugOnSliceForTest` on a throwaway
+probe (`plain settle: liveTileCount=130 slices=2`; `settleFromBands:
+liveTileCount=130 slices=130`). `kMovableHandle`'s resting tile (column 2, row
+4) is nowhere near that bottom-right corner, so a test built on a plain
+`settle` exercises the ordinary `_bake` path's own (separate) `_baked[key] =
+...` write and never reaches the line this mutant deletes — the mutation
+would survive for a reason unconnected to the code under test. `settleFromBands`
+forces a table edit that drops every tile at the same, unmoved camera, so the
+next frame's rest bake slices the whole viewport (130 of 130, asserted in the
+test as `slices == tilesBefore`), and `kMovableHandle`'s tile is necessarily
+among them.
+
+**Mutation:**
+
+```diff
+--- a/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
++++ b/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
+@@ -1209,7 +1209,7 @@
+         if (!_makeRoomForOneTile()) break;
+         final tile = _sliceTile(image, band, key, grid);
+         _tiles[key] = tile;
+-        _baked[key] = record;
++        // M5, deliberately absent: _baked[key] = record;
+         _lastUsedFrame[key] = _frameSerial;
+       }
+       _band = null;
+```
+
+**Procedure:** copied `tile_cache.dart` aside to
+`/private/tmp/claude-501/-Users-ahmeturel-Projects-oss-jet-cad/d5e851c1-248d-41da-b1c1-19632c9b5179/scratchpad/tile_cache.green.dart`,
+applied the edit, ran `CI=true flutter test test/tile_invalidation_test.dart`,
+then restored from the copy and diffed to confirm the restore was exact.
+**Never `git checkout`.**
+
+**Result:** red, as expected — and red for the intended reason: the movable
+entity is unfindable in the settled cache at all, because its tile carries no
+`_baked` record for anything.
+
+**Verbatim output:**
+
+```
+00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart
+00:00 +0: criterion 5: a leaf edit invalidates its own tiles and no others
+00:00 +1: criterion 5: a dragged instance drops the tiles it left
+00:00 +2: criterion 5: a dragged group leaves no ghost either
+00:00 +3: criterion 6: a group and an instance nested inside a definition
+00:00 +4: criterion 5: the undo of an instance transform invalidates both ends
+00:00 +5: criterion 6: a definition edit drops the generation, and less does not
+00:00 +6: criterion 9: all five change arms, none omitted
+00:00 +7: criterion 9: a load starts a new generation, an edit does not
+00:00 +8: criterion 5 / gap G6: a stroke reaching into a tile its geometry misses invalidates it
+00:00 +9: criterion 7: a layer edit repaints and drops the generation
+00:00 +10: an edit after a sliced settle condemns the sliced tiles
+══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
+The following TestFailure was thrown running a test:
+Expected: non-empty
+  Actual: Set:[]
+the movable entity must be findable in the settled cache
+
+When the exception was thrown, this was the stack:
+#4      main.<anonymous closure> (file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart:690:5)
+<asynchronous suspension>
+#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
+<asynchronous suspension>
+#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
+<asynchronous suspension>
+<asynchronous suspension>
+(elided one frame from package:stack_trace)
+
+This was caught by the test expectation on the following line:
+  file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart line 690
+The test description was:
+  an edit after a sliced settle condemns the sliced tiles
+════════════════════════════════════════════════════════════════════════════════════════════════════
+00:00 +10 -1: an edit after a sliced settle condemns the sliced tiles [E]
+  Test failed. See exception logs above.
+  The test description was: an edit after a sliced settle condemns the sliced tiles
+  
+00:00 +10 -1: Some tests failed.
+
+Failing tests:
+  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: an edit after a sliced settle condemns the sliced tiles
+```
+
+---
+
+## M12 — the skew term c is not compared
+
+**Batch-minors pass, found by review of `tile_regime_test.dart`.** Every
+fixture in that file — the `at()` helper and the skew test's own literals —
+sets `c = 0`, including both sides of `'the skew terms are compared too'`.
+Deleting `x.c == y.c` from `sameQuantisedCamera` therefore killed no test: `c`
+never varied, so the field being ignored was indistinguishable from the field
+being equal. Fixed by extending that test with a second pair that varies `c`
+and holds every other field fixed.
+
+**Mutation:**
+
+```diff
+--- a/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
++++ b/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
+@@ -240,7 +240,6 @@
+   return x.a == y.a &&
+       x.b == y.b &&
+-      x.c == y.c &&
+       x.d == y.d &&
+       x.e == y.e &&
+       x.f == y.f;
+```
+
+**Procedure:** copied `tile_cache.dart` aside to the scratchpad, edited the
+working file to delete `x.c == y.c &&`, ran
+`CI=true flutter test test/tile_regime_test.dart`, confirmed red, then
+restored the working file from the scratchpad copy. **Never `git checkout`.**
+
+**Result:** red, as expected — the new `c1`/`c2` case in `'the skew terms are
+compared too'` fails because two transforms differing only in `c` now compare
+equal.
+
+**Verbatim output:**
+
+```
+Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
+Downloading packages...
+  _fe_analyzer_shared 103.0.0 (105.0.0 available)
+  analyzer 13.3.0 (14.1.0 available)
+  code_assets 1.2.1 (2.0.0 available)
+  hooks 2.1.0 (2.2.0 available)
+  lucide_icons_flutter 3.1.15 (3.1.17 available)
+  material_color_utilities 0.13.0 (0.13.1 available)
+  objective_c 9.5.0 (9.6.0 available)
+  package_config 2.2.0 (3.0.0 available)
+  record_use 1.1.0 (1.1.1 available)
+  shadcn_ui 0.55.1 (0.56.2 available)
+  source_maps 0.10.13 (0.10.14 available)
+  test 1.31.1 (1.31.2 available)
+  test_api 0.7.12 (0.7.13 available)
+  test_core 0.6.18 (0.6.19 available)
+  vm_service 15.2.0 (15.3.0 available)
+Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
+15 packages have newer versions incompatible with dependency constraints.
+Try `flutter pub outdated` for more information.
+00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart
+00:00 +0: the same camera compares same
+00:00 +1: a scale change compares different
+00:00 +2: a translation change compares different
+00:00 +3: the skew terms are compared too
+00:00 +3 -1: the skew terms are compared too [E]
+  Expected: false
+    Actual: <true>
+  
+  package:matcher                                     expect
+  package:flutter_test/src/widget_tester.dart 473:18  expect
+  test/tile_regime_test.dart 43:5                     main.<fn>
+  
+00:00 +3 -1: a moving frame bakes nothing and walks nothing
+00:00 +4 -1: a moving frame with no composite falls through and draws something
+00:00 +5 -1: a steadily spun wheel never arms the rest gate
+00:00 +6 -1: the gate needs two unchanged frames, not one
+00:00 +7 -1: Some tests failed.
+
+Failing tests:
+  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart: the skew terms are compared too
+```
+
+Restored from the scratchpad copy and re-ran the same file green (`+8: All
+tests passed!`) before moving on.
+
+---
+
+## M13 — the rest bake ignores `debugRestBakeDisabled`
+
+**Task:** Task 12a, "the two measurement seams" (Ruling 14). Gates
+`test/tile_measurement_seam_test.dart`'s `'debugRestBakeDisabled slices
+nothing and still covers'`.
+
+**Why this mutant and not another.** `TileCache.debugRestBakeDisabled` is a
+measurement switch: criterion 4's denominator arm is *this cache without the
+rest bake*, and the only way to reach it inside one interleaved session is a
+runtime flag. A flag that is declared, documented and read — but whose read
+changes nothing the frame path does — fails silently and in the worst
+possible place: both arms of the ratio would run identical code, the ratio
+would read exactly **1.00**, and the number would be written into a document
+of record with nothing to contradict it. M13 is that failure, applied on
+purpose.
+
+**Mutation**, applied to
+`packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`:
+
+```diff
+--- a/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
++++ b/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
+@@ -1055,7 +1055,7 @@
+-    if (_restGateSteps >= kRestGateFrames && !debugRestBakeDisabled) {
++    if (_restGateSteps >= kRestGateFrames) {
+       _restBake(grid, quantised, viewport, painter, sink, vertices, origin);
+     }
+```
+
+**Procedure:** copied `tile_cache.dart` aside to the scratchpad
+(`tile_cache_m13.bak`), edited the working file, ran
+`CI=true flutter test test/tile_measurement_seam_test.dart`, confirmed red,
+then restored the working file with `cp` from the scratchpad copy and
+confirmed `diff` produced no output. **Never `git checkout`.**
+
+**Result:** red, on the slice count and not on the flag's own value. The
+flagged arm slices **130** — every visible tile — where correct code slices
+**0**. The other two tests in the file stay green, which is the point of the
+first one: `'the rest bake fires, and debugRestBakeDisabled suppresses it'`
+is the unflagged arm, and under M13 it is still true, so a reader can see
+that the mutation removed the *difference between the arms* rather than
+breaking the bake.
+
+**Verbatim output** (the `flutter pub get` preamble, identical to every other
+entry in this file, is trimmed):
+
+```
+00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart
+00:00 +0: the rest bake fires, and debugRestBakeDisabled suppresses it
+00:00 +1: debugRestBakeDisabled slices nothing and still covers
+══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
+The following TestFailure was thrown running a test:
+Expected: <0>
+  Actual: <130>
+with the rest bake disabled no tile may be cut from a band -- criterion 4's denominator arm is the
+budgeted per-tile path, and an arm that still slices is the numerator arm under a different name,
+which would put the ratio at 1.00
+
+When the exception was thrown, this was the stack:
+#4      main.<anonymous closure> (file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart:169:5)
+<asynchronous suspension>
+#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
+<asynchronous suspension>
+#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
+<asynchronous suspension>
+<asynchronous suspension>
+(elided one frame from package:stack_trace)
+
+This was caught by the test expectation on the following line:
+  file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart line 169
+The test description was:
+  debugRestBakeDisabled slices nothing and still covers
+════════════════════════════════════════════════════════════════════════════════════════════════════
+00:00 +1 -1: debugRestBakeDisabled slices nothing and still covers [E]
+  Test failed. See exception logs above.
+  The test description was: debugRestBakeDisabled slices nothing and still covers
+  
+00:00 +1 -1: debugFullViewportQuery grows the fallback walk to the whole viewport
+00:00 +2 -1: Some tests failed.
+
+Failing tests:
+  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart: debugRestBakeDisabled slices nothing and still covers
+```
+
+**Restore, verified.** `cp` from the scratchpad copy, `diff` against it empty,
+and the same file re-run green:
+
+```
+00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart
+00:00 +0: the rest bake fires, and debugRestBakeDisabled suppresses it
+00:00 +1: debugRestBakeDisabled slices nothing and still covers
+00:00 +2: debugFullViewportQuery grows the fallback walk to the whole viewport
+00:00 +3: All tests passed!
+```
+
+---
+
+## M14 — the live fallback ignores `debugFullViewportQuery`
+
+**Task:** Task 12a (Ruling 14). Gates
+`test/tile_measurement_seam_test.dart`'s `'debugFullViewportQuery grows the
+fallback walk to the whole viewport'`.
+
+**Why this mutant.** `TileCache.debugFullViewportQuery` reproduces **Plan
+3h's M4** — see `plan-3h-mutation-log.md` §"M4 — narrow the clip but not the
+query" — at runtime, so that criterion 8's "narrow" and "M4" arms can
+interleave inside one session instead of being two binaries run
+three-then-three. **Note the numbering collision:** this file's own M4 is a
+different mutation entirely; the flag reproduces *3h's* M4.
+
+A flag that is read but inert here is the same silent 1.00 as M13, with an
+extra trap of its own: M4 is pixel-invisible by construction. The clip stays
+narrow, so every pixel lands exactly where it belongs whether the query is
+the strip or the viewport; only the *amount of geometry tessellated to
+produce them* changes. So no pixel gate can see this switch fail, and the
+test that gates it has to read the strip the frame actually walked
+(`debugLastStrip`, written by `paintFrame` itself) and the triangles it
+actually emitted (`VerticesDrawSink.frameTriangleCount`) — which is the same
+instrument `kTriangleBudgetRatio` uses to kill 3h's M4 as a source edit.
+
+**Mutation**, applied to
+`packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`:
+
+```diff
+--- a/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
++++ b/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
+@@ -1147,9 +1147,7 @@
+-    final strip = debugFullViewportQuery
+-        ? Offset.zero & viewport
+-        : stripFor(uncovered, viewport);
++    final strip = stripFor(uncovered, viewport);
+     _lastStrip = strip;
+```
+
+**Procedure:** copied `tile_cache.dart` aside to the scratchpad
+(`tile_cache_m14.bak`), edited the working file, ran
+`CI=true flutter test test/tile_measurement_seam_test.dart`, confirmed red,
+then restored with `cp` and confirmed `diff` produced no output. **Never `git
+checkout`.**
+
+**Result:** red on the recorded strip. At the swept pan `Offset(0, 53)` on
+`fillingGrid` — the offset `kTriangleBudgetRatio`'s doc comment identifies as
+the tightest sample in that sweep — correct code produces
+
+- narrow arm: strip `Rect.fromLTRB(0, 0, 400, 85)`, **60** triangles
+- M4 arm: strip `Rect.fromLTRB(0, 0, 400, 300)`, **80** triangles
+
+so the flag moves the walk by 215 logical rows and the geometry by a third.
+Under M14 the M4 arm collapses onto the narrow arm exactly — same strip, same
+60 triangles — which is the reading the test refuses.
+
+**Verbatim output** (preamble trimmed as above):
+
+```
+00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart
+00:00 +0: the rest bake fires, and debugRestBakeDisabled suppresses it
+00:00 +1: debugRestBakeDisabled slices nothing and still covers
+00:00 +2: debugFullViewportQuery grows the fallback walk to the whole viewport
+00:00 +2 -1: debugFullViewportQuery grows the fallback walk to the whole viewport [E]
+  Expected: Rect:<Rect.fromLTRB(0.0, 0.0, 400.0, 300.0)>
+    Actual: Rect:<Rect.fromLTRB(0.0, 0.0, 400.0, 85.0)>
+  with the flag set the query is the full viewport -- that is what Plan 3h's M4 is: _FallbackArm(strip: Rect.fromLTRB(0.0, 0.0, 400.0, 85.0), triangles: 60, liveDraws: 1)
+  
+  package:matcher                                     expect
+  package:flutter_test/src/widget_tester.dart 473:18  expect
+  test/tile_measurement_seam_test.dart 211:5          main.<fn>
+  
+00:00 +2 -1: Some tests failed.
+
+Failing tests:
+  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart: debugFullViewportQuery grows the fallback walk to the whole viewport
+```
+
+**Restore, verified.** `cp` from the scratchpad copy, `diff` against it empty,
+`git status --porcelain` showing only this task's own two paths, and the file
+re-run green:
+
+```
+00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart
+00:00 +0: the rest bake fires, and debugRestBakeDisabled suppresses it
+00:00 +1: debugRestBakeDisabled slices nothing and still covers
+00:00 +2: debugFullViewportQuery grows the fallback walk to the whole viewport
+00:00 +3: All tests passed!
+```
+
+**One thing M14 does not gate, named rather than hidden.** The test asserts
+the M4 arm's strip *equals* the full viewport and that its triangle count
+*exceeds* the narrow arm's. It does not assert that the clip stayed narrow —
+that is what makes the flag M4 rather than M5, and it is held by the source
+(the flag's ternary touches only `strip`, and `canvas.clipRect(uncovered,
+...)` is on the line above it) and by the flag's own doc comment, not by a
+test. A future edit that widened the clip under the flag would keep this test
+green while publishing an "M4" arm that is not M4.
+
+---
+
+## M15 — a retired generation keeps its tiles
+
+**Task:** the criterion 4 warmth investigation. Gates
+`test/tile_zoom_warmth_test.dart`'s `'a zoom round trip leaves the next arm
+nothing warm to settle on'`.
+
+**Why this mutant.** Criterion 4 runs two arms of `runTileZoomPhase` against
+**one** `TileCache`, and each arm's script is symmetric: `kZoomSteps` steps at
+`kZoomFactor` then the same number at `1 / kZoomFactor`, ending arithmetically
+where it began. If a settled generation could survive an arm's gesture, the
+next arm's settle would find the viewport already covered and report its
+`settleFrames` **trivially**, in both arms, whatever the flag between them
+did — the ratio would read cache warmth rather than the rest bake, and be
+published as if it were the effect. That is exactly the degenerate fixture
+`CLAUDE.md` names as this codebase's dominant failure mode, and M15 is that
+failure applied on purpose: the one line that makes a retired generation
+actually go away.
+
+**Mutation**, applied to
+`packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`:
+
+```diff
+--- a/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
++++ b/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
+@@ -1577,7 +1577,7 @@
+       picture.dispose();
+     }
+-    _disposeTiles();
++    // M15: _disposeTiles();
+   }
+```
+
+**Procedure:** copied `tile_cache.dart` aside to the scratchpad
+(`tile_cache_m15.bak`), edited the working file, ran
+`CI=true flutter test test/tile_zoom_warmth_test.dart`, confirmed red, then
+restored the working file with `cp` from the scratchpad copy and confirmed
+`diff` produced no output. **Never `git checkout`.**
+
+**Result:** red at the first frame of the first arm's excursion, on
+`liveTileCount`. Correct code reads **0** there — one 3% zoom step is enough
+to fail `TileGrid.matchesScale`, so `_gridFor` retires the generation and
+`_retireGeneration` disposes its tiles — while under M15 all **130** tiles of
+the settled generation are still live. That is the leftover warmth the
+concern described, made real; the assertion that catches it is the one the
+whole file exists for.
+
+The assertion order matters and is deliberate: the test could have been
+written to check only the second arm's `settleFrames`, and it does check that
+too, but the *first frame of the first arm* is the only place where a single
+scale step has to have been sufficient. By the end of an 80-frame excursion
+"no tiles" is over-determined.
+
+**Verbatim output** (the `flutter pub get` preamble, identical to every other
+entry in this file, is trimmed):
+
+```
+00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_zoom_warmth_test.dart
+00:00 +0: a zoom round trip leaves the next arm nothing warm to settle on
+══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
+The following TestFailure was thrown running a test:
+Expected: <0>
+  Actual: <130>
+retiring the generation disposes its tiles -- the warm set the previous settle left behind cannot
+survive into this arm
+
+When the exception was thrown, this was the stack:
+#4      main.runArm (file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_zoom_warmth_test.dart:109:9)
+<asynchronous suspension>
+#5      main.<anonymous closure> (file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_zoom_warmth_test.dart:164:18)
+<asynchronous suspension>
+#6      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:192:15)
+<asynchronous suspension>
+#7      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1953:5)
+<asynchronous suspension>
+<asynchronous suspension>
+(elided one frame from package:stack_trace)
+
+This was caught by the test expectation on the following line:
+  file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_zoom_warmth_test.dart line 109
+The test description was:
+  a zoom round trip leaves the next arm nothing warm to settle on
+════════════════════════════════════════════════════════════════════════════════════════════════════
+00:00 +0 -1: a zoom round trip leaves the next arm nothing warm to settle on [E]
+  Test failed. See exception logs above.
+  The test description was: a zoom round trip leaves the next arm nothing warm to settle on
+  
+00:00 +0 -1: the zoom round trip does not return to the starting scale
+00:00 +1 -1: Some tests failed.
+
+Failing tests:
+  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_zoom_warmth_test.dart: a zoom round trip leaves the next arm nothing warm to settle on
+```
+
+**Restore, verified.** `cp` from the scratchpad copy, `diff` against it empty,
+`git status --porcelain` showing only this task's own new test file, and the
+file re-run green:
+
+```
+00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_zoom_warmth_test.dart
+00:00 +0: a zoom round trip leaves the next arm nothing warm to settle on
+00:00 +1: the zoom round trip does not return to the starting scale
+00:00 +2: All tests passed!
+```
+
+**The second, independent reason, which M15 does not touch.** The file's other
+test pins that the round trip does not return to the starting camera at all:
+`zoomAt` composes `about * m`, which for an unskewed camera is a scalar
+multiply of the scale term once per step, so 40 multiplies by `1.03` followed
+by 40 by `1 / 1.03` take **1.4 to 1.4000000000000017**, and `matchesScale` —
+like every stored-value comparison in `tile_cache.dart` — is exact `==`. That
+test is killed by a different mutant (`matchesScale` comparing with a
+`Tolerance` instead of `==`), not by M15, and it is deliberately kept separate:
+under M15 it stays green, which is what shows the two reasons are independent
+rather than one reason asserted twice.
+
+---
+
+## M16 — the clip widens along with the query under `debugFullViewportQuery`
+
+**Task:** the batch-minors pass, closing the gap M14's own log entry named:
+"One thing M14 does not gate... It does not assert that the clip stayed
+narrow... A future edit that widened the clip under the flag would keep this
+test green while publishing an 'M4' arm that is not M4." Gates
+`test/tile_measurement_seam_test.dart`'s `'debugFullViewportQuery grows the
+fallback walk to the whole viewport'`, specifically its `debugLastClip`
+assertions.
+
+**Why this mutant.** `TileCache.debugFullViewportQuery` is Plan 3h's M4 and
+not its M5 *precisely because* the clip stays narrow while the query widens —
+the flag's own doc comment and `tile_cache.dart:1140`'s comment both say so.
+Before this task, nothing in the test suite read the clip independently of
+the strip: `debugLastStrip` sees only what the fallback *walked*. An edit that
+widened `canvas.clipRect` under the flag would keep every existing assertion
+green — the strip still reads the full viewport, the triangle count is still
+higher — while publishing an "M4" arm that is neither 3h's M4 nor its M5. This
+mutant is that edit, made on purpose, to prove the new `debugLastClip` read
+and its assertions are not vacuous.
+
+**Mutation**, applied to
+`packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`:
+
+```diff
+--- a/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
++++ b/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
+@@ -1169,7 +1169,9 @@
+     // stay correct, so the sweep still reads zero, and the cost this whole
+     // change exists to remove comes back silently.
+-    canvas.clipRect(uncovered, doAntiAlias: false);
+-    _lastClip = uncovered;
++    final clip =
++        debugFullViewportQuery ? Offset.zero & viewport : uncovered;
++    canvas.clipRect(clip, doAntiAlias: false);
++    _lastClip = clip;
+     // **Walk the union, not the viewport.** The clip above only discards
+```
+
+**Procedure:** copied `tile_cache.dart` aside to the scratchpad
+(`tile_cache_m16.bak`), edited the working file, ran
+`CI=true flutter test test/tile_measurement_seam_test.dart`, confirmed red,
+then restored the working file with `cp` from the scratchpad copy and
+confirmed `diff` produced no output. **Never `git checkout`.**
+
+**Result:** red on `debugLastClip`, not on the strip or the triangle count —
+both of those stay exactly as M14's fix expects, because the mutation touches
+only the clip. At the same swept pan `Offset(0, 53)` on `fillingGrid`:
+
+- narrow arm: clip `Rect.fromLTRB(0.0, -11.0, 416.0, 53.0)` (the padded,
+  viewport-clamped `uncovered`)
+- M4 arm under the mutation: clip `Rect.fromLTRB(0.0, 0.0, 400.0, 300.0)` —
+  the full viewport, identical to its own (correctly widened) strip
+
+so under the mutation the clip moves with the flag and collapses onto the
+strip, which is exactly the "M4 that is neither M4 nor M5" state the new
+assertions exist to refuse.
+
+**Verbatim output** (preamble trimmed as in every other entry in this file):
+
+```
+00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart
+00:00 +0: the rest bake fires: the unflagged arm slices every visible tile
+00:00 +1: debugRestBakeDisabled slices nothing and still covers
+00:00 +2: debugFullViewportQuery grows the fallback walk to the whole viewport
+00:00 +2 -1: debugFullViewportQuery grows the fallback walk to the whole viewport [E]
+  Expected: Rect:<Rect.fromLTRB(0.0, -11.0, 416.0, 53.0)>
+    Actual: Rect:<Rect.fromLTRB(0.0, 0.0, 400.0, 300.0)>
+  the clip must not move when the flag is set -- only the query does: narrow=_FallbackArm(strip: Rect.fromLTRB(0.0, 0.0, 400.0, 85.0), clip: Rect.fromLTRB(0.0, -11.0, 416.0, 53.0), triangles: 60, liveDraws: 1) m4=_FallbackArm(strip: Rect.fromLTRB(0.0, 0.0, 400.0, 300.0), clip: Rect.fromLTRB(0.0, 0.0, 400.0, 300.0), triangles: 80, liveDraws: 1)
+  
+  package:matcher                                     expect
+  package:flutter_test/src/widget_tester.dart 473:18  expect
+  test/tile_measurement_seam_test.dart 229:5          main.<fn>
+  
+00:00 +2 -1: Some tests failed.
+
+Failing tests:
+  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart: debugFullViewportQuery grows the fallback walk to the whole viewport
+```
+
+**Restore, verified.** `cp` from the scratchpad copy, `diff` against it empty,
+`git status --porcelain` showing only this task's own paths, and the file
+re-run green:
+
+```
+00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart
+00:00 +0: the rest bake fires: the unflagged arm slices every visible tile
+00:00 +1: debugRestBakeDisabled slices nothing and still covers
+00:00 +2: debugFullViewportQuery grows the fallback walk to the whole viewport
+00:00 +3: All tests passed!
+```
diff --git a/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart b/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
index c137f19..861fc1c 100644
--- a/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
+++ b/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
@@ -156,20 +156,29 @@ const int kBakeBudgetDevicePixels = 262144;
 /// The cache's byte ceiling, counting the carry-over composite and every
 /// generation's tiles together.
 ///
 /// 96 MiB, not 64, for two reasons. A retired generation lives on as one
 /// viewport-sized composite (29.3 MiB on the reference viewport) beside the
 /// incoming generation's tiles (48.0 MiB at 512 px). And 96 MiB is the figure
 /// this cache may *replace*: the vertex buffer's high-water mark at 500,000
 /// entities, which falls to a single tile's geometry once bakes flush per tile.
 const int kTileCacheBytes = 96 * 1024 * 1024;
 
+/// Consecutive unchanged frames before a rest bake is permitted.
+///
+/// **Two, and the mouse wheel is why.** A wheel delivers isolated notches, so
+/// at one every notch would be a moving frame followed immediately by a
+/// resting frame: a full bake per notch, discarded by the next, and invisible
+/// to any criterion that only watches moving frames. Two costs one frame of
+/// latency (~16.7 ms) and makes a continuously spun wheel bake nothing.
+const int kRestGateFrames = 2;
+
 /// One tile's position in its generation's grid. Not world coordinates: the
 /// grid is anchored to the generation's own device-pixel lattice.
 @immutable
 class TileKey {
   const TileKey(this.x, this.y);
 
   final int x;
   final int y;
 
   @override
@@ -208,20 +217,42 @@ ViewportTransform quantiseCamera(
   final m = camera.worldToScreenMatrix;
   final e = (m.e * devicePixelRatio).roundToDouble() / devicePixelRatio;
   final f = (m.f * devicePixelRatio).roundToDouble() / devicePixelRatio;
   // Returning the same instance matters: `ViewportTransform`'s constructor
   // inverts the matrix, and this runs once per frame on the frame path.
   if (e == m.e && f == m.f) return camera;
   return ViewportTransform(
       worldToScreenMatrix: Transform2(m.a, m.b, m.c, m.d, e, f));
 }
 
+/// Whether two quantised cameras describe the same view, field by field.
+///
+/// Not `operator ==` on [ViewportTransform]: that type is used as a map key
+/// and compared for identity elsewhere, and giving it value equality would
+/// change behaviour far outside this gate.
+///
+/// **Translation is compared, not only scale.** Immediately after a zoom the
+/// generation is empty, so a pan that follows keeps the scale and does not
+/// cover the viewport; a scale-only comparison would let two same-scale pan
+/// frames arm the rest gate and spend a full bake while the camera is still
+/// moving. These are stored values, so the comparison is exact `==` and not
+/// `Tolerance`.
+bool sameQuantisedCamera(ViewportTransform a, ViewportTransform b) {
+  final x = a.worldToScreenMatrix, y = b.worldToScreenMatrix;
+  return x.a == y.a &&
+      x.b == y.b &&
+      x.c == y.c &&
+      x.d == y.d &&
+      x.e == y.e &&
+      x.f == y.f;
+}
+
 /// One scale generation's lattice.
 ///
 /// Tile `(x, y)` occupies device pixels `[x*T, (x+1)*T) x [y*T, (y+1)*T)` in
 /// the **anchor's** screen space. A later camera at the same scale differs from
 /// the anchor by a whole number of device pixels, so a tile's destination is
 /// that rect plus an integral offset — never a resample.
 @immutable
 class TileGrid {
   const TileGrid({
     required this.anchor,
@@ -293,28 +324,84 @@ class TileGrid {
   Rect destRectFor(TileKey key, ViewportTransform camera) {
     final (dx, dy) = deviceDeltaFrom(camera);
     return Rect.fromLTWH(
       (key.x * tileDevicePixels + dx) / devicePixelRatio,
       (key.y * tileDevicePixels + dy) / devicePixelRatio,
       _tileLogical,
       _tileLogical,
     );
   }
 
+  /// Where [key]'s pixels sit **inside** [band]'s image.
+  ///
+  /// Band-local, not grid-space. A key's device rectangle is measured from the
+  /// generation's anchor and goes negative as soon as a same-scale pan moves
+  /// the visible range; the band image starts at (0, 0) whatever the keys are
+  /// numbered. Integral by construction -- [deviceDeltaFrom] rounds, and a
+  /// tile side is `tileDevicePixels` exactly.
+  Rect sliceSourceRect(TileBand band, TileKey key) => Rect.fromLTWH(
+        key.x * tileDevicePixels.toDouble() - band.deviceRect.left,
+        0,
+        tileDevicePixels.toDouble(),
+        tileDevicePixels.toDouble(),
+      );
+
+  /// [visibleKeys] grouped into one band per tile row.
+  ///
+  /// **A band and not the whole union**, because the union has the tile set's
+  /// own area — `visibleKeys` yields a full rectangle — so one image for it
+  /// plus the tiles it is sliced into peaks at exactly `kTileCacheBytes` with
+  /// no headroom. One row at a time is 8 MiB at the reference viewport against
+  /// the union's 48.
+  List<TileBand> bandsFor(ViewportTransform camera, Size viewport) {
+    final byRow = <int, List<TileKey>>{};
+    for (final key in visibleKeys(camera, viewport)) {
+      (byRow[key.y] ??= <TileKey>[]).add(key);
+    }
+    final rows = byRow.keys.toList()..sort();
+    return [
+      for (final row in rows)
+        TileBand(
+          row: row,
+          keys: byRow[row]!..sort((a, b) => a.x.compareTo(b.x)),
+          deviceRect: Rect.fromLTWH(
+            byRow[row]!.first.x * tileDevicePixels.toDouble(),
+            row * tileDevicePixels.toDouble(),
+            byRow[row]!.length * tileDevicePixels.toDouble(),
+            tileDevicePixels.toDouble(),
+          ),
+        ),
+    ];
+  }
+
   /// Floor division that stays correct for negative numerators.
   ///
   /// Dart's `~/` truncates toward zero, so `-1 ~/ 64` is `0` and the tile to
   /// the left of the origin would share a key with the tile at it. A pan in
   /// either direction reaches negative keys within one tile of the anchor.
   static int _floorDiv(int a, int b) => (a / b).floor();
 }
 
+/// One tile row of the visible region: every key in it, and the device
+/// rectangle they span.
+class TileBand {
+  const TileBand(
+      {required this.row, required this.keys, required this.deviceRect});
+
+  final int row;
+  final List<TileKey> keys;
+
+  /// In the grid's device space — the space [TileGrid.deviceDeltaFrom]
+  /// returns, whose origin is the grid's anchor and not the viewport.
+  final Rect deviceRect;
+}
+
 /// A cache of rasterised viewport tiles.
 ///
 /// **What it is for, in numbers.** Plan 3d's clean rows put a 500,000-entity
 /// frame at 17.79 ms of build and 22.40 ms of raster — 40.27 ms of `totalSpan`
 /// against a 16.67 ms budget. The 2026-08-23 spike's Probe D measured the same
 /// frame drawn from a rasterised blit at **1.61 ms**, and the blit is
 /// corpus-independent: 0.97 ms of raster at 50,000 entities and at 500,000
 /// alike. The margin therefore widens with the drawing.
 ///
 /// **What it is not for.** Rebaking every frame — the zoom regime — was
@@ -442,20 +529,40 @@ class TileCache {
   /// every frame.
   ///
   /// **Never a resample of a resample.** A composite is minted only from a
   /// generation that covered the viewport ([_viewportCovered]), so a gesture
   /// frame — which anchors a fresh generation and bakes nothing into it —
   /// carries the *same* composite forward rather than re-flattening the
   /// already-scaled one. Eight gesture frames therefore filter the original
   /// pixels once, not eight times.
   Image? _carryOver;
 
+  /// The band image the current rest bake is slicing, if one is resident.
+  ///
+  /// Null on every frame that is not inside a band's slice loop. Held as a
+  /// field rather than a local **so that [liveBytes] can see it**: the ceiling
+  /// is consulted per sliced tile, and a source image invisible to the meter
+  /// would let the peak run past `kTileCacheBytes` inside the one frame the
+  /// meter exists to bound.
+  Image? _band;
+
+  /// Test seam for the byte meter. See [_band].
+  @visibleForTesting
+  void debugSetBand(Image? band) => _band = band;
+
+  /// Called once per sliced tile, while the band image is resident.
+  ///
+  /// The only point at which the byte ceiling can be observed at its peak;
+  /// a check after the frame would always read the steady state.
+  @visibleForTesting
+  void Function()? debugOnSliceForTest;
+
   /// The screen space [_carryOver] was recorded in: the quantised camera of
   /// the last frame the retired generation covered.
   ///
   /// Not the grid's anchor. A generation outlives many pans, and the anchor
   /// describes the camera the *first* of them ran at — its viewport rectangle
   /// need not hold anything the user can currently see.
   ViewportTransform? _carryOverAnchor;
 
   /// [_carryOver]'s extent in [_carryOverAnchor]'s logical screen space.
   ///
@@ -483,20 +590,72 @@ class TileCache {
   ///
   /// The precondition for minting a composite. A half-filled generation would
   /// flatten to an image that is transparent wherever it never baked, and
   /// blitting that in front of the live fallback would show a blank strip
   /// instead of a stale one.
   bool _viewportCovered = false;
 
   /// The quantised camera of the last [paintFrame].
   ViewportTransform? _lastCamera;
 
+  /// The previous frame's quantised camera, for the rest gate.
+  ViewportTransform? _lastQuantised;
+
+  /// Consecutive frames whose quantised camera did not change.
+  ///
+  /// Zero on the frame that changed. **One** is the frame in between, which
+  /// draws like a moving frame. **Two** arms the rest bake. The second frame
+  /// is the mouse wheel's: a wheel delivers isolated notches, so without it
+  /// every notch is one moving frame followed immediately by a resting frame,
+  /// a full bake per notch discarded by the next.
+  int _restGateSteps = 0;
+
+  /// The rest gate's counter, for tests. See [_restGateSteps].
+  int get debugRestGateSteps => _restGateSteps;
+
+  /// **Suppresses the rest bake. A measurement switch, not a correctness
+  /// switch.**
+  ///
+  /// Set, the resting frame never calls `_restBake`, and the cache fills the
+  /// viewport the way it did before Plan 3i: the ordinary budgeted per-tile
+  /// path, `budgetedTilesPerFrame` tiles a frame, over as many frames as that
+  /// takes. That is not an alternative configuration of the rest bake — it is
+  /// an earlier revision of `paintFrame`, and it is **precisely how criterion
+  /// 4's denominator arm is defined**.
+  ///
+  /// **It exists so one binary can run both arms of criterion 4's ratio in a
+  /// single session, interleaved.** That is the only reason a production
+  /// field carries a measurement switch. The two alternatives are both worse
+  /// and both have been tried in this repository: two binaries cannot
+  /// interleave, so session drift and thermal drift concentrate on whichever
+  /// arm ran last (`docs/superpowers/notes/2026-08-25-plan-3h-results.md`
+  /// records exactly that happening); and a rig that reconstructed the
+  /// per-tile arm for itself would be measuring its own reimplementation
+  /// rather than the code that ships, which is the mistake Plan 3g's `_probeBake`
+  /// made and [debugLastStrip]'s doc comment exists to keep from recurring.
+  /// `runInterleaved` in `dev_harness_2d`'s `measurement_rig.dart` alternates
+  /// whole arms; this field is the half of that arrangement the cache owes.
+  ///
+  /// **Pixels are the same either way; only the number of frames coverage
+  /// takes changes.** Both paths walk the same painter over the same scene
+  /// and bake into the same tile lattice — the band path does one walk per
+  /// tile row and copies the result into tiles, the per-tile path does one
+  /// walk per tile. A viewport that settles in one resting frame with the
+  /// bake enabled settles in tens of frames with it disabled, which is the
+  /// whole quantity criterion 4 scores. `tile_measurement_seam_test.dart`
+  /// pins that reading: with the flag set the cache still reaches
+  /// [viewportCovered] and still bakes tiles, having sliced none.
+  ///
+  /// Defaults to `false`. No non-debug caller sets it — `DraftCanvas` never
+  /// touches it, and the writers are that test and the measurement rig.
+  bool debugRestBakeDisabled = false;
+
   int _bakes = 0;
   int _carryOverBlits = 0;
   int _blits = 0;
   int _liveDraws = 0;
   int _generation = 0;
   int _invalidations = 0;
   int _evictions = 0;
   int _blitDestinations = 0;
   int _imagesAlive = 0;
 
@@ -564,22 +723,24 @@ class TileCache {
   /// composite, and a `liveBytes` that summed only [_tiles] would report the
   /// cache using a third of what it really holds. Measured from the image's
   /// own `width` and `height` rather than from `viewport`, because the
   /// composite's device size is a `ceil` of the viewport and it outlives the
   /// camera it was recorded against.
   ///
   /// A tile is `tileDevicePixels` square, RGBA, one byte a channel: exactly
   /// what `Picture.toImageSync` allocates in [_bake].
   int get liveBytes {
     final carryOver = _carryOver;
+    final band = _band;
     return _tiles.length * _tileBytes +
-        (carryOver == null ? 0 : carryOver.width * carryOver.height * 4);
+        (carryOver == null ? 0 : carryOver.width * carryOver.height * 4) +
+        (band == null ? 0 : band.width * band.height * 4);
   }
 
   /// Tiles the ceiling reclaimed over this cache's whole life.
   ///
   /// Not reset by [resetCounters], for [invalidationCount]'s reason: this
   /// counts a cache-lifetime event, not a per-frame one. **Distinct from
   /// [invalidationCount] deliberately** — an invalidated tile held wrong
   /// pixels, an evicted one held perfectly good pixels there was no room for,
   /// and a test that could not tell them apart would read a thrashing cap as a
   /// busy editor.
@@ -661,28 +822,95 @@ class TileCache {
 
   /// The rectangle the fallback walked on the most recent frame, or `null` if
   /// no fallback ran. Test-only, and **read-only**.
   ///
   /// Read from the shipped `paintFrame` rather than recomputed by a test, and
   /// that is the whole point of it. Plan 3g's rig reimplemented the bake
   /// geometry in `_probeBake` instead of calling `_bake`, so its overdraw
   /// column described the reimplementation and not the code that ships. A
   /// sweep that derived this rectangle from [TileGrid] would repeat that.
   ///
-  /// **A getter, not a mutable field.** `TileCache` already carries two
-  /// mutable test-only fields and the standing bar is that a third triggers
-  /// revisiting the design; `tilesHolding` is the precedent for reading state
-  /// out without adding a way to write it.
+  /// **A getter, not a mutable field.** `TileCache` now carries four mutable
+  /// test-only fields (`debugOnSliceForTest`, `debugRestBakeDisabled`,
+  /// `debugFullViewportQuery`, `bakeBudgetDevicePixels`) -- the bar that a
+  /// third would trigger revisiting the design has already been crossed and
+  /// answered. The revisit is Ruling 14 in Plan 3i's progress ledger: Tasks
+  /// 12 and 13 each pin a measurement whose two arms are meant to interleave
+  /// inside one session, and interleaving requires switching behaviour at
+  /// runtime -- two binaries cannot interleave. `tilesHolding` remains the
+  /// precedent for reading state out without adding a way to write it.
   Rect? get debugLastStrip => _lastStrip;
 
   Rect? _lastStrip;
 
+  /// The rectangle the fallback clipped its drawing to on the most recent
+  /// frame, or `null` if no fallback ran. Test-only, and **read-only**, for
+  /// [debugLastStrip]'s own reasons — read from the shipped `paintFrame`
+  /// rather than recomputed by a test.
+  ///
+  /// **Distinct from [debugLastStrip] deliberately.** [debugFullViewportQuery]
+  /// widens the strip the fallback *walks* while `canvas.clipRect(uncovered,
+  /// ...)` above it stays narrow -- that is what makes the flag Plan 3h's M4
+  /// and not its M5, and nothing before this getter existed could see the
+  /// clip independently of the strip. A change that widened the clip under
+  /// the flag would keep the strip assertion green while publishing an "M4"
+  /// arm that is neither 3h's M4 nor its M5.
+  Rect? get debugLastClip => _lastClip;
+
+  Rect? _lastClip;
+
+  /// **Hands the live fallback's query the full viewport instead of the
+  /// strip. This field ships a known defect behind a flag, and that is what
+  /// it is for.**
+  ///
+  /// It reproduces **Plan 3h's mutant M4** at runtime — defined in
+  /// `docs/superpowers/notes/plan-3h-mutation-log.md`, §"M4 — narrow the clip
+  /// but not the query": keep the narrow clip, and hand the query — what is
+  /// *walked*, not what is *drawn* — the whole viewport. Every pixel still
+  /// lands where it belongs, because the clip discards the surplus; what
+  /// changes is how much geometry the frame tessellates to produce them. That
+  /// is why the gate which kills M4 counts triangles and not pixels — see
+  /// `kTriangleBudgetRatio` in `test/support/tile_comparison.dart`.
+  ///
+  /// **The clip stays narrow, and that is what makes this M4 and not M5.**
+  /// The `canvas.clipRect(uncovered, doAntiAlias: false)` immediately above
+  /// the query is outside this field's reach and must stay that way. M5, in
+  /// the same log, reaches the same end state from the other direction — it
+  /// grows the query and leaves the clip untouched — so widening the clip
+  /// here would be neither mutant, and the M4 arm of a published ratio would
+  /// not be M4.
+  ///
+  /// **It exists so criterion 8's two arms can interleave inside one
+  /// session**, at n=9 per arm. Plan 3h could only run "narrow" and "M4" as
+  /// two binaries, three-then-three, because M4 was a source edit with no
+  /// runtime switch; its own results
+  /// (`docs/superpowers/notes/2026-08-25-plan-3h-results.md`) record what that
+  /// cost — the M4 arm ran last, in a visibly noisier session, on a phase M4
+  /// is inert on, so the arm ordering and not the mutation moved the numbers.
+  /// Removing that bias is Plan 3i's Task 13, and it needs a runtime switch or
+  /// it needs two binaries again.
+  ///
+  /// **Not byte-identical to Plan 3h's M4, though everything measured agrees.**
+  /// 3h's M4 kept `_lastStrip` narrow and dropped `canvas.translate` outright;
+  /// this flag instead routes the full viewport *through* `_lastStrip` and
+  /// leaves `canvas.translate(strip.left, strip.top)` in place, evaluating to
+  /// `translate(0, 0)`. That is numerically inert (`q.e - 0.0` is exact) and
+  /// every measured quantity -- walk extent, triangle count, pixels -- is
+  /// equivalent, but it means a [debugLastStrip] reading taken from this
+  /// flag's M4 arm cannot be cross-read against Plan 3h's log, which recorded
+  /// a narrow `_lastStrip` on its own M4 arm.
+  ///
+  /// Defaults to `false`. No non-debug caller sets it: a frame that reaches
+  /// the fallback with this standing is doing measurably more work than it has
+  /// to, deliberately.
+  bool debugFullViewportQuery = false;
+
   /// The blit `Paint`'s identity, for criterion 13.
   ///
   /// Exposed the way `VerticesDrawSink.debugPaint` is, and for the same
   /// reason: `paint_allocation_test.dart` reads
   /// `VerticesDrawSink.debugCapacityVertices` and that field can see neither a
   /// `Paint` nor a `Rect`. `STATUS.md` records why there is no heap-level
   /// instrument on this side — trap 5 — so the allocation criterion is a field
   /// read or it is prose.
   Paint get debugBlitPaint => _blitPaint;
 
@@ -730,28 +958,82 @@ class TileCache {
     // never baked the entity can still owe pixels for it.
     if (tablesRevision != _tablesRevision) {
       _tablesRevision = tablesRevision;
       _dropGeneration();
     }
 
     // Before anything reads it, so no tile can be carrying this frame's
     // ordinal before this frame blits it. `_makeRoomForOneTile` rests on that.
     _frameSerial++;
     _lastStrip = null;
+    _lastClip = null;
 
     final quantised = quantiseCamera(camera, devicePixelRatio);
     // The viewport reaches `_gridFor` because retiring a generation is now a
     // composite and not just a `dispose`: the outgoing tiles have to be
     // flattened into one viewport-sized image *before* they go.
     final grid = _gridFor(quantised, devicePixelRatio, viewport);
     _lastCamera = quantised;
 
+    // **Three frame kinds, and only one of them bakes.** A frame whose camera
+    // changed is *moving*. A frame that has matched once and not yet twice is
+    // the one in between. Both draw the composite and nothing else: no bake,
+    // and no live walk.
+    //
+    // The live walk is excluded deliberately and the measurement is why. On a
+    // moving frame the new generation is empty, so every visible key misses
+    // and `uncovered` accumulates by `expandToInclude` into the **whole
+    // viewport** rather than a ring; `stripFor` then clamps to the viewport.
+    // "Walk the uncovered region" is therefore a full-viewport live walk --
+    // 31.5-41.6 ms at 500,000 entities -- on every zoom-out frame.
+    final previous = _lastQuantised;
+    _restGateSteps =
+        previous != null && sameQuantisedCamera(previous, quantised)
+            ? _restGateSteps + 1
+            : 0;
+    _lastQuantised = quantised;
+    // **`previous == null` is not a moving frame.** It is the very first
+    // frame this cache has ever painted, with nothing behind it to have
+    // moved away from. Gating it on the literal `_restGateSteps >=
+    // kRestGateFrames` would leave a brand-new cache blank -- no bake, and
+    // since nothing has ever been retired -- until some later frame
+    // fortuitously repeated the same camera.
+    //
+    // **Not `&& !_viewportCovered` either.** A frame whose camera matches the
+    // last one but whose generation already covers the viewport still has to
+    // run the loop below: every visible key already holds an image, so the
+    // loop bakes nothing on its own, but it still has to *blit* those images
+    // onto this frame's canvas. `TileCache.paintFrame`'s only other exit from
+    // that loop is the coverage check inside it, which already makes baking
+    // a no-op once covered -- gating the loop itself here would additionally
+    // skip the blit, and a repeated call at an unchanged, already-settled
+    // camera would draw nothing at all.
+    //
+    // **Nor on a moving frame with no composite to fall back on.** The early
+    // return below is only honest when the carry-over blit just above it
+    // actually put something on screen. `_carryOver` is null on a moving
+    // frame in at least three real situations: the first frame this cache
+    // has ever painted (already exempted above); the outgoing generation
+    // never covered the viewport, so `_retireGeneration` minted nothing --
+    // which is exactly the state a second zoom reaches when it lands before
+    // the first one's settle completes; and any of `applyChange`,
+    // `_dropGeneration` or `_dropEverything` dropping a standing composite
+    // outright, if a camera change then lands before a rested frame. Gating
+    // a frame with no composite would paint nothing at all -- not a stale
+    // frame but a blank one -- for as long as the gesture continued. A blank
+    // viewport is worse than an expensive one, so this falls through to the
+    // ordinary bake-and-live-walk path instead: where there is nothing stale
+    // to show, drawing the real thing is the honest fallback.
+    final resting = previous == null ||
+        _carryOver == null ||
+        _restGateSteps >= kRestGateFrames;
+
     // Derived once and handed to every bake. Rebasing is frame-global by
     // construction; a per-tile origin would give each tile its own
     // quantisation step and `float32` residuals the live frame does not have.
     final origin = rebaseOriginFor(quantised.visibleWorld(viewport));
 
     // The budget is device pixels; a tile costs its own area against it, so
     // this is the number of *tiles* this frame may bake at the cache's
     // current tile size. See [budgetedTilesPerFrame]'s own doc comment.
     var budget = budgetedTilesPerFrame;
     var baked = 0;
@@ -776,20 +1058,43 @@ class TileCache {
       // there is nothing left to fill; a zoom *out* shrinks it and leaves a
       // genuine ring the live fallback owes. Asserting the containment rather
       // than assuming the gesture's direction is the difference between a
       // cheap gesture and a blank border.
       carryOverCovers = dest.left <= 0 &&
           dest.top <= 0 &&
           dest.right >= viewport.width &&
           dest.bottom >= viewport.height;
     }
 
+    if (!resting) {
+      // Nothing else this frame. `resting` is false here only because the
+      // camera is moving and a composite is already down to show for it --
+      // that is the third disjunct in `resting`'s own definition above, not
+      // an assumption made again here. A zoom out leaves that composite's
+      // ring as background until the gesture ends (spec D3).
+      return;
+    }
+
+    // **The literal gate here, and not `resting`.** `resting` is true on two
+    // frames that are not at rest at all: the very first frame this cache
+    // paints, and any moving frame with no composite to fall back on. Both
+    // disjuncts exist to stop a frame painting *nothing* -- the comment above
+    // says so in as many words: they "fall through to the ordinary
+    // bake-and-live-walk path". That path is budgeted and the band bake is
+    // not, so handing those two frames to the band bake would spend a
+    // full-viewport walk on the first frame of a still-moving gesture, which
+    // is precisely the zoom-regime cost this cache exists to refuse. A band
+    // is for a camera that has actually stopped.
+    if (_restGateSteps >= kRestGateFrames && !debugRestBakeDisabled) {
+      _restBake(grid, quantised, viewport, painter, sink, vertices, origin);
+    }
+
     for (final key in grid.visibleKeys(quantised, viewport)) {
       var image = _tiles[key];
       // **The ceiling is consulted before the bake, not after the frame.** A
       // small cap against a viewport of many tiles means the visible set alone
       // overruns it, so a sweep at the end of `paintFrame` would have nothing
       // left to reclaim -- every tile it could take was blitted this frame --
       // and `liveBytes` would settle wherever the visible set happened to put
       // it. Asking first makes the ceiling hold at every point inside the
       // frame as well as at its edges.
       if (image == null && budget > 0 && _makeRoomForOneTile()) {
@@ -826,57 +1131,271 @@ class TileCache {
       // change of the same gesture with nothing to blit while its own
       // generation is still empty. Surviving the frame that filled it costs
       // one frame of stale ink under antialiased edges and buys a gesture that
       // never blanks.
       if (baked == 0) _dropCarryOver();
       return;
     }
     // Stale scaled pixels rather than a live walk, deliberately: replaying the
     // whole painter is the ~60 ms stall this cache exists to remove, and a
     // gesture frame is precisely where it must not happen.
+    //
+    // **`carryOverCovers` was measured before [_restBake] may have dropped
+    // the composite, and that combination cannot leave this frame blank.**
+    // Read literally the pair is alarming: a `true` here plus a released
+    // composite plus an uncovered key would return with neither stale pixels
+    // nor a live walk -- blank, which is worse than either. It is
+    // unreachable, and the reason is [_restBake]'s own precondition rather
+    // than anything on this line. `_restBake` releases the composite only
+    // after pricing one band plus **every visible tile** against
+    // [cacheBytes], and `_makeRoomForOneTile` can then always find room,
+    // because the only tiles carrying this frame's serial are ones the same
+    // rest bake just cut. So a frame that dropped the composite is a frame
+    // that filled every visible key, `uncovered` is null, and control took
+    // the covered return above without ever reaching this line. The assert
+    // states it so a future change to that pricing fails loudly here instead
+    // of shipping an intermittently blank viewport.
+    assert(
+        !carryOverCovers || hasCarryOver,
+        'a frame that released the composite must have covered the viewport, '
+        'or this return leaves neither stale pixels nor a live walk');
     if (carryOverCovers) return;
     // One walk for the union, not one per tile: at 512 px a full visible set is
     // about 48 tiles (see the 48.0 MiB figure above), and 48 painter invocations
     // in one frame would be slower than the live path this cache exists to
     // replace. Clipped, so the covered tiles keep the pixels they just blitted.
     canvas.save();
     // **The clip is unchanged, and that is a decision.** `_bake` states the
     // rule for itself -- "The query is padded; the clip is not." Drop this
     // line and the pad becomes overdraw onto tiles already blitted: the pixels
     // stay correct, so the sweep still reads zero, and the cost this whole
     // change exists to remove comes back silently.
     canvas.clipRect(uncovered, doAntiAlias: false);
+    _lastClip = uncovered;
     // **Walk the union, not the viewport.** The clip above only discards
     // drawing; the walk below is what costs. `DraftPainter.paint` derives its
     // index query from `camera.visibleWorld(viewport)`, so handing it the full
     // viewport tessellates the whole frame and throws most of it away -- which
     // is what every fallback did before this line, and why the frame's excess
     // read as a full live walk.
-    final strip = stripFor(uncovered, viewport);
+    final strip = debugFullViewportQuery
+        ? Offset.zero & viewport
+        : stripFor(uncovered, viewport);
     _lastStrip = strip;
     canvas.translate(strip.left, strip.top);
     final q = quantised.worldToScreenMatrix;
     _drawInto(
         canvas,
         Size(strip.width, strip.height),
         ViewportTransform(
             worldToScreenMatrix: Transform2(
                 q.a, q.b, q.c, q.d, q.e - strip.left, q.f - strip.top)),
         painter,
         sink,
         vertices,
         origin,
         null);
     canvas.restore();
     _liveDraws++;
   }
 
+  /// Fills the visible region a **tile row at a time**, on a resting frame.
+  ///
+  /// **One walk per band, not one per tile.** A 512-pixel tile costs 12.56 ms
+  /// to bake (see [kTileDevicePixels]) and two of them overrun the frame
+  /// budget, so the tiled fill baked one tile per frame: after a zoom that is
+  /// about forty frames of stale, magnified pixels. A band is one walk of the
+  /// painter for a whole row, rasterised once and then *copied* into its
+  /// tiles -- a texture copy, not a raster -- so a viewport fills in one
+  /// frame.
+  ///
+  /// **Only when a visible key is actually missing.** A resting frame is not
+  /// necessarily an unfilled one: `paintFrame` reaches here on every frame
+  /// whose camera has stood still, including ones that already hold every tile
+  /// they need. Rebaking those would replace good images with identical ones,
+  /// leak the images it overwrote, and pay a full walk for nothing. This is
+  /// the "viewport not covered" half of the resting regime, tested against the
+  /// tiles themselves rather than against [_viewportCovered], which is a
+  /// statement about the *previous* frame's camera.
+  void _restBake(
+    TileGrid grid,
+    ViewportTransform quantised,
+    Size viewport,
+    DraftPainter painter,
+    CanvasDrawSink sink,
+    VerticesDrawSink? vertices,
+    Vector2 origin,
+  ) {
+    var missing = false;
+    for (final key in grid.visibleKeys(quantised, viewport)) {
+      if (!_tiles.containsKey(key)) {
+        missing = true;
+        break;
+      }
+    }
+    if (!missing) return;
+
+    final bands = grid.bandsFor(quantised, viewport);
+    if (bands.isEmpty) return;
+    final bandBytes = _bandBytesOf(bands.first);
+    var visibleTiles = 0;
+    for (final band in bands) {
+      visibleTiles += band.keys.length;
+    }
+    // **The whole fill is priced before any of it happens, and that is what
+    // makes dropping the composite safe.** A rest bake is all-or-nothing by
+    // intent: it exists to replace every pixel the composite serves in one
+    // frame. Under a ceiling that cannot hold a band plus the visible set,
+    // it would instead evict its own output slice by slice, arrive covering
+    // nothing, and have thrown the composite away to do it -- replacing
+    // stale pixels with a live walk, forever, which is the state
+    // [_makeRoomForOneTile]'s "bakes nothing rather than overrun" arm exists
+    // to refuse. So a ceiling that small leaves the whole frame to the
+    // budgeted tile loop below, composite and all.
+    //
+    // The peak this prices is the one the design was costed against: one band
+    // plus a full generation, 8 + 48 MiB at the reference viewport, against a
+    // 96 MiB cap. The *source* picture is not in it and cannot be -- it is
+    // freed by `endRecording` inside [_bakeBand] before the image exists.
+    if (bandBytes + visibleTiles * _tileBytes > cacheBytes) return;
+
+    // **The composite goes first.** The frame is about to draw real content
+    // and does not need it: it was blitted onto this canvas already, and the
+    // tiles below land on the same pixels. At the reference viewport the
+    // source picture and the tile set are each about 48 MiB against a 96 MiB
+    // cap, so the composite's 29.3 MiB on top is exactly what banding exists
+    // to avoid -- dropping it before the bake is the other half of the same
+    // arithmetic, and it is what leaves the ceiling room for the band. It is
+    // the same rule the covered-frame drop below states ("the incoming
+    // generation now covers every pixel the composite served"), decided
+    // ahead of the fill rather than after it, which the check above is what
+    // licenses.
+    _dropCarryOver();
+
+    for (final band in bands) {
+      // **Asked before the band is allocated, not after.** The ceiling is a
+      // ceiling and not a suggestion (see [_makeRoomForOneTile]), and a band
+      // is a whole row -- thirteen tiles' worth here, 8 MiB at the reference
+      // viewport. Baking one and discovering afterwards that nothing could be
+      // kept is the silent overrun that arm exists to refuse, so a ceiling
+      // that cannot hold a band leaves the whole rest bake to the ordinary
+      // budgeted tile loop and the live fallback below.
+      if (!_makeRoomForBytes(bandBytes + _tileBytes)) return;
+
+      final visited = <int>[];
+      final image = _bakeBand(
+          band, grid, quantised, painter, sink, vertices, origin, visited);
+      _band = image;
+      // [_bakeBand]'s `onVisit` records only what the painter visited
+      // directly; [_bake]'s climbs owners so that a *container's* transform
+      // reaches the tile through invalidation's direction one. This is where
+      // the band makes up the difference -- once per band rather than once
+      // per tile, which is the whole reason the band callback is the simpler
+      // one.
+      _recordOwners(visited, painter.document);
+      visited.sort();
+      // **One record per band, shared by reference.** `_invalidateTouched`
+      // condemns tiles by iterating `_baked`, and a sliced tile with no record
+      // is invisible to it: edit an entity after a settle and the stale tile
+      // keeps blitting over the corrected drawing. Sharing makes invalidation
+      // band-coarse, which is right because a band is exactly the unit a
+      // rebake walks.
+      final record = Uint32List.fromList(visited);
+      for (final key in band.keys) {
+        // A key this frame's tile map already serves keeps its own image and
+        // its own, narrower record. Overwriting it would leak the image it
+        // replaced -- `_tiles[key] = tile` disposes nothing -- and a pan
+        // within one generation reaches this loop with most of the row
+        // already held.
+        if (_tiles.containsKey(key)) {
+          _lastUsedFrame[key] = _frameSerial;
+          continue;
+        }
+        debugOnSliceForTest?.call();
+        // The ceiling is consulted before the write, not after the frame --
+        // the rule the tile loop already follows. The slice bypasses
+        // `budgetedTilesPerFrame`, which rations bakes; a slice is not a bake.
+        if (!_makeRoomForOneTile()) break;
+        final tile = _sliceTile(image, band, key, grid);
+        _tiles[key] = tile;
+        _baked[key] = record;
+        _lastUsedFrame[key] = _frameSerial;
+      }
+      _band = null;
+      _disposeImage(image);
+      _bakes++;
+    }
+  }
+
+  /// [_bake]'s owner climb, applied once to a whole band's visit list.
+  ///
+  /// **Direction one of the invalidation rule, which the band walk cannot
+  /// record for itself.** A tile's `_baked` record has to name not only the
+  /// entities drawn on it but every container they hang under, or a transform
+  /// applied to a group never condemns the tiles its children inked and the
+  /// drawing goes stale after an edit. [_bake] does this inside its own
+  /// `onVisit`; a band's `onVisit` records the direct visit alone and this
+  /// closes the gap over the accumulated list.
+  ///
+  /// Only the prefix that was there on entry is read, so the owners appended
+  /// below are not themselves re-climbed -- they cannot add anything, because
+  /// [climb] already walks each chain to its root.
+  void _recordOwners(List<int> visited, DraftDocument document) {
+    // Container nodes already recorded. Both a memo and the termination
+    // guard, exactly as in [_bake]: once a node is in, every ancestor of it is
+    // in too, so the climb stops there -- which keeps the pass linear in
+    // visits rather than O(visits x depth), and makes a malformed cyclic
+    // parent chain terminate instead of hanging the bake.
+    final containers = <int>{};
+
+    void climb(Handle from) {
+      var current = from;
+      while (true) {
+        final node = document.tree[current];
+        // A definition handle lives outside the node map, and a definition is
+        // not a placement: an edit inside one takes the generation-drop path
+        // and never consults this list.
+        if (node == null) return;
+        if (!containers.add(current.value)) return;
+        visited.add(current.value);
+        if (node.parent.isNone) return;
+        current = node.parent;
+      }
+    }
+
+    final direct = visited.length;
+    for (var i = 0; i < direct; i++) {
+      final handle = Handle(visited[i]);
+      final slot = document.entities.slotOf(handle);
+      if (slot != null) {
+        // A leaf names its container by owner; the root is a `GroupNode` like
+        // any other and is recorded too, so a transform of the root reaches
+        // every tile through direction one.
+        climb(document.entities.ownerAt(slot));
+        continue;
+      }
+      // An instance node the painter descended into: it is already recorded
+      // by the direct visit, and what is missing is the groups it hangs under.
+      final node = document.tree[handle];
+      if (node != null && !node.parent.isNone) climb(node.parent);
+    }
+  }
+
+  /// One band image's footprint: RGBA over its device rectangle, exactly what
+  /// `Picture.toImageSync` allocates in [_bakeBand].
+  ///
+  /// Every band of one grid is the same height and the visible region is a
+  /// full rectangle, so [TileGrid.bandsFor] yields rows of equal width and one
+  /// band's size answers for all of them.
+  int _bandBytesOf(TileBand band) =>
+      band.deviceRect.width.round() * band.deviceRect.height.round() * 4;
+
   /// Every tile is the same square, so this is built once rather than per
   /// blit. It was a getter until Task 10, which allocated a fresh `Rect` on
   /// each of a frame's ~48 blits — bounded by the viewport, so never a rule
   /// break, but the wrong side of the criterion this task lands.
   late final Rect _tileSourceRect = Rect.fromLTWH(
       0, 0, tileDevicePixels.toDouble(), tileDevicePixels.toDouble());
 
   /// Bytes one tile's image occupies: RGBA, one byte a channel, exactly what
   /// `Picture.toImageSync` allocates in [_bake].
   int get _tileBytes => tileDevicePixels * tileDevicePixels * 4;
@@ -932,25 +1451,36 @@ class TileCache {
   ///
   /// **The composite is never a candidate.** It is not in [_tiles] at all, and
   /// deliberately: [paintFrame] reads it every frame it stands, so a
   /// recency-ordered policy would never choose it anyway, and reclaiming it
   /// would replace stale pixels with blank ones. It still *counts* against the
   /// ceiling through [liveBytes] — so a cap smaller than one composite simply
   /// bakes nothing, which is the honest answer rather than a silent overrun.
   ///
   /// Returning `false` rather than baking anyway is what keeps [liveBytes] a
   /// ceiling and not a suggestion.
-  bool _makeRoomForOneTile() {
+  bool _makeRoomForOneTile() => _makeRoomForBytes(_tileBytes);
+
+  /// [_makeRoomForOneTile] generalised to an allocation that is not a tile.
+  ///
+  /// **A band is a whole tile row**, so the rest bake cannot ask this question
+  /// in units of one tile: it would be told yes, allocate thirteen tiles'
+  /// worth, and blow past [cacheBytes] before the first slice. Every word of
+  /// [_makeRoomForOneTile]'s doc comment applies unchanged -- the victim
+  /// policy, the blitted-this-frame guard, and the refusal to allocate at all
+  /// rather than overrun -- with only the size of the hole being made
+  /// different.
+  bool _makeRoomForBytes(int wanted) {
     // Computed from `liveBytes` so the composite is counted, then tracked
     // locally: the loop's only effect on it is one tile's worth per eviction.
     var bytes = liveBytes;
-    final ceiling = cacheBytes - _tileBytes;
+    final ceiling = cacheBytes - wanted;
     while (bytes > ceiling) {
       TileKey? victim;
       var oldest = 0;
       // A linear scan, not a heap. This runs only when the cache is full, the
       // map it walks is bounded by the ceiling itself, and a priority queue
       // would need per-blit maintenance on the frame path to save a scan that
       // a warm frame never performs.
       for (final entry in _lastUsedFrame.entries) {
         if (entry.value == _frameSerial) continue;
         if (victim == null || entry.value < oldest) {
@@ -1526,20 +2056,174 @@ class TileCache {
     visited.sort();
     _baked[key] = Uint32List.fromList(visited);
     final picture = recorder.endRecording();
     final image = picture.toImageSync(tileDevicePixels, tileDevicePixels);
     _imagesAlive++;
     picture.dispose();
     _bakes++;
     return image;
   }
 
+  /// Walks one band into one image.
+  ///
+  /// Modelled on [_bake] and sharing all three of its rules, at band scale.
+  ///
+  /// **The `onVisit` callback is deliberately simpler than [_bake]'s.**
+  /// `_bake` climbs owners so a container transform reaches the tile through
+  /// direction one. A band records the same information for a wider region,
+  /// and its caller shares one record across the band's tiles, so the owner
+  /// climb happens once there rather than once per tile.
+  Image _bakeBand(
+    TileBand band,
+    TileGrid grid,
+    ViewportTransform quantised,
+    DraftPainter painter,
+    CanvasDrawSink sink,
+    VerticesDrawSink? vertices,
+    Vector2 origin,
+    List<int> visitedInto,
+  ) {
+    // **The scale is the frame camera's; the translation is the anchor's.**
+    // [TileBand.deviceRect] lives in the grid's device space, whose origin is
+    // [TileGrid.anchor] and not this frame's camera -- exactly as a tile key
+    // does, and [TileGrid.bakeCameraFor] rebases a single tile off the anchor
+    // for the same reason. A generation outlives many pans, so at a rest bake
+    // the frame camera sits a whole number of device pixels away from the
+    // anchor; taking the translation from it would slide the band by that pan
+    // and the tiles cut out of it would not hold what [_bake] puts in the
+    // same keys. The frame camera is still required to belong to this
+    // generation, which is what the assert below states.
+    assert(
+        grid.matchesScale(quantised),
+        'a band belongs to one generation, so the frame camera and the grid '
+        'anchor must agree on scale');
+    final dpr = grid.devicePixelRatio;
+    final width = band.deviceRect.width / dpr;
+    final height = band.deviceRect.height / dpr;
+    final recorder = PictureRecorder();
+    final into = Canvas(recorder);
+    into.scale(dpr);
+    // **Hard, and for [_bake]'s reason.** An antialiased clip edge would make
+    // two adjacent bands' `source-over` fall short of full coverage along the
+    // row they share: a seam, in the one place this design exists to remove
+    // one.
+    into.clipRect(Rect.fromLTWH(0, 0, width, height), doAntiAlias: false);
+
+    // **The query is padded; the clip is not.** A stroke whose centreline lies
+    // just outside the band still inks inside it. [kTileSlack] is the same
+    // slack [_bake] queries with and the same slack the invalidation rule
+    // uses -- padding one alone makes them disagree. The canvas is pulled back
+    // by the same amount, so the padded viewport's origin lands where the
+    // band's own origin was.
+    const pad = kTileSlack;
+    into.save();
+    into.translate(-pad, -pad);
+
+    final m = grid.anchor.worldToScreenMatrix;
+    final bandCamera = ViewportTransform(
+      worldToScreenMatrix: Transform2(
+        m.a,
+        m.b,
+        m.c,
+        m.d,
+        m.e - band.deviceRect.left / dpr + pad,
+        m.f - band.deviceRect.top / dpr + pad,
+      ),
+    );
+
+    _drawInto(
+      into,
+      Size(width + 2 * pad, height + 2 * pad),
+      bandCamera,
+      painter,
+      sink,
+      vertices,
+      // **The viewport's origin, never the band's.** Rebasing is frame-global
+      // by construction: a per-band origin gives each band its own
+      // quantisation step and `float32` residuals the live frame does not
+      // have, and can cross a power-of-two step between one row and the next.
+      origin,
+      (handle) => visitedInto.add(handle.value),
+    );
+    into.restore();
+
+    final picture = recorder.endRecording();
+    final image = picture.toImageSync(
+        band.deviceRect.width.round(), band.deviceRect.height.round());
+    _imagesAlive++;
+    picture.dispose();
+    return image;
+  }
+
+  /// Test seam for [_bakeBand], which [_restBake] now also calls on the frame
+  /// path.
+  ///
+  /// **It was the only caller until Plan 3i Task 8 wired the band bake in**,
+  /// and it was introduced because `unused_element` is an error in this
+  /// package. That justification is gone; the wrapper stays because Task 6's
+  /// tests are written against it, and because what it lets them do is still
+  /// worth doing:
+  ///
+  /// What the band bake decides -- where the band camera puts a world point,
+  /// how far past the band's edge the query reaches, and which origin the walk
+  /// is rebased against -- is checkable without rasterising anything, and this
+  /// is what lets it be checked. The returned image is the caller's to
+  /// dispose.
+  @visibleForTesting
+  Image debugBakeBand(
+    TileBand band,
+    TileGrid grid,
+    ViewportTransform quantised,
+    DraftPainter painter,
+    CanvasDrawSink sink,
+    VerticesDrawSink? vertices,
+    Vector2 origin,
+    List<int> visitedInto,
+  ) =>
+      _bakeBand(
+          band, grid, quantised, painter, sink, vertices, origin, visitedInto);
+
+  /// Copies one tile's pixels out of a band image.
+  ///
+  /// A texture copy, not a geometry raster -- which is the whole difference
+  /// from the rejected Approach B. `FilterQuality.none`: the source rectangle
+  /// is integral and the destination is the same size, so there is nothing to
+  /// interpolate and a sampler would be pure cost.
+  Image _sliceTile(Image band, TileBand from, TileKey key, TileGrid grid) {
+    final recorder = PictureRecorder();
+    final into = Canvas(recorder);
+    into.drawImageRect(
+      band,
+      grid.sliceSourceRect(from, key),
+      Rect.fromLTWH(
+          0, 0, tileDevicePixels.toDouble(), tileDevicePixels.toDouble()),
+      _blitPaint,
+    );
+    final picture = recorder.endRecording();
+    final image = picture.toImageSync(tileDevicePixels, tileDevicePixels);
+    _imagesAlive++;
+    picture.dispose();
+    return image;
+  }
+
+  /// Test seam for [_sliceTile], which [_restBake] now also calls on the frame
+  /// path.
+  ///
+  /// Like [debugBakeBand] this existed because the slice had no production
+  /// caller until Plan 3i Task 8 and `unused_element` is an error in this
+  /// package. Kept because Task 7's tests call it directly, which is how they
+  /// slice a band they built themselves rather than one a whole frame
+  /// produced.
+  @visibleForTesting
+  Image debugSliceTile(Image band, TileBand from, TileKey key, TileGrid grid) =>
+      _sliceTile(band, from, key, grid);
+
   void _drawInto(
     Canvas canvas,
     Size size,
     ViewportTransform camera,
     DraftPainter painter,
     CanvasDrawSink sink,
     VerticesDrawSink? vertices,
     Vector2 origin,
     void Function(Handle handle)? onVisit,
   ) {
diff --git a/packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart b/packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart
index fe623e3..f35d997 100644
--- a/packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart
+++ b/packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart
@@ -50,47 +50,74 @@ const int _compositeBytes = 800 * 600 * 4;
 ///
 /// 138 tiles. A covering generation at this viewport and tile size is 130, so
 /// the first frame covers -- which is the precondition for minting a composite
 /// at all. The composite is then 1,920,000 of the ceiling's 2,260,992 bytes,
 /// leaving room for twenty tiles: a sixth of the viewport, so the generation
 /// never covers again, the composite is never dropped, and every pan after the
 /// zoom has to evict. That intersection is the state the two states this file
 /// already covered could not reach between them.
 const int _capWithComposite = 138 * _tileBytes;
 
+/// Enough more frames at the same camera `rig` just painted for the rest
+/// gate to arm and a resting frame to actually bake.
+///
+/// Plan 3i Task 2: a frame whose camera just changed is *moving* and draws
+/// only the carry-over composite -- no bake, no tile blit, no live walk.
+/// Every pan or zoom in this file used to bake and evict on the very next
+/// frame; now that frame is the moving one, and one more, unchanged-camera
+/// call used to be the one that actually bakes, blits and evicts, matching
+/// this file's pre-Plan-3i counts again.
+///
+/// Plan 3i Task 3 then raised the threshold from one unchanged frame to
+/// [kRestGateFrames] (two), so a single extra call now lands on the frame
+/// *in between* -- still not resting, so it also only blits the composite --
+/// and it takes `kRestGateFrames` of them to reach the one that bakes.
+void settle(TileRig rig) {
+  for (var i = 0; i < kRestGateFrames; i++) {
+    rig.paintOnce();
+  }
+}
+
 void main() {
   test('criterion 12: the cap holds and eviction is real, not theoretical',
       () async {
     // A cap of eight tiles at 64 device pixels: 8 * 64 * 64 * 4 = 131,072 B.
     // Small on purpose -- the point is that the policy runs, and a production
     // cap would need a corpus this suite cannot afford.
     final rig = TileRig(
         tileDevicePixels: 64, tilesBakedPerFrame: 1000, cacheBytes: 131072);
     addTearDown(rig.dispose);
 
     for (var i = 0; i < 6; i++) {
       rig.panBy(-64, -32);
       rig.paintOnce();
+      // No `settle` here: this test only pans, so no generation is ever
+      // retired and `_carryOver` stays null throughout -- the rest gate's
+      // fallback for a moving frame with nothing to fall back on keeps this
+      // call unGated, matching pre-Plan-3i counts on the very first call.
       expect(rig.cache.liveBytes, lessThanOrEqualTo(131072), reason: 'pan $i');
     }
     expect(rig.cache.evictionCount, greaterThan(0),
         reason: 'anti-degenerate clause 7: a cap nothing reaches is not a cap');
   });
 
   test('criterion 12: a pan back to reclaimed tiles draws live, not blank',
       () async {
     // Anti-degenerate clause 7. This is the failure that would ship as an
     // intermittent blank strip: no settled-frame criterion can see it.
     final rig = TileRig(
         tileDevicePixels: 64, tilesBakedPerFrame: 2, cacheBytes: 131072);
     addTearDown(rig.dispose);
     rig.paintOnce();
+    // No `settle` in either loop below: this test only pans, so `_carryOver`
+    // stays null throughout and every one of these calls falls through
+    // unGated.
     for (var i = 0; i < 6; i++) {
       rig.panBy(-64, 0);
       rig.paintOnce();
     }
     rig.cache.resetCounters();
     for (var i = 0; i < 6; i++) {
       rig.panBy(64, 0);
       rig.paintOnce();
     }
     expect(rig.cache.liveDrawCount, greaterThan(0),
@@ -268,21 +295,23 @@ void main() {
     //
     // A blank strip where a reclaimed tile used to be shows up as
     // `uncoveredPixels`, which `expectTiledEqualsLive` requires to be zero
     // over a capture that is required to have real ink in it.
     final rig = TileRig(
         tileDevicePixels: 64, tilesBakedPerFrame: 2, cacheBytes: _smallCap);
     addTearDown(rig.dispose);
 
     rig.paintOnce();
     // Twelve tiles of travel against an eight-tile ring: the long-pan fixture
-    // has to leave the retained set behind, or "reclaimed" names nothing.
+    // has to leave the retained set behind, or "reclaimed" names nothing. No
+    // `settle`: this test only pans, so `_carryOver` stays null throughout
+    // and every call below falls through unGated.
     for (var i = 0; i < 6; i++) {
       rig.panBy(-64, 0);
       rig.paintOnce();
     }
     expect(rig.cache.evictionCount, greaterThan(0),
         reason: 'setup: the pan really did overrun the cap');
     expect(rig.cache.holds(const TileKey(0, 0)), isFalse,
         reason: 'setup: and the tile the first frame baked is gone');
 
     // Every key here is inside the end camera's visible rectangle -- the
@@ -312,39 +341,58 @@ void main() {
     // **No other instrument in this plan can see a leaked `ui.Image`.** An
     // image holds native memory past its Dart object, so a path that removes a
     // tile from the map without disposing it frees nothing while every counter
     // reports success: `liveTileCount` falls, `liveBytes` falls,
     // `evictionCount` rises. Eviction is where that compounds, because it is
     // the only reclaim path that runs every frame forever.
     final rig = TileRig(
         tileDevicePixels: 64, tilesBakedPerFrame: 1000, cacheBytes: _smallCap);
     addTearDown(rig.dispose);
 
+    // No `settle`: this loop only pans, so `_carryOver` stays null throughout
+    // and every call below falls through unGated.
     for (var i = 0; i < 6; i++) {
       rig.panBy(-64, -32);
       rig.paintOnce();
       expect(rig.cache.debugImagesAlive, rig.cache.liveTileCount,
           reason: 'pan $i: every image this cache created and did not dispose '
               'is a tile it can still blit');
     }
     expect(rig.cache.evictionCount, greaterThan(0),
         reason: 'setup: images were actually reclaimed, so the equality above '
             'is a statement about a disposal that happened');
 
     // And the composite is tracked too, so the same equality keeps meaning
     // "nothing leaked" once one stands.
-    final zoomed = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
+    //
+    // **At [_capWithComposite] and not the production ceiling, since Plan 3i
+    // Task 8.** A resting frame now drops the composite before it bands, and
+    // it is licensed to do so exactly when the ceiling can hold a band plus
+    // the whole visible set -- which the production ceiling can. This one
+    // cannot (a band is 13 tiles and a covering generation 130, against 138
+    // tiles of ceiling), so the rest bake declines, the composite stands, and
+    // the budgeted tile loop fills what is left of the ceiling beside it:
+    // the state this assertion has always been about, reached at the one
+    // ceiling that still reaches it.
+    final zoomed = TileRig(
+        tileDevicePixels: 64,
+        tilesBakedPerFrame: 1000,
+        cacheBytes: _capWithComposite);
     addTearDown(zoomed.dispose);
     zoomed.paintOnce();
     zoomed.zoomBy(1.19);
     zoomed.paintOnce();
+    settle(zoomed);
     expect(zoomed.cache.hasCarryOver, isTrue, reason: 'setup');
+    expect(zoomed.cache.liveTileCount, greaterThan(0),
+        reason: 'setup: and tiles stand beside it, so the equality below is '
+            'about more than the composite alone');
     expect(zoomed.cache.debugImagesAlive, zoomed.cache.liveTileCount + 1);
 
     zoomed.cache.dispose();
     expect(zoomed.cache.debugImagesAlive, 0,
         reason: 'dispose releases every one of them');
   });
 
   test(
       'criterion 12: eviction runs with a composite standing, and never takes '
       'it', () async {
@@ -366,20 +414,21 @@ void main() {
     final covering = rig.cache.liveTileCount;
     expect(rig.cache.liveDrawCount, 0,
         reason: 'setup: the first generation covered the viewport, which is '
             'what lets it be retired into a composite rather than thrown away');
     expect(covering, greaterThan(30),
         reason: 'setup, anti-degenerate clause 3: 130 tiles, so "fewer than a '
             'covering generation" below is a real reduction');
 
     rig.zoomBy(1.19);
     rig.paintOnce();
+    settle(rig);
     expect(rig.cache.hasCarryOver, isTrue,
         reason: 'setup: the scale change minted one');
     // **Not `liveDrawCount` here.** A zoom *in* magnifies the composite past
     // the viewport's edges, so `paintFrame` takes the `carryOverCovers` early
     // return and skips the live walk entirely -- the gesture frame this cache
     // exists to make cheap. The tile count is what says the ceiling is now
     // shared; the live walk appears on the pans below, where the composite
     // has moved off the edge.
     expect(rig.cache.liveTileCount, lessThan(covering),
         reason: 'setup: the ceiling no longer admits a covering generation, '
@@ -389,20 +438,21 @@ void main() {
             'covers everywhere else.');
     expect(rig.cache.liveTileCount, greaterThan(0),
         reason: 'setup: but it does admit some, so tiles and the composite '
             'really are competing for one ceiling rather than the composite '
             'having taken all of it');
 
     final baseline = rig.cache.evictionCount;
     for (var i = 0; i < 6; i++) {
       rig.panBy(-64, -32);
       rig.paintOnce();
+      settle(rig);
       expect(rig.cache.hasCarryOver, isTrue,
           reason: 'pan $i: the composite is never a victim. The frame path '
               'reads it every frame it stands, and reclaiming it would put a '
               'blank region where stale pixels were.');
       expect(rig.cache.liveBytes, lessThanOrEqualTo(_capWithComposite),
           reason: 'pan $i');
       expect(rig.cache.liveBytes, greaterThan(_compositeBytes),
           reason: 'pan $i: and tiles are live beside it, so the ceiling is '
               'genuinely being shared rather than wholly consumed');
     }
@@ -414,63 +464,128 @@ void main() {
             'composite');
   });
 
   test(
       'criterion 12: a ceiling smaller than the composite bakes nothing '
       'rather than overrun it', () async {
     // The other half of the same policy. `_makeRoomForOneTile` returning
     // `false` rather than baking anyway is what keeps `liveBytes` a ceiling
     // and not a suggestion, and this is the only state where that arm is the
     // only thing running.
+    // **Two rigs, since Plan 3i Task 8, and the split is not a weakening.**
+    // This test used to make both of its claims over one journey, because one
+    // journey could reach a state that held a composite *and* a covering
+    // generation at once. It cannot any more: a resting frame drops the
+    // composite before it bands, licensed by the ceiling being able to hold a
+    // band plus the whole visible set, so at the production ceiling the
+    // settle below ends with 130 tiles and no composite. The composite is
+    // 117 tiles' worth against a band's 13, so no ceiling exists that admits
+    // a covering generation beside a composite but not a band beside one --
+    // the state is gone, not merely harder to reach. Each claim is therefore
+    // made where it now lives, with every number it asserted before intact.
+    //
+    // Claim one: one frame under a ceiling it cannot satisfy empties
+    // everything the blitted-this-frame guard does not protect.
     final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
     addTearDown(rig.dispose);
     rig.paintOnce();
     rig.zoomBy(1.19);
     rig.paintOnce();
-    expect(rig.cache.hasCarryOver, isTrue, reason: 'setup: a composite stands');
+    settle(rig);
     expect(rig.cache.liveTileCount, greaterThan(30),
         reason: 'setup: and there are tiles for the ceiling to take');
+    // **And no composite stands, which is chosen rather than left to
+    // chance.** Before Plan 3i Task 8 this arm asserted `isTrue` here, and
+    // that assertion was the only thing pinning the mass eviction below to
+    // running beside a standing composite. A resting frame now drops the
+    // composite before it bands, so the settle above ends with a covering
+    // generation and nothing else -- which is the right state for this claim
+    // (the eviction it measures is about the tile map alone) but has to be
+    // said, or a reader cannot tell whether the state was designed or
+    // drifted. The composite's own arm is claim two below, and the
+    // "eviction runs with a composite standing, and never takes it" test in
+    // this file covers the intersection.
+    expect(rig.cache.hasCarryOver, isFalse,
+        reason: 'setup: the settle covered the viewport, so the rest bake '
+            'released the composite -- this claim is about evicting tiles, '
+            'and it is measured with no composite in the total');
 
     // **Unreachable through the constructor**, which is why `cacheBytes` is
     // not final: a composite is minted only from a generation that covered,
     // so any ceiling that permits one is already larger than one composite.
     // Warm at a real ceiling, then take it away -- the manoeuvre the zoom
     // tests use on the bake budget, for the same reason.
     rig.cache.cacheBytes = 4 * _tileBytes;
 
     // **Two frames, and the first one is not the steady state.** Eviction is
     // asked only on a miss, so the tiles the loop had already blitted before
     // it reached one are protected by the very guard I2 is about and survive
     // the frame -- eleven of them here. The second frame pans past them and
     // the ceiling is left holding exactly what it cannot evict.
     final beforeSqueeze = rig.cache.evictionCount;
     rig.panBy(-64, -32);
     rig.paintOnce();
+    // The pan above is the moving frame the gate now inserts and it bakes
+    // and evicts nothing; `settle` below is the frame the rest of this test's
+    // comment is about.
+    settle(rig);
     // **The number `_makeRoomForOneTile`'s own doc comment cites.** One call
     // reclaims every held tile whose serial is older than this frame's, not
     // one and not one per bake -- an earlier version of that comment claimed
     // "at most one such eviction per bake" and this fixture is what falsifies
     // it. Asserted as a floor rather than as the exact 119, which would be a
     // statement about map iteration order.
     expect(rig.cache.evictionCount - beforeSqueeze, greaterThan(50),
         reason: 'a single frame under a ceiling it cannot satisfy empties '
             'everything the blitted-this-frame guard does not protect');
 
-    rig.cache.resetCounters();
-    rig.panBy(-64, -32);
-    rig.paintOnce();
-
-    expect(rig.cache.hasCarryOver, isTrue,
+    // Claim two: a ceiling smaller than the composite bakes nothing and keeps
+    // the composite. The squeeze happens on the *moving* frame after the
+    // zoom, where the composite has just been minted and the incoming
+    // generation is still empty -- the one point at which a ceiling this
+    // small can be imposed with a composite standing.
+    final squeezed = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
+    addTearDown(squeezed.dispose);
+    squeezed.paintOnce();
+    squeezed.zoomBy(1.19);
+    squeezed.paintOnce();
+    expect(squeezed.cache.hasCarryOver, isTrue,
+        reason: 'setup: a composite stands');
+    squeezed.cache.cacheBytes = 4 * _tileBytes;
+
+    squeezed.cache.resetCounters();
+    // The pan is what owes the live walk: a zoom *in* magnifies the composite
+    // past the viewport's edges and `paintFrame` skips the walk entirely, so
+    // without moving off that edge the last assertion below would read zero
+    // for a reason that has nothing to do with the ceiling.
+    squeezed.panBy(-64, -32);
+    squeezed.paintOnce();
+    settle(squeezed);
+
+    expect(squeezed.cache.hasCarryOver, isTrue,
         reason: 'the composite survives a ceiling it does not fit under: it '
             'is not in the tile map and eviction cannot reach it');
-    expect(rig.cache.liveBytes, _compositeBytes,
-        reason: 'and it is all the cache holds -- every tile went, and the '
-            'ceiling stayed a ceiling rather than being quietly exceeded');
-    expect(rig.cache.liveTileCount, 0);
-    expect(rig.cache.bakeCount, 0,
+    expect(squeezed.cache.liveBytes, _compositeBytes,
+        reason: 'and it is all the cache holds -- nothing was added beside '
+            'it, and the ceiling stayed a ceiling rather than being quietly '
+            'exceeded');
+    // **"Nothing was ever baked", not "every tile went".** The ceiling is
+    // imposed on the moving frame, where the incoming generation is already
+    // empty, so this witnesses a refusal to allocate and not a reclaim. The
+    // reclaim from a populated cache down to the composite alone is the
+    // "eviction runs with a composite standing, and never takes it" test
+    // above, which pans repeatedly under a ceiling most of which is the
+    // composite; nothing is lost by this one measuring the other half.
+    expect(squeezed.cache.liveTileCount, 0,
+        reason: 'the ceiling admitted no tile at all: not one was baked '
+            'beside the composite, which is what "bakes nothing rather than '
+            'overrun" means on a frame whose generation starts empty');
+    expect(squeezed.cache.bakeCount, 0,
         reason: 'baking under a ceiling that cannot hold the result is the '
-            'silent overrun this arm exists to refuse');
-    expect(rig.cache.liveDrawCount, 1,
+            'silent overrun this arm exists to refuse -- and the rest bake '
+            'refuses it too, band and all, rather than banding into a '
+            'ceiling that cannot keep the slices');
+    expect(squeezed.cache.liveDrawCount, 1,
         reason: 'and the live walk is what stops the frame going blank '
             'instead');
   });
 }
diff --git a/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart b/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart
new file mode 100644
index 0000000..657af33
--- /dev/null
+++ b/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart
@@ -0,0 +1,63 @@
+import 'dart:ui' as ui;
+
+import 'package:flutter/widgets.dart';
+import 'package:flutter_test/flutter_test.dart';
+import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
+
+import '../support/tile_harness.dart';
+
+void main() {
+  test('a live band image is counted in liveBytes', () {
+    final cache = TileCache(tileDevicePixels: 64);
+    addTearDown(cache.dispose);
+    final before = cache.liveBytes;
+
+    final recorder = ui.PictureRecorder();
+    Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 8, 8),
+        Paint()..color = const Color(0xFF00FF00));
+    final picture = recorder.endRecording();
+    final band = picture.toImageSync(256, 64);
+    picture.dispose();
+
+    cache.debugSetBand(band);
+    expect(cache.liveBytes, before + 256 * 64 * 4,
+        reason: 'a resident band image is 4 bytes a pixel like every other '
+            'image this cache holds, and the ceiling has to see it');
+
+    cache.debugSetBand(null);
+    expect(cache.liveBytes, before);
+    band.dispose();
+  });
+
+  testWidgets('the ceiling holds at every point inside the rest frame',
+      (t) async {
+    final h = await pumpTiled(t);
+    await settle(t, h);
+    // One tile of `pumpTiled`'s canvas: 64 device pixels square, RGBA.
+    const tileBytes = 64 * 64 * 4;
+    h.cache.debugOnSliceForTest = () {
+      expect(h.cache.liveBytes, lessThanOrEqualTo(kTileCacheBytes),
+          reason: 'the band image is resident here and the meter counts it');
+      // **The lower bound, and it is the half that has a witness.** The
+      // ceiling above is one-sided: a `paintFrame` that never assigned
+      // `_band` would leave `liveBytes` reading tiles alone, which is
+      // smaller still and satisfies it. Task 4's seam could only prove
+      // `liveBytes` counts a band handed to `debugSetBand`; this is what
+      // proves the production path puts one there. Fired as M6b.
+      expect(h.cache.liveBytes, greaterThan(h.cache.liveTileCount * tileBytes),
+          reason: 'the band image is in the total, not merely permitted by '
+              'it: a rest frame that never assigned _band would read exactly '
+              'the tile sum here');
+    };
+    addTearDown(() => h.cache.debugOnSliceForTest = null);
+
+    h.camera.zoomAt(const Offset(120, 90), 1.3);
+    await t.pump();
+    await t.pump();
+    await t.pump();
+
+    expect(h.cache.debugImagesAlive, h.cache.liveTileCount,
+        reason: 'no band image outlives its band, and the composite was '
+            'dropped before the bake');
+  });
+}
diff --git a/packages/jet_cad_2d_flutter/test/support/fixtures.dart b/packages/jet_cad_2d_flutter/test/support/fixtures.dart
index e9361ee..1d2852d 100644
--- a/packages/jet_cad_2d_flutter/test/support/fixtures.dart
+++ b/packages/jet_cad_2d_flutter/test/support/fixtures.dart
@@ -10,32 +10,33 @@ const Size kViewport = Size(800, 600);
 
 Handle addEntity(
   DraftDocument doc,
   Handle owner,
   Handle handle,
   EntityKind kind,
   List<double> coords,
   List<double> scalars, {
   DraftColor color = const ByLayerColor(),
   int transparency = 0,
+  int lineweight = 25,
 }) {
   doc.commands.execute(AddEntityCommand(
     record: EntityRecord(
       handle: handle,
       owner: owner,
       kind: kind,
       layer: ReservedHandles.layerZero,
       linetype: ReservedHandles.byLayerLinetype,
       linetypeScale: 1.0,
       geomIndex: 0,
       color: color,
-      lineweight: 25,
+      lineweight: lineweight,
       transparency: transparency,
       flags: 0,
     ),
     payload: GeometryPayload(
       coords: Float64List.fromList(coords),
       scalars: Float64List.fromList(scalars),
     ),
   ));
   return handle;
 }
@@ -141,24 +142,31 @@ DraftDocument differentialFixture(
       [ox + 30, oy + 15], const []);
 
   return doc;
 }
 
 /// Adds a line entity from ([x0], [y0]) to ([x1], [y1]), owned by [owner].
 ///
 /// [transparency] defaults to `0`, this channel's identity, so every existing
 /// caller is unaffected; a caller exercising translucency must pass a
 /// non-zero value explicitly.
+///
+/// [lineweight] is 1/100 mm on paper and defaults to the `25` every entity
+/// this file builds has always carried, so no existing fixture moves by a
+/// pixel. A caller that needs a stroke wide enough to ink across a boundary
+/// its centreline does not cross -- `bandCrossingGrid` is the one -- passes
+/// its own.
 Handle addLine(DraftDocument doc, Handle owner, Handle handle, double x0,
-        double y0, double x1, double y1, {int transparency = 0}) =>
+        double y0, double x1, double y1,
+        {int transparency = 0, int lineweight = 25}) =>
     addEntity(doc, owner, handle, EntityKind.line, [x0, y0, x1, y1], const [],
-        transparency: transparency);
+        transparency: transparency, lineweight: lineweight);
 
 /// Adds an empty block definition named [name].
 Handle addDefinition(DraftDocument doc, Handle handle, String name) {
   doc.tree.addDefinition(Definition(
       handle: handle,
       name: name,
       basePoint: Vector2.zero(),
       children: const []));
   return handle;
 }
diff --git a/packages/jet_cad_2d_flutter/test/support/tile_comparison.dart b/packages/jet_cad_2d_flutter/test/support/tile_comparison.dart
index cf24020..ed04196 100644
--- a/packages/jet_cad_2d_flutter/test/support/tile_comparison.dart
+++ b/packages/jet_cad_2d_flutter/test/support/tile_comparison.dart
@@ -15,25 +15,28 @@
 // so this instrument cannot produce an antialiased seam and a zero result here
 // is partly a property of the instrument. It proves geometric completeness:
 // no pixel missing, none drawn twice, no clipping arithmetic error. Accepted
 // gap G1 owns the rest, and mutant M3 is deferred to it. **M15 is the mutant
 // this instrument fires**, and it moves pixels software Skia renders perfectly
 // well.
 
 import 'dart:typed_data';
 import 'dart:ui';
 
+import 'package:flutter/rendering.dart';
+import 'package:flutter/widgets.dart' hide Image;
 import 'package:flutter_test/flutter_test.dart';
 import 'package:jet_cad_2d/jet_cad_2d.dart';
 import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
 
 import 'tile_fixture.dart';
+import 'tile_harness.dart';
 
 class InkReport {
   const InkReport({
     required this.liveInk,
     required this.tiledInk,
     required this.strayPixels,
     required this.uncoveredPixels,
     required this.differingPixels,
     required this.liveTriangleCount,
     required this.tiledTriangleCount,
@@ -336,21 +339,25 @@ Future<InkReport> measureFallbackAgreement(
       tileDevicePixels: 64, tilesBakedPerFrame: 1000, document: of(measurer));
   try {
     // Cover the viewport, so the strip that enters next has blitted tiles on
     // its interior side.
     rig.paintOnce();
     rig.cache.resetCounters();
     // One tile a frame, so the entering band stays uncovered and the fallback
     // owes it.
     rig.cache.bakeBudgetDevicePixels = 64 * 64;
     rig.panBy(pan.dx, pan.dy);
-
+    // No settle needed here: this fixture only pans, so no generation is
+    // ever retired and `_carryOver` stays null throughout -- the rest gate's
+    // fallback for a moving frame with nothing to fall back on keeps this
+    // call unGated, so the reduced budget below still leaves a genuine
+    // entering strip for the live fallback to own on this very call.
     final measured = await measureTiledAgreement(rig);
 
     // Anti-vacuity, and every clause of it was earned by an arrangement that
     // passed while proving nothing.
     expect(rig.cache.liveDrawCount, greaterThan(0),
         reason: 'pan $pan ran no fallback: $measured');
     expect(rig.cache.blitCount, greaterThan(0),
         reason: 'pan $pan blitted nothing, so nothing was partly baked');
     final strip = rig.cache.debugLastStrip;
     expect(strip, isNotNull, reason: 'pan $pan recorded no strip');
@@ -416,10 +423,214 @@ Future<List<InkReport>> sweepFallbackAgreement({
       reports.add(await measureFallbackAgreement(of, measurer, offset,
           minimumInk: minimumInk,
           minimumStripInk: minimumStripInk,
           checkTriangleBudget: checkTriangleBudget));
     } finally {
       measurer.clear();
     }
   }
   return reports;
 }
+
+/// The camera whose view span sits **just past a power-of-two rebase step**.
+///
+/// `rebaseOriginFor` (`camera_controller.dart`) takes the larger of the
+/// visible world box's two spans, floors its base-2 logarithm to get a step,
+/// and floors the view *centre* onto that step. A band is a fraction of the
+/// frame's height, so a `_bakeBand` that derived its own origin instead of
+/// using the one handed in would floor a different centre — and only lands on
+/// a *different* step cell when a cell boundary actually falls inside the
+/// frame. At an ordinary camera it usually does not, and the mutation is
+/// invisible; this camera is chosen so it does.
+///
+/// **The arithmetic, and how it is known to straddle.** The viewport is
+/// [kTileViewport], 400x300 logical. At the scale 3.0 below the visible world
+/// box is `400 / 3 = 133.333` by `300 / 3 = 100`, so the span is **133.333**,
+/// `floor(log2(133.333)) = 7`, and the step is **128** — the view is 1.042
+/// steps wide, so exactly one cell boundary lies inside it. The translations
+/// put the centre at
+///
+///     cx = (200 - e) / 3   = (200 + 184.5) / 3 = 128.1667
+///     cy = (f - 150) / 3   = (534.5 - 150) / 3 = 128.1667
+///
+/// which is **0.1667 world units — one device pixel — past the 128 boundary**,
+/// so the frame origin is `(128, 128)` and any band whose own centre falls
+/// below 128 takes `(128, 0)` or `(0, 128)` instead. The visible world y runs
+/// `78.167 .. 178.167`, so the 128 line is 50 world units inside it and the
+/// bands genuinely fall on both sides.
+///
+/// Both translations are whole device pixels at [kTileDpr] (`-184.5 * 2 =
+/// -369`, `534.5 * 2 = 1069`), so `quantiseCamera` leaves this camera exactly
+/// as written and the tiled and live arms see the same matrix. The visible
+/// world box, `x 61.5 .. 194.833` by `y 78.167 .. 178.167`, is strictly inside
+/// [bandCrossingGrid]'s `-52 .. 380` by `-52 .. 300` extent, so the drawing
+/// fills the viewport here rather than leaving a blank margin the comparison
+/// would pass on for free.
+ViewportTransform rebaseBoundaryCamera() => ViewportTransform(
+    worldToScreenMatrix: Transform2(3.0, 0, 0, -3.0, -184.5, 534.5));
+
+/// The [kTileViewport] at [kTileDpr], in device pixels — the size both
+/// captures come back at.
+///
+/// **Asserted rather than assumed, by every helper that takes them.** The
+/// edge sweeps below index a flat buffer as `(y * width + x) * 4`, so a
+/// capture of a different size is not a failure but a *silent* reinterpretation
+/// of the wrong quarter of the image, and the sweep goes on reporting zero.
+/// That is not hypothetical: `pumpTiled`'s `SizedBox` was inert under
+/// `pumpWidget`'s tight constraints until this task, so the canvas really was
+/// 800x600 logical and these captures really were 1600x1200.
+const int kCaptureWidth = 800;
+const int kCaptureHeight = 600;
+
+Future<ByteData> _captureBoundary(WidgetTester t) async {
+  final boundary = t.renderObject<RenderRepaintBoundary>(find.descendant(
+      of: find.byType(DraftCanvas), matching: find.byType(RepaintBoundary)));
+  late ByteData data;
+  // `toImage` is a real async rasterisation and deadlocks under the fake async
+  // zone a `testWidgets` body runs in; `runAsync` is the documented way out
+  // and is the pattern this file's `_capture` already relies on through
+  // `Picture.toImage`.
+  await t.runAsync(() async {
+    final image = await boundary.toImage(pixelRatio: kTileDpr);
+    data = (await image.toByteData())!;
+    image.dispose();
+  });
+  return data;
+}
+
+/// The tiled canvas exactly as it stands, at [kTileDpr].
+///
+/// Nothing is pumped here: a pump would give the cache another frame, and the
+/// state under test is the one the caller settled into.
+Future<ByteData> captureTiled(WidgetTester t, TiledHarness h) =>
+    _captureBoundary(t);
+
+/// The same document, index and camera, drawn with `tiles: false`.
+///
+/// **The camera is quantised and that is the rule, not a concession.**
+/// `TileCache.paintFrame` quantises once, covering the blits and the live
+/// fallback alike, so a tiled frame is internally consistent;
+/// `DraftCanvas`'s untiled branch deliberately does not (see its own comment
+/// — quantising there would move the *default* rendering path by up to half a
+/// device pixel for nothing). Handing the untiled tree the quantised camera is
+/// what makes the two captures one drawing seen twice rather than two
+/// drawings, and it is exactly what [measureTiledAgreement] does for its own
+/// live arm.
+///
+/// **This replaces the widget tree**, so the tiled cache behind [h] is
+/// disposed by the time it returns. Capture the tiled arm first — every caller
+/// here does, and Dart evaluates arguments left to right, so
+/// `differingPixels(await captureTiled(...), await captureLive(...))` is
+/// ordered correctly by the language rather than by luck.
+///
+/// **The key is the whole reason this returns a different image at all, and
+/// without it this instrument was blind to every mutant.**
+/// `_DraftCustomPainter.shouldRepaint` returns `false` unconditionally and
+/// says why — `repaint` is the only trigger, and answering `true` there would
+/// repaint on every unrelated rebuild. Pumping a tree that differs only in
+/// `tiles` therefore re-runs `didUpdateWidget` (which does tear the cache
+/// down) and then **keeps the retained picture**: the "live" capture came back
+/// byte-for-byte equal to the tiled one, and `differingPixels` read zero under
+/// M3, M7, M9, M9b, M10 and M11 alike. A key the tiled tree does not carry
+/// makes this a different element, so the render object is new and has no
+/// picture to retain.
+Future<ByteData> captureLive(WidgetTester t, TiledHarness h) async {
+  final controller = CameraController(quantiseCamera(h.camera.value, kTileDpr));
+  addTearDown(controller.dispose);
+  // The same `Center` `pumpTiled` needs, and for the same reason: without it
+  // this tree would be 800x600 logical and the two captures would be the same
+  // size as each other but not the size either arm's arithmetic assumes.
+  await t.pumpWidget(MediaQuery(
+    data: const MediaQueryData(devicePixelRatio: kTileDpr),
+    child: Directionality(
+      textDirection: TextDirection.ltr,
+      child: Center(
+          child: SizedBox(
+        width: kTileViewport.width,
+        height: kTileViewport.height,
+        child: DraftCanvas(
+          key: const ValueKey('captureLive'),
+          document: h.document,
+          index: h.index,
+          camera: controller,
+          tiles: false,
+          tileDevicePixels: 64,
+        ),
+      )),
+    ),
+  ));
+  await t.pump();
+  return _captureBoundary(t);
+}
+
+/// Pixels whose RGBA differs, over two captures of the same size.
+///
+/// Exact `==` on stored bytes, never a tolerance: these are recorded values,
+/// and a tolerance here is how a seam of one unit hides.
+int differingPixels(ByteData a, ByteData b) {
+  expect(a.lengthInBytes, b.lengthInBytes);
+  var differing = 0;
+  for (var i = 0; i < a.lengthInBytes; i += 4) {
+    if (a.getUint32(i) != b.getUint32(i)) differing++;
+  }
+  return differing;
+}
+
+bool _onEdge(int v, int tileDevicePixels) {
+  final m = v % tileDevicePixels;
+  return m == 0 || m == 1 || m == tileDevicePixels - 1;
+}
+
+/// The same comparison, restricted to the columns and rows a tile boundary
+/// falls on and the pixel either side of each.
+///
+/// A whole-frame count is dominated by tile interiors, where a seam cannot be:
+/// a slice that lost one column out of 64 moves 1.5% of the frame and reads as
+/// a small number beside a large one. This asks the question where the answer
+/// lives.
+int differingPixelsOnTileEdges(ByteData a, ByteData b,
+    {required int tileDevicePixels, required int width, required int height}) {
+  expect(a.lengthInBytes, width * height * 4,
+      reason: 'the sweep indexes rows by [width]; a capture of another size '
+          'is read as the wrong quarter of itself and still reports zero');
+  expect(b.lengthInBytes, a.lengthInBytes);
+  var differing = 0;
+  for (var y = 0; y < height; y++) {
+    for (var x = 0; x < width; x++) {
+      if (!_onEdge(x, tileDevicePixels) && !_onEdge(y, tileDevicePixels)) {
+        continue;
+      }
+      final i = (y * width + x) * 4;
+      if (a.getUint32(i) != b.getUint32(i)) differing++;
+    }
+  }
+  return differing;
+}
+
+/// Ink on those same rows and columns, so the sweep above cannot pass by
+/// having looked at background. [live] is the untiled capture.
+///
+/// **Non-transparent, not "not white", and the difference inverts the
+/// answer.** A `DraftCanvas` paints no background, so the page is
+/// `0x00000000`; layer zero's colour is white, so the *strokes* are
+/// `0xFFFFFFFF`. A predicate of `!= 0xFFFFFFFF` counts every background pixel
+/// and no drawn one — it read 11,660 where the true figure is 1,868, and it
+/// would have passed a floor of 200 on a capture with nothing in it at all.
+/// Alpha is what the rest of this file tests (`inkInside`, `measureTiled‐
+/// Agreement`) and it is what is tested here.
+int inkOnTileEdges(ByteData live,
+    {required int tileDevicePixels, required int width, required int height}) {
+  expect(live.lengthInBytes, width * height * 4,
+      reason: 'the sweep indexes rows by [width]; a capture of another size '
+          'is read as the wrong quarter of itself');
+  var ink = 0;
+  for (var y = 0; y < height; y++) {
+    for (var x = 0; x < width; x++) {
+      if (!_onEdge(x, tileDevicePixels) && !_onEdge(y, tileDevicePixels)) {
+        continue;
+      }
+      // Not the transparent page: a drawn pixel.
+      if (live.getUint8((y * width + x) * 4 + 3) != 0) ink++;
+    }
+  }
+  return ink;
+}
diff --git a/packages/jet_cad_2d_flutter/test/support/tile_fixture.dart b/packages/jet_cad_2d_flutter/test/support/tile_fixture.dart
index 1547857..7792009 100644
--- a/packages/jet_cad_2d_flutter/test/support/tile_fixture.dart
+++ b/packages/jet_cad_2d_flutter/test/support/tile_fixture.dart
@@ -322,10 +322,145 @@ DraftDocument fillingGrid(FlutterTextMeasurer measurer) {
   // (-52 + 16*22 = 300, -52 + 16*27 = 380), so the outermost line lands
   // exactly on the extent the table above measures rather than short of it.
   for (var t = -52.0; t <= 300.0; t += 16.0) {
     addLine(doc, doc.rootHandle, Handle(handle++), -52, t, 380, t);
   }
   for (var t = -52.0; t <= 380.0; t += 16.0) {
     addLine(doc, doc.rootHandle, Handle(handle++), t, -52, t, 300);
   }
   return doc;
 }
+
+/// Which side of boundary [n] its thick stroke sits on: **one stroke, not a
+/// pair**, alternating so both directions of the pad are exercised across the
+/// fixture.
+///
+/// **A stroke either side of the same boundary masks the loss it was placed to
+/// expose, and it did.** The two centrelines are 2 logical pixels apart
+/// against a 3.780 half-width, so their ink overlaps by 5.56 logical pixels
+/// and the union covers the boundary either way: the stroke centred at
+/// `32k - 1` inks `32k .. 32k + 2.780` inside band `k`, and the stroke centred
+/// at `32k + 1` -- which band `k`'s own query finds, padded or not -- inks
+/// `32k - 2.780 .. 32k + 4.780` over the top of it. Measured: with the pair in
+/// place, `const pad = 0.0` in `_bakeBand` (M9) changed **zero** pixels at
+/// [tileCamera]. With one stroke a boundary it changes thousands.
+double _sideFor(int n) => n.isOdd ? -1.0 : 1.0;
+
+/// The lineweight the band-boundary strokes in [bandCrossingGrid] carry, in
+/// 1/100 mm on paper.
+///
+/// **Chosen so the stroke is wider than its distance to the boundary, which is
+/// the whole of what M9 tests.** `CanvasDrawSink` and `VerticesDrawSink` both
+/// turn a lineweight into pixels as `hundredths / 100 * pixelsPerPaperMm`, and
+/// [kLogicalPixelsPerMm] is `96 / 25.4 = 3.7795`. At `200` that is
+/// `2.0 * 3.7795 = 7.559` logical pixels wide, so the half-width is **3.780
+/// logical pixels** — 7.559 device pixels at [kTileDpr]. A centreline placed
+/// one logical pixel outside a band's edge therefore inks 2.780 logical
+/// pixels (5.56 device rows) *inside* that band, across the band's whole
+/// width, and an unpadded band query drops every one of them.
+///
+/// The default `25` every other fixture here carries is 0.945 logical pixels
+/// wide — a half-width of 0.47, less than the one-pixel offset — so this
+/// fixture cannot be built out of it.
+const int kBandStrokeLineweight = 200;
+
+/// [fillingGrid]'s extent and spacing, plus **thick strokes centred just
+/// outside a band boundary**: the fixture the slice differential runs on.
+///
+/// **Anti-degenerate clause 2 — entities larger than one tile.** A 64
+/// device-pixel tile is 32 logical pixels at [kTileDpr]. Every horizontal line
+/// here spans world x `-52 .. 380`, which at [tileCamera]'s 1.4 scale is
+/// **604.8 logical pixels — 18.9 tiles**; every vertical spans world y
+/// `-52 .. 300`, **492.8 logical pixels, 15.4 tiles**. Crossing multiplicity
+/// is what the band design attacks (`kTileDevicePixels`' own doc comment
+/// measures it as the larger term), and a fixture of tile-sized entities would
+/// make the win invisible: no entity would ever be walked into two bands, and
+/// a slice arithmetic error would have nothing to disagree about.
+///
+/// **M9's target — a stroke whose centreline is outside the band it inks.**
+/// [tileCamera] maps world to screen as `sy = -1.4 * wy + 323`, and a band is
+/// one tile row: band `k` owns device rows `[64k, 64k + 64)`, which is logical
+/// screen y `[32k, 32k + 32)`. For each `k` in `1..9` this fixture places
+/// **one** [kBandStrokeLineweight] stroke, at logical screen y `32k - 1` for
+/// odd `k` and `32k + 1` for even `k` — one logical pixel outside a boundary,
+/// against a half-width of 3.780, so it inks 2.780 logical pixels (5.56 device
+/// rows) into the band on the far side. That entity's *bounds* do not
+/// intersect that band at all, and the painter's index query is an exact rect
+/// intersection on bounds — measured: a line 0.1 world units outside a query
+/// rect is not returned — so with `const pad = 0.0` in `_bakeBand` the band
+/// loses those rows across its full 800-device-pixel width. See [_sideFor] for
+/// why it is one stroke and not two.
+///
+/// The same is done one logical pixel outside each **column** boundary, which
+/// is not a band edge but is a tile edge: those strokes are what the per-tile
+/// `_bake` path's own pad owes, and they put ink on the columns
+/// `differingPixelsOnTileEdges` sweeps.
+///
+/// **Never (0, 0) and never the identity.** The extent, the spacing and the
+/// reasoning behind all three are [fillingGrid]'s — see its doc comment for
+/// why the drawing has to stay strictly wider than the viewport under every
+/// pan these arms take. The thick strokes are laid out by inverting
+/// [tileCamera], so their world coordinates are the far-from-origin,
+/// non-round numbers that camera implies rather than a hand-picked grid.
+DraftDocument bandCrossingGrid(FlutterTextMeasurer measurer) {
+  final doc = DraftDocument.empty(measurer: measurer);
+  var handle = 1000;
+  // [fillingGrid]'s geometry verbatim: the viewport stays interior to the
+  // drawing under every pan these arms take.
+  for (var t = -52.0; t <= 300.0; t += 16.0) {
+    addLine(doc, doc.rootHandle, Handle(handle++), -52, t, 380, t);
+  }
+  for (var t = -52.0; t <= 380.0; t += 16.0) {
+    addLine(doc, doc.rootHandle, Handle(handle++), t, -52, t, 300);
+  }
+
+  // [tileCamera] inverted. Written as the inverse rather than as literals so
+  // the strokes track the camera if it ever moves, instead of silently
+  // drifting off the boundaries they exist to straddle.
+  double worldY(double screenY) => (323.0 - screenY) / 1.4;
+  double worldX(double screenX) => (screenX + 37.0) / 1.4;
+
+  // Rows 1..9. Row 0's top edge is the viewport's own edge and row 10 is
+  // past the bottom of a 600 device-pixel viewport, so neither is a band
+  // boundary with a band on both sides of it.
+  for (var row = 1; row <= 9; row++) {
+    final y = worldY(row * 32.0 + _sideFor(row));
+    addLine(doc, doc.rootHandle, Handle(handle++), -52, y, 380, y,
+        lineweight: kBandStrokeLineweight);
+  }
+  // Columns 1..12 at 32 logical pixels: the last tile column starts at device
+  // x 768 and the viewport is 800 wide, so column 12's own left edge is the
+  // final one inside it.
+  for (var col = 1; col <= 12; col++) {
+    final x = worldX(col * 32.0 + _sideFor(col));
+    addLine(doc, doc.rootHandle, Handle(handle++), x, -52, x, 300,
+        lineweight: kBandStrokeLineweight);
+  }
+
+  // [kMovableHandle]'s resting position, for Task 10's edit-after-a-settle
+  // test. A group, not a bare leaf: `TransformNodeCommand` only accepts a
+  // node handle (`commands.dart:292`, `target.tree[handle]`), and only a
+  // group or an instance is one.
+  //
+  // Screen (80, 144), through the same inversion as the boundary strokes
+  // above: tile column 2 spans device x [128, 192) -- logical [64, 96) -- and
+  // row 4 spans device y [256, 320) -- logical [128, 160). 80 and 144 sit 16
+  // and 16 logical pixels inside those ranges respectively, comfortably clear
+  // of [kTileSlack]'s one-tile ring. The leaf's local (0, 0)-(6, 6) diagonal
+  // moves the far endpoint to screen (88.4, 135.6) -- still inside the same
+  // tile -- so the whole entity rests in one place:
+  // [TiledHarness.moveOneEntityOntoDisjointTiles] moves it to tile column 9,
+  // row 1, seven columns and three rows clear.
+  addGroup(doc, doc.rootHandle, kMovableHandle,
+      Transform2(1, 0, 0, 1, worldX(80), worldY(144)));
+  addLine(doc, kMovableHandle, Handle(handle++), 0, 0, 6, 6);
+  return doc;
+}
+
+/// The node [TiledHarness.moveOneEntityOntoDisjointTiles] moves, and
+/// [bandCrossingGrid]'s doc comment for its resting position and the
+/// arithmetic behind the move.
+///
+/// A [GroupNode] handle, deliberately: `TransformNodeCommand.apply`
+/// (`commands.dart:292-300`) accepts only a node already in
+/// `DraftDocument.tree`, and a leaf entity is not one.
+const Handle kMovableHandle = Handle(1100);
diff --git a/packages/jet_cad_2d_flutter/test/support/tile_harness.dart b/packages/jet_cad_2d_flutter/test/support/tile_harness.dart
new file mode 100644
index 0000000..a6da311
--- /dev/null
+++ b/packages/jet_cad_2d_flutter/test/support/tile_harness.dart
@@ -0,0 +1,203 @@
+// One tiled `DraftCanvas`, pumped, plus the two things every tiled-frame test
+// does with it: drive it to rest, and read the cache behind it.
+//
+// These lived in `tile_regime_test.dart` until Plan 3i Task 8, which needed
+// them from two more files. Moving rather than copying is the point: a second
+// copy of `settle` would be a second bound to keep in step with
+// [kRestGateFrames].
+
+import 'package:flutter/widgets.dart';
+import 'package:flutter_test/flutter_test.dart';
+import 'package:jet_cad_2d/jet_cad_2d.dart';
+import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
+
+import 'tile_fixture.dart';
+
+/// Everything a tiled-frame test needs to drive and read one canvas.
+class TiledHarness {
+  TiledHarness(this.cache, this.camera, this.document, this.index);
+  final TileCache cache;
+  final CameraController camera;
+  final DraftDocument document;
+
+  /// The index the tiled canvas was built over.
+  ///
+  /// Held so a second canvas can be pumped over the **same** document and the
+  /// same index — which is what `captureLive` does. Rebuilding the index
+  /// there would compare two frames drawn from two different trees, and a
+  /// query-order difference between them would read as a tiling defect.
+  final SpatialIndex index;
+
+  /// Moves [kMovableHandle] onto tiles it did not occupy, for Task 10's
+  /// edit-after-a-settle test.
+  ///
+  /// **Onto disjoint tiles, not merely somewhere else.** An edit that extends
+  /// a line rather than moving it makes the new tile set a superset of the
+  /// old one, and then "the old position was condemned" is true of an
+  /// implementation that condemns nothing -- the trap
+  /// `tile_invalidation_test.dart` documents at its own head.
+  ///
+  /// `TransformNodeCommand` **replaces** the node's transform rather than
+  /// composing with it, so the destination below is an absolute world point,
+  /// not an offset from wherever [kMovableHandle] happens to rest. Screen
+  /// (300, 48), through [tileCamera]'s own inversion (`sx = 1.4 wx - 37`,
+  /// `sy = -1.4 wy + 323`): tile column 9 spans device x [576, 640) -- logical
+  /// [288, 320) -- and row 1 spans device y [64, 128) -- logical [32, 64).
+  /// [bandCrossingGrid]'s doc comment places [kMovableHandle]'s resting
+  /// position at tile column 2, row 4 -- seven columns and three rows clear
+  /// of this destination, far outside [kTileSlack]'s one-tile ring, so the
+  /// two tile sets are disjoint by construction and the test only has to
+  /// confirm it.
+  void moveOneEntityOntoDisjointTiles() {
+    double worldX(double screenX) => (screenX + 37.0) / 1.4;
+    double worldY(double screenY) => (323.0 - screenY) / 1.4;
+    document.commands.execute(TransformNodeCommand(
+        kMovableHandle, Transform2(1, 0, 0, 1, worldX(300), worldY(48))));
+  }
+}
+
+/// Pumps a tiled canvas over `fillingGrid`, which inks every tile of
+/// [kTileViewport] at [tileCamera] -- so "nothing was drawn" can never be
+/// mistaken for "there was nothing to draw".
+Future<TiledHarness> pumpTiled(
+  WidgetTester t, {
+  DraftDocument Function(FlutterTextMeasurer)? document,
+  ViewportTransform? camera,
+}) async {
+  final measurer = FlutterTextMeasurer();
+  addTearDown(measurer.clear);
+  final doc = (document ?? fillingGrid)(measurer);
+  final index = SpatialIndex(doc);
+  addTearDown(index.dispose);
+  final controller = CameraController(camera ?? tileCamera());
+  addTearDown(controller.dispose);
+
+  // **The `Center` is load-bearing and was missing.** `pumpWidget` hands its
+  // child the surface's *tight* constraints (800x600 logical), and a
+  // `SizedBox` under tight constraints is inert -- `additionalConstraints
+  // .enforce(constraints)` gives the incoming tight box back unchanged. So
+  // this canvas was 800x600 logical, not [kTileViewport]: 1600x1200 device
+  // pixels, 25 x 19 = 475 tiles, and `fillingGrid` -- whose extent is derived
+  // in its own doc comment against a 400x300 viewport, and which reaches only
+  // screen x -109.8..495 at [tileCamera] -- left the right-hand 38% of every
+  // frame blank. `Center` passes loose constraints, so the box takes the size
+  // it asks for and the harness is the viewport it documents. Measured before
+  // and after: 475 tiles and a 1600x1200 capture became 130 and 800x600.
+  await t.pumpWidget(MediaQuery(
+    data: const MediaQueryData(devicePixelRatio: kTileDpr),
+    child: Directionality(
+      textDirection: TextDirection.ltr,
+      child: Center(
+          child: SizedBox(
+        width: kTileViewport.width,
+        height: kTileViewport.height,
+        child: DraftCanvas(
+          document: doc,
+          index: index,
+          camera: controller,
+          tiles: true,
+          tileDevicePixels: 64,
+        ),
+      )),
+    ),
+  ));
+  await t.pump();
+  final state = t.state<DraftCanvasState>(find.byType(DraftCanvas));
+  return TiledHarness(state.tileCache!, controller, doc, index);
+}
+
+/// Pumps until the canvas stops asking for frames, bounded.
+///
+/// The bound is not decoration: an implementation that asks forever would
+/// otherwise hang the suite instead of failing it.
+Future<void> settle(WidgetTester t, TiledHarness h) async {
+  for (var i = 0; i < 40 && t.binding.hasScheduledFrame; i++) {
+    await t.pump();
+  }
+  expect(t.binding.hasScheduledFrame, isFalse,
+      reason: 'the settle must terminate');
+}
+
+/// Drives [h] to a rest whose **every** visible tile was cut out of a band,
+/// and returns how many were.
+///
+/// **[settle] alone does not reach that state, and every slice-path mutant
+/// would be judged on two tiles if this did not exist.** `paintFrame` bakes up
+/// to `budgetedTilesPerFrame` tiles a frame through the per-tile `_bake` path
+/// — `262144 / (64 * 64) = 64` at this harness's tile size — and the rest gate
+/// needs two consecutive unchanged cameras before `_restBake` runs at all. A
+/// 400x300 logical viewport at [kTileDpr] is 800x600 device pixels, 13 x 10 =
+/// **130 tiles**, so the first two frames bake 128 of them and the rest frame
+/// finds two keys missing. `_restBake` skips every key `_tiles` already
+/// serves, so the band path would own 2 tiles of 130 — in the bottom-right
+/// corner, 24 device rows tall — and `sliceSourceRect`, the band pad and the
+/// band origin would all be measured there or nowhere.
+///
+/// **A table edit is what puts the whole viewport back in the band's hands at
+/// the same camera.** `paintFrame` reads `tables.mutationRevision` every frame
+/// and calls `_dropGeneration` when it moves; that drops the tiles and the
+/// composite and **keeps the lattice and the anchor** ("the tiles go and the
+/// lattice stays"). The camera has not moved, so `_restGateSteps` keeps its
+/// count and the very next frame is a rest frame over an empty generation:
+/// one band per tile row, 130 slices, at exactly the camera the fixture was
+/// laid out against. A zoom would reach the same state but would move the
+/// camera, and [bandCrossingGrid]'s strokes are placed against [tileCamera]'s
+/// band boundaries specifically.
+///
+/// The layer added is referenced by nothing, so not one pixel changes with it:
+/// the drop is the whole point of the edit.
+Future<int> settleFromBands(WidgetTester t, TiledHarness h) async {
+  await settle(t, h);
+  var slices = 0;
+  h.cache.debugOnSliceForTest = () => slices++;
+  addTearDown(() => h.cache.debugOnSliceForTest = null);
+  h.document.tables.layers.add(const LayerRecord(
+    handle: Handle(900),
+    name: 'BAND-DROP',
+    color: IndexedColor(3),
+    linetype: ReservedHandles.continuousLinetype,
+    lineweight: 50,
+    transparency: 0,
+  ));
+  await t.pump();
+  await settle(t, h);
+  h.cache.debugOnSliceForTest = null;
+  // Pinned to equality, not merely non-zero: this helper's own doc comment
+  // promises **every** visible tile was cut out of a band, and a rest bake
+  // that filled some tiles through the band path and backfilled the rest
+  // through the ordinary per-tile `_bake` would satisfy `greaterThan(0)`
+  // while breaking that promise. Measured on this harness: `slices ==
+  // liveTileCount == 130`.
+  expect(slices, equals(h.cache.liveTileCount),
+      reason: 'every visible tile must have been cut from a band -- a '
+          'partial band bake backfilled through the ordinary per-tile path '
+          'must not pass as a band settle');
+  expect(h.cache.viewportCovered, isTrue,
+      reason: 'the rest bake must have refilled the generation it dropped');
+  return slices;
+}
+
+/// One more painted frame at the camera [h] already has.
+///
+/// **The frame a rest bake after a *scale change* leaves on screen is not a
+/// clean generation, and this is the same allowance `tile_cache_test`'s
+/// `criterion 1: a settled frame equals the live frame after a zoom` makes by
+/// painting a fifth frame.** `paintFrame` blits the outgoing composite first
+/// and underneath everything, before it decides the frame is resting;
+/// `_restBake` then calls `_dropCarryOver`, which frees the composite for
+/// every *later* frame but cannot un-draw the blit this one already made. So
+/// the settled frame carries stale, magnified ink wherever the incoming tiles
+/// are transparent — 67,509 differing pixels of it on this task's arm 3 — and
+/// the first frame that is a statement about the new generation alone is the
+/// one after. Nothing schedules that frame: `viewportCovered` is true, so the
+/// canvas stops asking.
+///
+/// A zero pan rather than a real one: [ViewportTransform] declares no `==`, so
+/// a fresh instance always notifies, and the camera it notifies with is
+/// numerically the one already on screen — no key moves, no tile is rebaked,
+/// and `_restBake` returns at its "nothing missing" guard.
+Future<void> repaintOnce(WidgetTester t, TiledHarness h) async {
+  h.camera.panBy(Offset.zero);
+  await t.pump();
+  await settle(t, h);
+}
diff --git a/packages/jet_cad_2d_flutter/test/tile_band_test.dart b/packages/jet_cad_2d_flutter/test/tile_band_test.dart
new file mode 100644
index 0000000..b33263a
--- /dev/null
+++ b/packages/jet_cad_2d_flutter/test/tile_band_test.dart
@@ -0,0 +1,279 @@
+import 'dart:ui';
+
+import 'package:flutter_test/flutter_test.dart';
+import 'package:jet_cad_2d/jet_cad_2d.dart';
+import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
+import 'package:vector_math/vector_math_64.dart' show Vector2;
+
+import 'support/tile_fixture.dart';
+
+/// A painter that records what the band bake handed it and draws nothing.
+///
+/// **Nothing is drawn on purpose.** What this task decides is arithmetic --
+/// which camera, which viewport size, which rebase origin -- and every one of
+/// those is visible at the moment [paint] is entered. Rasterising the fixture
+/// as well would only make the answer arrive through a pixel comparison that
+/// the later differential task owns and that this task cannot yet run.
+class _RecordingPainter extends DraftPainter {
+  _RecordingPainter(DraftDocument document, SpatialIndex index)
+      : super(
+            document: document,
+            index: index,
+            resolver: DocumentStyleResolver(document));
+
+  ViewportTransform? seenCamera;
+  Size? seenViewport;
+  Vector2? seenOrigin;
+  int paints = 0;
+
+  @override
+  void paint(DrawSink sink, ViewportTransform camera, Size viewport) {
+    paints++;
+    seenCamera = camera;
+    seenViewport = viewport;
+    // Read here rather than after the call: `_drawInto` clears it in a
+    // `finally`, so a test that looked afterwards would always see null and
+    // could never tell a passed-through origin from a dropped one.
+    seenOrigin = debugRebaseOrigin;
+  }
+}
+
+void main() {
+  TileGrid gridAt(ViewportTransform camera) => TileGrid(
+      anchor: camera, devicePixelRatio: kTileDpr, tileDevicePixels: 64);
+
+  test('the bands partition the visible keys, in row order, without gaps', () {
+    final camera = quantiseCamera(tileCamera(), kTileDpr);
+    final grid = gridAt(camera);
+    final bands = grid.bandsFor(camera, kTileViewport);
+    final fromBands = bands.expand((b) => b.keys).toList();
+    final visible = grid.visibleKeys(camera, kTileViewport).toList();
+
+    expect(fromBands.toSet(), visible.toSet(),
+        reason: 'every visible key belongs to exactly one band');
+    expect(fromBands.length, visible.length, reason: 'and to only one');
+    for (var i = 1; i < bands.length; i++) {
+      expect(bands[i].row, bands[i - 1].row + 1,
+          reason: 'rows are contiguous and ascending');
+      expect(bands[i].deviceRect.top, bands[i - 1].deviceRect.bottom,
+          reason: 'and the bands touch without gap or overlap');
+    }
+  });
+
+  test('a band is one tile tall and the full union width', () {
+    final camera = quantiseCamera(tileCamera(), kTileDpr);
+    final bands = gridAt(camera).bandsFor(camera, kTileViewport);
+    for (final band in bands) {
+      expect(band.deviceRect.height, 64.0);
+      expect(band.deviceRect.width, band.keys.length * 64.0);
+    }
+  });
+
+  // The overhang is the point. `visibleKeys` yields every key the viewport
+  // touches, including keys that extend past it, and a source sized to the
+  // viewport has no pixels for those. This is M7's territory.
+  test('the union overhangs the viewport, and the bands carry the overhang',
+      () {
+    final camera = quantiseCamera(tileCamera(), kTileDpr);
+    final bands = gridAt(camera).bandsFor(camera, kTileViewport);
+    final union =
+        bands.map((b) => b.deviceRect).reduce((a, b) => a.expandToInclude(b));
+    final device = Rect.fromLTWH(
+        0, 0, kTileViewport.width * kTileDpr, kTileViewport.height * kTileDpr);
+    expect(union.contains(device.topLeft), isTrue);
+    expect(union.right, greaterThanOrEqualTo(device.right));
+    expect(union.bottom, greaterThanOrEqualTo(device.bottom));
+  });
+
+  // The band bake's own arithmetic, checked without rasterising anything.
+  //
+  // **The fixture is deliberately off both axes and off the anchor.** The grid
+  // is anchored at the resting camera and the frame camera is then panned a
+  // whole number of device pixels away from it, so the visible key range
+  // starts at x = 1 rather than 0 and a band from a lower row has a non-zero
+  // `deviceRect.top` as well as a non-zero `left`. A band at (0, 0) under an
+  // anchor that equals the frame camera proves none of what follows.
+  group('the band bake', () {
+    // -50 logical at dpr 2 is exactly -100 device pixels, so the pan keeps
+    // the grid's whole-device-pixel invariant and `deviceDeltaFrom` stays
+    // integral.
+    const panX = -50.0;
+    const panY = -30.0;
+    const pad = kTileSlack;
+
+    late TileRig rig;
+    late ViewportTransform anchor;
+    late ViewportTransform frame;
+    late TileGrid grid;
+    late List<TileBand> bands;
+    late TileBand band;
+
+    setUp(() {
+      rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
+      anchor = quantiseCamera(tileCamera(), kTileDpr);
+      final m = anchor.worldToScreenMatrix;
+      frame = quantiseCamera(
+          ViewportTransform(
+              worldToScreenMatrix:
+                  Transform2(m.a, m.b, m.c, m.d, m.e + panX, m.f + panY)),
+          kTileDpr);
+      grid = TileGrid(
+          anchor: anchor, devicePixelRatio: kTileDpr, tileDevicePixels: 64);
+      bands = grid.bandsFor(frame, kTileViewport);
+      // A lower row, so neither offset is zero.
+      band = bands[3];
+    });
+
+    tearDown(() => rig.dispose());
+
+    test('the fixture puts the band off both axes and off the anchor', () {
+      expect(band.deviceRect.left, isNot(0.0));
+      expect(band.deviceRect.top, isNot(0.0));
+      expect(frame.worldToScreenMatrix.e,
+          isNot(closeTo(anchor.worldToScreenMatrix.e, 1e-9)),
+          reason: 'the frame camera must differ from the anchor, or the '
+              'anchor-versus-frame choice below is untestable');
+      expect(frame.worldToScreenMatrix.f,
+          isNot(closeTo(anchor.worldToScreenMatrix.f, 1e-9)));
+    });
+
+    test('the band camera puts a world point at the band-local pixel', () {
+      // Not the origin and not a grid node: a point whose screen position is
+      // fractional in both axes.
+      final point = Vector2(123.5, 77.25);
+      final painter = _RecordingPainter(rig.doc, rig.index);
+      final visited = <int>[];
+
+      final image = rig.cache.debugBakeBand(
+          band, grid, frame, painter, rig.sink, null, Vector2.zero(), visited);
+      addTearDown(image.dispose);
+
+      expect(painter.paints, 1);
+      final bandCamera = painter.seenCamera!;
+
+      // The band's rectangle is in the grid's device space, so the reference
+      // is where the *anchor* puts the point, not where this frame's camera
+      // does. The two differ by the pan above, which is what makes this an
+      // assertion rather than a tautology.
+      final inAnchor = anchor.worldToScreen(point);
+      final expected = Vector2(
+        inAnchor.x - band.deviceRect.left / kTileDpr + pad,
+        inAnchor.y - band.deviceRect.top / kTileDpr + pad,
+      );
+      final actual = bandCamera.worldToScreen(point);
+
+      expect(actual.x, closeTo(expected.x, 1e-9));
+      expect(actual.y, closeTo(expected.y, 1e-9));
+
+      // The mutation this pins: reading the translation off the frame camera
+      // instead of the anchor. It is a different number here by construction.
+      final fromFrame = frame.worldToScreen(point);
+      expect(
+          actual.x,
+          isNot(closeTo(
+              fromFrame.x - band.deviceRect.left / kTileDpr + pad, 1e-6)),
+          reason: 'the band camera must be anchored where the tile keys are');
+
+      // Scale and skew are the generation's and are carried untouched.
+      final a = anchor.worldToScreenMatrix;
+      final b = bandCamera.worldToScreenMatrix;
+      expect(b.a, a.a);
+      expect(b.b, a.b);
+      expect(b.c, a.c);
+      expect(b.d, a.d);
+    });
+
+    test('the padded query reaches kTileSlack past the band on every side', () {
+      final painter = _RecordingPainter(rig.doc, rig.index);
+      final image = rig.cache.debugBakeBand(
+          band, grid, frame, painter, rig.sink, null, Vector2.zero(), <int>[]);
+      addTearDown(image.dispose);
+
+      final width = band.deviceRect.width / kTileDpr;
+      final height = band.deviceRect.height / kTileDpr;
+      expect(width, greaterThan(0));
+      expect(height, greaterThan(0));
+      expect(painter.seenViewport, Size(width + 2 * pad, height + 2 * pad),
+          reason: 'an unpadded query drops the half of a boundary stroke that '
+              'belongs to the band, because its centreline is outside it');
+
+      // The pad is only reach if the camera moves with it: a larger viewport
+      // whose origin did not shift would query the same rectangle grown to
+      // the right and down alone.
+      final b = painter.seenCamera!.worldToScreenMatrix;
+      final a = anchor.worldToScreenMatrix;
+      expect(b.e, closeTo(a.e - band.deviceRect.left / kTileDpr + pad, 1e-9));
+      expect(b.f, closeTo(a.f - band.deviceRect.top / kTileDpr + pad, 1e-9));
+
+      // And the image is the band, not the padded query.
+      expect(image.width, band.deviceRect.width.round());
+      expect(image.height, band.deviceRect.height.round());
+    });
+
+    test('every band is rebased against the origin handed in', () {
+      // Far from zero, so a band-derived origin could not coincide with it.
+      final origin = Vector2(4500000.0, -3100000.0);
+      final seen = <Vector2?>[];
+      for (final each in [bands.first, bands[3], bands.last]) {
+        final painter = _RecordingPainter(rig.doc, rig.index);
+        final image = rig.cache.debugBakeBand(
+            each, grid, frame, painter, rig.sink, null, origin, <int>[]);
+        addTearDown(image.dispose);
+        seen.add(painter.seenOrigin);
+      }
+      expect(seen, everyElement(same(origin)),
+          reason: 'a per-band origin gives each band its own float32 residual '
+              'and the rows disagree along their shared edge');
+    });
+
+    test('a slice rectangle is band-local and integral', () {
+      for (final key in band.keys) {
+        final src = grid.sliceSourceRect(band, key);
+        expect(src.left, greaterThanOrEqualTo(0.0),
+            reason: 'band-local, so never negative however the keys are '
+                'numbered -- a same-scale pan takes key.x negative');
+        expect(src.top, 0.0);
+        expect(src.width, 64.0);
+        expect(src.height, 64.0);
+        expect(src.left, src.left.roundToDouble(),
+            reason: 'integral by construction: `deviceDeltaFrom` rounds, '
+                'and a tile side is `tileDevicePixels` exactly');
+      }
+      expect(grid.sliceSourceRect(band, band.keys.first).left, 0.0);
+
+      // Necessary but weak on its own: `band.deviceRect.left` is *defined*
+      // as `band.keys.first.x * tileDevicePixels` (see `TileGrid.bandsFor`),
+      // so a grid-space implementation -- reading `key.x * tileDevicePixels`
+      // with no subtraction -- would give the same 0 for the first key
+      // whenever a band happens to start at grid column 0. This fixture's
+      // pan already puts `band.keys.first.x` at 1, so that assertion alone
+      // already catches it here; the next one is the general form and keeps
+      // catching it even against a fixture where the first key does not,
+      // because it pins the spacing between two consecutive keys rather than
+      // a single boundary value.
+      expect(band.keys.length, greaterThanOrEqualTo(2),
+          reason: 'a second key is required below, or this test is vacuous');
+      expect(grid.sliceSourceRect(band, band.keys[1]).left, 64.0,
+          reason: 'band-local: exactly one tile width in from the first key, '
+              'whatever grid column the band starts at -- a grid-space '
+              'implementation reads key.x * tileDevicePixels here and gets '
+              '128.0 instead');
+    });
+
+    test('the walk reports the handles it touched into visitedInto', () {
+      // The real painter here, not the recorder: this is the one claim that
+      // needs the walk to actually happen.
+      final visited = <int>[];
+      final image = rig.cache.debugBakeBand(band, grid, frame, rig.painter,
+          rig.sink, null, Vector2.zero(), visited);
+      addTearDown(image.dispose);
+      expect(visited, isNotEmpty);
+      expect(
+          visited.toSet().every((v) =>
+              rig.doc.tree[Handle(v)] != null ||
+              rig.doc.entities.slotOf(Handle(v)) != null),
+          isTrue,
+          reason: 'every recorded handle names something in the document');
+    });
+  });
+}
diff --git a/packages/jet_cad_2d_flutter/test/tile_cache_test.dart b/packages/jet_cad_2d_flutter/test/tile_cache_test.dart
index 4062b02..5953b74 100644
--- a/packages/jet_cad_2d_flutter/test/tile_cache_test.dart
+++ b/packages/jet_cad_2d_flutter/test/tile_cache_test.dart
@@ -190,44 +190,61 @@ void main() {
     // once a composite stands, where a frame legitimately hands
     // `drawImageRect` two different objects. Asserted only over the first
     // phase, the criterion would have gone on reading as "one Paint, always",
     // and a mutation that built the composite's `Paint` at the call site would
     // have had nowhere to be caught. Found by asking the file which tests
     // exclude the state their comment is about; see the fix round in the
     // report.
     final zoomed = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
     addTearDown(zoomed.dispose);
     zoomed.paintOnce();
-    // Four, not zero: the frame under the spy must contain *both* kinds of
-    // blit, or the two-object claim is made over one object again. Four
-    // *tiles*, at this rig's 64 px tile: the field is a device-pixel budget.
+    // A crippled budget, kept from the pre-Plan-3i version of this test and
+    // now inert on the frame under the spy: Task 8's rest bake fills the
+    // viewport in bands and the band bake is not rationed by
+    // `bakeBudgetDevicePixels` at all. It stays because it still rations the
+    // two frames *before* the spy's, which is what keeps them from covering
+    // early and retiring the composite out from under the assertion below.
     zoomed.cache.bakeBudgetDevicePixels = 4 * 64 * 64;
     zoomed.zoomBy(1.19);
+    // The gate's moving frame: it retires the old generation into a
+    // composite and bakes nothing of the new one. Then one more unchanged
+    // camera, which kRestGateFrames now requires before a frame may bake --
+    // one used to be enough, so this used to be the settled frame itself; it
+    // still only blits the composite. The spy call below is the frame after
+    // it -- the one kRestGateFrames now arms -- and needs both kinds of
+    // blit in the same frame.
+    zoomed.paintOnce();
+    zoomed.paintOnce();
     zoomed.cache.resetCounters();
     final zoomedSpy = SpyCanvas();
     zoomed.cache.paintFrame(
       canvas: zoomedSpy,
       viewport: kTileViewport,
       devicePixelRatio: kTileDpr,
       camera: zoomed.camera,
       painter: zoomed.painter,
       sink: zoomed.sink,
       vertices: zoomed.vertices,
       tablesRevision: zoomed.doc.tables.mutationRevision,
     );
 
     expect(zoomed.cache.carryOverBlitCount, 1);
-    expect(zoomed.cache.blitCount, 4);
+    // 130, not the four the budget used to allow: the rest frame bands the
+    // whole visible set in one go. The composite is blitted first and dropped
+    // inside the same frame, so both kinds of blit are still here -- which is
+    // the only property this test is about, and it is now made over a larger
+    // set of tile blits rather than a smaller one.
+    expect(zoomed.cache.blitCount, 130);
     final zoomedCalls = zoomedSpy.named('drawImageRect').toList();
-    expect(zoomedCalls.length, 5,
-        reason: 'one composite and four tiles: the state is real, not a '
-            'second cold frame under another name');
+    expect(zoomedCalls.length, 131,
+        reason: 'one composite and the whole visible set: the state is real, '
+            'not a second cold frame under another name');
     final zoomedPaints =
         zoomedCalls.map((c) => c.args.whereType<Paint>().single).toList();
     expect(
         identical(zoomedPaints.first, zoomed.cache.debugCarryOverPaint), isTrue,
         reason: 'the composite goes first and with its own field, so an '
             'incoming tile and a live walk both composite on top of it');
     for (final paint in zoomedPaints.skip(1)) {
       expect(identical(paint, zoomed.cache.debugBlitPaint), isTrue,
           reason: 'and every tile blit still gets the one tile Paint');
     }
@@ -548,43 +565,69 @@ void main() {
         reason: 'the new generation holds nothing, so the ink below cannot '
             'have come from a tile');
     expect(rig.cache.liveDrawCount, 0,
         reason: 'and no live walk ran, so it cannot have come from the '
             'painter either');
     expect(gestureInk, greaterThan(5000),
         reason: 'the composite must actually reach the canvas: $gestureInk '
             'against a warm $warmInk');
   });
 
-  test('the settle spreads its bakes across frames', () async {
+  test('the settle spreads its bakes across frames, until it rests', () async {
     final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 4);
     addTearDown(rig.dispose);
     rig.paintOnce();
     rig.zoomBy(1.03);
+    // No moving-frame absorber needed: generation one never covered the
+    // viewport at a budget of four, so `_retireGeneration` never minted a
+    // composite from it -- the very first call below has no composite to
+    // fall back on and falls through to the ordinary bake path unGated,
+    // exactly like the one after it.
+    //
+    // **Two frames and not three, because the third one is no longer a
+    // budgeted frame.** `kRestGateFrames` is two, so the third call at this
+    // unchanged camera is the *resting* frame Plan 3i Task 8 added, and a
+    // resting frame does not ration: it bands the whole visible region in
+    // one go, which is the entire point of that plan. The ration itself is
+    // unchanged -- still four tiles per frame -- and the two frames below are
+    // where it is still the thing that decides. The third frame is asserted
+    // separately underneath, because "the budget throttles" and "the rest
+    // frame finishes" are now two different claims and a single loop over
+    // three frames could no longer distinguish them.
     rig.cache.resetCounters();
-    // Settled: the scale stops moving, so the new generation fills in.
-    for (var i = 0; i < 3; i++) {
+    for (var i = 0; i < 2; i++) {
       rig.paintOnce();
     }
-    expect(rig.cache.bakeCount, 12, reason: 'four per frame, three frames');
-    expect(rig.cache.liveTileCount, 12,
-        reason: 'and every bake was kept, so 12 is a throttle rather than a '
-            'recount of four tiles rebaked three times');
+    expect(rig.cache.bakeCount, 8, reason: 'four per frame, two frames');
+    expect(rig.cache.liveTileCount, 8,
+        reason: 'and every bake was kept, so 8 is a throttle rather than a '
+            'recount of four tiles rebaked twice');
     expect(rig.cache.hasCarryOver, isFalse,
         reason: 'and no composite stands: generation one never covered the '
             'viewport at a budget of four, so nothing was minted -- which is '
             'what makes the live-draw count below a statement about coverage '
             'rather than about suppression');
-    expect(rig.cache.liveDrawCount, 3,
-        reason: 'anti-vacuity: all three frames still left ink uncovered, so '
-            'the visible set is larger than 12 and the budget is what bounded '
+    expect(rig.cache.liveDrawCount, 2,
+        reason: 'anti-vacuity: both frames still left ink uncovered, so '
+            'the visible set is larger than 8 and the budget is what bounded '
             'the count');
+
+    // And the frame the gate now arms finishes the fill on its own, from the
+    // eight tiles the ration left it -- the behaviour the two assertions
+    // above would otherwise read as a regression.
+    rig.paintOnce();
+    expect(rig.cache.viewportCovered, isTrue,
+        reason: 'the resting frame bands the rest of the viewport in one '
+            'frame rather than four more tiles of it');
+    expect(rig.cache.liveTileCount, greaterThan(8),
+        reason: 'and it kept what it cut, so the coverage above is tiles and '
+            'not a live walk');
   });
 
   test('criterion 1: a settled frame equals the live frame after a zoom',
       () async {
     // **The zoom half of criterion 1, and the camera was the degenerate
     // fixture.** Every criterion 1 case before this one runs at the rig's one
     // scale of 1.4 -- a pan cannot change a scale -- so nothing in this plan
     // had ever asked whether a *different* scale tiles exactly.
     //
     // It does, at all forty-one factors swept from 0.70 to 1.50 in steps of
@@ -593,27 +636,35 @@ void main() {
     // here no longer excludes anything: **1.22 and 1.10 are two of the six**,
     // and they are in it deliberately. These are a criterion-1 claim rather
     // than a demonstration -- mutant M4 reddens every one of them, because a
     // generation replayed at the old scale carries the old stroke widths and
     // the old dash phase and no pan test can see either.
     for (final factor in <double>[0.74, 0.83, 1.10, 1.16, 1.22, 1.30]) {
       final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 1000);
       addTearDown(rig.dispose);
       rig.paintOnce();
       rig.zoomBy(factor);
-      // Two frames. The first anchors the new generation and fills it, with
-      // the composite blitted underneath; the second bakes nothing, finds the
-      // viewport covered, and retires the composite. Only the third frame --
+      // Four frames now, the first two of them new: the gate's moving frame,
+      // which retires the old (covered) generation into a composite and
+      // bakes nothing, and the frame after it, which the Task 3 threshold
+      // still counts as not-yet-rested -- one unchanged camera used to be
+      // enough, kRestGateFrames now asks for two, so this second frame also
+      // bakes nothing and only blits the composite. Of the two after that,
+      // the first anchors the new generation and fills it, with the
+      // composite blitted underneath; the second bakes nothing, finds the
+      // viewport covered, and retires the composite. Only the fifth frame --
       // the comparison's own -- is a clean generation, and that is the frame
       // criterion 1 is a claim about.
       rig.paintOnce();
       rig.paintOnce();
+      rig.paintOnce();
+      rig.paintOnce();
       expect(rig.cache.hasCarryOver, isFalse,
           reason: 'factor $factor: a covered viewport retires the composite, '
               'and a composite still on screen would compose stale ink under '
               'every antialiased tile edge');
       await expectTiledEqualsLive(rig);
     }
   });
 
   // **Defect F1, closed in Task 9a.** This group was a measurement of a live
   // defect; it is now the gate that keeps it closed.
diff --git a/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart b/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart
index 5c6a9fd..c841ac0 100644
--- a/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart
+++ b/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart
@@ -25,20 +25,21 @@ import 'dart:typed_data';
 
 import 'package:flutter/widgets.dart';
 import 'package:flutter_test/flutter_test.dart';
 import 'package:jet_cad_2d/jet_cad_2d.dart';
 import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
 import 'package:vector_math/vector_math_64.dart' hide Aabb2, Colors;
 
 import 'support/fixtures.dart';
 import 'support/tile_comparison.dart';
 import 'support/tile_fixture.dart';
+import 'support/tile_harness.dart';
 
 /// A root leaf on the left, and a definition placed twice: once on the left,
 /// once far to the right.
 ///
 /// At [tileCamera] the world→screen map is `x -> 1.4x - 37`, `y -> 323 - 1.4y`,
 /// and a 64 device-pixel tile at `dpr` 2 is 32 logical pixels, so the two
 /// placements land eight tiles apart on x: instance 300 covers tile columns
 /// 0-1, instance 301 covers columns 8-9. "Did the other side survive" is
 /// therefore a question the geometry can answer, and an implementation that
 /// answers every edit by dropping the generation fails it.
@@ -632,20 +633,88 @@ void main() {
     expect(paints, greaterThan(paintsBefore),
         reason: 'a layer edit must cause a frame at all -- the half a counter '
             'inside paint could never reach');
     // And the half the frame count cannot see. `_dropGeneration` counts what
     // it threw away, so this is exact rather than "more than none": every tile
     // the previous frame baked is gone, whatever the new frame rebaked.
     expect(cache.invalidationCount, invalidationsBefore + tilesBefore,
         reason: 'every tile baked before the edit was drawn against the old '
             'layer table and must have been thrown away');
   });
+
+  // Criterion 10. `_invalidateTouched` condemns tiles by iterating `_baked`
+  // in both directions -- see this file's own header -- and a *sliced* tile
+  // has no record of its own unless the rest bake shares one band-wide record
+  // across every tile it cuts. A tile with no record is invisible to both
+  // directions: edit an entity after a settle and the stale tile keeps
+  // blitting over the corrected drawing, with `invalidationCount` reading
+  // zero. M5 is exactly that mutation -- deleting `_baked[key] = record;` in
+  // `_restBake`.
+  testWidgets('an edit after a sliced settle condemns the sliced tiles',
+      (t) async {
+    final h = await pumpTiled(t, document: bandCrossingGrid);
+    // **`settle` alone is not enough, and this is measured rather than
+    // assumed.** At this harness's budget (`kBakeBudgetDevicePixels`, 64
+    // tiles of 64 device pixels each) the ordinary per-tile loop bakes all
+    // but two of the viewport's 130 tiles across the first two frames, before
+    // the rest gate ever arms -- `settleFromBands`'s own doc comment says so,
+    // and a probe run confirmed it: a plain `settle` here slices exactly 2 of
+    // 130 tiles, in the bottom-right corner, nowhere near `kMovableHandle`'s
+    // resting tile at column 2, row 4. A test built on a plain `settle` would
+    // pass with `_baked[key] = record;` deleted for no reason connected to
+    // the code under test -- M5 would survive silently. `settleFromBands`
+    // forces a table edit that drops every tile at the same, unmoved camera,
+    // so the very next frame's rest bake slices the *whole* viewport -- 130
+    // of 130, asserted below -- and `kMovableHandle`'s tile is necessarily
+    // among them.
+    final slices = await settleFromBands(t, h);
+    final tilesBefore = h.cache.liveTileCount;
+    expect(tilesBefore, greaterThan(0),
+        reason: 'not vacuous: there must be tiles to condemn');
+    expect(slices, tilesBefore,
+        reason: 'every visible tile must have come from the band-sliced '
+            'path, or the movable entity might be sitting on one that '
+            "did not -- exactly the gap `settle` alone leaves");
+    final invalidationsBefore = h.cache.invalidationCount;
+
+    // The fixture guard, exactly as every test above states it: the old and
+    // new tile sets must be disjoint, or direction one and direction two
+    // cannot be told apart and deleting either goes unnoticed. `oldTiles` is
+    // the harness's own settled record -- the tiles the sliced band bake
+    // actually wrote `kMovableHandle` into; `newTiles` is a fresh oracle's
+    // answer for where the document's edited state paints it, exactly the
+    // way `tilesFor` above answers direction two for the unsliced tests. See
+    // `bandCrossingGrid`'s and `moveOneEntityOntoDisjointTiles`'s doc
+    // comments for the arithmetic: tile column 2, row 4 against tile column
+    // 9, row 1, seven columns and three rows clear.
+    final oldTiles = h.cache.tilesHolding(kMovableHandle).toSet();
+    expect(oldTiles, isNotEmpty,
+        reason: 'the movable entity must be findable in the settled cache');
+
+    h.moveOneEntityOntoDisjointTiles();
+    final newTiles = tilesFor(h.document, kMovableHandle).toSet();
+    expect(newTiles, isNotEmpty);
+    expect(newTiles.intersection(oldTiles), isEmpty,
+        reason: 'fixture guard: unless the edit lands the entity on tiles it '
+            'did not occupy, direction one and direction two cannot be told '
+            'apart and deleting either goes unnoticed');
+
+    await t.pump();
+
+    expect(h.cache.invalidationCount, greaterThan(invalidationsBefore),
+        reason: 'sliced tiles carry the band record, so the edit reaches them');
+    await settle(t, h);
+    expect(
+        differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
+        reason: 'and the drawing is correct afterwards, which is the half a '
+            'counter alone cannot show');
+  });
 }
 
 /// One vertical line eight tile rows tall, and a definition placed clear of it.
 ///
 /// The line is the probe for accepted gap G6. Anti-degenerate clause 1 holds
 /// structurally: at a 64 device-pixel tile and `dpr` 2 the line spans about
 /// eight rows, so it cannot sit inside one tile. Clause 4 is why the
 /// definition is here at all — a root-only fixture never reaches the
 /// definition arm — and the placement sits in tile columns 9-10, four columns
 /// clear of anything this test condemns, so "and still not a generation drop"
diff --git a/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart b/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart
new file mode 100644
index 0000000..6f5290d
--- /dev/null
+++ b/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart
@@ -0,0 +1,245 @@
+// The two runtime switches Plan 3i's Tasks 12 and 13 measure through, and the
+// only tests that can tell a switch that switches from one that is merely
+// read.
+//
+// **Why this file exists at all.** Criterion 4 scores a ratio between a
+// "rest" arm and a "tiled" arm; criterion 8 scores a ratio between a "narrow"
+// arm and an "M4" arm. Both ratios are defined to run **interleaved in one
+// session**, which means one binary has to be able to be both arms — hence
+// `TileCache.debugRestBakeDisabled` and `TileCache.debugFullViewportQuery`.
+// A flag that is read but changes nothing observable would make both ratios
+// read exactly 1.00, and the degenerate number would land in a document of
+// record with nothing to contradict it. So each test below asserts on what
+// the frame path *did* — slices, coverage, the recorded strip, triangles
+// emitted — and never on the flag's own value, which is true by assignment.
+//
+// **Why a file of its own, rather than `tile_regime_test.dart` or
+// `tile_fallback_test.dart`.** The two switches share a subject — they are
+// the measurement seams, and they exist for one reason — but they sit on
+// opposite sides of `paintFrame`: one suppresses the rest bake, the other
+// widens the live fallback's query. Splitting them across those two files
+// would put half of one purpose in each and leave neither file able to say
+// why its half is there; `tile_regime_test.dart` is about the rest *gate*
+// predicate (four of its tests are pure-Dart camera comparisons) and
+// `tile_fallback_test.dart` is a pixel-agreement sweep that declares in its
+// own header that it names no symbol from `jet_cad_2d_flutter`. Both flag
+// tests name several.
+//
+// Mutants M13 and M14 in `docs/superpowers/notes/plan-3i-mutation-log.md` are
+// the deletions of the two switches; each reddens exactly one test here.
+
+import 'package:flutter/widgets.dart';
+import 'package:flutter_test/flutter_test.dart';
+import 'package:jet_cad_2d/jet_cad_2d.dart';
+import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
+
+import 'support/tile_fixture.dart';
+import 'support/tile_harness.dart';
+
+/// Drops [h]'s generation at an unmoved camera and settles, counting slices.
+///
+/// **This is `settleFromBands` with its two promises removed, and the
+/// removal is the point rather than a shortcut.** That helper asserts
+/// `slices == liveTileCount` and `viewportCovered`, which is exactly the
+/// claim `debugRestBakeDisabled` is built to falsify: the flagged arm slices
+/// nothing. A shared helper cannot both promise the band settle and be the
+/// vehicle for proving it did not happen, so the two arms below drive
+/// themselves and state their own promises at the call site — the enabled arm
+/// restates `settleFromBands`'s equality verbatim.
+///
+/// Everything else is deliberately *not* re-implemented: the pump bound lives
+/// in [settle] and is called, not copied, so this file cannot drift out of
+/// step with `kRestGateFrames` the way a second copy of that loop would.
+///
+/// The mechanics are `settleFromBands`'s and its doc comment carries the
+/// reasoning: `paintFrame` reads `tables.mutationRevision` every frame and
+/// drops the generation when it moves, keeping the lattice and the anchor, so
+/// the very next frame is a rest frame over an empty generation **at a camera
+/// that never moved** — which is the only state where the whole viewport is
+/// in the rest bake's hands rather than the two corner tiles the initial
+/// budgeted fill happens to leave. The layer added is referenced by nothing,
+/// so not one pixel changes with it.
+Future<int> _restFromEmptyGeneration(WidgetTester t, TiledHarness h) async {
+  await settle(t, h);
+  var slices = 0;
+  h.cache.debugOnSliceForTest = () => slices++;
+  addTearDown(() => h.cache.debugOnSliceForTest = null);
+  h.document.tables.layers.add(const LayerRecord(
+    handle: Handle(901),
+    name: 'SEAM-DROP',
+    color: IndexedColor(3),
+    linetype: ReservedHandles.continuousLinetype,
+    lineweight: 50,
+    transparency: 0,
+  ));
+  await t.pump();
+  await settle(t, h);
+  h.cache.debugOnSliceForTest = null;
+  return slices;
+}
+
+/// What one live-fallback frame did, read off the shipped frame path.
+class _FallbackArm {
+  const _FallbackArm(this.strip, this.clip, this.triangles, this.liveDraws);
+
+  /// `TileCache.debugLastStrip`: the rectangle the fallback actually walked.
+  final Rect? strip;
+
+  /// `TileCache.debugLastClip`: the rectangle the fallback's drawing was
+  /// clipped to. Under [debugFullViewportQuery] this must stay [strip]'s
+  /// narrow twin, `uncovered` -- that is what makes the flag Plan 3h's M4 and
+  /// not its M5.
+  final Rect? clip;
+
+  /// `VerticesDrawSink.frameTriangleCount` for that frame — the quantity
+  /// criterion 8's ratio is built on, and the one `kTriangleBudgetRatio`
+  /// already uses to kill this mutation as a source edit.
+  final int triangles;
+  final int liveDraws;
+
+  @override
+  String toString() => '_FallbackArm(strip: $strip, clip: $clip, '
+      'triangles: $triangles, liveDraws: $liveDraws)';
+}
+
+/// One partly-baked frame with an entering band the fallback owes.
+///
+/// The arrangement is `measureFallbackAgreement`'s, minus the pixel capture:
+/// cover the viewport at a budget that never runs out, then drop the budget to
+/// one tile a frame and pan, so the entering band cannot be baked and the live
+/// walk has to own it. No settle is needed — this fixture only pans, so no
+/// generation is ever retired and `_carryOver` stays null throughout.
+///
+/// **`Offset(0, 53)` and not any pan.** `kTriangleBudgetRatio`'s doc comment
+/// records the swept measurement behind this choice: over `kFallbackOffsets`
+/// on `fillingGrid`, this is the offset where the shipped narrowing's
+/// tiled/live triangle ratio is *worst* (0.9375) and where the mutant's is
+/// highest — the tightest sample in the sweep, so a switch that failed to
+/// widen the walk has the least room to hide here. Its band is also a single
+/// axis, so `uncovered` stays a genuine strip rather than bounding to the
+/// whole viewport the way a diagonal pan's does.
+_FallbackArm _fallbackArm({required bool fullViewportQuery}) {
+  final measurer = FlutterTextMeasurer();
+  try {
+    final rig = TileRig(
+        tileDevicePixels: 64,
+        tilesBakedPerFrame: 1000,
+        document: fillingGrid(measurer));
+    try {
+      rig.paintOnce();
+      rig.cache.bakeBudgetDevicePixels = 64 * 64;
+      rig.cache.debugFullViewportQuery = fullViewportQuery;
+      rig.panBy(0, 53);
+      // Both counters zeroed immediately before the frame under test, so
+      // every number below is that one frame's own emission rather than a
+      // running total that includes the covering frame above.
+      rig.cache.resetCounters();
+      rig.vertices.resetCounters();
+      rig.paintOnce();
+      return _FallbackArm(rig.cache.debugLastStrip, rig.cache.debugLastClip,
+          rig.vertices.frameTriangleCount, rig.cache.liveDrawCount);
+    } finally {
+      rig.dispose();
+    }
+  } finally {
+    measurer.clear();
+  }
+}
+
+void main() {
+  testWidgets(
+      'the rest bake fires: the unflagged arm slices every visible tile',
+      (t) async {
+    // Arm 1: the flag off, which is every shipped frame. This half is the
+    // anti-degenerate clause for arm 2 — without it, "no slices" would be
+    // satisfied by an arrangement that never reaches a rest frame at all, and
+    // the flag would look load-bearing while doing nothing.
+    final enabled = await pumpTiled(t);
+    final slicedWithBake = await _restFromEmptyGeneration(t, enabled);
+    expect(slicedWithBake, equals(enabled.cache.liveTileCount),
+        reason: 'setup: with the flag off the rest bake must own the whole '
+            'viewport, or the flagged arm below proves nothing');
+    expect(slicedWithBake, greaterThan(1),
+        reason: 'setup: a one- or two-tile band settle is the degenerate '
+            'case `settleFromBands` exists to avoid');
+    expect(enabled.cache.viewportCovered, isTrue);
+  });
+
+  testWidgets('debugRestBakeDisabled slices nothing and still covers',
+      (t) async {
+    final h = await pumpTiled(t);
+    h.cache.debugRestBakeDisabled = true;
+
+    final sliced = await _restFromEmptyGeneration(t, h);
+
+    // The switch actually switched: no tile on this frame came out of a band.
+    expect(sliced, 0,
+        reason: 'with the rest bake disabled no tile may be cut from a band '
+            '-- criterion 4\'s denominator arm is the budgeted per-tile path, '
+            'and an arm that still slices is the numerator arm under a '
+            'different name, which would put the ratio at 1.00');
+    // And it is a measurement switch, not a correctness switch: the ordinary
+    // budgeted path still filled the viewport, through `_bake`, over more
+    // frames. Asserting both is what separates "the bake was suppressed" from
+    // "the frame did nothing at all" -- the latter would also slice zero.
+    expect(h.cache.bakeCount, greaterThan(0),
+        reason: 'the budgeted per-tile path must have baked the tiles the '
+            'band path was not allowed to');
+    expect(h.cache.viewportCovered, isTrue,
+        reason: 'pixels stay correct either way; only how many frames '
+            'coverage takes changes');
+    expect(h.cache.liveTileCount, greaterThan(1),
+        reason: 'and the generation it refilled is the whole visible set, '
+            'not a corner of it');
+  });
+
+  test('debugFullViewportQuery grows the fallback walk to the whole viewport',
+      () {
+    final narrow = _fallbackArm(fullViewportQuery: false);
+    final m4 = _fallbackArm(fullViewportQuery: true);
+
+    // Non-vacuity first: both arms must have actually run a live fallback on
+    // the frame under test, or the strips below are the previous frame's.
+    expect(narrow.liveDraws, greaterThan(0), reason: 'narrow=$narrow');
+    expect(m4.liveDraws, greaterThan(0), reason: 'm4=$m4');
+
+    // The shipped arm walks a strip, and a strip strictly inside the
+    // viewport. This is the clause that fails if the fixture ever stops
+    // producing an interior edge -- at which point both arms would walk the
+    // whole viewport for reasons that have nothing to do with the flag.
+    expect(narrow.strip, isNotNull, reason: 'narrow=$narrow');
+    expect(narrow.strip!.height, lessThan(kTileViewport.height),
+        reason: 'the narrowed query must walk less than the full viewport, '
+            'or the two arms are the same arm: narrow=$narrow');
+
+    // The M4 arm walks the viewport. `debugLastStrip` is written by
+    // `paintFrame` itself from the value the walk was handed, so this reads
+    // the shipped code's decision rather than restating the flag.
+    expect(m4.strip, equals(Offset.zero & kTileViewport),
+        reason: 'with the flag set the query is the full viewport -- that is '
+            'what Plan 3h\'s M4 is: $m4');
+
+    // **The clip is what separates this M4 from Plan 3h's M5.** M5 reaches
+    // the same end state from the other direction -- it grows the query and
+    // leaves the clip untouched -- so a flag that widened the clip along with
+    // the strip would publish an "M4" arm that is neither mutant. The clip
+    // must stay the same narrow `uncovered` rectangle whether the flag is set
+    // or not, and it must differ from the M4 arm's own (widened) strip.
+    expect(m4.clip, isNotNull, reason: 'm4=$m4');
+    expect(m4.clip, equals(narrow.clip),
+        reason: 'the clip must not move when the flag is set -- only the '
+            'query does: narrow=$narrow m4=$m4');
+    expect(m4.clip, isNot(equals(m4.strip)),
+        reason: 'a clip that widened along with the strip would be neither '
+            'Plan 3h\'s M4 nor its M5: m4=$m4');
+
+    // And the quantity criterion 8 is actually a ratio of. The strip
+    // assertions above see the rectangle; this sees the cost, which is the
+    // only reason the rectangle matters. A wider walk that tessellated the
+    // same geometry would be an M4 that is inert, and the criterion 8 ratio
+    // would read 1.00 with both switches working perfectly.
+    expect(m4.triangles, greaterThan(narrow.triangles),
+        reason: 'the full-viewport query must tessellate more geometry than '
+            'the strip-sized one: narrow=$narrow m4=$m4');
+  });
+}
diff --git a/packages/jet_cad_2d_flutter/test/tile_regime_test.dart b/packages/jet_cad_2d_flutter/test/tile_regime_test.dart
new file mode 100644
index 0000000..b9de199
--- /dev/null
+++ b/packages/jet_cad_2d_flutter/test/tile_regime_test.dart
@@ -0,0 +1,167 @@
+import 'package:flutter_test/flutter_test.dart';
+import 'package:jet_cad_2d/jet_cad_2d.dart';
+import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
+
+import 'support/tile_harness.dart';
+
+void main() {
+  ViewportTransform at(double scale, double e, double f) => ViewportTransform(
+      worldToScreenMatrix: Transform2(scale, 0, 0, -scale, e, f));
+
+  test('the same camera compares same', () {
+    expect(sameQuantisedCamera(at(1.4, 10, 20), at(1.4, 10, 20)), isTrue);
+  });
+
+  test('a scale change compares different', () {
+    expect(sameQuantisedCamera(at(1.4, 10, 20), at(1.5, 10, 20)), isFalse);
+  });
+
+  // Translation is in the comparison and not only scale. Immediately after a
+  // zoom the generation is empty, so a pan that follows keeps the scale and
+  // does not cover the viewport: under a scale-only rule two same-scale pan
+  // frames would satisfy every rest condition and spend a full bake while the
+  // camera is still moving.
+  test('a translation change compares different', () {
+    expect(sameQuantisedCamera(at(1.4, 10, 20), at(1.4, 11, 20)), isFalse);
+    expect(sameQuantisedCamera(at(1.4, 10, 20), at(1.4, 10, 21)), isFalse);
+  });
+
+  test('the skew terms are compared too', () {
+    final a = ViewportTransform(
+        worldToScreenMatrix: Transform2(1.4, 0.1, 0, -1.4, 10, 20));
+    final b = ViewportTransform(
+        worldToScreenMatrix: Transform2(1.4, 0.2, 0, -1.4, 10, 20));
+    expect(sameQuantisedCamera(a, b), isFalse);
+
+    // The other skew term. Every other fixture in this file, including `a`
+    // and `b` above, leaves `c` at 0 -- so without a case that varies it,
+    // deleting `x.c == y.c` from the comparison kills no test here.
+    final c1 = ViewportTransform(
+        worldToScreenMatrix: Transform2(1.4, 0, 0.1, -1.4, 10, 20));
+    final c2 = ViewportTransform(
+        worldToScreenMatrix: Transform2(1.4, 0, 0.2, -1.4, 10, 20));
+    expect(sameQuantisedCamera(c1, c2), isFalse);
+  });
+
+  testWidgets('a moving frame bakes nothing and walks nothing', (t) async {
+    final h = await pumpTiled(t);
+    // Settle first, so the failure below cannot be "there was nothing to do".
+    await settle(t, h);
+    expect(h.cache.viewportCovered, isTrue);
+
+    h.cache.resetCounters();
+    for (var i = 0; i < 8; i++) {
+      h.camera.zoomAt(const Offset(120, 90), 1.05);
+      await t.pump();
+    }
+
+    expect(h.cache.bakeCount, 0, reason: 'a moving frame must bake nothing');
+    // `liveDrawCount` and not the painter's leaf counter: `DraftPainter.paint`
+    // zeroes its own counters on entry, so a frame that never calls it leaves
+    // the previous frame's number standing and the assertion would pass for
+    // the wrong reason. The cache's counter increments where the live walk
+    // actually happens.
+    expect(h.cache.liveDrawCount, 0,
+        reason: 'a moving frame must draw no live geometry either -- the '
+            'uncovered region bounds to the whole viewport, so a live walk '
+            'there is a full-viewport walk, 31.5-41.6 ms at 500,000 entities');
+    expect(h.cache.carryOverBlitCount, greaterThan(0),
+        reason: 'and it must still show something');
+  });
+
+  testWidgets(
+      'a moving frame with no composite falls through and draws something',
+      (t) async {
+    final h = await pumpTiled(t);
+    // A one-tile budget: the first generation this cache ever bakes cannot
+    // cover `fillingGrid`'s ~130 tiles at this viewport within a handful of
+    // frames, so no generation is ever retired into a composite before the
+    // zooms below -- the review's state (2), reached without ever settling
+    // once. `settle` is not called here on purpose: settling would either
+    // finish covering (defeating the setup) or, if it never can, hang the
+    // suite -- neither is wanted.
+    h.cache.bakeBudgetDevicePixels = 64 * 64;
+    // **And a ceiling below one band, which is what actually holds the
+    // generation short now.** Plan 3i Task 8's rest bake is not rationed by
+    // `bakeBudgetDevicePixels` -- it fills the viewport a tile row at a time
+    // -- so the budget alone no longer keeps a generation from covering. It
+    // declines to run at all when the ceiling cannot hold a band plus the
+    // visible set, and eight tiles cannot hold a thirteen-tile row, so this
+    // is the knob that produces the never-covering generation the setup
+    // needs. Both are kept: the budget is what bounds the frames the rest
+    // bake declines.
+    h.cache.cacheBytes = 8 * 64 * 64 * 4;
+    await t.pump();
+    // Non-vacuous setup, asserted rather than assumed: if this generation
+    // somehow did cover, the zoom below would mint a composite the normal
+    // way and the frames after it would pass for a reason that has nothing
+    // to do with the guard this test exists to catch.
+    expect(h.cache.hasCarryOver, isFalse,
+        reason: 'setup: nothing has ever been retired into a composite yet');
+    expect(h.cache.viewportCovered, isFalse,
+        reason: 'setup: the one-tile budget cannot have covered the '
+            'viewport already, or the composite above would be real for '
+            'the wrong reason');
+
+    h.cache.resetCounters();
+    // Two zooms, with no settling frame in between: the generation the first
+    // zoom leaves behind never gets a chance to cover either, so the second
+    // zoom's own retire attempt also has nothing to mint from.
+    h.camera.zoomAt(const Offset(120, 90), 1.05);
+    await t.pump();
+    h.camera.zoomAt(const Offset(120, 90), 1.05);
+    await t.pump();
+
+    expect(h.cache.hasCarryOver, isFalse,
+        reason: 'the outgoing generation for both zooms never covered, so '
+            '`_retireGeneration` minted nothing to fall back on -- this is '
+            'the state the guard has to survive without painting nothing');
+    // `liveDrawCount` alone, not the three-way sum: a single blitted tile
+    // satisfies "not gated" without proving the frame drew any geometry, and
+    // the live walk is what the ordinary bake-and-live-walk path this guard
+    // falls through to actually promises. Confirmed to still die to the
+    // guard's own mutation (deleting `_carryOver == null ||`): with no
+    // composite and the clause gone, `resting` reads false, the early return
+    // fires, and `liveDrawCount` stays 0.
+    expect(h.cache.liveDrawCount, greaterThan(0),
+        reason: 'a moving frame with no composite to show must still draw '
+            'something -- the ordinary bake-and-live-walk path -- rather '
+            'than leave the viewport blank for the length of the gesture');
+  });
+
+  // A wheel spun steadily: one scale change per frame, with a single
+  // unchanged frame between notches. Under a one-frame gate this bakes on
+  // every second frame.
+  testWidgets('a steadily spun wheel never arms the rest gate', (t) async {
+    final h = await pumpTiled(t);
+    await settle(t, h);
+    h.cache.resetCounters();
+
+    for (var notch = 0; notch < 6; notch++) {
+      h.camera.zoomAt(const Offset(120, 90), 1.1); // the moving frame
+      await t.pump();
+
+      // After the first notch, a composite is minted by the settled generation.
+      // Asserting it exists proves the gate's threshold term is under test: if
+      // the composite were null, the guard's middle disjunct would decide every
+      // frame and the threshold value would be unreachable.
+      if (notch == 0) {
+        expect(h.cache.hasCarryOver, isTrue,
+            reason: 'the first zoom retires the settled generation into a '
+                'composite; without it this test is vacuous');
+      }
+
+      await t.pump(); // one unchanged frame before the next notch
+    }
+
+    expect(h.cache.bakeCount, 0,
+        reason: 'a wheel that keeps turning must never reach two consecutive '
+            'unchanged frames, so it must never bake');
+  });
+
+  test('the gate needs two unchanged frames, not one', () {
+    // The threshold itself, stated where a reader can see it: one unchanged
+    // frame is the in-between frame and draws like a moving one.
+    expect(kRestGateFrames, 2);
+  });
+}
diff --git a/packages/jet_cad_2d_flutter/test/tile_settle_test.dart b/packages/jet_cad_2d_flutter/test/tile_settle_test.dart
index e458290..f6fbd68 100644
--- a/packages/jet_cad_2d_flutter/test/tile_settle_test.dart
+++ b/packages/jet_cad_2d_flutter/test/tile_settle_test.dart
@@ -14,49 +14,60 @@
 //
 // Both directions are asserted. A canvas that asks for a frame unconditionally
 // passes the first test and spins the device's GPU forever, so the second test
 // is what makes the first one worth landing.
 import 'package:flutter/widgets.dart';
 import 'package:flutter_test/flutter_test.dart';
 import 'package:jet_cad_2d/jet_cad_2d.dart';
 import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
 
 import 'support/tile_fixture.dart';
+import 'support/tile_harness.dart';
 
 void main() {
   /// Pumps a canvas whose viewport needs more tiles than one frame may bake.
   ///
   /// 400x300 logical at dpr 2 is 800x600 device pixels; at a 64-pixel tile
   /// that is 13 x 10 = 130 tiles against a budget of 262144 / 4096 = 64 per
   /// frame. Two frames minimum, and the fixture inks all of them.
+  ///
+  /// **The `Center` is load-bearing, the same finding `pumpTiled` in
+  /// `support/tile_harness.dart` documents.** `pumpWidget` hands its child the
+  /// surface's *tight* constraints, and a `SizedBox` under tight constraints
+  /// is inert -- so without `Center` this canvas ran at 800x600 logical
+  /// (1600x1200 device pixels, 475 tiles), not the 400x300 the comment above
+  /// describes, and the "ten is slack" bound below was really spent on eight
+  /// of its ten iterations.
   Future<TileCache> pumpFilling(WidgetTester tester) async {
     final measurer = FlutterTextMeasurer();
     addTearDown(measurer.clear);
     final doc = fillingGrid(measurer);
     final index = SpatialIndex(doc);
     addTearDown(index.dispose);
     final camera = CameraController(tileCamera());
     addTearDown(camera.dispose);
 
     await tester.pumpWidget(MediaQuery(
       data: const MediaQueryData(devicePixelRatio: kTileDpr),
       child: Directionality(
         textDirection: TextDirection.ltr,
-        child: SizedBox(
-          width: kTileViewport.width,
-          height: kTileViewport.height,
-          child: DraftCanvas(
-            document: doc,
-            index: index,
-            camera: camera,
-            tiles: true,
-            tileDevicePixels: 64,
+        child: Center(
+          child: SizedBox(
+            width: kTileViewport.width,
+            height: kTileViewport.height,
+            child: DraftCanvas(
+              document: doc,
+              index: index,
+              camera: camera,
+              tiles: true,
+              tileDevicePixels: 64,
+            ),
           ),
         ),
       ),
     ));
     await tester.pump();
     return tester.state<DraftCanvasState>(find.byType(DraftCanvas)).tileCache!;
   }
 
   testWidgets('a frame that left tiles unbaked asks for another', (t) async {
     final cache = await pumpFilling(t);
@@ -79,11 +90,29 @@ void main() {
     for (var i = 0; i < 10 && t.binding.hasScheduledFrame; i++) {
       await t.pump();
     }
 
     expect(cache.liveTileCount, greaterThan(afterFirst),
         reason: 'the extra frames must have baked something');
     expect(t.binding.hasScheduledFrame, isFalse,
         reason: 'a covered viewport owes nothing, and a canvas that keeps '
             'asking burns the GPU on a still screen');
   });
+
+  testWidgets('the settle completes in one frame', (t) async {
+    final h = await pumpTiled(t);
+    await settle(t, h);
+    expect(h.cache.viewportCovered, isTrue);
+
+    h.camera.zoomAt(const Offset(120, 90), 1.3);
+    await t.pump(); // moving
+    await t.pump(); // in between
+    final tilesBefore = h.cache.liveTileCount;
+    await t.pump(); // the rest frame
+    expect(h.cache.viewportCovered, isTrue,
+        reason: 'one rest frame covers the viewport; the tiled fill it '
+            'replaces took one frame per tile');
+    expect(h.cache.liveTileCount, greaterThan(tilesBefore));
+    expect(t.binding.hasScheduledFrame, isFalse,
+        reason: 'and nothing is owed afterwards');
+  });
 }
diff --git a/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart b/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart
new file mode 100644
index 0000000..010a05f
--- /dev/null
+++ b/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart
@@ -0,0 +1,143 @@
+// The pixel instruments the slice path is judged by: criteria 5, 6 and 11.
+//
+// **Why four arms and not one.** Arm 1 compares a settled tiled frame against
+// the live frame at the same camera, and that is the criterion. It cannot see
+// two whole classes of defect on its own:
+//
+//   * A band cut wider than the viewport blits its **transparent overhang**
+//     off the right-hand edge, where nothing is looking. Plan 3h's p95 pan
+//     gate is blind to it too — a transparent blit costs exactly what an
+//     opaque one costs. Only a pan smaller than one tile brings that overhang
+//     inside the viewport, which is arm 2.
+//   * A slice rectangle measured in grid space rather than band space is the
+//     *same rectangle* whenever the visible key range starts at column 0,
+//     because `TileBand.deviceRect.left` is defined as
+//     `keys.first.x * tileDevicePixels`. The pinned pure-zoom script never
+//     moves that range. Arm 3 takes a pan between the scale change and the
+//     rest bake, which does.
+//
+// Arm 4 is criterion 6 with teeth: the same comparison restricted to the rows
+// and columns a tile boundary falls on, plus the clause that says the sweep
+// looked at ink rather than at background.
+//
+// **Every arm settles through `settleFromBands`, and that is load-bearing.**
+// A plain `settle` reaches its rest frame with 128 of 130 tiles already baked
+// by the per-tile path, so the band bake would slice two corner tiles and
+// every mutant below would be judged on those two. See `settleFromBands`.
+//
+// **Zero, never a tolerance.** `quantiseCamera` puts every tile destination on
+// whole device pixels, so a blit is a 1:1 texel copy; there is nothing for a
+// tolerance to absorb and a seam of one unit is exactly what one would hide.
+import 'package:flutter_test/flutter_test.dart';
+
+import 'support/tile_comparison.dart';
+import 'support/tile_fixture.dart';
+import 'support/tile_harness.dart';
+
+void main() {
+  testWidgets('a settled generation is identical to a live frame', (t) async {
+    final h = await pumpTiled(t, document: bandCrossingGrid);
+    await settleFromBands(t, h);
+    expect(
+        differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
+        reason: 'a band is queried with a pad and clipped without one, and '
+            'the tiles cut out of it have to hold what the live frame draws');
+  });
+
+  // The same arm at a camera whose view span straddles a power-of-two rebase
+  // step, so a band that derived its own origin would land in a different
+  // cell of that step from the frame. See `rebaseBoundaryCamera`.
+  testWidgets('and at a camera on a power-of-two rebase boundary', (t) async {
+    final h = await pumpTiled(t,
+        document: bandCrossingGrid, camera: rebaseBoundaryCamera());
+    await settleFromBands(t, h);
+    expect(
+        differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
+        reason: 'rebasing is frame-global: every band must be walked against '
+            'the frame origin, not one it derived for itself');
+  });
+
+  testWidgets('and stays identical after a pan smaller than one tile',
+      (t) async {
+    final h = await pumpTiled(t, document: bandCrossingGrid);
+    await settleFromBands(t, h);
+    // Under one 32-logical-pixel tile in both axes, so the visible key range
+    // does not move and no tile is rebaked: what changes is only *where* the
+    // tiles already held blit, which is what drags an edge tile's overhang
+    // into view.
+    h.camera.panBy(const Offset(-11, -7));
+    await settle(t, h);
+    expect(
+        differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
+        reason: 'an edge tile sliced from a viewport-sized source blits its '
+            'transparent overhang here, and costs the same as an opaque one, '
+            'so no timing gate can see it');
+  });
+
+  testWidgets('and when a pan lands between the scale change and the bake',
+      (t) async {
+    final h = await pumpTiled(t, document: bandCrossingGrid);
+    await settleFromBands(t, h);
+    h.camera.zoomAt(const Offset(120, 90), 1.3);
+    await t.pump(); // moving: the generation is retired and a new one anchored
+    // 90 x 60 logical is 180 x 120 device pixels, two and a bit tiles in each
+    // axis, and **positive**, which drives the visible key range *negative*:
+    // `visibleKeys` starts at `-dx`, so `x0 = floorDiv(-180, 64) = -3` and
+    // `y0 = -2`, and the band's `deviceRect.left` is -192. Both halves matter.
+    // Without a pan at all, band-local and grid-space slice arithmetic are the
+    // *same arithmetic* -- `deviceRect.left` is `keys.first.x * 64`, which is
+    // zero when the range starts at column 0 -- and M10 is unwitnessable; with
+    // the range negative the grid-space rectangle is negative too and reads
+    // off the front of the band image, which is the case the pinned pure-zoom
+    // script never produces.
+    //
+    // **The sign is also what keeps the untiled reference honest here, and
+    // that is a measured constraint rather than a preference.** A tile bake
+    // queries the index padded by `kTileSlack`; `DraftPainter.paint` queries
+    // `camera.visibleWorld(viewport)` with no slack at all. So a stroke whose
+    // centreline lies within its own half-width *outside* a viewport edge is
+    // drawn by the tiled frame and missed by the live one -- the tiled frame
+    // is the correct one, and the difference is a property of the reference.
+    // At `Offset(-90, -60)` this fixture's thick stroke at world y 184.286
+    // lands at screen y -2.5 against a 3.78 half-width and the arm read 1,767
+    // stray pixels across the top three device rows. At `Offset(90, 60)` the
+    // four such windows are world y in (248.9, 250.98) and (82.0, 84.07) and
+    // world x in (-5.37, -3.30) and (216.48, 218.56), and no thick stroke this
+    // fixture places falls in any of them. Reported as a finding: the
+    // asymmetry is real and belongs to `DraftPainter`, not to the tile path.
+    h.camera.panBy(const Offset(90, 60));
+    await t.pump(); // moving again, so the rest gate starts over
+    await settle(t, h);
+    // The rest frame blitted the outgoing composite underneath the generation
+    // it then dropped, so it is not a statement about the new tiles alone.
+    // See `repaintOnce`; `tile_cache_test`'s criterion 1 pays for the same
+    // frame and asserts the same thing before comparing.
+    await repaintOnce(t, h);
+    expect(h.cache.hasCarryOver, isFalse,
+        reason: 'a composite still on screen composes the outgoing '
+            'generation under every transparent pixel of the incoming one');
+    expect(
+        differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
+        reason: 'a grid-space slice rectangle reads off the wrong part of the '
+            'band image as soon as the visible key range moves');
+  });
+
+  // Criterion 6, with its teeth: the boundary columns and rows specifically.
+  testWidgets('tile boundaries carry no difference of their own', (t) async {
+    final h = await pumpTiled(t, document: bandCrossingGrid);
+    await settleFromBands(t, h);
+    final tiled = await captureTiled(t, h);
+    final live = await captureLive(t, h);
+    const w = kCaptureWidth, hgt = kCaptureHeight; // 800 x 600 device pixels
+    expect(
+        differingPixelsOnTileEdges(tiled, live,
+            tileDevicePixels: 64, width: w, height: hgt),
+        0,
+        reason: 'a seam lives on the boundary, and a whole-frame count buries '
+            'it under 62 interior columns out of every 64');
+    // Not vacuous: the sweep must have looked at ink, not at background.
+    expect(inkOnTileEdges(live, tileDevicePixels: 64, width: w, height: hgt),
+        greaterThan(200),
+        reason: 'two blank captures agree perfectly and prove nothing');
+  });
+}
diff --git a/packages/jet_cad_2d_flutter/test/tile_zoom_warmth_test.dart b/packages/jet_cad_2d_flutter/test/tile_zoom_warmth_test.dart
new file mode 100644
index 0000000..921ffc5
--- /dev/null
+++ b/packages/jet_cad_2d_flutter/test/tile_zoom_warmth_test.dart
@@ -0,0 +1,232 @@
+// Whether one arm of the zoom measurement leaves the next arm's settle
+// trivially covered.
+//
+// **The concern.** `apps/dev_harness_2d/lib/measurement_rig.dart`'s
+// `runTileZoomPhase` ends every arm with a settle, and `main.dart` runs
+// `kZoomArms` of them back to back against **one** `TileCache`, resetting
+// `camera.value = fittedCamera` before each. The gesture is symmetric --
+// `kZoomSteps` steps at `kZoomFactor` and then the same number at
+// `1 / kZoomFactor` -- so it ends, arithmetically, where it began. If the warm
+// generation an arm's settle leaves behind were still live when the next arm's
+// settle is measured, "frames to a covered viewport" would read 1 in both arms
+// of criterion 4 whatever the flag under test did, and the ratio would be
+// measuring cache warmth rather than the rest bake. That is the degenerate
+// fixture `CLAUDE.md` names as this codebase's dominant failure mode, and it
+// would be invisible in the published number.
+//
+// **The answer this file records is that it does not happen, for two
+// independent reasons, and it pins both.**
+//
+// 1. A zoom frame changes the scale, `TileCache._gridFor` finds
+//    `TileGrid.matchesScale` false and retires the generation, and
+//    `_retireGeneration` ends in `_disposeTiles()`. So the warm generation is
+//    gone after the **first** frame of the excursion -- not at its end -- and
+//    no frame in between can refill it: every gesture frame is a moving frame
+//    and takes `paintFrame`'s early return, which bakes nothing. Measured
+//    below: `liveTileCount` 130 -> 0 on frame one, and 0 for all 80 frames.
+// 2. The round trip does not land back on the starting camera anyway.
+//    `zoomAt` multiplies the scale term one step at a time, so 40 multiplies
+//    by 1.03 followed by 40 by `1 / 1.03` take 1.4 to 1.4000000000000017 --
+//    and `matchesScale`, like every stored-value comparison in this file, is
+//    exact `==`. The second test pins that number.
+//
+// The two arms below therefore settle identically -- same frame count, same
+// band-bake count, same tile count -- and neither settle is trivial. That is
+// the property criterion 4's ratio needs, and this file is the regression that
+// keeps it.
+import 'package:flutter_test/flutter_test.dart';
+import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
+
+import 'support/tile_fixture.dart';
+import 'support/tile_harness.dart';
+
+/// Steps in each direction, mirroring `measurement_rig.dart`'s `kZoomSteps`.
+///
+/// The rig's constant is pinned by the design spec and lives in an app package
+/// this one cannot import, so it is restated rather than shared. What matters
+/// here is the *shape* -- an excursion that returns to its starting scale --
+/// but the count is matched anyway so that the float residue the second test
+/// pins is the residue the rig's own script actually accumulates.
+const int kArmZoomSteps = 40;
+
+/// Per-step factor, mirroring `measurement_rig.dart`'s `kZoomFactor`.
+const double kArmZoomFactor = 1.03;
+
+/// What one arm of the two-arm sequence measured.
+class _ArmResult {
+  _ArmResult({
+    required this.settleFrames,
+    required this.settleBakes,
+    required this.tilesAfterSettle,
+  });
+
+  /// Idle frames pumped before [TileCache.viewportCovered] first read true, or
+  /// **0** when it was already true before a single idle frame was pumped --
+  /// which is precisely the trivial coverage this file exists to rule out.
+  final int settleFrames;
+
+  /// [TileCache.bakeCount] over the settle. Band-counted, not tile-counted:
+  /// the settle's bakes come from `_restBake`, which counts once per band.
+  final int settleBakes;
+
+  final int tilesAfterSettle;
+}
+
+void main() {
+  // Off-centre, the same 30%/70% of the viewport `zoomFocusFor` uses: a focal
+  // point at the viewport's centre coincides with `rebaseOriginFor`'s own
+  // centre and half the residual arithmetic never runs.
+  final focus = Offset(kTileViewport.width * 0.30, kTileViewport.height * 0.70);
+
+  /// One arm: reset the camera the way `main.dart` does, run the round trip,
+  /// then measure the settle.
+  Future<_ArmResult> runArm(
+    WidgetTester t,
+    TiledHarness h,
+    ViewportTransform fitted,
+  ) async {
+    h.camera.value = fitted;
+    // The two throwaway frames `runTileZoomPhase` takes before it resets its
+    // counters.
+    for (var i = 0; i < 2; i++) {
+      h.camera.panBy(Offset.zero);
+      await t.pump();
+    }
+
+    final generationBefore = h.cache.generation;
+    for (var i = 0; i < kArmZoomSteps; i++) {
+      h.camera.zoomAt(focus, kArmZoomFactor);
+      await t.pump();
+      if (i == 0) {
+        // **Reason 1, at the only frame where it is visible.** By the end of
+        // the excursion "no tiles" is over-determined -- 80 scale changes have
+        // happened -- so an implementation that retired the generation only
+        // on, say, a large enough scale ratio would still arrive at zero. The
+        // first frame is where a single 3% step has to have been enough.
+        expect(h.cache.generation, generationBefore + 1,
+            reason: 'the first zoom frame changes the scale, so the grid must '
+                'have been retired and a new generation anchored');
+        expect(h.cache.liveTileCount, 0,
+            reason: 'retiring the generation disposes its tiles -- the warm '
+                'set the previous settle left behind cannot survive into '
+                'this arm');
+        expect(h.cache.viewportCovered, isFalse,
+            reason: 'and coverage is a statement about tiles that exist, so '
+                'it goes with them');
+      }
+    }
+    for (var i = 0; i < kArmZoomSteps; i++) {
+      h.camera.zoomAt(focus, 1 / kArmZoomFactor);
+      await t.pump();
+    }
+
+    // No gesture frame refilled anything: `paintFrame` returns early on every
+    // moving frame that has a composite to blit, which all 80 of these do
+    // after the first.
+    expect(h.cache.liveTileCount, 0,
+        reason: 'no frame of the excursion may bake -- a moving frame blits '
+            'the composite and returns');
+    expect(h.cache.viewportCovered, isFalse,
+        reason: 'the gesture ends with an empty generation, so the settle '
+            'that follows has real work to do');
+
+    h.cache.resetCounters();
+    var settleFrames = 0;
+    // Zero means the settle was over before it started. The loop is skipped
+    // rather than entered so that the trivial case is reported as 0 and never
+    // as 1 -- 1 is what a genuine one-frame settle would read, and the whole
+    // question here is telling those two apart.
+    if (!h.cache.viewportCovered) {
+      for (var i = 1; i <= 30; i++) {
+        await t.pump();
+        settleFrames = i;
+        if (h.cache.viewportCovered) break;
+      }
+    }
+    return _ArmResult(
+      settleFrames: settleFrames,
+      settleBakes: h.cache.bakeCount,
+      tilesAfterSettle: h.cache.liveTileCount,
+    );
+  }
+
+  testWidgets('a zoom round trip leaves the next arm nothing warm to settle on',
+      (t) async {
+    final h = await pumpTiled(t);
+    await settle(t, h);
+    // Not vacuous: the arms below are only interesting because there *was* a
+    // warm generation for the first one to inherit.
+    expect(h.cache.viewportCovered, isTrue);
+    expect(h.cache.liveTileCount, 130,
+        reason: 'setup: the whole viewport is warm before arm A starts');
+    final fitted = h.camera.value;
+
+    final armA = await runArm(t, h, fitted);
+    final armB = await runArm(t, h, fitted);
+
+    // **The finding.** Both arms pay a real settle, and they pay the same one.
+    expect(armA.settleFrames, greaterThan(0),
+        reason: 'arm A must not find the viewport already covered');
+    expect(armB.settleFrames, greaterThan(0),
+        reason: 'arm B must not inherit arm A settle -- a settle reported as '
+            'covered before its first idle frame is measuring cache warmth, '
+            'not the rest bake');
+    expect(armB.settleFrames, armA.settleFrames,
+        reason: 'the two arms of criterion 4 must cost the same number of '
+            'frames when nothing differs between them but the arm ordinal');
+    expect(armB.settleBakes, armA.settleBakes,
+        reason: 'and the same number of band bakes');
+    expect(armB.tilesAfterSettle, armA.tilesAfterSettle,
+        reason: 'and must arrive at the same generation');
+
+    // The absolute figures, pinned so a change of regime is visible rather
+    // than merely equal to itself: two idle frames (the rest gate needs two
+    // consecutive unchanged cameras -- `kRestGateFrames`), ten bands, 130
+    // tiles.
+    expect(armA.settleFrames, 2);
+    expect(armA.settleBakes, 10);
+    expect(armA.tilesAfterSettle, 130);
+  });
+
+  // Reason 2, on its own, without a canvas: even if the excursion had left
+  // tiles behind, the scale it returns to is not the scale it started from.
+  //
+  // A unit test rather than a second widget test because nothing here needs a
+  // frame -- this is `zoomAt`'s arithmetic and `matchesScale`'s exactness,
+  // and the widget test above already covers the cache's behaviour.
+  test('the zoom round trip does not return to the starting scale', () {
+    final camera = CameraController(tileCamera());
+    addTearDown(camera.dispose);
+    final start = quantiseCamera(camera.value, kTileDpr);
+    final focus =
+        Offset(kTileViewport.width * 0.30, kTileViewport.height * 0.70);
+
+    for (var i = 0; i < kArmZoomSteps; i++) {
+      camera.zoomAt(focus, kArmZoomFactor);
+    }
+    for (var i = 0; i < kArmZoomSteps; i++) {
+      camera.zoomAt(focus, 1 / kArmZoomFactor);
+    }
+    final end = quantiseCamera(camera.value, kTileDpr);
+
+    // The residue, spelled out. `zoomAt` composes `about * m`, and for a
+    // camera with no skew that is a plain scalar multiply of the scale term
+    // once per step, so 80 roundings accumulate here and nowhere else.
+    expect(start.worldToScreenMatrix.a, 1.4);
+    expect(end.worldToScreenMatrix.a, 1.4000000000000017);
+    expect(end.worldToScreenMatrix.a, closeTo(1.4, 1e-14),
+        reason: 'the trip does return to the starting scale within float '
+            'error -- which is exactly why an implementation comparing with '
+            'a Tolerance would treat the generation as reusable');
+    expect(sameQuantisedCamera(start, end), isFalse,
+        reason: 'but the comparison is a stored-value comparison and is '
+            'exact `==`, so the grid that ends the excursion is not the grid '
+            'that began it');
+    // The translation, by contrast, does come back -- quantisation snaps it
+    // onto the same device pixel. Asserted so that the difference above is
+    // known to be the scale term and not a translation the reader might
+    // assume away.
+    expect(end.worldToScreenMatrix.e, start.worldToScreenMatrix.e);
+    expect(end.worldToScreenMatrix.f, start.worldToScreenMatrix.f);
+  });
+}
```
