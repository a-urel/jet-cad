# Task 5 report — Tool and ToolContext additions, SnapSettings, the cursor rebuild

## What I implemented

- `packages/jet_cad_2d_flutter/lib/src/snap_settings.dart` (new): `SnapSettings extends ChangeNotifier` with `objectSnap` (default `true`) and `toggleObjectSnap()`.
- `packages/jet_cad_2d_flutter/lib/src/tool.dart`:
  - `services.dart` import widened to include `MouseCursor`; added imports for `grip_cache.dart`, `page_notifier.dart`, `snap_settings.dart`.
  - `ToolContext` gained three optional fields: `PageNotifier? page`, `SnapSettings? snap`, `GripCache? grips`, all defaulting to null so every existing call site (all of which use only the four required named args) still compiles unchanged.
  - `abstract class Tool` gained three members with defaults, after `paintOverlay`: `MouseCursor get cursor => MouseCursor.defer;`, `Transform2? get selectionPreviewTransform => null;`, `void paintWorldOverlay(Canvas canvas, Vector2 origin, double scale) {}`.
- `packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart`: `build` now wraps the `MouseRegion` in a `ListenableBuilder` listening to `widget.tools` (the `ToolController`), so `MouseRegion.cursor` tracks `_tool.cursor` and rebuilds only on a tool notification or swap; the `Listener` subtree (pointer routing) is passed as the builder's cached `child` and is not rebuilt.
- `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart`: added `export 'src/snap_settings.dart';` after `src/selection_style.dart` (alphabetically correct — falls before `src/tile_cache.dart`).
- `packages/jet_cad_2d_flutter/test/interaction_cursor_test.dart` (new, I1): the exact test given in the brief, verbatim.

No deviations from the brief's code.

## TDD evidence

**RED.** Command:
```
CI=true flutter test test/interaction_cursor_test.dart
```
Result (tail):
```
00:00 +0: the MouseRegion follows the active tool's cursor (spec D5, M-03ab)
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════
The following TestFailure was thrown running a test:
Expected: SystemMouseCursor:<SystemMouseCursor(move)>
  Actual: _DeferringMouseCursor:<defer>
a notification rebuilds the MouseRegion
...
00:00 +0 -1: the MouseRegion follows the active tool's cursor (spec D5, M-03ab) [E]
  Test failed. See exception logs above.
00:00 +0 -1: Some tests failed.
```
Note: the brief predicted this would fail as a *compile* error ("`cursor` is not a member of `Tool`"). It did not — `@override MouseCursor get cursor => _cursor;` on `_CursorTool` is syntactically just a new member with a (currently harmless) `@override` annotation; Dart does not reject an `@override` on a name absent from the supertype as a compile error, only as an analyzer hint. The test instead ran and failed at the first assertion that depends on the tool's cursor reaching the widget, which is RED for the same underlying reason (the wiring doesn't exist yet). I did not change the test to force a compile error, since the brief's test text is verbatim and this is a legitimate red for the feature under test.

**GREEN.** Command:
```
CI=true flutter test test/interaction_cursor_test.dart test/interaction_layer_test.dart test/tool_controller_test.dart
```
Result (tail):
```
00:00 +13: All tests passed!
```
(`tool_controller_test.dart` also passed when run standalone: `00:00 +2: All tests passed!` — confirms `_CountingTool` still compiles and passes with no new overrides.)

## Gate line (packages/jet_cad_2d_flutter)

```
cd packages/jet_cad_2d_flutter && flutter test
```
Tail:
```
00:11 +806 ~1 -5: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```
806 pass (up from the 805 pass + 1 skip baseline noted in the dispatch — the new test file added 1 test, and the previously-skipped test's count folds into the run total differently across `flutter test` invocations; the failing set is exactly the five standing golden failures named in the standing instructions, nothing else). Exit code 1, as documented ("exits 1 on exactly five standing ... failures; any other failure is yours").

```
flutter analyze
```
```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.6s)
```
Exit code 0.

```
dart format --output=none --set-exit-if-changed .
```
```
Formatted 153 files (0 changed) in 0.27 seconds.
```
Exit code 0.

## Files changed

- `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` (modified)
- `packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart` (modified)
- `packages/jet_cad_2d_flutter/lib/src/snap_settings.dart` (new)
- `packages/jet_cad_2d_flutter/lib/src/tool.dart` (modified)
- `packages/jet_cad_2d_flutter/test/interaction_cursor_test.dart` (new)

## Self-review

- Diffed the commit against the brief's code blocks: `snap_settings.dart`, the `tool.dart` import list and `ToolContext`/`Tool` additions, `interaction_layer.dart`'s `build`, and the barrel export all match verbatim.
- `git status --short` before staging showed no `analysis_options.yaml` rewrite; nothing needed reverting.
- Checked every pre-existing `ToolContext(...)` call site (`test/tool_controller_test.dart`, `test/selection_overlay_test.dart`, `test/select_tool_test.dart`, `test/support/selection_fixture.dart`) — all use only the four required named args, so they compile unchanged against the new optional fields.
- Checked `_CountingTool` (`test/tool_controller_test.dart`) — it overrides none of the three new members and both its tests still pass, confirming the defaults are load-bearing.
- Mutation check (by hand, not executed as a separate mutant): flipping the new `ListenableBuilder`'s `listenable:` from `widget.tools` to nothing (i.e. reverting to a plain `MouseRegion(cursor: _tool.cursor, ...)` with no rebuild trigger) would make the I1 test's second and third assertions (`SystemMouseCursors.move`, then `.grabbing`) fail, since `build` is never called again on a bare `notifyListeners()` from the tool with no listener attached to that state's `build`. This confirms the test is not a degenerate pass — it depends on the rebuild wiring, not just the initial cursor value.
- No unused imports: `MouseCursor`, `grip_cache.dart`, `page_notifier.dart`, `snap_settings.dart` are all referenced in `tool.dart`; `flutter analyze` (which treats `unused_import`/`unused_element` as errors in this package) found no issues.

## Concerns

None. `paintWorldOverlay` and `selectionPreviewTransform` are wired into `Tool`'s contract per the brief but are not yet called from any painter — that's expected, since wiring the overlay painter to them is a later task in this plan, not part of Task 5's scope per the brief.
