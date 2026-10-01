# Task 3 report — render: symbol thumbnails (spec D5, R-2, F-7, F-8, F-15)

Commit: 359a70a `feat(render): symbol thumbnails` (parent 7bed823). Not pushed.

Files:
- packages/jet_cad_2d_flutter/lib/src/symbol_thumbnails.dart (new): `kThumbnailPadding = 0.08`; `SymbolThumbnails({maxEntries = 64})` with `imageFor({key, document, logicalSize, devicePixelRatio, foreground})`, `length`, `dispose()`.
- packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart: `export 'src/symbol_thumbnails.dart';`.
- packages/jet_cad_2d_flutter/test/symbol_thumbnails_test.dart (new, 13 tests).

## Gates
Render (`CI=true flutter test`, full suite, log scratchpad/b3/render.log):
```
00:53 +987 ~1 -7: Some tests failed.
```
974 + 13 new = 987, 1 skip, 7 failures = the standing ones only (text_ladder_golden rungs 1-5, text_lod_ladder_golden rungs 1-2, RenderBackend.canvas), checked by listing every `[E]`.
`flutter analyze`: `No issues found! (ran in 3.0s)`; `dart format --output=none --set-exit-if-changed .`: `Formatted 180 files (0 changed)`.
App (imports the package export; count unchanged): `02:48 +819: All tests passed!`, `No issues found! (ran in 1.4s)`, `Formatted 145 files (0 changed)`, fmt=0.
Engine: untouched by the diff, not re-run.
Allocation invariants: `git diff --stat` on packages/jet_cad_2d/test/invariants, packages/jet_cad_2d_flutter/test/invariants and packages/jet_cad_2d: empty. No analysis_options.yaml committed (staged by explicit path).

## Tests (all pixel/image work under `tester.runAsync`, P-4)
Fixtures built in the test (no app import): `lineSymbol()` — definition basePoint (300,150), a thick (2 mm) BYBLOCK line and an ACI 1 circle symmetric about it, instance at translate(52000,-31000)·rot(0.7)·scale(-1,1) with ByBlockColor; `hookSymbol()` — basePoint (-120,410), BYBLOCK polyline + arc, instance at translate(-18000,74000)·rot(-1.2)·scale(1,-1). A guard test checks basePoint off origin, non-identity mirrored instance, extents far from origin.
- T1 two documents give different bytes, each with ink (>50 inked pixels).
- T2 Size(41.3,30.6) at DPR 2 -> 83x61; at DPR 1.5 -> 62x46.
- T3 same request twice: pending future shared (identical), builder called once, same image.
- T4 (4 cases) a version change, a logical size, a DPR, a foreground each paint anew (builds 2), and the first key still hits.
- T5 maxEntries 2: a, b, hit a, c -> b disposed (LRU, not FIFO), a and c live; b again repaints and evicts a.
- T6 an entry evicted while pending: the awaiting holder sees an undisposed image and clones it; a microtask later the original is disposed, the clone not.
- T7 dispose() disposes all, empties, later use throws StateError.
- T8 foreground: centre pixel (on the BYBLOCK line) composited over 0xF4F1EA with `foregroundFor(cell)` is < 40 per channel; the control with white ink is > 215.
- T9 a throwing builder: `imageFor` returns normally, the future errors with the StateError, the cache still works.

## Mutants
cp to scratchpad/b3/backup.dart, one sed, `CI=true flutter test test/symbol_thumbnails_test.dart` in the foreground, cp back, `restored diff=0` every time. Lines at 359a70a, file lib/src/symbol_thumbnails.dart.

| Id | Line | Mutation | Red test(s) | Real output |
|---|---|---|---|---|
| M-09k | :76 | key part -> `0` | T1, T4 version, T5, T6 | `Expected: <2>` / `Actual: <1>` (`each part of the key paints anew a version change [E]`) |
| M-09x size | :76 | `logicalSize` -> `null` in key | T4 logical size | `Expected: <2>` / `Actual: <1>`, `+12 -1` |
| M-09x DPR | :76 | `devicePixelRatio` -> `null` in key | T2, T4 DPR | `Expected: [62, 46]` / `Actual: [83, 61]`; `Expected: <2>` / `Actual: <1>` |
| M-09x foreground | :76 | `foreground` -> `null` in key | T4 foreground, T8 | `Expected: every element(a value greater than <215>)` / `Actual: [0, 0, 0]` |
| M-09y | :112 | `DocumentStyleResolver(doc)` (foreground not passed) | T8 | `Expected: every element(a value less than <40>)` / `Actual: [255, 255, 255]` |
| M-09z | :87 | eviction drops the entry without `release()` | T5, T6 | `Expected: true` / `Actual: <false>`, `+11 -2` |
| M-09z (b) | :170 | `release()` does not dispose the image | T5, T7 | `Expected: [true, true]` / `Actual: [false, false]` |
| M-09b15 | :139 | width ignores the DPR | T2, T6, T8, T9 | `Expected: [83, 61]` / `Actual: [41, 61]` |
| extra: pending dispose immediate | :154 | `scheduleMicrotask(image.dispose)` -> `image.dispose()` | T6 | `Expected: false` / `Actual: <true>` |
| extra: cache dispose skips entries | :98 | `entry.release()` -> `entry` | T7 | `Expected: [true, true]` / `Actual: [false, false]` |
| extra: FIFO, not LRU | :77 | `_entries.remove(cacheKey)` -> `_entries[cacheKey]` | T5 | `Expected: true` / `Actual: <false>` |
| (equivalent, discarded) | :79 | `_entries[cacheKey] = hit` -> `??= hit` | none, `+13: All tests passed!` | equivalent: the key was just removed, so `??=` re-inserts at the end too. Replaced by the FIFO mutant above. |

## Decisions
- Padding: 8% of the extents' **larger** side on every side (`kThumbnailPadding`), so a zero-height symbol still gets a margin; empty extents are not padded (fit handles them).
- The cache key is a Dart record `(key, logicalSize, devicePixelRatio, foreground)`: structural, exact `==` on stored values (CLAUDE.md), one line to mutate.
- Pending eviction: an entry evicted before its future completes disposes its image one microtask after completion, so every listener of that future (including an `await` continuation) can clone it first. Documented in the class doc: a holder must clone in its completion callback. Relevant to Task 4 (the cell clones).
- Failed futures stay cached (the library is immutable in a session; no repaint storm on rebuild); the cache's own listener swallows the error so it is never reported unhandled; the caller's future still errors.
- `imageFor` after `dispose()` throws StateError (a programmer error, not a paint failure).
- `_paint` is `async`, so a builder or paint throw never escapes synchronously; on a paint throw the recorder's picture is ended and disposed, the index always disposed.

## Spec/plan notes, open issues
- Plan Task 2 said "Task 3 adds the cache parameter" to `FloorPlannerApp`; Task 3's own text and this brief say render only, app unchanged. Not added: the app's `thumbnails` parameter is open for Task 9 (whose text says `FloorPlannerApp` passes the cache it owns) — the orchestrator should make sure the brief for 8/9 includes it.
- `Image.debugDisposed` is a debug-mode-only signal (asserts on under `flutter test`), fine for the suite.

## Task 3b (review findings 1, 2; test-only)
Commit: 3faabd4 `test(render): thumbnails pin the padding and the sink DPR (3b)`, parent 1951d01. Only test/symbol_thumbnails_test.dart changed.

Added: `hairlineSymbol()` (basePoint (640,-275), one 0.05 mm BYBLOCK line, instance at translate(-37000,-91000)·rot(0.4)·scale(-1,1); a single line, not a polyline, because a join overlaps two faded strokes: a first try with a rectangle read peak alpha 240 at DPR 2), helpers `inkBox`, `peakAlpha`, and two tests:
- T10 padding: for line, hook and hair at 48x40 DPR 2, the ink box stays >= 2 device px from every side; for hook and hair ("tight" extents) the ink comes within 15% of both edges of at least one axis. The line fixture is excluded from that half: its ring's extents are the local box turned 0.7 rad (measured ink 24..71 x 16..63 in 96x80). Measured: hook [15,8]..[85,74], hair [10,33]..[85,45].
- T11 sink DPR: peak alpha of the hairline at DPR 1 in [80,110], at DPR 2 in [175,210] (formula: 96 and 193).

Mutants (scratchpad/b3b, same procedure, restored diff=0 each), lib/src/symbol_thumbnails.dart at 1951d01:
| Mutant | Line | Red | Output |
|---|---|---|---|
| `pad = 0.0 *` | :114 | T10 | `Expected: every element(a value greater than or equal to <2>)` / `Actual: [5, 0]` |
| fit on the raw extents | :117 | T10 | same: `Actual: [5, 0]` |
| sink `devicePixelRatio: 1.0` | :125 | T11 | `Expected: be in range from 175 (inclusive) to 210 (inclusive)` / `Actual: <96>` |
| extra: `pad = 0.25 *` (too much) | :114 | T10 | `Expected: true` / `Actual: <false>` |

Gate: render `00:59 +999 ~1 -7: Some tests failed.` (the 7 are the standing text_ladder rungs 1-5 and text_lod_ladder rungs 1-2, every `[E]` listed); `No issues found!`; `Formatted 182 files (0 changed)`. App and engine untouched (test-only render change), not re-run.
