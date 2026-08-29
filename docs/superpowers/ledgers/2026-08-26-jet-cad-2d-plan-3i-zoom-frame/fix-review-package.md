# Fix-wave re-review package (9206743..HEAD)

## Commits
c5794d7 docs: fix wave A's mutants, and three record-integrity corrections
ca0638f test(tiles): two instruments that could not fail
1a46886 fix(tiles): a pan after a zoom drew only the stale composite
3ba7f05 test(harness): ZOOM_MODE rejects what it cannot parse
45da407 feat(harness): ZOOM_MODE wires the interleaved arms criteria 4 and 8 name
7567619 docs: M20 -- the settle reads the frame before the one that covered
93052db fix(rig): the settle named the wrong frame, and the gesture the wrong 80

## Stat
```
 apps/dev_harness_2d/lib/main.dart                  |  86 ++-
 apps/dev_harness_2d/lib/measurement_rig.dart       | 644 ++++++++++++++++++---
 .../test/settle_attribution_test.dart              | 341 +++++++++++
 apps/dev_harness_2d/test/zoom_arm_wiring_test.dart | 247 ++++++++
 docs/superpowers/notes/plan-3i-mutation-log.md     | 596 ++++++++++++++++++-
 .../jet_cad_2d_flutter/lib/src/tile_cache.dart     | 200 +++++--
 .../test/invariants/tile_budget_test.dart          |  16 +-
 .../test/invariants/tile_bytes_test.dart           | 104 ++++
 .../test/support/tile_comparison.dart              |  31 +
 .../test/support/tile_harness.dart                 |  21 +
 .../jet_cad_2d_flutter/test/tile_grid_test.dart    |  48 ++
 .../jet_cad_2d_flutter/test/tile_regime_test.dart  | 200 ++++++-
 .../test/tile_slice_differential_test.dart         |  18 +
 13 files changed, 2399 insertions(+), 153 deletions(-)
```

## Diff
```diff
diff --git a/apps/dev_harness_2d/lib/main.dart b/apps/dev_harness_2d/lib/main.dart
index 94092b0..e17365a 100644
--- a/apps/dev_harness_2d/lib/main.dart
+++ b/apps/dev_harness_2d/lib/main.dart
@@ -272,24 +272,53 @@ final double kPanStep = _doubleDefine(
 /// **An `int.fromEnvironment` would be wrong here for [_intDefine]'s
 /// standing reason**: it silently reads anything it cannot parse as the
 /// default, and `ZOOM_ARMS=4` mistyped as `ZOOM_ARMS=4x` would run zero arms
 /// while looking like a run that asked for four.
 ///
 /// Inert at its default of zero: an ordinary `RUN_R2` session is unaffected,
 /// and this is additive to `runR2Rig`'s own pan and zoom phases, not a
 /// replacement for either.
 final int kZoomArms = _intDefine(
     'ZOOM_ARMS', const String.fromEnvironment('ZOOM_ARMS'), 0,
     minimum: 0);
 
+/// What [kZoomArms] repeats of the zoom phase are *for*.
+///
+/// - `plain` -- one configuration, repeated. Criterion 2's p95 and nothing
+///   else. **No flag is flipped**, so these are not criterion 4's or
+///   criterion 8's arms, and the transcript says so on every line.
+/// - `criterion4` -- the rest bake against `debugRestBakeDisabled`,
+///   interleaved.
+/// - `criterion8` -- the narrowed band query against `debugFullViewportQuery`
+///   (Plan **3h**'s M4), interleaved.
+///
+/// **A `String.fromEnvironment` with an explicit throw**, the rule [kBackend]
+/// and [kTilePx] already follow and that Plan 3c lost a full device run to by
+/// not following: a define that silently falls back to its default writes one
+/// run into the table under a heading the command line claimed and the run did
+/// not use. `ZOOM_MODE=criterion_4` must stop the session, not quietly measure
+/// nine repetitions of one arm.
+enum ZoomMode { plain, criterion4, criterion8 }
+
+ZoomMode parseZoomMode(String raw) => switch (raw) {
+      'plain' => ZoomMode.plain,
+      'criterion4' => ZoomMode.criterion4,
+      'criterion8' => ZoomMode.criterion8,
+      final other => throw StateError(
+          'ZOOM_MODE must be plain, criterion4 or criterion8; got "$other"'),
+    };
+
+final ZoomMode kZoomMode = parseZoomMode(
+    const String.fromEnvironment('ZOOM_MODE', defaultValue: 'plain'));
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
 /// Always built on [harnessMeasurer], a real `FlutterTextMeasurer` —
 /// `DraftDocument`'s own default is the zero-metrics `InsertionPointMeasurer`,
@@ -513,41 +542,90 @@ Future<void> _driveR2(
     vertices: vertices,
     resolvedBackend: resolvedBackend,
     tileCache: tileCache,
     pumpFrame: _pumpFrame,
     settle: _settle,
     panStep: kPanStep,
   );
 
   // The `tile zoom` phase (Plan 3i, Task 11): `ZOOM_ARMS` repeats of the
   // pinned script, each starting fresh from the same fitted camera `runR2Rig`
   // itself started from, so this arm and Plan 3h's tile-pan arm inside
   // `runR2Rig` describe the same starting state. Off by default -- see
-  // [kZoomArms].
+  // [kZoomArms]. What the repeats are *for* is [kZoomMode].
   if (tileCache != null && kZoomArms > 0) {
     // The pinned reference viewport (§5), not `viewport` above -- see
     // `runTileZoomPhase`'s doc comment for what a differently sized real
     // window means for these numbers.
     const zoomViewport = Size(1600, 1200);
     warnIfZoomViewportMismatch(viewport, zoomViewport);
-    for (var arm = 0; arm < kZoomArms; arm++) {
+
+    // One arm: back to the fitted camera, then the whole pinned script. The
+    // camera reset is here rather than inside the phase because the arms of a
+    // ratio must start from the same camera, and the phase does not own it.
+    Future<ZoomReport> runArm() async {
       camera.value = fittedCamera;
       await _pumpFrame();
-      final zoomReport = await runTileZoomPhase(
+      return runTileZoomPhase(
         camera: camera,
         cache: tileCache,
         pumpFrame: _pumpFrame,
         viewport: zoomViewport,
       );
-      printZoomReport('R2 tile zoom arm $arm ($kEntities)', zoomReport);
+    }
+
+    switch (kZoomMode) {
+      // **Relabelled rather than refused.** Repeats of one configuration are a
+      // real capability -- criterion 2 is a p95 over gesture frames and wants
+      // repeats, not arms -- so refusing here would remove a measurement to
+      // prevent a mislabelling. What made the old output dangerous was that it
+      // printed `arm 0..8` with no flag flipped and nothing naming which arm
+      // was which: the exact shape and labelling of the n=9 interleaved
+      // transcript criteria 4 and 8 call for, with every ratio reading 1.00.
+      // The word "arm" is gone, every line says which flag state it ran at,
+      // and the heading below says what this mode is not.
+      case ZoomMode.plain:
+        print('R2 tile zoom: ZOOM_MODE=plain -- $kZoomArms repeats of the '
+            'pinned script in ONE configuration (no measurement flag '
+            'flipped). This is criterion 2 only. It is NOT criterion 4 or '
+            'criterion 8: those need two arms interleaved, and are '
+            'ZOOM_MODE=criterion4 and ZOOM_MODE=criterion8.');
+        for (var repeat = 0; repeat < kZoomArms; repeat++) {
+          printZoomReport(
+              zoomPlainLabel(
+                  repeat: repeat, repeats: kZoomArms, entities: kEntities),
+              await runArm());
+        }
+      case ZoomMode.criterion4:
+        print('R2 tile zoom: ZOOM_MODE=criterion4 -- $kZoomArms repeats of '
+            "arm A then arm B, interleaved, in one session. Criterion 4's "
+            'ratio is settleWallMs(arm B) / settleWallMs(arm A), per arm.');
+        await runZoomCriterionArms(
+          criterion: ZoomCriterion.four,
+          repeats: kZoomArms,
+          entities: kEntities,
+          cache: tileCache,
+          runArm: runArm,
+        );
+      case ZoomMode.criterion8:
+        print('R2 tile zoom: ZOOM_MODE=criterion8 -- $kZoomArms repeats of '
+            "arm A then arm B, interleaved, in one session. Arm B is Plan "
+            "3h's M4 as a runtime flag, not this plan's M4.");
+        await runZoomCriterionArms(
+          criterion: ZoomCriterion.eight,
+          repeats: kZoomArms,
+          entities: kEntities,
+          cache: tileCache,
+          runArm: runArm,
+        );
     }
   }
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
index 2f7e973..f02544a 100644
--- a/apps/dev_harness_2d/lib/measurement_rig.dart
+++ b/apps/dev_harness_2d/lib/measurement_rig.dart
@@ -682,66 +682,355 @@ Offset zoomFocusFor(Size viewport) =>
 /// print. This check sits at the call site itself, so the warning lands right
 /// next to the numbers it is warning about.
 void warnIfZoomViewportMismatch(Size real, Size pinned) {
   if (real == pinned) return;
   print('  !!! WARNING: tile zoom phase run at window='
       '${real.width.toStringAsFixed(0)}x${real.height.toStringAsFixed(0)}, '
       'not the pinned reference ${pinned.width.toStringAsFixed(0)}x'
       '${pinned.height.toStringAsFixed(0)} -- the numbers below are measured '
       'at the WRONG VIEWPORT and are not comparable to design spec §5 or to '
       'any run at the pinned size !!!');
 }
 
+/// Every `FrameTiming` reported while this log is armed, in delivery order,
+/// attributed to the frames a phase pumped **by ordinal**.
+///
+/// **Why an ordinal and not an arrival window.** `addTimingsCallback` reports
+/// a frame only *after* it has rasterised, and a `pumpFrame` completes at
+/// `SchedulerBinding.endOfFrame` -- the frame's post-frame phase, *before* its
+/// scene rasterises. So the timings that arrive while frame *i* is being
+/// pumped are frame *i-1*'s, or none at all: reading "whatever arrived during
+/// this frame" names the wrong frame systematically rather than occasionally,
+/// and re-registering a callback around a phase boundary drops the tail of one
+/// phase instead of moving it. That is the hazard [runR2Rig] states at its own
+/// registration, and the reason this type exists.
+///
+/// **The rule.** One registration spans every frame the phase pumps; delivery
+/// order is pump order; frame *i*'s timing is the *i*-th one delivered. Frames
+/// pumped before [arm] are therefore poison -- their timings arrive *after*
+/// registration and would take the ordinals of frames that came later -- so a
+/// phase arms this log before its own warm-up frames and excludes the warm-up
+/// ordinals from its sample, rather than arming after them.
+///
+/// The last frames' timings are still in flight when the last pump returns,
+/// which is what [drain] is for.
+class FrameTimingLog {
+  final List<FrameTiming> _reported = <FrameTiming>[];
+  int _pumped = 0;
+  bool _armed = false;
+
+  void _collect(List<FrameTiming> timings) => _reported.addAll(timings);
+
+  /// Registers the one callback that spans the whole phase.
+  void arm() {
+    if (_armed) {
+      throw StateError('FrameTimingLog.arm() twice: one registration spans '
+          'the phase, and a second would double every timing');
+    }
+    SchedulerBinding.instance.addTimingsCallback(_collect);
+    _armed = true;
+  }
+
+  /// Unregisters the callback. Safe to call when never armed, so a caller can
+  /// put it in a `finally`.
+  void disarm() {
+    if (!_armed) return;
+    SchedulerBinding.instance.removeTimingsCallback(_collect);
+    _armed = false;
+  }
+
+  /// How many frames have been pumped through [pump] and [drain]. Also the
+  /// ordinal the next pumped frame will take.
+  int get pumpedFrames => _pumped;
+
+  /// How many timings have been reported so far, across every pumped frame.
+  int get reportedFrames => _reported.length;
+
+  /// Pumps one frame and gives it the next ordinal.
+  Future<void> pump(Future<void> Function() pumpFrame) async {
+    _pumped++;
+    await pumpFrame();
+  }
+
+  /// Pumps bare frames until the frames with ordinals below [upTo] have all
+  /// reported, or until [maxExtraFrames] have been pumped without getting
+  /// there.
+  ///
+  /// **This is the "one extra frame at the end" the attribution needs.** The
+  /// last frame of a phase cannot have reported by the time its own pump
+  /// returns; without a drain its timing is not late, it is *absent*, and the
+  /// phase's last sample would silently read as missing. The drained frames
+  /// take ordinals of their own, so a later phase sharing this log stays
+  /// aligned. It is a bound and not a wait loop: on a device that stops
+  /// reporting altogether this returns rather than hanging, and the shortfall
+  /// shows up as a missing sample the report prints.
+  ///
+  /// Returns how many extra frames it pumped.
+  Future<int> drain(
+    Future<void> Function() pumpFrame, {
+    required int upTo,
+    int maxExtraFrames = 4,
+  }) async {
+    var extra = 0;
+    while (_reported.length < upTo && extra < maxExtraFrames) {
+      await pump(pumpFrame);
+      extra++;
+    }
+    return extra;
+  }
+
+  /// `totalSpan` of the frame at [ordinal] in milliseconds, or null when no
+  /// timing was ever reported for it.
+  ///
+  /// Null rather than `0.0`: a frame that reported nothing is a hole in the
+  /// sample, and zero is a *fast frame*. Publishing one as the other is how a
+  /// composite blit that drew nothing gets read as a settle.
+  double? msAt(int ordinal) => ordinal >= 0 && ordinal < _reported.length
+      ? _reported[ordinal].totalSpan.inMicroseconds / 1000.0
+      : null;
+
+  /// [msAt] over the half-open ordinal range `[start, end)`, holes included.
+  List<double?> msRange(int start, int end) =>
+      <double?>[for (var i = start; i < end; i++) msAt(i)];
+}
+
+/// What [runSettlePhase] measured: the idle settle after a gesture.
+class SettleReport {
+  SettleReport({
+    required this.frames,
+    required this.covered,
+    required this.coveringFrameMs,
+    required this.wallMs,
+    required this.framesMissing,
+  });
+
+  /// How many idle frames elapsed before [TileCache.viewportCovered] first
+  /// read true, or the whole idle budget when it never did (see [covered]).
+  final int frames;
+
+  /// Whether coverage was reached at all inside the idle budget.
+  final bool covered;
+
+  /// `totalSpan` of the single frame at which coverage was first read -- **one
+  /// frame, not the settle**. See [ZoomReport.settleCoveringFrameMs].
+  final double coveringFrameMs;
+
+  /// Wall clock across [frames], summed. See [ZoomReport.settleWallMs].
+  final double wallMs;
+
+  /// How many of those [frames] never reported a timing. Nonzero means both
+  /// figures above are over a short sample and must not be published as they
+  /// stand.
+  final int framesMissing;
+}
+
+/// Idle frames pumped after the gesture, pinned by design spec §5.
+const int kIdleFrames = 30;
+
+/// Throwaway frames pumped at the phase boundary, before the gesture's
+/// counters are reset. Their ordinals are excluded from every published
+/// window -- see [runTileZoomPhase].
+const int kZoomWarmUpFrames = 2;
+
+/// The idle settle that follows the gesture: [idleFrames] bare frames, the
+/// first frame at which [covered] reads true, and the two time figures
+/// criteria 3 and 4 are read off.
+///
+/// **The idle frames drive no camera change at all** -- unlike the forced
+/// no-op `panBy(Offset.zero)` this file's other phases use to force a repaint
+/// once nothing is dirty, an idle frame here is a bare [pumpFrame] call.
+/// `DraftCanvasState`'s own settle notifier
+/// (`draft_canvas.dart:_requestSettleFrame`) is what keeps requesting a real
+/// frame for as long as the cache owes tiles; forcing one artificially would
+/// measure a phase this rig does not drive on a real trackpad gesture's tail.
+///
+/// It pumps the full [idleFrames] even after coverage, so a cache that keeps
+/// asking for frames after covering (which it must not) is exercised the same
+/// way a real gesture's tail would exercise it.
+///
+/// **[covered] is a predicate and not the cache itself** so that this
+/// attribution can be tested at all: [runTileZoomPhase] refuses to run outside
+/// a profile build, and a `TileCache` cannot be made to cover a viewport
+/// without a painted widget. The production call site passes
+/// `() => cache.viewportCovered`.
+Future<SettleReport> runSettlePhase({
+  required FrameTimingLog log,
+  required Future<void> Function() pumpFrame,
+  required bool Function() covered,
+  int idleFrames = kIdleFrames,
+}) async {
+  final firstOrdinal = log.pumpedFrames;
+  var frames = idleFrames;
+  var everCovered = false;
+  for (var i = 0; i < idleFrames; i++) {
+    await log.pump(pumpFrame);
+    // Coverage is read straight after the pump because it is *cache state*,
+    // written during the frame that just ran -- it is only the frame's
+    // *timing* that arrives late, and that is what the ordinal below is for.
+    if (!everCovered && covered()) {
+      everCovered = true;
+      frames = i + 1;
+    }
+  }
+  await log.drain(pumpFrame, upTo: firstOrdinal + idleFrames);
+
+  final ms = log.msRange(firstOrdinal, firstOrdinal + frames);
+  var wallMs = 0.0;
+  var missing = 0;
+  for (final v in ms) {
+    if (v == null) {
+      missing++;
+    } else {
+      wallMs += v;
+    }
+  }
+  return SettleReport(
+    frames: frames,
+    covered: everCovered,
+    coveringFrameMs: ms.isEmpty ? 0.0 : (ms.last ?? 0.0),
+    wallMs: wallMs,
+    framesMissing: missing,
+  );
+}
+
 /// What [runTileZoomPhase] reports: the gesture's frame times and the
 /// cache's counters over it, then the settle that follows.
 class ZoomReport {
   ZoomReport({
     required this.gestureFrameMs,
+    required this.gestureFramesMissing,
     required this.gestureBakes,
     required this.gestureLiveDraws,
-    required this.settleMs,
+    required this.settleCoveringFrameMs,
+    required this.settleWallMs,
     required this.settleFrames,
+    required this.settleCovered,
+    required this.settleFramesMissing,
   });
 
-  /// `totalSpan`, one entry per gesture frame -- 80 entries at the pinned
-  /// script (`2 * kZoomSteps`). p95 over this list is criterion 2.
+  /// Builds a report from a gesture window and the [SettleReport] that
+  /// followed it.
+  factory ZoomReport.from({
+    required List<double?> gestureMs,
+    required int gestureBakes,
+    required int gestureLiveDraws,
+    required SettleReport settle,
+  }) {
+    final frames = <double>[];
+    var missing = 0;
+    for (final v in gestureMs) {
+      if (v == null) {
+        missing++;
+      } else {
+        frames.add(v);
+      }
+    }
+    return ZoomReport(
+      gestureFrameMs: frames,
+      gestureFramesMissing: missing,
+      gestureBakes: gestureBakes,
+      gestureLiveDraws: gestureLiveDraws,
+      settleCoveringFrameMs: settle.coveringFrameMs,
+      settleWallMs: settle.wallMs,
+      settleFrames: settle.frames,
+      settleCovered: settle.covered,
+      settleFramesMissing: settle.framesMissing,
+    );
+  }
+
+  /// `totalSpan`, one entry per gesture frame whose timing was actually
+  /// reported. p95 over this list is criterion 2.
+  ///
+  /// **The 80-entry claim is enforced, not asserted.** The window is the
+  /// ordinal range of the `2 * kZoomSteps` frames the script pumped, so
+  /// `gestureFrameMs.length + gestureFramesMissing == 2 * kZoomSteps` always
+  /// holds, and a short sample shows up as [gestureFramesMissing] rather than
+  /// as a p95 over a silently truncated list. Before the ordinal window, the
+  /// count was 80 by coincidence: the callback was registered after the two
+  /// warm-up frames -- which rasterise before registration and are reported
+  /// after it -- and removed the instant the last frame was pumped, so the
+  /// sample was padded at the head with the two cheapest frames in the phase
+  /// and truncated at the tail by however many timings were still in flight.
+  /// Both errors push p95 down, which is the direction that makes criterion 2
+  /// pass.
   final List<double> gestureFrameMs;
 
+  /// How many of the `2 * kZoomSteps` gesture frames never reported a timing,
+  /// even after [FrameTimingLog.drain]. Zero on a healthy run; anything else
+  /// means [gestureFrameMs] is short and its p95 is not the criterion's.
+  final int gestureFramesMissing;
+
   /// [TileCache.bakeCount] since the counters were reset at the start of the
   /// gesture, read at the gesture's end.
   ///
   /// **This is the budgeted path's unit: once per tile, not once per band.**
   /// Every frame in the 80-frame gesture is a *moving* frame -- the camera
   /// changes every frame by construction -- so [TileCache.paintFrame]'s rest
   /// branch (`_restBake`, counted once per band) never runs during the
   /// gesture; only the ordinary budgeted tile loop could contribute here.
   /// Criterion 1 expects this at zero. A reader comparing this figure
   /// against a settle-phase bake count (band-counted) would be comparing two
   /// different units -- see `TileCache.bakeCount`'s own doc comment.
   final int gestureBakes;
 
   /// [TileCache.liveDrawCount] over the same window as [gestureBakes].
   /// Criterion 1 expects this at zero too.
   final int gestureLiveDraws;
 
-  /// `totalSpan` of the one idle frame at which [TileCache.viewportCovered]
-  /// first became true, or of the last idle frame pumped if 30 idle frames
-  /// never reached coverage. Criterion 3 reads this.
-  final double settleMs;
+  /// `totalSpan` of the **one** idle frame at which [TileCache.viewportCovered]
+  /// first became true, or of the last idle frame pumped if [kIdleFrames]
+  /// never reached coverage. Criterion 3 reads this, and criterion 3 only.
+  ///
+  /// **One frame, and never the settle's duration.** Criterion 4 is wall clock
+  /// across the whole settle and is [settleWallMs]; on the rest-bake arm the
+  /// settle is ~1 baking frame and the two nearly coincide, but on the
+  /// denominator arm the settle is many frames and this figure is the last of
+  /// them alone. A ratio formed from this field compares one frame against one
+  /// frame -- the "two readings straddling the gate" design spec §4 exists to
+  /// prevent.
+  final double settleCoveringFrameMs;
+
+  /// Criterion 4's numerator or denominator, quoting the criterion: **"wall
+  /// clock to a covered viewport, from the first frame after the gesture ends
+  /// to the frame that covers it"**.
+  ///
+  /// The sum of `totalSpan` over idle frames 1..[settleFrames] inclusive --
+  /// the frame that covers the viewport included, the idle frames after it
+  /// excluded. This is the only figure criterion 4's ratio may be formed
+  /// from; see [settleCoveringFrameMs] for why the per-frame figure is not.
+  final double settleWallMs;
 
   /// How many idle frames elapsed before [TileCache.viewportCovered] first
-  /// read true (1 if the very first idle frame after the gesture already
-  /// covers, which is what criterion 3 asserts), or 30 if coverage was never
-  /// reached within the pinned idle-frame budget.
+  /// read true, or [kIdleFrames] if coverage was never reached inside the
+  /// pinned idle-frame budget (which [settleCovered] distinguishes).
+  ///
+  /// **Correct code reads 2, not 1** (Ruling 15 in Plan 3i's ledger). The
+  /// arithmetic: `kRestGateFrames` is 2, so a bake needs two consecutive
+  /// frames on the same camera; the last gesture frame changed the camera, so
+  /// idle frame 1 can only reach `_restGateSteps == 1` and takes
+  /// `paintFrame`'s moving-frame early return; idle frame 2 is the first that
+  /// can bake. Criterion 3's stated "one frame" and the separately pinned
+  /// `kRestGateFrames = 2` cannot both hold, and 1 here is a value only broken
+  /// code produces. `tile_zoom_warmth_test.dart` pins `settleFrames == 2` in
+  /// the other package.
   final int settleFrames;
+
+  /// Whether coverage was reached at all within [kIdleFrames]. False makes
+  /// [settleFrames] a floor rather than a measurement, and both time figures
+  /// meaningless.
+  final bool settleCovered;
+
+  /// How many of the [settleFrames] never reported a timing. See
+  /// [gestureFramesMissing].
+  final int settleFramesMissing;
 }
 
 /// The `tile zoom` phase, pinned by the design spec (§5) and not the
 /// implementer's to choose: [kZoomSteps] frames zooming in at [kZoomFactor]
 /// about [zoomFocusFor], then [kZoomSteps] zooming back out at
 /// `1 / kZoomFactor` about the same point -- one camera change per frame,
 /// matching what a trackpad delivers -- then 30 idle frames, where the
 /// settle is read.
 ///
 /// **[camera] must already be at R2's fitted camera** (the same
 /// `ViewportTransform.fit` the caller's R2 rig used, before that rig's own
 /// scripted motion), so the zoom arm and Plan 3h's tile-pan arm are
@@ -754,147 +1043,147 @@ class ZoomReport {
 /// it into a screen-space anchor the same way `runR2Rig`'s own zoom step
 /// anchors at the fixed `Offset(800, 600)` (that phase's viewport centre)
 /// regardless of what window the app is actually running in. A caller on a
 /// real window of a different size gets a phase that still runs -- `zoomAt`
 /// accepts any finite, positive factor at any screen point -- but the
 /// focal point then sits at a different fraction of the *real* viewport than
 /// 30%/70%, and comparing its numbers against another run's figures, or
 /// against the design spec's priced predictions, is only sound once the
 /// window is confirmed to actually be the reference size. `main.dart`'s
 /// `RUN_R2` mode prints the real window size for exactly this reason; a
 /// caller of this phase should do the same.
 ///
-/// The idle frames drive no camera change at all -- unlike the forced
-/// no-op `panBy(Offset.zero)` this file's other phases use to force a final
-/// repaint once nothing is dirty, an idle frame here is a bare [pumpFrame]
-/// call. `DraftCanvasState`'s own settle notifier
-/// (`draft_canvas.dart:_requestSettleFrame`) is what keeps requesting a real
-/// frame for as long as the cache owes tiles; forcing one artificially would
-/// measure a phase this rig does not actually drive on a real trackpad
-/// gesture's tail.
+/// The idle settle after the gesture is [runSettlePhase]'s, and its doc
+/// comment carries why an idle frame here is a bare [pumpFrame] call.
+///
+/// **Every frame this phase pumps goes through one [FrameTimingLog].** The
+/// warm-up frames are pumped *after* the log is armed and then excluded by
+/// ordinal, rather than pumped before registration and silently charged to the
+/// gesture; the gesture window is an ordinal range rather than "whatever
+/// arrived between two registrations"; and the settle's last frames are
+/// drained rather than dropped. See [FrameTimingLog] for why every one of
+/// those is the same bug.
 Future<ZoomReport> runTileZoomPhase({
   required CameraController camera,
   required TileCache cache,
   required Future<void> Function() pumpFrame,
   required Size viewport,
 }) async {
   refuseDebugMode();
   final focus = zoomFocusFor(viewport);
-
-  // Two throwaway frames before the counters reset, the same boundary slack
-  // `runTilePhases`'s own `phase()` helper takes: a `FrameTiming` is reported
-  // after its frame rasterises, so the phase boundary needs a frame or two of
-  // slack the gesture itself must not be charged for.
-  for (var i = 0; i < 2; i++) {
-    camera.panBy(Offset.zero);
-    await pumpFrame();
-  }
-
-  final gestureTimings = <FrameTiming>[];
-  void collectGesture(List<FrameTiming> t) => gestureTimings.addAll(t);
-  SchedulerBinding.instance.addTimingsCallback(collectGesture);
-  // Warm-up excluded: reset only after the fitted camera has settled (the
-  // two throwaway frames above), per §5.
-  cache.resetCounters();
+  final log = FrameTimingLog()..arm();
   try {
+    // Two throwaway frames before the counters reset, the same boundary slack
+    // `runTilePhases`'s own `phase()` helper takes -- but pumped *after* the
+    // log is armed, so their timings land on ordinals 0 and 1 and are excluded
+    // by the gesture window below. Pumped before arming, they would rasterise
+    // before registration, be reported after it, and take the first two
+    // gesture ordinals: a no-op repaint of a covered generation is the
+    // cheapest frame in the phase, and two of them at the head of the sample
+    // push p95 down.
+    for (var i = 0; i < kZoomWarmUpFrames; i++) {
+      camera.panBy(Offset.zero);
+      await log.pump(pumpFrame);
+    }
+
+    // Warm-up excluded: reset only after the fitted camera has settled (the
+    // two throwaway frames above), per §5.
+    final gestureStart = log.pumpedFrames;
+    cache.resetCounters();
     for (var i = 0; i < kZoomSteps; i++) {
       camera.zoomAt(focus, kZoomFactor);
-      await pumpFrame();
+      await log.pump(pumpFrame);
     }
     for (var i = 0; i < kZoomSteps; i++) {
       camera.zoomAt(focus, 1 / kZoomFactor);
-      await pumpFrame();
+      await log.pump(pumpFrame);
     }
-  } finally {
-    SchedulerBinding.instance.removeTimingsCallback(collectGesture);
-  }
-  final gestureBakes = cache.bakeCount;
-  final gestureLiveDraws = cache.liveDrawCount;
-  final gestureFrameMs = [
-    for (final t in gestureTimings) t.totalSpan.inMicroseconds / 1000.0
-  ];
+    // Read before the settle: the settle bakes, and these two counters are
+    // the gesture's.
+    final gestureBakes = cache.bakeCount;
+    final gestureLiveDraws = cache.liveDrawCount;
 
-  // 30 idle frames. No camera nudge -- see the doc comment above for why a
-  // bare pumpFrame is the honest idle frame here. Tracks the first frame at
-  // which the viewport becomes covered, which is what criterion 3 reads;
-  // still pumps the full 30 so a cache that keeps asking for frames after
-  // coverage (which it must not) is exercised the same way a real trackpad
-  // gesture's tail would exercise it.
-  const idleFrames = 30;
-  var settleFrames = idleFrames;
-  var settleMs = 0.0;
-  var covered = false;
-  for (var i = 0; i < idleFrames; i++) {
-    final idleTimings = <FrameTiming>[];
-    void collectIdle(List<FrameTiming> t) => idleTimings.addAll(t);
-    SchedulerBinding.instance.addTimingsCallback(collectIdle);
-    try {
-      await pumpFrame();
-    } finally {
-      SchedulerBinding.instance.removeTimingsCallback(collectIdle);
-    }
-    final frameMs = idleTimings.isEmpty
-        ? 0.0
-        : idleTimings.last.totalSpan.inMicroseconds / 1000.0;
-    if (!covered && cache.viewportCovered) {
-      covered = true;
-      settleFrames = i + 1;
-      settleMs = frameMs;
-    } else if (!covered) {
-      // Not yet covered: keep the running "last frame pumped" figure, so a
-      // script that never reaches coverage within the idle budget still
-      // reports something rather than 0.0.
-      settleMs = frameMs;
-    }
-  }
+    final settle = await runSettlePhase(
+      log: log,
+      pumpFrame: pumpFrame,
+      covered: () => cache.viewportCovered,
+    );
 
-  return ZoomReport(
-    gestureFrameMs: gestureFrameMs,
-    gestureBakes: gestureBakes,
-    gestureLiveDraws: gestureLiveDraws,
-    settleMs: settleMs,
-    settleFrames: settleFrames,
-  );
+    // The gesture window, read only now: the settle's own drain is what
+    // brought the last gesture frames' timings in.
+    return ZoomReport.from(
+      gestureMs: log.msRange(gestureStart, gestureStart + 2 * kZoomSteps),
+      gestureBakes: gestureBakes,
+      gestureLiveDraws: gestureLiveDraws,
+      settle: settle,
+    );
+  } finally {
+    log.disarm();
+  }
 }
 
 /// Prints a [ZoomReport] the way [report] prints a plain frame-timing list,
 /// plus the counters [report] alone cannot see.
 ///
 /// **`gestureBakes` is the budgeted, per-tile unit of [TileCache.bakeCount],
 /// not the per-band unit the rest bake counts in.** See [ZoomReport
 /// .gestureBakes]'s own doc comment for why: every gesture frame is moving,
 /// so the rest path never contributes to it. A reader comparing this figure
 /// against a Plan 3g or 3h transcript, where `bakeCount` always meant tiles,
 /// is comparing like with like here -- but comparing it against this same
 /// cache's post-settle `bakeCount` would not be, because a rest bake (if one
 /// fired during the idle frames this report also covers) counts bands.
+/// **Every line carries [label].** An interleaved run prints two arms per
+/// repeat and the arms differ only in which flag was flipped; a continuation
+/// line indented under the wrong heading is a number attributed to the wrong
+/// arm, which is the failure mode of this whole measurement.
 void printZoomReport(String label, ZoomReport r) {
   if (r.gestureFrameMs.isEmpty) {
     print('$label: no gesture frames recorded');
   } else {
     final sorted = [...r.gestureFrameMs]..sort();
     var sum = 0.0;
     for (final v in sorted) {
       sum += v;
     }
     print('$label gestureFrames=${sorted.length} '
         'p50=${sorted[(sorted.length * 0.5).floor()].toStringAsFixed(2)}ms '
         'p95=${sorted[(sorted.length * 0.95).floor()].toStringAsFixed(2)}ms '
         'max=${sorted.last.toStringAsFixed(2)}ms '
         'mean=${(sum / sorted.length).toStringAsFixed(2)}ms');
   }
-  print('  gestureBakes=${r.gestureBakes}(tiles, budgeted path) '
+  print('$label   gestureBakes=${r.gestureBakes}(tiles, budgeted path) '
       'gestureLiveDraws=${r.gestureLiveDraws}');
-  print('  settleFrames=${r.settleFrames} '
-      'settleMs=${r.settleMs.toStringAsFixed(2)}');
+  // Two time figures, never one. `settleWallMs` is criterion 4's wall clock
+  // across the settle; `coveringFrameMs` is criterion 3's single frame. They
+  // coincide only when the settle is one frame long, which is the arm the
+  // ratio's numerator comes from and not the arm its denominator comes from.
+  print('$label   settleFrames=${r.settleFrames} '
+      'covered=${r.settleCovered} '
+      'settleWallMs=${r.settleWallMs.toStringAsFixed(2)}(criterion 4, '
+      'wall clock over the settle) '
+      'coveringFrameMs=${r.settleCoveringFrameMs.toStringAsFixed(2)}'
+      '(criterion 3, that one frame)');
+  if (!r.settleCovered) {
+    print('$label   !!! WARNING: the viewport never covered within '
+        '$kIdleFrames idle frames -- settleFrames is a floor, and neither '
+        'time figure above is a settle !!!');
+  }
+  final missing = r.gestureFramesMissing + r.settleFramesMissing;
+  if (missing > 0) {
+    print('$label   !!! WARNING: $missing frame(s) reported no FrameTiming '
+        '(gesture ${r.gestureFramesMissing} of ${2 * kZoomSteps}, settle '
+        '${r.settleFramesMissing} of ${r.settleFrames}) -- the figures above '
+        'are over a SHORT SAMPLE and are not comparable !!!');
+  }
 }
 
 /// Runs [rest] and [tiled] alternately — `rest, tiled, rest, tiled, …` — for
 /// [arms] repeats of each, awaiting every callback before starting the next.
 ///
 /// **The interleaved unit is one whole arm, not one frame.** An arm is a
 /// complete phase — a zoom script, its settle and its report — and splitting
 /// it finer would interleave two half-measured caches into each other's
 /// generations. What is refused here is the *blocked* ordering: all of one arm
 /// and then all of the other.
 ///
 /// **Why it matters, in this repository's own numbers.** A measurement session
@@ -916,12 +1205,193 @@ void printZoomReport(String label, ZoomReport r) {
 /// number of repeats, and an off-by-one here would silently publish an n=1
 /// row under an n=0 heading.
 Future<void> runInterleaved({
   required int arms,
   required Future<void> Function() rest,
   required Future<void> Function() tiled,
 }) async {
   for (var i = 0; i < arms; i++) {
     await rest();
     await tiled();
   }
 }
+
+/// One arm of an interleaved zoom measurement: which criterion it belongs to,
+/// which side of that criterion's ratio it is, and the runtime flag that makes
+/// it that side.
+///
+/// **An arm is a whole configuration, not a flag.** [applyTo] writes *both*
+/// measurement flags on every arm, so an arm's label describes the cache
+/// completely and no leftover from a previous criterion's run can sit under a
+/// label that does not mention it.
+enum ZoomArm {
+  /// Criterion 4's numerator: the rest bake this plan added.
+  restBakeOn(
+    criterion: 4,
+    side: 'A',
+    flag: 'debugRestBakeDisabled=false',
+    description: "rest bake ON -- criterion 4's numerator",
+  ),
+
+  /// Criterion 4's denominator: "today's behaviour with the rest bake
+  /// disabled", which is the tiled fill the rest bake replaces.
+  restBakeOff(
+    criterion: 4,
+    side: 'B',
+    flag: 'debugRestBakeDisabled=true',
+    description: "rest bake OFF -- criterion 4's denominator, the tiled fill",
+  ),
+
+  /// Criterion 8's numerator: the narrowed band query.
+  narrowQuery(
+    criterion: 8,
+    side: 'A',
+    flag: 'debugFullViewportQuery=false',
+    description: "narrow band query -- criterion 8's numerator",
+  ),
+
+  /// Criterion 8's denominator, which is **Plan 3h's M4** and not this plan's:
+  /// mutant numbering is per-plan and M4/M5 collide between the two logs, so
+  /// the label says whose M4 it is.
+  fullViewportQuery(
+    criterion: 8,
+    side: 'B',
+    flag: 'debugFullViewportQuery=true',
+    description: "full-viewport query (Plan 3h's M4) -- criterion 8's "
+        'denominator',
+  );
+
+  const ZoomArm({
+    required this.criterion,
+    required this.side,
+    required this.flag,
+    required this.description,
+  });
+
+  /// Which numbered criterion in design spec §4 this arm belongs to.
+  final int criterion;
+
+  /// `A` for the criterion's numerator, `B` for its denominator.
+  final String side;
+
+  /// The flag state that defines this arm, printed verbatim in its label so a
+  /// reader never has to infer which switch was flipped.
+  final String flag;
+
+  /// What the arm is, in the criterion's own words.
+  final String description;
+
+  /// Puts [cache] into this arm's configuration.
+  ///
+  /// **No generation reset, deliberately.** A zoom round trip leaves no warm
+  /// tiles: the excursion's first zoom frame already fails
+  /// `TileGrid.matchesScale`, the generation is retired and its tiles disposed,
+  /// and the trip lands on scale `1.4000000000000017` rather than `1.4`. That
+  /// was settled by test rather than by argument -- see
+  /// `tile_zoom_warmth_test.dart` in `jet_cad_2d_flutter` -- so each arm
+  /// genuinely re-bakes and neither arm's settle is trivially covered. Only
+  /// the flags are written here.
+  void applyTo(TileCache cache) {
+    cache.debugRestBakeDisabled = this == ZoomArm.restBakeOff;
+    cache.debugFullViewportQuery = this == ZoomArm.fullViewportQuery;
+  }
+}
+
+/// A criterion measured as a ratio between two interleaved [ZoomArm]s.
+enum ZoomCriterion {
+  /// Criterion 4: rest-bake wall clock against the tiled fill it replaces.
+  four(numerator: ZoomArm.restBakeOn, denominator: ZoomArm.restBakeOff),
+
+  /// Criterion 8: Plan 3h's criterion 3, re-measured at n=7-9 interleaved.
+  eight(numerator: ZoomArm.narrowQuery, denominator: ZoomArm.fullViewportQuery);
+
+  const ZoomCriterion({required this.numerator, required this.denominator});
+
+  final ZoomArm numerator;
+  final ZoomArm denominator;
+}
+
+/// The label every line of an arm's report is printed under.
+///
+/// It names the criterion, the repeat, the side of the ratio, the exact flag
+/// state and the entity count -- everything a reader needs to attribute the
+/// numbers without reading the source that produced them. A transcript a
+/// reader cannot attribute is the failure mode this measurement has already
+/// been bitten by: nine repetitions of one arm, printed as `arm 0..8`, with
+/// nothing naming which arm was which and every ratio reading 1.00.
+String zoomArmLabel(
+  ZoomArm arm, {
+  required int repeat,
+  required int repeats,
+  required int entities,
+}) =>
+    'R2 tile zoom c${arm.criterion} repeat ${repeat + 1}/$repeats '
+    'arm ${arm.side} [${arm.flag}] ${arm.description} ($entities)';
+
+/// The label a repeat of the **plain** zoom mode prints under: one
+/// configuration, repeated, with no measurement flag flipped.
+///
+/// **It must not be mistakable for [zoomArmLabel]'s output.** The word "arm"
+/// appears only in the phrase that denies it, both flag states are printed
+/// even though neither was flipped, and the criterion named is 2. What this
+/// replaces printed `R2 tile zoom arm 0..8` -- the shape and the labelling of
+/// the n=9 interleaved transcript criteria 4 and 8 call for, produced by a run
+/// in which no flag was ever flipped and every ratio would read 1.00.
+String zoomPlainLabel({
+  required int repeat,
+  required int repeats,
+  required int entities,
+}) =>
+    'R2 tile zoom plain repeat ${repeat + 1}/$repeats '
+    '[debugRestBakeDisabled=false debugFullViewportQuery=false] '
+    'criterion 2 only, NOT an interleaved arm ($entities)';
+
+/// Drives [criterion]'s two arms, [repeats] times, alternating them and
+/// flipping the flag that makes each arm the arm its label names.
+///
+/// This is the *arrangement* design spec §4 pins as part of criterion 4 and
+/// criterion 8: same session, interleaved, never blocked, and every arm's
+/// number reported rather than only the aggregate. [runInterleaved] owns the
+/// ordering; this owns the configuration and the labelling.
+///
+/// [runArm] runs one whole zoom phase and returns its report -- it is
+/// responsible for restoring the camera to the fitted state first, because
+/// the arms of a ratio must start from the same camera. [emit] is
+/// [printZoomReport] in production and a recorder in tests.
+///
+/// The flags are restored to their defaults when the run ends, however it
+/// ends: a later phase in the same session must not inherit a measurement
+/// switch. The cache's *generations* are deliberately left alone -- see
+/// [ZoomArm.applyTo].
+Future<void> runZoomCriterionArms({
+  required ZoomCriterion criterion,
+  required int repeats,
+  required int entities,
+  required TileCache cache,
+  required Future<ZoomReport> Function() runArm,
+  void Function(String label, ZoomReport report) emit = printZoomReport,
+}) async {
+  var repeat = 0;
+  try {
+    await runInterleaved(
+      arms: repeats,
+      rest: () async {
+        final arm = criterion.numerator;
+        arm.applyTo(cache);
+        final label = zoomArmLabel(arm,
+            repeat: repeat, repeats: repeats, entities: entities);
+        emit(label, await runArm());
+      },
+      tiled: () async {
+        final arm = criterion.denominator;
+        arm.applyTo(cache);
+        final label = zoomArmLabel(arm,
+            repeat: repeat, repeats: repeats, entities: entities);
+        emit(label, await runArm());
+        repeat++;
+      },
+    );
+  } finally {
+    cache.debugRestBakeDisabled = false;
+    cache.debugFullViewportQuery = false;
+  }
+}
diff --git a/apps/dev_harness_2d/test/settle_attribution_test.dart b/apps/dev_harness_2d/test/settle_attribution_test.dart
new file mode 100644
index 0000000..4069af0
--- /dev/null
+++ b/apps/dev_harness_2d/test/settle_attribution_test.dart
@@ -0,0 +1,341 @@
+// Which frame the settle's numbers are read off.
+//
+// **The defect this file exists for.** A `FrameTiming` is delivered only after
+// its frame has rasterised, and `pumpFrame` completes at
+// `SchedulerBinding.endOfFrame` -- the frame's post-frame phase, *before* the
+// scene rasterises. So the timings that arrive while frame *i* is being pumped
+// belong to frame *i-1*. The settle used to register a fresh timings callback
+// around each single `await pumpFrame()` and read `.last` out of it, which
+// therefore reported the **previous** frame's `totalSpan` under the label "the
+// frame that covered the viewport" -- and on correct code the covering frame is
+// idle frame 2 (Ruling 15), so the published figure was the in-between frame:
+// a composite blit that draws nothing and is essentially free. `settleMs` is
+// the only time value criteria 3 and 4 are read off.
+//
+// **How the fake frames below model that.** `_FrameDriver.pump` renders frame
+// *i* and, in the same call, reports frame *i-1*'s timing -- exactly the
+// one-frame lag the engine has. Nothing here measures anything: the costs are
+// chosen, not observed, so that attribution is the only thing under test. The
+// device runs are Plan 3i's Tasks 12 and 13 and are not these tests.
+//
+// `runSettlePhase` and not `runTileZoomPhase` because the latter opens with
+// `refuseDebugMode()` -- correctly, since a debug frame time means nothing --
+// and `flutter test` is a debug build. The attribution under test is all in
+// `runSettlePhase`, which is the production settle: `runTileZoomPhase` calls
+// it with `() => cache.viewportCovered`.
+import 'package:dev_harness_2d/measurement_rig.dart';
+import 'package:flutter/scheduler.dart';
+import 'package:flutter_test/flutter_test.dart';
+
+/// A `FrameTiming` whose `totalSpan` is exactly [ms] -- `rasterFinish` minus
+/// `vsyncStart`, which is the only field any of these tests reads.
+FrameTiming _timing(double ms, int frameNumber) {
+  final us = (ms * 1000).round();
+  return FrameTiming(
+    vsyncStart: 0,
+    buildStart: 0,
+    buildFinish: us ~/ 2,
+    rasterStart: us ~/ 2,
+    rasterFinish: us,
+    rasterFinishWallTime: us,
+    frameNumber: frameNumber,
+  );
+}
+
+/// Pumps frames that report their timings one frame late, the way the engine
+/// does.
+class _FrameDriver {
+  _FrameDriver({required this.costMs, this.tailCostMs = 4.0});
+
+  /// `totalSpan` of frame *i*, by ordinal. Frames past the end cost
+  /// [tailCostMs].
+  final List<double> costMs;
+  final double tailCostMs;
+
+  /// How many frames have been pumped.
+  int pumped = 0;
+
+  /// The ordinal of the next frame whose timing is still owed.
+  int _delivered = 0;
+
+  double costOf(int ordinal) =>
+      ordinal < costMs.length ? costMs[ordinal] : tailCostMs;
+
+  Future<void> pump() async {
+    pumped++;
+    // At most one frame in flight: pumping frame *i* is what lets frame *i-1*'s
+    // timing arrive. The last frame pumped is therefore always still owed --
+    // which is what `FrameTimingLog.drain` exists to collect.
+    if (_delivered < pumped - 1) {
+      final ordinal = _delivered++;
+      SchedulerBinding.instance.platformDispatcher.onReportTimings!(
+        <FrameTiming>[_timing(costOf(ordinal), ordinal)],
+      );
+    }
+    await Future<void>.delayed(Duration.zero);
+  }
+}
+
+void main() {
+  TestWidgetsFlutterBinding.ensureInitialized();
+
+  test('the covering frame is the one reported, not the frame before it',
+      () async {
+    // Idle frame 2 covers -- the count Ruling 15 derives from
+    // `kRestGateFrames = 2` -- and it is the expensive one. Frame 1 is the
+    // in-between composite blit: cheap, and what the old attribution published.
+    final driver = _FrameDriver(costMs: <double>[4.0, 90.0]);
+    final log = FrameTimingLog()..arm();
+    final SettleReport settle;
+    try {
+      settle = await runSettlePhase(
+        log: log,
+        pumpFrame: driver.pump,
+        covered: () => driver.pumped >= 2,
+        idleFrames: 5,
+      );
+    } finally {
+      log.disarm();
+    }
+
+    expect(settle.frames, 2,
+        reason: 'coverage was declared on the second idle frame');
+    expect(settle.covered, isTrue);
+    expect(settle.framesMissing, 0,
+        reason: 'both settle frames must have reported a timing');
+    expect(settle.coveringFrameMs, closeTo(90.0, 1e-9),
+        reason: 'the covering frame cost 90ms; 4ms is the frame before it, '
+            'which is what reading the arrival window rather than the ordinal '
+            'reports');
+  });
+
+  test('the settle frame moves the reported figure', () async {
+    // The same script, with the covering frame made arbitrarily expensive. If
+    // the reported figure is read off the frame before it, this reads 4.0 in
+    // both arms and the settle figure is inert -- a number that cannot move is
+    // not a measurement.
+    Future<SettleReport> run(double coveringCost) async {
+      final driver = _FrameDriver(costMs: <double>[4.0, coveringCost]);
+      final log = FrameTimingLog()..arm();
+      try {
+        return await runSettlePhase(
+          log: log,
+          pumpFrame: driver.pump,
+          covered: () => driver.pumped >= 2,
+          idleFrames: 5,
+        );
+      } finally {
+        log.disarm();
+      }
+    }
+
+    final cheap = await run(9.0);
+    final dear = await run(900.0);
+    expect(cheap.coveringFrameMs, closeTo(9.0, 1e-9));
+    expect(dear.coveringFrameMs, closeTo(900.0, 1e-9));
+    expect(dear.coveringFrameMs - cheap.coveringFrameMs, closeTo(891.0, 1e-9),
+        reason: 'the settle figure must track the settle frame');
+  });
+
+  test('wall clock over the settle is the sum, not the last frame', () async {
+    // Criterion 4 is "wall clock to a covered viewport, from the first frame
+    // after the gesture ends to the frame that covers it". A many-frame settle
+    // is the denominator arm's shape, and the last frame alone is not it.
+    final driver = _FrameDriver(costMs: <double>[5.0, 6.0, 90.0]);
+    final log = FrameTimingLog()..arm();
+    final SettleReport settle;
+    try {
+      settle = await runSettlePhase(
+        log: log,
+        pumpFrame: driver.pump,
+        covered: () => driver.pumped >= 3,
+        idleFrames: 6,
+      );
+    } finally {
+      log.disarm();
+    }
+
+    expect(settle.frames, 3);
+    expect(settle.coveringFrameMs, closeTo(90.0, 1e-9));
+    expect(settle.wallMs, closeTo(101.0, 1e-9),
+        reason: '5 + 6 + 90 over the three frames of the settle; the idle '
+            'frames after coverage are not part of it');
+  });
+
+  test('the idle frames after coverage are not charged to the settle',
+      () async {
+    // Frames 4 and 5 are pumped -- a cache that keeps asking for frames after
+    // it covers must still be exercised -- but they are after the settle and
+    // their cost is not criterion 4's.
+    final driver =
+        _FrameDriver(costMs: <double>[5.0, 6.0, 500.0, 500.0], tailCostMs: 0.0);
+    final log = FrameTimingLog()..arm();
+    final SettleReport settle;
+    try {
+      settle = await runSettlePhase(
+        log: log,
+        pumpFrame: driver.pump,
+        covered: () => driver.pumped >= 2,
+        idleFrames: 5,
+      );
+    } finally {
+      log.disarm();
+    }
+
+    expect(settle.frames, 2);
+    expect(settle.wallMs, closeTo(11.0, 1e-9));
+    expect(driver.pumped, greaterThanOrEqualTo(5),
+        reason: 'the full idle budget is still pumped');
+  });
+
+  test('the last idle frame is drained rather than dropped', () async {
+    // Coverage on the very last idle frame: its own timing cannot have arrived
+    // by the time its pump returns, so without the drain it is absent and the
+    // figure reads 0.0 -- a fast frame, which is how a dropped sample gets
+    // published as a good one.
+    final driver = _FrameDriver(costMs: <double>[1.0, 2.0, 3.0, 42.0]);
+    final log = FrameTimingLog()..arm();
+    final SettleReport settle;
+    try {
+      settle = await runSettlePhase(
+        log: log,
+        pumpFrame: driver.pump,
+        covered: () => driver.pumped >= 4,
+        idleFrames: 4,
+      );
+    } finally {
+      log.disarm();
+    }
+
+    expect(settle.frames, 4);
+    expect(settle.framesMissing, 0);
+    expect(settle.coveringFrameMs, closeTo(42.0, 1e-9));
+    expect(settle.wallMs, closeTo(48.0, 1e-9));
+    expect(driver.pumped, 5, reason: 'one extra frame collected the last one');
+  });
+
+  test('a settle that never covers says so', () async {
+    final driver = _FrameDriver(costMs: <double>[7.0, 7.0, 7.0]);
+    final log = FrameTimingLog()..arm();
+    final SettleReport settle;
+    try {
+      settle = await runSettlePhase(
+        log: log,
+        pumpFrame: driver.pump,
+        covered: () => false,
+        idleFrames: 3,
+      );
+    } finally {
+      log.disarm();
+    }
+
+    expect(settle.covered, isFalse);
+    expect(settle.frames, 3, reason: 'the whole idle budget, as a floor');
+    expect(settle.wallMs, closeTo(21.0, 1e-9));
+  });
+
+  test('a frame that never reports is a hole, not a zero', () async {
+    // A driver that stops reporting altogether: the drain gives up after its
+    // bound rather than hanging, and the shortfall is counted rather than
+    // being averaged in as a free frame.
+    final log = FrameTimingLog()..arm();
+    final SettleReport settle;
+    try {
+      settle = await runSettlePhase(
+        log: log,
+        pumpFrame: () async {},
+        covered: () => true,
+        idleFrames: 3,
+      );
+    } finally {
+      log.disarm();
+    }
+
+    expect(settle.frames, 1);
+    expect(settle.framesMissing, 1);
+    expect(settle.wallMs, 0.0);
+  });
+
+  test('the gesture window excludes the warm-up frames and keeps its tail',
+      () async {
+    // The whole phase's shape, without the parts `runTileZoomPhase` cannot run
+    // in a debug build: two warm-up frames, a gesture, then a settle. The warm-
+    // ups are the cheapest frames in the phase (a no-op repaint of a covered
+    // generation) and the tail frames are among the dearest, so a sample padded
+    // at the head and truncated at the tail is one whose p95 reads low.
+    const gestureFrames = 2 * kZoomSteps;
+    final costs = <double>[
+      1.0, 1.0, // the two warm-up frames
+      for (var i = 0; i < gestureFrames - 1; i++) 10.0,
+      77.0, // the last gesture frame
+    ];
+    final driver = _FrameDriver(costMs: costs, tailCostMs: 3.0);
+    final log = FrameTimingLog()..arm();
+    final List<double?> gestureMs;
+    try {
+      for (var i = 0; i < kZoomWarmUpFrames; i++) {
+        await log.pump(driver.pump);
+      }
+      final gestureStart = log.pumpedFrames;
+      for (var i = 0; i < gestureFrames; i++) {
+        await log.pump(driver.pump);
+      }
+      await runSettlePhase(
+        log: log,
+        pumpFrame: driver.pump,
+        covered: () => true,
+        idleFrames: 2,
+      );
+      gestureMs = log.msRange(gestureStart, gestureStart + gestureFrames);
+    } finally {
+      log.disarm();
+    }
+
+    final report = ZoomReport.from(
+      gestureMs: gestureMs,
+      gestureBakes: 0,
+      gestureLiveDraws: 0,
+      settle: SettleReport(
+        frames: 1,
+        covered: true,
+        coveringFrameMs: 3.0,
+        wallMs: 3.0,
+        framesMissing: 0,
+      ),
+    );
+
+    expect(report.gestureFramesMissing, 0);
+    expect(report.gestureFrameMs.length, gestureFrames,
+        reason: 'the 80-entry claim, enforced by the ordinal window');
+    expect(report.gestureFrameMs.first, closeTo(10.0, 1e-9),
+        reason: 'the first gesture frame, not a 1ms warm-up frame');
+    expect(report.gestureFrameMs.last, closeTo(77.0, 1e-9),
+        reason: 'the last gesture frame, which the old registration dropped');
+    expect(report.gestureFrameMs.where((v) => v == 1.0), isEmpty,
+        reason: 'no warm-up frame may appear in the gesture sample');
+  });
+
+  test('a short sample is counted, and length plus missing is the script',
+      () async {
+    // `gestureFrameMs.length + gestureFramesMissing == 2 * kZoomSteps` is the
+    // invariant that makes the 80-entry claim enforced rather than asserted.
+    final report = ZoomReport.from(
+      gestureMs: <double?>[
+        for (var i = 0; i < 2 * kZoomSteps; i++) i.isEven ? 10.0 : null,
+      ],
+      gestureBakes: 0,
+      gestureLiveDraws: 0,
+      settle: SettleReport(
+        frames: 2,
+        covered: true,
+        coveringFrameMs: 9.0,
+        wallMs: 12.0,
+        framesMissing: 0,
+      ),
+    );
+
+    expect(report.gestureFrameMs.length + report.gestureFramesMissing,
+        2 * kZoomSteps);
+    expect(report.gestureFramesMissing, kZoomSteps);
+  });
+}
diff --git a/apps/dev_harness_2d/test/zoom_arm_wiring_test.dart b/apps/dev_harness_2d/test/zoom_arm_wiring_test.dart
new file mode 100644
index 0000000..7b30cba
--- /dev/null
+++ b/apps/dev_harness_2d/test/zoom_arm_wiring_test.dart
@@ -0,0 +1,247 @@
+// Whether an interleaved run's arms are the arms its transcript says they are.
+//
+// **The defect this file exists for.** `runInterleaved` had no production
+// caller: `main.dart` ran `ZOOM_ARMS` repeats of one configuration and printed
+// them as `R2 tile zoom arm 0..8` -- the exact shape and labelling of the n=9
+// interleaved transcript criteria 4 and 8 call for -- while neither
+// `debugRestBakeDisabled` nor `debugFullViewportQuery` was ever set. Every
+// ratio a reader formed from that transcript would have read **1.00**, and the
+// degenerate number would have landed in a document of record with nothing to
+// contradict it. Ruling 14 built the two flags for exactly this; nothing
+// flipped them.
+//
+// **What is tested here, and what is not.** The device runs are Plan 3i's
+// Tasks 12 and 13 and are blocked on machine power, so no number appears in
+// this file. What is testable without a device is everything that decides
+// whether the numbers *mean* what the transcript claims: the arms alternate,
+// the flag named by an arm's label is the flag actually set while that arm
+// runs, each arm's label is distinguishable from the other's and from a plain
+// repeat's, and the flags do not outlive the run.
+import 'dart:async';
+
+import 'package:dev_harness_2d/main.dart';
+import 'package:dev_harness_2d/measurement_rig.dart';
+import 'package:flutter_test/flutter_test.dart';
+import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
+
+/// A report with no measurement in it: these tests drive the wiring, and a
+/// figure here would be a fabricated one.
+ZoomReport _emptyReport() => ZoomReport.from(
+      gestureMs: <double?>[],
+      gestureBakes: 0,
+      gestureLiveDraws: 0,
+      settle: SettleReport(
+        frames: 2,
+        covered: true,
+        coveringFrameMs: 0.0,
+        wallMs: 0.0,
+        framesMissing: 0,
+      ),
+    );
+
+/// What one arm's callback saw: the label it was printed under, and the cache
+/// flags as they stood *while the arm ran*.
+class _Seen {
+  _Seen(this.label, this.restBakeDisabled, this.fullViewportQuery);
+
+  final String label;
+  final bool restBakeDisabled;
+  final bool fullViewportQuery;
+}
+
+void main() {
+  /// Runs [criterion]'s arms against a real [TileCache], recording the flag
+  /// state observed inside each arm.
+  Future<(List<_Seen>, TileCache)> drive(
+    ZoomCriterion criterion, {
+    required int repeats,
+  }) async {
+    final cache = TileCache();
+    final labels = <String>[];
+    final flags = <(bool, bool)>[];
+    await runZoomCriterionArms(
+      criterion: criterion,
+      repeats: repeats,
+      entities: 50000,
+      cache: cache,
+      runArm: () async {
+        // Read inside the arm, not after it: a flag flipped after the phase
+        // ran would label the arm correctly and measure the other one.
+        flags.add((cache.debugRestBakeDisabled, cache.debugFullViewportQuery));
+        return _emptyReport();
+      },
+      emit: (label, report) => labels.add(label),
+    );
+    expect(labels.length, flags.length,
+        reason: 'one label emitted per arm run, in arm order');
+    return (
+      <_Seen>[
+        for (var i = 0; i < flags.length; i++)
+          _Seen(labels[i], flags[i].$1, flags[i].$2),
+      ],
+      cache,
+    );
+  }
+
+  test('criterion 4 alternates its arms and flips only its own flag', () async {
+    final (seen, cache) = await drive(ZoomCriterion.four, repeats: 3);
+
+    expect(seen.length, 6, reason: 'three repeats of two arms');
+    expect(
+      <bool>[for (final s in seen) s.restBakeDisabled],
+      <bool>[false, true, false, true, false, true],
+      reason: 'rest bake on for the numerator, off for the denominator, '
+          'alternating -- never all of one arm and then all of the other',
+    );
+    expect(
+      seen.every((s) => !s.fullViewportQuery),
+      isTrue,
+      reason: "criterion 8's flag has no business being set in criterion 4's "
+          'run: an arm is a whole configuration',
+    );
+    expect(cache.debugRestBakeDisabled, isFalse,
+        reason: 'the flags do not outlive the run');
+  });
+
+  test('criterion 8 alternates its arms and flips only its own flag', () async {
+    final (seen, cache) = await drive(ZoomCriterion.eight, repeats: 2);
+
+    expect(seen.length, 4);
+    expect(
+      <bool>[for (final s in seen) s.fullViewportQuery],
+      <bool>[false, true, false, true],
+    );
+    expect(seen.every((s) => !s.restBakeDisabled), isTrue);
+    expect(cache.debugFullViewportQuery, isFalse);
+  });
+
+  test('every arm is labelled with the flag it actually ran at', () async {
+    final (seen, _) = await drive(ZoomCriterion.four, repeats: 2);
+
+    for (final s in seen) {
+      final claimed = s.label.contains('debugRestBakeDisabled=true');
+      expect(claimed, s.restBakeDisabled,
+          reason: 'the label claims $claimed and the cache ran at '
+              '${s.restBakeDisabled}: ${s.label}');
+    }
+  });
+
+  test("criterion 8's denominator names whose M4 it is", () async {
+    final (seen, _) = await drive(ZoomCriterion.eight, repeats: 1);
+
+    expect(seen[1].label, contains("Plan 3h's M4"),
+        reason: 'mutant numbering is per-plan and M4/M5 collide between the '
+            "3h and 3i logs, so the arm's own label has to say which");
+    expect(seen[0].label, isNot(contains('M4')));
+  });
+
+  test('no two arms of a run share a label', () async {
+    final (seen, _) = await drive(ZoomCriterion.four, repeats: 3);
+
+    expect(seen.map((s) => s.label).toSet().length, seen.length,
+        reason: 'repeat and side both appear, so every arm of the transcript '
+            'is attributable on its own line');
+    expect(seen[0].label, contains('repeat 1/3'));
+    expect(seen[0].label, contains('arm A'));
+    expect(seen[1].label, contains('repeat 1/3'));
+    expect(seen[1].label, contains('arm B'));
+    expect(seen[4].label, contains('repeat 3/3'));
+  });
+
+  test('a plain repeat cannot be read as an interleaved arm', () {
+    final plain = zoomPlainLabel(repeat: 0, repeats: 9, entities: 50000);
+    final armA = zoomArmLabel(ZoomArm.restBakeOn,
+        repeat: 0, repeats: 9, entities: 50000);
+    final armB = zoomArmLabel(ZoomArm.restBakeOff,
+        repeat: 0, repeats: 9, entities: 50000);
+
+    expect(armA, contains('arm A'));
+    expect(armB, contains('arm B'));
+    // The old output was `R2 tile zoom arm 0`, which reads as one of these.
+    expect(plain, isNot(matches(RegExp(r'arm [AB0-9]'))));
+    expect(plain, contains('NOT an interleaved arm'));
+    expect(plain, contains('criterion 2 only'));
+    expect(plain, contains('debugRestBakeDisabled=false'));
+    expect(plain, contains('debugFullViewportQuery=false'));
+  });
+
+  test('every printed line of a report carries its arm label', () {
+    final label = zoomArmLabel(ZoomArm.fullViewportQuery,
+        repeat: 4, repeats: 9, entities: 500000);
+    final lines = <String>[];
+    runZoned(
+      () => printZoomReport(
+        label,
+        ZoomReport.from(
+          gestureMs: <double?>[for (var i = 0; i < 2 * kZoomSteps; i++) 5.0],
+          gestureBakes: 0,
+          gestureLiveDraws: 0,
+          settle: SettleReport(
+            frames: 2,
+            covered: true,
+            coveringFrameMs: 8.0,
+            wallMs: 13.0,
+            framesMissing: 0,
+          ),
+        ),
+      ),
+      zoneSpecification: ZoneSpecification(
+        print: (_, __, ___, line) => lines.add(line),
+      ),
+    );
+
+    expect(lines, isNotEmpty);
+    for (final line in lines) {
+      expect(line, startsWith(label),
+          reason: 'an indented continuation line under the wrong heading is a '
+              'number attributed to the wrong arm');
+    }
+    // Both time figures print, and neither can be read as the other.
+    expect(lines.join('\n'), contains('settleWallMs=13.00'));
+    expect(lines.join('\n'), contains('coveringFrameMs=8.00'));
+  });
+
+  test('a short sample and an uncovered settle both shout', () {
+    final lines = <String>[];
+    runZoned(
+      () => printZoomReport(
+        'label',
+        ZoomReport.from(
+          gestureMs: <double?>[
+            for (var i = 0; i < 2 * kZoomSteps; i++) i < 3 ? null : 5.0,
+          ],
+          gestureBakes: 0,
+          gestureLiveDraws: 0,
+          settle: SettleReport(
+            frames: kIdleFrames,
+            covered: false,
+            coveringFrameMs: 5.0,
+            wallMs: 150.0,
+            framesMissing: 1,
+          ),
+        ),
+      ),
+      zoneSpecification: ZoneSpecification(
+        print: (_, __, ___, line) => lines.add(line),
+      ),
+    );
+
+    final text = lines.join('\n');
+    expect(text, contains('never covered'));
+    expect(text, contains('SHORT SAMPLE'));
+    expect(text, contains('gesture 3 of ${2 * kZoomSteps}'));
+  });
+
+  test('ZOOM_MODE accepts its three values and rejects anything else', () {
+    expect(parseZoomMode('plain'), ZoomMode.plain);
+    expect(parseZoomMode('criterion4'), ZoomMode.criterion4);
+    expect(parseZoomMode('criterion8'), ZoomMode.criterion8);
+    // The Plan 3c failure, in this define's own terms: a value that looks
+    // right and selects the default would print nine repeats of one arm under
+    // a heading the command line asked criterion 4 for.
+    expect(() => parseZoomMode('criterion_4'), throwsStateError);
+    expect(() => parseZoomMode('4'), throwsStateError);
+    expect(() => parseZoomMode('true'), throwsStateError);
+    expect(() => parseZoomMode(''), throwsStateError);
+  });
+}
diff --git a/docs/superpowers/notes/plan-3i-mutation-log.md b/docs/superpowers/notes/plan-3i-mutation-log.md
index 722ffeb..ba4ddd8 100644
--- a/docs/superpowers/notes/plan-3i-mutation-log.md
+++ b/docs/superpowers/notes/plan-3i-mutation-log.md
@@ -17,24 +17,38 @@
 > pixels at `kTileDpr`, 25 x 19 = 475 tiles, ~19 one-tile-row bands -- not the
 > 400x300 logical / 130 tile / ~10 band canvas the fix made every later entry
 > in this file true of. The kills stand and are **not re-run**: each mutation
 > still produces exactly the failure its own entry describes, on whatever
 > canvas the suite ran against that day, and a canvas size does not decide
 > whether a band image leaks or a slice loop drops eleven tiles. What the note
 > is for is the raw counts those three entries print -- `475`, `513`, `38`,
 > `19 bands`, and the `800x600`/`BoxConstraints(w=800.0, h=600.0)` seen in one
 > stack trace -- so a reader does not mistake them for the fixed canvas's
 > figures (130 tiles, ~10 bands) or wonder why they disagree with every later
 > entry.
 
+> **Note, added by fix wave A: M1, M4 and M4b predate that fix too, and the
+> note above named only three entries.** A reader could not tell whether the
+> other three survived the refactor, so each is re-derived here against the
+> fixed canvas rather than re-run.
+>
+> * **M1** prints `512` for "a moving frame must bake nothing". That is
+>   `budgetedTilesPerFrame` -- `kBakeBudgetDevicePixels / (64 * 64) = 64`
+>   tiles a frame over the test's 8 zoom frames -- and it is budget-limited on
+>   either canvas, because 475 tiles and 130 tiles both exceed 64. **Re-derives
+>   unchanged: 512.**
+> * **M4** prints `512` and `768` for the same reason, at 8 and 12 budgeted
+>   frames respectively. **Both re-derive unchanged.**
+> * **M4b** does not: see the correction inside its own entry.
+
 ## M1
 
 **Task:** Task 2, "A moving frame draws the composite and nothing else."
 
 **Mutation:** In `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`'s
 `paintFrame`, deleted the guard block
 
 ```dart
     if (!resting) {
       // Nothing else this frame. The composite is already down; a zoom out
       // leaves its ring as background until the gesture ends (spec D3).
       return;
@@ -171,24 +185,43 @@ Expected: <0>
   Actual: <384>
 a wheel that keeps turning must never reach two consecutive unchanged frames,
 so it must never bake
 
 00:00 +6 -2: the gate needs two unchanged frames, not one [E]
 Expected: <2>
   Actual: <1>
 ```
 
 With kRestGateFrames = 1, the wheel test bakes on every other notch (384 tiles
 instead of 0), confirming the threshold of 2 is necessary to meet the spec.
 
+> **Correction, fix wave A: the kill number above is stale in value *and* in
+> unit, and the mutation still kills.** M4b was fired at Task 3, before Task 8
+> introduced `_restBake`, so `_bakes` then counted *tiles* and the transcript's
+> `384` is 6 notches x the 64-tile budget. At HEAD the frame after each notch
+> is a rest frame over a generation the notch just retired, so every band is
+> missing and `_bakes` increments **once per band**: 6 notches x 10 bands =
+> **60**, and the unit is bands, not tiles. The prose "384 tiles" should be
+> read as "60 bands". Nothing else about the entry changes -- the gate is
+> alive, the mutation is still red, and no new transcript is fabricated for
+> it. (Fix wave A's own per-band probe does not move this number either: after
+> a retire the generation is empty, so every band is missing and every band
+> bakes.)
+>
+> The second failing test in the transcript, `the gate needs two unchanged
+> frames, not one`, was renamed by fix wave A to **`the gate is two unchanged
+> frames, and the constant says so`** -- the finding was that its name claimed
+> a behavioural gate while its body asserts the constant's own value. Same
+> assertion, same kill.
+
 ---
 
 ## M2 — the slice loop emits only the first tile of each band
 
 > Measured at the pre-fix 800x600-logical canvas -- see the note at the top
 > of this file. The kill stands; it is not re-run.
 
 **Task 8.** A band is walked and rasterised in full, but only its leftmost tile
 is cut out of it. Every other visible key is left to the budgeted tile loop, so
 a resting frame no longer covers the viewport in one frame — which is the whole
 claim Task 8 lands.
 
@@ -319,24 +352,61 @@ The test description was:
   the ceiling holds at every point inside the rest frame
 ════════════════════════════════════════════════════════════════════════════════════════════════════
 00:00 +1 -1: the ceiling holds at every point inside the rest frame [E]
   Test failed. See exception logs above.
   The test description was: the ceiling holds at every point inside the rest frame
   
 00:00 +1 -1: Some tests failed.
 
 Failing tests:
   /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart: the ceiling holds at every point inside the rest frame
 ```
 
+### Added gate, fix wave A: re-fired against `the ceiling binds inside the rest frame, and eviction holds it`
+
+**Not a rewrite of the history above.** The whole-branch review found that the
+arm this mutant died on ran at 43x of headroom in its ceiling clause -- 130
+tiles plus one band, 2,342,912 bytes, against a `kTileCacheBytes` of
+100,663,296 -- so no mutation to the rest bake could move `liveBytes` far
+enough to trip that clause, and the entry above records the kill landing on
+`debugImagesAlive`, not on the ceiling. Fix wave A added a second arm at a cap
+the frame reaches on every slice, and re-fired this mutation against it.
+
+**Result:** red there too, and again on `debugImagesAlive` -- four leaked band
+images:
+
+```
+The following TestFailure was thrown running a test:
+Expected: <172>
+  Actual: <176>
+no band image outlives its band here either
+
+  [stack trace elided]
+The test description was:
+  the ceiling binds inside the rest frame, and eviction holds it
+
+00:00 +1 -2: Some tests failed.
+Failing tests:
+  test/invariants/tile_bytes_test.dart: the ceiling binds inside the rest frame, and eviction holds it
+  test/invariants/tile_bytes_test.dart: the ceiling holds at every point inside the rest frame
+```
+
+**And a finding worth recording rather than a gate: `liveBytes` is structurally
+blind to this mutant, at any cap.** It sums `_tiles`, `_carryOver` and the
+image currently in `_band` -- and `_band` is reassigned at the top of every
+band iteration, so an image the loop failed to dispose stops being counted the
+moment the next band starts. No ceiling, however tight, can catch M6 through
+`liveBytes`; `debugImagesAlive` is its gate and always was. The new arm's own
+mutant is **M20**, which trips the ceiling clause directly.
+
 ---
 
 ## M6b — the band image is never assigned to `_band`
 
 > Measured at the pre-fix 800x600-logical canvas -- see the note at the top
 > of this file (the `BoxConstraints(w=800.0, h=600.0)` in the transcript
 > below is that canvas). The kill stands; it is not re-run.
 
 **Task 8, fix round 1.** The band is baked, sliced and disposed correctly, but
 `_band` is never set, so `liveBytes` cannot see the one image the whole banding
 design exists to bound.
 
@@ -607,28 +677,38 @@ that is arm 2.
 +        viewport.width * devicePixelRatio, viewport.height * devicePixelRatio);
 +  }
 +
    /// Floor division that stays correct for negative numerators.
    ///
    /// Dart's `~/` truncates toward zero, so `-1 ~/ 64` is `0` and the tile to
 ```
 
 **Procedure:** copied `tile_cache.dart` aside, applied the edit, ran the
 whole package suite with `CI=true flutter test`, then restored from the copy.
 **Never `git checkout`.**
 
-**Result:** red on arm 2 (3,780 differing pixels -- 14 device rows across 270
-columns of the bottom edge) and on arm 3 (8,692). Arm 1, arm 5 and the tile-edge
-sweep are all green under it, which is the measurement Task 5's `>=` bound
-predicted.
+**Result:** red on two of the differential arms, **named here rather than
+numbered** -- 8,692 differing pixels on *"and stays identical after a pan
+smaller than one tile"*, and 3,780 (14 device rows across 270 columns of the
+bottom edge) on *"and when a pan lands between the scale change and the bake"*.
+The settled-generation arm, the rebase-boundary arm and the tile-edge sweep are
+all green under it, which is the measurement Task 5's `>=` bound predicted.
+
+> **Correction, fix wave A.** This paragraph read "red on arm 2 (3,780 ...)
+> and on arm 3 (8,692)", which is the two numbers swapped against this entry's
+> own transcript below: 8,692 is printed under *"and stays identical after a
+> pan smaller than one tile"* and 3,780 under *"and when a pan lands between
+> the scale change and the bake"*. The kill stands; the attribution did not.
+> Rewritten to name the arms, because the file's arms have been counted two
+> different ways.
 
 **Verbatim output:**
 
 ```
 The following TestFailure was thrown running a test:
 Expected: <0>
   Actual: <8692>
 an edge tile sliced from a viewport-sized source blits its transparent overhang here, and costs the
 same as an opaque one, so no timing gate can see it
 
   [stack trace elided]
 The test description was:
@@ -680,27 +760,37 @@ boundary, alternating sides, is what makes the loss reachable. Recorded on
      // by the same amount, so the padded viewport's origin lands where the
      // band's own origin was.
 -    const pad = kTileSlack;
 +    const pad = 0.0;
      into.save();
      into.translate(-pad, -pad);
 ```
 
 **Procedure:** copied `tile_cache.dart` aside, applied the edit, ran the
 whole package suite with `CI=true flutter test`, then restored from the copy.
 **Never `git checkout`.**
 
-**Result:** red on all five differential arms and on both of Task 6's band-query
-unit tests. 30,160 differing pixels on arms 1 and 5, 8,196 and 9,170 on arms 2
-and 3, 3,475 on the tile-edge sweep.
+**Result:** red on all five differential arms and on both of Task 6's
+band-query unit tests. By name, from the transcript below: **30,160** differing
+pixels on *"a settled generation is identical to a live frame"* and again on
+*"and stays identical after a pan smaller than one tile"*; **3,475** on *"and
+at a camera on a power-of-two rebase boundary"*; **9,170** on *"and when a pan
+lands between the scale change and the bake"*; and **8,196** on the tile-edge
+sweep, *"tile boundaries carry no difference of their own"*.
+
+> **Correction, fix wave A.** This paragraph read "30,160 differing pixels on
+> arms 1 and 5, 8,196 and 9,170 on arms 2 and 3, 3,475 on the tile-edge
+> sweep". The transcript prints 3,475 against the rebase-boundary arm and
+> 8,196 against the tile-edge sweep -- the reverse. The kills stand; the
+> attribution did not, and the transcript is the record.
 
 **Verbatim output:**
 
 ```
 The following TestFailure was thrown running a test:
 Expected: <0>
   Actual: <30160>
 a band is queried with a pad and clipped without one, and the tiles cut out of it have to hold what
 the live frame draws
 
   [stack trace elided]
 The test description was:
@@ -1621,12 +1711,504 @@ Failing tests:
 
 **Restore, verified.** `cp` from the scratchpad copy, `diff` against it empty,
 `git status --porcelain` showing only this task's own paths, and the file
 re-run green:
 
 ```
 00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart
 00:00 +0: the rest bake fires: the unflagged arm slices every visible tile
 00:00 +1: debugRestBakeDisabled slices nothing and still covers
 00:00 +2: debugFullViewportQuery grows the fallback walk to the whole viewport
 00:00 +3: All tests passed!
 ```
+
+---
+
+## M20 — the settle reads the frame before the one that covered
+
+**Task:** fix wave B, the Blocking finding of Plan 3i's final whole-branch
+review. Gates `apps/dev_harness_2d/test/settle_attribution_test.dart`.
+
+**Why this mutant and not another.** `settleMs` is the only time value
+criteria 3 and 4 are read off, and it named the wrong frame *systematically*,
+not occasionally. A `FrameTiming` is delivered only after its frame has
+rasterised; `pumpFrame` completes at `SchedulerBinding.endOfFrame`, the
+frame's post-frame phase, *before* its scene rasterises. The idle loop
+registered a fresh `collectIdle` callback around a single `await pumpFrame()`
+and read `.last` out of it, so the timings it saw for idle frame *i* were
+frame *i-1*'s, or none. On correct code coverage first reads true at idle
+frame **2** (Ruling 15), so the published figure was idle frame 1: the
+in-between composite blit that draws nothing and is essentially free. The
+number would have looked exactly like the one-frame settle criterion 3 wants,
+and would have been a measurement of a blit. M20 restores that attribution as
+a one-ordinal shift, which is precisely what the old code did.
+
+**Mutation**, applied to
+`apps/dev_harness_2d/lib/measurement_rig.dart`, in `runSettlePhase`:
+
+```diff
+--- a/apps/dev_harness_2d/lib/measurement_rig.dart
++++ b/apps/dev_harness_2d/lib/measurement_rig.dart
+@@ -876,1 +876,1 @@
+-  final ms = log.msRange(firstOrdinal, firstOrdinal + frames);
++  final ms = log.msRange(firstOrdinal - 1, firstOrdinal + frames - 1);
+```
+
+**Procedure:** copied `measurement_rig.dart` aside to the scratchpad
+(`measurement_rig_m20.bak`), edited the working file, ran
+`CI=true flutter test --concurrency=1 test/settle_attribution_test.dart` from
+`apps/dev_harness_2d`, confirmed red, then restored the working file with `cp`
+from the scratchpad copy and confirmed `diff` produced no output. **Never
+`git checkout`.**
+
+**Result:** red, six of the nine tests, and the named mutation the brief asked
+for dies on the figure moving: with the covering frame made arbitrarily
+expensive, `coveringFrameMs` reads **4.0** -- the cheap frame before it -- in
+both the 9 ms arm and the 900 ms arm. The settle figure is inert under the
+mutant, which is the whole point: a number that cannot move is not a
+measurement. Criterion 4's wall clock dies alongside it (**6.0** where the
+three-frame settle is 5 + 6 + 90 = 101.0), and the drain test dies on the hole
+rather than on a value, because a shifted window leaves the last frame
+unattributed.
+
+Two tests survive M20 and are meant to: `'the gesture window excludes the
+warm-up frames and keeps its tail'` reads a different window (the gesture's,
+not the settle's), and `'a frame that never reports is a hole, not a zero'`
+asserts a shortfall that a shift by one does not change.
+
+**Verbatim output** (the `flutter pub get` preamble, identical to every other
+entry in this file, is trimmed):
+
+```
+00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart
+00:00 +0: the covering frame is the one reported, not the frame before it
+00:00 +0 -1: the covering frame is the one reported, not the frame before it [E]
+  Expected: <0>
+    Actual: <1>
+  both settle frames must have reported a timing
+  
+  package:matcher                                     expect
+  package:flutter_test/src/widget_tester.dart 473:18  expect
+  test/settle_attribution_test.dart 104:5             main.<fn>
+  
+00:00 +0 -1: the settle frame moves the reported figure
+00:00 +0 -2: the settle frame moves the reported figure [E]
+  Expected: a numeric value within <1e-9> of <9.0>
+    Actual: <4.0>
+     Which:  differs by <5.0>
+  
+  package:matcher                                     expect
+  package:flutter_test/src/widget_tester.dart 473:18  expect
+  test/settle_attribution_test.dart 134:5             main.<fn>
+  
+00:00 +0 -2: wall clock over the settle is the sum, not the last frame
+00:00 +0 -3: wall clock over the settle is the sum, not the last frame [E]
+  Expected: a numeric value within <1e-9> of <90.0>
+    Actual: <6.0>
+     Which:  differs by <84.0>
+  
+  package:matcher                                     expect
+  package:flutter_test/src/widget_tester.dart 473:18  expect
+  test/settle_attribution_test.dart 159:5             main.<fn>
+  
+00:00 +0 -3: the idle frames after coverage are not charged to the settle
+00:00 +0 -4: the idle frames after coverage are not charged to the settle [E]
+  Expected: a numeric value within <1e-9> of <11.0>
+    Actual: <5.0>
+     Which:  differs by <6.0>
+  
+  package:matcher                                     expect
+  package:flutter_test/src/widget_tester.dart 473:18  expect
+  test/settle_attribution_test.dart 186:5             main.<fn>
+  
+00:00 +0 -4: the last idle frame is drained rather than dropped
+00:00 +0 -5: the last idle frame is drained rather than dropped [E]
+  Expected: <0>
+    Actual: <1>
+  
+  package:matcher                                     expect
+  package:flutter_test/src/widget_tester.dart 473:18  expect
+  test/settle_attribution_test.dart 211:5             main.<fn>
+  
+00:00 +0 -5: a settle that never covers says so
+00:00 +0 -6: a settle that never covers says so [E]
+  Expected: a numeric value within <1e-9> of <21.0>
+    Actual: <14.0>
+     Which:  differs by <7.0>
+  
+  package:matcher                                     expect
+  package:flutter_test/src/widget_tester.dart 473:18  expect
+  test/settle_attribution_test.dart 234:5             main.<fn>
+  
+00:00 +0 -6: a frame that never reports is a hole, not a zero
+00:00 +1 -6: the gesture window excludes the warm-up frames and keeps its tail
+00:00 +2 -6: a short sample is counted, and length plus missing is the script
+00:00 +3 -6: Some tests failed.
+
+Failing tests:
+  /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: a settle that never covers says so
+  /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: the covering frame is the one reported, not the frame before it
+  /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: the idle frames after coverage are not charged to the settle
+  /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: the last idle frame is drained rather than dropped
+  ... and 2 more
+```
+
+**Restore, verified.** `cp` from the scratchpad copy, `diff` against it empty,
+and the same file re-run green:
+
+```
+00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart
+00:00 +0: the covering frame is the one reported, not the frame before it
+00:00 +1: the settle frame moves the reported figure
+00:00 +2: wall clock over the settle is the sum, not the last frame
+00:00 +3: the idle frames after coverage are not charged to the settle
+00:00 +4: the last idle frame is drained rather than dropped
+00:00 +5: a settle that never covers says so
+00:00 +6: a frame that never reports is a hole, not a zero
+00:00 +7: the gesture window excludes the warm-up frames and keeps its tail
+00:00 +8: a short sample is counted, and length plus missing is the script
+00:00 +9: All tests passed!
+```
+
+---
+
+> **Fix wave A opens here.** Everything below was fired against the
+> whole-branch review's findings, on the fixed 400x300-logical canvas (130
+> tiles, 10 bands). `M20` is **not** in this run: it belongs to the parallel
+> wave working in `apps/dev_harness_2d/` and is recorded above. Numbering in
+> this file is shared between the two waves, which is why the ceiling mutant
+> below is `M21` and not `M20`.
+
+## M17 — a moving frame returns unconditionally, so a pan draws only the composite
+
+**Fix wave A, MAJOR 1.** The defect as shipped: `resting` was computed from
+`_restGateSteps` alone and never asked what spec D1 defines *moving* by --
+whether the scale changed. `CameraController.panBy` copies `a, b, c, d`
+bit-identically, so `TileGrid.matchesScale` holds, `_gridFor` returns the
+standing grid without retiring, and a composite minted by the preceding zoom
+survives the pan; with the camera changing every frame the rest gate never
+armed, so every pan frame blitted that composite at the panned position and
+returned with `_tiles` empty. This mutation restores that behaviour.
+
+**Mutation:** In `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`'s
+`paintFrame`, deleted the pan disjunct from `resting`:
+
+```diff
+     final resting = previous == null ||
+         _carryOver == null ||
+-        (!scaleChanged && _restGateSteps == 0) ||
+         _restGateSteps >= kRestGateFrames;
+```
+
+**Procedure:** copied `tile_cache.dart` aside to the scratchpad, applied the
+edit, ran `CI=true flutter test test/tile_regime_test.dart`, then restored the
+working file from the copy and `diff`ed it clean. **Never `git checkout`.**
+
+**Result:** red — the pan frames bake nothing, so `bakeCount` reads 0. (The
+ink assertion on the revealed strip is behind it in the same test and never
+runs; the counter clause fails first.)
+
+**Verbatim output:**
+
+```
+00:00 +8: a pan after a zoom fills the region the composite slides off
+══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
+The following TestFailure was thrown running a test:
+Expected: a value greater than <0>
+  Actual: <0>
+   Which: is not a value greater than <0>
+a pan is not a moving frame (spec D1 defines moving by the scale) and D8 leaves the pan path baking
+at its edge
+
+  [stack trace elided]
+This was caught by the test expectation on the following line:
+  file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart line 231
+The test description was:
+  a pan after a zoom fills the region the composite slides off
+════════════════════════════════════════════════════════════════════════════════════════════════════
+00:00 +8 -1: a pan after a zoom fills the region the composite slides off [E]
+  Test failed. See exception logs above.
+00:00 +8 -1: an edit inside one band rebakes that band alone
+00:00 +9 -1: a skipped band keeps its tiles out of the ceiling's reach
+00:00 +10 -1: the gate is two unchanged frames, and the constant says so
+00:00 +11 -1: Some tests failed.
+
+Failing tests:
+  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart: a pan after a zoom fills the region the composite slides off
+```
+
+**Restore, verified.** `cp` from the scratchpad copy, `diff` against it empty,
+the same file re-run green:
+
+```
+00:00 +10: a skipped band keeps its tiles out of the ceiling's reach
+00:00 +11: the gate is two unchanged frames, and the constant says so
+00:00 +12: All tests passed!
+```
+
+---
+
+## M18 — the rest bake's probe is frame-global, so one missing tile walks every band
+
+**Fix wave A, MAJOR 2.** `_restBake` computed a single `missing` boolean over
+all visible keys and then called `_bakeBand` for every band; the per-key
+`containsKey ... continue` inside the loop skips only the *slice*, so a band
+whose keys were all held still paid a painter walk, a `_recordOwners` over its
+whole visit list, a `toImageSync` and a `_bakes++` before throwing the image
+away.
+
+**Mutation:** deleted the per-band probe from the band loop, leaving the
+frame-global one in place:
+
+```diff
+     for (final band in bands) {
+-      var bandMissing = false;
+-      for (final key in band.keys) {
+-        if (!_tiles.containsKey(key)) {
+-          bandMissing = true;
+-          break;
+-        }
+-      }
+-      if (!bandMissing) {
+-        for (final key in band.keys) {
+-          _lastUsedFrame[key] = _frameSerial;
+-        }
+-        continue;
+-      }
+-
+       if (!_makeRoomForBytes(bandBytes + _tileBytes)) return;
+```
+
+**Procedure:** as M17, against `test/tile_regime_test.dart`.
+
+**Result:** red — the edit condemns three bands (direction one condemns every
+tile whose band record names the handle, and `kTileSlack` is one tile row at
+this tile size, so the leaf is visited by the walks for rows 3, 4 and 5), and
+the mutant bakes all ten.
+
+**Verbatim output:**
+
+```
+00:00 +9: an edit inside one band rebakes that band alone
+══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
+The following TestFailure was thrown running a test:
+Expected: <3>
+  Actual: <10>
+only the bands the edit condemned owe a walk; the other 7 hold every key they need, and rebaking
+them replaces good images with identical ones -- a whole-viewport walk for three rows, on every
+frame of a drag
+
+  [stack trace elided]
+The test description was:
+  an edit inside one band rebakes that band alone
+════════════════════════════════════════════════════════════════════════════════════════════════════
+00:00 +9 -1: an edit inside one band rebakes that band alone [E]
+00:00 +9 -1: a skipped band keeps its tiles out of the ceiling's reach
+00:00 +10 -1: the gate is two unchanged frames, and the constant says so
+00:00 +11 -1: Some tests failed.
+
+Failing tests:
+  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart: an edit inside one band rebakes that band alone
+```
+
+**Restore, verified** — same `cp`, empty `diff`, and `+12: All tests passed!`
+on the same file.
+
+---
+
+## M19a / M19b — `a` and `d` in `sameQuantisedCamera` are each individually deletable
+
+**Fix wave A.** M12's defect one field over, recorded as a Task 1 deferred
+minor ("`a` and `d` are correlated in every fixture (`d == -a`), so deleting
+either check alone survives") and never closed. `tile_regime_test.dart`'s
+`at()` helper builds `Transform2(scale, 0, 0, -scale, e, f)`, so every fixture
+in the file tied `d` to `-a`, and the only other caller compares two `zoomAt`
+results where both terms move together. Closed with an anisotropic fixture and
+one arm per term.
+
+**Mutations:**
+
+```diff
+   return x.a == y.a &&        <- M19a deletes this line
+       x.b == y.b &&
+       x.c == y.c &&
+       x.d == y.d &&           <- M19b deletes this line
+       x.e == y.e &&
+       x.f == y.f;
+```
+
+**Procedure:** as M17, against `test/tile_regime_test.dart`, once per arm.
+
+**Result:** both red, and **only** on the new test -- `a scale change compares
+different` stays green under both, which is the degeneracy stated as a
+measurement.
+
+**Verbatim output, M19a:**
+
+```
+00:00 +3: the two scale terms are compared independently
+00:00 +3 -1: the two scale terms are compared independently [E]
+  Expected: false
+    Actual: <true>
+  x scale alone, with y held: a generation anchored at one x scale cannot blit at another
+  
+  package:matcher                                     expect
+  package:flutter_test/src/widget_tester.dart 473:18  expect
+  test/tile_regime_test.dart 49:5                     main.<fn>
+  
+00:00 +3 -1: the skew terms are compared too
+00:00 +11 -1: Some tests failed.
+
+Failing tests:
+  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart: the two scale terms are compared independently
+```
+
+**Verbatim output, M19b:**
+
+```
+00:00 +3: the two scale terms are compared independently
+00:00 +3 -1: the two scale terms are compared independently [E]
+  Expected: false
+    Actual: <true>
+  y scale alone, with x held
+  
+  package:matcher                                     expect
+  package:flutter_test/src/widget_tester.dart 473:18  expect
+  test/tile_regime_test.dart 53:5                     main.<fn>
+  
+00:00 +11 -1: Some tests failed.
+
+Failing tests:
+  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart: the two scale terms are compared independently
+```
+
+**Restore, verified** after each: empty `diff`, `+12: All tests passed!`.
+
+---
+
+## M19c / M19d / M19e — the same degeneracy in `TileGrid.matchesScale`
+
+**Fix wave A.** `matchesScale` compares `a`, `b`, `c` and `d`, and
+`awkwardCamera` -- the fixture every arm of `tile_grid_test.dart` uses -- has
+`d == -a` and `b == c == 0`. Its `matchesScale is exact, not tolerant` arm
+nudges `a` alone, so deleting the `b`, `c` or `d` comparison killed nothing.
+The `sameQuantisedCamera` fixture does **not** reach `matchesScale` -- they are
+different functions with different callers -- so this needed its own
+anisotropic, skewed fixture, added as `every scale term is compared, one at a
+time`.
+
+**Mutations:** in `TileGrid.matchesScale`, one term deleted per arm --
+**M19c** drops `a.d == b.d`, **M19d** drops `a.b == b.b`, **M19e** drops
+`a.c == b.c`.
+
+**Procedure:** as M17, against `test/tile_grid_test.dart`, once per arm.
+
+**Result:** all three red, each on its own clause of the new arm, with
+`matchesScale is exact, not tolerant` green throughout -- which is the
+statement that the old fixture could not tell these fields from constants.
+
+**Verbatim output, M19c:**
+
+```
+00:00 +7: TileGrid matchesScale is exact, not tolerant
+00:00 +8: TileGrid every scale term is compared, one at a time
+00:00 +8 -1: TileGrid every scale term is compared, one at a time [E]
+  Expected: false
+    Actual: <true>
+  d: the y scale, which every tiled fixture ties to -a
+  
+  package:matcher                                     expect
+  package:flutter_test/src/widget_tester.dart 473:18  expect
+  test/tile_grid_test.dart 193:7                      main.<fn>.<fn>
+  
+00:00 +8 -1: Some tests failed.
+
+Failing tests:
+  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_grid_test.dart: TileGrid every scale term is compared, one at a time
+```
+
+M19d and M19e print the same failure against the `b:` and `c:` clauses of the
+same arm, verbatim:
+
+```
+  Expected: false
+    Actual: <true>
+  b: a generation baked without this shear cannot blit with it
+  
+  package:matcher                                     expect
+  package:flutter_test/src/widget_tester.dart 473:18  expect
+  test/tile_grid_test.dart 182:7                      main.<fn>.<fn>
+  
+00:00 +8 -1: Some tests failed.
+```
+
+```
+  Expected: false
+    Actual: <true>
+  c: the other shear term
+  
+  package:matcher                                     expect
+  package:flutter_test/src/widget_tester.dart 473:18  expect
+  test/tile_grid_test.dart 188:7                      main.<fn>.<fn>
+  
+00:00 +8 -1: Some tests failed.
+```
+
+**Restore, verified** after each: empty `diff`, `+9: All tests passed!`.
+
+---
+
+## M21 — the slice loop writes a tile without asking the ceiling
+
+**Fix wave A.** The gate this fires is the new `the ceiling binds inside the
+rest frame, and eviction holds it`, added because criterion 7's original
+headline clause could not fail: it ran at `kTileCacheBytes` (100,663,296
+bytes) against a fixture whose whole peak was 2,342,912 -- 43x of headroom.
+The new arm prices its cap off the tiles the frame is actually holding, so the
+frame runs *at* its ceiling from the first slice to the last: measured, 12
+slices, 12 evictions, and a peak of exactly `cap`.
+
+**Mutation:** in `_restBake`'s slice loop:
+
+```diff
+         debugOnSliceForTest?.call();
+-        if (!_makeRoomForOneTile()) break;
+         final tile = _sliceTile(image, band, key, grid);
+```
+
+**Procedure:** as M17, against `test/invariants/tile_bytes_test.dart`.
+
+**Result:** red, one tile over the cap, thrown from inside `paint()` -- which
+is the point of observing the ceiling from `debugOnSliceForTest` rather than
+after the frame.
+
+**Verbatim output:**
+
+```
+00:00 +2: the ceiling binds inside the rest frame, and eviction holds it
+══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
+The following TestFailure was thrown during paint():
+Expected: a value less than or equal to <3031040>
+  Actual: <3047424>
+   Which: is not a value less than or equal to <3031040>
+criterion 7, at a cap that can be reached: the band image is resident here and the meter counts it
+
+The relevant error-causing widget was:
+  CustomPaint
+  CustomPaint:file:///Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart:359:16
+
+  [stack trace elided]
+00:00 +2 -1: the ceiling binds inside the rest frame, and eviction holds it [E]
+  Test failed. See exception logs above.
+00:00 +2 -1: Some tests failed.
+
+Failing tests:
+  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart: the ceiling binds inside the rest frame, and eviction holds it
+```
+
+**Restore, verified.** Empty `diff`, and:
+
+```
+00:00 +1: the ceiling holds at every point inside the rest frame
+00:00 +2: the ceiling binds inside the rest frame, and eviction holds it
+00:00 +3: All tests passed!
+```
diff --git a/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart b/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
index 861fc1c..5b3d51f 100644
--- a/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
+++ b/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
@@ -959,34 +959,47 @@ class TileCache {
     if (tablesRevision != _tablesRevision) {
       _tablesRevision = tablesRevision;
       _dropGeneration();
     }
 
     // Before anything reads it, so no tile can be carrying this frame's
     // ordinal before this frame blits it. `_makeRoomForOneTile` rests on that.
     _frameSerial++;
     _lastStrip = null;
     _lastClip = null;
 
     final quantised = quantiseCamera(camera, devicePixelRatio);
+    // Held across the call below because **`grid.matchesScale(quantised)` is
+    // true by construction once `_gridFor` has returned**: a scale change is
+    // exactly the case where it retires the generation and anchors a fresh
+    // grid *at this camera*. Spec D1 defines a *moving* frame as one whose
+    // quantised scale fails `matchesScale` against the current generation's
+    // anchor, and the only place that question can still be asked is here,
+    // against the generation the frame arrived at. Identity, not
+    // `matchesScale`, so a device-pixel-ratio or tile-size change -- which
+    // also re-anchors -- counts as the scale change it is.
+    final incoming = _grid;
     // The viewport reaches `_gridFor` because retiring a generation is now a
     // composite and not just a `dispose`: the outgoing tiles have to be
     // flattened into one viewport-sized image *before* they go.
     final grid = _gridFor(quantised, devicePixelRatio, viewport);
+    final scaleChanged = !identical(incoming, grid);
     _lastCamera = quantised;
 
-    // **Three frame kinds, and only one of them bakes.** A frame whose camera
-    // changed is *moving*. A frame that has matched once and not yet twice is
-    // the one in between. Both draw the composite and nothing else: no bake,
-    // and no live walk.
+    // **Three frame kinds, and only one of them bakes.** A frame whose
+    // *scale* changed is *moving* (spec D1). A frame that has matched once
+    // and not yet twice is the one in between. Both draw the composite and
+    // nothing else: no bake, and no live walk. A frame that changed only its
+    // translation is none of the three -- it is a pan, and D8 leaves the pan
+    // path exactly as it was.
     //
     // The live walk is excluded deliberately and the measurement is why. On a
     // moving frame the new generation is empty, so every visible key misses
     // and `uncovered` accumulates by `expandToInclude` into the **whole
     // viewport** rather than a ring; `stripFor` then clamps to the viewport.
     // "Walk the uncovered region" is therefore a full-viewport live walk --
     // 31.5-41.6 ms at 500,000 entities -- on every zoom-out frame.
     final previous = _lastQuantised;
     _restGateSteps =
         previous != null && sameQuantisedCamera(previous, quantised)
             ? _restGateSteps + 1
             : 0;
@@ -1014,26 +1027,49 @@ class TileCache {
     // frame in at least three real situations: the first frame this cache
     // has ever painted (already exempted above); the outgoing generation
     // never covered the viewport, so `_retireGeneration` minted nothing --
     // which is exactly the state a second zoom reaches when it lands before
     // the first one's settle completes; and any of `applyChange`,
     // `_dropGeneration` or `_dropEverything` dropping a standing composite
     // outright, if a camera change then lands before a rested frame. Gating
     // a frame with no composite would paint nothing at all -- not a stale
     // frame but a blank one -- for as long as the gesture continued. A blank
     // viewport is worse than an expensive one, so this falls through to the
     // ordinary bake-and-live-walk path instead: where there is nothing stale
     // to show, drawing the real thing is the honest fallback.
+    //
+    // **Nor on a pan, and that is spec D8.** A *moving* frame is one whose
+    // scale changed (D1); a frame that changed only its translation is a pan,
+    // and D8 says the pan path is untouched by this plan. Without the last
+    // disjunct below it was not: `CameraController.panBy` copies `a, b, c, d`
+    // bit-identically, so `_gridFor` returns the standing grid without
+    // retiring, a composite minted by the *preceding* zoom survives the whole
+    // pan, and every pan frame took the early return -- blitting that
+    // composite at the panned position while the region it uncovers at the
+    // leading edge stayed background, and `_tiles` stayed empty, until the
+    // camera happened to hold still for [kRestGateFrames] frames. D3's
+    // accepted ring is a zoom-out's ring and nothing else; an unfilled pan is
+    // a regression against D8, and before this plan the same frame paid a
+    // live walk over the uncovered region and got the pixels right.
+    //
+    // **`_restGateSteps == 0` is what makes this the pan and not the frame
+    // *between* two zoom notches.** D1's third frame kind -- matched once, not
+    // yet twice -- draws what a moving frame draws, and it is a frame whose
+    // camera did *not* change, so it carries a count of at least one. A pan
+    // frame changed the camera and reset the count to zero. Reading the count
+    // rather than the camera keeps the wheel's in-between frame cheap, which
+    // is the whole of D1's two-frame clause.
     final resting = previous == null ||
         _carryOver == null ||
+        (!scaleChanged && _restGateSteps == 0) ||
         _restGateSteps >= kRestGateFrames;
 
     // Derived once and handed to every bake. Rebasing is frame-global by
     // construction; a per-tile origin would give each tile its own
     // quantisation step and `float32` residuals the live frame does not have.
     final origin = rebaseOriginFor(quantised.visibleWorld(viewport));
 
     // The budget is device pixels; a tile costs its own area against it, so
     // this is the number of *tiles* this frame may bake at the cache's
     // current tile size. See [budgetedTilesPerFrame]'s own doc comment.
     var budget = budgetedTilesPerFrame;
     var baked = 0;
@@ -1058,41 +1094,44 @@ class TileCache {
       // there is nothing left to fill; a zoom *out* shrinks it and leaves a
       // genuine ring the live fallback owes. Asserting the containment rather
       // than assuming the gesture's direction is the difference between a
       // cheap gesture and a blank border.
       carryOverCovers = dest.left <= 0 &&
           dest.top <= 0 &&
           dest.right >= viewport.width &&
           dest.bottom >= viewport.height;
     }
 
     if (!resting) {
       // Nothing else this frame. `resting` is false here only because the
-      // camera is moving and a composite is already down to show for it --
-      // that is the third disjunct in `resting`'s own definition above, not
-      // an assumption made again here. A zoom out leaves that composite's
-      // ring as background until the gesture ends (spec D3).
+      // scale is moving, or moved one frame ago, and a composite is already
+      // down to show for it -- that is what the disjuncts in `resting`'s own
+      // definition above say, not an assumption made again here. A zoom out
+      // leaves that composite's ring as background until the gesture ends
+      // (spec D3); a *pan* does not reach this line at all (spec D8).
       return;
     }
 
-    // **The literal gate here, and not `resting`.** `resting` is true on two
+    // **The literal gate here, and not `resting`.** `resting` is true on three
     // frames that are not at rest at all: the very first frame this cache
-    // paints, and any moving frame with no composite to fall back on. Both
-    // disjuncts exist to stop a frame painting *nothing* -- the comment above
-    // says so in as many words: they "fall through to the ordinary
-    // bake-and-live-walk path". That path is budgeted and the band bake is
-    // not, so handing those two frames to the band bake would spend a
+    // paints, any moving frame with no composite to fall back on, and any pan
+    // frame. All three disjuncts exist to stop a frame painting *nothing* --
+    // the comment above says so in as many words: they "fall through to the
+    // ordinary bake-and-live-walk path". That path is budgeted and the band
+    // bake is not, so handing those frames to the band bake would spend a
     // full-viewport walk on the first frame of a still-moving gesture, which
-    // is precisely the zoom-regime cost this cache exists to refuse. A band
-    // is for a camera that has actually stopped.
+    // is precisely the zoom-regime cost this cache exists to refuse -- and on
+    // a pan it would spend one per frame for the length of the gesture. A
+    // band is for a camera that has actually stopped, which is what the
+    // count, and only the count, says.
     if (_restGateSteps >= kRestGateFrames && !debugRestBakeDisabled) {
       _restBake(grid, quantised, viewport, painter, sink, vertices, origin);
     }
 
     for (final key in grid.visibleKeys(quantised, viewport)) {
       var image = _tiles[key];
       // **The ceiling is consulted before the bake, not after the frame.** A
       // small cap against a viewport of many tiles means the visible set alone
       // overruns it, so a sweep at the end of `paintFrame` would have nothing
       // left to reclaim -- every tile it could take was blitted this frame --
       // and `liveBytes` would settle wherever the visible set happened to put
       // it. Asking first makes the ceiling hold at every point inside the
@@ -1216,24 +1255,30 @@ class TileCache {
   /// the "viewport not covered" half of the resting regime, tested against the
   /// tiles themselves rather than against [_viewportCovered], which is a
   /// statement about the *previous* frame's camera.
   void _restBake(
     TileGrid grid,
     ViewportTransform quantised,
     Size viewport,
     DraftPainter painter,
     CanvasDrawSink sink,
     VerticesDrawSink? vertices,
     Vector2 origin,
   ) {
+    // **Kept as a cheap frame-global early-out**, ahead of `bandsFor`'s
+    // allocation: a rest frame over a generation that is already whole is the
+    // common case (`paintFrame` reaches here on *every* frame whose camera has
+    // stood still), and this answers it without building the band list. It is
+    // not the probe that decides what gets baked -- that one is per band,
+    // inside the loop below.
     var missing = false;
     for (final key in grid.visibleKeys(quantised, viewport)) {
       if (!_tiles.containsKey(key)) {
         missing = true;
         break;
       }
     }
     if (!missing) return;
 
     final bands = grid.bandsFor(quantised, viewport);
     if (bands.isEmpty) return;
     final bandBytes = _bandBytesOf(bands.first);
@@ -1263,74 +1308,122 @@ class TileCache {
     // tiles below land on the same pixels. At the reference viewport the
     // source picture and the tile set are each about 48 MiB against a 96 MiB
     // cap, so the composite's 29.3 MiB on top is exactly what banding exists
     // to avoid -- dropping it before the bake is the other half of the same
     // arithmetic, and it is what leaves the ceiling room for the band. It is
     // the same rule the covered-frame drop below states ("the incoming
     // generation now covers every pixel the composite served"), decided
     // ahead of the fill rather than after it, which the check above is what
     // licenses.
     _dropCarryOver();
 
     for (final band in bands) {
+      // **The probe is per band, and it has to be.** One missing key anywhere
+      // in the viewport used to commit *every* band to a full painter walk, a
+      // `_recordOwners` over its whole visit list, a `toImageSync` and a
+      // `_bakes++` -- and then to throw the image away, because the per-key
+      // `containsKey` below skips only the *slice*. That is the ordinary edit
+      // path, not an edge case: after an `applyChange` the camera has not
+      // moved, so the gate is still armed and the very next frame rest-bakes,
+      // while `_invalidateTouched` has typically condemned tiles in one band
+      // alone. A drag paid one whole-viewport walk a frame for it. This
+      // paragraph is the doc comment's own reasoning -- "rebaking those would
+      // replace good images with identical ones ... and pay a full walk for
+      // nothing" -- applied at the granularity the walk actually happens at.
+      //
+      // **The recency touch is not optional, and it is what keeps the ceiling
+      // proof intact.** The proof the up-front pricing rests on is that at
+      // band `i` the set `_makeRoomForBytes` may not evict is exactly the keys
+      // of bands `0..i-1`, which holds because every one of those keys was
+      // written with this frame's serial -- sliced, or already held and
+      // touched. A band skipped *without* the touch would leave its keys
+      // evictable by a later band's `_makeRoomForBytes`, and the frame would
+      // blit a hole it had already decided it owned. So a skipped band pays
+      // one map write per key and nothing else: no `_makeRoomForBytes`, no
+      // band image, no walk, no `_bakes++`.
+      var bandMissing = false;
+      for (final key in band.keys) {
+        if (!_tiles.containsKey(key)) {
+          bandMissing = true;
+          break;
+        }
+      }
+      if (!bandMissing) {
+        for (final key in band.keys) {
+          _lastUsedFrame[key] = _frameSerial;
+        }
+        continue;
+      }
+
       // **Asked before the band is allocated, not after.** The ceiling is a
       // ceiling and not a suggestion (see [_makeRoomForOneTile]), and a band
       // is a whole row -- thirteen tiles' worth here, 8 MiB at the reference
       // viewport. Baking one and discovering afterwards that nothing could be
       // kept is the silent overrun that arm exists to refuse, so a ceiling
       // that cannot hold a band leaves the whole rest bake to the ordinary
       // budgeted tile loop and the live fallback below.
       if (!_makeRoomForBytes(bandBytes + _tileBytes)) return;
 
       final visited = <int>[];
       final image = _bakeBand(
           band, grid, quantised, painter, sink, vertices, origin, visited);
       _band = image;
-      // [_bakeBand]'s `onVisit` records only what the painter visited
-      // directly; [_bake]'s climbs owners so that a *container's* transform
-      // reaches the tile through invalidation's direction one. This is where
-      // the band makes up the difference -- once per band rather than once
-      // per tile, which is the whole reason the band callback is the simpler
-      // one.
-      _recordOwners(visited, painter.document);
-      visited.sort();
-      // **One record per band, shared by reference.** `_invalidateTouched`
-      // condemns tiles by iterating `_baked`, and a sliced tile with no record
-      // is invisible to it: edit an entity after a settle and the stale tile
-      // keeps blitting over the corrected drawing. Sharing makes invalidation
-      // band-coarse, which is right because a band is exactly the unit a
-      // rebake walks.
-      final record = Uint32List.fromList(visited);
-      for (final key in band.keys) {
-        // A key this frame's tile map already serves keeps its own image and
-        // its own, narrower record. Overwriting it would leak the image it
-        // replaced -- `_tiles[key] = tile` disposes nothing -- and a pan
-        // within one generation reaches this loop with most of the row
-        // already held.
-        if (_tiles.containsKey(key)) {
+      // **The band is released on every exit from here, including a throw.**
+      // `_band` is not a local: [liveBytes] counts it, so an image stranded in
+      // that field overstates the cache by a whole band for the rest of its
+      // life and `_makeRoomForBytes` over-evicts forever after -- a leaked
+      // image plus a permanently wrong meter, from one exception in
+      // [_recordOwners] or [_sliceTile]. No non-throwing path reaches it
+      // today; the `finally` is what keeps that true of paths added later.
+      try {
+        // [_bakeBand]'s `onVisit` records only what the painter visited
+        // directly; [_bake]'s climbs owners so that a *container's* transform
+        // reaches the tile through invalidation's direction one. This is where
+        // the band makes up the difference -- once per band rather than once
+        // per tile, which is the whole reason the band callback is the simpler
+        // one.
+        _recordOwners(visited, painter.document);
+        visited.sort();
+        // **One record per band, shared by reference.** `_invalidateTouched`
+        // condemns tiles by iterating `_baked`, and a sliced tile with no
+        // record is invisible to it: edit an entity after a settle and the
+        // stale tile keeps blitting over the corrected drawing. Sharing makes
+        // invalidation band-coarse, which is right because a band is exactly
+        // the unit a rebake walks.
+        final record = Uint32List.fromList(visited);
+        for (final key in band.keys) {
+          // A key this frame's tile map already serves keeps its own image and
+          // its own, narrower record. Overwriting it would leak the image it
+          // replaced -- `_tiles[key] = tile` disposes nothing -- and a pan
+          // within one generation reaches this loop with most of the row
+          // already held.
+          if (_tiles.containsKey(key)) {
+            _lastUsedFrame[key] = _frameSerial;
+            continue;
+          }
+          debugOnSliceForTest?.call();
+          // The ceiling is consulted before the write, not after the frame --
+          // the rule the tile loop already follows. The slice bypasses
+          // `budgetedTilesPerFrame`, which rations bakes; a slice is not a
+          // bake.
+          if (!_makeRoomForOneTile()) break;
+          final tile = _sliceTile(image, band, key, grid);
+          _tiles[key] = tile;
+          _baked[key] = record;
           _lastUsedFrame[key] = _frameSerial;
-          continue;
         }
-        debugOnSliceForTest?.call();
-        // The ceiling is consulted before the write, not after the frame --
-        // the rule the tile loop already follows. The slice bypasses
-        // `budgetedTilesPerFrame`, which rations bakes; a slice is not a bake.
-        if (!_makeRoomForOneTile()) break;
-        final tile = _sliceTile(image, band, key, grid);
-        _tiles[key] = tile;
-        _baked[key] = record;
-        _lastUsedFrame[key] = _frameSerial;
+      } finally {
+        _band = null;
+        _disposeImage(image);
       }
-      _band = null;
-      _disposeImage(image);
       _bakes++;
     }
   }
 
   /// [_bake]'s owner climb, applied once to a whole band's visit list.
   ///
   /// **Direction one of the invalidation rule, which the band walk cannot
   /// record for itself.** A tile's `_baked` record has to name not only the
   /// entities drawn on it but every container they hang under, or a transform
   /// applied to a group never condemns the tiles its children inked and the
   /// drawing goes stale after an edit. [_bake] does this inside its own
   /// `onVisit`; a band's `onVisit` records the direct visit alone and this
@@ -2244,14 +2337,21 @@ class TileCache {
       // Restored even on a throw: a painter left with a stale origin would
       // draw the *next* frame against a tile's rebase point.
       painter.debugRebaseOrigin = null;
       painter.debugOnVisit = null;
     }
   }
 
   void dispose() {
     _disposeTiles();
     _dropCarryOver();
     _grid = null;
     _lastCamera = null;
+    // A band never outlives its own iteration of [_restBake]'s loop -- the
+    // `finally` there disposes the image and clears this field on every exit,
+    // throw included -- so this is belt and braces rather than a release.
+    // It is here because [liveBytes] reads the field: leaving a disposed
+    // image's dimensions in it would let a disposed cache still report a
+    // band's worth of bytes.
+    _band = null;
   }
 }
diff --git a/packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart b/packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart
index f35d997..e4c5134 100644
--- a/packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart
+++ b/packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart
@@ -575,17 +575,29 @@ void main() {
     // "eviction runs with a composite standing, and never takes it" test
     // above, which pans repeatedly under a ceiling most of which is the
     // composite; nothing is lost by this one measuring the other half.
     expect(squeezed.cache.liveTileCount, 0,
         reason: 'the ceiling admitted no tile at all: not one was baked '
             'beside the composite, which is what "bakes nothing rather than '
             'overrun" means on a frame whose generation starts empty');
     expect(squeezed.cache.bakeCount, 0,
         reason: 'baking under a ceiling that cannot hold the result is the '
             'silent overrun this arm exists to refuse -- and the rest bake '
             'refuses it too, band and all, rather than banding into a '
             'ceiling that cannot keep the slices');
-    expect(squeezed.cache.liveDrawCount, 1,
+    // **Two walks, one per frame that owed one, and the pan frame is the one
+    // that changed.** Before the D8 fix a same-scale pan with a composite
+    // standing took `paintFrame`'s moving-frame early return, so the three
+    // frames below were: pan -- composite only, no walk; the in-between
+    // frame; then the rest frame, whose rest bake the ceiling declines and
+    // whose tile loop the ceiling admits nothing to, leaving one live walk.
+    // The pan is a pan and not a zoom, so it is no longer a moving frame: it
+    // falls through and pays its own walk over a viewport the shrunken
+    // ceiling cannot tile. That is the whole point of the fix -- the region
+    // the composite slid off is drawn rather than left as background -- and
+    // the number moving from 1 to 2 is what records it.
+    expect(squeezed.cache.liveDrawCount, 2,
         reason: 'and the live walk is what stops the frame going blank '
-            'instead');
+            'instead -- once on the pan frame, which no longer hides behind '
+            'the composite, and once on the rest frame that follows it');
   });
 }
diff --git a/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart b/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart
index 657af33..9998d97 100644
--- a/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart
+++ b/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart
@@ -1,18 +1,19 @@
 import 'dart:ui' as ui;
 
 import 'package:flutter/widgets.dart';
 import 'package:flutter_test/flutter_test.dart';
 import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
 
+import '../support/tile_fixture.dart';
 import '../support/tile_harness.dart';
 
 void main() {
   test('a live band image is counted in liveBytes', () {
     final cache = TileCache(tileDevicePixels: 64);
     addTearDown(cache.dispose);
     final before = cache.liveBytes;
 
     final recorder = ui.PictureRecorder();
     Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 8, 8),
         Paint()..color = const Color(0xFF00FF00));
     final picture = recorder.endRecording();
@@ -51,13 +52,116 @@ void main() {
     };
     addTearDown(() => h.cache.debugOnSliceForTest = null);
 
     h.camera.zoomAt(const Offset(120, 90), 1.3);
     await t.pump();
     await t.pump();
     await t.pump();
 
     expect(h.cache.debugImagesAlive, h.cache.liveTileCount,
         reason: 'no band image outlives its band, and the composite was '
             'dropped before the bake');
   });
+
+  testWidgets('the ceiling binds inside the rest frame, and eviction holds it',
+      (t) async {
+    final h = await pumpTiled(t, document: bandCrossingGrid);
+    await settle(t, h);
+    const tileBytes = 64 * 64 * 4;
+    // A band is the visible key range's full width, one tile tall: 13 columns
+    // at this 800 x 600 device-pixel viewport.
+    const bandBytes = 13 * tileBytes;
+    expect(h.cache.liveTileCount, 130,
+        reason: 'what this viewport is, asserted rather than assumed: '
+            '13 x 10 tiles');
+
+    // **The pan is the setup, and what it leaves behind is the point.** Keys
+    // that left the viewport stay in the map until something reclaims them,
+    // so the cache below holds the visible set *and* a tail of stale tiles --
+    // which is the only state in which the rest frame's ceiling has anything
+    // to do. Without it the frame's own pricing guarantees room and no
+    // eviction ever runs inside a rest bake.
+    h.camera.panBy(const Offset(-96, -96));
+    await settle(t, h);
+    // **Two repaints at the same camera, because the pan settled without
+    // arming the gate.** Most of the visible set survives a three-tile pan,
+    // so the budgeted loop covers the viewport on the pan frame itself and
+    // the canvas stops asking for frames with the rest gate still at zero.
+    // `repaintOnce` notifies with a numerically identical camera, which is
+    // what the gate counts.
+    await repaintOnce(t, h);
+    await repaintOnce(t, h);
+    expect(h.cache.debugRestGateSteps, greaterThanOrEqualTo(kRestGateFrames),
+        reason: 'setup: the frame after the edit has to be a rest frame, or '
+            'the budgeted per-tile loop refills the condemned band and the '
+            'band path is never reached');
+
+    final held = h.cache.liveTileCount;
+    expect(held, greaterThan(130),
+        reason: 'setup: the pan must have left stale keys behind, or the '
+            'cap below is not one the frame has to work against');
+
+    // **This is what the old arm could not do.** It asserted `liveBytes <=
+    // kTileCacheBytes` on a fixture whose entire peak was 2,342,912 bytes
+    // against 100,663,296 -- 43x of headroom, where no mutation to the rest
+    // bake could move the number far enough to fail. Criterion 7 says the
+    // ceiling holds "at every point inside the rest frame"; a ceiling nothing
+    // can reach is not a measurement of that.
+
+    final evictedBefore = h.cache.evictionCount;
+    h.moveOneEntityWithinOneBand();
+    // **One pump for the edit to arrive, then the cap, then the rest frame.**
+    // `DraftDocument`'s change stream reaches `TileCache.applyChange` through
+    // the widget rather than from `execute`, so the condemned tiles are still
+    // in the map on the line after the edit and the frame that drops them is
+    // this pump. Pricing before it would leave the cap a condemned band's
+    // worth too generous and nothing would ever have to be reclaimed.
+    await t.pump();
+    final afterEdit = h.cache.liveTileCount;
+    expect(afterEdit, lessThan(held),
+        reason: 'setup: the edit must have condemned tiles by now, or the '
+            'cap below is priced against a generation that never lost any');
+
+    // **A cap the frame reaches on every slice, derived rather than picked.**
+    // One band plus everything the cache is holding: large enough that
+    // `_restBake`'s up-front pricing (one band plus the *visible* set, which
+    // is smaller than what the pan left held) proceeds, and tight enough that
+    // the first `_makeRoomForBytes` must reclaim before the band image can
+    // exist, and every slice after it must reclaim again before its tile can.
+    // The frame runs at its ceiling from the first slice to the last.
+    final cap = bandBytes + afterEdit * tileBytes;
+    h.cache.cacheBytes = cap;
+
+    var peak = 0;
+    var slices = 0;
+    h.cache.debugOnSliceForTest = () {
+      slices++;
+      final bytes = h.cache.liveBytes;
+      if (bytes > peak) peak = bytes;
+      expect(bytes, lessThanOrEqualTo(cap),
+          reason: 'criterion 7, at a cap that can be reached: the band image '
+              'is resident here and the meter counts it');
+    };
+    addTearDown(() => h.cache.debugOnSliceForTest = null);
+
+    await settle(t, h);
+    h.cache.debugOnSliceForTest = null;
+
+    expect(slices, greaterThan(0),
+        reason: 'non-vacuity: the rest bake must have run and cut tiles, or '
+            'the ceiling was observed nowhere');
+    expect(h.cache.evictionCount, greaterThan(evictedBefore),
+        reason: 'and it ran with the ceiling binding: this cap cannot hold '
+            'what the pan left plus a band, so the frame had to reclaim '
+            'inside itself rather than at its edges. Measured: 12 slices, '
+            '12 evictions, and a peak of exactly cap');
+    expect(peak, greaterThan(cap - 2 * tileBytes),
+        reason: 'and the frame ran within one tile of the cap the whole way, '
+            'which is what makes the clause above a measurement: at 43x of '
+            'headroom no mutation to the rest bake can move liveBytes far '
+            'enough to fail it');
+    expect(h.cache.debugImagesAlive, h.cache.liveTileCount,
+        reason: 'no band image outlives its band here either');
+    expect(h.cache.viewportCovered, isTrue,
+        reason: 'and the frame still filled the viewport under the cap');
+  });
 }
diff --git a/packages/jet_cad_2d_flutter/test/support/tile_comparison.dart b/packages/jet_cad_2d_flutter/test/support/tile_comparison.dart
index ed04196..25aa4e4 100644
--- a/packages/jet_cad_2d_flutter/test/support/tile_comparison.dart
+++ b/packages/jet_cad_2d_flutter/test/support/tile_comparison.dart
@@ -553,24 +553,55 @@ Future<ByteData> captureLive(WidgetTester t, TiledHarness h) async {
           index: h.index,
           camera: controller,
           tiles: false,
           tileDevicePixels: 64,
         ),
       )),
     ),
   ));
   await t.pump();
   return _captureBoundary(t);
 }
 
+/// Non-transparent pixels of a **widget capture** inside [logical], a
+/// rectangle in logical pixels scaled by [kTileDpr] and clipped to the
+/// capture.
+///
+/// [inkInside] answers the same question for a [TileRig] capture, which is a
+/// `Uint8List`; this one takes the `ByteData` [captureTiled] and [captureLive]
+/// return, and is indexed against [kCaptureWidth] rather than against
+/// [kTileViewport], for the reason [differingPixelsOnTileEdges] states: a
+/// capture of another size is read as the wrong quarter of itself and still
+/// reports a number.
+///
+/// **Ink, not agreement.** The question it exists for is "did the frame draw
+/// anything here at all, or is this region background" -- which is what a
+/// blank strip left by a frame that returned early looks like, and which a
+/// whole-frame `differingPixels` buries under the tiles around it.
+int inkInsideCapture(ByteData capture, Rect logical) {
+  expect(capture.lengthInBytes, kCaptureWidth * kCaptureHeight * 4,
+      reason: 'the sweep indexes rows by kCaptureWidth');
+  final x0 = (logical.left * kTileDpr).floor().clamp(0, kCaptureWidth);
+  final x1 = (logical.right * kTileDpr).ceil().clamp(0, kCaptureWidth);
+  final y0 = (logical.top * kTileDpr).floor().clamp(0, kCaptureHeight);
+  final y1 = (logical.bottom * kTileDpr).ceil().clamp(0, kCaptureHeight);
+  var ink = 0;
+  for (var y = y0; y < y1; y++) {
+    for (var x = x0; x < x1; x++) {
+      if (capture.getUint8((y * kCaptureWidth + x) * 4 + 3) != 0) ink++;
+    }
+  }
+  return ink;
+}
+
 /// Pixels whose RGBA differs, over two captures of the same size.
 ///
 /// Exact `==` on stored bytes, never a tolerance: these are recorded values,
 /// and a tolerance here is how a seam of one unit hides.
 int differingPixels(ByteData a, ByteData b) {
   expect(a.lengthInBytes, b.lengthInBytes);
   var differing = 0;
   for (var i = 0; i < a.lengthInBytes; i += 4) {
     if (a.getUint32(i) != b.getUint32(i)) differing++;
   }
   return differing;
 }
diff --git a/packages/jet_cad_2d_flutter/test/support/tile_harness.dart b/packages/jet_cad_2d_flutter/test/support/tile_harness.dart
index a6da311..926a1e0 100644
--- a/packages/jet_cad_2d_flutter/test/support/tile_harness.dart
+++ b/packages/jet_cad_2d_flutter/test/support/tile_harness.dart
@@ -45,24 +45,45 @@ class TiledHarness {
   /// [288, 320) -- and row 1 spans device y [64, 128) -- logical [32, 64).
   /// [bandCrossingGrid]'s doc comment places [kMovableHandle]'s resting
   /// position at tile column 2, row 4 -- seven columns and three rows clear
   /// of this destination, far outside [kTileSlack]'s one-tile ring, so the
   /// two tile sets are disjoint by construction and the test only has to
   /// confirm it.
   void moveOneEntityOntoDisjointTiles() {
     double worldX(double screenX) => (screenX + 37.0) / 1.4;
     double worldY(double screenY) => (323.0 - screenY) / 1.4;
     document.commands.execute(TransformNodeCommand(
         kMovableHandle, Transform2(1, 0, 0, 1, worldX(300), worldY(48))));
   }
+
+  /// Moves [kMovableHandle] **along its own tile row**, so exactly one band is
+  /// condemned, for the per-band rest-bake probe.
+  ///
+  /// The same arithmetic as [moveOneEntityOntoDisjointTiles] and a different
+  /// destination, chosen so that both directions of invalidation land in the
+  /// same band. Direction one condemns every tile whose `_baked` record names
+  /// the handle, and a sliced tile's record is its **whole band's** (spec D6),
+  /// so the old position condemns row 4 entire. Direction two condemns the
+  /// tiles the new geometry reaches: screen (300, 144) with the leaf's local
+  /// (0, 0)-(6, 6) diagonal reaching screen (308.4, 135.6) -- both inside row
+  /// 4, which spans device y [256, 320), logical [128, 160). So the band set
+  /// this edit condemns is `{row 4}` and the other nine rows of the viewport
+  /// are untouched, which is the whole point: a rest bake that walks them
+  /// anyway is walking a whole viewport to replace one row.
+  void moveOneEntityWithinOneBand() {
+    double worldX(double screenX) => (screenX + 37.0) / 1.4;
+    double worldY(double screenY) => (323.0 - screenY) / 1.4;
+    document.commands.execute(TransformNodeCommand(
+        kMovableHandle, Transform2(1, 0, 0, 1, worldX(300), worldY(144))));
+  }
 }
 
 /// Pumps a tiled canvas over `fillingGrid`, which inks every tile of
 /// [kTileViewport] at [tileCamera] -- so "nothing was drawn" can never be
 /// mistaken for "there was nothing to draw".
 Future<TiledHarness> pumpTiled(
   WidgetTester t, {
   DraftDocument Function(FlutterTextMeasurer)? document,
   ViewportTransform? camera,
 }) async {
   final measurer = FlutterTextMeasurer();
   addTearDown(measurer.clear);
diff --git a/packages/jet_cad_2d_flutter/test/tile_grid_test.dart b/packages/jet_cad_2d_flutter/test/tile_grid_test.dart
index 09eee72..85c8660 100644
--- a/packages/jet_cad_2d_flutter/test/tile_grid_test.dart
+++ b/packages/jet_cad_2d_flutter/test/tile_grid_test.dart
@@ -147,14 +147,62 @@ void main() {
     test('matchesScale is exact, not tolerant', () {
       final grid = gridAt(awkwardCamera());
       final m = grid.anchor.worldToScreenMatrix;
       expect(grid.matchesScale(grid.anchor), isTrue);
       // One ulp of zoom retires the generation. Stored-value comparisons in
       // this repository are exact `==`; a tolerant scale test would replay a
       // generation baked at a different stroke width and dash phase.
       final nudged = ViewportTransform(
           worldToScreenMatrix:
               Transform2(m.a + m.a * 1e-15, m.b, m.c, m.d, m.e, m.f));
       expect(grid.matchesScale(nudged), isFalse);
     });
+
+    // **Four fields, four arms, one field moved per arm.** `awkwardCamera`
+    // has `d == -a` and `b == c == 0`, so the arm above -- which moves `a`
+    // alone -- is the only one of the four comparisons it can fail: deleting
+    // `a.b == b.b`, `a.c == b.c` or `a.d == b.d` from `matchesScale` left the
+    // file green. This is `sameQuantisedCamera`'s own degeneracy (M19) at the
+    // other stored-value comparison in this file, closed the same way, and it
+    // needs its own fixture because no camera the tiled tests drive reaches
+    // `matchesScale` with `b`, `c` or an independent `d`.
+    test('every scale term is compared, one at a time', () {
+      // Anisotropic *and* skewed, so no two of the four terms are tied.
+      final grid = gridAt(ViewportTransform(
+          worldToScreenMatrix:
+              Transform2(2.5, 0.3, -0.7, -1.9, 17.31, 409.77)));
+      final m = grid.anchor.worldToScreenMatrix;
+      expect(grid.matchesScale(grid.anchor), isTrue,
+          reason: 'non-vacuity: the anchor matches itself, so the four arms '
+              'below fail for the field they move and not for the fixture');
+      expect(
+          grid.matchesScale(ViewportTransform(
+              worldToScreenMatrix: Transform2(2.6, m.b, m.c, m.d, m.e, m.f))),
+          isFalse,
+          reason: 'a: the x scale');
+      expect(
+          grid.matchesScale(ViewportTransform(
+              worldToScreenMatrix: Transform2(m.a, 0.4, m.c, m.d, m.e, m.f))),
+          isFalse,
+          reason: 'b: a generation baked without this shear cannot blit with '
+              'it');
+      expect(
+          grid.matchesScale(ViewportTransform(
+              worldToScreenMatrix: Transform2(m.a, m.b, -0.8, m.d, m.e, m.f))),
+          isFalse,
+          reason: 'c: the other shear term');
+      expect(
+          grid.matchesScale(ViewportTransform(
+              worldToScreenMatrix: Transform2(m.a, m.b, m.c, -2.0, m.e, m.f))),
+          isFalse,
+          reason: 'd: the y scale, which every tiled fixture ties to -a');
+      // And the translation is *not* in this comparison: a pan keeps the
+      // generation, which is the whole reason the key excludes translation.
+      expect(
+          grid.matchesScale(ViewportTransform(
+              worldToScreenMatrix:
+                  Transform2(m.a, m.b, m.c, m.d, m.e + 13, m.f - 7))),
+          isTrue,
+          reason: 'a pan does not retire a generation');
+    });
   });
 }
diff --git a/packages/jet_cad_2d_flutter/test/tile_regime_test.dart b/packages/jet_cad_2d_flutter/test/tile_regime_test.dart
index b9de199..6f431ed 100644
--- a/packages/jet_cad_2d_flutter/test/tile_regime_test.dart
+++ b/packages/jet_cad_2d_flutter/test/tile_regime_test.dart
@@ -1,40 +1,69 @@
+import 'dart:ui';
+
 import 'package:flutter_test/flutter_test.dart';
 import 'package:jet_cad_2d/jet_cad_2d.dart';
 import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
 
+import 'support/tile_comparison.dart';
+import 'support/tile_fixture.dart';
 import 'support/tile_harness.dart';
 
 void main() {
   ViewportTransform at(double scale, double e, double f) => ViewportTransform(
       worldToScreenMatrix: Transform2(scale, 0, 0, -scale, e, f));
 
   test('the same camera compares same', () {
     expect(sameQuantisedCamera(at(1.4, 10, 20), at(1.4, 10, 20)), isTrue);
   });
 
   test('a scale change compares different', () {
     expect(sameQuantisedCamera(at(1.4, 10, 20), at(1.5, 10, 20)), isFalse);
   });
 
   // Translation is in the comparison and not only scale. Immediately after a
   // zoom the generation is empty, so a pan that follows keeps the scale and
   // does not cover the viewport: under a scale-only rule two same-scale pan
   // frames would satisfy every rest condition and spend a full bake while the
   // camera is still moving.
   test('a translation change compares different', () {
     expect(sameQuantisedCamera(at(1.4, 10, 20), at(1.4, 11, 20)), isFalse);
     expect(sameQuantisedCamera(at(1.4, 10, 20), at(1.4, 10, 21)), isFalse);
   });
 
+  // **`a` and `d` are separate fields and every other fixture here ties them
+  // together.** The `at()` helper builds `Transform2(scale, 0, 0, -scale, ...)`
+  // and 'a scale change compares different' moves both at once, so deleting
+  // either `x.a == y.a &&` or `x.d == y.d &&` left the other one firing and
+  // the whole suite green -- M12's defect one field over, recorded as a
+  // deferred minor at Task 1 and closed here. An anisotropic camera is what
+  // separates them: `d != -a`, and each arm moves one term only.
+  test('the two scale terms are compared independently', () {
+    ViewportTransform anisotropic(double a, double d) =>
+        ViewportTransform(worldToScreenMatrix: Transform2(a, 0, 0, d, 10, 20));
+
+    expect(sameQuantisedCamera(anisotropic(1.4, -2.1), anisotropic(1.4, -2.1)),
+        isTrue,
+        reason: 'non-vacuity: two equal anisotropic cameras must still '
+            'compare same, or the two arms below pass for want of any '
+            'agreement at all');
+    expect(sameQuantisedCamera(anisotropic(1.4, -2.1), anisotropic(1.5, -2.1)),
+        isFalse,
+        reason: 'x scale alone, with y held: a generation anchored at one x '
+            'scale cannot blit at another');
+    expect(sameQuantisedCamera(anisotropic(1.4, -2.1), anisotropic(1.4, -2.2)),
+        isFalse,
+        reason: 'y scale alone, with x held');
+  });
+
   test('the skew terms are compared too', () {
     final a = ViewportTransform(
         worldToScreenMatrix: Transform2(1.4, 0.1, 0, -1.4, 10, 20));
     final b = ViewportTransform(
         worldToScreenMatrix: Transform2(1.4, 0.2, 0, -1.4, 10, 20));
     expect(sameQuantisedCamera(a, b), isFalse);
 
     // The other skew term. Every other fixture in this file, including `a`
     // and `b` above, leaves `c` at 0 -- so without a case that varies it,
     // deleting `x.c == y.c` from the comparison kills no test here.
     final c1 = ViewportTransform(
         worldToScreenMatrix: Transform2(1.4, 0, 0.1, -1.4, 10, 20));
@@ -150,18 +179,183 @@ void main() {
             reason: 'the first zoom retires the settled generation into a '
                 'composite; without it this test is vacuous');
       }
 
       await t.pump(); // one unchanged frame before the next notch
     }
 
     expect(h.cache.bakeCount, 0,
         reason: 'a wheel that keeps turning must never reach two consecutive '
             'unchanged frames, so it must never bake');
   });
 
-  test('the gate needs two unchanged frames, not one', () {
-    // The threshold itself, stated where a reader can see it: one unchanged
-    // frame is the in-between frame and draws like a moving one.
+  // **Spec D8: the pan path is untouched.** A pan straight after a zoom is the
+  // frame this whole test exists for, and it was drawing only the stale
+  // composite for the length of the gesture: `CameraController.panBy` copies
+  // `a, b, c, d` bit-identically, so `TileGrid.matchesScale` holds, `_gridFor`
+  // returns the standing grid without retiring, and the composite the zoom
+  // minted survives every pan frame. With the camera changing every frame the
+  // rest gate never armed, so `_tiles` stayed empty and the region the
+  // composite slid off stayed background until the user stopped moving.
+  //
+  // A macOS trackpad reaches this directly: any stretch of a gesture where the
+  // pan continues after the scale stops changing.
+  testWidgets('a pan after a zoom fills the region the composite slides off',
+      (t) async {
+    final h = await pumpTiled(t);
+    await settle(t, h);
+    expect(h.cache.viewportCovered, isTrue,
+        reason: 'setup: a generation that covers is what a zoom can retire '
+            'into a composite');
+
+    // One zoom step, and one only: the settled generation is flattened into
+    // the composite and every tile disposed, which is the state the pan below
+    // starts from.
+    h.camera.zoomAt(const Offset(120, 90), 1.3);
+    await t.pump();
+    expect(h.cache.hasCarryOver, isTrue,
+        reason: 'setup: the zoom minted the composite the pan then carries');
+    expect(h.cache.liveTileCount, 0,
+        reason: 'setup: and retired every tile, so anything the pan frames '
+            'put on screen below is theirs');
+
+    h.cache.resetCounters();
+    // Four pan frames at exactly the scale the zoom left. Enough that the
+    // composite -- magnified 1.3x about (120, 90), so it reaches x = 484 in a
+    // 400-wide viewport -- slides its right edge inside the viewport and
+    // stops covering.
+    for (var i = 0; i < 4; i++) {
+      h.camera.panBy(const Offset(-40, 0));
+      await t.pump();
+    }
+
+    expect(h.cache.bakeCount, greaterThan(0),
+        reason: 'a pan is not a moving frame (spec D1 defines moving by the '
+            'scale) and D8 leaves the pan path baking at its edge');
+    expect(h.cache.liveTileCount, greaterThan(0),
+        reason: 'and the tiles it bakes are what fill the revealed region '
+            'once the composite no longer covers it');
+
+    // **The pixels, not only the counters.** The strip below is the part of
+    // the viewport the composite has slid off: its right edge sits at
+    // 120 + 1.3 * 280 - 160 = 324 logical after the four pans, so
+    // [324, 400) x [0, 300) is served by the incoming generation alone. A
+    // frame that returned early leaves it transparent.
+    const revealed = Rect.fromLTRB(324, 0, 400, 300);
+    final tiled = await captureTiled(t, h);
+    final ink = inkInsideCapture(tiled, revealed);
+    // `captureLive` replaces the widget tree and disposes the cache behind
+    // `h`, so it comes last and nothing is read from the cache after it.
+    final live = await captureLive(t, h);
+    expect(inkInsideCapture(live, revealed), greaterThan(200),
+        reason: 'non-vacuity: the fixture must actually draw in the strip, '
+            'or "the tiled frame drew nothing there" is not a defect');
+    expect(ink, greaterThan(200),
+        reason: 'the region the composite slid off must carry the drawing, '
+            'not background: this is spec D3 accepting a ring on a zoom '
+            '*out* and nothing else');
+  });
+
+  // **Spec D6 and the rest bake's own doc comment, at the granularity the
+  // walk happens at.** One missing key anywhere in the viewport used to
+  // commit every band to a full painter walk, an owner climb, a
+  // `toImageSync` and a `_bakes++` -- and then to throw the image away,
+  // because the per-key skip inside the band loop skips only the slice.
+  //
+  // This is the ordinary edit path: after an `applyChange` the camera has not
+  // moved, so the gate is still armed and the next frame rest-bakes, while
+  // invalidation has typically condemned one band.
+  testWidgets('an edit inside one band rebakes that band alone', (t) async {
+    final h = await pumpTiled(t, document: bandCrossingGrid);
+    await settleFromBands(t, h);
+
+    // **The control, measured rather than assumed.** A whole-generation drop
+    // at the same camera is the same rest frame with every band missing, and
+    // the number it bakes is what "all of them" means on this viewport. The
+    // assertion below is only worth making because this one is larger.
+    h.cache.resetCounters();
+    h.document.tables.layers.add(const LayerRecord(
+      handle: Handle(901),
+      name: 'ALL-BANDS',
+      color: IndexedColor(3),
+      linetype: ReservedHandles.continuousLinetype,
+      lineweight: 50,
+      transparency: 0,
+    ));
+    await t.pump();
+    await settle(t, h);
+    final allBands = h.cache.bakeCount;
+    expect(allBands, greaterThan(5),
+        reason: 'non-vacuity: the viewport must span several bands, or "one '
+            'band, not all of them" is a distinction without a difference');
+    expect(h.cache.viewportCovered, isTrue,
+        reason: 'setup: the control frame refilled what it dropped');
+
+    // The measurement: one edit, inside one band.
+    h.cache.resetCounters();
+    final invalidatedBefore = h.cache.invalidationCount;
+    h.moveOneEntityWithinOneBand();
+    await t.pump();
+    await settle(t, h);
+
+    expect(h.cache.invalidationCount, greaterThan(invalidatedBefore),
+        reason: 'setup: the edit must have condemned tiles, or the rest bake '
+            'below had nothing to do for a reason that is not the probe');
+    // **Three of ten, and the three are derivable rather than observed.**
+    // Direction one of invalidation condemns every tile whose `_baked` record
+    // names the handle, and a sliced tile's record is its whole band's (spec
+    // D6). A band's walk is *queried* padded by [kTileSlack] and clipped hard
+    // (spec D4/D7), and `kTileSlack` is 32 logical pixels -- exactly one tile
+    // row at this harness's 64 device pixels and `kTileDpr` of 2 -- so a leaf
+    // resting in row 4 is visited by the walks for rows 3, 4 and 5 and named
+    // in all three records. Measured: 39 tiles condemned, 3 x 13. The number
+    // to compare it against is `allBands`, not one: the defect this pins is a
+    // rest bake that walked all ten and threw seven images away.
+    expect(h.cache.bakeCount, 3,
+        reason: 'only the bands the edit condemned owe a walk; the other '
+            '${allBands - 3} hold every key they need, and rebaking them '
+            'replaces good images with identical ones -- a whole-viewport '
+            'walk for three rows, on every frame of a drag');
+    expect(h.cache.bakeCount, lessThan(allBands),
+        reason: 'stated twice on purpose: the exact 3 pins the pad is reach, '
+            'and this clause is the one that fails if the frame-global probe '
+            'comes back and every band bakes again');
+    expect(h.cache.viewportCovered, isTrue,
+        reason: 'and skipping them must not leave a hole: a skipped band '
+            'keeps its tiles, and they are still blitted');
+  });
+
+  testWidgets('a skipped band keeps its tiles out of the ceiling\'s reach',
+      (t) async {
+    // The other half of the skip, and the half that is easy to get wrong.
+    // `_makeRoomForBytes` may evict any tile whose recency is older than this
+    // frame's, so a band skipped *without* touching its keys' recency would
+    // leave them evictable by a later band's own room-making -- and the frame
+    // would blit a hole in a row it had already decided it owned. The rest
+    // bake's up-front pricing rests on exactly that: at band `i` the
+    // un-evictable set is the keys of bands `0..i-1`.
+    final h = await pumpTiled(t, document: bandCrossingGrid);
+    await settleFromBands(t, h);
+    final tiles = h.cache.liveTileCount;
+
+    h.cache.resetCounters();
+    final evictedBefore = h.cache.evictionCount;
+    h.moveOneEntityWithinOneBand();
+    await t.pump();
+    await settle(t, h);
+
+    expect(h.cache.evictionCount, evictedBefore,
+        reason: 'nothing may be evicted here: every visible key carries this '
+            'frame is serial, skipped bands included');
+    expect(h.cache.liveTileCount, tiles,
+        reason: 'the generation is whole again and exactly as large as it '
+            'was: one band rebaked, nine left standing');
+  });
+
+  test('the gate is two unchanged frames, and the constant says so', () {
+    // A restatement of the constant and named as one. The *behaviour* it
+    // gates is 'a steadily spun wheel never arms the rest gate' above, which
+    // is what reddens under M4b; this line exists so a reader who changes the
+    // constant sees the threshold the wheel test was written against.
     expect(kRestGateFrames, 2);
   });
 }
diff --git a/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart b/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart
index 010a05f..e4a701a 100644
--- a/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart
+++ b/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart
@@ -98,25 +98,43 @@ void main() {
     // centreline lies within its own half-width *outside* a viewport edge is
     // drawn by the tiled frame and missed by the live one -- the tiled frame
     // is the correct one, and the difference is a property of the reference.
     // At `Offset(-90, -60)` this fixture's thick stroke at world y 184.286
     // lands at screen y -2.5 against a 3.78 half-width and the arm read 1,767
     // stray pixels across the top three device rows. At `Offset(90, 60)` the
     // four such windows are world y in (248.9, 250.98) and (82.0, 84.07) and
     // world x in (-5.37, -3.30) and (216.48, 218.56), and no thick stroke this
     // fixture places falls in any of them. Reported as a finding: the
     // asymmetry is real and belongs to `DraftPainter`, not to the tile path.
     h.camera.panBy(const Offset(90, 60));
     await t.pump(); // moving again, so the rest gate starts over
+    // **The slice count is what pins this arm to the slice path.** Arms 1, 2
+    // and 5 settle through `settleFromBands`, which asserts `slices ==
+    // liveTileCount`; this arm's second settle asserted only `hasCarryOver`
+    // and the pixel count, and was sound solely because `_restBake` runs
+    // ahead of the budgeted tile loop inside `paintFrame`. That is a property
+    // of statement order, not of anything this test checks: if the budgeted
+    // loop ever filled first, this arm would go green with no tile cut from a
+    // band at all and M10 -- the slice rectangle measured in grid space --
+    // would survive it silently, which is the one mutant the arm exists for.
+    var slices = 0;
+    h.cache.debugOnSliceForTest = () => slices++;
+    addTearDown(() => h.cache.debugOnSliceForTest = null);
     await settle(t, h);
+    h.cache.debugOnSliceForTest = null;
+    expect(slices, greaterThan(0),
+        reason: 'this arm judges the slice path at a negative key range, so '
+            'the settle it judges has to have cut tiles out of a band. '
+            'Measured: 66 of the 130 visible tiles, the other 64 being the '
+            'pan frame is own budgeted bakes');
     // The rest frame blitted the outgoing composite underneath the generation
     // it then dropped, so it is not a statement about the new tiles alone.
     // See `repaintOnce`; `tile_cache_test`'s criterion 1 pays for the same
     // frame and asserts the same thing before comparing.
     await repaintOnce(t, h);
     expect(h.cache.hasCarryOver, isFalse,
         reason: 'a composite still on screen composes the outgoing '
             'generation under every transparent pixel of the incoming one');
     expect(
         differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
         reason: 'a grid-space slice rectangle reads off the wrong part of the '
             'band image as soon as the visible key range moves');
```
