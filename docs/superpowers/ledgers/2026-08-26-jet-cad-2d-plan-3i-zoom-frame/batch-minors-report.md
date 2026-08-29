# Plan 3i — batch of six deferred Minor findings

Worked directly on `main`, no branch, no worktree, per instruction. All six
findings landed as described below; none required production code changes or
turned out larger than described.

---

## Finding 1 — M12, the skew term `c` is not compared

**File:** `packages/jet_cad_2d_flutter/test/tile_regime_test.dart`

`sameQuantisedCamera` compares all six `Transform2` fields (`a, b, c, d, e,
f`), but every fixture in the file — the `at()` helper and both sides of `'the
skew terms are compared too'` — left `c` at `0`. Deleting `x.c == y.c` from
the comparison therefore killed nothing.

Extended `'the skew terms are compared too'` with a second pair, `c1`/`c2`,
that varies `c` (`0.1` vs `0.2`) while holding every other field fixed:

```dart
    // The other skew term. Every other fixture in this file, including `a`
    // and `b` above, leaves `c` at 0 -- so without a case that varies it,
    // deleting `x.c == y.c` from the comparison kills no test here.
    final c1 = ViewportTransform(
        worldToScreenMatrix: Transform2(1.4, 0, 0.1, -1.4, 10, 20));
    final c2 = ViewportTransform(
        worldToScreenMatrix: Transform2(1.4, 0, 0.2, -1.4, 10, 20));
    expect(sameQuantisedCamera(c1, c2), isFalse);
```

Extending the existing test read better beside what was there than a sibling
test would have — the test's own title already says "terms" (plural) and now
actually covers both.

**Mutation proof (M12):** see the diff, procedure and verbatim red output
under `## M12` at the bottom of
`docs/superpowers/notes/plan-3i-mutation-log.md`, reproduced again below for
this report's own record.

### M12 mutation diff

```diff
--- a/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
+++ b/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
@@ -240,7 +240,6 @@
   return x.a == y.a &&
       x.b == y.b &&
-      x.c == y.c &&
       x.d == y.d &&
       x.e == y.e &&
       x.f == y.f;
```

**Procedure:** copied `tile_cache.dart` aside to the scratchpad
(`/private/tmp/.../scratchpad/tile_cache.dart.orig`), edited the working file
in place to delete `x.c == y.c &&`, ran
`CI=true flutter test test/tile_regime_test.dart`, confirmed red, then
restored the working file **from the scratchpad copy** (never `git
checkout`). Re-ran the same file afterwards and confirmed all 8 tests green
again.

### M12 verbatim red output

```
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (105.0.0 available)
  analyzer 13.3.0 (14.1.0 available)
  code_assets 1.2.1 (2.0.0 available)
  hooks 2.1.0 (2.2.0 available)
  lucide_icons_flutter 3.1.15 (3.1.17 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  objective_c 9.5.0 (9.6.0 available)
  package_config 2.2.0 (3.0.0 available)
  record_use 1.1.0 (1.1.1 available)
  shadcn_ui 0.55.1 (0.56.2 available)
  source_maps 0.10.13 (0.10.14 available)
  test 1.31.1 (1.31.2 available)
  test_api 0.7.12 (0.7.13 available)
  test_core 0.6.18 (0.6.19 available)
  vm_service 15.2.0 (15.3.0 available)
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart
00:00 +0: the same camera compares same
00:00 +1: a scale change compares different
00:00 +2: a translation change compares different
00:00 +3: the skew terms are compared too
00:00 +3 -1: the skew terms are compared too [E]
  Expected: false
    Actual: <true>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_regime_test.dart 43:5                     main.<fn>
  
00:00 +3 -1: a moving frame bakes nothing and walks nothing
00:00 +4 -1: a moving frame with no composite falls through and draws something
00:00 +5 -1: a steadily spun wheel never arms the rest gate
00:00 +6 -1: the gate needs two unchanged frames, not one
00:00 +7 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart: the skew terms are compared too
```

Red as expected. Restored from the scratchpad copy; re-run of the same file
after restoring: `+8: All tests passed!`.

---

## Finding 2 — `settleFromBands` promises more than it asserts

**File:** `packages/jet_cad_2d_flutter/test/support/tile_harness.dart`

The helper's own doc comment says it drives the cache to "a rest whose
**every** visible tile was cut out of a band," but it only asserted
`slices > 0` — satisfied by a single band-cut tile even if the rest of the
viewport backfilled through the ordinary per-tile `_bake` path. A measured run
showed `slices == liveTileCount == 130`.

Changed the assertion to pin equality:

```dart
  expect(slices, equals(h.cache.liveTileCount),
      reason: 'every visible tile must have been cut from a band -- a '
          'partial band bake backfilled through the ordinary per-tile path '
          'must not pass as a band settle');
```

Nothing about what the helper *does* changed — only what it asserts, per the
brief. All call sites (`tile_invalidation_test.dart`,
`tile_slice_differential_test.dart`) still pass with the tightened bound,
which is itself evidence the promise already held in practice; the change
closes the gap between what was promised and what was checked.

---

## Finding 3 — `pumpFilling`'s stale doc comment (uncentred `SizedBox`)

**File:** `packages/jet_cad_2d_flutter/test/tile_settle_test.dart`

The local `pumpFilling` helper built its canvas from a bare `SizedBox` under
`pumpWidget`'s tight constraints — inert, the same defect `pumpTiled` in
`support/tile_harness.dart` had until Task 9's fix (commit `1e2f891`). Without
`Center`, the canvas ran at 800x600 logical (1600x1200 device pixels, ~475
tiles) rather than the 400x300 logical / 130-tile canvas its own doc comment
described, and the "ten is slack" bound in the second test was actually
spent on roughly eight of its ten iterations.

Wrapped the `SizedBox` in `Center`, matching `pumpTiled`, and added a note to
the doc comment recording why:

```dart
  /// **The `Center` is load-bearing, the same finding `pumpTiled` in
  /// `support/tile_harness.dart` documents.** `pumpWidget` hands its child the
  /// surface's *tight* constraints, and a `SizedBox` under tight constraints
  /// is inert -- so without `Center` this canvas ran at 800x600 logical
  /// (1600x1200 device pixels, 475 tiles), not the 400x300 the comment above
  /// describes, and the "ten is slack" bound below was really spent on eight
  /// of its ten iterations.
```

**Is the ten-iteration bound now tight or slack?** Still slack, and by a wide
margin — **not** raised. Verified empirically, not by arithmetic alone:
temporarily instrumented the loop in `'the settle finishes, and then stops
asking'` to print how many of its 10 iterations actually ran (copy-edit-run-
restore discipline, scratchpad copy, never `git checkout`):

```
DEBUG iterations used: 1, liveTileCount=130
```

Only 1 of the 10 available iterations was needed post-fix (the two frames
`pumpFilling` itself pumps already cover 128 of 130 tiles; the loop's first
pump finishes the remaining 2). The bound is not tight; no change to the `10`
constant was made or is warranted. The instrumentation was reverted from the
scratchpad copy before continuing; `git diff --stat` on the file showed no
stray changes afterward.

---

## Finding 4 — annotating mutation-log entries measured at the pre-fix canvas

**File:** `docs/superpowers/notes/plan-3i-mutation-log.md`

Traced which entries were measured against `pumpTiled` **before** Task 9's
`Center` fix (commit `1e2f891`) landed. All three of Task 8's mutants — M2,
M6, M6b — predate that fix and ran on the un-centred 800x600-logical canvas
(1600x1200 device pixels, 25 x 19 = 475 tiles, ~19 one-tile-row bands), not
the 400x300 logical / 130-tile canvas every later entry in the file was
measured against:

- M6's `Expected: <475>` / `Actual: <513>` and its "38 leaked band images (19
  bands ...)" result line are the pre-fix canvas's counts.
- M6b's transcript shows `BoxConstraints(w=800.0, h=600.0)` directly in a
  stack trace — the pre-fix canvas, in the raw Flutter error output.
- M2's assertion is boolean (`true`/`false`), so it carries no misleading
  count, but it too ran on the pre-fix canvas via `pumpTiled`.

Added one clearly-marked note at the top of the file explaining the
discrepancy, why the kills still stand (a canvas size does not decide whether
a band image leaks or a slice loop drops eleven tiles — kills are **not
re-run**), and which raw numbers belong to the old canvas. Added a one-line
pointer at each of the three headers (`## M2`, `## M6`, `## M6b`) so a reader
hitting the entry directly, without reading the top of the file first, still
sees the flag.

---

## Finding 5 — the sum assertion proves less than it could

**File:** `packages/jet_cad_2d_flutter/test/tile_regime_test.dart`

The regression test for "a moving frame with no composite falls through and
draws something" asserted
`blitCount + liveDrawCount + carryOverBlitCount > 0`, satisfied by a single
blitted tile — proving "not gated" rather than "not blank." Tightened to
`liveDrawCount > 0`, the frame actually drawing geometry, per the brief.

```dart
    // `liveDrawCount` alone, not the three-way sum: a single blitted tile
    // satisfies "not gated" without proving the frame drew any geometry, and
    // the live walk is what the ordinary bake-and-live-walk path this guard
    // falls through to actually promises. Confirmed to still die to the
    // guard's own mutation (deleting `_carryOver == null ||`): with no
    // composite and the clause gone, `resting` reads false, the early return
    // fires, and `liveDrawCount` stays 0.
    expect(h.cache.liveDrawCount, greaterThan(0), ...);
```

**Confirmed the tighter form still dies to the original mutation** (deleting
`_carryOver == null ||` from the `resting` guard in `paintFrame`,
`tile_cache.dart` line 922). Copy-edit-run-restore, scratchpad copy, never
`git checkout`:

```diff
     final resting = previous == null ||
-        _carryOver == null ||
         _restGateSteps >= kRestGateFrames;
```

Ran `CI=true flutter test test/tile_regime_test.dart` against the mutated
file. Verbatim (relevant excerpt):

```
Expected: a value greater than <0>
  Actual: <0>
   Which: is not a value greater than <0>
a moving frame with no composite to show must still draw something -- the ordinary
bake-and-live-walk path -- rather than leave the viewport blank for the length of the gesture

...
The test description was:
  a moving frame with no composite falls through and draws something
════════════════════════════════════════════════════════════════════════════════════════════════════
00:00 +5 -1: a moving frame with no composite falls through and draws something [E]
  Test failed. See exception logs above.
```

**Died as expected.** Restored `tile_cache.dart` from the scratchpad copy
afterward; `git diff --stat` on it showed no stray changes.

---

## Finding 6 — a silent viewport mismatch in front of a measurement

**Files:** `apps/dev_harness_2d/lib/measurement_rig.dart`,
`apps/dev_harness_2d/lib/main.dart`

`runTileZoomPhase`'s focal point is priced against the pinned reference
viewport, 1600x1200 logical (spec §5) — `main.dart`'s `_driveR2` hardcodes
`const zoomViewport = Size(1600, 1200)` and passes it in regardless of the
real window. Before this change, the only way an operator could notice a
mismatch was the unrelated `R2 app-run: window=...` print earlier in the same
run's output.

Added `warnIfZoomViewportMismatch(Size real, Size pinned)` to
`measurement_rig.dart` — a warning, not a throw, so a mismatched run still
produces numbers, now clearly labelled as measured at the wrong viewport —
and call it at the zoom phase's own call site in `main.dart`, right before
the arm loop:

```dart
    const zoomViewport = Size(1600, 1200);
    warnIfZoomViewportMismatch(viewport, zoomViewport);
    for (var arm = 0; arm < kZoomArms; arm++) {
```

The warning prints inline with (immediately before) the zoom arm's own
numbers, so it cannot be scrolled past the way the earlier `window=...` print
could.

---

## Gate results

All three gates run per the global constraints (`CI=true`, all files not one,
`--concurrency=1` for `dev_harness_2d`). Full verbatim transcripts follow.

### `packages/jet_cad_2d` — `CI=true dart test && CI=true dart analyze && dart format --output=none --set-exit-if-changed .`

Result: **797 tests passed**, `dart analyze`: **No issues found!**, `dart
format`: **Formatted 113 files (0 changed)**.

### `packages/jet_cad_2d_flutter` — `CI=true flutter test && CI=true flutter analyze && dart format --output=none --set-exit-if-changed .`

Result: **400 tests passed** (`+400: All tests passed!`), `flutter analyze`:
**No issues found!**, `dart format`: **Formatted 71 files (0 changed)**.

### `apps/dev_harness_2d` — `CI=true flutter test --concurrency=1 && CI=true flutter analyze && dart format --output=none --set-exit-if-changed lib test`

Result: **20 tests passed** (`+20: All tests passed!`), `flutter analyze`:
**No issues found!**, `dart format`: **Formatted 6 files (0 changed)**.

Full verbatim transcripts of all three runs are in the Appendix at the end of
this report.

---

## Files touched

- `packages/jet_cad_2d_flutter/test/tile_regime_test.dart` (findings 1, 5)
- `packages/jet_cad_2d_flutter/test/support/tile_harness.dart` (finding 2)
- `packages/jet_cad_2d_flutter/test/tile_settle_test.dart` (finding 3)
- `docs/superpowers/notes/plan-3i-mutation-log.md` (findings 4, 1's M12 entry)
- `apps/dev_harness_2d/lib/measurement_rig.dart` (finding 6)
- `apps/dev_harness_2d/lib/main.dart` (finding 6)

No production code in `packages/jet_cad_2d_flutter/lib/` or
`apps/dev_harness_2d/lib/` other than `measurement_rig.dart`'s new helper
function and its one call site was changed. `packages/jet_cad_2d` was not
touched. `git status` before staging showed no `analysis_options.yaml` and no
`Runner.xcodeproj/project.pbxproj` in the changed-file list.

---

## Appendix: full verbatim gate transcripts

### `packages/jet_cad_2d` full output

```
00:00 +0: loading test/core/tolerance_test.dart
00:00 +0: test/core/tolerance_test.dart: standard tolerance is absolute in document units
00:00 +1: test/core/list_equality_test.dart: compares element-wise
00:00 +2: test/core/handle_test.dart: Handle none is zero and reports isNone
00:00 +3: test/core/handle_test.dart: Handle none is zero and reports isNone
00:00 +4: test/core/handle_test.dart: Handle none is zero and reports isNone
00:00 +5: test/core/handle_test.dart: Handle none is zero and reports isNone
00:00 +6: test/core/handle_test.dart: Handle none is zero and reports isNone
00:00 +7: test/core/handle_test.dart: Handle none is zero and reports isNone
00:00 +8: test/core/handle_test.dart: Handle none is zero and reports isNone
00:00 +9: test/core/handle_test.dart: Handle none is zero and reports isNone
00:00 +10: test/core/handle_test.dart: Handle none is zero and reports isNone
00:00 +11: test/core/tolerance_test.dart: eqAngle uses the angular tolerance, not the linear one
00:00 +12: test/core/handle_test.dart: Handle hex round-trips in the DXF uppercase form
00:00 +13: test/core/diagnostic_test.dart: carries severity, a machine-matchable code, and affected handles
00:00 +14: test/core/diagnostic_test.dart: carries severity, a machine-matchable code, and affected handles
00:00 +15: test/core/diagnostic_test.dart: carries severity, a machine-matchable code, and affected handles
00:00 +16: test/core/diagnostic_test.dart: carries severity, a machine-matchable code, and affected handles
00:00 +17: test/core/diagnostic_test.dart: carries severity, a machine-matchable code, and affected handles
00:00 +18: test/core/diagnostic_test.dart: carries severity, a machine-matchable code, and affected handles
00:00 +19: test/core/diagnostic_test.dart: carries severity, a machine-matchable code, and affected handles
00:00 +20: test/codec/json_codec_test.dart: encodes the schema version and a fixed top-level key order
00:00 +21: test/codec/json_codec_test.dart: encodes the schema version and a fixed top-level key order
00:00 +22: test/codec/json_codec_test.dart: encodes the schema version and a fixed top-level key order
00:00 +23: test/codec/json_codec_test.dart: encodes the schema version and a fixed top-level key order
00:00 +24: test/codec/instance_style_codec_test.dart: an instance round-trips all four style fields at non-default values
00:00 +25: test/codec/instance_style_codec_test.dart: an instance round-trips all four style fields at non-default values
00:00 +26: test/codec/json_codec_test.dart: refuses a schema version from the future
00:00 +27: test/codec/instance_style_codec_test.dart: the four fields are absent-tolerant and default to the no-op values
00:00 +28: test/codec/json_codec_test.dart: refuses a schema version below the first one that ever existed
00:00 +29: test/codec/instance_style_codec_test.dart: two instances differing only in linetypeScale are not equal
00:00 +30: test/codec/json_codec_test.dart: round-trips a document structurally
00:00 +31: test/codec/json_codec_test.dart: round-trips a document structurally
00:00 +32: test/codec/instance_style_codec_test.dart: a v5 document resolves bit-identically under a v6 build every field of the resolved style matches the pre-3f.1 answer
00:00 +33: test/codec/instance_style_codec_test.dart: a v5 document resolves bit-identically under a v6 build every field of the resolved style matches the pre-3f.1 answer
00:00 +34: test/codec/instance_style_codec_test.dart: a v5 document resolves bit-identically under a v6 build every field of the resolved style matches the pre-3f.1 answer
00:00 +35: test/codec/instance_style_codec_test.dart: a v5 document resolves bit-identically under a v6 build every field of the resolved style matches the pre-3f.1 answer
00:00 +36: test/codec/json_codec_test.dart: a stored geomIndex in an older file is discarded, not honoured
00:00 +37: test/codec/instance_style_codec_test.dart: a v5 document resolves bit-identically under a v6 build a v6 build refuses nothing it wrote and everything from the future
00:00 +38: test/codec/json_codec_test.dart: serialization is idempotent, which is the determinism guarantee
00:00 +39: test/codec/json_codec_test.dart: two documents built the same way encode identically
00:00 +40: test/codec/json_codec_test.dart: unknown top-level fields survive a round-trip
00:00 +41: test/codec/json_codec_test.dart: preserved raw data and components survive a round-trip
00:00 +42: test/codec/schema_v3_fixture_test.dart: a version-3 document loads under the version-4 build
00:00 +43: test/codec/schema_v3_fixture_test.dart: a version-3 document loads under the version-4 build
00:00 +44: test/codec/schema_v3_fixture_test.dart: a version-3 document loads under the version-4 build
00:00 +45: test/codec/schema_v3_fixture_test.dart: a version-3 document loads under the version-4 build
00:00 +46: test/codec/schema_v3_fixture_test.dart: a version-3 document loads under the version-4 build
00:00 +47: test/codec/schema_v3_fixture_test.dart: a version-3 document loads under the version-4 build
00:00 +48: test/codec/schema_v3_fixture_test.dart: a version-3 document loads under the version-4 build
00:00 +49: test/codec/schema_v3_fixture_test.dart: a version-3 document loads under the version-4 build
00:00 +50: test/codec/schema_v3_fixture_test.dart: a version-3 document loads under the version-4 build
00:00 +51: test/codec/schema_v3_fixture_test.dart: a version-3 document loads under the version-4 build
00:00 +52: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +53: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +54: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +55: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +56: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +57: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +58: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +59: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +60: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +61: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +62: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +63: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +64: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +65: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +66: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +67: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +68: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +69: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +70: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +71: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +72: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +73: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +74: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +75: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +76: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +77: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +78: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +79: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +80: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +81: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +82: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +83: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +84: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +85: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +86: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +87: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +88: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +89: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +90: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +91: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +92: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +93: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +94: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +95: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +96: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +97: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +98: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +99: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +100: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +101: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +102: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +103: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +104: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +105: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +106: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +107: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +108: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +109: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +110: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +111: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +112: test/invariants/query_allocation_test.dart: (setUpAll)
The Dart VM service is listening on http://127.0.0.1:65134/OrcXiAOskrA=/
00:00 +113: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +114: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +115: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +116: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +117: test/invariants/query_allocation_test.dart: (setUpAll)
The Dart DevTools debugger and profiler is available at: http://127.0.0.1:65134/OrcXiAOskrA=/devtools/?uri=ws://127.0.0.1:65134/OrcXiAOskrA=/ws
00:00 +118: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +119: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +120: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +121: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +122: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +123: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +124: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +125: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +126: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +127: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +128: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +129: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +130: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +131: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +132: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +133: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +134: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +135: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +136: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +137: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +138: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +139: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +140: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +141: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +142: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +143: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +144: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +145: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +146: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +147: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +148: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +149: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +150: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +151: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +152: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +153: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +154: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +155: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +156: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +157: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +158: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +159: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +160: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +161: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +162: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +163: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +164: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +165: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +166: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +167: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +168: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +169: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +170: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +171: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +172: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +173: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +174: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +175: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +176: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +177: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +178: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +179: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +180: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +181: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +182: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +183: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +184: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +185: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +186: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +187: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +188: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +189: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +190: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +191: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +192: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +193: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +194: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +195: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +196: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +197: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +198: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +199: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +200: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +201: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +202: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +203: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +204: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +205: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +206: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +207: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +208: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +209: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +210: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +211: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +212: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +213: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +214: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +215: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +216: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +217: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +218: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +219: test/invariants/query_allocation_test.dart: (setUpAll)
00:00 +219: test/invariants/text_paint_allocation_test.dart: (setUpAll)
00:00 +219: test/document/region_command_test.dart: the fill gets the lower handle, so it draws underneath
00:00 +220: test/document/region_command_test.dart: the fill gets the lower handle, so it draws underneath
00:00 +221: test/document/region_command_test.dart: the fill gets the lower handle, so it draws underneath
00:00 +222: test/document/region_command_test.dart: the fill gets the lower handle, so it draws underneath
00:00 +223: test/document/region_command_test.dart: the fill gets the lower handle, so it draws underneath
00:00 +224: test/document/region_command_test.dart: the fill gets the lower handle, so it draws underneath
00:00 +225: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +226: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +227: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +228: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +229: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +230: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +231: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +232: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +233: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +234: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +235: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +236: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +237: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +238: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +239: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +240: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +241: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +242: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +243: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +244: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +245: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +246: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +247: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +248: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +249: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +250: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +251: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +252: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +253: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +254: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +255: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +256: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +257: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +258: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +259: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +260: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +261: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +262: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +263: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +264: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +265: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +266: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +267: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +268: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +269: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +270: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +271: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +272: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +273: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +274: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +275: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +276: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +277: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +278: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +279: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +280: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +281: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +282: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +283: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +284: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +285: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +286: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +287: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +288: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +289: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +290: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +291: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +292: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +293: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +294: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +295: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +296: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +297: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +298: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +299: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +300: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +301: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +302: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +303: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +304: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +305: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +306: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +307: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +308: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +309: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +310: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +311: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +312: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +313: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +314: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +315: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +316: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +317: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +318: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +319: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +320: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +321: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +322: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +323: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +324: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +325: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +326: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +327: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +328: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +329: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +330: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +331: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +332: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +333: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +334: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +335: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +336: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +337: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +338: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +339: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +340: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +341: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +342: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +343: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +344: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +345: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +346: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +347: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +348: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +349: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +350: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +351: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +352: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +353: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +354: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +355: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +356: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +357: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +358: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +359: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +360: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +361: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +362: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +363: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +364: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:00 +365: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +366: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +367: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +368: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +369: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +370: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +371: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +372: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +373: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +374: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +375: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +376: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +377: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +378: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +379: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +380: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +381: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +382: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +383: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +384: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +385: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +386: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +387: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +388: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +389: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +390: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +391: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +392: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +393: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +394: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +395: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +396: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +397: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +398: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +399: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +400: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +401: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +402: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +403: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +404: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +405: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +406: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +407: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +408: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +409: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +410: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +411: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +412: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +413: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +414: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +415: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +416: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +417: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +418: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +419: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +420: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +421: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +422: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +423: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +424: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +425: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +426: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +427: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +428: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +429: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +430: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +431: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +432: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +433: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +434: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +435: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +436: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +437: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +438: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +439: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +440: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +441: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +442: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +443: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +444: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +445: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +446: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +447: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +448: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +449: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +450: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +451: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +452: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +453: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +454: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +455: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +456: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +457: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +458: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +459: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +460: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +461: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +462: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +463: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +464: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +465: test/invariants/query_allocation_test.dart: forEachInRect does not allocate in steady state
00:01 +466: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +467: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +468: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +469: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +470: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +471: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +472: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +473: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +474: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +475: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +476: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +477: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +478: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +479: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +480: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +481: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +482: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +483: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +484: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +485: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +486: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +487: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +488: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +489: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +490: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +491: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +492: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +493: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +494: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +495: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +496: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +497: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +498: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +499: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +500: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +501: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +502: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +503: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +504: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +505: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +506: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +507: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +508: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +509: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +510: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +511: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +512: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +513: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +514: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +515: test/invariants/text_paint_allocation_test.dart: a text leaf costs a bounded multiple of the residual-path norm
00:01 +516: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +517: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +518: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +519: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +520: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +521: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +522: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +523: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +524: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +525: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +526: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +527: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +528: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +529: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +530: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +531: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +532: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +533: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +534: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +535: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +536: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +537: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +538: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +539: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +540: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +541: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +542: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +543: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +544: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +545: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +546: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +547: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +548: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +549: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +550: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +551: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +552: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +553: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +554: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +555: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +556: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +557: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +558: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +559: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +560: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +561: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +562: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +563: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +564: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +565: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +566: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +567: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +568: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +569: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +570: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +571: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +572: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +573: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +574: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +575: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +576: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +577: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +578: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +579: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +580: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +581: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +582: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +583: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +584: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +585: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +586: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +587: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +588: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +589: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +590: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +591: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +592: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +593: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +594: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +595: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +596: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +597: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +598: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +599: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +600: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +601: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +602: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +603: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +604: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +605: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +606: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +607: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +608: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +609: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +610: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +611: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +612: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +613: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +614: test/invariants/query_allocation_test.dart: forEachInstanceInRect does not allocate in steady state
00:01 +615: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +616: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +617: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +618: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +619: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +620: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +621: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +622: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +623: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +624: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +625: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +626: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +627: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +628: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +629: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +630: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +631: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +632: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +633: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +634: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +635: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +636: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +637: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +638: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +639: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +640: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +641: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +642: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +643: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +644: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +645: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +646: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +647: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +648: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +649: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +650: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +651: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +652: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +653: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +654: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +655: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +656: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +657: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +658: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +659: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +660: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +661: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +662: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +663: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +664: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +665: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +666: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +667: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +668: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +669: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +670: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +671: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +672: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +673: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +674: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +675: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +676: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +677: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +678: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +679: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +680: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +681: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +682: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +683: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +684: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +685: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +686: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +687: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +688: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +689: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +690: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +691: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +692: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +693: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +694: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +695: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +696: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +697: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +698: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +699: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +700: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +701: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +702: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +703: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +704: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +705: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +706: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +707: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +708: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +709: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +710: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +711: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +712: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +713: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +714: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +715: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +716: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +717: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +718: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +719: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +720: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +721: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +722: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +723: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +724: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +725: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +726: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +727: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +728: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +729: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +730: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +731: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +732: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +733: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +734: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +735: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +736: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +737: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +738: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +739: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +740: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +741: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +742: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +743: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +744: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +745: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +746: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +747: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +748: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +749: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +750: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +751: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +752: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +753: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +754: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +755: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +756: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +757: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:01 +758: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +759: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +760: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +761: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +762: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +763: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +764: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +765: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +766: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +767: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +768: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +769: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +770: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +771: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +772: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +773: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +774: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +775: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +776: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +777: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +778: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +779: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +780: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +781: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +782: test/index/packed_rtree_test.dart: search allocates nothing after the first call
00:02 +783: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +784: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +785: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +786: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +787: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +788: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +789: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +790: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +791: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +792: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +793: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +794: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +795: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:03 +796: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:03 +797: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +797: All tests passed!
Analyzing jet_cad_2d...
No issues found!
Formatted 113 files (0 changed) in 0.20 seconds.
```

### `packages/jet_cad_2d_flutter` full output

```
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (105.0.0 available)
  analyzer 13.3.0 (14.1.0 available)
  code_assets 1.2.1 (2.0.0 available)
  hooks 2.1.0 (2.2.0 available)
  lucide_icons_flutter 3.1.15 (3.1.17 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  objective_c 9.5.0 (9.6.0 available)
  package_config 2.2.0 (3.0.0 available)
  record_use 1.1.0 (1.1.1 available)
  shadcn_ui 0.55.1 (0.56.2 available)
  source_maps 0.10.13 (0.10.14 available)
  test 1.31.1 (1.31.2 available)
  test_api 0.7.12 (0.7.13 available)
  test_core 0.6.18 (0.6.19 available)
  vm_service 15.2.0 (15.3.0 available)
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/large_coordinate_test.dart
00:00 +0: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/large_coordinate_test.dart: every residual reaching Canvas is small at 4.5e6
00:00 +1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/large_coordinate_test.dart: every coordinate reaching Canvas is small at 4.5e6
00:00 +2: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/large_coordinate_test.dart: recorded points reproduce world coordinates through the residual
00:00 +3: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/large_coordinate_test.dart: with rebasing disabled, float32 rounding is observable
00:00 +4: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/large_coordinate_test.dart: at the origin the rebase changes nothing measurable
00:00 +5: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 5: a leaf edit invalidates its own tiles and no others
00:00 +6: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 5: a dragged instance drops the tiles it left
00:00 +7: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 5: a dragged group leaves no ghost either
00:00 +8: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 6: a group and an instance nested inside a definition
00:00 +9: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/camera_controller_test.dart: rebaseOriginFor is stable while the camera moves within one grid step
00:00 +10: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 5: the undo of an instance transform invalidates both ends
00:00 +11: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 5: the undo of an instance transform invalidates both ends
00:00 +12: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/camera_controller_test.dart: rebaseOriginFor leaves a residual float32 can carry, where the raw coordinate is already lossy
00:00 +13: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 6: a definition edit drops the generation, and less does not
00:00 +14: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 6: a definition edit drops the generation, and less does not
00:00 +15: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 6: a definition edit drops the generation, and less does not
00:00 +16: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 6: a definition edit drops the generation, and less does not
00:00 +17: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 6: a definition edit drops the generation, and less does not
00:00 +18: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/camera_controller_test.dart: CameraController panBy notifies, so a repaint boundary knows the frame is stale
00:00 +19: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 9: all five change arms, none omitted
00:00 +20: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 9: all five change arms, none omitted
00:00 +21: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 9: all five change arms, none omitted
00:00 +22: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 9: all five change arms, none omitted
00:00 +23: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 9: a load starts a new generation, an edit does not
00:00 +24: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: a segment becomes two triangles a half-width either side of it
00:00 +25: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 5 / gap G6: a stroke reaching into a tile its geometry misses invalidates it
00:00 +26: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart: the residual is baked into the positions, not pushed on the canvas
00:00 +27: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +28: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +29: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +30: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +31: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +32: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +33: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +34: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +35: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +36: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +37: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +38: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +39: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +40: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +41: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +42: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +43: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +44: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +45: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +46: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +47: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +48: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +49: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +50: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +51: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +52: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +53: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +54: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +55: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +56: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +57: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +58: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +59: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +60: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +61: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +62: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +63: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +64: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +65: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +66: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +67: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +68: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +69: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +70: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +71: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +72: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +73: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +74: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +75: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +76: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +77: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +78: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +79: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart: criterion 7: a layer edit repaints and drops the generation
00:00 +80: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_paint_test.dart: the reference walk and the painter agree with text on
00:00 +81: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_paint_test.dart: the reference walk and the painter agree with text on
00:00 +82: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_paint_test.dart: a text entity is drawn through its own style, not through STANDARD
00:00 +83: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_paint_test.dart: the walk and the painter agree about a blank text entity
00:00 +84: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_paint_test.dart: the text corpus is not vacuous
00:00 +85: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_paint_test.dart: drawText: false drops the text ops and leaves the rest of the frame byte-identical
00:01 +86: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/stroke_width_golden_test.dart: paper-space stroke width at three zoom levels
00:01 +87: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/fill_ladder_golden_test.dart: fill ladder rung 1 (RenderBackend.canvas)
00:01 +88: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/fill_ladder_golden_test.dart: fill ladder rung 1 (RenderBackend.canvas)
00:01 +89: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/fill_ladder_golden_test.dart: fill ladder rung 1 (RenderBackend.canvas)
00:01 +90: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/fill_ladder_golden_test.dart: fill ladder rung 1 (RenderBackend.canvas)
00:01 +91: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart: dash ladder rung 1 (RenderBackend.canvas)
00:01 +92: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
00:01 +93: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
00:01 +94: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
00:01 +95: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
00:01 +96: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
00:01 +97: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
00:01 +98: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
00:01 +99: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
00:01 +100: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/fill_ladder_golden_test.dart: fill ladder rung 2 (RenderBackend.canvas)
00:01 +101: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/sink_comparison_test.dart: anisotropic stroke width diverges, and vertices is right
00:01 +102: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart: dash ladder rung 2 (RenderBackend.canvas)
00:01 +103: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_lod_ladder_golden_test.dart: text lod ladder rung 2 (RenderBackend.vertices)
00:01 +104: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_lod_ladder_golden_test.dart: text lod ladder rung 2 (RenderBackend.vertices)
00:01 +105: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.vertices)
00:01 +106: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.vertices)
00:01 +107: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.vertices)
00:01 +108: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart: dash ladder rung 2 (RenderBackend.vertices)
00:01 +109: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_lod_ladder_golden_test.dart: text lod ladder rung 3 (RenderBackend.canvas)
00:01 +110: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/fill_ladder_golden_test.dart: fill ladder rung 3 (RenderBackend.canvas)
00:01 +111: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/fill_ladder_golden_test.dart: fill ladder rung 3 (RenderBackend.canvas)
00:01 +112: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart: dash ladder rung 3 (RenderBackend.canvas)
00:01 +113: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_lod_ladder_golden_test.dart: text lod ladder rung 3 (RenderBackend.vertices)
00:01 +114: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.vertices)
00:01 +115: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.vertices)
00:01 +116: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart: dash ladder rung 3 (RenderBackend.vertices)
00:01 +117: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
00:01 +118: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart: dash ladder rung 4 (RenderBackend.canvas)
00:01 +119: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_rebase_test.dart: an injected rebase origin overrides the one the view span would give
00:01 +120: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.vertices)
00:01 +121: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.vertices)
00:01 +122: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart: dash ladder rung 4 (RenderBackend.vertices)
00:01 +123: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
00:01 +124: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart: dash ladder rung 5 (RenderBackend.canvas)
00:01 +125: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.vertices)
00:02 +126: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.vertices)
00:02 +127: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
00:02 +128: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.vertices)
00:02 +129: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: (tearDownAll)
00:02 +129: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/differential_test.dart: the painter draws a superset of the reference walk, in order
00:02 +130: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/differential_test.dart: the same holds at 4.5e6 with the view over one nested instance
00:02 +131: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/differential_test.dart: the reference draws something, so the comparison is not vacuous
00:02 +132: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/differential_test.dart: the differential fixture is entirely continuous
00:02 +133: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/differential_test.dart: the reference uses no spatial index at all
00:02 +134: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/differential_test.dart: the painter and the reference agree on the nested instance colour
00:02 +135: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/differential_test.dart: the oracle catches a broken painter a dropped op fails
00:02 +136: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/differential_test.dart: the oracle catches a broken painter a reordered pair fails
00:02 +137: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/differential_test.dart: the oracle catches a broken painter a shifted residual fails
00:02 +138: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/viewport_transform_test.dart: round-trips a point at site-plan magnitude in Float64
00:02 +139: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/viewport_transform_test.dart: round-trips a point at site-plan magnitude in Float64
00:02 +140: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_containment_test.dart: no tile bakes geometry from beyond its own rect
00:02 +141: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_containment_test.dart: no tile bakes geometry from beyond its own rect
00:02 +142: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_containment_test.dart: no tile bakes geometry from beyond its own rect
00:02 +143: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_containment_test.dart: no tile bakes geometry from beyond its own rect
00:02 +144: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_containment_test.dart: no tile bakes geometry from beyond its own rect
00:02 +145: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_containment_test.dart: no tile bakes geometry from beyond its own rect
00:02 +146: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_containment_test.dart: no tile bakes geometry from beyond its own rect
00:02 +147: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_containment_test.dart: no tile bakes geometry from beyond its own rect
00:02 +148: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_containment_test.dart: no tile bakes geometry from beyond its own rect
00:02 +149: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_containment_test.dart: no tile bakes geometry from beyond its own rect
00:02 +150: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart: the ceiling holds at every point inside the rest frame
00:02 +151: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart: the ceiling holds at every point inside the rest frame
00:02 +152: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart: the ceiling holds at every point inside the rest frame
00:02 +153: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart: the ceiling holds at every point inside the rest frame
00:02 +154: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_bytes_test.dart: the ceiling holds at every point inside the rest frame
00:02 +155: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart: criterion 12: a pan back to reclaimed tiles draws live, not blank
00:02 +156: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart: criterion 13: allocation is viewport-bounded and the Paint is one
00:02 +157: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart: criterion 13: and the destination count is a live reading, not a zero
00:02 +158: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart: criterion 12: liveBytes counts the composite, not only the tiles
00:02 +159: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart: criterion 12: eviction never reclaims a tile this frame blitted
00:02 +160: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart: criterion 12: a frame at the cap still equals the live frame
00:02 +161: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart: criterion 12: eviction disposes what it reclaims
00:02 +162: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/tile_budget_test.dart: criterion 12: eviction runs with a composite standing, and never takes it
00:02 +163: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/frame_accounting_test.dart: text accounting closes: drawn + culled + skipped is every text leaf
00:02 +164: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/frame_accounting_test.dart: text accounting closes: drawn + culled + skipped is every text leaf
00:02 +165: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_canvas_test.dart: repaints on a camera change without rebuilding
00:02 +166: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_canvas_test.dart: repaints on a camera change without rebuilding
00:02 +167: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_canvas_test.dart: repaints on a camera change without rebuilding
00:03 +168: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +169: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +170: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +171: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +172: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +173: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +174: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +175: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +176: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +177: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +178: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +179: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +180: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +181: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +182: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +183: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +184: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +185: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +186: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +187: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +188: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +189: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +190: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +191: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +192: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +193: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +194: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +195: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +196: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +197: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +198: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +199: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +200: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +201: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: a steady-state frame allocates O(1) per flush, not O(entities)
00:03 +202: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: flush hands drawVertices the same Paint object every time, not a call-site-local one
00:03 +203: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_settle_test.dart: a frame that left tiles unbaked asks for another
00:03 +204: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_settle_test.dart: a frame that left tiles unbaked asks for another
00:03 +204: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart: load-time triangulation cost, recorded
LOAD fills=5000 elapsed=66ms
00:03 +205: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_settle_test.dart: a frame that left tiles unbaked asks for another
00:03 +206: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_settle_test.dart: a frame that left tiles unbaked asks for another
00:03 +206: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/rig/paint_microbench_test.dart: (suite)
  Skip: run explicitly: flutter test --tags rig --run-skipped
00:03 +206 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_settle_test.dart: a frame that left tiles unbaked asks for another
00:03 +207 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_settle_test.dart: the settle finishes, and then stops asking
00:03 +208 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_settle_test.dart: the settle completes in one frame
00:03 +209 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: a first frame bakes up to its budget and draws the rest live
00:03 +210 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_lod_test.dart: text below the threshold is culled and never measured
00:03 +211 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_lod_test.dart: text below the threshold is culled and never measured
00:03 +212 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_lod_test.dart: text below the threshold is culled and never measured
00:03 +213 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_lod_test.dart: text below the threshold is culled and never measured
00:04 +214 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_lod_test.dart: text below the threshold is culled and never measured
00:04 +215 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: the blit Paint is one instance for the life of the cache
00:04 +216 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/fill_render_test.dart: an unfillable boundary is skipped and counted, not handed to a sink
00:04 +217 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/text_lod_test.dart: the same text at the same camera draws once LOD is off
00:04 +218 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: the blit hands drawImageRect the same Paint object every time, not a call-site-local one
00:04 +219 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: the blit hands drawImageRect the same Paint object every time, not a call-site-local one
00:04 +220 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: the blit hands drawImageRect the same Paint object every time, not a call-site-local one
00:04 +221 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: the blit hands drawImageRect the same Paint object every time, not a call-site-local one
00:04 +222 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: the blit hands drawImageRect the same Paint object every time, not a call-site-local one
00:04 +223 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: the blit hands drawImageRect the same Paint object every time, not a call-site-local one
00:04 +224 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: the blit hands drawImageRect the same Paint object every time, not a call-site-local one
00:04 +225 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: the blit hands drawImageRect the same Paint object every time, not a call-site-local one
00:04 +226 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: the blit hands drawImageRect the same Paint object every time, not a call-site-local one
00:04 +227 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: the blit hands drawImageRect the same Paint object every time, not a call-site-local one
00:04 +228 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: the blit hands drawImageRect the same Paint object every time, not a call-site-local one
00:04 +229 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: criterion 1: a warm tiled frame equals the live frame exactly
00:04 +230 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: criterion 1: and it still holds after twenty-three awkward pans
00:04 +231 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: criterion 1: and it still holds after twenty-three awkward pans
00:04 +232 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: criterion 1: and it still holds after twenty-three awkward pans
00:04 +233 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: criterion 1: and it still holds after twenty-three awkward pans
00:04 +234 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: criterion 1: and it still holds after twenty-three awkward pans
00:04 +235 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: criterion 1: and it still holds after twenty-three awkward pans
00:04 +236 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: criterion 1: and it still holds after twenty-three awkward pans
00:04 +237 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: criterion 1: and it still holds after twenty-three awkward pans
00:04 +238 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: criterion 1: and it still holds after twenty-three awkward pans
00:04 +239 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: criterion 1: and it still holds after twenty-three awkward pans
00:04 +240 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: criterion 1: and it still holds after twenty-three awkward pans
00:04 +241 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: criterion 1: and it still holds after twenty-three awkward pans
00:04 +242 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: criterion 1: and it still holds after twenty-three awkward pans
00:04 +243 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: criterion 1: and it still holds after twenty-three awkward pans
00:04 +244 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: criterion 1: and it still holds after twenty-three awkward pans
00:04 +245 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: criterion 1: and it still holds after twenty-three awkward pans
00:04 +246 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart: a moving frame bakes nothing and walks nothing
00:04 +247 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart: a moving frame bakes nothing and walks nothing
00:04 +248 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart: a moving frame bakes nothing and walks nothing
00:04 +249 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart: a moving frame bakes nothing and walks nothing
00:04 +250 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart: a moving frame bakes nothing and walks nothing
00:04 +251 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart: a moving frame bakes nothing and walks nothing
00:04 +252 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart: a moving frame bakes nothing and walks nothing
00:04 +253 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart: a moving frame bakes nothing and walks nothing
00:04 +254 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart: a moving frame bakes nothing and walks nothing
00:04 +255 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart: a moving frame bakes nothing and walks nothing
00:04 +256 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart: a moving frame bakes nothing and walks nothing
00:04 +257 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_regime_test.dart: a moving frame bakes nothing and walks nothing
00:04 +258 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:04 +259 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:04 +260 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:04 +261 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:04 +262 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:04 +263 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:04 +264 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:04 +265 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:04 +266 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:04 +267 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:04 +268 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: with no backend given, the widget resolves the platform default
00:04 +269 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_order_test.dart: leaves and instances interleave by ascending handle
00:04 +270 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_order_test.dart: leaves and instances interleave by ascending handle
00:04 +271 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_order_test.dart: leaves and instances interleave by ascending handle
00:04 +272 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_order_test.dart: leaves and instances interleave by ascending handle
00:04 +273 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_order_test.dart: leaves and instances interleave by ascending handle
00:04 +274 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_order_test.dart: leaves and instances interleave by ascending handle
00:04 +275 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_order_test.dart: leaves and instances interleave by ascending handle
00:04 +276 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: an explicit backend is honoured, not clamped
00:04 +277 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: an explicit backend is honoured, not clamped
00:04 +278 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: an explicit backend is honoured, not clamped
00:04 +279 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: an explicit backend is honoured, not clamped
00:04 +280 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: an explicit backend is honoured, not clamped
00:04 +281 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_order_test.dart: the instance buffer grows past its initial capacity and then stops
00:04 +282 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/render_backend_test.dart: only the resolved backend builds a sink
00:04 +283 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_order_test.dart: painting never issues a SpatialIndex-level query from inside a visit
00:04 +284 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_order_test.dart: painting never issues a SpatialIndex-level query from inside a visit
00:04 +285 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:04 +286 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:04 +287 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:04 +288 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:04 +289 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:04 +290 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:04 +291 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:04 +292 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:04 +293 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:04 +294 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:04 +295 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:04 +296 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:04 +297 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:04 +298 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:04 +299 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart: a solid circle inks its whole centreline, seam included
00:05 +300 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_root_test.dart: the leaf buffer does not grow after warm-up
00:05 +301 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_root_test.dart: the leaf buffer does not grow after warm-up
00:05 +302 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_root_test.dart: the leaf buffer does not grow after warm-up
00:05 +303 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_root_test.dart: the leaf buffer does not grow after warm-up
00:05 +304 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_root_test.dart: the leaf buffer does not grow after warm-up
00:05 +305 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_root_test.dart: the leaf buffer does not grow after warm-up
00:05 +306 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_root_test.dart: the leaf buffer does not grow after warm-up
00:05 +307 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_root_test.dart: the leaf buffer does not grow after warm-up
00:05 +308 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_root_test.dart: the leaf buffer does not grow after warm-up
00:05 +309 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_root_test.dart: the leaf buffer does not grow after warm-up
00:05 +310 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_root_test.dart: the leaf buffer does not grow after warm-up
00:05 +311 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_root_test.dart: the leaf buffer does not grow after warm-up
00:05 +312 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +313 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +314 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +315 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +316 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +317 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +318 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +319 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +320 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +320 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/fill_seam_test.dart: the translucent seam, measured
SEAM interior=656204 over8=0 fraction=0.000% worst=0
00:05 +321 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +322 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +323 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +324 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +325 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +326 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +327 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +328 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +329 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +330 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +331 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +332 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +333 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +334 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +335 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +336 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +337 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +338 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +339 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +340 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +341 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +342 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +343 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +344 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +345 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +346 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +347 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +348 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +349 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +350 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +351 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +352 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +353 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +354 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +355 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +356 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +357 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +358 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +359 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +360 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +361 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +362 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +363 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +364 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +365 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: no depth buffer grows after warm-up
00:05 +366 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: the corpus draws the same picture twice in a row
00:05 +367 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: the corpus draws the same picture twice in a row
00:06 +368 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: the corpus draws the same picture twice in a row
00:06 +369 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: the corpus draws the same picture twice in a row
00:06 +370 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: the corpus draws the same picture twice in a row
00:06 +371 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: the corpus draws the same picture twice in a row
00:06 +372 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draft_painter_recursion_test.dart: the corpus draws the same picture twice in a row
00:06 +373 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_join_test.dart: an open polyline gets no join between its ends
00:06 +374 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_join_test.dart: a zero-length step is skipped and the join spans it
00:06 +375 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_join_test.dart: joins are emitted under the residual, not in local space
00:06 +376 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_join_test.dart: a flattened curve joins its chords
00:06 +377 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_join_test.dart: a circle joins at its seam, so there is no notch at the start angle
00:06 +378 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_join_test.dart: the seam is one join, not two, and not a cap
00:06 +379 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_join_test.dart: an open run of the same points has two corners, not four
00:06 +380 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_join_test.dart: a closed run of two points closes without a phantom seam
00:06 +381 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_differential_test.dart: the sink inks every primitive the reference walk draws
00:06 +382 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: a settled generation is identical to a live frame
00:06 +383 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: a settled generation is identical to a live frame
00:06 +384 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: a settled generation is identical to a live frame
00:06 +385 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: a settled generation is identical to a live frame
00:06 +386 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: a settled generation is identical to a live frame
00:06 +387 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: a settled generation is identical to a live frame
00:06 +388 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: a settled generation is identical to a live frame
00:06 +389 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: a settled generation is identical to a live frame
00:06 +390 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: a settled generation is identical to a live frame
00:06 +391 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: a settled generation is identical to a live frame
00:06 +392 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: a settled generation is identical to a live frame
00:06 +393 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: a settled generation is identical to a live frame
00:06 +394 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: a settled generation is identical to a live frame
00:06 +395 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: a settled generation is identical to a live frame
00:06 +396 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: and at a camera on a power-of-two rebase boundary
00:06 +397 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: and stays identical after a pan smaller than one tile
00:06 +398 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: and when a pan lands between the scale change and the bake
00:06 +399 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: tile boundaries carry no difference of their own
00:06 +400 ~1: All tests passed!
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (105.0.0 available)
  analyzer 13.3.0 (14.1.0 available)
  code_assets 1.2.1 (2.0.0 available)
  hooks 2.1.0 (2.2.0 available)
  lucide_icons_flutter 3.1.15 (3.1.17 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  objective_c 9.5.0 (9.6.0 available)
  package_config 2.2.0 (3.0.0 available)
  record_use 1.1.0 (1.1.1 available)
  shadcn_ui 0.55.1 (0.56.2 available)
  source_maps 0.10.13 (0.10.14 available)
  test 1.31.1 (1.31.2 available)
  test_api 0.7.12 (0.7.13 available)
  test_core 0.6.18 (0.6.19 available)
  vm_service 15.2.0 (15.3.0 available)
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Analyzing jet_cad_2d_flutter...                                 
No issues found! (ran in 1.2s)
Formatted 71 files (0 changed) in 0.13 seconds.
```

### `apps/dev_harness_2d` full output

```
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (105.0.0 available)
  analyzer 13.3.0 (14.1.0 available)
  code_assets 1.2.1 (2.0.0 available)
  hooks 2.1.0 (2.2.0 available)
  lucide_icons_flutter 3.1.15 (3.1.17 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  objective_c 9.5.0 (9.6.0 available)
  package_config 2.2.0 (3.0.0 available)
  record_use 1.1.0 (1.1.1 available)
  shadcn_ui 0.55.1 (0.56.2 available)
  source_maps 0.10.13 (0.10.14 available)
  test 1.31.1 (1.31.2 available)
  test_api 0.7.12 (0.7.13 available)
  test_core 0.6.18 (0.6.19 available)
  vm_service 15.2.0 (15.3.0 available)
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/seam_corpus_test.dart
00:00 +0: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/seam_corpus_test.dart: the fan carries at least eight distinct slopes
00:00 +1: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/seam_corpus_test.dart: at least four of those slopes are shallow
00:00 +2: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/seam_corpus_test.dart: the corpus spans a real area on both axes
00:00 +3: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/seam_corpus_test.dart: the corpus sits far from the origin
00:00 +4: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/seam_corpus_test.dart: curves are present alongside the straight lines
00:00 +5: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/seam_corpus_test.dart: two lineweight regimes are on screen at once
00:00 +6: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/seam_corpus_test.dart: the corpus stays small enough to read by eye
00:00 +7: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/seam_corpus_test.dart: the corpus paints
00:00 +8: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/seam_corpus_test.dart: the corpus carries a measurer DraftCanvas will accept
00:00 +9: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/seam_corpus_test.dart: CORPUS accepts its two values and rejects anything else
00:00 +10: loading /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/pointer_zoom_test.dart
00:00 +10: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/pointer_zoom_test.dart: trackpad two-finger scroll up zooms in
00:02 +11: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/pointer_zoom_test.dart: trackpad two-finger scroll down zooms out
00:04 +12: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/pointer_zoom_test.dart: pinch open zooms in by the reported scale
00:06 +13: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/pointer_zoom_test.dart: pinch closed zooms out
00:07 +14: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/pointer_zoom_test.dart: a gesture reporting cumulative values does not compound
00:09 +15: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/pointer_zoom_test.dart: pan and scale on one event combine
00:10 +16: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/pointer_zoom_test.dart: a second gesture starts from a clean factor
00:12 +17: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/pointer_zoom_test.dart: mouse wheel still zooms through the signal path
00:13 +18: loading /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/zoom_script_test.dart
00:14 +18: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/zoom_script_test.dart: the pinned script is 40 in, 40 out, at 1.03
00:14 +19: /Users/ahmeturel/Projects/oss/jet-cad/apps/dev_harness_2d/test/zoom_script_test.dart: the focal point is off-centre
00:14 +20: All tests passed!
Resolving dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`...
Downloading packages...
  _fe_analyzer_shared 103.0.0 (105.0.0 available)
  analyzer 13.3.0 (14.1.0 available)
  code_assets 1.2.1 (2.0.0 available)
  hooks 2.1.0 (2.2.0 available)
  lucide_icons_flutter 3.1.15 (3.1.17 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  objective_c 9.5.0 (9.6.0 available)
  package_config 2.2.0 (3.0.0 available)
  record_use 1.1.0 (1.1.1 available)
  shadcn_ui 0.55.1 (0.56.2 available)
  source_maps 0.10.13 (0.10.14 available)
  test 1.31.1 (1.31.2 available)
  test_api 0.7.12 (0.7.13 available)
  test_core 0.6.18 (0.6.19 available)
  vm_service 15.2.0 (15.3.0 available)
Got dependencies in `/Users/ahmeturel/Projects/oss/jet-cad`!
15 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Analyzing dev_harness_2d...                                     
No issues found! (ran in 1.0s)
Formatted 6 files (0 changed) in 0.01 seconds.
```
