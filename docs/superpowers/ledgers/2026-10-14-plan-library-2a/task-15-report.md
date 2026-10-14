# Task 15 report: PlanCanvas and the plan library's paint-allocation invariant

Status: DONE_WITH_CONCERNS (concerns are minor; every gate green)

BASE 29aaea73. Commits:
- `539b0676` feat(plan): PlanCanvas and its paint-allocation invariant (P2)
- `8106dab0` test(plan): CV-alloc reads what a rebuild kept before its premise
- `a6958db4` test(plan): CV-10 pins the shortcut guard through the text entry

## Implemented

- `lib/src/canvas/plan_canvas.dart`: `PlanCanvas` (controller, rulers, grid, snapping, autofocus) and `kLockHintDuration` (2 s), exported from the barrel. Owns the paper, ink key and resolver (planner_shell.dart:281-382 less the 2b table fills), the canvas colour, the fit-on-start latch per document, follows `load`/`newPlan` swaps (controller listener plus a build-time identity check), the one-canvas-per-controller debug assert after the frame, the locale push (didChangeDependencies and on a new controller), `snappingAllowed` in initState and didUpdateWidget, and the lock hint (`Key('plan-lock-hint')`, `PlanStrings.lockedHint`, IgnorePointer, cleared by a timer 2 s after it was set).
- `lib/src/canvas/plan_canvas_view.dart`: port of `planner_view.dart` as `@internal PlanCanvasView` with `controller` as first named parameter, handed to the text entry.
- `lib/src/canvas/text_entry_overlay.dart`: port; `controller` added; wrapped in `PlanShortcutGuard`.
- `lib/src/shortcuts/chords.dart`: port of shell_commands.dart:10-61.
- `lib/src/shortcuts/plan_shortcut_guard.dart`: `PlanShortcutGuard`, `planLetterKeys` (generic V L P R C A T plus F), `letterKey`, `PlanTextKeys` (copied), re-exports chords (ruling R-l).
- `plan_controller.dart`: `@internal TextTool get textTool` (Step 5), and `@internal bool get isDisposed` (see deviations).
- `l10n/locale_scope.dart`: the post-frame report is skipped when the controller is disposed (Task 9 carried item).
- camera_bounds.dart reused from Task 8, not re-ported (R-k).

Carried items:
- Locale push vs disposed controller (Task 9): guarded in `PlanLocaleScope.push` (`context.mounted && !controller.isDisposed`), pinned by CV-8 (M-CV-8).
- Lock hint (Task 11's `lockHint`): shown by the canvas, CV-4 (M-CV-4a, M-CV-4b).
- Grip drag in flight when the kit's drag answers null (Task 11 cannot-verify): the canvas drives grips, so pinned by widget test CV-9: a boom block's grip dragged on the canvas; a healthy drag commits (positive control); with `gripsPreview` failing from the first move, `GuardedGrips` refuses the drag in flight, the release's `drag` answers null, and the drag ends cleanly: no exception, no undo step, the stored size unchanged, `planSelect.dragKind == null`, exactly one `(boom, hookFailed)` diagnostic, clean teardown. M-CV-9 (remove `if (_failed.contains(group)) return null;` from `GuardedGrips.drag`) turns it red.

## TDD evidence

RED (Step 4), `flutter test test/canvas/plan_canvas_test.dart test/invariants/canvas_paint_allocation_test.dart` before any lib file:
```
test/canvas/plan_canvas_test.dart:20:8: Error: Error when reading 'lib/src/canvas/plan_canvas_view.dart': No such file or directory
test/canvas/plan_canvas_test.dart:56:29: Error: Method not found: 'PlanCanvas'.
test/canvas/plan_canvas_test.dart:123:23: Error: Undefined name 'kLockHintDuration'.
```
(`clampCameraScale` was already Task 8's, so it did not appear.)

First GREEN attempt: 7 passed, 3 failed: CV-2 (two canvases scheduled two checks, so two FlutterErrors: "Multiple exceptions (2) were detected"), CV-8 (RED as designed before the guard: `FlutterError:<A ValueNotifier<Locale> was used after being disposed.>`), CV-9 (fixture: page grid snap moved the drop; `Expected ... <900> Actual: <550.0>`). Fixed: one check per controller per frame; the locale guard; grid snap off in CV-9's plan and the committed size compared exactly.

GREEN: `00:01 +10: All tests passed!` (plan_canvas_test + CV-alloc), then CV-10 added: `00:00 +1: All tests passed!`.

Ported tests, first run: `+47 -3` (A20, A21, palette M-DT-9 "White to Blueprint"): the page edit that replaces a swatch tap is heard after the frame it is pumped in; fixed with a second pump (see deviations), then `00:02 +50: All tests passed!`.

## Mutations (each on committed files, reverted with `git checkout -- <file>`, `git diff --quiet -- <file>` exit 0 after every one)

| Mutant | Site | Test | Red line |
|---|---|---|---|
| M-CV-1 | `fitOnStart: _fitOnStartFor(document),` -> `false` | CV-1 | `Which: at location [0] is <0.20357142857142854> instead of <0.1529047619047619>` |
| M-CV-2a | `if (count > 1)` -> `count > 2` (renamed site, see deviations) | CV-2 | `Expected: <Instance of 'FlutterError'> Actual: <null>` |
| M-CV-2b | `_leave(_c);` removed from dispose | CV-2 | `Expected: null Actual: FlutterError:<A PlanController is shown in one PlanCanvas at a time ...` reason `a canvas that replaces another is not a second one` |
| M-CV-3 | `_c.addListener(_onController);` removed from initState | CV-3 | `Expected: true Actual: <false>` |
| M-CV-4a | builder `=> shown` -> `=> false` | CV-4 | `Found 0 widgets with key [<'plan-lock-hint'>]` line 118 |
| M-CV-4b | `_hintTimer = Timer(...)` removed | CV-4 | `Expected: false Actual: <true>` line 124 |
| M-CV-5 | `rulers: widget.rulers,` -> `true` | CV-5 | `Found 1 widget with type "RulerFrame"` line 139 |
| M-CV-5g (extra) | `grid: widget.grid,` -> `true` | CV-5 | `Expected: false Actual: <true>` line 140 |
| M-CV-6a | `snappingAllowed` write removed from initState | CV-6 | `Expected: false Actual: <true>` line 155 |
| M-CV-6b | `snappingAllowed` write removed from didUpdateWidget | CV-6 | `Expected: true Actual: <false>` line 159 |
| M-CV-7 | `PlanLocaleScope.push` removed from didChangeDependencies | CV-7 | `Expected: Locale:<tr> Actual: Locale:<en>` line 176 |
| M-CV-8 (new) | locale_scope.dart `context.mounted && !controller.isDisposed` -> `context.mounted` | CV-8 | `Actual: FlutterError:<A ValueNotifier<Locale> was used after being disposed.` line 203 |
| M-CV-9 (new) | guard.dart: `if (_failed.contains(group)) return null;` removed from `GuardedGrips.drag` | CV-9 | `Expected: <899.9999999999964> Actual: <1600.0>` reason `nothing committed` line 260 |
| M-CV-10a (new) | guard's letter entries removed | CV-10 | `Expected: false Actual: <true>` `... "Key L") reaches the` line 293 |
| M-CV-10b (new) | guard's Undo/Redo chord entries removed | CV-10 | `Expected: empty Actual: ['undo']` line 300 |
| M-CV-10c (new) | text entry not wrapped in `PlanShortcutGuard` | CV-10 | `Expected: false Actual: <true>` line 293 |
| M-CV-alloc-1 | `resolver: _resolver,` -> `canvasResolverFor(document, paper: paper, dark: _darkCanvas)` | CV-alloc | first run (brief's order): `Expected: a value greater than <0> Actual: <0>` line 91 (flush premise); after 8106dab0: `a rebuild handed DraftCanvas a new resolver: a new painter and every cache made again` line 101 |
| M-CV-alloc-2 | `key: ObjectKey(document),` -> `UniqueKey()` | CV-alloc | first run: line 91 (flush premise); after 8106dab0: `a rebuild remounted DraftCanvas` line 95 |
| M-DC-3 | `_paperArgb` -> `_c.page.value?.background ?? _surfaceArgb` | dark_canvas "dark theme on White" | `Expected: '0x1e1f22' Actual: '0xffffff'` line 83 |
| M-DT-12 | text_entry_overlay.dart `filled: true,` removed | canvas_ui M-DT-12 (both) | `Expected: '0x33353a' Actual: '0x1e1f22'` line 78; both tests `[E]` |

## Gates (packages/jet_cad_2d_plan, at a6958db4, clean tree)

```
flutter test       -> 00:08 +445: All tests passed!
flutter analyze    -> No issues found! (ran in 2.6s)
dart format --output=none --set-exit-if-changed .  -> Formatted 113 files (0 changed); exit 0
git status --short -> (empty)
```
445 = 393 before + 52 new (plan_canvas 11, CV-alloc 1, canvas_ui 3, dark_canvas 5, theme_canvas 12, canvas_palette 9, canvas_draw 5, touch_tools 1, canvas_layout 4, canvas_camera 1). No other package touched.

## Files

New: `packages/jet_cad_2d_plan/lib/src/canvas/{plan_canvas,plan_canvas_view,text_entry_overlay}.dart`, `lib/src/shortcuts/{chords,plan_shortcut_guard}.dart`, `test/support/canvas_fixture.dart`, `test/canvas/{plan_canvas,canvas_ui,dark_canvas,theme_canvas,canvas_palette,canvas_draw,touch_tools,canvas_layout,canvas_camera}_test.dart`, `test/invariants/canvas_paint_allocation_test.dart`.
Modified: `lib/jet_cad_2d_plan.dart`, `lib/src/controller/plan_controller.dart`, `lib/src/l10n/locale_scope.dart`.

## Deviations from the brief

1. **One-canvas check deduplicated** (plan_canvas.dart). The brief scheduled one post-frame check per canvas; two canvases of one controller then threw two FlutterErrors, and CV-2's `takeException()` saw "Multiple exceptions (2)". A small `_Shown` record (the canvas set plus `checkScheduled`) in the Expando schedules one check per controller and frame. The condition is `count > 1` (M-CV-2a mutates that line).
2. **`PlanController.isDisposed` (`@internal`)** added, and `PlanLocaleScope.push`'s callback checks it (the Task 9 carried item; the controller had no way to tell). locale_scope.dart is therefore in this task's commit (not in the brief's git add list). Not a Shared interface.
3. **Tests added beyond the brief**: CV-8 (carried locale item), CV-9 (carried grip-drag item), CV-10 (the guard that lands here had no test that goes red without it; nothing binds keys above the canvas until Task 16). Step 13's "eight tests" is eleven.
4. **CV-alloc assertion order** (8106dab0): the identity checks (same DraftCanvasState, painter, sink) now precede the flush premise. With the brief's order both named mutants went red on the premise (`totalFlushCount > 0`, a remounted canvas or new painter flushes into another sink), hiding which mutant it was. No assertion changed.
5. **Ported page edits get a second pump** (canvas_draw_test A20 after each page edit/undo/redo, A21 after `notifyLoaded`; canvas_palette_test's `paper()` helper). The document's change stream is asynchronous; with no frame scheduled at `pump()` time the page notifier hears the edit after that frame, and the canvas alone has nothing that schedules one (in the source the swatch tap and the shell's bar did). Pump count is fixture; no assertion changed. The shell had the same async listener, so this is not a canvas behaviour change.
6. **CV-9's plan turns grid snap off** (the default page snaps the drop) and compares the refused drag to the size the healthy drag stored (exact `==`), not a literal 900 (the drag stores 899.9999999999964).
7. **Unneeded imports dropped**: the explicit `src/file/plan_file.dart` import in canvas_fixture.dart and the alloc test (analyzer `unnecessary_import`: `ensureManifest` is exported by the barrel); `package:flutter/material.dart` in touch_tools_test.dart (same lint).
8. **text_entry_overlay.dart doc wording**: only `:18` said "the shell's letters"; `:77` ("the shell's shortcuts") and `:94` ("reaches the shell") now say "the plan's shortcuts". PlanCanvasView's doc at `:69` says "PlanCanvas computes it" (the service view is 2b's). One code comment ("the shell's nominal fit", view `_drawingArea`) is left as copied.
9. **Ported-test adaptations not spelled out by the brief**: `theme_canvas_test`'s bare-shell test is named "a bare PlanCanvas reads the ambient extension" (reasons unchanged); `canvas_camera_test`'s `pageFitOf` reads `c.canvasRect.value!.size` as the source did (the brief allowed the canvas size); `draftLine`'s doc comment from :589-590 was taken with the helper; the dark-canvas and theme tests' `pumpView` keep the source's two pumps.

## Self-review

- Frame path: the resolver is rebuilt only when its key (foreground, dark) changes; the view is keyed by `ObjectKey(document)`; CV-alloc rebuilds PlanCanvas every frame over the 4,000-entity corpus with 50 selected roots and pins the state, painter, sink, capacity and Paint. `build` allocates a few widgets and possibly a `withSelection` palette per build, none per entity.
- `_rebind` runs from build when a parent rebuild arrives before the controller's notification (listener moves, resolver remade): a side effect in build, kept from the brief.
- Ported assertions: none changed, none weakened; reason strings kept.

## Concerns

1. `lockHint` re-set while already true does not notify (ValueNotifier), so the hint clears 2 s after the first refusal, not the latest. Matches the brief's wording ("after it was set"); a host seeing a second refusal 1.9 s later gets a 0.1 s hint.
2. `planLetterKeys` ignores its controller until Task 16 widens it (by design, R-l); M-CV-10a/b/c pin today's generic set only.
3. `PlanTextKeys` lands unused here (Tasks 16-18 consume it); no test pins it in this task.
4. CV-8's scenario (a host disposing the controller in a post-frame callback queued before the canvas's report, the canvas still mounted) is contrived; I found no ordinary widget path where the canvas is still mounted when its controller is disposed. The guard is cheap and the test pins it.

## Fix round 1

Commit: `1d68c7a5` fix(plan): a lock hint already set when a canvas binds clears too

### Change (review Important 1)

The 2 s timer started only when the canvas heard `lockHint` change from false to true, and only the canvas ever writes false. Three paths therefore left the hint on for good:
- a refusal before any canvas mounted;
- a refusal in the 2 s before a canvas was replaced (`dispose` cancels the timer);
- a controller handed to the canvas while its hint showed.

`plan_canvas.dart` now calls `_onHint()` right after `lockHint.addListener(_onHint)`, both in `initState` and in `didUpdateWidget`'s controller-swap branch. `_onHint` starts the timer only when the hint is true.

Not done: a later refusal restarting the 2 s window. A refusal while the hint shows writes true over true, and a `ValueNotifier` does not notify on an equal value. Restarting would need an event or counter on the controller, which is a new notifier API. Per the instruction it is left as is, and `_onHint`'s doc comment now says so.

Also not changed: when the canvas swaps away from a controller whose hint shows, that old controller's hint stays true until a canvas binds it again. Writing false during the swap would notify during build. The `initState` path clears it on the next mount (CV-4b's case).

### Covering tests

Added to `test/canvas/plan_canvas_test.dart`:
- **CV-4b:** `lockHint` is set before the canvas mounts. Expected: the hint shows, then after `kLockHintDuration` it is false and gone.
- **CV-4c:** the canvas shows c with its hint up, then is handed d, whose hint is already set. Expected: d's hint shows, then clears after `kLockHintDuration`.

`flutter test test/canvas/plan_canvas_test.dart` → `00:01 +12: All tests passed!` (12 tests in that file: CV-1..CV-10, CV-4b, CV-4c).

### Mutations

Each was applied to the committed file, reverted with `git checkout -- lib/src/canvas/plan_canvas.dart`, and checked with `git diff --quiet` (exit 0 every time).

| Mutant | Site | Red output |
|---|---|---|
| M-CV-4c | delete `_onHint();` in initState | `Expected: false  Actual: <true>`, plan_canvas_test.dart line 142, `CV-4b ... [E]` |
| M-CV-4d | delete `_onHint();` in the swap branch | `Expected: false  Actual: <true>`, line 162, `CV-4c ... [E]` |

Spot-check, re-run at 1d68c7a5:

| Mutant | Red output |
|---|---|
| M-CV-alloc-1 | `Expected: true  Actual: <false>` / `a rebuild handed DraftCanvas a new resolver: a new painter and every cache made again`, canvas_paint_allocation_test.dart line 101; `diff-quiet exit 0` |
| M-CV-alloc-2 | `Expected: true  Actual: <false>` / `a rebuild remounted DraftCanvas`, line 95; `diff-quiet exit 0` |
| M-CV-2b | `Expected: null  Actual: FlutterError:<A PlanController is shown in one PlanCanvas at a time (spec 2a P2): this` / `a canvas that replaces another is not a second one`, plan_canvas_test.dart line 83; `diff-quiet exit 0` |

### Gates (packages/jet_cad_2d_plan, at 1d68c7a5)

```
flutter test     -> 00:08 +447: All tests passed!
flutter analyze  -> No issues found! (ran in 3.3s)
dart format --output=none --set-exit-if-changed . -> Formatted 113 files (0 changed); format exit 0
git status --short -> (empty)
```

Correction to the main report's per-file count: plan_canvas_test held 10 tests at a6958db4 (CV-1..CV-10), not 11. The total of 52 new tests is the suite's own count (445 - 393).
