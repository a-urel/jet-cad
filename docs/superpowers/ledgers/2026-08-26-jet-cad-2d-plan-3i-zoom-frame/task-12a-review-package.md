# Review package — Task 12a/13a

## Commits
50445e4 test(harness): runInterleaved alternates whole arms, never blocks them
2f90f15 feat(tiles): runtime seams for criterion 4's and criterion 8's interleaved arms

## Stat
```
 apps/dev_harness_2d/lib/measurement_rig.dart       |  38 ++++
 .../dev_harness_2d/test/interleaved_arms_test.dart |  61 ++++++
 docs/superpowers/notes/plan-3i-mutation-log.md     | 196 ++++++++++++++++++
 .../jet_cad_2d_flutter/lib/src/tile_cache.dart     |  79 +++++++-
 .../test/tile_measurement_seam_test.dart           | 224 +++++++++++++++++++++
 5 files changed, 596 insertions(+), 2 deletions(-)
```

## Diff
```diff
diff --git a/apps/dev_harness_2d/lib/measurement_rig.dart b/apps/dev_harness_2d/lib/measurement_rig.dart
index f5aa05f..2f7e973 100644
--- a/apps/dev_harness_2d/lib/measurement_rig.dart
+++ b/apps/dev_harness_2d/lib/measurement_rig.dart
@@ -880,10 +880,48 @@ void printZoomReport(String label, ZoomReport r) {
         'p50=${sorted[(sorted.length * 0.5).floor()].toStringAsFixed(2)}ms '
         'p95=${sorted[(sorted.length * 0.95).floor()].toStringAsFixed(2)}ms '
         'max=${sorted.last.toStringAsFixed(2)}ms '
         'mean=${(sum / sorted.length).toStringAsFixed(2)}ms');
   }
   print('  gestureBakes=${r.gestureBakes}(tiles, budgeted path) '
       'gestureLiveDraws=${r.gestureLiveDraws}');
   print('  settleFrames=${r.settleFrames} '
       'settleMs=${r.settleMs.toStringAsFixed(2)}');
 }
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
diff --git a/docs/superpowers/notes/plan-3i-mutation-log.md b/docs/superpowers/notes/plan-3i-mutation-log.md
index f36f386..e78f003 100644
--- a/docs/superpowers/notes/plan-3i-mutation-log.md
+++ b/docs/superpowers/notes/plan-3i-mutation-log.md
@@ -1208,10 +1208,206 @@ Try `flutter pub outdated` for more information.
 00:00 +5 -1: a steadily spun wheel never arms the rest gate
 00:00 +6 -1: the gate needs two unchanged frames, not one
 00:00 +7 -1: Some tests failed.
 
 Failing tests:
   /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart: the skew terms are compared too
 ```
 
 Restored from the scratchpad copy and re-ran the same file green (`+8: All
 tests passed!`) before moving on.
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
diff --git a/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart b/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
index e83281d..d5386e5 100644
--- a/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
+++ b/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
@@ -605,20 +605,57 @@ class TileCache {
   /// Zero on the frame that changed. **One** is the frame in between, which
   /// draws like a moving frame. **Two** arms the rest bake. The second frame
   /// is the mouse wheel's: a wheel delivers isolated notches, so without it
   /// every notch is one moving frame followed immediately by a resting frame,
   /// a full bake per notch discarded by the next.
   int _restGateSteps = 0;
 
   /// The rest gate's counter, for tests. See [_restGateSteps].
   int get debugRestGateSteps => _restGateSteps;
 
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
 
@@ -793,20 +830,56 @@ class TileCache {
   /// sweep that derived this rectangle from [TileGrid] would repeat that.
   ///
   /// **A getter, not a mutable field.** `TileCache` already carries two
   /// mutable test-only fields and the standing bar is that a third triggers
   /// revisiting the design; `tilesHolding` is the precedent for reading state
   /// out without adding a way to write it.
   Rect? get debugLastStrip => _lastStrip;
 
   Rect? _lastStrip;
 
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
 
@@ -972,21 +1045,21 @@ class TileCache {
     // **The literal gate here, and not `resting`.** `resting` is true on two
     // frames that are not at rest at all: the very first frame this cache
     // paints, and any moving frame with no composite to fall back on. Both
     // disjuncts exist to stop a frame painting *nothing* -- the comment above
     // says so in as many words: they "fall through to the ordinary
     // bake-and-live-walk path". That path is budgeted and the band bake is
     // not, so handing those two frames to the band bake would spend a
     // full-viewport walk on the first frame of a still-moving gesture, which
     // is precisely the zoom-regime cost this cache exists to refuse. A band
     // is for a camera that has actually stopped.
-    if (_restGateSteps >= kRestGateFrames) {
+    if (_restGateSteps >= kRestGateFrames && !debugRestBakeDisabled) {
       _restBake(grid, quantised, viewport, painter, sink, vertices, origin);
     }
 
     for (final key in grid.visibleKeys(quantised, viewport)) {
       var image = _tiles[key];
       // **The ceiling is consulted before the bake, not after the frame.** A
       // small cap against a viewport of many tiles means the visible set alone
       // overruns it, so a sweep at the end of `paintFrame` would have nothing
       // left to reclaim -- every tile it could take was blitted this frame --
       // and `liveBytes` would settle wherever the visible set happened to put
@@ -1064,21 +1137,23 @@ class TileCache {
     // line and the pad becomes overdraw onto tiles already blitted: the pixels
     // stay correct, so the sweep still reads zero, and the cost this whole
     // change exists to remove comes back silently.
     canvas.clipRect(uncovered, doAntiAlias: false);
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
diff --git a/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart b/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart
new file mode 100644
index 0000000..6f140d7
--- /dev/null
+++ b/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart
@@ -0,0 +1,224 @@
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
+  const _FallbackArm(this.strip, this.triangles, this.liveDraws);
+
+  /// `TileCache.debugLastStrip`: the rectangle the fallback actually walked.
+  final Rect? strip;
+
+  /// `VerticesDrawSink.frameTriangleCount` for that frame — the quantity
+  /// criterion 8's ratio is built on, and the one `kTriangleBudgetRatio`
+  /// already uses to kill this mutation as a source edit.
+  final int triangles;
+  final int liveDraws;
+
+  @override
+  String toString() => '_FallbackArm(strip: $strip, triangles: $triangles, '
+      'liveDraws: $liveDraws)';
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
+      return _FallbackArm(rig.cache.debugLastStrip,
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
+  testWidgets('the rest bake fires, and debugRestBakeDisabled suppresses it',
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
```
