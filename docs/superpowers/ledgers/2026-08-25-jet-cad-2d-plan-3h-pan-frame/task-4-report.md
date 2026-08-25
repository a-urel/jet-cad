# Task 4 report: `stripFor`, the arithmetic half

All commands run from `/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter`.

## `git status --porcelain` before staging (repo root, before any edits)

```
(clean)
```

Confirmed clean at the start of the task. After Step 6's edits, before staging, the repo root reported:

```
 M packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
 M packages/jet_cad_2d_flutter/test/tile_cache_test.dart
```

Exactly the two files the brief names, nothing else touched (no `analysis_options.yaml` rewrite staged).

## Step 1: tests added

Added the `stripFor` group verbatim from the brief to `test/tile_cache_test.dart`, inside `main()`, immediately before its closing `}` (after the `accepted gap` group). `dart:ui` (`Rect`, `Size`, `Offset`) and the package barrel (`package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart`) were already imported, so no import changes were needed there.

## Step 2: run and watch them fail — verbatim output

```
$ CI=true flutter test test/tile_cache_test.dart --plain-name "stripFor"
...
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart
test/tile_cache_test.dart:950:14: Error: Method not found: 'stripFor'.
      expect(stripFor(const Rect.fromLTRB(100, 80, 200, 180), viewport),
             ^^^^^^^^
test/tile_cache_test.dart:959:14: Error: Method not found: 'stripFor'.
      expect(stripFor(Offset.zero & viewport, viewport), Offset.zero & viewport);
             ^^^^^^^^
test/tile_cache_test.dart:966:14: Error: Method not found: 'stripFor'.
      expect(stripFor(const Rect.fromLTRB(0, 0, 40, 300), viewport),
             ^^^^^^^^
test/tile_cache_test.dart:971:14: Error: Method not found: 'stripFor'.
      expect(stripFor(const Rect.fromLTRB(360, 260, 400, 300), viewport),
             ^^^^^^^^
00:00 +0 -1: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart [E]
  Failed to load "/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart":
  Compilation failed for testPath=/Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: test/tile_cache_test.dart:950:14: Error: Method not found: 'stripFor'.
        expect(stripFor(const Rect.fromLTRB(100, 80, 200, 180), viewport),
               ^^^^^^^^
  test/tile_cache_test.dart:959:14: Error: Method not found: 'stripFor'.
        expect(stripFor(Offset.zero & viewport, viewport), Offset.zero & viewport);
               ^^^^^^^^
  test/tile_cache_test.dart:966:14: Error: Method not found: 'stripFor'.
        expect(stripFor(const Rect.fromLTRB(0, 0, 40, 300), viewport),
               ^^^^^^^^
  test/tile_cache_test.dart:971:14: Error: Method not found: 'stripFor'.
        expect(stripFor(const Rect.fromLTRB(360, 260, 400, 300), viewport),
               ^^^^^^^^
  .
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart
```

A compile error naming `stripFor`, exactly as predicted.

## Step 3: the function

Added `import 'dart:math' as math;` above `dart:typed_data` (keeping the existing `dart:` group sorted), and added `stripFor` in `lib/src/tile_cache.dart` immediately after `const double kTileSlack = kScreenClipInflate;`, verbatim from the brief:

```dart
Rect stripFor(Rect uncovered, Size viewport) => Rect.fromLTRB(
      math.max(0.0, uncovered.left - kTileSlack),
      math.max(0.0, uncovered.top - kTileSlack),
      math.min(viewport.width, uncovered.right + kTileSlack),
      math.min(viewport.height, uncovered.bottom + kTileSlack),
    );
```

## Step 4: run and watch them pass — verbatim output

```
$ CI=true flutter test test/tile_cache_test.dart --plain-name "stripFor"
...
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart
00:00 +0: stripFor pads an interior rect on every side
00:00 +1: stripFor clamps to the viewport rather than growing past it
00:00 +2: stripFor clamps one edge at a time
00:00 +3: stripFor a strip touching the bottom-right clamps there and pads inward
00:00 +4: All tests passed!
```

## Step 5: mutant M1

```
$ cp lib/src/tile_cache.dart /tmp/tile_cache.m1
```

Edit applied to `stripFor` (drop the clamp):

```diff
 Rect stripFor(Rect uncovered, Size viewport) => Rect.fromLTRB(
-      math.max(0.0, uncovered.left - kTileSlack),
-      math.max(0.0, uncovered.top - kTileSlack),
-      math.min(viewport.width, uncovered.right + kTileSlack),
-      math.min(viewport.height, uncovered.bottom + kTileSlack),
+      uncovered.left - kTileSlack,
+      uncovered.top - kTileSlack,
+      uncovered.right + kTileSlack,
+      uncovered.bottom + kTileSlack,
     );
```

Run:

```
$ CI=true flutter test test/tile_cache_test.dart --plain-name "stripFor"
...
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart
00:00 +0: stripFor pads an interior rect on every side
00:00 +1: stripFor clamps to the viewport rather than growing past it
00:00 +1 -1: stripFor clamps to the viewport rather than growing past it [E]
  Expected: Rect:<Rect.fromLTRB(0.0, 0.0, 400.0, 300.0)>
    Actual: Rect:<Rect.fromLTRB(-32.0, -32.0, 432.0, 332.0)>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_cache_test.dart 959:7                     main.<fn>.<fn>

00:00 +1 -1: stripFor clamps one edge at a time
00:00 +1 -2: stripFor clamps one edge at a time [E]
  Expected: Rect:<Rect.fromLTRB(0.0, 0.0, 72.0, 300.0)>
    Actual: Rect:<Rect.fromLTRB(-32.0, -32.0, 72.0, 332.0)>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_cache_test.dart 966:7                     main.<fn>.<fn>

00:00 +1 -2: stripFor a strip touching the bottom-right clamps there and pads inward
00:00 +1 -3: stripFor a strip touching the bottom-right clamps there and pads inward [E]
  Expected: Rect:<Rect.fromLTRB(328.0, 228.0, 400.0, 300.0)>
    Actual: Rect:<Rect.fromLTRB(328.0, 228.0, 432.0, 332.0)>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_cache_test.dart 971:7                     main.<fn>.<fn>

00:00 +1 -3: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: stripFor a strip touching the bottom-right clamps there and pads inward
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: stripFor clamps one edge at a time
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart: stripFor clamps to the viewport rather than growing past it
```

**Verified, not assumed: exactly three of the four cases reddened** — `clamps to the viewport rather than growing past it`, `clamps one edge at a time`, and `a strip touching the bottom-right clamps there and pads inward`. `pads an interior rect on every side` stayed green, as predicted (it never touches an edge close enough for the clamp to bind). This matches the brief's prediction of "three of the four" exactly — no discrepancy to flag this time.

Note in passing: the mutant also drops the only use of `dart:math`'s `min`/`max`, leaving `import 'dart:math' as math;` genuinely unused in the mutated file. `flutter test` still ran and reported the above (unused_import is enforced by `flutter analyze`, not by the test compiler), so this did not interfere with the mutation result.

Restore:

```
$ cp /tmp/tile_cache.m1 lib/src/tile_cache.dart
$ CI=true flutter test test/tile_cache_test.dart --plain-name "stripFor"
...
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_cache_test.dart
00:00 +0: stripFor pads an interior rect on every side
00:00 +1: stripFor clamps to the viewport rather than growing past it
00:00 +2: stripFor clamps one edge at a time
00:00 +3: stripFor a strip touching the bottom-right clamps there and pads inward
00:00 +4: All tests passed!
```

Confirmed byte-identical to the pre-mutation copy: `diff /tmp/tile_cache.m1 lib/src/tile_cache.dart` produced no output.

## Step 6: full suite, analyze, format

### `CI=true flutter test` (whole package)

```
...
00:06 +370 ~1: All tests passed!
```

370 tests passed, 1 skipped (the `rig`-tagged suite, which is deliberately skipped in the normal run per `dart_test.yaml` — "run explicitly: flutter test --tags rig --run-skipped").

**A verification note, since the compact/expanded text reporter is driven by several concurrent test-file isolates writing to one stdout stream:** grepping the captured transcript for `stripFor` or its individual case descriptions (`interior rect`, `clamps to the viewport`, `clamps one edge`, `touching the bottom-right`) found none, while several unrelated lines appeared to repeat verbatim (e.g. `criterion 1: a settled frame equals the live frame after a zoom` printed six times). Rather than take "All tests passed!" on faith given that oddity, I reran with `CI=true flutter test --reporter json` and parsed the event stream directly:

- 415 `testStart`/`testDone` pairs, all with `result: success`, `done: {success: true}`.
- The 4 `stripFor` tests are present by exact name in that stream, each `success`:
  - `stripFor pads an interior rect on every side` → success
  - `stripFor clamps to the viewport rather than growing past it` → success
  - `stripFor clamps one edge at a time` → success
  - `stripFor a strip touching the bottom-right clamps there and pads inward` → success

Conclusion: the human-readable reporter's dropped/duplicated lines are a cosmetic artifact of unsynchronized concurrent-isolate writes to one piped stdout (confirmed independently by running `test/tile_cache_test.dart` alone, where all 30 of its tests — including the 4 new ones — print cleanly with no repeats: `00:00 +29: All tests passed!` after `stripFor a strip touching the bottom-right clamps there and pads inward`). The JSON reporter is authoritative here and shows a clean, complete, all-green run with no regressions.

### `flutter analyze`

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)
```

### `dart format --output=none --set-exit-if-changed .`

First run (before fixing formatting introduced by the pasted test group) exited 1:

```
Changed test/tile_cache_test.dart
Formatted 64 files (1 changed) in 0.12 seconds.
```

Ran `dart format test/tile_cache_test.dart` to apply the required reflow (wrapped the `clamps to the viewport` line, which the brief's snippet had unwrapped). Re-ran the check:

```
Formatted 64 files (0 changed) in 0.12 seconds.
```

Exit code 0. Re-ran the full suite and analyze after the formatting fix to confirm nothing regressed:

```
00:06 +370 ~1: All tests passed!
```

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.1s)
```

## Commit

Staged exactly the two files the brief names:

```
$ git status --porcelain
 M packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
 M packages/jet_cad_2d_flutter/test/tile_cache_test.dart
$ git add packages/jet_cad_2d_flutter/lib/src/tile_cache.dart packages/jet_cad_2d_flutter/test/tile_cache_test.dart
```

Committed with the message given in the brief verbatim. Resulting commit: `18cdf90b4732125300ce4393012477a1cc8168df`.

```
commit 18cdf90b4732125300ce4393012477a1cc8168df
    feat: stripFor, the fallback walk's padded and clamped rectangle

    Pure, because the clamp has no other witness: the fallback's pixels are
    identical clamped or not and only its cost moves. Mutant M1 -- drop the clamp
    -- reddens three of the four cases.

    The clamp was found by measuring. uncovered is a bounding rectangle built with
    expandToInclude, so an L-shaped uncovered set bounds to the whole frame, and
    padding that asks for 464 x 364 where the untiled path asks for 400 x 300. An
    unclamped arm doubled the vertex buffer to 384 MiB with every other counter
    unchanged.

 .../jet_cad_2d_flutter/lib/src/tile_cache.dart     | 29 ++++++++++++++++++
 .../jet_cad_2d_flutter/test/tile_cache_test.dart   | 34 ++++++++++++++++++++++
 2 files changed, 63 insertions(+)
```

## Summary

- Mutation prediction verified, not assumed: M1 reddens exactly **3 of 4** cases, matching the brief.
- No other file changed; `analysis_options.yaml` never touched or staged.
- `stripFor` adds no field to `TileCache` — top-level pure function only, as required.
- `paintFrame` was not touched; this task lands only the arithmetic and its tests, per the brief's explicit scope.
