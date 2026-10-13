# Task 2 report: jet_cad_2d_flutter 0.7.1 packaged (D2)

Status: DONE_WITH_CONCERNS. Commit 09153e8b "feat(jet_cad_2d_flutter): package 0.7.1 for pub.dev (D2)".

## Per step
1. Baseline. `dart pub -C packages/jet_cad_2d_flutter publish --dry-run`: one error (no LICENSE in the root directory), one issue (no CHANGELOG.md; the `publish_to` message was not printed, the pubspec gets a different path), archive 1005 KB with test/ inside. `dart doc --dry-run`: "Found 6 warnings and 0 errors" - [this] pdf_content.dart:103; [_bake] tile_cache.dart (kTileSlack, from lines 40/68); [anchor], [centre], [stem] grip_cache.dart:106; [_attach] draft_canvas.dart:131 (drawText, from line 128).
2. RED. test/example_test.dart written as in the brief: `flutter test test/example_test.dart` -> "Error when reading 'example/lib/main.dart': No such file or directory ... Couldn't find constructor 'DraftExampleApp'", "Some tests failed."
3. Example written. GREEN: "00:00 +1: All tests passed!"
   Deviations from the brief's code (real API): `Aabb2.inflate` does not exist, the real method is `expandedBy(20)` (aabb2.dart:72). Everything else matched (DraftDocument.empty(measurer:), addDrafted, linePayload, circlePayload, ViewportTransform.fit, SpatialIndex, CameraController, pickInto, HitPath, QueryFilter.picking). Test: removed the unused `package:flutter/widgets.dart` import (analyzer error) and added `// ignore: avoid_relative_lib_imports` with a one-line reason above the example import.
4. Mutants (copy in scratchpad, restored, cmp clean):
   - M-RX1 (circle command removed): FAIL, "Expected: <2> Actual: <1>".
   - M-RX2 (`document.extents.expandedBy(20)` -> `Aabb2(Vector2(0,0), Vector2(1,1))`): FAIL, "Expected: a value greater than or equal to <500.0> Actual: <1.2017543859649122>".
5. pubspec, LICENSE (cmp equal to root), .pubignore done as in the brief. Description claims checked against the barrel: rulers = RulerFrame (ruler_frame.dart exported); selection = SelectTool/selection*.dart exported; snapping = SnapSettings, drawSnapMarker, ToolContext.snap; PDF/PNG = exportPagePdf/exportPagePng (page_export.dart exported). Kept all.
6. README/CHANGELOG/comments. README claims checked: DraftCanvas, CameraController, ViewportTransform(.fit), RulerFrame, InteractionLayer(tools: ToolController), SelectTool, LineTool, PolylineTool, RectangleTool, CircleTool, ArcTool, TextTool, SnapSettings, drawSnapMarker (it is a function, not a "SnapMarker" widget; written as `drawSnapMarker`), exportPagePdf, exportPagePng, FlutterTextMeasurer - all exported by the barrel. The brief's "selection overlay" / "grips" are in the barrel too. Old README moved with `git mv` to test/README.md unchanged. export_testing.dart library comment and geometry_collector.dart (sentence naming `shaders/cad_stroke.vert` reworded to `cad_stroke.vert` plus "The shader sources are in the repository (`packages/jet_cad_2d_flutter/shaders/`), not in the published package.") edited.
7. dart doc: before "Found 6 warnings and 0 errors."; after "Found 0 warnings and 0 errors." Fixes: pdf_content `[this]`->`this`, `[other]`->`[o]`; `_bake`, `_attach`, anchor/centre/stem code-quoted (tile_cache.dart has several `[_bake]` all quoted, hence 32 changed comment lines).
8. Gate (see below), commit, dry run, pana.

## Gate
- `flutter test --file-reporter json:...` : 1453 tests, 5 failed (the five text_ladder_golden_test.dart goldens, rungs 1-5). `dart run tool/ci/expect_failures.dart --package packages/jet_cad_2d_flutter --root packages/jet_cad_2d_flutter <json>` prints only "standing failure passed or did not run: test/golden/text_lod_ladder_golden_test.dart :: text lod ladder rung 1 / rung 2", exit 1. This is exactly R-1's expected difference (no other difference).
- `flutter analyze`: "No issues found!"
- `dart format --output=none --set-exit-if-changed .`: "Formatted 234 files (0 changed)".
- Engine and gpu gates not re-run (no change to them; only this package's files changed).
- `git diff --cached --stat` listed no analysis_options.yaml; `git status` clean of it.

## Dry run on the committed state
`dart pub -C packages/jet_cad_2d_flutter publish --dry-run`: exit 0, "Total compressed archive size: 226 KB." "Package has 0 warnings." Top level listed: CHANGELOG.md, LICENSE, README.md, analysis_options.yaml, dart_test.yaml, example, lib, pubspec.yaml. No test/, build/ or shaders/ (lib/src/export/testing/ is the intentional export_testing source).

## pana 0.23.19 (git archive HEAD, test/ build/ shaders/ removed)
Total 40/160. Not a meaningful score: `jet_cad_2d` ^0.7.1 is not on pub.dev (404), so "Because jet_cad_2d_flutter depends on jet_cad_2d any which doesn't exist ... version solving failed" and dartdoc, platform detection, analysis and the dependency checks all fail. A scratch copy with a `dependency_overrides` path was tried; pana strips overrides, same result. Sections:
- Dart file conventions 20/30: pubspec 0/10 (repository mismatch: GitHub main still has `https://github.com/ahmeturel/jet-cad` and `publish_to: none`; expected until merge), README 5/5, CHANGELOG 5/5, OSI license 10/10 (Apache-2.0).
- Documentation 10/20: dartdoc 0/10 (dependency resolution failed), example 10/10.
- Platform 0/20, Analysis 0/50 (both: resolution failed), Dependencies 10/40 (latest SDKs 10/10; the other two failed on resolution).
Re-run pana after jet_cad_2d 0.7.1 is published and the branch is on GitHub main.

## Files changed
packages/jet_cad_2d_flutter/: pubspec.yaml, README.md (new text), test/README.md (moved old), LICENSE, .pubignore, CHANGELOG.md, example/lib/main.dart, test/example_test.dart, lib/export_testing.dart, lib/src/{gpu/geometry_collector,tile_cache,grip_cache,draft_canvas,export/testing/pdf_content}.dart.

## Self-review
Version and the jet_cad_2d dependency lines untouched. No screenshots, no publish_to, no push/tag/merge. No shared pubspec keys beyond brief.

## Concerns
- pana score cannot be reached until the engine is on pub.dev (above).
- `packages/jet_cad_2d/README.md` still says the Flutter packages "are not published on pub.dev"; that is now false for this package (and Task 3's). Out of this task's scope; flagged.
- `dart_test.yaml` and `analysis_options.yaml` ship in the archive (the engine's does the same for analysis_options); harmless.
