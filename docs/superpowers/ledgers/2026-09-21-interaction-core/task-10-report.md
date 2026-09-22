# Task 10 report: the app — controllers on the shell, the interaction tree, the status text

## What was implemented

`apps/floor_planner/lib/main.dart` (`_PlannerShellState`):
- `late final SelectionController _selection = SelectionController(_document);`
  constructed **before** the tool context/controller, so its listener on
  `document.changes` runs first and prunes dead selection keys before
  `PlannerView`'s `OutlineCache` (also listening on `document.changes`) walks
  them.
- `late final ToolContext _context` and `late final ToolController _tools =
  ToolController(initial: SelectTool(), context: _context)`.
- `late final Listenable _status = Listenable.merge([_selection, _tools]);`
  and `String _statusLine()` returning `'${_tools.active.name}'` alone when
  the selection is empty, or with `' — ${_selection.length} selected'`
  (em dash, U+2014) appended otherwise.
- `dispose()` now runs `_tools.dispose(); _selection.dispose();` before
  `_camera.dispose()`.
- `chrome-top` is now a `Container` with an `Align(alignment:
  Alignment.centerLeft, child: Padding(..., child: ListenableBuilder(
  listenable: _status, builder: ... Text(_statusLine(), key: const
  Key('status-text')))))`.
- `PlannerView` is constructed with the new `selection: _selection, tools:
  _tools` arguments.

`apps/floor_planner/lib/planner_view.dart`:
- `PlannerView` gained two required public fields, `selection` and `tools`
  (`SelectionController`, `ToolController`), reachable from tests through
  `tester.widget<PlannerView>(...)`.
- `_PlannerViewState` gained `late final OutlineCache _outlines =
  OutlineCache(widget.document, widget.selection);` and `late final
  Listenable _repaint = Listenable.merge([widget.selection, widget.tools,
  widget.camera]);`, with `_outlines.dispose()` added to `dispose()`.
- The view tree inside `CameraGestureDetector` is now:
  `InteractionLayer(tools: widget.tools, child: Stack([DraftCanvas(...),
  Positioned.fill(RepaintBoundary(CustomPaint(painter:
  SelectionOverlayPainter(...), size: Size.infinite)))]))`, matching the
  Architecture spec and the brief's Step 2 code exactly.

`apps/floor_planner/test/planner_shell_test.dart`: three new tests appended
(existing four left unedited); imports added for `flutter/rendering.dart`
(`RenderCustomPaint`), `jet_cad_2d` and `vector_math_64`'s `Vector2`.

## Departures

- `RenderCustomPaint` is not re-exported by `package:flutter/widgets.dart`
  (that barrel only re-exports `TextSelectionHandleType` from
  `rendering.dart`), so test 2 needed an explicit `import
  'package:flutter/rendering.dart' show RenderCustomPaint;`. A local, obvious
  fix — recorded here per the brief's "ambiguity" note, though this wasn't
  ambiguous, just a missing import the brief didn't call out.
- Test 3 does not call `tester.binding.setSurfaceSize` — the default widget
  test surface is already 800×600 (verified: the probe point mapped inside
  the `InteractionLayer`'s bounds without it), so the extra call in the
  brief's own test 4 (unrelated, pre-existing) was not needed here.

## TDD evidence

**RED** — appended the three tests (importing `PlannerView.selection` /
`.tools`, which did not exist yet, and `RenderCustomPaint`, not yet
imported) and ran:

```
$ CI=true flutter test test/planner_shell_test.dart
...
test/planner_shell_test.dart:110:29: Error: 'RenderCustomPaint' isn't a type.
        tester.renderObject<RenderCustomPaint>(overlayFinder).size;
                            ^^^^^^^^^^^^^^^^^
test/planner_shell_test.dart:94:10: Error: The getter 'selection' isn't defined for the type 'PlannerView'.
    view.selection.replace([key!]);
         ^^^^^^^^^
test/planner_shell_test.dart:130:17: Error: The getter 'selection' isn't defined for the type 'PlannerView'.
    expect(view.selection.length, 1);
                ^^^^^^^^^
00:00 +0 -1: Some tests failed.
```

(Added the `RenderCustomPaint` import before implementing the app code, since
it is a test-file-only fix; the `selection`/`tools` failures are the ones
Step 2 addresses.)

**GREEN** — after implementing `main.dart` and `planner_view.dart`:

```
$ CI=true flutter test test/planner_shell_test.dart
00:00 +0: the shell shows a canvas over a non-empty, off-origin plan
00:00 +1: the camera is fitted to the real viewport on first layout
00:00 +2: the three chrome slots are laid out and empty
00:00 +3: a resize after the first layout does not re-fit the camera
00:00 +4: the status text shows the tool name and follows the selection
00:00 +5: the interaction tree is in place
00:00 +6: a click on a wall selects it in the running shell
00:00 +7: All tests passed!
```

Full app test suite (includes `startup_plan_test.dart`):

```
$ CI=true flutter test
...
00:00 +11: All tests passed!
```

## App gate line (all four commands plus both builds)

```
$ cd apps/floor_planner && CI=true flutter test && flutter analyze \
    && dart format --output=none --set-exit-if-changed . \
    && flutter build macos --debug && flutter build web
```

- `CI=true flutter test`: `All tests passed!` (11 tests, exit 0).
- `flutter analyze`: `Analyzing floor_planner... No issues found! (ran in 1.4s)` (exit 0).
- `dart format --output=none --set-exit-if-changed .`: after one initial
  `dart format .` pass to reformat the freshly appended test code (its line
  wrapping did not match `dart format`'s own choices), the check reported
  `Formatted 5 files (0 changed)` — exit 0.
- `flutter build macos --debug`: `✓ Built build/macos/Build/Products/Debug/floor_planner.app` (exit 0). One pre-existing warning, unrelated to this change: `Run script build phase 'Run Script' will be run during every build...` (Xcode "Flutter Assemble" target).
- `flutter build web`: `✓ Built build/web` (exit 0). Pre-existing informational notes only (wasm dry-run suggestion, MaterialIcons tree-shaking).

Render package check (barrel consumed by the app; a name collision would
show here too):

```
$ cd packages/jet_cad_2d_flutter && CI=true flutter analyze
Analyzing jet_cad_2d_flutter... No issues found! (ran in 1.2s)
```

`git status --short` after both builds showed only the three intended
source files modified — no `analysis_options.yaml` was rewritten by
`pub get`/`flutter build` in this run, so nothing needed a `git checkout --`.

## Trailer check

```
$ git log -1 --format=%B | grep -c "Fable 5.1"
1
```

## Files changed

- `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-02-interaction-core/apps/floor_planner/lib/main.dart`
- `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-02-interaction-core/apps/floor_planner/lib/planner_view.dart`
- `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-02-interaction-core/apps/floor_planner/test/planner_shell_test.dart`

Commit: `e6eb713 feat(app): selection, hover and band in the floor planner; tool name and count in the top bar`

## Self-review

- Listener-order constraint honoured: `_selection` is a `late final` field
  declared and initialized before `_context`/`_tools` in `_PlannerShellState`,
  and `OutlineCache` is constructed in `_PlannerViewState` from the
  shell-owned `_selection` passed down through `widget.selection` — the
  shell's controller is already subscribed to `document.changes` by the time
  the view's `OutlineCache` subscribes (it is constructed later, in a
  different widget's `initState`/`late final` chain, always after the
  shell's own field initializers have run since the shell built `PlannerView`
  as a child).
- Dispose order matches the brief: shell disposes `_tools` then `_selection`
  before `_camera`; view disposes `_outlines`.
- `DraftCanvas` is not wrapped in an extra `RepaintBoundary` — it already
  provides its own (confirmed by reading `draft_canvas.dart`'s existing
  structure) — and the overlay's `CustomPaint` sits inside
  `Positioned.fill(RepaintBoundary(...))` with `size: Size.infinite`, per the
  brief, so it is not laid out at zero in the loose `Stack`.
- Verified via the "interaction tree" test that the `RenderCustomPaint` for
  the overlay actually resolves to the same size as `DraftCanvas`, not just
  that the widget exists.
- `find.byWidgetPredicate((w) => w is CustomPaint && w.painter is
  SelectionOverlayPainter)` uses the renamed class directly, per the task's
  explicit instruction that every brief mention of `SelectionOverlay` means
  `SelectionOverlayPainter`. No `hide` was needed anywhere — `flutter/
  material.dart` and the barrel do not collide (confirmed by both `flutter
  analyze` runs reporting no issues).
- The wall-probe point `(kPlanOriginX + 100, kPlanOriginY)` was checked, not
  assumed: both the status-text test and the click test assert the pick/tap
  actually lands on geometry (`expect(hitFound, isTrue, ...)` and the
  `inInclusiveRange` checks on the projected screen point) before relying on
  it, matching the brief's explicit instruction not to trust the point
  blindly.
- Did not run a mutation sweep (reserved for Task 11), and did not touch
  `analysis_options.yaml`.

## Concerns

- None found. The render package's public surface matched the brief's
  description exactly (constructor signatures, the `SelectionOverlayPainter`
  rename, `resolveHit`, `kPickRadiusPixels`), so no NEEDS_CONTEXT was raised.
- One thing worth a reviewer's eye: `_statusLine()` and the `Text` widget are
  rebuilt on every `_status` notification (selection **or** tool-controller
  change) but `_statusLine()` itself is cheap (`String` interpolation, no
  allocation of note), so this should not threaten the frame-path
  non-negotiable — the non-negotiable is scoped to the frame/paint path, not
  UI-thread state changes at selection/tool-swap rate.
