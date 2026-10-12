# Report: plan colours Slice 2, Task 1 (the page export's underlay)

Status: DONE (one commit, `fd750181`). Worktree `plan-colors-2`, branch `feat/plan-colors-slice-2`.

## Implemented

- `lib/src/export/page_underlay.dart` (new): sealed `PageUnderlayFill`
  (`placement`, `argb`), `PageUnderlayPolygon` (throws `ArgumentError` for empty
  `triangles`, `count < 4`, `count * 2 > xy.length`), `PageUnderlayCircle`,
  and `drawPageUnderlay(sink, camera, fills)` exactly as the brief's body
  (`ResolvedStyle(argb, 0, continuousLinetype, 1)`, `beginResidual(world.multiply(placement))`,
  `fillPolygon`/`fillCircle`, `endResidual`).
- `page_export.dart`: `underlay` (named, default `const []`) on `exportPagePdf` and
  `exportPagePng`; `drawPageUnderlay` runs inside `_withExportIndex`'s callback
  after the sink exists (PNG: after the `drawPaint` ground; PDF: before the painter),
  only when `underlay.isNotEmpty`; both doc comments gained the bullet.
- Barrel: `export 'src/export/page_underlay.dart';`.
- `test/export/page_underlay_test.dart` (new): PU1-PU5.

Files: `packages/jet_cad_2d_flutter/lib/src/export/page_underlay.dart`,
`.../lib/src/export/page_export.dart`, `.../lib/jet_cad_2d_flutter.dart`,
`.../test/export/page_underlay_test.dart`.

## Fixture
Page A4 landscape 1:50, origin world (3000, -1500), white. Placement
`translation(4000.5, 2500.25) . rotation(0.7) . scale(1, -1)`. L polygon and circle
`(600.5, -350.25, r 180)` as the brief; ARGB `0x9900897B` (teal) and `0x998E24AA` (purple).
One thick (1.0 mm) black LINE through the world image of local (600, 200). Every
expected point is computed forward from the literals with the explicit formula
`wx = 4000.5 + x cos0.7 + y sin0.7`, `wy = 2500.25 + x sin0.7 - y cos0.7` (not
`pageCamera`, not `Transform2` of the code under test). PU5's expected residual is
written out algebraically (k = u/50), compared at 1e-9.

## TDD evidence
- RED: implementation removed (page_export.dart and the barrel restored with
  `git show HEAD:... >`, `page_underlay.dart` moved aside), then
  `flutter test test/export/page_underlay_test.dart` printed
  `Error: Method not found: 'drawPageUnderlay'`, `Method not found: 'PageUnderlayPolygon'`, `... exportPagePdf ... ^^^` (no `underlay` parameter), ending
  `00:00 +0 -1: Some tests failed.` (loading failed: compile errors).
  Honest note: I wrote the implementation before the tests and removed it afterwards to
  record the RED; the compile-error RED is the same one a test-first run would give.
- GREEN: first run had two failures from my own test mistakes (see Deviations), then
  `00:00 +10: All tests passed!`.

## Gates
- `packages/jet_cad_2d_flutter`: `flutter test --file-reporter json:/tmp/s2t1-render.json`:
  1600 success, 5 error (the five `text_ladder_golden_test.dart` rungs 1-5, standing).
  `dart run tool/ci/expect_failures.dart --package packages/jet_cad_2d_flutter --root packages/jet_cad_2d_flutter /tmp/s2t1-render.json` exits 1 and names only
  `test/golden/text_lod_ladder_golden_test.dart :: text lod ladder rung 1 / rung 2 (RenderBackend.canvas)` as
  "standing failure passed or did not run": the recorded macOS standing difference. All
  `page_underlay` tests pass in the run.
  `flutter analyze`: `No issues found!`. `dart format --output=none --set-exit-if-changed .`: `Formatted 230 files (0 changed)`, exit 0.
- `packages/jet_cad_2d_gpu`: `flutter test` -> `+20: All tests passed!`; analyze `No issues found!`; format 0 changed.
- `packages/jet_cad_floor_plan`: `flutter test --enable-vmservice` -> `+1949: All tests passed!`; analyze `No issues found!`; format 0 changed.
- `jet_cad_2d` untouched (not run). No `analysis_options.yaml` in the commit (`git status` clean after it).

## Mutants (each applied, run `flutter test test/export/page_underlay_test.dart`, reverted by copying the pre-saved file back and `cmp`-verifying)
- **M-C7a** `sink.beginResidual(world)`: red in PU1 (`Expected: a value less than or equal to <2>  Actual: <153>`), PU2 (`within <0.00063> of <69.0457>  Actual: <-158.74>`), PU5 (`within <1e-9> of <0.0903>  Actual: <0.1181>`), also PU3-PNG.
- **M-C7b** `world.multiply(Transform2.translation(placement.e, placement.f))`: red in PU1 (`Actual: <85>`), PU2 (`Actual: <68.05926>` vs 69.0457), PU5.
- **M-PU-a** underlay after the document (both PNG and PDF sites): red in PU1 (`Expected: [0, 0, 0, 255]  Actual: [0, 82, 74, 255]`, the line pixel tinted teal), PU2 (`Expected: a value less than <11>  Actual: <25>`, operator order).
- **M-PU-b** circle as a 65-point `fillPolygon` fan: red in PU2 (`isCubic` -> `Expected: true  Actual: <false>`) and PU5 (`Expected: FillCircleOp ... Actual: FillPolygonOp`).
- **M-PU-c** `beginResidual(world); endResidual()` before the loop: red in PU3's sink test
  (`drawPageUnderlay([]) does not touch the sink`: `Expected: empty  Actual: [`) and PU5 (`Expected: an object with length of <6>`).
  The byte-equality PU3 legs do NOT kill it (see Deviations).

## Deviations from the brief (real API)
1. PDF vertices: `PdfContentSubpath.vertices` are already mapped through the CTM by the reader, so the test compares them as they come (not "mapped through `state.ctm`" again, which doubled the transform in my first draft).
2. PDF tolerance: the `pdf` package writes every number, CTM entries included, to 5 decimals; 1e-6 pt is unattainable (observed 4.8e-4 pt). The test uses the repo's `pdfTolerance(...)` from `test/support/pdf_tolerance.dart` with the hand-written residual (a few thousandths of a point; the mutants still miss by 1 to 200 pt).
3. PU3 PDF: the `pdf` package writes a random trailer `/ID` per write, so two writes of one document are never byte-equal (first diff at byte 271 of an empty document). The test blanks `/ID[<..><..>]` (same length) and compares the rest. I also assert a non-empty underlay differs, so the comparison can fail.
4. M-PU-c: `CanvasDrawSink` and `PdfDrawSink` both push the residual lazily (only on the first primitive), so an empty `beginResidual/endResidual` pair changes no bytes; PU3's byte legs cannot kill it. I added a third PU3 test on a `RecordingDrawSink` (`drawPageUnderlay(..., [])` records no ops), which does; PU5 kills it too. Brief's "Killer: PU3" is met by that leg.
5. `RecordingDrawSink` is in `lib/src/draw_sink.dart` (exported via the barrel); `ResolvedStyle`/`triangulateSimplePolygon`/`ReservedHandles` come from `jet_cad_2d`. `ViewportTransform` is imported relatively in the new file.
6. PU1's second "inside the L" pixel is local (850, 150) (my first choice, (800, 250), was ~3 px from the thick line's edge); it is not in the brief.
7. Extra PU4 cases: `count < 4`, and an accepted well-formed polygon.

## Self-review
- Alpha is used as given (no export-side opacity), matching the interface.
- `underlay.isNotEmpty` guard keeps the empty path byte-identical (PNG bytes equal; PDF equal modulo `/ID`).
- Draw order: fills in list order, before the painter; PU2 asserts fill < fill < first stroke by `operatorIndex`.
- Fixture is non-degenerate: turned, mirrored, off-origin, asymmetric L, off-centre circle; the "unmirrored circle" probe pixel is white.
- No existing signature changed; only one new optional named parameter per export function; no existing test edited.

## Concerns
- `PageUnderlayPolygon` validates shape only (not that `triangles` indexes within `count`); out of scope for the brief.
- The PNG tests read pixels at 150 dpi with a +-2 channel tolerance; AA only matters at fill edges, which no probe sits on.
