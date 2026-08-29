# Waves C+D re-review package (c5794d7..HEAD)
750316b docs: M23 dies, M24 survives and the derivation says why it must
d74d620 fix(tiles): the frame a pan stops on drew only the composite
001599b docs: M22's record, and the ceiling arm's mutant is M21 and not M20
85e0726 fix(harness): the zoom phase read ordinals out of a stream it never drained

```
 apps/dev_harness_2d/lib/main.dart                  |   7 +
 apps/dev_harness_2d/lib/measurement_rig.dart       | 222 ++++++++-
 .../test/settle_attribution_test.dart              | 288 +++++++++++-
 apps/dev_harness_2d/test/zoom_arm_wiring_test.dart |   2 +-
 docs/superpowers/notes/plan-3i-mutation-log.md     | 514 ++++++++++++++++++++-
 .../jet_cad_2d_flutter/lib/src/tile_cache.dart     |  46 +-
 .../test/invariants/tile_budget_test.dart          |  37 +-
 .../test/support/tile_comparison.dart              |  28 ++
 .../jet_cad_2d_flutter/test/tile_regime_test.dart  | 213 ++++++++-
 9 files changed, 1317 insertions(+), 40 deletions(-)
```
```diff
diff --git a/apps/dev_harness_2d/lib/main.dart b/apps/dev_harness_2d/lib/main.dart
index e17365a..c57b6c8 100644
--- a/apps/dev_harness_2d/lib/main.dart
+++ b/apps/dev_harness_2d/lib/main.dart
@@ -553,24 +553,31 @@ Future<void> _driveR2(
   // `runR2Rig` describe the same starting state. Off by default -- see
   // [kZoomArms]. What the repeats are *for* is [kZoomMode].
   if (tileCache != null && kZoomArms > 0) {
     // The pinned reference viewport (§5), not `viewport` above -- see
     // `runTileZoomPhase`'s doc comment for what a differently sized real
     // window means for these numbers.
     const zoomViewport = Size(1600, 1200);
     warnIfZoomViewportMismatch(viewport, zoomViewport);
 
     // One arm: back to the fitted camera, then the whole pinned script. The
     // camera reset is here rather than inside the phase because the arms of a
     // ratio must start from the same camera, and the phase does not own it.
+    //
+    // **This pump's `FrameTiming` lands inside the phase, not before it.**
+    // `_pumpFrame` completes at `SchedulerBinding.endOfFrame`, before the
+    // frame rasterises, so the timing arrives after `runTileZoomPhase` has
+    // armed its log. The phase drains it — see
+    // `FrameTimingLog.establishBaseline` — rather than this call site trying
+    // to order itself against a report that has not happened yet.
     Future<ZoomReport> runArm() async {
       camera.value = fittedCamera;
       await _pumpFrame();
       return runTileZoomPhase(
         camera: camera,
         cache: tileCache,
         pumpFrame: _pumpFrame,
         viewport: zoomViewport,
       );
     }
 
     switch (kZoomMode) {
diff --git a/apps/dev_harness_2d/lib/measurement_rig.dart b/apps/dev_harness_2d/lib/measurement_rig.dart
index f02544a..b72ffeb 100644
--- a/apps/dev_harness_2d/lib/measurement_rig.dart
+++ b/apps/dev_harness_2d/lib/measurement_rig.dart
@@ -702,32 +702,70 @@ void warnIfZoomViewportMismatch(Size real, Size pinned) {
 /// this frame" names the wrong frame systematically rather than occasionally,
 /// and re-registering a callback around a phase boundary drops the tail of one
 /// phase instead of moving it. That is the hazard [runR2Rig] states at its own
 /// registration, and the reason this type exists.
 ///
 /// **The rule.** One registration spans every frame the phase pumps; delivery
 /// order is pump order; frame *i*'s timing is the *i*-th one delivered. Frames
 /// pumped before [arm] are therefore poison -- their timings arrive *after*
 /// registration and would take the ordinals of frames that came later -- so a
 /// phase arms this log before its own warm-up frames and excludes the warm-up
 /// ordinals from its sample, rather than arming after them.
 ///
+/// **[arm] is not enough on its own, and a phase must call
+/// [establishBaseline] straight after it.** Arming does not empty the engine's
+/// queue: a caller's own pump just before the phase, and whatever the engine
+/// had not yet batched, both report *after* registration and take ordinals
+/// that belong to frames pumped later. [establishBaseline] is what drains
+/// them; [sawBacklog] is the invariant that says it failed to.
+///
 /// The last frames' timings are still in flight when the last pump returns,
 /// which is what [drain] is for.
 class FrameTimingLog {
   final List<FrameTiming> _reported = <FrameTiming>[];
   int _pumped = 0;
   bool _armed = false;
 
-  void _collect(List<FrameTiming> timings) => _reported.addAll(timings);
+  /// The `frameNumber` of the last frame known to belong to the *pre-baseline*
+  /// stream, or null before [establishBaseline] has run. Every timing at or
+  /// below it is dropped rather than appended: a straggler from before the
+  /// baseline must not take an ordinal that belongs to a frame pumped after
+  /// it. See [establishBaseline].
+  int? _baselineFrameNumber;
+  bool _baselineEstablished = false;
+
+  /// Latched when [reportedFrames] exceeds [pumpedFrames] *after* the
+  /// baseline. See [sawBacklog].
+  bool _sawBacklog = false;
+  int _worstExcess = 0;
+
+  void _collect(List<FrameTiming> timings) {
+    final baseline = _baselineFrameNumber;
+    for (final timing in timings) {
+      if (baseline != null && timing.frameNumber <= baseline) continue;
+      _reported.add(timing);
+    }
+    // The invariant: a frame reports only after it has rasterised, and it
+    // cannot rasterise before it was pumped, so at most one timing per pumped
+    // frame can ever have arrived. More than that means timings this log did
+    // not pump are in the stream -- which is exactly a backlog, and exactly
+    // the thing that shifts every ordinal by an amount nothing else measures.
+    // Before the baseline a backlog is *expected* (it is what the baseline
+    // drains), so this only latches once the baseline is in place.
+    if (_baselineEstablished && _reported.length > _pumped) {
+      _sawBacklog = true;
+      final excess = _reported.length - _pumped;
+      if (excess > _worstExcess) _worstExcess = excess;
+    }
+  }
 
   /// Registers the one callback that spans the whole phase.
   void arm() {
     if (_armed) {
       throw StateError('FrameTimingLog.arm() twice: one registration spans '
           'the phase, and a second would double every timing');
     }
     SchedulerBinding.instance.addTimingsCallback(_collect);
     _armed = true;
   }
 
   /// Unregisters the callback. Safe to call when never armed, so a caller can
@@ -736,30 +774,141 @@ class FrameTimingLog {
     if (!_armed) return;
     SchedulerBinding.instance.removeTimingsCallback(_collect);
     _armed = false;
   }
 
   /// How many frames have been pumped through [pump] and [drain]. Also the
   /// ordinal the next pumped frame will take.
   int get pumpedFrames => _pumped;
 
   /// How many timings have been reported so far, across every pumped frame.
   int get reportedFrames => _reported.length;
 
+  /// Whether [establishBaseline] has run and left this log with a known-empty
+  /// backlog.
+  bool get baselineEstablished => _baselineEstablished;
+
+  /// Whether [reportedFrames] has ever exceeded [pumpedFrames] since the
+  /// baseline was established -- the invariant that says every ordinal in this
+  /// log is off by an unknown amount.
+  ///
+  /// Reading a figure out of such a log throws; this getter is how a caller
+  /// (or a test) asks without throwing.
+  bool get sawBacklog => _sawBacklog;
+
   /// Pumps one frame and gives it the next ordinal.
   Future<void> pump(Future<void> Function() pumpFrame) async {
     _pumped++;
     await pumpFrame();
   }
 
+  /// Drains whatever the engine still owes from before [arm], then rebases
+  /// this log so ordinal 0 is genuinely the next frame pumped.
+  ///
+  /// **Why any of this is needed.** Ordinals index [_reported] directly, so
+  /// ordinal *k* is pumped frame *k* only if `_reported[0]` is the first frame
+  /// pumped after [arm]. Two things break that on a device and neither is
+  /// rare:
+  ///
+  /// 1. *A guaranteed shift of one.* A caller that pumps a frame just before
+  ///    the phase -- `main.dart`'s `runArm` resets the camera and pumps --
+  ///    completes that pump at `SchedulerBinding.endOfFrame`, **before** the
+  ///    frame rasterises. Its `FrameTiming` therefore arrives *after* [arm]
+  ///    and lands at `_reported[0]`, pushing every ordinal along by one. The
+  ///    published "covering frame" then names the in-between composite blit
+  ///    that drew nothing, and the gesture window is padded at the head with
+  ///    the cheapest frame in the phase and truncated at the tail.
+  /// 2. *Engine batching.* `FrameTiming`s are delivered in batches
+  ///    (approximately once a second in release, once every ~100 ms in debug
+  ///    and profile), and `SchedulerBinding.initInstances` registers its own
+  ///    timings callback in `!kReleaseMode` -- so reporting neither starts nor
+  ///    stops at [arm]. Every frame still unflushed at that moment shifts the
+  ///    stream further: 0-6 of them at a 100 ms batch and 60 Hz.
+  ///
+  /// Nothing downstream can see either one. `framesMissing` looks for holes
+  /// *inside* a window, and a shifted-but-full window has none.
+  ///
+  /// **What this does.** Rounds of "pump [framesPerRound] frames back to back,
+  /// then stop pumping and wait a [batchWindow]" until the reported stream
+  /// stops growing while nothing is being pumped -- which is what "the engine
+  /// owes this log nothing" looks like from here -- and then drops [_reported]
+  /// and resets [_pumped] **in the same synchronous step**, so the two cannot
+  /// disagree. The last frame number seen becomes [_baselineFrameNumber], so a
+  /// straggler that arrives after the reset is dropped instead of stealing
+  /// ordinal 0.
+  ///
+  /// **Pumping is continuous inside a round** so that no frame the app
+  /// schedules for itself (`DraftCanvasState`'s settle notifier does) can
+  /// slip in unpumped; the wait that follows is what lets the batch flush.
+  ///
+  /// **[waitForBatch] is injectable so this is testable at all.** The default
+  /// is a real `Future.delayed`; a test drives a fake stream and hands in a
+  /// callback that flushes it instead of sleeping.
+  ///
+  /// Throws when the stream never goes quiet inside [maxRounds]. That is a
+  /// throw and not a warning because every figure the phase would go on to
+  /// publish is an ordinal read out of a stream whose offset is unknown: there
+  /// is no number to salvage, only a wrong one to print.
+  Future<void> establishBaseline(
+    Future<void> Function() pumpFrame, {
+    int framesPerRound = kBaselineFramesPerRound,
+    Duration batchWindow = kTimingBatchWindow,
+    int maxRounds = kBaselineMaxRounds,
+    Future<void> Function(Duration)? waitForBatch,
+  }) async {
+    if (!_armed) {
+      throw StateError('FrameTimingLog.establishBaseline() before arm(): '
+          'there is no stream to drain until the callback is registered');
+    }
+    if (_baselineEstablished) {
+      throw StateError('FrameTimingLog.establishBaseline() twice: the second '
+          'call would throw away a phase that is already being measured');
+    }
+    final wait = waitForBatch ?? (Duration d) => Future<void>.delayed(d);
+    for (var round = 0; round < maxRounds; round++) {
+      for (var i = 0; i < framesPerRound; i++) {
+        await pump(pumpFrame);
+      }
+      await wait(batchWindow);
+      final settledCount = _reported.length;
+      // A second window with nothing pumped into it. If the stream grew, the
+      // engine still owed timings a moment ago and may still owe more.
+      await wait(batchWindow);
+      if (_reported.length != settledCount || _reported.isEmpty) continue;
+      // Quiet, and non-empty: everything the engine owed has landed. Rebase.
+      _baselineFrameNumber = _reported.last.frameNumber;
+      _reported.clear();
+      _pumped = 0;
+      _sawBacklog = false;
+      _worstExcess = 0;
+      _baselineEstablished = true;
+      return;
+    }
+    throw StateError('FrameTimingLog.establishBaseline(): the timing stream '
+        'never went quiet in $maxRounds rounds of $framesPerRound frames and '
+        '$batchWindow -- $reportedFrames timing(s) across $pumpedFrames '
+        'pumped frames. Every ordinal below would be offset by an unknown '
+        'amount, so there is no figure to publish.');
+  }
+
+  /// Throws when this log has seen a backlog since its baseline.
+  void _refuseShiftedStream() {
+    if (!_sawBacklog) return;
+    throw StateError('FrameTimingLog: the reported stream ran ahead of the '
+        'pumped one by up to $_worstExcess frame(s) after the baseline. '
+        'reportedFrames <= pumpedFrames is what makes ordinal k the k-th '
+        'frame pumped; with a backlog every figure read out of this log names '
+        'the wrong frame, and by an amount nothing here can recover.');
+  }
+
   /// Pumps bare frames until the frames with ordinals below [upTo] have all
   /// reported, or until [maxExtraFrames] have been pumped without getting
   /// there.
   ///
   /// **This is the "one extra frame at the end" the attribution needs.** The
   /// last frame of a phase cannot have reported by the time its own pump
   /// returns; without a drain its timing is not late, it is *absent*, and the
   /// phase's last sample would silently read as missing. The drained frames
   /// take ordinals of their own, so a later phase sharing this log stays
   /// aligned. It is a bound and not a wait loop: on a device that stops
   /// reporting altogether this returns rather than hanging, and the shortfall
   /// shows up as a missing sample the report prints.
@@ -775,53 +924,79 @@ class FrameTimingLog {
       await pump(pumpFrame);
       extra++;
     }
     return extra;
   }
 
   /// `totalSpan` of the frame at [ordinal] in milliseconds, or null when no
   /// timing was ever reported for it.
   ///
   /// Null rather than `0.0`: a frame that reported nothing is a hole in the
   /// sample, and zero is a *fast frame*. Publishing one as the other is how a
   /// composite blit that drew nothing gets read as a settle.
-  double? msAt(int ordinal) => ordinal >= 0 && ordinal < _reported.length
-      ? _reported[ordinal].totalSpan.inMicroseconds / 1000.0
-      : null;
+  double? msAt(int ordinal) {
+    _refuseShiftedStream();
+    return ordinal >= 0 && ordinal < _reported.length
+        ? _reported[ordinal].totalSpan.inMicroseconds / 1000.0
+        : null;
+  }
 
   /// [msAt] over the half-open ordinal range `[start, end)`, holes included.
   List<double?> msRange(int start, int end) =>
       <double?>[for (var i = start; i < end; i++) msAt(i)];
 }
 
+/// How long [FrameTimingLog.establishBaseline] waits for the engine to flush a
+/// batch of `FrameTiming`s.
+///
+/// The framework's own figure is "approximately once every 100ms in debug and
+/// profile builds"; this is that with margin, and the baseline waits two of
+/// them per round.
+const Duration kTimingBatchWindow = Duration(milliseconds: 150);
+
+/// How many frames [FrameTimingLog.establishBaseline] pumps per round, back to
+/// back, before it stops and waits.
+const int kBaselineFramesPerRound = 4;
+
+/// How many rounds [FrameTimingLog.establishBaseline] gives the stream to go
+/// quiet before it refuses to produce a baseline at all.
+const int kBaselineMaxRounds = 8;
+
 /// What [runSettlePhase] measured: the idle settle after a gesture.
 class SettleReport {
   SettleReport({
     required this.frames,
     required this.covered,
     required this.coveringFrameMs,
     required this.wallMs,
     required this.framesMissing,
   });
 
   /// How many idle frames elapsed before [TileCache.viewportCovered] first
   /// read true, or the whole idle budget when it never did (see [covered]).
   final int frames;
 
   /// Whether coverage was reached at all inside the idle budget.
   final bool covered;
 
   /// `totalSpan` of the single frame at which coverage was first read -- **one
   /// frame, not the settle**. See [ZoomReport.settleCoveringFrameMs].
-  final double coveringFrameMs;
+  ///
+  /// **Null when that frame reported no timing at all**, which is the hole
+  /// [FrameTimingLog.msAt] takes such care to distinguish from a zero: zero is
+  /// a *fast frame*, and publishing a hole as one is how a composite blit that
+  /// drew nothing gets read as a settle. The type carries it, so a reader who
+  /// takes this field without also reading [framesMissing] still cannot get a
+  /// number where there was none.
+  final double? coveringFrameMs;
 
   /// Wall clock across [frames], summed. See [ZoomReport.settleWallMs].
   final double wallMs;
 
   /// How many of those [frames] never reported a timing. Nonzero means both
   /// figures above are over a short sample and must not be published as they
   /// stand.
   final int framesMissing;
 }
 
 /// Idle frames pumped after the gesture, pinned by design spec §5.
 const int kIdleFrames = 30;
@@ -877,25 +1052,28 @@ Future<SettleReport> runSettlePhase({
   var wallMs = 0.0;
   var missing = 0;
   for (final v in ms) {
     if (v == null) {
       missing++;
     } else {
       wallMs += v;
     }
   }
   return SettleReport(
     frames: frames,
     covered: everCovered,
-    coveringFrameMs: ms.isEmpty ? 0.0 : (ms.last ?? 0.0),
+    // `ms.last` already carries the hole as null; there is nothing to
+    // substitute for it. An empty window (`frames` of zero, which only a zero
+    // idle budget produces) is the same absence.
+    coveringFrameMs: ms.isEmpty ? null : ms.last,
     wallMs: wallMs,
     framesMissing: missing,
   );
 }
 
 /// What [runTileZoomPhase] reports: the gesture's frame times and the
 /// cache's counters over it, then the settle that follows.
 class ZoomReport {
   ZoomReport({
     required this.gestureFrameMs,
     required this.gestureFramesMissing,
     required this.gestureBakes,
@@ -978,25 +1156,31 @@ class ZoomReport {
 
   /// `totalSpan` of the **one** idle frame at which [TileCache.viewportCovered]
   /// first became true, or of the last idle frame pumped if [kIdleFrames]
   /// never reached coverage. Criterion 3 reads this, and criterion 3 only.
   ///
   /// **One frame, and never the settle's duration.** Criterion 4 is wall clock
   /// across the whole settle and is [settleWallMs]; on the rest-bake arm the
   /// settle is ~1 baking frame and the two nearly coincide, but on the
   /// denominator arm the settle is many frames and this figure is the last of
   /// them alone. A ratio formed from this field compares one frame against one
   /// frame -- the "two readings straddling the gate" design spec §4 exists to
   /// prevent.
-  final double settleCoveringFrameMs;
+  ///
+  /// **Null is a hole, not a fast frame.** See
+  /// [SettleReport.coveringFrameMs]: when the frame criterion 3 names reported
+  /// no timing at all there is no number, and this field says so in its type
+  /// rather than handing back a `0.0` that reads as the fastest frame in the
+  /// run.
+  final double? settleCoveringFrameMs;
 
   /// Criterion 4's numerator or denominator, quoting the criterion: **"wall
   /// clock to a covered viewport, from the first frame after the gesture ends
   /// to the frame that covers it"**.
   ///
   /// The sum of `totalSpan` over idle frames 1..[settleFrames] inclusive --
   /// the frame that covers the viewport included, the idle frames after it
   /// excluded. This is the only figure criterion 4's ratio may be formed
   /// from; see [settleCoveringFrameMs] for why the per-frame figure is not.
   final double settleWallMs;
 
   /// How many idle frames elapsed before [TileCache.viewportCovered] first
@@ -1050,37 +1234,49 @@ class ZoomReport {
 /// against the design spec's priced predictions, is only sound once the
 /// window is confirmed to actually be the reference size. `main.dart`'s
 /// `RUN_R2` mode prints the real window size for exactly this reason; a
 /// caller of this phase should do the same.
 ///
 /// The idle settle after the gesture is [runSettlePhase]'s, and its doc
 /// comment carries why an idle frame here is a bare [pumpFrame] call.
 ///
 /// **Every frame this phase pumps goes through one [FrameTimingLog].** The
 /// warm-up frames are pumped *after* the log is armed and then excluded by
 /// ordinal, rather than pumped before registration and silently charged to the
 /// gesture; the gesture window is an ordinal range rather than "whatever
-/// arrived between two registrations"; and the settle's last frames are
+/// arrived between two registrations"; the engine's backlog at arming time is
+/// drained and the ordinals rebased before the first warm-up frame, so
+/// ordinal 0 is a frame this phase pumped; and the settle's last frames are
 /// drained rather than dropped. See [FrameTimingLog] for why every one of
 /// those is the same bug.
 Future<ZoomReport> runTileZoomPhase({
   required CameraController camera,
   required TileCache cache,
   required Future<void> Function() pumpFrame,
   required Size viewport,
 }) async {
   refuseDebugMode();
   final focus = zoomFocusFor(viewport);
   final log = FrameTimingLog()..arm();
   try {
+    // Arming registers a callback; it does not empty the engine's queue. The
+    // caller's own pump just before this phase (`main.dart`'s `runArm` resets
+    // the camera and pumps one frame) rasterises *after* its pump returns, so
+    // its timing is guaranteed to arrive here, and whatever else the engine
+    // had not batched arrives with it. Both would take ordinals belonging to
+    // frames pumped later, and nothing downstream can see it: a window shifted
+    // whole has no holes for `framesMissing` to find. This drains them and
+    // rebases the ordinals; see [FrameTimingLog.establishBaseline].
+    await log.establishBaseline(pumpFrame);
+
     // Two throwaway frames before the counters reset, the same boundary slack
     // `runTilePhases`'s own `phase()` helper takes -- but pumped *after* the
     // log is armed, so their timings land on ordinals 0 and 1 and are excluded
     // by the gesture window below. Pumped before arming, they would rasterise
     // before registration, be reported after it, and take the first two
     // gesture ordinals: a no-op repaint of a covered generation is the
     // cheapest frame in the phase, and two of them at the head of the sample
     // push p95 down.
     for (var i = 0; i < kZoomWarmUpFrames; i++) {
       camera.panBy(Offset.zero);
       await log.pump(pumpFrame);
     }
@@ -1152,26 +1348,34 @@ void printZoomReport(String label, ZoomReport r) {
         'mean=${(sum / sorted.length).toStringAsFixed(2)}ms');
   }
   print('$label   gestureBakes=${r.gestureBakes}(tiles, budgeted path) '
       'gestureLiveDraws=${r.gestureLiveDraws}');
   // Two time figures, never one. `settleWallMs` is criterion 4's wall clock
   // across the settle; `coveringFrameMs` is criterion 3's single frame. They
   // coincide only when the settle is one frame long, which is the arm the
   // ratio's numerator comes from and not the arm its denominator comes from.
   print('$label   settleFrames=${r.settleFrames} '
       'covered=${r.settleCovered} '
       'settleWallMs=${r.settleWallMs.toStringAsFixed(2)}(criterion 4, '
       'wall clock over the settle) '
-      'coveringFrameMs=${r.settleCoveringFrameMs.toStringAsFixed(2)}'
+      // A hole prints as a hole. `0.00` here would be the fastest frame of the
+      // run, and criterion 3 would be read off a frame that never reported.
+      'coveringFrameMs='
+      '${r.settleCoveringFrameMs?.toStringAsFixed(2) ?? "NONE"}'
       '(criterion 3, that one frame)');
+  if (r.settleCoveringFrameMs == null) {
+    print('$label   !!! WARNING: criterion 3 has NO figure -- the frame that '
+        'coverage was read at reported no FrameTiming at all. That is a hole '
+        'in the sample and not a fast frame !!!');
+  }
   if (!r.settleCovered) {
     print('$label   !!! WARNING: the viewport never covered within '
         '$kIdleFrames idle frames -- settleFrames is a floor, and neither '
         'time figure above is a settle !!!');
   }
   final missing = r.gestureFramesMissing + r.settleFramesMissing;
   if (missing > 0) {
     print('$label   !!! WARNING: $missing frame(s) reported no FrameTiming '
         '(gesture ${r.gestureFramesMissing} of ${2 * kZoomSteps}, settle '
         '${r.settleFramesMissing} of ${r.settleFrames}) -- the figures above '
         'are over a SHORT SAMPLE and are not comparable !!!');
   }
diff --git a/apps/dev_harness_2d/test/settle_attribution_test.dart b/apps/dev_harness_2d/test/settle_attribution_test.dart
index 4069af0..bc5e301 100644
--- a/apps/dev_harness_2d/test/settle_attribution_test.dart
+++ b/apps/dev_harness_2d/test/settle_attribution_test.dart
@@ -34,55 +34,124 @@ FrameTiming _timing(double ms, int frameNumber) {
   return FrameTiming(
     vsyncStart: 0,
     buildStart: 0,
     buildFinish: us ~/ 2,
     rasterStart: us ~/ 2,
     rasterFinish: us,
     rasterFinishWallTime: us,
     frameNumber: frameNumber,
   );
 }
 
 /// Pumps frames that report their timings one frame late, the way the engine
-/// does.
+/// does, and -- when [backlogMs] is non-empty -- opens with a batch of timings
+/// for frames that were pumped **before** the log was armed.
+///
+/// **The backlog is not decoration.** Without it this fixture models a stream
+/// whose backlog is empty at `arm()`, which is the one case the device never
+/// gives you: `main.dart`'s `runArm` pumps a camera-reset frame whose timing
+/// cannot have arrived by the time its own pump returns, and the engine
+/// batches its reports besides. A driver that only ever delivers frames it
+/// pumped itself cannot reproduce a shifted stream, so it cannot fail on one.
 class _FrameDriver {
-  _FrameDriver({required this.costMs, this.tailCostMs = 4.0});
+  _FrameDriver({
+    required this.costMs,
+    this.tailCostMs = 4.0,
+    this.backlogMs = const <double>[],
+  });
 
   /// `totalSpan` of frame *i*, by ordinal. Frames past the end cost
   /// [tailCostMs].
   final List<double> costMs;
   final double tailCostMs;
 
+  /// `totalSpan` of the frames pumped before the log was armed, oldest first.
+  /// They are all delivered in one batch on the first [pump], which is where
+  /// the engine would deliver them: after registration, at the head of the
+  /// stream, in front of every frame the phase goes on to pump.
+  final List<double> backlogMs;
+
   /// How many frames have been pumped.
   int pumped = 0;
 
   /// The ordinal of the next frame whose timing is still owed.
   int _delivered = 0;
+  bool _backlogReported = false;
+
+  /// Engine frame numbers are one sequence across both: the backlog takes
+  /// `0 .. backlogMs.length - 1`, and post-arm ordinal *i* takes
+  /// `backlogMs.length + i`. With no backlog this is the identity, which is
+  /// what it was before backlogs existed.
+  int get _frameNumberBase => backlogMs.length;
 
   double costOf(int ordinal) =>
       ordinal < costMs.length ? costMs[ordinal] : tailCostMs;
 
+  void _report(List<FrameTiming> timings) {
+    if (timings.isEmpty) return;
+    SchedulerBinding.instance.platformDispatcher.onReportTimings!(timings);
+  }
+
+  List<FrameTiming> _takeBacklog() {
+    if (_backlogReported) return const <FrameTiming>[];
+    _backlogReported = true;
+    return <FrameTiming>[
+      for (var i = 0; i < backlogMs.length; i++) _timing(backlogMs[i], i),
+    ];
+  }
+
   Future<void> pump() async {
     pumped++;
+    _report(_takeBacklog());
     // At most one frame in flight: pumping frame *i* is what lets frame *i-1*'s
     // timing arrive. The last frame pumped is therefore always still owed --
     // which is what `FrameTimingLog.drain` exists to collect.
     if (_delivered < pumped - 1) {
       final ordinal = _delivered++;
-      SchedulerBinding.instance.platformDispatcher.onReportTimings!(
-        <FrameTiming>[_timing(costOf(ordinal), ordinal)],
+      _report(
+        <FrameTiming>[_timing(costOf(ordinal), _frameNumberBase + ordinal)],
       );
     }
     await Future<void>.delayed(Duration.zero);
   }
+
+  /// Delivers every timing still owed, without pumping anything.
+  ///
+  /// This is what a batch flush looks like from the framework's side while the
+  /// rig is not pumping: the frames already rasterised report, and then the
+  /// stream goes quiet. `FrameTimingLog.establishBaseline` waits for exactly
+  /// that quiet, so a test hands this in as its `waitForBatch`.
+  Future<void> flush() async {
+    final owed = <FrameTiming>[..._takeBacklog()];
+    while (_delivered < pumped) {
+      final ordinal = _delivered++;
+      owed.add(_timing(costOf(ordinal), _frameNumberBase + ordinal));
+    }
+    _report(owed);
+    await Future<void>.delayed(Duration.zero);
+  }
+}
+
+/// Arms [log] and drains whatever the engine owed before it was armed, the way
+/// `runTileZoomPhase` does -- with [driver] standing in for the engine's batch
+/// flush, so no test has to sleep through a real [kTimingBatchWindow].
+Future<void> _armAndBaseline(FrameTimingLog log, _FrameDriver driver,
+    {int framesPerRound = 2}) async {
+  log.arm();
+  await log.establishBaseline(
+    driver.pump,
+    framesPerRound: framesPerRound,
+    batchWindow: Duration.zero,
+    waitForBatch: (_) => driver.flush(),
+  );
 }
 
 void main() {
   TestWidgetsFlutterBinding.ensureInitialized();
 
   test('the covering frame is the one reported, not the frame before it',
       () async {
     // Idle frame 2 covers -- the count Ruling 15 derives from
     // `kRestGateFrames = 2` -- and it is the expensive one. Frame 1 is the
     // in-between composite blit: cheap, and what the old attribution published.
     final driver = _FrameDriver(costMs: <double>[4.0, 90.0]);
     final log = FrameTimingLog()..arm();
@@ -124,25 +193,27 @@ void main() {
           covered: () => driver.pumped >= 2,
           idleFrames: 5,
         );
       } finally {
         log.disarm();
       }
     }
 
     final cheap = await run(9.0);
     final dear = await run(900.0);
     expect(cheap.coveringFrameMs, closeTo(9.0, 1e-9));
     expect(dear.coveringFrameMs, closeTo(900.0, 1e-9));
-    expect(dear.coveringFrameMs - cheap.coveringFrameMs, closeTo(891.0, 1e-9),
+    // Non-null in both arms: the two `closeTo`s above already fail on a hole,
+    // so the `!`s here cannot be what a broken attribution trips over.
+    expect(dear.coveringFrameMs! - cheap.coveringFrameMs!, closeTo(891.0, 1e-9),
         reason: 'the settle figure must track the settle frame');
   });
 
   test('wall clock over the settle is the sum, not the last frame', () async {
     // Criterion 4 is "wall clock to a covered viewport, from the first frame
     // after the gesture ends to the frame that covers it". A many-frame settle
     // is the denominator arm's shape, and the last frame alone is not it.
     final driver = _FrameDriver(costMs: <double>[5.0, 6.0, 90.0]);
     final log = FrameTimingLog()..arm();
     final SettleReport settle;
     try {
       settle = await runSettlePhase(
@@ -245,24 +316,29 @@ void main() {
         log: log,
         pumpFrame: () async {},
         covered: () => true,
         idleFrames: 3,
       );
     } finally {
       log.disarm();
     }
 
     expect(settle.frames, 1);
     expect(settle.framesMissing, 1);
     expect(settle.wallMs, 0.0);
+    expect(settle.coveringFrameMs, isNull,
+        reason: 'the field carries the hole. `0.0` here is a *fast frame*, '
+            'and a reader who takes this field without also reading '
+            'framesMissing would publish the fastest number in the run as '
+            "criterion 3's settle");
   });
 
   test('the gesture window excludes the warm-up frames and keeps its tail',
       () async {
     // The whole phase's shape, without the parts `runTileZoomPhase` cannot run
     // in a debug build: two warm-up frames, a gesture, then a settle. The warm-
     // ups are the cheapest frames in the phase (a no-op repaint of a covered
     // generation) and the tail frames are among the dearest, so a sample padded
     // at the head and truncated at the tail is one whose p95 reads low.
     const gestureFrames = 2 * kZoomSteps;
     final costs = <double>[
       1.0, 1.0, // the two warm-up frames
@@ -329,13 +405,215 @@ void main() {
         frames: 2,
         covered: true,
         coveringFrameMs: 9.0,
         wallMs: 12.0,
         framesMissing: 0,
       ),
     );
 
     expect(report.gestureFrameMs.length + report.gestureFramesMissing,
         2 * kZoomSteps);
     expect(report.gestureFramesMissing, kZoomSteps);
   });
+
+  // --- The backlog: what `arm()` alone does not do. ----------------------
+
+  test('the baseline drains what arming did not, and rebases the ordinals',
+      () async {
+    // Three frames pumped before `arm()`: the camera reset `main.dart`'s
+    // `runArm` does, plus whatever batch the engine was still holding. Every
+    // one of them reports *after* registration.
+    final driver = _FrameDriver(
+      backlogMs: <double>[111.0, 222.0, 333.0],
+      costMs: <double>[1.0, 1.0],
+    );
+    final log = FrameTimingLog();
+    try {
+      expect(log.baselineEstablished, isFalse);
+      await _armAndBaseline(log, driver);
+
+      expect(log.baselineEstablished, isTrue);
+      expect(log.pumpedFrames, 0,
+          reason: 'ordinal 0 must be the next frame pumped, not the fourth '
+              'frame of somebody else\'s backlog');
+      expect(log.reportedFrames, 0,
+          reason: 'and nothing may already be sitting at that ordinal');
+      expect(log.sawBacklog, isFalse);
+
+      // A straggler from before the baseline, arriving after the reset: it is
+      // dropped by frame number rather than taking ordinal 0.
+      SchedulerBinding.instance.platformDispatcher.onReportTimings!(
+        <FrameTiming>[_timing(999.0, 0)],
+      );
+      expect(log.reportedFrames, 0);
+      expect(log.sawBacklog, isFalse);
+    } finally {
+      log.disarm();
+    }
+  });
+
+  test('a backlog reported after arming does not take the settle ordinals',
+      () async {
+    // The Blocking defect, one frame over. Costs 1.0 are the baseline frames;
+    // the settle is 4.0 then 90.0, and coverage is on the second idle frame
+    // (Ruling 15). Without the baseline, ordinal 0 of the settle is the
+    // backlog's third entry and the published figure is a frame from before
+    // the phase began.
+    final driver = _FrameDriver(
+      backlogMs: <double>[111.0, 222.0, 333.0],
+      costMs: <double>[1.0, 1.0, 4.0, 90.0],
+      tailCostMs: 3.0,
+    );
+    final log = FrameTimingLog();
+    final SettleReport settle;
+    // Counted here rather than off the log, so this predicate says the same
+    // thing whether or not the ordinals were rebased.
+    var idlePumps = 0;
+    try {
+      await _armAndBaseline(log, driver);
+      settle = await runSettlePhase(
+        log: log,
+        pumpFrame: () async {
+          idlePumps++;
+          await driver.pump();
+        },
+        covered: () => idlePumps >= 2,
+        idleFrames: 5,
+      );
+    } finally {
+      log.disarm();
+    }
+
+    expect(settle.frames, 2);
+    expect(settle.framesMissing, 0);
+    expect(settle.coveringFrameMs, closeTo(90.0, 1e-9),
+        reason: 'the covering frame. 333.0 is the backlog, 1.0 is a baseline '
+            'frame, and 4.0 is the composite blit before it');
+    expect(settle.wallMs, closeTo(94.0, 1e-9));
+  });
+
+  test('a backlog reported after arming does not pad the gesture window',
+      () async {
+    // The same shift, read off the other window: a sample padded at the head
+    // with somebody else's cheap frames and truncated at the tail is one whose
+    // p95 reads low.
+    const gestureFrames = 2 * kZoomSteps;
+    const backlogCost = 2.0;
+    final costs = <double>[
+      1.0, 1.0, // the two baseline frames
+      1.0, 1.0, // the two warm-up frames
+      for (var i = 0; i < gestureFrames - 1; i++) 10.0,
+      77.0, // the last gesture frame
+    ];
+    final driver = _FrameDriver(
+      backlogMs: <double>[for (var i = 0; i < 4; i++) backlogCost],
+      costMs: costs,
+      tailCostMs: 3.0,
+    );
+    final log = FrameTimingLog();
+    final List<double?> gestureMs;
+    try {
+      await _armAndBaseline(log, driver);
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
+    expect(report.gestureFrameMs.length, gestureFrames);
+    expect(report.gestureFrameMs.first, closeTo(10.0, 1e-9),
+        reason: 'the first gesture frame, not a backlog frame and not a '
+            'baseline or warm-up frame');
+    expect(report.gestureFrameMs.last, closeTo(77.0, 1e-9),
+        reason: 'the last gesture frame, which a shifted window truncates');
+    expect(report.gestureFrameMs.where((v) => v == backlogCost), isEmpty,
+        reason: 'no frame from before the phase may appear in the sample');
+    expect(report.gestureFrameMs.where((v) => v == 1.0), isEmpty,
+        reason: 'and no baseline or warm-up frame either');
+  });
+
+  test('a backlog after the baseline is refused rather than published',
+      () async {
+    // `reportedFrames <= pumpedFrames` is what makes ordinal k the k-th frame
+    // pumped: a frame reports only after it has rasterised, and it cannot
+    // rasterise before it was pumped. More timings than pumps means frames
+    // this log never pumped are in the stream, and every ordinal past them is
+    // off by an amount nothing here can recover -- which is exactly the state
+    // that published a composite blit as a settle, undetected.
+    final driver = _FrameDriver(costMs: <double>[1.0, 1.0, 5.0, 6.0]);
+    final log = FrameTimingLog();
+    try {
+      await _armAndBaseline(log, driver);
+      expect(log.sawBacklog, isFalse);
+
+      // Two frames this log never pumped, of the shape a late engine batch
+      // has. Their frame numbers are past the baseline, so the frame-number
+      // filter does not catch them -- the invariant is what does.
+      SchedulerBinding.instance.platformDispatcher.onReportTimings!(
+        <FrameTiming>[_timing(7.0, 9000), _timing(8.0, 9001)],
+      );
+
+      expect(log.sawBacklog, isTrue,
+          reason: 'two timings across zero pumped frames');
+      expect(() => log.msAt(0), throwsStateError,
+          reason: 'a shifted stream yields no figure, loudly, rather than a '
+              'plausible one quietly');
+      expect(() => log.msRange(0, 2), throwsStateError);
+    } finally {
+      log.disarm();
+    }
+  });
+
+  test('a stream that never goes quiet is refused, not measured', () async {
+    // An engine that keeps reporting frames the rig never pumped never lets
+    // the baseline establish itself. There is no ordinal to hand back, so
+    // there is no figure -- and a rig that prints one anyway is the failure
+    // this whole file exists for.
+    var phantomFrameNumber = 9000;
+    final log = FrameTimingLog()..arm();
+    try {
+      await expectLater(
+        log.establishBaseline(
+          () async {},
+          framesPerRound: 1,
+          batchWindow: Duration.zero,
+          maxRounds: 3,
+          waitForBatch: (_) async {
+            SchedulerBinding.instance.platformDispatcher.onReportTimings!(
+              <FrameTiming>[_timing(5.0, phantomFrameNumber++)],
+            );
+          },
+        ),
+        throwsStateError,
+      );
+      expect(log.baselineEstablished, isFalse);
+    } finally {
+      log.disarm();
+    }
+  });
 }
diff --git a/apps/dev_harness_2d/test/zoom_arm_wiring_test.dart b/apps/dev_harness_2d/test/zoom_arm_wiring_test.dart
index 7b30cba..c7156b6 100644
--- a/apps/dev_harness_2d/test/zoom_arm_wiring_test.dart
+++ b/apps/dev_harness_2d/test/zoom_arm_wiring_test.dart
@@ -24,25 +24,25 @@ import 'package:dev_harness_2d/measurement_rig.dart';
 import 'package:flutter_test/flutter_test.dart';
 import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
 
 /// A report with no measurement in it: these tests drive the wiring, and a
 /// figure here would be a fabricated one.
 ZoomReport _emptyReport() => ZoomReport.from(
       gestureMs: <double?>[],
       gestureBakes: 0,
       gestureLiveDraws: 0,
       settle: SettleReport(
         frames: 2,
         covered: true,
-        coveringFrameMs: 0.0,
+        coveringFrameMs: null,
         wallMs: 0.0,
         framesMissing: 0,
       ),
     );
 
 /// What one arm's callback saw: the label it was printed under, and the cache
 /// flags as they stood *while the arm ran*.
 class _Seen {
   _Seen(this.label, this.restBakeDisabled, this.fullViewportQuery);
 
   final String label;
   final bool restBakeDisabled;
diff --git a/docs/superpowers/notes/plan-3i-mutation-log.md b/docs/superpowers/notes/plan-3i-mutation-log.md
index ba4ddd8..d4e68a8 100644
--- a/docs/superpowers/notes/plan-3i-mutation-log.md
+++ b/docs/superpowers/notes/plan-3i-mutation-log.md
@@ -387,25 +387,25 @@ The test description was:
 00:00 +1 -2: Some tests failed.
 Failing tests:
   test/invariants/tile_bytes_test.dart: the ceiling binds inside the rest frame, and eviction holds it
   test/invariants/tile_bytes_test.dart: the ceiling holds at every point inside the rest frame
 ```
 
 **And a finding worth recording rather than a gate: `liveBytes` is structurally
 blind to this mutant, at any cap.** It sums `_tiles`, `_carryOver` and the
 image currently in `_band` -- and `_band` is reassigned at the top of every
 band iteration, so an image the loop failed to dispose stops being counted the
 moment the next band starts. No ceiling, however tight, can catch M6 through
 `liveBytes`; `debugImagesAlive` is its gate and always was. The new arm's own
-mutant is **M20**, which trips the ceiling clause directly.
+mutant is **M21**, which trips the ceiling clause directly.
 
 ---
 
 ## M6b — the band image is never assigned to `_band`
 
 > Measured at the pre-fix 800x600-logical canvas -- see the note at the top
 > of this file (the `BoxConstraints(w=800.0, h=600.0)` in the transcript
 > below is that canvas). The kill stands; it is not re-run.
 
 **Task 8, fix round 1.** The band is baked, sliced and disposed correctly, but
 `_band` is never set, so `liveBytes` cannot see the one image the whole banding
 design exists to bound.
@@ -2203,12 +2203,524 @@ The relevant error-causing widget was:
 
 Failing tests:
   /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart: the ceiling binds inside the rest frame, and eviction holds it
 ```
 
 **Restore, verified.** Empty `diff`, and:
 
 ```
 00:00 +1: the ceiling holds at every point inside the rest frame
 00:00 +2: the ceiling binds inside the rest frame, and eviction holds it
 00:00 +3: All tests passed!
 ```
+
+---
+
+> **Fix wave C opens here.** `M22`, `M22b` and `M22c` were fired in
+> `apps/dev_harness_2d/`, against the Blocking finding and the first Minor of
+> the fix-wave review. Numbering in this file is shared between the waves;
+> `M21` was the last number taken when these were fired.
+
+## M22 — the ordinal scheme trusts a stream it never drained
+
+**Fix wave C, the Blocking finding.** One frame further along than M20, and
+the same defect. `FrameTimingLog.msAt(ordinal)` indexes `_reported` directly,
+so ordinal *k* is pumped frame *k* **only if `_reported[0]` is the first frame
+pumped after `arm()`**. Two things break that on the device, and neither is
+rare:
+
+1. **A guaranteed shift of one.** `main.dart`'s `runArm` does
+   `camera.value = fittedCamera; await _pumpFrame();` and *then* calls
+   `runTileZoomPhase`, which is where `FrameTimingLog()..arm()` runs.
+   `_pumpFrame` completes at `SchedulerBinding.endOfFrame` -- before the frame
+   rasterises -- so that camera-reset frame's `FrameTiming` is **guaranteed**
+   to arrive after `arm()` and to land at `_reported[0]`.
+2. **Engine batching.** `FrameTiming`s are delivered in batches
+   ("approximately once a second in release mode and approximately once every
+   100ms in debug and profile builds"), and `SchedulerBinding.initInstances`
+   registers its timings callback in `!kReleaseMode`, so reporting neither
+   starts nor stops at `arm()`. Every frame still unflushed at that moment
+   shifts the stream further: 0-6 at a 100 ms batch and 60 Hz.
+
+**Nothing detected it.** `framesMissing` looks for holes *inside* a window,
+and a window shifted whole has none, so no `SHORT SAMPLE` warning fires. With
+the guaranteed shift of one alone, `settleCoveringFrameMs` was the in-between
+composite blit -- exactly the frame M20 exists to keep out of that field --
+and the gesture window was padded at the head with the cheapest frame in the
+phase and truncated at the tail.
+
+`runTileZoomPhase`'s own comment stated this mechanism correctly and pumped
+its two warm-up frames *after* arming for exactly this reason. The reasoning
+was right and stopped at the function boundary; the defect moved to the
+caller.
+
+**The fix** is `FrameTimingLog.establishBaseline`, called by
+`runTileZoomPhase` immediately after `arm()`: rounds of "pump frames back to
+back, then stop pumping and wait a batch window" until the reported stream
+stops growing while nothing is being pumped, then drop `_reported` and reset
+`_pumped` **in the same synchronous step** so the two cannot disagree. The
+last frame number seen becomes a baseline, and a straggler at or below it is
+dropped rather than taking ordinal 0. The reviewer's invariant --
+`reportedFrames <= pumpedFrames` -- latches from the timings callback once the
+baseline is in place, and every read out of a log that saw a backlog throws.
+
+**Mutation**, applied to
+`apps/dev_harness_2d/lib/measurement_rig.dart`, in
+`FrameTimingLog.establishBaseline` -- the reconciliation removed, the direct
+index left as it was:
+
+```diff
+       // Quiet, and non-empty: everything the engine owed has landed. Rebase.
+-      _baselineFrameNumber = _reported.last.frameNumber;
+-      _reported.clear();
+-      _pumped = 0;
+       _sawBacklog = false;
+       _worstExcess = 0;
+-      _baselineEstablished = true;
+       return;
+```
+
+**Procedure:** copied `measurement_rig.dart` aside to the scratchpad
+(`measurement_rig_m22.bak`), edited the working file, ran
+`CI=true flutter test --concurrency=1 test/settle_attribution_test.dart` from
+`apps/dev_harness_2d`, confirmed red, then restored the working file with `cp`
+from the scratchpad copy and confirmed `diff` produced no output. **Never
+`git checkout`.**
+
+**Result:** red, four of the fourteen tests. The covering frame reads **1.0**
+under the mutant -- a baseline frame, cheaper than every gesture frame in the
+phase -- where the frame coverage was actually read at cost 90.0, and the
+gesture window's first entry reads **1.0** where the first gesture frame cost
+10.0.
+
+**The old fixture could not have caught it, which is why the driver changed.**
+`_FrameDriver` started `_delivered` at 0 and only ever delivered frames it had
+pumped itself: its stream modelled an **empty backlog at `arm()`**, the one
+case the device never gives you. It now takes a `backlogMs` list -- timings
+for frames pumped *before* the log was armed, delivered in one batch at the
+head of the stream, with engine frame numbers below every post-arm frame --
+and a `flush()` that stands in for a batch flush while nothing is pumped. The
+two pre-existing gesture-window and hole tests survive M22 and are meant to:
+they are written on drivers with no backlog, and a stream with no backlog is
+not shifted.
+
+**Verbatim output** (the `flutter pub get` preamble, identical to every other
+entry in this file, is trimmed):
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
+00:00 +9: the baseline drains what arming did not, and rebases the ordinals
+00:00 +9 -1: the baseline drains what arming did not, and rebases the ordinals [E]
+  Expected: true
+    Actual: <false>
+  
+  package:matcher                                     expect
+  package:flutter_test/src/widget_tester.dart 473:18  expect
+  test/settle_attribution_test.dart 434:7             main.<fn>
+  
+00:00 +9 -1: a backlog reported after arming does not take the settle ordinals
+00:00 +9 -2: a backlog reported after arming does not take the settle ordinals [E]
+  Expected: a numeric value within <1e-9> of <90.0>
+    Actual: <1.0>
+     Which:  differs by <89.0>
+  the covering frame. 333.0 is the backlog, 1.0 is a baseline frame, and 4.0 is the composite blit before it
+  
+  package:matcher                                     expect
+  package:flutter_test/src/widget_tester.dart 473:18  expect
+  test/settle_attribution_test.dart 488:5             main.<fn>
+  
+00:00 +9 -2: a backlog reported after arming does not pad the gesture window
+00:00 +9 -3: a backlog reported after arming does not pad the gesture window [E]
+  Expected: a numeric value within <1e-9> of <10.0>
+    Actual: <1.0>
+     Which:  differs by <9.0>
+  the first gesture frame, not a backlog frame and not a baseline or warm-up frame
+  
+  package:matcher                                     expect
+  package:flutter_test/src/widget_tester.dart 473:18  expect
+  test/settle_attribution_test.dart 549:5             main.<fn>
+  
+00:00 +9 -3: a backlog after the baseline is refused rather than published
+00:00 +9 -4: a backlog after the baseline is refused rather than published [E]
+  Expected: true
+    Actual: <false>
+  two timings across zero pumped frames
+  
+  package:matcher                                     expect
+  package:flutter_test/src/widget_tester.dart 473:18  expect
+  test/settle_attribution_test.dart 581:7             main.<fn>
+  
+00:00 +9 -4: a stream that never goes quiet is refused, not measured
+00:00 +10 -4: Some tests failed.
+
+Failing tests:
+  /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: a backlog after the baseline is refused rather than published
+  /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: a backlog reported after arming does not pad the gesture window
+  /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: a backlog reported after arming does not take the settle ordinals
+  /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: the baseline drains what arming did not, and rebases the ordinals
+```
+
+**Restore, verified.** Empty `diff`, and the fourteen green transcript quoted
+under M22c below.
+
+---
+
+## M22b — the baseline gives up quietly instead of refusing
+
+**Fix wave C.** The companion clause to M22: when the timing stream never goes
+quiet, `establishBaseline` has no offset to hand back, and returning anyway
+would let the phase publish ordinals that are wrong by an unknown amount --
+the same failure M22 restores, arrived at from the other side. This mutant
+proves the refusal is load-bearing and not decoration.
+
+**Mutation:** the tail of `FrameTimingLog.establishBaseline`:
+
+```diff
+-    throw StateError('FrameTimingLog.establishBaseline(): the timing stream '
+-        'never went quiet in $maxRounds rounds of $framesPerRound frames and '
+-        '$batchWindow -- $reportedFrames timing(s) across $pumpedFrames '
+-        'pumped frames. Every ordinal below would be offset by an unknown '
+-        'amount, so there is no figure to publish.');
++    return;
+```
+
+**Procedure:** as M22, against
+`test/settle_attribution_test.dart` (`measurement_rig_m22b.bak`).
+
+**Result:** red, one test.
+
+**Verbatim output:**
+
+```
+00:00 +12: a backlog after the baseline is refused rather than published
+00:00 +13: a stream that never goes quiet is refused, not measured
+00:00 +13 -1: a stream that never goes quiet is refused, not measured [E]
+  Expected: throws <Instance of 'StateError'>
+    Actual: <Instance of 'Future<void>'>
+     Which: emitted <null>
+  
+  package:matcher                                    expectLater
+  package:flutter_test/src/widget_tester.dart 507:8  expectLater
+  test/settle_attribution_test.dart 600:13           main.<fn>
+  
+00:00 +13 -1: Some tests failed.
+
+Failing tests:
+  /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: a stream that never goes quiet is refused, not measured
+```
+
+---
+
+## M22c — a hole published as a fast frame
+
+**Fix wave C, the first Minor.** `SettleReport.coveringFrameMs` was a
+non-nullable `double` filled from `ms.isEmpty ? 0.0 : (ms.last ?? 0.0)`.
+`FrameTimingLog.msAt`'s own doc forbids exactly that: *"Null rather than
+`0.0`: a frame that reported nothing is a hole in the sample, and zero is a
+**fast frame**. Publishing one as the other is how a composite blit that drew
+nothing gets read as a settle."* The field was guarded only by `framesMissing`
+and a printed warning, not by its type, so a reader taking the field alone got
+a zero where the doc promised a hole -- and zero is the fastest number the run
+can produce. The field and `ZoomReport.settleCoveringFrameMs` are now
+`double?`, and `printZoomReport` prints `coveringFrameMs=NONE` with its own
+warning line rather than `0.00`.
+
+**Mutation:** in `runSettlePhase`:
+
+```diff
+-    coveringFrameMs: ms.isEmpty ? null : ms.last,
++    coveringFrameMs: ms.isEmpty ? 0.0 : (ms.last ?? 0.0),
+```
+
+**Procedure:** as M22 (`measurement_rig_m22c.bak`).
+
+**Result:** red, one test -- `'a frame that never reports is a hole, not a
+zero'`, which asserted the shortfall and the wall clock but, until this fix,
+never asserted what the published per-frame figure was.
+
+**Verbatim output:**
+
+```
+00:00 +6: a frame that never reports is a hole, not a zero
+00:00 +6 -1: a frame that never reports is a hole, not a zero [E]
+  Expected: null
+    Actual: <0.0>
+  the field carries the hole. `0.0` here is a *fast frame*, and a reader who takes this field without also reading framesMissing would publish the fastest number in the run as criterion 3's settle
+  
+  package:matcher                                     expect
+  package:flutter_test/src/widget_tester.dart 473:18  expect
+  test/settle_attribution_test.dart 328:5             main.<fn>
+  
+00:00 +6 -1: the gesture window excludes the warm-up frames and keeps its tail
+00:00 +7 -1: a short sample is counted, and length plus missing is the script
+00:00 +8 -1: the baseline drains what arming did not, and rebases the ordinals
+00:00 +9 -1: a backlog reported after arming does not take the settle ordinals
+00:00 +10 -1: a backlog reported after arming does not pad the gesture window
+00:00 +11 -1: a backlog after the baseline is refused rather than published
+00:00 +12 -1: a stream that never goes quiet is refused, not measured
+00:00 +13 -1: Some tests failed.
+
+Failing tests:
+  /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/settle_attribution_test.dart: a frame that never reports is a hole, not a zero
+```
+
+**Restore, verified** -- for all three mutants. Each was restored by `cp` from
+its own scratchpad copy with an empty `diff`, and the restored file is
+byte-identical to the pre-M22 copy:
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
+00:00 +9: the baseline drains what arming did not, and rebases the ordinals
+00:00 +10: a backlog reported after arming does not take the settle ordinals
+00:00 +11: a backlog reported after arming does not pad the gesture window
+00:00 +12: a backlog after the baseline is refused rather than published
+00:00 +13: a stream that never goes quiet is refused, not measured
+00:00 +14: All tests passed!
+```
+
+---
+
+> **Fix wave D opens here.** `M23` and `M24` were fired in
+> `packages/jet_cad_2d_flutter/`, against the two Major findings of the
+> fix-wave review. Numbering in this file is shared between the waves;
+> `M22c` was the last number taken when these were fired.
+
+## M23 — the frame after a pan is not told it followed a pan
+
+**Fix wave D, the first Major finding.** The flash the review describes:
+`correct -> blank -> correct`, one frame long, on every pan that follows a
+zoom out. A pan frame changes the camera, so `_restGateSteps` is 0 and
+`resting`'s third disjunct sends it through the ordinary bake-and-live-walk
+path — correct pixels, ring included. Then the pan stops. The next frame
+repeats the same quantised camera, so the count reads **1**: too late for the
+`== 0` disjunct, too early for `>= kRestGateFrames`. `_carryOver` is still
+standing, because it is dropped only on a frame that covers *and* bakes
+nothing, so `resting` is false and the frame returns after the composite blit
+alone. The strip the composite has slid off is background for that one frame.
+
+The fix is the one bit the review named: `_lastChangeWasPan`, written only on a
+frame that changed something, so `resting` can tell "matched once after a pan"
+from "matched once after a zoom". Widening `resting` instead would have taken
+D1's wheel clause and D3's zoom-out ring with it, which is Ruling 17's mistake.
+
+**The gate this fires** is the new `the frame the pan stops on still fills what
+the composite does not cover`, in `test/tile_regime_test.dart`. It is a rig
+test and not a widget test on purpose: an uncovered cache asks `DraftCanvas`
+for another frame from a post-frame callback, so the repaint boundary is dirty
+the moment this frame ends and `captureTiled`'s `toImage` asserts on
+`!debugNeedsPaint` — and that same fact is what makes this frame reach the
+screen at all, so it cannot be arranged away. `captureTiledFrame` was added
+beside `captureLiveFrame` for it: the capture *is* the frame.
+
+**Mutation:** the bit, all three of it — the field, the write and the read:
+
+```diff
+-  bool _lastChangeWasPan = false;
+
+-    if (!cameraHeld || scaleChanged) _lastChangeWasPan = !scaleChanged;
+
+     final resting = previous == null ||
+         _carryOver == null ||
+         (!scaleChanged && _restGateSteps == 0) ||
+-        _lastChangeWasPan ||
+         _restGateSteps >= kRestGateFrames;
+```
+
+**Procedure:** as M17. `cp lib/src/tile_cache.dart /tmp/.../tile_cache.bak`,
+edit, run, restore by `cp`, `diff` to prove the restore, run again.
+
+**Result:** red, one test, and the measured ink in the strip is **literally
+zero** — not a shortfall but background, which is what the finding says the
+frame shows.
+
+**Verbatim output:**
+
+```
+00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart
+00:00 +0: the same camera compares same
+00:00 +1: a scale change compares different
+00:00 +2: a translation change compares different
+00:00 +3: the two scale terms are compared independently
+00:00 +4: the skew terms are compared too
+00:00 +5: a moving frame bakes nothing and walks nothing
+00:00 +6: a moving frame with no composite falls through and draws something
+00:00 +7: a steadily spun wheel never arms the rest gate
+00:00 +8: a pan after a zoom fills the region the composite slides off
+00:00 +9: the frame the pan stops on still fills what the composite does not cover
+00:00 +9 -1: the frame the pan stops on still fills what the composite does not cover [E]
+  Expected: a value greater than <200>
+    Actual: <0>
+     Which: is not a value greater than <200>
+  the one frame between the last pan and the rest bake must draw what the pan frames before it drew, or the strip flashes background for a frame and comes back
+  
+  package:matcher                                     expect
+  package:flutter_test/src/widget_tester.dart 473:18  expect
+  test/tile_regime_test.dart 357:5                    main.<fn>
+  
+00:00 +9 -1: a zoom out leaves its ring as background, the frame after the last notch included
+00:00 +10 -1: an edit inside one band rebakes that band alone
+00:00 +11 -1: a skipped band keeps its tiles out of the ceiling's reach
+00:00 +12 -1: the gate is two unchanged frames, and the constant says so
+00:00 +13 -1: Some tests failed.
+
+Failing tests:
+  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart: the frame the pan stops on still fills what the composite does not cover
+```
+
+**The two tests that must stay green under this mutant, and did.** `a steadily
+spun wheel never arms the rest gate` (D1's two-frame clause) and the new `a
+zoom out leaves its ring as background, the frame after the last notch
+included` (D3) are both in the transcript above, both passing while the pan
+arm fails. They gate the opposite direction: a fix that widened `resting`
+enough to catch the pan tail would redden one or both.
+
+**Restore, verified.** Empty `diff` against the pre-mutation copy, and:
+
+```
+00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart
+00:00 +0: the same camera compares same
+00:00 +1: a scale change compares different
+00:00 +2: a translation change compares different
+00:00 +3: the two scale terms are compared independently
+00:00 +4: the skew terms are compared too
+00:00 +5: a moving frame bakes nothing and walks nothing
+00:00 +6: a moving frame with no composite falls through and draws something
+00:00 +7: a steadily spun wheel never arms the rest gate
+00:00 +8: a pan after a zoom fills the region the composite slides off
+00:00 +9: the frame the pan stops on still fills what the composite does not cover
+00:00 +10: a zoom out leaves its ring as background, the frame after the last notch included
+00:00 +11: an edit inside one band rebakes that band alone
+00:00 +12: a skipped band keeps its tiles out of the ceiling's reach
+00:00 +13: the gate is two unchanged frames, and the constant says so
+00:00 +14: All tests passed!
+```
+
+---
+
+## M24 — a skipped band's keys are not stamped with the frame's serial — **a survivor, and the reason is arithmetic**
+
+**Fix wave D, the second Major finding.** The review is right that
+`tile_regime_test.dart`'s `a skipped band keeps its tiles out of the ceiling's
+reach` cannot fail: `pumpTiled` never sets `cacheBytes`, so the cache runs at
+`kTileCacheBytes` against ~2.1 MB of tiles and `_makeRoomForBytes` exits before
+its first iteration. The arm it asks for — a cap tight enough that the only
+remaining eviction victims are a skipped band's keys — **cannot be built**, and
+not for want of a tight enough cap. Under every cap the rest bake will run
+under, a skipped band's key can never be selected as a victim at all.
+
+**The derivation.** Write `t` for `_tileBytes`, `V` for the visible tiles held
+at the moment of a room request, `St` for the stale off-viewport tiles held.
+
+1. `_restBake` refuses to start unless `bandBytes + visibleTiles * t <=
+   cacheBytes` (`tile_cache.dart:1306`). At the harness's viewport that is
+   `13t + 130t = 143t`, and it is the smallest cap the rest bake runs under.
+2. Every room request inside the rest bake is made while a visible key is
+   still missing — `_makeRoomForBytes(bandBytes + t)` runs only when the band
+   has a missing key, `_makeRoomForOneTile()` only for a key not in `_tiles` —
+   so `V <= visibleTiles - 1`.
+3. The ceiling for `_makeRoomForBytes(bandBytes + t)` is `cacheBytes -
+   14t >= 129t`, and `liveBytes` is `(V + St) * t` there (`_band` is not yet
+   assigned, and the composite was dropped before the loop). Evictions needed:
+   `V + St - 129 <= St`. For `_makeRoomForOneTile` inside the slice loop the
+   band image is resident, and the same subtraction gives the same bound.
+4. **Every stale key's serial is strictly older than every visible key's.** A
+   key is stamped only on a frame it is visible on, and the frame that made a
+   key stale is by definition a frame whose camera changed — which resets the
+   rest gate, so no rest bake happens on it.
+
+So the demand never exceeds the stale supply, and the victim policy is
+oldest-first: `_makeRoomForBytes` takes stale keys and stops before it reaches
+any visible key, skipped band or otherwise. The stamp is unobservable through
+`viewportCovered`, `evictionCount`, `liveTileCount` or `liveBytes` — and by the
+end of the frame every visible key carries the serial anyway, because the tile
+loop stamps each one it blits.
+
+**Mutation:** the three lines the review names:
+
+```diff
+       if (!bandMissing) {
+-        for (final key in band.keys) {
+-          _lastUsedFrame[key] = _frameSerial;
+-        }
+         continue;
+       }
+```
+
+**Procedure:** as M23, plus a scratch probe built to be the arm and run under
+both variants. The probe is `bandCrossingGrid` settled from bands, then *n*
+pans of exactly one tile (64 device pixels, so the visible key count stays 130
+and the pricing minimum stays `143t`), each settled — which leaves 10 stale
+keys per pan and nothing else — then `cacheBytes = 143 * 16384 = 2342912`, then
+`moveOneEntityWithinOneBand` and a settle. That is the tightest legal cap with
+a real eviction load inside a rest bake that skips nine of its ten bands. It
+was **not landed**: it distinguishes nothing, and a test that cannot fail is
+the finding it was written to close.
+
+**Result: survives.** Identical numbers under both variants, to the byte.
+
+Before the mutation:
+
+```
+PROBE pans=0 held=130 afterCap=130 bytesAfterCap=2129920 evictionsDuringEdit=0 liveTiles=130 covered=true liveDraws=2 bakes=142 liveBytes=2129920 cap=2342912
+PROBE pans=1 held=140 afterCap=140 bytesAfterCap=2293760 evictionsDuringEdit=0 liveTiles=137 covered=true liveDraws=2 bakes=185 liveBytes=2244608 cap=2342912
+PROBE pans=3 held=160 afterCap=160 bytesAfterCap=2621440 evictionsDuringEdit=8 liveTiles=143 covered=true liveDraws=2 bakes=199 liveBytes=2342912 cap=2342912
+PROBE pans=6 held=190 afterCap=190 bytesAfterCap=3112960 evictionsDuringEdit=29 liveTiles=143 covered=true liveDraws=2 bakes=220 liveBytes=2342912 cap=2342912
+00:00 +4: All tests passed!
+```
+
+After it:
+
+```
+PROBE pans=0 held=130 afterCap=130 bytesAfterCap=2129920 evictionsDuringEdit=0 liveTiles=130 covered=true liveDraws=2 bakes=142 liveBytes=2129920 cap=2342912
+PROBE pans=1 held=140 afterCap=140 bytesAfterCap=2293760 evictionsDuringEdit=0 liveTiles=137 covered=true liveDraws=2 bakes=185 liveBytes=2244608 cap=2342912
+PROBE pans=3 held=160 afterCap=160 bytesAfterCap=2621440 evictionsDuringEdit=8 liveTiles=143 covered=true liveDraws=2 bakes=199 liveBytes=2342912 cap=2342912
+PROBE pans=6 held=190 afterCap=190 bytesAfterCap=3112960 evictionsDuringEdit=29 liveTiles=143 covered=true liveDraws=2 bakes=220 liveBytes=2342912 cap=2342912
+00:00 +4: All tests passed!
+```
+
+The `pans=3` and `pans=6` rows are the ones that matter: 8 and 29 evictions
+happen *during* the edit frame, at a `liveBytes` that lands exactly on the cap,
+with nine bands skipped — and the coverage, the tile count and the eviction
+count are the same with the stamp and without it. Clause 4 above is why: those
+victims are stale keys, and the demand stopped before the visible set.
+
+The whole package suite also stays green under the mutation — 413 passing, 1
+skipped, the same as with it.
+
+**Restore, verified.** Empty `diff` against the pre-mutation copy, and the
+package suite green again (the gate transcript in the fix-wave report).
+
+**What was done instead of the arm.** The production stamp stays: it is what
+the ceiling proof cites, and it costs one map write per key of a skipped band.
+The test's comment was rewritten to say what it actually gates — that a skipped
+band's tiles are still standing and still blitted afterwards — and to record
+that the stamp itself is unobservable, with the derivation and a pointer here.
+Gating it would need an instrument that can see intra-frame victim selection,
+which is a production seam, and the brief for this wave forbids adding one for
+it.
+
+**A second thing the derivation settles**, recorded because the review's arm
+was framed around it: a hole left by such an eviction would not be a blank
+region even if one could be produced. A missing key becomes part of `uncovered`
+and the live fallback draws it — correct pixels at a cost — and the one path
+that would show background instead, `carryOverCovers` returning early, is
+unreachable here: a frame that skips a band holds tiles from a previous fill,
+and a standing composite implies a scale change, which disposes every tile. So
+`viewportCovered` was never the observable this proof needed.
diff --git a/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart b/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
index 5b3d51f..539c1af 100644
--- a/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
+++ b/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
@@ -603,24 +603,44 @@ class TileCache {
   /// Consecutive frames whose quantised camera did not change.
   ///
   /// Zero on the frame that changed. **One** is the frame in between, which
   /// draws like a moving frame. **Two** arms the rest bake. The second frame
   /// is the mouse wheel's: a wheel delivers isolated notches, so without it
   /// every notch is one moving frame followed immediately by a resting frame,
   /// a full bake per notch discarded by the next.
   int _restGateSteps = 0;
 
   /// The rest gate's counter, for tests. See [_restGateSteps].
   int get debugRestGateSteps => _restGateSteps;
 
+  /// Whether the camera's **last actual change** moved the translation alone.
+  ///
+  /// **The one bit that tells the frame after a pan from the frame between two
+  /// wheel notches.** Both are frames whose camera repeated the previous one,
+  /// so [_restGateSteps] reads 1 on both and the count alone cannot separate
+  /// them — and they owe opposite frames. After a zoom, D1's two-frame clause
+  /// says the in-between frame must stay as cheap as a moving frame, or a
+  /// steadily spun wheel bakes once per notch; after a pan, the same frame owes
+  /// the bake-and-live-walk every pan frame before it paid, or the strip the
+  /// composite has slid off goes background for exactly one frame and comes
+  /// back — the flash D8 does not permit and D3 does not cover, because D3's
+  /// accepted ring is a zoom *out*'s and nothing else.
+  ///
+  /// Written only on a frame that changed something, so it remembers the last
+  /// change across any number of unchanged frames. **A scale change always
+  /// writes `false` here**, whether or not the quantised camera also moved, so
+  /// this can never be true on a moving frame and the disjunct it feeds needs
+  /// no `!scaleChanged` of its own.
+  bool _lastChangeWasPan = false;
+
   /// **Suppresses the rest bake. A measurement switch, not a correctness
   /// switch.**
   ///
   /// Set, the resting frame never calls `_restBake`, and the cache fills the
   /// viewport the way it did before Plan 3i: the ordinary budgeted per-tile
   /// path, `budgetedTilesPerFrame` tiles a frame, over as many frames as that
   /// takes. That is not an alternative configuration of the rest bake — it is
   /// an earlier revision of `paintFrame`, and it is **precisely how criterion
   /// 4's denominator arm is defined**.
   ///
   /// **It exists so one binary can run both arms of criterion 4's ratio in a
   /// single session, interleaved.** That is the only reason a production
@@ -990,28 +1010,34 @@ class TileCache {
     // and not yet twice is the one in between. Both draw the composite and
     // nothing else: no bake, and no live walk. A frame that changed only its
     // translation is none of the three -- it is a pan, and D8 leaves the pan
     // path exactly as it was.
     //
     // The live walk is excluded deliberately and the measurement is why. On a
     // moving frame the new generation is empty, so every visible key misses
     // and `uncovered` accumulates by `expandToInclude` into the **whole
     // viewport** rather than a ring; `stripFor` then clamps to the viewport.
     // "Walk the uncovered region" is therefore a full-viewport live walk --
     // 31.5-41.6 ms at 500,000 entities -- on every zoom-out frame.
     final previous = _lastQuantised;
-    _restGateSteps =
-        previous != null && sameQuantisedCamera(previous, quantised)
-            ? _restGateSteps + 1
-            : 0;
+    final cameraHeld =
+        previous != null && sameQuantisedCamera(previous, quantised);
+    _restGateSteps = cameraHeld ? _restGateSteps + 1 : 0;
+    // **Only a frame that changed something writes the bit**, which is what
+    // makes it a memory rather than a second reading of this frame. A scale
+    // change writes `false` even when the quantised camera itself held --
+    // a device-pixel-ratio or tile-size change re-anchors the generation
+    // without moving the camera -- so [_lastChangeWasPan] is never true on a
+    // frame `resting` must treat as moving.
+    if (!cameraHeld || scaleChanged) _lastChangeWasPan = !scaleChanged;
     _lastQuantised = quantised;
     // **`previous == null` is not a moving frame.** It is the very first
     // frame this cache has ever painted, with nothing behind it to have
     // moved away from. Gating it on the literal `_restGateSteps >=
     // kRestGateFrames` would leave a brand-new cache blank -- no bake, and
     // since nothing has ever been retired -- until some later frame
     // fortuitously repeated the same camera.
     //
     // **Not `&& !_viewportCovered` either.** A frame whose camera matches the
     // last one but whose generation already covers the viewport still has to
     // run the loop below: every visible key already holds an image, so the
     // loop bakes nothing on its own, but it still has to *blit* those images
@@ -1049,27 +1075,39 @@ class TileCache {
     // camera happened to hold still for [kRestGateFrames] frames. D3's
     // accepted ring is a zoom-out's ring and nothing else; an unfilled pan is
     // a regression against D8, and before this plan the same frame paid a
     // live walk over the uncovered region and got the pixels right.
     //
     // **`_restGateSteps == 0` is what makes this the pan and not the frame
     // *between* two zoom notches.** D1's third frame kind -- matched once, not
     // yet twice -- draws what a moving frame draws, and it is a frame whose
     // camera did *not* change, so it carries a count of at least one. A pan
     // frame changed the camera and reset the count to zero. Reading the count
     // rather than the camera keeps the wheel's in-between frame cheap, which
     // is the whole of D1's two-frame clause.
+    //
+    // **And [_lastChangeWasPan] is what carries the pan one frame further.**
+    // The count alone stops at the frame the pan stops on: the *next* frame
+    // repeats the same camera, so the count reads 1 -- too late for the
+    // disjunct above, too early for the gate below -- and with the composite
+    // still standing the frame returned after the blit alone. The strip the
+    // composite has slid off was background for that one frame and correct
+    // again on the next: correct -> blank -> correct, on every pan tail. The
+    // bit says which kind of change the count is counting away from, so a pan
+    // tail keeps drawing what its pan frames drew while a wheel's in-between
+    // frame stays exactly as cheap as the notch before it.
     final resting = previous == null ||
         _carryOver == null ||
         (!scaleChanged && _restGateSteps == 0) ||
+        _lastChangeWasPan ||
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
diff --git a/packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart b/packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart
index e4c5134..c3862bf 100644
--- a/packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart
+++ b/packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart
@@ -575,29 +575,40 @@ void main() {
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
-    // **Two walks, one per frame that owed one, and the pan frame is the one
-    // that changed.** Before the D8 fix a same-scale pan with a composite
-    // standing took `paintFrame`'s moving-frame early return, so the three
-    // frames below were: pan -- composite only, no walk; the in-between
-    // frame; then the rest frame, whose rest bake the ceiling declines and
-    // whose tile loop the ceiling admits nothing to, leaving one live walk.
-    // The pan is a pan and not a zoom, so it is no longer a moving frame: it
-    // falls through and pays its own walk over a viewport the shrunken
-    // ceiling cannot tile. That is the whole point of the fix -- the region
-    // the composite slid off is drawn rather than left as background -- and
-    // the number moving from 1 to 2 is what records it.
-    expect(squeezed.cache.liveDrawCount, 2,
+    // **Three walks, one per frame that owed one, and both of the first two
+    // are fixes this plan landed.** The three frames below are: the pan; the
+    // frame the pan stops on -- matched once, not yet twice; then the rest
+    // frame, whose rest bake the ceiling declines and whose tile loop the
+    // ceiling admits nothing to.
+    //
+    // Before the D8 fix only the last of the three walked: a same-scale pan
+    // with a composite standing took `paintFrame`'s moving-frame early
+    // return, and so did the frame after it. The pan is a pan and not a zoom,
+    // so it is no longer a moving frame -- 1 became 2. The frame the pan
+    // stops on repeats that camera, which put `_restGateSteps` at 1: too late
+    // for the pan disjunct, too early for the rest gate, so it took the early
+    // return alone and the strip the composite had slid off was background
+    // for exactly that one frame, correct either side of it. `_lastChangeWasPan`
+    // is what carries the pan through it -- 2 became 3.
+    //
+    // **The count is one walk per frame and no more.** Each of these frames
+    // draws a viewport the shrunken ceiling cannot tile at all, so every one
+    // of them owes exactly one walk; a number above three here would mean a
+    // frame walking twice, and a number below it a frame showing background
+    // or stale pixels.
+    expect(squeezed.cache.liveDrawCount, 3,
         reason: 'and the live walk is what stops the frame going blank '
             'instead -- once on the pan frame, which no longer hides behind '
-            'the composite, and once on the rest frame that follows it');
+            'the composite, once on the frame the pan stops on, and once on '
+            'the rest frame that follows it');
   });
 }
diff --git a/packages/jet_cad_2d_flutter/test/support/tile_comparison.dart b/packages/jet_cad_2d_flutter/test/support/tile_comparison.dart
index 25aa4e4..86054a0 100644
--- a/packages/jet_cad_2d_flutter/test/support/tile_comparison.dart
+++ b/packages/jet_cad_2d_flutter/test/support/tile_comparison.dart
@@ -222,24 +222,52 @@ Future<InkReport> expectTiledEqualsLive(TileRig rig,
 /// reason: the two arms must be one drawing seen twice.
 Future<Uint8List> captureLiveFrame(TileRig rig) => _capture((canvas) {
       final quantised = quantiseCamera(rig.camera, kTileDpr);
       rig.painter.debugRebaseOrigin =
           rebaseOriginFor(quantised.visibleWorld(kTileViewport));
       rig.sink.canvas = canvas;
       rig.vertices.canvas = canvas;
       rig.painter.paint(rig.vertices, quantised, kTileViewport);
       rig.vertices.flush();
       rig.painter.debugRebaseOrigin = null;
     });
 
+/// The **tiled** frame's device pixels, RGBA, row-major at [kTileDpr].
+///
+/// [captureLiveFrame]'s counterpart, and the only instrument that can see the
+/// frame kinds a cache reaches by *standing still*. The widget capture
+/// (`captureTiled`) cannot: an uncovered cache asks `DraftCanvas` for another
+/// frame from a post-frame callback, so by the time `pump` returns the repaint
+/// boundary is dirty and `toImage` asserts on `!debugNeedsPaint`. Precisely
+/// the states this reads -- an unsettled cache one frame after the camera
+/// stopped -- are the ones that leave it dirty.
+///
+/// **The capture is itself a frame, and that is the point.** It calls
+/// `paintFrame` once at the rig's current camera, exactly as the next frame of
+/// the application would, and the cache advances accordingly: the pixels
+/// returned are that frame's, and the counters read afterwards are that
+/// frame's too.
+Future<Uint8List> captureTiledFrame(TileRig rig) => _capture((canvas) {
+      rig.cache.paintFrame(
+        canvas: canvas,
+        viewport: kTileViewport,
+        devicePixelRatio: kTileDpr,
+        camera: rig.camera,
+        painter: rig.painter,
+        sink: rig.sink,
+        vertices: rig.vertices,
+        tablesRevision: rig.doc.tables.mutationRevision,
+      );
+    });
+
 /// Non-transparent pixels of [pixels] inside [logical], a rectangle in
 /// **logical** pixels that is scaled by [kTileDpr] and clipped to the capture.
 ///
 /// The capture is the device-pixel buffer [captureLiveFrame] returns;
 /// `TileCache.debugLastStrip` is logical, like every rectangle `paintFrame`
 /// works in, so the conversion belongs here rather than at the call site.
 int inkInside(Uint8List pixels, Rect logical) {
   final width = (kTileViewport.width * kTileDpr).round();
   final height = (kTileViewport.height * kTileDpr).round();
   final x0 = (logical.left * kTileDpr).floor().clamp(0, width);
   final x1 = (logical.right * kTileDpr).ceil().clamp(0, width);
   final y0 = (logical.top * kTileDpr).floor().clamp(0, height);
diff --git a/packages/jet_cad_2d_flutter/test/tile_regime_test.dart b/packages/jet_cad_2d_flutter/test/tile_regime_test.dart
index 6f431ed..f749f03 100644
--- a/packages/jet_cad_2d_flutter/test/tile_regime_test.dart
+++ b/packages/jet_cad_2d_flutter/test/tile_regime_test.dart
@@ -3,24 +3,38 @@ import 'dart:ui';
 import 'package:flutter_test/flutter_test.dart';
 import 'package:jet_cad_2d/jet_cad_2d.dart';
 import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
 
 import 'support/tile_comparison.dart';
 import 'support/tile_fixture.dart';
 import 'support/tile_harness.dart';
 
 void main() {
   ViewportTransform at(double scale, double e, double f) => ViewportTransform(
       worldToScreenMatrix: Transform2(scale, 0, 0, -scale, e, f));
 
+  /// Enough more frames at the camera [rig] just painted for the rest gate to
+  /// arm and a resting frame to actually bake.
+  ///
+  /// `tile_budget_test.dart` carries the same three lines for the same reason
+  /// and neither is imported by the other; both are written from
+  /// [kRestGateFrames] rather than from a literal, so the gate's threshold
+  /// stays the single bound. `tile_harness.dart`'s `settle` is the widget
+  /// harness's and pumps a tree; this one paints a rig.
+  void settleRig(TileRig rig) {
+    for (var i = 0; i < kRestGateFrames; i++) {
+      rig.paintOnce();
+    }
+  }
+
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
@@ -246,24 +260,185 @@ void main() {
     // `captureLive` replaces the widget tree and disposes the cache behind
     // `h`, so it comes last and nothing is read from the cache after it.
     final live = await captureLive(t, h);
     expect(inkInsideCapture(live, revealed), greaterThan(200),
         reason: 'non-vacuity: the fixture must actually draw in the strip, '
             'or "the tiled frame drew nothing there" is not a defect');
     expect(ink, greaterThan(200),
         reason: 'the region the composite slid off must carry the drawing, '
             'not background: this is spec D3 accepting a ring on a zoom '
             '*out* and nothing else');
   });
 
+  // **The frame the pan stops on, which is a frame class of its own.** Every
+  // pan frame above changes the camera, so `_restGateSteps` reads 0 and the
+  // frame falls through to bake-and-live-walk. Then the user stops: the next
+  // frame repeats the same quantised camera, the count reads 1 -- too late for
+  // that disjunct, too early for the rest gate -- and with the composite still
+  // standing the frame returned after the composite blit alone. The strip the
+  // composite had slid off was background for exactly one frame and correct
+  // again on the next: correct -> blank -> correct, on every pan tail. The
+  // frame *before* it only became correct with the D8 fix above, which is what
+  // makes the flash stand out rather than what introduced it.
+  //
+  // Nothing but the remembered bit separates this frame from a wheel's
+  // in-between frame, which owes the opposite answer: the zoom-out test below
+  // holds that end and the wheel test above holds D1's.
+  //
+  // **A rig and not the widget harness, because of what the frame is.** An
+  // uncovered cache asks `DraftCanvas` for another frame from a post-frame
+  // callback, so the repaint boundary is dirty the moment this frame ends and
+  // `captureTiled`'s `toImage` asserts rather than capturing. The same fact is
+  // what makes this frame reach the screen at all, so it cannot be arranged
+  // away -- see [captureTiledFrame].
+  test(
+      'the frame the pan stops on still fills what the composite '
+      'does not cover', () async {
+    final measurer = FlutterTextMeasurer();
+    addTearDown(measurer.clear);
+    // **Four tiles a frame, and it is load-bearing twice over.** The rest bake
+    // ignores the budget, so the settle below still covers in one frame; the
+    // *pan* frames are budgeted, and a generation that caught up during the
+    // pan would both cover the viewport -- ending the settle, so the tail
+    // frame never happens -- and drop the composite the tail frame blits.
+    final rig = TileRig(
+        tileDevicePixels: 64,
+        tilesBakedPerFrame: 4,
+        document: fillingGrid(measurer));
+    addTearDown(rig.dispose);
+
+    rig.paintOnce();
+    settleRig(rig);
+    expect(rig.cache.viewportCovered, isTrue,
+        reason: 'setup: a generation that covers is what a zoom can retire '
+            'into a composite');
+
+    // A zoom **out**, so the composite cannot cover: it shrinks about the
+    // viewport centre to [50, 350] x [37.5, 262.5] logical, and D3 leaves the
+    // ring outside it as background for the length of the gesture. The strip
+    // this test reads is not that ring -- it is inside the composite's own
+    // rows and to the right of where the *pan* carried it, which is D8's
+    // business and not D3's.
+    rig.zoomBy(0.75);
+    rig.paintOnce();
+    expect(rig.cache.hasCarryOver, isTrue,
+        reason: 'setup: the zoom minted the composite the pan then carries');
+    expect(rig.cache.liveTileCount, 0,
+        reason: 'setup: and retired every tile, so anything on screen below '
+            'is the pan frames own');
+
+    for (var i = 0; i < 4; i++) {
+      rig.panBy(-40, 0);
+      rig.paintOnce();
+    }
+    expect(rig.cache.hasCarryOver, isTrue,
+        reason: 'setup: the composite is still standing, which is what makes '
+            'the frame below take the early return at all');
+    expect(rig.cache.viewportCovered, isFalse,
+        reason: 'setup: an uncovered cache is what asks `DraftCanvas` for the '
+            'tail frame -- covered, the flash frame would never be painted');
+    expect(rig.cache.debugRestGateSteps, 0,
+        reason: 'setup: every pan frame changed the camera');
+
+    // The tail frame: one more frame at exactly the camera the last pan left.
+    final tiled = await captureTiledFrame(rig);
+    expect(rig.cache.debugRestGateSteps, 1,
+        reason: 'the frame under test is the one that has matched once and '
+            'not yet twice -- neither a pan frame nor a rest frame');
+
+    // The strip the composite has slid off, taken inside the composite's own
+    // rows so that D3's accepted ring cannot account for it: the composite
+    // reaches x = 190 after four pans of 40 logical pixels, and the fixture
+    // inks out to x = 261 at this camera.
+    const revealed = Rect.fromLTRB(194, 40, 258, 240);
+    final live = await captureLiveFrame(rig);
+    expect(inkInside(live, revealed), greaterThan(200),
+        reason: 'non-vacuity: the fixture must actually draw in the strip, '
+            'or "the tiled frame drew nothing there" is not a defect');
+    expect(inkInside(tiled, revealed), greaterThan(200),
+        reason: 'the one frame between the last pan and the rest bake must '
+            'draw what the pan frames before it drew, or the strip flashes '
+            'background for a frame and comes back');
+  });
+
+  // **Spec D3, at the frame the test above could have broken.** A zoom out
+  // shrinks the composite and leaves a ring, and that ring stays background
+  // until the gesture ends: the alternative is a full-viewport live walk on
+  // every zoom-out frame -- 31.5-41.6 ms at 500,000 entities -- because the
+  // uncovered region bounds to the whole viewport while the incoming
+  // generation is empty.
+  //
+  // The frame after the last notch is the one at risk. It has matched once and
+  // not yet twice, exactly like the pan tail above, and it must still draw
+  // what a moving frame draws. **The pan before the gesture is not
+  // decoration**: it leaves the remembered bit set, so a bit a scale change
+  // fails to clear turns this frame into the full-viewport walk D3 refuses.
+  test(
+      'a zoom out leaves its ring as background, the frame after the '
+      'last notch included', () async {
+    final measurer = FlutterTextMeasurer();
+    addTearDown(measurer.clear);
+    final rig = TileRig(
+        tileDevicePixels: 64,
+        tilesBakedPerFrame: 1000,
+        document: fillingGrid(measurer));
+    addTearDown(rig.dispose);
+
+    rig.paintOnce();
+    settleRig(rig);
+    rig.panBy(-24, 0);
+    rig.paintOnce();
+    settleRig(rig);
+    expect(rig.cache.viewportCovered, isTrue,
+        reason: 'setup: the pan settled, and left the last camera change a '
+            'pan rather than a zoom');
+
+    rig.cache.resetCounters();
+    for (var notch = 0; notch < 3; notch++) {
+      rig.zoomBy(0.9);
+      rig.paintOnce();
+      if (notch == 0) {
+        expect(rig.cache.hasCarryOver, isTrue,
+            reason: 'setup: the first notch retires the settled generation '
+                'into the composite the rest of the gesture blits');
+      }
+    }
+    expect(rig.cache.debugRestGateSteps, 0,
+        reason: 'setup: every notch changed the camera');
+
+    // The frame after the last notch.
+    final tiled = await captureTiledFrame(rig);
+    expect(rig.cache.debugRestGateSteps, 1,
+        reason: 'the frame under test has matched once and not yet twice');
+    expect(rig.cache.bakeCount, 0,
+        reason: 'a zoom gesture and the frame after it bake nothing (D1)');
+    expect(rig.cache.liveDrawCount, 0,
+        reason: 'and walk no live geometry: on a zoom-out frame the uncovered '
+            'region bounds to the whole viewport, so a walk here is a '
+            'full-viewport walk -- the frame D3 exists to prevent');
+    expect(rig.cache.carryOverBlitCount, greaterThan(0),
+        reason: 'non-vacuity: those frames did still show something');
+
+    // And the ring itself, in pixels. Three notches of 0.9 put the
+    // composite's right edge at 200 + 0.729 * 200 = 345.8 logical, while the
+    // fixture inks past the viewport's own edge at this camera.
+    const ring = Rect.fromLTRB(348, 30, 398, 270);
+    final live = await captureLiveFrame(rig);
+    expect(inkInside(live, ring), greaterThan(200),
+        reason: 'non-vacuity: there is drawing out there to have left out');
+    expect(inkInside(tiled, ring), 0,
+        reason: 'the ring is background until the gesture ends, and the frame '
+            'after the last notch is still inside the gesture');
+  });
+
   // **Spec D6 and the rest bake's own doc comment, at the granularity the
   // walk happens at.** One missing key anywhere in the viewport used to
   // commit every band to a full painter walk, an owner climb, a
   // `toImageSync` and a `_bakes++` -- and then to throw the image away,
   // because the per-key skip inside the band loop skips only the slice.
   //
   // This is the ordinary edit path: after an `applyChange` the camera has not
   // moved, so the gate is still armed and the next frame rest-bakes, while
   // invalidation has typically condemned one band.
   testWidgets('an edit inside one band rebakes that band alone', (t) async {
     final h = await pumpTiled(t, document: bandCrossingGrid);
     await settleFromBands(t, h);
@@ -317,31 +492,55 @@ void main() {
             'walk for three rows, on every frame of a drag');
     expect(h.cache.bakeCount, lessThan(allBands),
         reason: 'stated twice on purpose: the exact 3 pins the pad is reach, '
             'and this clause is the one that fails if the frame-global probe '
             'comes back and every band bakes again');
     expect(h.cache.viewportCovered, isTrue,
         reason: 'and skipping them must not leave a hole: a skipped band '
             'keeps its tiles, and they are still blitted');
   });
 
   testWidgets('a skipped band keeps its tiles out of the ceiling\'s reach',
       (t) async {
-    // The other half of the skip, and the half that is easy to get wrong.
-    // `_makeRoomForBytes` may evict any tile whose recency is older than this
-    // frame's, so a band skipped *without* touching its keys' recency would
-    // leave them evictable by a later band's own room-making -- and the frame
-    // would blit a hole in a row it had already decided it owned. The rest
-    // bake's up-front pricing rests on exactly that: at band `i` the
-    // un-evictable set is the keys of bands `0..i-1`.
+    // The other half of the skip: a rest bake that skips a band must leave
+    // that band's tiles standing and blittable, and this measures that they
+    // are -- nothing evicted, and the generation exactly as large afterwards
+    // as before.
+    //
+    // **What it does not gate, stated because it reads as though it does.**
+    // The skip branch also stamps every key of a skipped band with the
+    // frame's serial, and that stamp is what the ceiling proof cites -- at
+    // band `i` the set `_makeRoomForBytes` may not evict is the keys of bands
+    // `0..i-1`. Deleting the stamp changes nothing this test, or any other,
+    // can see, and the reason is arithmetic rather than headroom:
+    //
+    // * the rest bake refuses to start unless `cacheBytes` funds one band plus
+    //   **every** visible tile, so the ceiling for a room request inside it is
+    //   at least `visibleTiles - 1` tiles;
+    // * every room request inside it is made while a visible key is still
+    //   missing, so at most `visibleTiles - 1` visible tiles are held;
+    // * therefore the eviction demand never exceeds the number of *stale*
+    //   off-viewport keys held, and every stale key's serial is strictly
+    //   older than any visible key's -- a key is stamped only on a frame it is
+    //   visible on -- so `_makeRoomForBytes` takes stale keys and stops.
+    //
+    // Measured at the tightest cap the rest bake will run under
+    // (`13 + 130` tiles here), with 30 and 60 stale keys left by whole-tile
+    // pans: identical eviction counts, tile counts, coverage and byte peaks
+    // with the stamp and without it. See **M24** in
+    // `docs/superpowers/notes/plan-3i-mutation-log.md`, recorded there as a
+    // survivor with the derivation; the stamp stays in the production path as
+    // the belt to the pricing's braces, and gating it would need an
+    // instrument that can see intra-frame victim selection, which is a
+    // production seam this plan will not add for it.
     final h = await pumpTiled(t, document: bandCrossingGrid);
     await settleFromBands(t, h);
     final tiles = h.cache.liveTileCount;
 
     h.cache.resetCounters();
     final evictedBefore = h.cache.evictionCount;
     h.moveOneEntityWithinOneBand();
     await t.pump();
     await settle(t, h);
 
     expect(h.cache.evictionCount, evictedBefore,
         reason: 'nothing may be evicted here: every visible key carries this '
```
