# Task 1 report — the page camera and the export fixture (spec D2, T-1)

**Commit:** `c96bb9b` feat(render): the page camera for export (on top of `7fab442`; not pushed).

## Files
- `packages/jet_cad_2d_flutter/lib/src/export/page_camera.dart` (new): `PageCamera {camera, size, pixelsPerPaperMm}`, `pageCamera(page, u)`; matrix `Transform2(k, 0, 0, -k, -S.minX*k, S.maxY*k)`, `k = u/den`, size `(effW*u, effH*u)` unrounded, `ArgumentError` for non-finite / non-positive `u`. Reads only the page.
- `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart`: `export 'src/export/page_camera.dart';`
- `packages/jet_cad_2d_flutter/test/export/page_camera_test.dart` (new): T-1, 16 tests.
- `packages/jet_cad_2d_flutter/test/support/export_fixture.dart` (new): `exportFixture({scaleDenominator = 50, measurer = InsertionPointMeasurer})` returning `ExportFixture` with `document`, `page` and named handles: `instance`, `definition`, `instanceLine`, `instancePolyline`, `pointInInstance`, `separatorGroup`, `separatorLine`, `outerGroup`, `outerGroupLine`, `outerGroupInstance`, `outerDefinition`, `outerInstanceLeaf`, `nestedGroup`, `nestedLine`, `line`, `closedPolyline`, `dashed`, `arc`, `circle`, `fill`, `fillBoundary`, `labelBig`, `labelWc`, `aci7Line`, `outsideLine`. Constants: `kExportOriginX/Y`, `kExportBackground`, `kExportDashedLinetype` (values copied from the app's `kDashedLinetypeRecord`: handle 6, `[200, -100]`, total 300), `kExportInstanceTransform`, `kExportInstanceRgb` 0xFF0000, `kExportInstanceLineweight` 70, `kExportArcSweep` (-110 deg), `kExportFillTransparency` 127 (alpha 0x80).
- `packages/jet_cad_2d_flutter/test/support/export_fixture_test.dart` (new): 7 tests pinning non-degeneracy (page origin (3000,-1500), A4 landscape 1:50, background 0xFF303030; instance transform not identity, rotation 30 deg, scale (1.5,-0.75) checked entry by entry; colour/lineweight overrides != ByBlock; basePoint != origin; BYBLOCK leaves; root leaves have explicit colour and lineweight; ACI 7; fill transparency 127; DASHED; outer group has own line, own instance, nested group with a line; separator is a childless group with exactly one dashed polyline; everything but the outside line inside the sheet, and the outside line outside).

Fixture geometry (world mm): sheet x 3000..17850, y -1500..9000 at 1:50. Instance at (7000, 5600), so it maps to (80, 68) paper mm from the sheet's top-left — the page camera test pins that.

## Gates
Render (`CI=true flutter test`), real tail:
```
00:55 +1023 ~1 -7: Some tests failed.
```
1,001 + 22 new = 1,023 passed, 1 skip, 7 failing = the standing Linux golden failures, exactly:
```
test/golden/text_ladder_golden_test.dart: text ladder rung 1..5 (RenderBackend.canvas) [E]   (5)
test/golden/text_lod_ladder_golden_test.dart: text lod ladder rung 1, 2 (RenderBackend.canvas) [E]   (2)
```
`CI=true flutter analyze`: `No issues found! (ran in 4.9s)`.
`CI=true dart format --output=none --set-exit-if-changed .`: `Formatted 186 files (0 changed)`, exit 0.
Engine and app: **not re-run, unchanged** — this task touches only the render package (no pubspec): `git diff --stat 7fab442 -- packages/jet_cad_2d apps` is empty. Goldens and the two allocation invariant tests: `git diff --stat` empty. `analysis_options.yaml` not staged.

## Mutants (all fired with cp backup, one file test run in the foreground, cp back, `diff` exit 0)
| id | file:line | mutation | red | real output |
|---|---|---|---|---|
| M-13f | page_camera.dart:48 | `sheetWorldRect(page)` -> `sheetWorldRect(page.copyWith(originX: 0, originY: 0))` | page_camera_test: corners x3, above-sheet x3, instance origin | `00:00 +8 -7: Some tests failed.` |
| M-13g | page_camera.dart:56,58 | `-k` -> `k` and `sheet.maxY * k` -> `-sheet.minY * k` (y' = (y - minY)k: no flip; two lines, the faithful form) | corners x3, 1,000 mm segment x3, above-sheet x3, instance origin | `00:00 +5 -10: Some tests failed.` |
| M-13g' | page_camera.dart:56 | one-line variant: only `-k` -> `k` | same | `00:00 +5 -10: Some tests failed.` |
| FX-1 | export_fixture.dart:99 | instance scale (1.5, -0.75) -> (1.5, 0.75) | export_fixture_test "the instance: rotated 30 degrees, scaled (1.5, -0.75), overrides" | `00:00 +6 -1: Some tests failed.` |
| FX-2 | export_fixture.dart:109 | fill transparency 127 -> 0 | export_fixture_test "root leaves carry their own colour and lineweight" | `00:00 +6 -1: Some tests failed.` |

`size and pixelsPerPaperMm`, `the size is unrounded at 150 dpi` and the ArgumentError test are not killed by M-13f/g (they are about size, not the matrix); a mutant rounding the size (`.roundToDouble()`) or dropping the guard would be theirs — not fired, they are not plan-named.

## What the spec / plan got wrong or left open
1. **`basePoint` is not read by the renderer.** `grep basePoint` finds it only in `jet_cad_2d/lib/src/document/node.dart` and `src/testing/generate_document.dart`; neither `DraftPainter`, `referenceWalk` nor anything in the render lib reads it. The fixture's non-origin `basePoint` (120, 45) is therefore a stored value only: it cannot make any export test go red. The spec's Testing paragraph implies it is exercised.
2. **The spec's Architecture table** still lists `test/support/pdf_content.dart`; plan P-2 moves the reader to `lib/src/export/testing/pdf_content.dart`. The plan wins; noted for Task 3.
3. **"No style equals its default" vs the separator.** The fixture's separator line is ByLayer colour, DASHED, lw 35 — the real separator's style (F-8), kept deliberately so the render-side "separator" matches what the app generates. Every other leaf names its own colour and lineweight; the instance's leaves are BYBLOCK by design (they carry the overrides).
4. The plan names handles `separatorGroup` etc.; I added `separatorLine`, `definition`, `instanceLine`, `instancePolyline`, `outerDefinition`, `outerInstanceLeaf`, `fillBoundary` so later tasks can name leaves without searching.

## Decisions
- `exportFixture` takes `scaleDenominator` (T-4 needs 1:100; origin unchanged) and `measurer` (Tasks 5/6 pass a `FlutterTextMeasurer`). Handles come from `doc.handleSeed`, so draw order follows creation order.
- Its leaves are written by private helpers in the fixture file (no change to the shared `fixtures.dart`).
