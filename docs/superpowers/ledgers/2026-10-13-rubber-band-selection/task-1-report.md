# Task 1 report: the shared band painter

Commit: 38ca3af6 `feat(render): a shared selection band painter and direction rule`

## Implemented

- `lib/src/selection_band.dart` (new): `bandModeFor`, `SelectionBandPainter` exactly as the brief's sketch. The two relative imports (`canvas_palette.dart` holds `PaperPalette`, `selection_style.dart` holds `kBandFillAlpha`) were already right; nothing needed adjusting.
- `lib/jet_cad_2d_flutter.dart`: `export 'src/selection_band.dart';` placed alphabetically (after `selection.dart`, before `selection_overlay.dart`), not literally beside `selection_style.dart`.
- `lib/src/select_tool.dart`: both mode computations call `bandModeFor(_start, _end)`; field `_bandPainter`; `paintOverlay` ends in `_bandPainter.paint(canvas, rect, _bandMode!, paper)`; `_drawDashedRect` deleted; import added. `_bandMode!` is safe: `bandScreen` is non-null only while `dragKind == band`, and both places that set the band kind set `_bandMode` in the same step.
- `test/selection_band_test.dart` (new): BP1, BP2, BP3.

Files: the four above. No `analysis_options.yaml` touched; `jet_cad_2d` not edited.

## TDD

RED: `cd packages/jet_cad_2d_flutter && flutter test test/selection_band_test.dart`:
`Error when reading 'lib/src/selection_band.dart': No such file or directory` and `Method not found: 'bandModeFor'` / `'SelectionBandPainter'`, "Failed to load ... Compilation failed". Expected: the file did not exist.

GREEN (same command, after the implementation): `00:00 +3: All tests passed!`
Then with `tool_palette_test.dart` and `select_tool_test.dart`: `+35: All tests passed!`; `selection_band_test` + `tool_palette_test` after the last revert: `+13: All tests passed!`.

## Gate (render package)

- `flutter test --file-reporter json:/tmp/claude-501/t1-render.json`: `+1445 ~1 -5: Some tests failed.` The failures are the text-ladder goldens.
- `dart run tool/ci/expect_failures.dart --package packages/jet_cad_2d_flutter --root packages/jet_cad_2d_flutter /tmp/claude-501/t1-render.json`: exit **1**, output exactly two lines, both "standing failure passed or did not run": `text_lod_ladder_golden_test.dart :: text lod ladder rung 1` and `rung 2`. That is the recorded macOS standing difference (the brief's task text said exit 0; with rungs 1-2 passing the tool reports them and exits 1). No unexpected failure, no new failure.
- `flutter analyze`: `No issues found!`
- `dart format --output=none --set-exit-if-changed .`: `Formatted 232 files (0 changed)`, exit 0.

Only the render package was touched; the engine and GPU packages were not run (`jet_cad_2d` unchanged; the GPU package does not import `select_tool.dart`'s band code).

## Mutants (each applied, seen red, reverted by copying the original file back; `cmp` confirmed identical)

- **M-BP1** `end.dx >= start.dx` to `end.dx > start.dx`: killer BP1, `selection_band_test.dart:27` (equal x): Expected `BandMode.window`, Actual `BandMode.crossing`.
- **M-BP2** compare `dy` instead of `dx`: killer BP1, `selection_band_test.dart:29` (`(310,90)->(310,40)`): Expected `window`, Actual `crossing`.
- **M-BP3** `_stroke.color = color` moved inside the crossing branch: killers BP3 (`:93`, "call 1 colour": the third call's window stroke is crossing green `0.1804/0.6196/0.3569` instead of the first call's) and BP2 (`:53`, a first-use window stroke is black `4278190080` instead of `0xFF1E6FE8`).
- **M-RB18** stroke colour swapped between the modes: killers BP2 (`:53`, Expected `4280184808` Actual `4281245275`), BP3 (Expected `4281245275`, Actual `4280184808`), and the design-mode tests in `tool_palette_test.dart` (window band paintOverlay stroke, window band in pixels "the left edge" got (95,214,143), crossing band paintOverlay).

## Self-review

- Behaviour kept: the fill is drawn first at `kBandFillAlpha`, then the 1 px stroke; dashes walk TL, TR, BR, BL clockwise, 6 on / 4 off, as before. The old code built `Paint`s and a `Path` per frame; the new one reuses fields (RB16 direction). The dash arithmetic is on doubles instead of `Offset` ops: same values (the pixel tests in `tool_palette_test` pass).
- `math` and `Path` imports in `select_tool.dart` are still used elsewhere (analyze clean).
- (Fix round 1 below corrects BP3's degenerate tail.)
- Concerns: none beyond the exit-1 note above (the two standing-difference lines). BP2's "path bounds within 1e-9" and first-dash assertions use `Path.getBounds` / `computeMetrics`, which work under `flutter test`.

## Fix round 1

Commit: 9926758d `test(render): the band painter's dash path is reset per call`

Finding: BP3's "second crossing" check compared one shared `Path` instance with itself (SpyCanvas stores the path by reference), so removing `_dashes.reset()` stayed green.

Changed:
- `test/selection_band_test.dart`: BP3's degenerate tail removed; new **BP4** paints two crossings with different rects (`20.5,30.25,120.5,70.25` then `300.5,200.25,560.5,380.25`) through a `_PathSnapshot` canvas that reads `getBounds()` and the contour count inside `drawPath`. It asserts the second call's bounds equal its own rect only, and its contour count equals a fresh painter's and exceeds the small rect's.
- `lib/src/selection_band.dart`: `_edge`'s doc no longer names the deleted `_drawDashedRect`.

M-BP4 (`_dashes.reset();` removed): red in BP4 at `selection_band_test.dart:114`: `Expected: a numeric value within <1e-9> of <300.5>  Actual: <20.5>  Which: differs by <280.0>` (the second band's path still holds the first's dashes). Reverted by copying the file back (`grep -c "_dashes.reset"` = 1).

Re-run: `flutter test test/selection_band_test.dart test/tool_palette_test.dart` gives `+14: All tests passed!`; `flutter analyze`: `No issues found!`; `dart format --output=none --set-exit-if-changed .`: `Formatted 232 files (0 changed)`, exit 0.
