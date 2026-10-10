# Slice 4, Task 2: the two bars, `mergeCandidate`, an idle Undo, the canvas re-measured (independent review)

- **Commit reviewed:** `86115fa` (parent `ffe0b9c`), branch `claude/exciting-pasteur-9m22jv`.
- **Where:** my own clones, `/home/user/review-s4t2` (at `86115fa`) and `/home/user/review-s4t2-base` (at `ffe0b9c`). Both are deleted at the end of the review. Nothing was edited, committed or pushed in `/home/user/jet-cad`; this file is the only one written there.
- **Scratch:** `/tmp/claude-0/-home-user/428cafca-0083-5012-a7ac-5456349e70a8/scratchpad/rv-s4t2/`. It holds:
  - `probes/zz_rv_pixels_test.dart`, `probes/zz_rv_behaviour_test.dart` and `probes/zz_rv_killers_test.dart`;
  - `mutate.py`, `mutants.out` and `mlogs/`;
  - `base_goldens/`;
  - `struct_{base,task}{,_n}.txt`;
  - the JSON runs.
- **Environment:** Flutter 3.47.6 at `/root/sdk/flutter/bin`, `CI=true`.

## Verdict

**Approve once R-1 and R-2 are fixed. R-3 to R-5 are small and can land in the same fix commit.**

- The library is right, and the default bars are today's, pixel for pixel and element for element.
- One named killer does not hold its mutant's most natural form (R-1). The whole S-4 wiring can be removed and the suite stays green.
- The fixes for R-1, R-4 and R-5 are test or doc changes. R-2 is a one-line library fix.

## What I verified, and how

### 1. Scope, P-1 and P-6

- **The barrel** gains exactly `FloorPlanEditorAction`, `FloorPlanEditorBar`, `FloorPlanServiceAction` and `FloorPlanServiceBar` (the diff of `lib/jet_cad_floor_plan.dart`).
- **Existing tests:** the only one edited is `barrel_test.dart` B1 (+4 names). `git diff --stat ffe0b9c 86115fa -- '*/test/*'` shows that file and the new `bars_test.dart`, nothing else.
- **Untouched:** the engine, the render package, `tool/ci` and both apps (`git diff --quiet`).
- **`DocumentToolbar.groups` is additive:**
  - it is a second `const` constructor;
  - the existing constructor, its fields and `groupGap` are unchanged;
  - with the default constructor, `_children()` lays out exactly today's list literal (an empty group is skipped, and the gap only falls between two non-empty groups).
- **Pixel comparison against `ffe0b9c`** (`zz_rv_pixels_test.dart`, which compiles on both commits):
  - Goldens were written on the base and compared on the task: **60 of 60 identical**.
  - The cases covered:
    - light and dark;
    - the selection mode for every combination of `onExport`, `onMergeRequested` and `onSplitRequested` (8), each in three states: nothing selected; `1` moved and `{1, 2}` selected, so Undo and Merge are enabled; a group `{1, 2}` selected, so Split is enabled;
    - the design mode with and without `onExport`, fresh and after an edit;
    - a bare `PlannerShell` with the floor planner's seven file commands (one disabled), with and without a document name.
- **Structural comparison:** the same 60 cases dump the element subtree under `service-bar` or `chrome-top` (widget type, key, `SizedBox` size, `Text` data, padding). That is 16,836 lines, **identical once GlobalKey hashes are normalised**. "With no new parameter, every code path is today's, structurally" holds.

### 2. Correctness

| Claim | Evidence | Holds |
|---|---|---|
| Order and subset in both bars; today's rules inside the subset; 8 px and 12 px gaps | the implementer's M-H40 tests and gap tests; my mutants O3, O4, O15 and O25 are red | yes. One exception for a bare shell: **R-2** |
| A duplicate is refused (`ArgumentError` named `actions`), both bars, both modes | BT2; O12 is red | yes |
| `leading` and `trailing` are in place and reach the host's state | the S-19 tests | yes |
| A host `Spacer` or `Expanded` works | RV4: a `Spacer` in the service `leading` pushes Undo to x = 1124 and Print ends at 1428 (the bar's padding). An `Expanded` in the editor `trailing` shares the free width with the status line. No exception | yes |
| A host `TextField` takes the focus and text, and jet-cad's letters, Undo and Redo do not fire | T2-b, both bars | yes, but Ctrl+E, Ctrl+P and F3 still fire: **R-4** |
| `visible: false` gives the canvas the height | the two `visible: false` tests; my probe RV5 | yes |
| R-13, `canvasRect`, overlays and `worldToGlobal` follow a runtime toggle | `PlannerView._check` re-reports the rect each frame, so `canvasRect` follows. M-H47, T2-f and the "mode not shown" test are green after the correction frame | yes, after one frame: **R-3** |
| The theme's `serviceBarHeight` interplay | `_barHeightNow` runs only while the bar is shown. A height changed while the bar is hidden is caught when it is shown again (last ≠ now), and `_measureChrome` fires as well; the two measurements are idempotent. `theme_service_test` (60 px, T3-d) is green | yes |
| `mergeCandidate` is exactly what Merge sends; null in design; locked and hidden tables | M-H44, S-5, T2-d. RV7: `{1, L}` gives `selectedTables {1}` and null; `{1, 5}` gives `{1}` and null; a group `{2, L}` with `{1, 2}` selected gives `{1, 2}`, as `mergeQualifies` (the button's old source) does | yes |
| Notifications only on a change | the notification test. My mutant O5 (always assign) is **equivalent**, because `selectedTables` is replaced only on a content change, so the candidate is the identical set whenever it is equal | yes |
| S-4 idle wait: `canUndo` stays truthful; the selection mode acts at once; it holds across a document swap (`load` builds a new shell before the old is disposed) | T2-c, "the selection mode is unchanged", and my K2 | yes, but the killer is weak: **R-1** |
| S-4 breaks no host flow | Only a design-mode `undo()` or `redo()` while `Tool.isMidShape` is a no-op; the busy flag is null under the view. A host button enabled by `canUndo` presses to nothing; this is documented, and it is the shell's key behaviour | yes |
| S-20: the chords do not depend on `actions` | T2-e; the binding code is unchanged | yes |

### 3. Gates (my runs, at `86115fa` unless stated)

| Gate | Result |
|---|---|
| Planner `flutter test --enable-vmservice --file-reporter json` | `06:41 +1742: All tests passed!` (exit 0) |
| Planner standing comparison | `packages/jet_cad_floor_plan: 1742 tests; the standing failures and skips, exactly` (exit 0) |
| Planner analyze / format | `No issues found!` / `Formatted 267 files (0 changed)` |
| `apps/restaurant_demo` test / analyze / format | `00:41 +60: All tests passed!` / `No issues found!` / 8 files, 0 changed |
| `apps/floor_planner` test / analyze / format | `02:20 +212: All tests passed!` / `No issues found!` / 47 files, 0 changed |
| Engine `dart test` (exit 1, standing), then the comparison | `packages/jet_cad_2d: 1258 tests; the standing failures and skips, exactly` (exit 0) |
| Render `flutter test` (exit 1, standing), then the comparison | `packages/jet_cad_2d_flutter: 1390 tests; the standing failures and skips, exactly` (exit 0) |

I ran the engine and render packages in the base clone, because `git diff --quiet ffe0b9c 86115fa -- packages/jet_cad_2d packages/jet_cad_2d_flutter tool/ci` shows them byte-identical. That way the task clone was free for the mutants.

These match the implementer's counts.

### 4. Mutants

- Each mutant was applied textually by `mutate.py`, which asserts the site occurs exactly once.
- Each was run against `bars_test.dart`, `table_groups_toolbar_test.dart` and `theme_service_test.dart`.
- Each was restored from a copy and checked with `filecmp`. `git diff --quiet 86115fa` was clean afterwards.

**Named and task-local mutants (all re-applied by me): every one is red.**

| Mutant | Red in |
|---|---|
| M-H40 (service; editor buttons; editor read-outs) | the M-H40 tests |
| M-H44 | M-H44, T2-d, the notification test, TB1 to TB5 |
| M-H47 (no re-measure) | M-H47(serviceBar), T2-f |
| M-H47 (a 44 px box kept) | M-H47(serviceBar), T2-f, both `visible: false` tests |
| T2-a (service bar: gap after every action / no gap) | BC1 |
| T2-a (toolbar: no gap / a gap after every button) | BC2, BC3 |
| T2-b (inside `ExcludeFocus`; no guard in the editor; no guard in the service bar) | the T2-b tests |
| T2-c (undo check removed / redo check removed) | T2-c |
| T2-d (candidate not refreshed by `setTableGroups`) | T2-d, TB4 |
| T2-e (editor / service) | T2-e |
| T2-f | T2-f |

**My own mutants (21): 13 red, 8 survived the task's tests.**

| Mutant | Result |
|---|---|
| O1 default path off (always `_toolbarFor`) | red (BC3) |
| O2 a bare shell's other file commands dropped | red |
| O3 a group per button | red |
| O4 no gap between the read-outs | red |
| O6 no mode check on the candidate | red (M-H44) |
| O7 a modifiable copy | red |
| O10 Merge flag listening to `selectedTables` only | red (TB1 to TB4, T2-d) |
| O11 `_canvasMoved` measuring as the selection mode always | red (T2-f) |
| O12 editor actions not validated | red |
| O14 `toString` `visible` inverted | red |
| O15 Export shown without `onExport` | red |
| O23 the toolbar's two groups swapped | red |
| O25 Split gated by Merge's callback | red |
| **O17** the shell's probe always idle (`() => true`) | **survived**. Red with my K1 (R-1) |
| **O18** the view never passes `onIdle` | **survived**. Red with K1 (R-1) |
| **O8** the idle withdrawal unconditional (an old shell's dispose withdraws the new one's probe) | **survived**. Red with my K2 (R-1) |
| **O20** an empty toolbar kept for `[snap, zoom]` | **survived**. Red with my K3 (R-5) |
| **O24** guard only when `leading` is non-empty (a `trailing`-only host field unguarded) | **survived**. Red with my K4 (R-5) |
| O21 `_mergeCandidate.dispose()` removed | survived. Optional (R-5) |
| O5 the notification guard always true | survived, **equivalent** (see the table in section 2) |
| O9 the mid-shape check moved after the settle | survived, **equivalent**: the settle does not end a Polyline |

K1 to K4 are green on the unmutated tree. They are in `probes/zz_rv_killers_test.dart` (K5 is R-2's red test).

## Findings

### R-1 (Important): T2-c's killer cancels itself; the whole S-4 wiring can be removed with the suite green

**The problem.** T2-c calls `c.undo(); c.redo();` and only then checks the state id and the encoding. When neither call is guarded, the undo and the redo both act and cancel out. The state id and the encoded plan come back the same, and the shape stays pending.

- That is why the mutants that remove a single line (`undo`'s or `redo`'s check) are red, but the realistic regression is not.
- **O18**, the view not wiring `onIdle`, survives the whole task suite. So does **O17**, a probe that always reads idle.
- This is the same pattern as the implementer's own Finding 1 for T2-b, one test over.
- **O8** survives as well: a withdrawal that is not identity-checked would let an old shell's dispose drop the new shell's probe after a `load`.

**Fix (test only):**

- Check after each call alone. After `c.undo()`: the state id and encoding are unchanged and `canRedo` is unchanged. After `c.redo()`: the same.
- Add the swap case: a `load` in the design mode, a Polyline part-way, `undo()`, and the state is unchanged.
- My K1 and K2 do exactly this. K1 kills O17 and O18; K2 kills O8.

### R-2 (Minor, library): a bare shell's file commands gain a 12 px gap when only the read-outs, or the file order, change

**The cause.** `_toolbarFor` starts with `lastFile = null`. The first file action therefore opens a new group after the "other file commands" group, and a `groupGap` lands between Save As and Export (or Print). These are two file buttons, which S-2 and the class doc ("12 px between a file button and an edit button") say are not separated.

**Evidence.**

| Bare shell, seven file commands | Export | Print | Undo |
|---|---|---|---|
| default (`kBareEdges`) | 212 | 252 | 304 |
| `actions: [export, print, undo, redo, zoom, snap]` (only the read-outs swapped) (RV1) | 224 | 264 | 316 |
| `[print, export, undo, redo, …]` (RV1b) | 264 | 224 | — |

My K5 is red on the task (`Expected: <212.0>  Actual: <224.0>`).

**Reach.** It is only reachable through `PlannerShell`, which is not exported, with a non-default `editorBar`. The floor planner app uses the default, so no host sees it today. It is still a wrong rule in code the next tasks will extend.

**Fix.** In `_toolbarFor`, treat the leading run as file buttons: `bool? lastFile = groups.first.isEmpty ? null : true;`. The implementer's `[undo, redo, print]` test still holds with this change, and K5 turns green.

### R-3 (Minor): the one-frame offset is wider than Finding 4 says, and two docs over-claim

These are measured positions of table 1's centre: before the switch, in the first frame after it, and settled.

| Case | Before | Frame 1 | Settled |
|---|---|---|---|
| default bars, first switch (RV5a) | (657.6, 465.0) | (657.6, 465.0) | exact |
| service bar hidden from the start, first switch (RV5b) | 465.0 | **421.0** (44 off) | 465.0 |
| theme 60 px bar, first switch (RV5c), S-10's existing behaviour | 465.0 | **481.0** (16 off) | 465.0 |
| **editor bar hidden while in the selection mode, then a switch to design (RV5d)** | 465.0 | **421.0** | 465.0 |

**What the report leaves out.** Finding 4 names only the first switch into a mode whose bar is hidden. The same frame occurs at **every first switch after the not-shown mode's bar was toggled** (RV5d). The stored origin for that mode is stale until the new mode is measured.

**What the docs over-claim:**

- `FloorPlanView.serviceBar`'s doc says "the view measures where the canvas now starts, so a mode switch keeps the plan in place (R-13)".
- `canvasRect`'s doc says `worldToGlobal` is "right from the switch".

**Fix:**

- **Required:** amend both docs ("from the frame after the switch when a bar's visibility or height changed since that mode was last measured"), and name the limit in the report and the CHANGELOG list for Task 7.
- **Optional, for a later slice:** an internal `canvasAssumed(mode, origin)`. The view would call it at build, when a bar of the mode not shown changes visibility, with the known delta (44, or the theme's bar height), and at its first build for a hidden bar. That removes the frame.

### R-4 (Minor, doc): the bars' docs say the chords do not reach the plan from a host field; Export, Print and F3 do

- **Evidence:**
  - RV2: a focused `TextField` in the service bar's `leading`, Ctrl+E → handled, and `export-dialog` opens.
  - RV3: in the editor's `trailing`, F3 → handled, `osnap-text` goes from "OSNAP" to "osnap off"; Ctrl+E → the export dialog opens.
- **Why it happens:** `ShellShortcutGuard` deliberately guards only the letters, Undo, Redo and Escape ("The file chords are not guarded").
- **What is wrong:** `FloorPlanServiceBar`'s doc ("the bar's chords do not reach the plan from it") is wrong, and the editor bar's doc is incomplete.
- **Fix:** say "Undo, Redo and Escape (in the editor also the tool letters) stay in the field; the file chords (Export, Print) and F3 still act". Alternatively, guard F3 for host widgets as well, which is a behaviour decision for the controller.

### R-5 (Minor, tests): three cheap gaps

- **O20:** with `actions` holding no button, the toolbar and its 16 px must go. Killer K3: `[snap, zoom]` → `status-text` at x = 12.
- **O24:** the service bar's guard is tested only through `leading`. Killer K4: a host field in the service `trailing`, Ctrl+Z → the plan is not undone.
- **O21:** the new notifier's dispose is unchecked. This is optional. A `mergeCandidate.addListener` after `dispose` throwing would pin it.

### R-6 (Info): `mergeCandidate` is stale inside a `mode` listener

- **Evidence (RV6):** a `mode` listener reads `(design, {1, 2}, null)` during `setMode(design)`; the candidate becomes null a moment later, in `_select`.
- This is the order `selectedTables` and `selectedGroup` already have (`_mode.value = next` before `_select`), and the doc promises ordering only relative to `selectedTables` and `tableGroups`. No change is asked.

## Rulings on the implementer's findings

1. **The weak T2-b killer, fixed: accepted.** The fixed test is red under all three T2-b forms in my runs. The same undo-then-redo cancellation is still in T2-c: R-1.
2. **One guard around the whole row: accepted.**
   - Verified: a host `Spacer` and `Expanded` work (RV4).
   - The no-host-widget tree is today's (the structure dump).
   - The guard is inert for the buttons.
   - Its coverage for the service bar's `trailing` is untested (R-5, K4).
3. **The default editor path is today's call verbatim: accepted.** Verified by 60 identical goldens and identical element dumps. The non-default path has the R-2 gap.
4. **The one-frame offset: accepted for this task, as R-3.**
   - It is the plan's own mechanism: M-H47's killer says "(the seed corrected)", and S-10 already shows it at 16 px with a 60 px theme bar.
   - The report under-states it: it also occurs after a toggle of the not-shown mode's bar (RV5d).
   - The two docs must not promise "from the switch".
   - Recording it as a limit is required. Removing the frame is optional.
5. **`mergeCandidate` reuses the unmodifiable `selectedTables` set: accepted.** It is equal to what Merge sends, and it is immutable (O7 is red). The `setEquals` guard is redundant but harmless (O5 is equivalent).
6. **Members added beyond the public names** (`registerIdle` `@internal`; `ShellIdleRegistrar`, not exported; `PlannerShell.onIdle` and `editorBar`; `ServiceView.bar`; `DocumentToolbar.groups`): **accepted.** All are optional or a new constructor, so the plan's internal-constructor rule holds, and the barrel gains exactly the four names (R-1 of the spec's Risks).
