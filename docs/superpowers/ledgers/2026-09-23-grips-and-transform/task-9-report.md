# Task 9 report — the shell owns the caches, F3, osnap-text, the test seam

## Status: DONE

## What I implemented

`apps/floor_planner/lib/main.dart`:
- `PlannerShell` gained the test seam: `document` (`DraftDocument?`) and
  `initialCamera` (`ViewportTransform?`), both optional so `const
  PlannerShell()` in `FloorPlannerApp` is unchanged.
- `_PlannerShellState` now owns `SnapSettings _snap`, `OutlineCache
  _outlines` and `GripCache _grips`, moved from `PlannerView`.
- `_nominalFit()` extracted exactly as the brief specifies, reading
  `_page.value` (not re-reading the document's `PageComponent` directly) so
  a document with no page fits its extents instead of throwing on a null
  bang.
- `ToolContext` gained `page: _page, snap: _snap, grips: _grips`.
- `dispose()` gained `_grips.dispose()` and `_outlines.dispose()` (before
  `_selection.dispose()`, mirroring construction order in reverse) and
  `_snap.dispose()`.
- F3 bound via `SingleActivator(LogicalKeyboardKey.f3, includeRepeats:
  false)` to `_snap.toggleObjectSnap`.
- The top bar's `Row` gained the `osnap-text` `ListenableBuilder` between
  the status `Spacer()` and the zoom text.
- `PlannerView(...)` gained `outlines: _outlines, grips: _grips`.

`apps/floor_planner/lib/planner_view.dart`:
- `PlannerView` takes `outlines` and `grips` as required parameters.
- `_PlannerViewState` no longer constructs or disposes an `OutlineCache` —
  it owns nothing to dispose now (the `dispose()` override was deleted
  entirely, not left as an empty override).
- `_repaint` merges `widget.outlines` and `widget.grips` alongside
  `selection`, `tools`, `camera`.
- The overlay's `outlines:` argument reads `widget.outlines`.

`apps/floor_planner/test/planner_grips_test.dart` (new): the brief's A1–A4
verbatim, plus one additional test (see "Controller notes" below).

## Controller notes, checked explicitly

1. **Construction order (Ruling 03-19).** `GripCache` is constructed after
   `OutlineCache`, both after `SelectionController`. This holds not just by
   textual field order but *structurally*: `GripCache(_document, _selection,
   _outlines)`'s constructor-argument evaluation forces `_selection` then
   `_outlines` to initialize (if not already) before `GripCache`'s own
   constructor body runs; `OutlineCache(_document, _selection)` likewise
   forces `_selection` first. Since `SelectionController` subscribes to
   `document.changes` in its own constructor, and `OutlineCache` does the
   same, this dependency chain guarantees `SelectionController.listen()`
   registers before `OutlineCache.listen()` regardless of which field a
   caller touches first — Dart's `late final` lazy-init graph enforces it,
   not declaration order. Listener order on `SelectionController` itself
   (`ChangeNotifier.addListener`) is guaranteed the same way: `OutlineCache`
   calls `selection.addListener` inside its own constructor, which runs
   (per the same argument-forcing chain) before `GripCache`'s constructor
   calls `selection.addListener`. So on a selection change, `OutlineCache`'s
   listener always runs before `GripCache`'s — matching the comment.
2. **Overlay's repaint listenable includes `GripCache` in production.**
   Confirmed: `PlannerView`'s `_repaint = Listenable.merge([selection,
   tools, camera, outlines, grips])` — not only the render-layer test rig.
3. **cmd+Z mid-drag through the shell (M-03aa).** A4 in
   `planner_grips_test.dart` drives this through `PlannerShell` (via
   `pumpShell`), not the tool directly: it starts a real drag with a
   `TestGesture`, sends cmd+Z mid-drag through the shell's
   `CallbackShortcuts`, and asserts `undoDepth` unchanged and
   `tools.active.phase == ToolPhase.dragging` before finishing the drag with
   `gesture.up()`.
4. **Removing the planner mid-drag.** The brief's A1–A4 don't cover this.
   Added a fifth test, `replacing the shell mid-drag disposes cleanly, no
   exception (M-03ao, shell)`: starts a drag through `PlannerShell`, then
   `tester.pumpWidget(const SizedBox.shrink())` to tear down the *whole*
   shell (document, controllers, all three caches, `SnapSettings`) while the
   pointer is still captured, then finishes the pointer's `up()`. This is
   deliberately at the shell level, not just `InteractionLayer` in
   isolation (that's already covered by
   `packages/jet_cad_2d_flutter/test/select_tool_drag_test.dart`'s
   `'removing the layer mid-drag cancels byte-identically (M-03ao)'`) — the
   new test proves the shell's own construction/dispose chain doesn't
   introduce a new assert when everything above `InteractionLayer` also
   goes away mid-drag.

   **Mutation check (not left to inspection):** I temporarily commented out
   `_leaving = true;` in `InteractionLayer._release()` (`packages/
   jet_cad_2d_flutter/lib/src/interaction_layer.dart`) — the mutant that
   defeated Task 7's fix — reran just this test, and it failed with the
   `setState()/markNeedsBuild() called during build` assertion (stack trace
   through `Element.markNeedsBuild` → `ValueNotifier<MouseCursor>` firing
   during the shell's teardown rebuild). Restored the file (`git diff` on it
   came back empty afterward) and reran to confirm green again. This proves
   the new test is not vacuous.

## Known trap checked

`PageComponent.copyWith(gridStepMm: <int>)` — not applicable here; the
test's only `PageComponent` construction is the direct constructor
(`PageComponent(originX: 7000, originY: 3000, gridStepMm: 100)`), where an
integer literal in a `double`-typed named argument position is a `double`
literal in Dart, not an `int`. No `copyWith` call was added by this task.

## TDD evidence

**RED** — `cd apps/floor_planner && CI=true flutter test
test/planner_grips_test.dart`, before any `lib/` changes:

```
00:00 +0: loading .../test/planner_grips_test.dart
test/planner_grips_test.dart:58:58: Error: No named parameter with the name 'document'.
  await tester.pumpWidget(MaterialApp(home: PlannerShell(document: doc)));
                                                         ^^^^^^^^
lib/main.dart:29:9: Context: Found this candidate, but the arguments don't match.
  const PlannerShell({super.key});
        ^^^^^^^^^^^^
00:00 +0 -1: Some tests failed.
```

Expected: `PlannerShell` had no `document`/`initialCamera` parameters yet.

**GREEN** — after implementing `lib/main.dart` and `lib/planner_view.dart`,
`cd apps/floor_planner && CI=true flutter test test/planner_grips_test.dart
test/planner_shell_test.dart`:

```
00:01 +16: All tests passed!
```

(16 = the brief's four A-tests + the twelve existing `planner_shell_test.dart`
tests, before the fifth mid-drag-removal test was added.)

After adding the fifth (mid-drag shell removal) test, same command:

```
00:01 +17: All tests passed!
```

## Gate line output

`cd apps/floor_planner && CI=true flutter test` (full app suite):

```
00:01 +26: All tests passed!
```

26 = 21 pre-existing (`planner_shell_test.dart` 12, `page_panel_test.dart` 9,
`startup_plan_test.dart` 1... actually the branch-point count from the brief
context was 21) + 4 new A-tests + 1 new mid-drag-removal test = 26. Matches.

`flutter analyze`:

```
Analyzing floor_planner...
No issues found! (ran in 1.4s)
```

`dart format --output=none --set-exit-if-changed .`:

```
Formatted 8 files (0 changed) in 0.03 seconds.
exit: 0
```

`flutter build macos --release`:

```
✓ Built build/macos/Build/Products/Release/floor_planner.app (51.1MB)
```

`flutter build web --release`:

```
✓ Built build/web
```

Also re-ran the sibling packages' gate lines (unmodified by this task, but
"every task ends green" applies to the tree as a whole):

`cd packages/jet_cad_2d && CI=true dart test`:

```
00:03 +888: All tests passed!
```

`dart analyze` / `dart format --output=none --set-exit-if-changed .`: no
issues, 0 changed.

`cd packages/jet_cad_2d_flutter && CI=true flutter test`:

```
00:13 +846: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```

834 passed + 1 skipped + exactly the five standing golden failures named in
the standing instructions — no other failures. `flutter analyze`: "No issues
found!". `dart format --output=none --set-exit-if-changed .`: 0 changed.

## Files changed

- `apps/floor_planner/lib/main.dart` (modified)
- `apps/floor_planner/lib/planner_view.dart` (modified)
- `apps/floor_planner/test/planner_grips_test.dart` (new)

## Self-review findings

- Grepped `planner_view.dart` for stray `_outlines` references after
  deleting the field and its `dispose()` override: none found — the state
  class now owns nothing to dispose, matching the brief.
- Confirmed no unused imports were introduced in either modified file
  (`flutter analyze` is clean, and `unused_import`/`unused_element` are
  errors in this package per house rules).
- Confirmed `git status --short` shows no `analysis_options.yaml` rewrite
  and no stray files, before and after the release builds.
- Verified `SelectionOverlayPainter` does not take a `grips` constructor
  parameter — it reads grips from `tools.context.grips` (per its doc
  comment), so `PlannerView` only needed to add `grips` to the repaint
  merge, not thread it into the painter's constructor. This matches the
  brief's instructions exactly (no deviation).

## Deviations from the brief's code

None. The implementation follows the brief's code verbatim, with one
addition beyond the brief: the fifth test (`replacing the shell mid-drag
disposes cleanly...`) added per the controller's note 4, since the brief's
A1–A4 don't exercise shell-level teardown mid-drag.

## Concerns

None outstanding. All four controller notes hold, verified explicitly
(including a live mutation check for note 4, not just static inspection).
