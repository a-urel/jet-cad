# Task 1 report: The collector records text, and the spec's one word

## What was implemented

Followed `task-1-brief.md` with controller Rulings P1 and P2 applied:

- **Step 1 (spec's one word, Ruling E9):** ran the brief's `python3` script
  verbatim. The assertion matched on the first try (`s.count(old) == 1`); no
  `old` adjustment was needed. Diff below.
- **Step 2:** wrote `test/gpu/resident_text_test.dart` with the brief's eight
  tests verbatim, plus (Ruling P2) two direct tests of `boundTransformedBox`:
  a 90-degree rotation of `(0,-2)..(40,8)` giving `(-8,0)..(2,40)`, and a
  mirror `(-1,0,0,1,0,0)` yielding `min <= max` on both axes.
- **Step 3:** ran the new test file, confirmed the expected compile-error RED.
- **Step 4 (Ruling P1):** created `lib/src/gpu/text_patches.dart` with the
  four constants and **no imports** at first, then (Ruling P2) added
  `boundTransformedBox` to that same file — which pulls in `dart:typed_data`
  and `package:jet_cad_2d/jet_cad_2d.dart` for `Transform2`, exactly as the
  ruling anticipates. The function is written as four manually-unrolled
  corner computations (not a loop over a list literal) so it allocates
  nothing — a `for (final corner in [...])` version was tried first and
  discarded because the list literal is itself a per-call allocation, which
  would contradict the doc comment's "Allocation-free" claim.
- **Step 5:** created `lib/src/gpu/resident_text.dart` with `ResidentTextRecord`
  verbatim from the brief.
- **Step 6:** modified `geometry_collector.dart`:
  - added the two imports (`resident_text.dart`, `text_patches.dart`)
  - extended the constructor with `measurer` and `textStyleOf`, both optional
  - added `_texts`, `_textLayout` (reused `TextLayout`), and (Ruling P2)
    `_boxScratch` (reused `Float64List(4)`) fields
  - added the `texts` getter (`List.unmodifiable` view, documented as copying
    the same way `data` does)
  - replaced `skippedOps`'s doc with the brief's replacement text
  - replaced `text()`: on a null `measurer`/`textStyleOf` it still counts
    (`_skipped++`); otherwise it lays out the glyph box via
    `TextLayout.layOutBox`, calls `boundTransformedBox` (Ruling P2's
    substitute for the brief's inline `corner(...)` closure) into
    `_boxScratch`, pads by `kTextBoxPadDevicePixels / (devicePixelRatio *
    kBandLowerScale)` (band floor, Ruling E9), and appends a
    `ResidentTextRecord` using `resolved.argb` directly (never
    `_coveredArgb`, per the brief's explicit note).
  - added the two exports to `lib/jet_cad_2d_flutter.dart`.
- **Step 7:** ran the focused test file (10/10 pass — 8 brief tests + 2
  `boundTransformedBox` tests), then the whole suite, `flutter analyze`,
  `dart format`.
- **Step 8:** committed with the brief's exact message, all six files staged
  (spec, `resident_text.dart`, `text_patches.dart`, `geometry_collector.dart`,
  the barrel, and the test file).

## Deviation from the brief's literal text (and why)

The brief's Step 2 test file imports both the barrel
(`package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart`) and
`package:jet_cad_2d_flutter/src/gpu/text_patches.dart` directly. Once Step 6's
barrel export of `text_patches.dart` is in place, the second import is
redundant — `flutter analyze` failed with `unnecessary_import` (info-level,
but `flutter analyze` still exits 1 on any issue). I removed that one import
line from the test file; everything the test uses (`kBandLowerScale`,
`boundTransformedBox`, etc.) is still reached through the barrel import. No
other change to the test file's content.

`skippedOps`'s doc: the brief's "Replace `skippedOps`'s doc" block does not
carry forward the pre-existing history lines ("`circle` and `arc` stopped
counting here in Plan B's Task 5; ..."). I replaced the whole comment with
exactly the brief's given text, per "Replace" being explicit about the full
new comment.

## TDD evidence

**RED** — `cd packages/jet_cad_2d_flutter && flutter test test/gpu/resident_text_test.dart` (before Steps 4-6):

```
test/gpu/resident_text_test.dart:157:5: Error: Method not found: 'boundTransformedBox'.
      boundTransformedBox(0, -2, 40, 8, const Transform2(-1, 0, 0, 1, 0, 0), out);
      ^^^^^^^^^^^^^^^^^^^
test/gpu/resident_text_test.dart:42:14: Error: The getter 'texts' isn't defined for the type 'GeometryCollector'.
   - 'GeometryCollector' is from 'package:jet_cad_2d_flutter/src/gpu/geometry_collector.dart' ('lib/src/gpu/geometry_collector.dart').
   ...
00:00 +0 -1: Some tests failed.

Failing tests:
  .../test/gpu/resident_text_test.dart: loading .../test/gpu/resident_text_test.dart
```
(compile error, as expected — `text_patches.dart` did not exist yet, `texts` and `measurer` were undefined)

**GREEN** — same command, after Steps 4-6:

```
00:00 +0: loading .../test/gpu/resident_text_test.dart
00:00 +0: a text op becomes one record carrying the residual, flat
00:00 +1: the instance index is the number of instances written before it
00:00 +2: the box is the four transformed corners, padded at the band floor
00:00 +3: the pad is one device pixel at the band floor, not at the ceiling
00:00 +4: a mirrored residual still yields min <= max
00:00 +5: without a measurer, text is counted and not recorded (Ruling E2)
00:00 +6: the text list is in emission order and is not sortable by handle
00:00 +7: the band constants and the pad are what the spec says
00:00 +8: boundTransformedBox: a 90-degree rotation of the box re-bounds it
00:00 +9: boundTransformedBox: a mirror still yields min <= max
00:00 +10: All tests passed!
```
Exit code: 0.

## Package gate

All three run from `packages/jet_cad_2d_flutter`, after the redundant-import
fix and after re-formatting (see below):

**`flutter test`**
```
...
00:08 +575 ~1: .../test/tile_slice_differential_test.dart: tile boundaries carry no difference of their own
00:08 +576 ~1: All tests passed!
```
Exit code: 0. (576 passed, 1 skipped — the skip is pre-existing and unrelated to this task; 0 failed.)

**`flutter analyze`**
First run (before removing the redundant import) surfaced exactly one issue:
```
info • The import of 'package:jet_cad_2d_flutter/src/gpu/text_patches.dart' is unnecessary because all of the used elements are also provided by the import of 'package:jet_cad_2d_flutter/jet_cad_2d.dart' (barrel) • test/gpu/resident_text_test.dart:6:8 • unnecessary_import
1 issue found.
```
Exit code: 1. After removing that import line:
```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.8s)
```
Exit code: 0.

**`dart format --output=none --set-exit-if-changed .`**
First run:
```
Changed lib/src/gpu/geometry_collector.dart
Changed lib/src/gpu/text_patches.dart
Formatted 95 files (2 changed) in 0.16 seconds.
```
Exit code: 1. Ran `dart format` (writing) on those two files, then re-checked:
```
Formatted 95 files (0 changed) in 0.14 seconds.
```
Exit code: 0.

Re-ran `flutter test test/gpu/resident_text_test.dart` and `flutter analyze`
after the formatting pass, and the full `flutter test` once more — all green,
exit 0 each time (see above; the final full-suite run is the one quoted).

## Files changed

- `docs/superpowers/specs/2026-08-29-gpu-resident-render-backend-design.md` — Ruling E9's one word (upper -> lower scale bound), via the brief's script
- `packages/jet_cad_2d_flutter/lib/src/gpu/resident_text.dart` (new) — `ResidentTextRecord`
- `packages/jet_cad_2d_flutter/lib/src/gpu/text_patches.dart` (new) — the four constants + `boundTransformedBox` (Ruling P2)
- `packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart` — constructor/fields, `texts` getter, `skippedOps` doc, `text()`
- `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` — exports for the two new files
- `packages/jet_cad_2d_flutter/test/gpu/resident_text_test.dart` (new) — 10 tests (8 brief + 2 `boundTransformedBox`)

Commit: `26184f3 feat(gpu): the collector records text as a resident list`
(6 files changed, 356 insertions(+), 9 deletions(-))

## Self-review

- **Completeness:** every brief step done; both P1 and P2 rulings applied;
  the extra `boundTransformedBox` tests from P2 are present.
- **Quality:** doc comments kept at the brief's density; `boundTransformedBox`
  unrolled by hand to keep the "allocation-free" claim in its own doc comment
  true (a list-literal loop would have allocated per call).
- **Discipline:** no changes outside the six files the brief/commit message
  names, except the one redundant-import line removed from the test file
  (documented above) — nothing else in the test's assertions was altered.
- **Testing:** all ten tests in the file exercise non-degenerate fixtures —
  rotated/sheared/mirrored/off-origin residuals, non-uniform dpr/band-floor
  arithmetic, emission-order and instance-index checks against a non-empty
  prior buffer. `git status --short` confirmed no `analysis_options.yaml`
  was ever staged.

## Concerns

- The redundant-import deviation (documented above) is a small, mechanical
  fix required to keep `flutter analyze` green given Step 6's barrel export;
  it does not change any test's behavior or assertions.
- None outstanding otherwise. `GeometryCollector.text()` and
  `boundTransformedBox` are ready for Task 2 to build the classification
  functions on top of `text_patches.dart`.
