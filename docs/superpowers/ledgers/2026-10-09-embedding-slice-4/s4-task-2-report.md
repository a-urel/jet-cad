# Slice 4, Task 2: the two bars, `mergeCandidate`, an idle Undo, the canvas re-measured (implementer's report)

- **Branch:** `claude/exciting-pasteur-9m22jv`, from `ffe0b9c` (Task 1).
- **Commit:** `86115fa`. Pushed as `ffe0b9c..86115fa`.
- **Environment:** Flutter 3.47.6 at `/root/sdk/flutter/bin`, `CI=true`. Scratch files, the mutant runner and its logs: `/tmp/claude-0/-home-user/428cafca-0083-5012-a7ac-5456349e70a8/scratchpad/s4t2-impl/` (`mutate.py`, `mutants.json`, `logs/`, `bc_base_test.dart`).
- **`analysis_options.yaml`:** none touched or committed. `git status` before the commit showed only the nine task files; after it, the tree was clean.
- **Scope:** nothing of Tasks 3 to 7. The engine and `jet_cad_2d_flutter` are not edited. No golden, counter or allocation test is edited. The only edited existing test is B1 in `barrel_test.dart` (+4 names), which the plan names.

## Files

| File | What |
|---|---|
| `lib/src/host/bars.dart` (new) | `enum FloorPlanServiceAction { undo, redo, merge, split, export, print }` and `enum FloorPlanEditorAction { export, print, undo, redo, snap, zoom }`, each in today's left-to-right order (S-2). `final class FloorPlanServiceBar` / `FloorPlanEditorBar` as C-1 / C-2 write them (`visible = true`, `actions = …values`, `leading`, `trailing = const []`), `==` and `hashCode` with `listEquals` over actions and widgets, `toString` naming only what differs from the default (`FloorPlanServiceBar()`, `FloorPlanEditorBar(visible: false, actions: [zoom])`, widgets by `toStringShort`). Internal `validateBars`: an `ArgumentError` named `actions` for a repeated action. |
| `lib/src/host/service_view.dart` | Optional `bar` (default `const FloorPlanServiceBar()`). The bar is built only when `visible` (the canvas then takes the height, and `_barHeightNow` runs only while it is shown). `_bar`: `leading`, the actions in the given order under today's rules (merge/split need their callbacks, export needs `onExport`), 8 px between two shown actions of different groups (history / groups / page), `trailing`. Host widgets present: the whole row sits in a `ShellShortcutGuard` (so a host `Spacer`/`Expanded` still works); none: the row is today's. Merge's flag now reads `controller.mergeCandidate` (one source); the `mergeQualifies` import is gone. The chords are untouched (S-20). |
| `lib/src/planner_shell.dart` | Optional `editorBar` (default `const FloorPlanEditorBar()`) and `onIdle` (`ShellIdleRegistrar`, new typedef). The top bar moved into `_topBar`; with `visible: false` it is not built. With the default `actions` (by `listEquals`), the toolbar is today's call `DocumentToolbar(fileCommands:, editCommands:)` exactly. Otherwise `_toolbarFor`: the shell's other file commands first (New to Save As), then the buttons in the given order, a group per run of file (export/print) or edit (undo/redo) buttons; no toolbar (and no 16 px) when nothing is left. The read-outs (`snap`, `zoom`) in the given order, 16 px apart. Host widgets: the row inside a `ShellShortcutGuard`, outside the toolbar's `ExcludeFocus`. The chord bindings still read the full `fileCommands` and `editCommands` (S-20). The shell registers `() => _idle` through `onIdle` in `initState`, withdrawn in `dispose`. |
| `lib/src/document_toolbar.dart` | A second constructor, `DocumentToolbar.groups({required groups})`. The existing constructor is unchanged. `build` lays out `_groups ?? [fileCommands, editCommands]` with `groupGap` between two non-empty groups, which is today's rule for two groups. |
| `lib/src/host/floor_plan_controller.dart` | `ValueListenable<Set<String>?> mergeCandidate`, set at the end of `_refreshSelectedGroup`. In the selection mode it is `selectedTables` (already an unmodifiable set) when `mergeQualifies`, else null; it is null in the design mode. It notifies only on a change (`setEquals`), and is disposed with the controller. `@internal registerIdle(bool Function())`, which returns a withdrawal as `registerSettle` does. `undo()` and `redo()` return at once when the mode is design and the probe reads not idle (S-4); they are documented. |
| `lib/src/host/floor_plan_view.dart` | `serviceBar`, `editorBar` (documented). `validateBars` runs at build, as `validateOverlayLayout` does. **R-13, generalized:** `_measureChrome()` keeps `(serviceBar.visible, editorBar.visible)` from the last build. After a build with different values, one post-frame `_canvasMoved()` re-measures the **shown** mode's canvas (`_shown`, set in the modes' builder; checked against `controller.mode`). S-10's `_serviceCanvasMoved` became `_canvasMoved` and is still `ServiceView.onCanvasMoved`, so the theme-height trigger stays. The modes get `bar:` / `editorBar:` / `onIdle: c.registerIdle`. |
| `lib/jet_cad_floor_plan.dart`, `test/host/barrel_test.dart` | The four names; B1 gains them. |
| `test/host/bars_test.dart` (new, 35 tests) | See "Tests" below. |

## Tests (`test/host/bars_test.dart`, on `embeddingPlanJson()` under `embeddingCamera()`)

**The characterization was written first and run green on the base.**

- I wrote it with `lib` still at `ffe0b9c`: BC1 to BC3, 11 tests.
- A probe printed every left edge, and the values were written in as constants. The run was `00:04 +11: All tests passed!` on the base.
- It is unchanged after the task and green. The base-run copy is `bc_base_test.dart` in the scratch directory.

The groups and what each test pins:

- **BC1:** the service bar for every combination of onExport, Merge and Split (8 tests).
- **BC2:** the view's editor bar, with and without onExport. It covers the buttons, `status-text`, `osnap-text` and `zoom-text`.
- **BC3:** a bare `PlannerShell` with the floor planner's seven file-command ids.
- **BT1:** the four names through the barrel alone (prefixed import). It checks the enums' order, `==`, `hashCode` (equal lists that are not the same list), each field changed alone being unequal, and `toString`.
- **BT2:** a repeated action is an `ArgumentError` named `actions`, for each bar, in both modes.
- **M-H40** (two tests), plus:
  - the gap rules for non-default orders: the editor `[print, undo]` puts 12 px between them; the service `[redo, undo, merge, export, split]` puts 8 px at each change of group;
  - today's rules inside the subset;
  - a bare shell's other file commands come first (`[undo, redo, print]`).
- **visible: false:**
  - Selection mode: no bar, and the canvas is at the view's top with the view's size.
  - Design mode: no `chrome-top`; `chrome-left` is at the view's top; the canvas is at `(240 + ruler, ruler)`; the tools are inside `chrome-left`.
- **Host widgets:**
  - Leading is 30 px and trailing is 70 px in both bars.
  - They sit in place, inside the bar's rect.
  - The service bar's default buttons shift by exactly 30 px.
  - A tap on the leading widget updates the trailing widget through the host's own `ValueNotifier`.
  - **T2-b** (two tests).
- **mergeCandidate:**
  - **M-H44**.
  - S-5: it works without `onMergeRequested`.
  - **T2-d**.
  - Notifications are counted: 1 per change, 0 for an equal set, 0 for an unrelated group, 0 for null staying null.
- **Idle Undo:** **T2-c**, plus a check that the selection mode is unchanged.
- **Chords:** **T2-e**.
- **Re-measure:**
  - **M-H47(serviceBar)** and **T2-f**.
  - The bar of the mode not shown is changed: the next switch keeps the table in place, because the existing assumed-origin correction applies.

Screen points come from the camera's forward transform (`canvasOf`) from the `InteractionLayer`'s origin. A table's world point is its instance transform applied to `embeddingBox`'s centre.

## Mutants (each applied by `mutate.py`, seen red, restored from a copy, `cmp` equal)

| Mutant | Applied as | Killer (red) | Reason seen |
|---|---|---|---|
| **M-H40** (service bar) | `_actions` iterates `FloorPlanServiceAction.values.where(actions.contains)` | `M-H40 the service bar [print, undo] …` | print's left edge: expected 12, got 68 |
| **M-H40** (editor buttons) | `_toolbarFor` iterates the enum's values filtered by `actions` | `M-H40 the editor bar [redo, undo, zoom, snap] …` | redo's left edge: expected 12, got 52 |
| M-H40 (editor read-outs) | the read-out loop iterates the enum's values filtered by `actions` | same test | osnap's left edge: expected 1444, got 1184 |
| **M-H44** | candidate = `selected` when not empty (selection mode) | `M-H44 the selection mode: …` (also T2-d and the notification test) | `1` alone: expected null, got `{1}` |
| **M-H47(serviceBar)**, form "keyed on the theme's bar height alone" | `_measureChrome()` call removed from the view's build | `M-H47(serviceBar) hidden from the start: …` | the table off by 44 px after the runtime show and a switch |
| **M-H47(serviceBar)**, form "a 44 px box kept" | hidden bar replaced by `SizedBox(height: kServiceBarHeight)` | same test | `canvasIn`: expected (0, 0), got (0, 44) |
| **T2-a** (service bar: a gap after every action) | `if (lastGroup != null)` | BC1 (8 red) | `service-redo` at 68, not 60 |
| **T2-a** (service bar: no gap) | gap condition `&& false` | BC1 (8 red) | `service-merge` at 108, not 116 |
| **T2-a** (toolbar: no group gap) | `DocumentToolbar` gap `&& false` | BC2, BC3 | `toolbar-undo` at 92, not 104 |
| **T2-a** (toolbar: a gap after every button) | a gap before each button that follows a button | BC2, BC3 | `toolbar-print` at 64, not 52 |
| **T2-b** (inside the toolbar's `ExcludeFocus`) | editor row wrapped as `ShellShortcutGuard(child: ExcludeFocus(child: row))` | `T2-b a host TextField in the editor bar's trailing …` | the field does not take the focus (expected true) |
| **T2-b** (outside a guard, editor) | the guard removed | same test | W handled (expected false, got true) |
| **T2-b** (outside a guard, service) | the guard removed | `T2-b a host TextField in the service bar's leading …` | table 1 moved back by the undo (see Finding 1) |
| **T2-c** (`undo()` mid-shape) | `if (_editorMidShape) return;` removed from `undo` | `T2-c the Polyline tool with two points placed …` | the state id moved |
| T2-c (`redo()` mid-shape) | the same line removed from `redo` | same test | the state id moved |
| **T2-d** | the candidate computed in `_refreshSelected` instead of `_refreshSelectedGroup` | `T2-d setTableGroups alone moves it …` | expected null after the group was set, got `{1, 2}` |
| **T2-e** (editor) | the shell binds only the edit commands the bar shows | `T2-e editor [export, print], service [print] …` | Ctrl+Z not handled |
| **T2-e** (service) | the undo chords bound only when `actions` holds undo | same test | Ctrl+Z not handled |
| **T2-f** | the chrome tuple ignores `editorBar.visible` | `T2-f the editor bar hidden at runtime …` | in the selection mode the table was off by 44 px |

## Gates (real results, at the committed tree)

| Gate | Command | Result |
|---|---|---|
| Planner tests | `flutter test --enable-vmservice --file-reporter json:…` | `05:32 +1742: All tests passed!` (1707 + 35) |
| Planner standing comparison | `dart run tool/ci/expect_failures.dart --package packages/jet_cad_floor_plan --root packages/jet_cad_floor_plan planner.json` | `packages/jet_cad_floor_plan: 1742 tests; the standing failures and skips, exactly` (exit 0) |
| Planner analyze | `flutter analyze` | `No issues found!` |
| Planner format | `dart format --output=none --set-exit-if-changed .` | 267 files (0 changed) |
| Demo (`apps/restaurant_demo`) | test / analyze / format | `00:42 +60: All tests passed!`; `No issues found!`; 8 files, 0 changed |
| Floor planner (`apps/floor_planner`) | test / analyze / format | `01:58 +212: All tests passed!`; `No issues found!`; 47 files, 0 changed |
| Engine (`jet_cad_2d`) | `dart test --file-reporter json` (exit 1, its standing failures), then the comparison | `packages/jet_cad_2d: 1258 tests; the standing failures and skips, exactly` (exit 0) |
| Render (`jet_cad_2d_flutter`) | `flutter test --file-reporter json` (exit 1, its standing failures), then the comparison | `packages/jet_cad_2d_flutter: 1390 tests; the standing failures and skips, exactly` (exit 0) |

Every test the plan lists as "unedited and green" for this task passes inside these runs. In the planner that is `view_test`, `table_groups_toolbar_test`, `theme_service_test` (the 60 px bar, T3-d), `view_events_test`, `floor_plan_theme_test`, `planner_shell_test`, `dimension_shell_test`, `planner_draw_test`, `planner_grips_test`, `room_grips_test`, `wall_tool_test`, `l10n/*`, `controller_test`, `table_groups_controller_test` and `camera_test`. In the floor planner it is the document tests and `app_words_test`. The demo's tests pass too.

## For the CHANGELOG (Task 7)

- **Fix (S-4):** `FloorPlanController.undo()` and `redo()` now do nothing in the design mode while the editor's tool is part-way through a shape, as the editor's own Undo button and key already did.
- In 0.3.0, a host calling `undo()` mid-shape undid a step beneath the pending shape.
- `canUndo` and `canRedo` keep their meaning (the history). So a host button enabled by them may be pressed then, and nothing happens.

## Findings and deviations

1. **My first T2-b service killer was too weak, and a mutant showed it.**
   - The first version sent Ctrl+Z and then Ctrl+Y before checking. Without the guard, the redo restored what the undo removed, so "the service guard removed" survived.
   - The test now checks after Ctrl+Z alone: the table has not moved, `canUndo` is true and `canRedo` is false. The mutant is red against it, as recorded above.
2. **Host widgets: one guard around the whole row, not one per widget.**
   - With one guard per widget, a host `Spacer` or `Expanded` in `leading` or `trailing` would lose its `Flex` parent.
   - `ShellShortcutGuard` is inert unless a text field is focused, so wrapping jet-cad's buttons in it as well changes nothing for them.
   - With no host widget the row is not wrapped, so the default bar's tree is today's.
3. **The editor's default toolbar path is today's call verbatim.** When `actions` equals `FloorPlanEditorAction.values`, the shell calls `DocumentToolbar(fileCommands:, editCommands:)` as before. This holds even for a bare shell whose host orders its file commands differently.
4. **A one-frame offset at the first switch into a mode whose bar is hidden.**
   - The controller's seed is still `(0, 44)`. At the first switch, the reframe uses it, and the post-frame measurement corrects it. This is the existing assumed-origin mechanism, as S-10's theme heights already work.
   - So for one frame the plan sits 44 px off; after that it is exact (M-H47's killer pins this).
   - Seeding from the view's chrome would remove the frame. That would be a new controller seam, which I did not add.
5. **`mergeCandidate` reuses the `selectedTables` set** instead of copying it. That set is already unmodifiable and replaced on every change. The test checks that `add` throws and that it is equal to what Merge sends.
6. **Controller and shell members added beyond the public names:**
   - `registerIdle` (`@internal`);
   - `ShellIdleRegistrar` (a typedef in `planner_shell.dart`, not exported);
   - `PlannerShell.onIdle` and `PlannerShell.editorBar`, `ServiceView.bar`, and `DocumentToolbar.groups` (all optional or a new constructor).

   The barrel and B1 gain exactly the four names.

## Fixes

- **Commit:** `834c832`, `fix(floor_plan): the first frame after a switch, the toolbar gap, the bars' docs (Slice 4, Task 2 review)`, on top of Task 4 (`5c72a5e`) and the Task 3 and Task 1 fix commits.
- **Files:** `lib/src/host/floor_plan_controller.dart`, `lib/src/host/floor_plan_view.dart`, `lib/src/planner_shell.dart`, `lib/src/host/bars.dart`, `test/host/bars_test.dart` (the task's own file, extended: `mountHost` gains `theme`, `mountBare` gains `editorBar`). No existing test edited; no `analysis_options.yaml`; nothing enters the barrel.
- **Scratch:** `/tmp/claude-0/-home-user/428cafca-0083-5012-a7ac-5456349e70a8/scratchpad/s4-fix123/t2/` (`mutate.py`, `results.txt`, `mlogs/`).

### R-1: T2-c each call alone, and after a load

- T2-c now checks after `undo()` alone and after `redo()` alone: the state id, the encoding and the history (`canUndo` and `canRedo`) unchanged each time.
- New: **T2-c after a `load()`** in the design mode (the new shell registers its probe before the old one is disposed): a Polyline part-way, `undo()` leaves the state id and the encoding.

### R-2: the toolbar's first file group

`_toolbarFor` starts with `bool? lastFile = groups.first.isEmpty ? null : true;`: Export or Print right after a bare shell's other file commands joins their group. Killer: **R-2** (the review's K5): a bare shell with `[export, print, undo, redo, zoom, snap]` keeps every button's left edge of `kBareEdges` (red before: Export at 224, not 212). The default path and `[undo, redo, print]` are unchanged.

### R-3: the one-frame offset, removed

**The cause.** A switch reframes the camera by the difference of the two modes' canvas origins (`_canvasAt`), synchronously, before the new mode is built. The origin of a mode the view does not show was the seed (the default chrome) or the last measurement, so after a chrome change of that mode (a bar hidden from the start or at runtime, the theme's bar height, Task 4's rulers and left column) the first frame used a stale origin and the measurement after it corrected the camera.

**The fix (internal, no public name).**
- The view knows where each mode's canvas starts by its chrome alone (`_chromeOrigin`): the selection mode at `(0, bar shown ? the theme's serviceBarHeight ?? 44 : 0)`; the design mode at `((left column ? 240 : 0) + ruler, (editor bar ? 44 : 0) + ruler)`, `ruler = rulers ? 24 : 0`.
- At each build of the view, and at each change of its resolved theme, a small internal widget under the theme scope (`_ChromeOrigins`, which depends on the scope; its child is the same widget, so a theme change rebuilds it alone and no overlay, G-5) calls `controller.canvasAssumed(mode, chromeOrigin)` for the mode **not shown**.
- `canvasAssumed` keeps, per mode, the chrome origin its stored origin was seeded or measured under (`_chromeAt`, the default chrome at first; `canvasMeasured` gains an optional `chrome:` that the view passes). It moves, by the difference, the stored origin, a reframing's assumption still awaiting its measurement, and the rect `canvasRect` takes at the switch (its far corner kept). The shown mode is untouched: it is measured after the frame as before (a switch made with no view, then a view with a different chrome, is still corrected by that measurement).
- With the default chrome nothing moves, so the seeds stay a test seam (V7b, V7h and VZ6 run unedited and green).
- The docs of `FloorPlanView.serviceBar` and `canvasRect` now say what holds: the plan stays in place from the first frame, and `worldToGlobal` is right from the switch for a mode a view has shown.

**First-frame tests** (`bars_test.dart`, group "the review fixes"). Each records table 1's place, switches, and checks: the first frame drawn with the camera the switch left is at the place; the camera is not corrected after that frame; settled at the place; and, for a mode a view has shown, `worldToGlobal` right at the switch.
- the service bar hidden from the start, first switch (frame 1 was 44 px off);
- the theme's 60 px bar given to the view, first switch (16 px off);
- the ambient theme's bar height changed while the design mode is shown and the view is not rebuilt (60, then 52);
- the editor bar hidden while the selection mode is shown, then shown again;
- the service bar hidden while the design mode is shown, then shown again (`canvasRect` keeps its far corner);
- a bar hidden while its mode is shown and shown again while it is not (the basis from the measurement);
- the editor's rulers off, `readOnly` (no left column), then `full`, each changed while the selection mode is shown;
- a switch made while no view is shown, then a view whose service bar is hidden (the shown mode is left to its measurement).

### R-4: the bars' docs

- `FloorPlanServiceBar`: in a host field Undo and Redo stay in the field; the file chords (Export's Ctrl+E, Print's Ctrl+P and their Cmd forms) still reach the plan.
- `FloorPlanEditorBar`: the tool letters, Undo, Redo and Escape stay in the field; the file chords and F3 still act.
- The guide (`docs/host-guide.md`) does not mention the bars yet (Task 7), so it repeats no claim.

### R-5

- **R-5 (K3):** `[snap, zoom]`: no `DocumentToolbar`, `status-text` at 12.
- **R-5 (K4):** a host field in the service bar's `trailing`: Ctrl+Z leaves the plan as it was.
- O21: skipped, as ruled.

### Mutants (each applied by `mutate.py`, `bars_test.dart` run, every file restored and checked with `filecmp`)

| Mutant | Red in |
|---|---|
| O8 (any withdrawal clears the probe) | T2-c after a load |
| O17 (the shell's probe always idle) | T2-c, T2-c after a load |
| O18 (the view passes no `onIdle`) | T2-c, T2-c after a load |
| O20 (an empty toolbar kept) | R-5 `[snap, zoom]` |
| O24 (the guard only with `leading`) | R-5 trailing field |
| R-2 reverted (`bool? lastFile;`) | R-2 |
| R3-m1 no `canvasAssumed` call | every R-3 first-frame test |
| R3-m2 the rect not moved | the R-3 tests with `worldToGlobal` at the switch |
| R3-m3 the pending assumption not moved | the R-3 tests, and "a bar of the mode not shown changed" |
| R3-m4 the theme's height ignored | the two theme tests |
| R3-m5 the shown mode moved too (both guards removed) | "a switch made while no view is shown", and others |
| R3-m6 `canvasMeasured` records no basis | "a bar hidden while its mode is shown, shown again while it is not" |
| R3-m7 the theme read without depending on it | the ambient theme test |
| R3-m8, R3-m9, R3-m10 the left column, the rulers, the editor bar left out of the design origin | the rulers and left column test; the editor bar tests |
| M-H47 (both forms) and T2-f, re-applied after the fix | M-H47(serviceBar), T2-f, and R-3 tests |

Note: when an R-3 test fails, the next test can report a teardown assertion from the failed test's tree (`ServiceView.dispose` creates its lazy `_pageReady` flag on a controller already disposed by the test's tear-down). It appears only after a failure, and the code is older than this slice (`bb81e6a`).

### Final gates (at `834c832`, after the last fix commit; a fresh run after a container restart killed the first one; `gates.sh`, `gates.out` in the scratch directory)

| Package | Tests (standing comparison) | Analyze | Format |
|---|---|---|---|
| `packages/jet_cad_floor_plan` (`--enable-vmservice`) | `04:34 +1787: All tests passed!`; "1787 tests; the standing failures and skips, exactly" | No issues | 271 files, 0 changed |
| `apps/restaurant_demo` | `+60: All tests passed!` | No issues | 8 files, 0 changed |
| `apps/floor_planner` | `+212: All tests passed!` | No issues | 47 files, 0 changed |
| `packages/jet_cad_2d_gpu` | 20 tests; exactly | No issues | 10 files, 0 changed |
| `packages/jet_cad_2d` | exit 1 (the 2 standing); "1258 tests; the standing failures and skips, exactly" | `--fatal-infos`: No issues | 170 files, 0 changed |
| `packages/jet_cad_2d_flutter` | exit 1 (the 7 standing goldens); "1415 tests; the standing failures and skips, exactly" | No issues | 227 files, 0 changed |

`git status` clean afterwards; no `analysis_options.yaml` committed. Pushed as `5c72a5e..834c832`.
