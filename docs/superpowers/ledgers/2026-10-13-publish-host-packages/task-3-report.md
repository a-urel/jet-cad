# Task 3 report: jet_cad_floor_plan 0.7.1 packaged (D3, D11)

Status: DONE_WITH_CONCERNS. Commit 5eec3012 "feat(jet_cad_floor_plan): package 0.7.1 for pub.dev (D3)".

## Per step
1. Baseline: dry run exit 65 (no LICENSE error; 3 issues: repository, README, CHANGELOG); archive listed test/, build?, tool/. `dart doc --dry-run`: "Found 23 warnings and 0 errors."
2. Wrote test/example_test.dart. RED: "Undefined name 'FloorPlanExampleApp'" (loading failed, 1 failed).
3. Wrote example/lib/main.dart verbatim from the brief. GREEN: "+1: All tests passed!".
4. Mutants (copy in scratchpad, restored, cmp ok both):
   - M-FX1 (`sources: const []`): test FAILS, but by the loader's own `ArgumentError: Invalid argument (sources): must not be empty` thrown while building, not by the `isNotEmpty` assertion. It is killed, but the library-entries assertion is not what kills it (see concerns).
   - M-FX2 (`const SizedBox()` for FloorPlanView): FAILS (`findsOneWidget` on FloorPlanView, test line 17).
5. pubspec: publish_to removed, repository, issue_tracker, topics, description (60-180 chars), sdk ^3.6.0 with rewritten comment (pdf 3.13.x binds Flutter floor). LICENSE cmp same as root. .pubignore as brief.
6. README, CHANGELOG as brief; editor.dart library comment extended.
7. dart doc 23 -> 0 ("Found 0 warnings and 0 errors."): backticks for unresolved refs in text_entry_overlay.dart, dimension_geometry.dart (record fields), wall_attach.dart, floor_plan_view.dart; "in [0, 1]" reworded to "in the range 0 to 1" in floor_plan_theme.dart docs (one `[0, 1]` in a doc comment on lerp wrapped in backticks; the ArgumentError message string left unchanged); ambiguous re-export of `readBundledLibrary` (editor and symbol_sources) fixed by `export 'src/symbols/symbol_library_loader.dart' hide readBundledLibrary;` in editor.dart. Nothing in apps/packages/tool imported it from editor.dart (grep); only symbol_sources.dart and a test via src/.
8. Gates: planner `flutter test --enable-vmservice` exit 0, 2011 tests; `expect_failures.dart` printed "packages/jet_cad_floor_plan: 2011 tests; the standing failures and skips, exactly" (exit 0). analyze: No issues. format: 0 changed. apps/floor_planner: +212 passed, analyze clean, format clean. apps/restaurant_demo: +69 passed, analyze clean, format clean. No analysis_options.yaml modified (git status clean after).
9. Committed; dry run on committed state: exit 0, "Package has 0 warnings.", archive 462 KB. Review Focus 1 grep printed 3 lines (Roboto_LICENSE.txt, furniture.jetlib, Roboto-Regular.ttf); the test/tool/build grep printed nothing.
   pana 0.23.19 (git archive copy, test/ build/ tool/ removed): **40/160**. Sections: conventions 20/30 (pubspec 0/10: "Failed to verify repository URL ... has no repository or homepage URL" as the copy is not a git checkout/repo; README 5/5, CHANGELOG 5/5, license Apache-2.0 10/10); documentation 10/20 (dartdoc could not run, resolution failed; example 10/10); platforms 0/20; static analysis 0/50; dependencies 10/40 (latest SDK 10/10; others 0). Every failure but the repository check is "jet_cad_2d_flutter doesn't exist at pub.dev" (version solving). Per R-4 the full run is the human's checklist.

## Files changed
packages/jet_cad_floor_plan/: pubspec.yaml, LICENSE, .pubignore, README.md, CHANGELOG.md, example/lib/main.dart, test/example_test.dart, lib/editor.dart, lib/src/text_entry_overlay.dart, lib/src/parametric/dimension_geometry.dart, lib/src/symbols/wall_attach.dart, lib/src/host/floor_plan_theme.dart, lib/src/host/floor_plan_view.dart.

## Deviations from the brief
- The loaded state class is `SymbolLibraryReady` (not `SymbolLibraryLoaded`), and it is not exported by any public library; the test imports `package:jet_cad_floor_plan/src/symbols/symbol_library_state.dart` (own-package src import; analyzer clean). Its library getter is `.library.entries` as the brief had.
- The test calls `await tester.runAsync(state.symbols.load)` then `pump()` (asset read needs real async); `load()` is once-only so it joins the controller's own load.
- Test carries `// ignore: avoid_relative_lib_imports` with a reason (as Task 2).
- editor.dart gets `hide readBundledLibrary` (doc fix; narrows editor's surface by one symbol, unused anywhere).
- Description text and the example are verbatim; the example needs no probe-driven change (the controller starts the loader itself through `startSymbols` when the view mounts, so no initState load).
- README claims checked against the barrel: tools wall/door/window/room/dimension exist in FloorPlanTool; tables/service/export types are exported; languages en/de/tr.

## Self-review
All README names verified in the barrels: FloorPlanController, FloorPlanView, SymbolLibraryLoader, furnitureSymbolSource, SymbolLibrarySource, SymbolNames, ensureFloorPlanFonts, registerFontLicences, floorPlanSupportedLocales, floorPlanLocalizationsDelegates. `symbols.dart` exports build_library and the catalog types; `symbol_sources.dart` the sources.

## Concerns
- The CHANGELOG (verbatim from the brief) refers to the host guide's "The restaurant symbols" section, which does not exist in docs/host-guide.md yet; Task 6 creates it. Also the README's `mySymbolSource` is a placeholder name.
- M-FX1 dies on the loader's ArgumentError, not on the entries assertion; a mutant that supplies a non-empty but wrong source would test the assertion, not fired.
- pana's low score is the 404s of the two lower packages plus the non-git copy; only the human's post-publication run is informative.

## Fix round 1
CHANGELOG.md, 0.7.1: "a plan either saves opens in the other." became "a plan saved by either release opens in the other." Nothing else changed. Commit e2869e54.
Command: `dart pub -C packages/jet_cad_floor_plan publish --dry-run` on the committed state: exit 0, last line "Package has 0 warnings.". Working tree clean.
