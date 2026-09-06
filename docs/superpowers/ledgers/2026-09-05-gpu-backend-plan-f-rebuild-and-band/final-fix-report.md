# Plan F — final-review fix wave: report

Branch `plan-f/rebuild-and-band`, worktree `.worktrees/plan-f-rebuild-and-band`.
Base HEAD before this wave: `2b0dd0e`.

## Findings

### A (Important) — a throwing rebuild now falls back like a failed upload

`ResidentRebuilder._run` (`packages/jet_cad_2d_flutter/lib/src/gpu/resident_rebuilder.dart`)
now wraps `await rebuildNow(...)` in `catch (error, stackTrace)`. On a throw it
sets `_uploadFailed = true`, clears `_pending`, disposes and nulls `_backend`,
reports through `FlutterError.reportError(FlutterErrorDetails(exception: error,
stack: stackTrace, library: 'jet_cad_2d_flutter', context:
ErrorDescription('rebuilding the resident GPU backend')))`, then calls
`notifyListeners()` if not disposed. The existing `finally` still clears
`_inFlightTrigger`.

Covering tests:
- `test/gpu/resident_rebuilder_test.dart`: new test `'a throwing upload falls
  back for good, the same as a null upload'`. Added `bool throwing` to
  `FakeUploader` (`test/support/recording_frame_painter.dart`), which throws
  `StateError('upload exploded')`. Asserts `uploadFailed` true, `backend`
  null, `tester.takeException()` is that exact `StateError` (via
  `FlutterErrorDetails.exception`), and a later `markDirty` + `land` leaves
  `rebuilds == 1`.
  Output: `00:00 +8: a throwing upload falls back for good, the same as a null upload` (green, part of the file's 10/10 run).
- `test/gpu/draft_canvas_fallback_test.dart`: new test `'a throwing upload
  falls back for good: two reports, vertices still paints'`. **Deviation
  from the letter of the finding, documented in the test's own comment**: the
  finding asked for two separate `tester.takeException()` calls (StateError,
  then FlutterError), one after each pump. I verified empirically (see
  `binding.dart:1774` in the installed Flutter SDK) that
  `TestWidgetsFlutterBinding.FlutterError.onError` holds only ONE pending
  exception; a second `reportError` before the first is taken collapses both
  into a synthetic "Multiple exceptions (2) were detected" error — and both
  reports here fire synchronously, in the same microtask, inside the very
  first `pumpWidget` call (the rebuilder's own catch reports the `StateError`,
  then its `notifyListeners()` synchronously runs
  `DraftCanvas._onResidentLanded`, which reports the `FlutterError` fallback),
  so there is no point at which test code can call `takeException()` between
  them — confirmed by an instrumented run that printed the "Multiple
  exceptions" text after `pumpWidget` and `null` after every subsequent pump.
  I intercepted `FlutterError.onError` directly for the scope of the test
  instead, collecting both reports into a list and asserting on order and
  content (`StateError` with `'upload exploded'`, then `FlutterError`
  containing `'upload failed'`), then restoring the previous handler.
  Verified `uploadFailed`, `backend == null`,
  `debugResidentFallbackReports == 1`, and that the canvas keeps painting
  through `vertices` after a subsequent zoom.
  Output: `00:00 +2: a throwing upload falls back for good: two reports, vertices still paints` (green, part of the file's 4/4 run).

### B (Important) — three stale "until Plan F" doc comments

- `lib/src/gpu/text_patches.dart` (the band constants' doc, was ~:10-16):
  replaced the "provisional... until Plan F measures the band" paragraph with
  the measured result — straight geometry holds criterion 1 across the whole
  `[0.25, 4.0]` sweep; a corpus with a curve or a near-threshold label makes
  criterion 1 a step at each frozen watermark decision, so the reported band
  is `[1.0, 1.0]`; constants stay at `0.5` / `2.0` under Ruling F6-a because
  shrinking them would rebuild on every zoom step, and unfreezing either
  watermark row is the human's call. Points at
  `docs/superpowers/notes/2026-09-05-plan-f-results.md`.
- `lib/src/draft_canvas.dart` ~:227 (`vertices` field doc, "has no
  GPU-resident sink of its own to build yet (Plan F's work)") and ~:510
  (`_DraftCustomPainter.vertices` doc, "routed here until Plan F"): both
  reworded to the Ruling F5 sentence — the vertices sink is what a
  `residentGpu` canvas draws through before its first rebuild lands and after
  an upload fails.

No test attached (doc-only); `flutter analyze` and `dart format` confirm the
comments compile and are formatted.

### C (Important) — `DraftCanvas.tiles` doc

Added a paragraph to the `tiles` field doc noting that on a `residentGpu`
canvas the flag is ignored: no tile cache is built beside the resident
backend, both are gesture paths, and the resident one holds the whole
drawing. Points at `DraftCanvasState.tileCache`'s own comment, which already
carried this fact for the implementation side.

### D (Minor 5) — `_DraftCustomPainter.shouldRepaint`

Changed to:
```dart
bool shouldRepaint(_DraftCustomPainter old) {
  return old.resident != resident ||
      (resident != null && old.devicePixelRatio != devicePixelRatio);
}
```
so switching `backend:` away from `residentGpu` now repaints — previously the
early `if (r == null) return false` made the identity comparison unreachable
whenever the *new* delegate's `resident` was null, even if `old.resident` was
not, so the last GPU frame stayed composited underneath the vertices/tile
path that just took over. Added a paragraph to the doc comment explaining
why the identity check must run even when `resident` is null.

Covering test: `test/gpu/draft_canvas_resident_test.dart`, new test
`'switching the backend away from residentGpu repaints instead of leaving
the last GPU frame on screen'`. Pumps `canvas()` and lands, then pumps an
inline `DraftCanvas` with `backend: RenderBackend.vertices` over the same
document/index/camera; asserts `paints` grew and `state(t).resident` is null.
Output: `00:00 +6: switching the backend away from residentGpu repaints instead of leaving the last GPU frame on screen` (green, part of the file's 8/8 run).

### E (Minor 6) — `test/render_backend_test.dart`

Guarded the `tester.takeException()` assertion at the end of `'an explicit
backend is honoured, not clamped'` with
`if (resolveBackend(RenderBackend.residentGpu) != RenderBackend.residentGpu)`,
and deleted the stray empty `//` comment line above the loop. Ran the whole
file green (part of the 668-test `flutter test` run below).

### F (Minor 7) — `lib/src/gpu/gpu_draw_backend.dart` class doc

Updated the per-patch enumeration:
- `gpu.RenderTarget` and `gpu.ColorAttachment` added, noting both measured at
  88.0/frame by the device probe (confirmed against
  `docs/superpowers/notes/2026-09-05-plan-f-results.md:522-525` and the
  criterion-5 table — not edited, only read for the number).
- "a `gpu.BufferView`" → "the three `gpu.BufferView`s" per patch: confirmed
  in the code (`gpu_draw_backend.dart`'s patch-pass loop) — two explicit
  `gpu.BufferView(...)` constructions for `bindVertexBuffer` (corners,
  `patch.instances`) plus the one `HostBuffer.emplace` returns for the
  uniform block (confirmed `emplace`'s return type is `BufferView` in
  `flutter_scene`'s `gpu/web/buffer.dart:237`).
- "the `Transform2`" → "two `Transform2`s for `toPatch`": the translation
  `composeTransforms` takes (`Transform2.translation(-region.x, -region.y)`)
  and the composed result it returns.

Doc-only; `flutter analyze` confirms it compiles.

### G (Minor 8) — `test/gpu/classify_grid_test.dart`

Relabeled the replacement mutation from `M-F10` to `M-F10′` (the Unicode
prime U+2032, matching the mutation log and results note verbatim — verified
byte-for-byte via `xxd` against
`docs/superpowers/notes/2026-09-05-plan-f-results.md`). Kept the sentence
recording the original `M-F10` (`.floor()` → `.round()`) as equivalent,
unchanged.

### H (Minor 9) — `test/gpu/band_sweep_test.dart`

Renamed the test from `'text with level of detail on: exact inside [0.5,
1.0]...'` to `'...exact inside [0.35, 1.0]...'`, matching the measured run
and the test's own surrounding comment, which already said `[0.35, 1.0]`.

### I (Minor 14) — `test/gpu/draft_canvas_resident_test.dart`

New test `'a new document replaces the rebuilder, and the new collection is
taken from the new document, not the old one's'`. Builds a second
`textOverlapFixture(measurer2)` + `SpatialIndex(doc2)`, edits doc2's label
901 from `'COVERED'` to `'SECOND'` via `SetEntityTextCommand` *before*
pumping the canvas with `document: doc2, index: index2`, then lands. Asserts:
- `s.resident` `isNot(same(first))` and `first.disposed` is true,
- `doc.tables.debugListenerCount == 0` (old document) and
  `doc2.tables.debugListenerCount == 1` (new document),
- the new rebuilder's `collection!.texts` contains `'SECOND'` and not
  `'COVERED'`, proving the new collection was walked from the new document,
  not carried over from the old one.

Output: `00:00 +7: a new document replaces the rebuilder, and the new
collection is taken from the new document, not the old one's` (green, part
of the file's 8/8 run).

## The nine gates, with exit codes

```
$ cd packages/jet_cad_2d && dart test
... All tests passed! (798/798)
$ echo $?
0

$ cd packages/jet_cad_2d && dart analyze
Analyzing jet_cad_2d... No issues found!
$ echo $?
0

$ cd packages/jet_cad_2d && dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.14s
$ echo $?
0

$ cd packages/jet_cad_2d_flutter && flutter test
... All tests passed! (668/668)
$ echo $?
0

$ cd packages/jet_cad_2d_flutter && flutter analyze
Analyzing jet_cad_2d_flutter... No issues found!
$ echo $?
0

$ cd packages/jet_cad_2d_flutter && dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.16s
$ echo $?
0

$ cd apps/dev_harness_2d && flutter test --concurrency=1
... All tests passed! (82/82)
$ echo $?
0

$ cd apps/dev_harness_2d && flutter analyze
Analyzing dev_harness_2d... No issues found!
$ echo $?
0

$ cd apps/dev_harness_2d && dart format --output=none --set-exit-if-changed .
Formatted 22 files (0 changed) in 0.04s
$ echo $?
0
```

(`dart format --output=none --set-exit-if-changed .` was run once, saw three
files it would reformat — `resident_rebuilder.dart`,
`draft_canvas_resident_test.dart`, `render_backend_test.dart` — reformatted
them with plain `dart format <files>`, then re-ran the check clean before
recording the exit code above.)

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/gpu/resident_rebuilder.dart` (A)
- `packages/jet_cad_2d_flutter/lib/src/gpu/text_patches.dart` (B)
- `packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart` (B, C, D)
- `packages/jet_cad_2d_flutter/lib/src/gpu/gpu_draw_backend.dart` (F)
- `packages/jet_cad_2d_flutter/test/support/recording_frame_painter.dart` (A)
- `packages/jet_cad_2d_flutter/test/gpu/resident_rebuilder_test.dart` (A)
- `packages/jet_cad_2d_flutter/test/gpu/draft_canvas_fallback_test.dart` (A)
- `packages/jet_cad_2d_flutter/test/gpu/draft_canvas_resident_test.dart` (D, I)
- `packages/jet_cad_2d_flutter/test/render_backend_test.dart` (E)
- `packages/jet_cad_2d_flutter/test/gpu/classify_grid_test.dart` (G)
- `packages/jet_cad_2d_flutter/test/gpu/band_sweep_test.dart` (H)

No file under `packages/jet_cad_2d`, neither sink file, no shader, and no
`DraftPainter` API surface was touched. No file under `docs/` was touched —
no measured number changed. `analysis_options.yaml` was not touched or
staged in any of the three workspaces (checked via `git status --porcelain`
before committing).

## Concerns

- **Finding A's widget-level test deviates from the letter of the spec**, for
  a reason verified against the Flutter SDK source rather than assumed (see
  above): `tester.takeException()` cannot see two same-tick reports
  separately, no matter how pumps are interleaved, because
  `TestWidgetsFlutterBinding` collapses a second `reportError` into a
  synthetic message before test code ever regains control. The test still
  verifies the same underlying fact the finding cared about — two reports, in
  the right order, with the right content — via a scoped
  `FlutterError.onError` interception instead. Flagging this for review since
  it is a judgment call, not a literal implementation of the finding's test
  recipe.
- Finding F's "three `gpu.BufferView`s per patch" and "88.0/frame" wording is
  accurate as a *static* description of what the per-patch loop constructs
  and as a citation of the results note's own number for `RenderTarget`/
  `ColorAttachment`, but the note's own measured `BufferView` count
  (89.9/frame, attributed there to only "the patch's sub-buffer view") does
  not itself decompose into "3 × patches" the way `Rect` (288.9, "three
  `Rect`s per patch") does. I did not reconcile this discrepancy or touch the
  results note (out of scope, no measured number may change there); the class
  doc's new wording is about what the code constructs, not a restatement of
  the probe's per-class breakdown.
