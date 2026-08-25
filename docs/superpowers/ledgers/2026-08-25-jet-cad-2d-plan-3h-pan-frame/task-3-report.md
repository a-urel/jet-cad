# Task 3 report: the fallback sweep, gating today's code

Status: complete. All six steps executed in order; the controller amendment
(Step 3 replacement) was followed verbatim. One deviation from the brief's
literal Step 1 text was required to keep `flutter analyze` green — recorded
below in its own section, per Warning 2 ("verify, do not assume").

## Step 2: verbatim first-failure output

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_fallback_test.dart
...
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart
test/tile_fallback_test.dart:47:27: Error: Method not found: 'sweepFallbackAgreement'.
    final reports = await sweepFallbackAgreement(
                          ^^^^^^^^^^^^^^^^^^^^^^
test/tile_fallback_test.dart:67:27: Error: Method not found: 'sweepFallbackAgreement'.
    final reports = await sweepFallbackAgreement(
                          ^^^^^^^^^^^^^^^^^^^^^^
00:00 +0 -1: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart [E]
  Failed to load "/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart":
  Compilation failed for testPath=/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart: test/tile_fallback_test.dart:47:27: Error: Method not found: 'sweepFallbackAgreement'.
      final reports = await sweepFallbackAgreement(
                            ^^^^^^^^^^^^^^^^^^^^^^
  test/tile_fallback_test.dart:67:27: Error: Method not found: 'sweepFallbackAgreement'.
      final reports = await sweepFallbackAgreement(
                            ^^^^^^^^^^^^^^^^^^^^^^
  .
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart
```

Matches the brief's expectation exactly: a compile error naming
`sweepFallbackAgreement` as undefined.

## Exact edits to `tile_cache.dart`

Per the controller amendment, not the plan's original Step 3 text. Diff:

```diff
@@ -644,6 +644,24 @@ class TileCache {
           if (_contains(entry.value, handle.value)) entry.key
       ];
 
+  /// The rectangle the fallback owes on the most recent frame -- `uncovered`
+  /// padded and clamped by [stripFor] -- or `null` if no fallback ran.
+  /// Test-only, and **read-only**.
+  ///
+  /// Read from the shipped `paintFrame` rather than recomputed by a test, and
+  /// that is the whole point of it. Plan 3g's rig reimplemented the bake
+  /// geometry in `_probeBake` instead of calling `_bake`, so its overdraw
+  /// column described the reimplementation and not the code that ships. A
+  /// sweep that derived this rectangle from [TileGrid] would repeat that.
+  ///
+  /// **A getter, not a mutable field.** `TileCache` already carries two
+  /// mutable test-only fields and the standing bar is that a third triggers
+  /// revisiting the design; `tilesHolding` is the precedent for reading state
+  /// out without adding a way to write it.
+  Rect? get debugLastStrip => _lastStrip;
+
+  Rect? _lastStrip;
+
   /// The blit `Paint`'s identity, for criterion 13.
   ///
   /// Exposed the way `VerticesDrawSink.debugPaint` is, and for the same
@@ -704,6 +722,7 @@ class TileCache {
     // Before anything reads it, so no tile can be carrying this frame's
     // ordinal before this frame blits it. `_makeRoomForOneTile` rests on that.
     _frameSerial++;
+    _lastStrip = null;
 
     final quantised = quantiseCamera(camera, devicePixelRatio);
     // The viewport reaches `_gridFor` because retiring a generation is now a
@@ -807,6 +826,7 @@ class TileCache {
     // replace. Clipped, so the covered tiles keep the pixels they just blitted.
     canvas.save();
     canvas.clipRect(uncovered, doAntiAlias: false);
+    _lastStrip = stripFor(uncovered, viewport);
     _drawInto(
         canvas, viewport, quantised, painter, sink, vertices, origin, null);
     canvas.restore();
```

The doc comment's first line reads "The rectangle the fallback owes ... --
`uncovered` padded and clamped by [stripFor] -- or `null` if no fallback ran"
per the amendment's required wording (not the plan's original "walked").
`_drawInto` still receives `viewport` and `quantised` unchanged; no
`canvas.translate` was added. `_lastStrip` is the sole new field, private,
written only from `paintFrame`, read only through the getter — no setter
exists.

## Deviation from the brief's literal Step 1 text (Warning 2)

The brief's Step 1 code block opens with `import 'dart:ui';` before
`package:flutter_test/flutter_test.dart`. With that import present, `flutter
analyze` reported:

```
info • The import of 'dart:ui' is unnecessary because all of the used elements
are also provided by the import of 'package:flutter_test/flutter_test.dart'.
Try removing the import directive • test/tile_fallback_test.dart:12:8 •
unnecessary_import

1 issue found.
```

`flutter analyze` exits `1` on this info-level issue in this workspace (verified:
`flutter analyze` on the untouched baseline, via `git stash -u`, reports "No
issues found!" with exit `0`; restoring the change reproduces the single
`unnecessary_import` issue). The file's only use of a `dart:ui` symbol is
`Offset`, which `package:flutter_test/flutter_test.dart` already provides
transitively, so the import is redundant under this analyzer's rules — this is
a fact about the tree today, not a prediction the brief got wrong on its own
terms; the brief just didn't run analyze against this exact file's symbol set.
Per "every task ends green" and the "verify, do not assume" instruction, I
removed the `import 'dart:ui';` line from `test/tile_fallback_test.dart`
(nothing else in the file changed) rather than leave analyze red. This does
not touch the brief's explicit `jet_cad_2d_flutter`-import prohibition, which
is about a different symbol set (`unused_import`, an error) and stands as
written — the shipped file has neither import.

No other deviations. `dart format` additionally reflowed one line inside
`measureFallbackAgreement`'s `TileRig(...)` construction in
`tile_comparison.dart` (wrapped onto one 80-column line rather than three) —
a formatter-driven whitespace change, not a hand edit, applied by running
`dart format` per Step 6's own command.

## Step 5: pass output, both tests

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_fallback_test.dart
...
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart
00:00 +0: criterion 2 and 2c: a partly baked frame equals the live frame
00:00 +1: criterion 2b: the near-axis arm stays inside the tiled path's bound
00:00 +2: All tests passed!
```

Both tests passed on the first run against today's (unnarrowed) fallback code.
No offset from `kFallbackOffsets` needed substitution — every sample's
`debugLastStrip` was strictly interior to the 400x300 viewport (see figures
below), so criterion 2c's `strip != viewport` held everywhere.

## Per-offset figures

Captured with a throwaway instrumented copy of the sweep
(`test/tile_fallback_debug_dump_test.dart`, written only to surface these
numbers for this report, then deleted — it is not part of the deliverable and
is not staged). It called `measureTiledAgreement` and printed
`bakeCount`/`blitCount`/`liveDrawCount`/`debugLastStrip`/`InkReport` for each
offset, under the same rig setup `measureFallbackAgreement` uses (cover once,
reset counters, `bakeBudgetDevicePixels = 64*64`, pan, measure). Kept as one
run's real transcript, not recomputed by hand:

### `fillingGrid` (criterion 2 / 2c fixture)

| offset | bake | blit | live | strip | InkReport |
|---|---|---|---|---|---|
| (37, 0) | 1 | 121 | 1 | `Rect.fromLTRB(0.0, 0.0, 69.0, 300.0)` | live: 38886, tiled: 38886, stray: 0, uncovered: 0, differing: 0 |
| (53, 0) | 1 | 111 | 1 | `Rect.fromLTRB(0.0, 0.0, 85.0, 300.0)` | live: 36906, tiled: 36906, stray: 0, uncovered: 0, differing: 0 |
| (71, 0) | 1 | 111 | 1 | `Rect.fromLTRB(0.0, 0.0, 103.0, 300.0)` | live: 35970, tiled: 35970, stray: 0, uncovered: 0, differing: 0 |
| (0, 37) | 1 | 118 | 1 | `Rect.fromLTRB(0.0, 0.0, 400.0, 69.0)` | live: 38208, tiled: 38208, stray: 0, uncovered: 0, differing: 0 |
| (0, 53) | 1 | 105 | 1 | `Rect.fromLTRB(0.0, 0.0, 400.0, 85.0)` | live: 37056, tiled: 37056, stray: 0, uncovered: 0, differing: 0 |
| (0, 71) | 1 | 105 | 1 | `Rect.fromLTRB(0.0, 0.0, 400.0, 103.0)` | live: 34232, tiled: 34232, stray: 0, uncovered: 0, differing: 0 |
| (-41, 0) | 1 | 121 | 1 | `Rect.fromLTRB(343.0, 0.0, 400.0, 300.0)` | live: 37608, tiled: 37608, stray: 0, uncovered: 0, differing: 0 |
| (0, -41) | 1 | 118 | 1 | `Rect.fromLTRB(0.0, 247.0, 400.0, 300.0)` | live: 37668, tiled: 37668, stray: 0, uncovered: 0, differing: 0 |

Every strip is strictly interior to `Rect.fromLTRB(0, 0, 400, 300)` (the full
viewport at `kTileViewport = Size(400, 300)`), and every `InkReport` is exact:
0 stray, 0 uncovered, 0 differing.

### `nearAxisDiagonals` (criterion 2b fixture)

| offset | bake | blit | live | strip | InkReport |
|---|---|---|---|---|---|
| (37, 0) | 1 | 121 | 1 | `Rect.fromLTRB(0.0, 0.0, 69.0, 300.0)` | live: 10703, tiled: 10707, stray: 29, uncovered: 25, differing: 54 |
| (53, 0) | 1 | 111 | 1 | `Rect.fromLTRB(0.0, 0.0, 85.0, 300.0)` | live: 10703, tiled: 10707, stray: 29, uncovered: 25, differing: 54 |
| (71, 0) | 1 | 111 | 1 | `Rect.fromLTRB(0.0, 0.0, 103.0, 300.0)` | live: 10703, tiled: 10707, stray: 29, uncovered: 25, differing: 54 |
| (0, 37) | 1 | 118 | 1 | `Rect.fromLTRB(0.0, 0.0, 400.0, 69.0)` | live: 10212, tiled: 10214, stray: 19, uncovered: 17, differing: 36 |
| (0, 53) | 1 | 105 | 1 | `Rect.fromLTRB(0.0, 0.0, 400.0, 85.0)` | live: 9805, tiled: 9807, stray: 19, uncovered: 17, differing: 36 |
| (0, 71) | 1 | 105 | 1 | `Rect.fromLTRB(0.0, 0.0, 400.0, 103.0)` | live: 8928, tiled: 8930, stray: 19, uncovered: 17, differing: 36 |
| (-41, 0) | 1 | 121 | 1 | `Rect.fromLTRB(343.0, 0.0, 400.0, 300.0)` | live: 8685, tiled: 8687, stray: 19, uncovered: 17, differing: 36 |
| (0, -41) | 1 | 118 | 1 | `Rect.fromLTRB(0.0, 247.0, 400.0, 300.0)` | live: 10342, tiled: 10344, stray: 19, uncovered: 17, differing: 36 |

`differingPixels` is 54 or 36 at every offset — both `<= 60`, and
`differingPixels / liveInk` is at most `54/10703 ≈ 0.00505 < 0.01` — both
clauses of criterion 2b's assertion hold at every offset with headroom. The
`(0, -41)` sample's `differing: 36` against `liveInk: 10342` reproduces the
brief's cited reference figure (36 of 10342, 0.348%) exactly, confirming this
sweep measures the same accepted gap `tile_cache_test.dart` already gates.

### Substitutions

None. All eight offsets in `kFallbackOffsets` produced a strip strictly
interior to the viewport and satisfied both tests as specified in the brief,
verbatim, with no offset swapped.

## Step 6: full suite / analyze / format

Full suite (`CI=true flutter test`), tail:

```
00:05 +358 ~1: .../vertices_differential_test.dart: the sink inks every primitive the reference walk draws
00:05 +359 ~1: .../lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
...
00:05 +372 ~1: All tests passed!
```

372 tests passed, 0 failed. The `~1` is a single pre-existing skip tagged
`rig` (`Skip: run explicitly: flutter test --tags rig --run-skipped`),
confirmed present identically on the untouched baseline (see below) — not
introduced by this task.

Combined gate, run exactly as Step 6 specifies:

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
...
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)
Formatted 65 files (0 changed) in 0.13 seconds.
$ echo $?
0
```

Baseline sanity check (`git stash -u` back to the last commit, `18cdf90`):

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.9s)
```

confirming the one `unnecessary_import` issue seen mid-task was introduced by
this task's own new file and not pre-existing, which is why it was fixed
rather than reported as a pre-existing condition.

## `git status --porcelain` before staging

```
 M packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
 M packages/jet_cad_2d_flutter/test/support/tile_comparison.dart
?? packages/jet_cad_2d_flutter/test/tile_fallback_test.dart
```

Exactly the three files the brief names. No `analysis_options.yaml` changes
present. Staged and committed as:

```
git add lib/src/tile_cache.dart test/support/tile_comparison.dart test/tile_fallback_test.dart
git commit -m "test: a sweep that executes the live fallback, which no pixel gate ever has ..."
```

(commit message body as given in the brief's Step 6, verbatim).
