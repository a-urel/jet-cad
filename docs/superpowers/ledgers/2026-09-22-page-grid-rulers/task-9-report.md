# Task 9 report — the app: register, place, fit to page, the tree, the zoom text

Commit: `d4f0516` — `feat(app): the page under the plan — startup page, fit to
page, rulers and chrome in the tree, zoom text`

## What was implemented

### `lib/startup_plan.dart`
At the end of `startupPlan`, before `return doc;`: `PageComponent.register`
on the document's own registry, `doc.header.units = DrawingUnits.millimeters`,
then `SetComponentCommand<PageComponent>` through the command log with the
page from a new top-level `startupPage(Aabb2 extents)`, then
`doc.commands.clearHistory()` (Ruling 04-1). `startupPage` builds a default
`PageComponent()` (A4, landscape, 1:50, metres) and re-centres it on
`extents` via `copyWith(originX:, originY:)`, exactly as the brief's Step 3.

### `lib/main.dart`
- `late final PageNotifier _page = PageNotifier(_document);`, constructed
  after `_document`.
- The initial `_camera` now comes from
  `fitToPage(_document.components.get<PageComponent>(_document.rootHandle)!, const Size(1440, 900))`
  instead of `ViewportTransform.fit(_document.extents, ...)`.
- `_page` is disposed after `_selection`, before `_camera` (Ruling 04-2).
- `PlannerView` now receives `page: _page`.
- Top bar: the status-text `ListenableBuilder` is unchanged in string
  content; it now sits in a `Row` with a `Spacer()` and a second
  `ListenableBuilder(listenable: Listenable.merge([_camera, _page]), builder: (_, __) => Text(_zoomLine(), key: const Key('zoom-text')))`.
  `_zoomLine()` and the static `_trimNumber` helper match the brief verbatim.

### `lib/planner_view.dart`
- New required `page` (`PageNotifier`) constructor parameter and field.
- New `_chromeRepaint = Listenable.merge([widget.camera, widget.page])`.
- `build` now returns `RulerFrame(camera:, page:, child: LayoutBuilder(...))`
  wrapping the same `CameraGestureDetector > InteractionLayer > Stack` as
  before, with a `PageChromePainter` added as the Stack's first child
  (`Positioned.fill(RepaintBoundary(CustomPaint(painter: PageChromePainter(...))))`),
  then `DraftCanvas`, then the existing `SelectionOverlayPainter` — the exact
  order in the brief's Step 3.

**One implementation deviation from the brief's literal Step 3 snippet**, in
the fit-once branch: the brief's code sets `widget.camera.value = ...`
synchronously inside the `LayoutBuilder`'s own `builder`. That code, copied
verbatim, throws:

```
setState() or markNeedsBuild() called during build.
This ListenableBuilder widget cannot be marked as needing to build because
the framework is already in the process of building widgets. ...
The widget on which setState() or markNeedsBuild() was called was:
  ListenableBuilder
The widget which was currently being built when the offending call was made was:
  LayoutBuilder
```

Cause: `CameraController`'s own doc comment says it is "a `ValueNotifier` so
a change repaints inside a `RepaintBoundary` **without rebuilding the widget
tree**." Every existing listener respects that (paint-only, via `repaint:`).
The new zoom-text `ListenableBuilder` in `main.dart` is the first listener
that rebuilds a widget from a `_camera` notification — and it sits outside
the `LayoutBuilder`'s own subtree (a sibling higher in the tree, in the top
bar). Setting `camera.value` synchronously from inside the nested
`LayoutBuilder`'s build notifies that sibling's `ListenableBuilder`
mid-build, which Flutter forbids (a widget may only be marked dirty during
build if one of its *ancestors* is currently building).

Fix: defer the same assignment to `WidgetsBinding.instance.addPostFrameCallback`,
registered from inside the `LayoutBuilder` branch (guarded by `if (!mounted) return;`).
This runs after the current frame's build/layout/paint completes — outside
any build phase — so the notification is now ordinary, not a build-time
violation. Effect on behaviour: given the test sequence
`await tester.pumpWidget(...); await tester.pump();`, the first `pumpWidget`
call's frame executes the post-frame callback before returning (setting
`camera.value` and scheduling a second frame); the explicit `await tester.pump()`
then runs that second frame, so by the time a test observes anything the
camera is already correctly fitted — no test needed to change. The
`_fitted` latch is still flipped synchronously inside the `LayoutBuilder`
branch, so the branch still only runs once regardless of the deferred body.
The one real-world cost is a single dropped frame at startup (the first
paint briefly uses the un-fitted 1440×900 camera before the deferred fit
lands); this is not observable to the widget tests, which only assert
post-settle state, but it is a genuine, if imperceptible, behavioural change
from a synchronous fit. I judged this the correct fix rather than reporting
BLOCKED, since the alternative (matching the brief's snippet verbatim) is a
crash, not a design choice open to interpretation; I flag it here per
"never synthesize test output" / "always confirm claims independently."

No numeric test expectation needed correction — the brief's format string,
constants and `zoomOf`/`fitToPage` values all worked out as written.

## TDD evidence

### RED (before implementation, after adding the five new/updated tests)

Command: `CI=true flutter test test/startup_plan_test.dart test/planner_shell_test.dart`

Tail of output:
```
00:00 +5 -2: ...planner_shell_test.dart: the camera is fitted to the real viewport on first layout [E]
00:00 +5 -3: ...planner_shell_test.dart: the camera is fitted to the page at the drawing area's size [E]
00:01 +5 -4: ...planner_shell_test.dart: the page chrome and the rulers are in the tree, under the canvas [E]
00:01 +5 -5: ...planner_shell_test.dart: the zoom text reads the scale and the fitted zoom [E]
...
00:01 +12 -5: Some tests failed.

Failing tests:
  .../planner_shell_test.dart: the camera is fitted to the page at the drawing area's size
  .../planner_shell_test.dart: the camera is fitted to the real viewport on first layout
  .../planner_shell_test.dart: the page chrome and the rulers are in the tree, under the canvas
  .../planner_shell_test.dart: the zoom text reads the scale and the fitted zoom
  .../startup_plan_test.dart: the startup plan carries an A4 landscape page at 1:50 centred on the plan, in millimetres, with no history
```
12 passed (pre-existing), 5 failed (exactly the new/updated tests) — as expected before implementation.

### GREEN (after implementing all three `lib/` files, including the
post-frame-callback fix)

Command: `CI=true flutter test test/startup_plan_test.dart test/planner_shell_test.dart`

Tail of output:
```
00:00 +4: .../startup_plan_test.dart: the startup plan carries an A4 landscape page at 1:50 centred on the plan, in millimetres, with no history
00:00 +5: .../planner_shell_test.dart: the shell shows a canvas over a non-empty, off-origin plan
00:00 +6: .../planner_shell_test.dart: the camera is fitted to the real viewport on first layout
00:00 +7: .../planner_shell_test.dart: the camera is fitted to the page at the drawing area's size
00:01 +8: .../planner_shell_test.dart: the page chrome and the rulers are in the tree, under the canvas
00:01 +9: .../planner_shell_test.dart: the zoom text reads the scale and the fitted zoom
00:01 +10: .../planner_shell_test.dart: the three chrome slots are laid out and empty
00:01 +11: .../planner_shell_test.dart: a resize after the first layout does not re-fit the camera
00:01 +12: .../planner_shell_test.dart: the status text shows the tool name and follows the selection
00:01 +13: .../planner_shell_test.dart: the interaction tree is in place
00:01 +14: .../planner_shell_test.dart: a click on a wall selects it in the running shell
00:01 +15: .../planner_shell_test.dart: cmd+Z undoes a Delete through the command log
00:01 +16: .../planner_shell_test.dart: ctrl+Z after deleting two walls brings both back in one step
00:01 +17: All tests passed!
```
17/17 passed.

## Gate line (from `apps/floor_planner`)

Command: `CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed . && flutter build macos --release && flutter build web --release`

Printed counter and summary lines, in order:
```
00:00 +17: All tests passed!
```
```
Analyzing floor_planner...
No issues found! (ran in 1.3s)
```
```
Formatted 5 files (0 changed) in 0.03 seconds.
```
```
Building macOS application...
✓ Built build/macos/Build/Products/Release/floor_planner.app (47.3MB)
```
```
Compiling lib/main.dart for the Web...                             25.0s
✓ Built build/web
```
Chained exit code (`echo $?` after the full `&&` chain): `0`

(Ran the full test suite standalone first — `CI=true flutter test` — same
result, `+17: All tests passed!`, before chaining; then `flutter analyze`
alone — `No issues found!`; then `dart format --output=none --set-exit-if-changed .`
alone, which required an actual `dart format lib/ test/` pass first — see
below.)

### The one snag: `dart format --output=none --set-exit-if-changed .`

First run (before running the real formatter) printed:
```
Changed lib/startup_plan.dart
Changed test/planner_shell_test.dart
Changed test/startup_plan_test.dart
Formatted 5 files (3 changed) in 0.27 seconds.
```
exit 1 — my hand-edits weren't formatter-clean. Ran `dart format lib/ test/`
to actually apply formatting (3 files reformatted: mostly test-name string
wrapping and the `startupPage`/`SetComponentCommand` call layout), then
re-ran `--output=none --set-exit-if-changed .`:
```
Formatted 5 files (0 changed) in 0.03 seconds.
```
exit 0. Re-ran the full test suite and `flutter analyze` after formatting to
confirm nothing broke — both still green (see GREEN section and analyze
output above).

## Files changed

- `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-04-page-grid-rulers/apps/floor_planner/lib/startup_plan.dart`
- `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-04-page-grid-rulers/apps/floor_planner/lib/main.dart`
- `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-04-page-grid-rulers/apps/floor_planner/lib/planner_view.dart`
- `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-04-page-grid-rulers/apps/floor_planner/test/startup_plan_test.dart`
- `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-04-page-grid-rulers/apps/floor_planner/test/planner_shell_test.dart`

`git status --short` before commit showed exactly these five files — no
`analysis_options.yaml` drift, nothing to `git checkout --`.

## Self-review

**Completeness**
- Startup test: added, passes (`the startup plan carries an A4 landscape
  page at 1:50 centred on the plan, in millimetres, with no history`).
- The four shell tests: `the camera is fitted to the real viewport on first
  layout` (updated to `fitToPage`), `the camera is fitted to the page at the
  drawing area's size` (new), `the page chrome and the rulers are in the
  tree, under the canvas` (new), `the zoom text reads the scale and the
  fitted zoom` (new) — all pass.
- `startupPage`: implemented as a top-level function exactly per the brief.
- Registration once: `PageComponent.register` is called exactly once per
  `startupPlan` call, on that document's own `ComponentRegistry` instance —
  never twice on the same registry.
- `header.units`: set to `DrawingUnits.millimeters`.
- `clearHistory`: called immediately after the `SetComponentCommand`
  execute, so `doc.commands.canUndo` is `false` on a fresh document.
- The notifier's lifetime: `_page` constructed right after `_document`,
  disposed right after `_selection` (before `_camera`), per Ruling 04-2.
- The tree: `RulerFrame > LayoutBuilder > CameraGestureDetector >
  InteractionLayer > Stack[PageChromePainter, DraftCanvas,
  SelectionOverlayPainter]`, verified by the new tree test
  (`RulerFrame` found once, the `PageChromePainter` `CustomPaint` found once
  and sized exactly to `DraftCanvas`).
- `zoom-text`: format `1:50 · ${...}%` with the middle dot (U+00B7),
  percent rounded with `.round()`, verified before and after a
  `camera.zoomAt` call.
- The rewritten comment (Ruling 04-9): the stale "fills the 200-entry undo
  stack" comment in the ctrl+Z test is replaced with one describing that the
  history is cleared at startup (Ruling 04-1); the live-count assertions
  themselves are untouched.

**Quality**
- The one deviation from the brief's literal code (deferring the initial
  camera-fit assignment to a post-frame callback) is documented above with
  the exact crash it fixes and its one behavioural cost (a single
  imperceptible dropped frame at startup, invisible to the widget tests).
  I did not touch any test expectation to work around this — the deferred
  assignment still lands before either test `await` returns.
- `PageChromePainter`'s `repaint:` is `_chromeRepaint = Listenable.merge([camera, page])`,
  matching the brief; it is a paint-only listener, unaffected by the
  build-time issue above.

**Discipline**
- `main.dart`'s `status-text` string content (`_statusLine()`) is byte-for-byte
  unchanged; only its layout container changed (from `Align` to a `Row` with
  a `Spacer()`, to make room for `zoom-text`).
- `chrome-right` is untouched — still an empty, sized `Container`.
- No subagents dispatched; no mutation sweep beyond what the brief's tests
  exercise.

**Pristine output**: `git status --short` shows exactly the five files
listed above, both before and after the full gate line; no
`analysis_options.yaml` rewrite to discard.

## Concerns

- The post-frame-callback deviation from the brief's Step 3 snippet (see
  above) is the one substantive judgment call in this task. It fixes a real
  crash the brief's literal code produces once the zoom-text
  `ListenableBuilder` is wired to `_camera`, and every test still passes
  with the exact expected values. A reviewer should confirm this reasoning
  rather than assume the snippet was followed verbatim.

## Fix round 1 (review verdict: Approved, one Important finding)

Commit: `9f08c10` — `docs(app): the fit lands at the end of the first frame, not before it`

Comment-only fix in `apps/floor_planner/lib/planner_view.dart`, per the
reviewer's finding: the comment above the post-frame deferral claimed the
real-size fit lands "before the canvas underneath has had a frame to listen
on anything," which is backwards — frame 1 builds, lays out and paints at
the shell's nominal 1440×900 fit; the post-frame callback then sets
`camera.value`, and the real-size fit only paints from frame 2 onward.

Three comments changed, no code:
- The `PlannerView` class doc, which described only the inner
  `CameraGestureDetector`/`DraftCanvas` pair and no longer matched the tree
  added in Task 9 (`RulerFrame` on the outside, `PageChromePainter` and the
  selection overlay alongside `DraftCanvas`). Now: "The rulers around the
  drawing area: a [RulerFrame] whose child is a [CameraGestureDetector]
  over the page chrome, the [DraftCanvas] and the selection overlay."
- The `_fitted` field doc, which asserted the "before the canvas has
  listened" claim. Now: "Ruling 01-2: the camera is fitted once, to the
  size the drawing area really got; since Plan 04 the fit lands at the end
  of the first frame (Ruling 04-16)."
- The inline comment at the post-frame-callback site, rewritten to state
  plainly what triggers the deferral (Flutter forbidding a mid-build
  notification to the zoom text's builder) and what it actually produces
  (frame 1 at the nominal fit, frame 2 at the real size), per the
  reviewer's suggested wording.

### Verification

`CI=true flutter test test/planner_shell_test.dart` from `apps/floor_planner`:
```
00:00 +0: the shell shows a canvas over a non-empty, off-origin plan
00:00 +1: the camera is fitted to the real viewport on first layout
00:00 +2: the camera is fitted to the page at the drawing area's size
00:00 +3: the page chrome and the rulers are in the tree, under the canvas
00:00 +4: the zoom text reads the scale and the fitted zoom
00:00 +5: the three chrome slots are laid out and empty
00:00 +6: a resize after the first layout does not re-fit the camera
00:00 +7: the status text shows the tool name and follows the selection
00:00 +8: the interaction tree is in place
00:00 +9: a click on a wall selects it in the running shell
00:00 +10: cmd+Z undoes a Delete through the command log
00:01 +11: ctrl+Z after deleting two walls brings both back in one step
00:01 +12: All tests passed!
```

`flutter analyze`:
```
Analyzing floor_planner...
No issues found! (ran in 1.5s)
```

`dart format --output=none --set-exit-if-changed .`:
```
Formatted 5 files (0 changed) in 0.03 seconds.
```
Exit 0.

`git status --short` before commit showed only
`apps/floor_planner/lib/planner_view.dart` modified — no
`analysis_options.yaml` drift, nothing to restore.

`git log -1 --format=%B | grep -c "Fable 5.1"` → `1`.
