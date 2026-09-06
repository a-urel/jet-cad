# Task 4 report: Criterion 10 — the fallback, exactly once, observably

## What was done

Wrote `packages/jet_cad_2d_flutter/test/gpu/draft_canvas_fallback_test.dart`
exactly as given in the brief's Step 1, with two mechanical deviations both
called for by the brief's own context notes:

- Dropped `import 'dart:ui';` and `import 'package:flutter/foundation.dart';`
  — `flutter analyze` reported both as `unnecessary_import` (everything they
  provide — `Size`, `FlutterError` — is already re-exported by
  `package:flutter/widgets.dart`, which the file also imports), and the task
  context said to drop any import analyze flags this way.
- `dart format` reflowed the `SizedBox(...)` call in `wrap` onto three lines
  instead of one. No other formatting changes.

No changes to `lib/src/draft_canvas.dart` were needed. Task 3's wiring
(the static latch, `_reportResidentFallback`, the `_attach`-time report for
no-GPU, and the `_onResidentLanded` report for a failed upload) already
satisfies every assertion in the brief's three tests. All three passed on
the first run, with no failing assertion to diagnose.

## Test run

Command: `flutter test test/gpu/draft_canvas_fallback_test.dart` (run from
`packages/jet_cad_2d_flutter`), first attempt, before the import cleanup:

```
00:00 +0: loading .../test/gpu/draft_canvas_fallback_test.dart
00:00 +0: no GPU: two canvases, vertices both, one report
00:00 +1: a failed upload: vertices from then on, one report, no retry
00:00 +2: a canvas whose upload succeeds reports nothing
00:00 +3: All tests passed!
```

All three tests green, no wiring gap found.

## Production fix

None. Task 3's `DraftCanvas` latch and listener wiring already met
criterion 10 exactly as specified: one report per process regardless of
which fallback fires first, no throw on the frame path, no retry after an
upload failure, and no report for an explicit `RenderBackend.vertices`
request. `lib/src/draft_canvas.dart` is untouched by this task.

## Gates (run from `packages/jet_cad_2d_flutter`, after the import cleanup)

### `flutter test`

Tail of output:

```
00:07 +644 ~1: .../test/tile_measurement_seam_test.dart: the rest bake fires: the unflagged arm slices every visible tile
00:07 +645 ~1: .../test/tile_measurement_seam_test.dart: the rest bake fires: the unflagged arm slices every visible tile
00:07 +646 ~1: .../test/tile_measurement_seam_test.dart: debugRestBakeDisabled slices nothing and still covers
00:07 +647 ~1: .../test/tile_measurement_seam_test.dart: debugFullViewportQuery grows the fallback walk to the whole viewport
00:07 +648 ~1: All tests passed!
```

Exit code: 0. (The `~1` markers are pre-existing skips unrelated to this
task — the only file this task touches is the new test file, confirmed by
`git status --short` showing nothing else changed.)

### `flutter analyze`

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.9s)
```

Exit code: 0.

### `dart format --output=none --set-exit-if-changed .`

```
Formatted 108 files (0 changed) in 0.16 seconds.
```

Exit code: 0.

## Files changed

- `packages/jet_cad_2d_flutter/test/gpu/draft_canvas_fallback_test.dart` (new, 121 lines)

`lib/src/draft_canvas.dart`: unchanged.

## Self-review

- Diffed the committed test file against the brief's literal text: the only
  differences are the two dropped imports and one line reflowed by
  `dart format` (the `SizedBox` call in `wrap` split across three lines
  instead of one) — both mechanical, both expected.
- `git status --short` before committing showed only the new test file;
  `analysis_options.yaml` was not touched.
- Confirmed via `git diff` that no other file in the tree changed as a
  side effect of running `flutter pub get` / `flutter test` / `flutter
  analyze` (dependency version-bump notices printed to stdout, but nothing
  was written to `pubspec.lock` or committed).
- Commit contains exactly one file, matches the brief's Step 3 message and
  carries the required `Co-Authored-By` trailer.

## Concerns

None. This task needed no wiring fix — Task 3 already satisfied criterion
10 in full, and this test now pins that in the suite.
