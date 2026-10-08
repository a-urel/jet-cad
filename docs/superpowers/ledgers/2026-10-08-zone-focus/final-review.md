# Final review: the zone focus slice, `14616d9..03a6805`

**Reviewer:** independent final reviewer. **Range:** `14616d9..03a6805` on
`claude/exciting-pasteur-9m22jv`, 10 commits.

**Clones:**
- `/tmp/zone-final/repo` ran the gates and the base count at `14616d9`.
- `/tmp/zone-final/mut` ran the probes, the mutants and the host probe.

**Rules kept:**
- Nothing was committed.
- Every mutated file was restored from a scratch copy and checked with `cmp`. All 20 restores printed `cmp=0`.
- `git status --short` is empty in both clones at the end.
- The only file written in `/home/user/jet-cad` is this one.

**Read:** CLAUDE.md, spec rev 2, the plan, the results note, and the ledger (the spec review, three task reports and three task reviews). I checked the ledger's claims against the code and the diff rather than taking them on trust.

## Verdict

**Approve with fixes.** No finding blocks the merge.

- The code does what spec rev 2 says. I found no correctness defect in the code paths that cross the tasks:
  - framing with the focus;
  - groups with the focus;
  - `visible` with framing and with the veil;
  - a mode switch;
  - Undo and service moves;
  - a layer toggle followed by a switch;
  - `load`, `newPlan` and `restoreServiceLayout`;
  - dispose.
- Every gate is green, and I re-ran each one. The standing comparison is exact.
- The engine, the renderer and the GPU package have an empty diff. No golden and no allocation invariant was touched.
- The findings are:
  - one test gap, where a mutant survived (F-2). I wrote and verified a killer for it;
  - three host-guide inaccuracies or omissions that a POS author would hit (F-1, F-3, F-4);
  - five nits.

### The API as a host sees it (Monépro's Appendix B.2)

- **Zone tabs:** `fitToTables(codes)`, optionally with `setTableFocus(codes)`. *All* is `fitToView()` plus `setTableFocus(null)`.
- **"My tables":** `setTableFocus(myCodes)`. Combined with a zone, it is the intersection.
- **The unplaced list:** `tables` plus `FloorPlanTable.visible`, as a set difference.
- These cover B.2's floor screen with no new barrel export. The API is complete for B.2.

#### The surprises I looked for

- **`fitToTables` true, yet nothing visible framed.** This happens in two cases:
  - a table whose own node is invisible (F-6). Only a hand-edited file can produce one;
  - a table so far out that its camera is not finite. The page is then fitted (Task 1 R-1). The results note says so; the guide does not.

  In the ordinary case, the call returns true only for Z0 candidates, which are the tables the selection mode draws and picks.
- **"Frame after a load", the guide's own advice, works in one step.** My probe PX1 (below) shows `load(json); fitToTables({'3'})`, with a view mounted, framing 3 in both modes. The old view's posted fit returns on `!mounted`; the new view's first-frame fit reads the new target.
- **The focus kept across a `load`** is specified (Z10) and documented. Its consequence for a host that loads another area into the same controller is not spelled out (F-4).
- **`fitToTables` in the design mode while the focus is drawn only in the selection mode.** This is by design (Z11), and the guide says "in the selection mode". The demo shows the switch in the design mode too, with no effect; the Task 3 review accepted this as R-5.

### Correctness across the tasks

All paths below are under `packages/jet_cad_floor_plan/lib/src/`.

- **Framing and the service copy.**
  - `framingFor` resolves on `_active.document` (`host/floor_plan_controller.dart:413-436`), so a service move, a restore, an Undo or a mode switch is followed.
  - Under X3 (framing read from the design), VZ3 and VF6 go red.
- **The focus and the groups.** The group fade (`service/table_group_painter.dart`, `_rebuild`) tests `lookup.visibleMembers`, which is built over the same Z0 candidates the veil uses. So:
  - a hidden focused member never un-fades its group;
  - a locked focused member does (RX1).
- **`visible` with framing and the veil.** `_onVisibleLayer` (`host/floor_plan_controller.dart:842`) applies the same layer rule as `TablePicker.candidatesOf` (`service/table_picker.dart:242`).
- **A layer toggle in the design mode, then a switch.**
  - `setMode` builds a fresh service copy from the design (`host/floor_plan_controller.dart:719-737`). The service copy therefore never diverges from the design's layers.
  - X13 (`tables.visible` read from the design while the active plan is the copy) survives, and I judge it **equivalent**: the copy is decoded from the design's JSON, so it has the same handles and layers, and nothing edits the design while the copy is active.
- **`load`, `resetLayout` and `restoreServiceLayout`.**
  - `ServiceView` is keyed by `ObjectKey(document)` (`host/floor_plan_view.dart:205-206`). Each of these calls builds a new view, with new veil and group painters over the new copy.
  - The focus survives all three, pinned by CF3 (X7 and X8 are red).
- **Dispose.**
  - `_focus` is disposed with the controller (CF5).
  - A posted `_fit` on an unmounted view returns before it calls `framingFor` (`planner_view.dart:179`), so a torn-down controller is never asked to frame.

### The non-negotiables

- **The frame path.** Per frame:
  - `TableFocusPainter.paint` reads two ids and the focus identity, fills one reused `Float64List(16)` and draws one prebuilt `Path` with one reused `Paint`;
  - the group painter sets the stroke width on its two prebuilt paints.

  Nothing is allocated per entity in steady state. X9 (the rebuild key's focus never stored, so the veil rebuilds on every frame) is red in FP3, FP4, FP5, VF4, RV1 and RV2.
- **Allocation invariants and goldens.** `git diff --stat 14616d9..03a6805 -- packages/jet_cad_2d packages/jet_cad_2d_flutter packages/jet_cad_2d_gpu` prints nothing. The range touches no `*.png` or golden file.
- **Draw order.**
  - The veil is one `drawPath`.
  - Group frames still sort by their lowest member handle.
  - The overlay order is veil, then chips. The selection outlines stay above both (RV3 and TG-Z4 pin it).
- **I-6, existing tests unedited.** `git diff -U0 14616d9..03a6805 -- '*test*'` removes two lines, both import widenings:
  - `controller_test.dart`: `show Color` became `show Color, Size`. This is recorded in the Task 1 report.
  - `demo_test.dart`'s `show` list. This is recorded in the Task 3 report.

### Docs, checked claim by claim

**The host guide's "Zones: framing and focus"** (`docs/host-guide.md:398-470`). Every sentence matches the code except the following:
- the inert recipe (F-1);
- the comparison sentence and "can never match" (F-3);
- the unstated consequence of keeping the focus across a load (F-4);
- "A group with a focused member draws as before": precisely, a focused *visible* member. This is not worth an edit.

The § 4 cross-reference is right.

**The CHANGELOG's Unreleased section.** Every statement is true. It omits two behaviour changes to existing API (F-8).

**STATUS.** True:
- The tag `v0.2.0` exists at `7355c00`: `git ls-remote --tags` gives `7355c001f585…`.
- The in-flight entry links the spec, the plan and the results.
- "Next" is this review.

**Roadmap row 14.** True: spec, plan and results are linked; "in review; a look owed".

**The results note.** I checked these claims against my own runs:
- planner 1,436 at the head, made of 1,435 at `5022cc9` plus RX1;
- 1,380 at `14616d9`: my run at `14616d9` printed `03:52 +1380: All tests passed!`;
- demo 39;
- `tool/ci` 58;
- `check_guide`: 16 blocks;
- the probe exits 0 with 42M;
- the engine and the renderer are untouched;
- the equivalence argument for O10 is correct. `Transform2.invert` (`jet_cad_2d/lib/src/geometry/transform2.dart:111`) throws on a zero or non-finite determinant, so no `ViewportTransform` with scale 0 can exist.

I did not re-run the Chromium smoke test. Its claims are the controller's.

**`dart run tool/ci/check_guide.dart`:** `docs/host-guide.md: all 16 code blocks are in the host probe`, exit 0.

## Findings

**F-1 — minor (doc) — `docs/host-guide.md:426-430`: the inert recipe misses two callbacks that act on a faded table.**
- **Scenario:**
  1. A host follows the recipe and gates `onTableTap`, `onTableContextMenu` and its `selectedTables` listener on `tableFocus`.
  2. A waiter under "My tables" taps a faded table that is a member of a group.
  3. `onGroupTap(groupId, number)` still fires, ungated, right after `onTableTap` (`service/table_select_tool.dart:291`; the guide's own `:394`). A host that opens the order from `onGroupTap`, as the guide's example does at `:174`, opens a colleague's order.
  4. Separately, Merge stays offered for a selection that holds faded tables (`host/service_view.dart:248`), and `onMergeRequested` receives them.
- **Fix:** name `onGroupTap` and `onMergeRequested` in the recipe's list of callbacks: "check `controller.tableFocus.value` in your `onTableTap`, `onGroupTap`, `onTableContextMenu`, `onMergeRequested` and `selectedTables` listener".

**F-2 — minor (test gap) — `packages/jet_cad_floor_plan/lib/src/service/table_focus_painter.dart:81-84`: dropping the previous veil region when every table becomes focused is unpinned.**
- **Mutant X12** clears `_region` only on a null focus. This leaves the last build's region in place when a rebuild finds no faded table (`!any`). X12 survives all 138 tests in the 9 zone-related test files.
- **Why it survives:** FP4 reaches "every table focused" only from a null focus, so `_region` was already null.
- **Scenario a regression would ship:**
  1. "My tables" = {1, 2, 3}, so table 4 is veiled.
  2. The waiter takes over table 4, and the host sets {1, 2, 3, 4}.
  3. The old veil stays drawn over table 4, now focused, until something else moves.
- **Fix:** land this test in `test/service/table_focus_painter_test.dart`, after FP4. It is green at `03a6805` and red under X12 (`Expected: empty, Actual: [`):

```dart
  test(
      'FX1 a veil drawn, then every table focused: nothing is drawn (the '
      'region of the last build is dropped, not kept)', () {
    final doc = rowOfTables(4);
    final camera =
        ValueNotifier(cameraOn(quadsOf(doc, (t) => t.number == '1').single));
    final focus = ValueNotifier<Set<String>?>({'1', '2', '3'});
    final painter = painterOn(doc, camera, focus, ValueNotifier<int>(kPaper));
    expect(spyFrame(painter).seen, hasLength(3), reason: 'premise: one faded');
    focus.value = {'1', '2', '3', '4'};
    expect(spyFrame(painter).seen, isEmpty, reason: 'every table focused');
  });
```

**F-3 — minor (doc) — `docs/host-guide.md:460-470`: the unplaced recipe and the number rules say more than the code does.**
- **(a) Trimming.**
  - `fitToTables` and `setTableFocus` trim the host's codes (`floor_plan_controller.dart:1001-1005`).
  - `unplacedTables` compares them untrimmed with the plan's trimmed numbers (`table_index.dart:91-94`).
  - **Scenario:** a POS code `' 7'` is framed and focused as table 7, yet listed as unplaced beside it.
  - "Your codes are compared with the plan's numbers trimmed" does not tell the host that it must trim.
- **(b) "A code that breaks those rules can never match a table in the plan."** This overclaims.
  - 14a T4 is enforced only where a number is typed (`selection_panel.dart:396`).
  - `TableSurvey.of` takes any non-empty trimmed `TABLE` label (`table_index.dart:91-94`). So a plan from a hand-edited or foreign file can hold a 12-character number, and a 12-character code would match it.
- **Fix:**
  - Say "trim your codes as the planner trims its numbers". Optionally make the recipe `codes.map((c) => c.trim()).toSet().difference(...)`, in the guide and the probe together.
  - Reword (b) as "the planner never writes such a number".

**F-4 — minor (doc) — `docs/host-guide.md:415-422`: the guide says to frame again after a `load`, but not that the focus needs resetting too.**
- **Scenario:** a POS keeps one controller per location and `load`s the chosen area's plan (decision 12: one plan per area).
  1. The waiter is on the Salon's zone A with "Fade the others" on.
  2. The waiter switches to the Teras.
  3. The framing is dropped (page fit), but the focus `{1…5}` is kept by number.
  4. If the Teras's codes differ, every Teras table is veiled. If they overlap, as in the demo (Salon 1–11, Teras 1–6), Teras 1–5 show and Teras 6 is veiled. Either way the result reads as the new area's zone.
- This is the specified behaviour (Z10, F-8's precedent). The guide states the rule, "kept across … loads", but not this consequence.
- **Fix:** one sentence after "frame after a load": "and set the focus again: it is kept by number, and the numbers may now name the new plan's tables or none of them".

**F-5 — nit (demo) — `apps/restaurant_demo/lib/main.dart:316-328`: `_revert` breaks its own guide's "frame after a load".**
- After *Reload*, the zone toggle still reads `B`, `tableFocus` is still `{6, 7}`, and the camera shows the page.
- **Fix:** in `_revert`, after the load, re-apply the area's zone:

```dart
if (area.zone case final z?) {
  showZone(area, area.zones[z]!, fadeOthers: area.fadeOthers);
}
```

  Alternatively, reset `area.zone`.

**F-6 — nit (rule) — `packages/jet_cad_floor_plan/lib/src/service/table_picker.dart:233-268` and `host/floor_plan_controller.dart:842-846`: Z0 and `visible` ignore `Node.visible`.**
- The renderer hides a node whose own `visible` is false (`jet_cad_2d/lib/src/index/query_filter.dart:176`, `:229`). `candidatesOf` checks only the layer.
- **Probe PX2:** I flipped B4's instance node to `"visible": false` in the zone fixture's JSON. The output was `PX2 fitToTables(B4) = true, visible = true`.
- By the code, such a table is not drawn yet is framed, veiled, picked, and counted as placed.
- **Reachability:** only a hand-edited file reaches this. `query_filter.dart:71` says nothing rewrites `Node.visible` yet, and the picker had the same rule before this slice.
- **Fix:** either add `if (!node.visible) continue;` in `candidatesOf` and the same test in `_onVisibleLayer`, or record it as an accepted gap beside Task 3's R-2.

**F-7 — nit (test gap) — `tool/ci/check_guide.dart` and `test/host/controller_test.dart` (CV3): the guide's `unplacedTables` recipe is executed nowhere.**
- **Mutant X16** drops `table.visible &&` from the recipe in both the guide and the probe, consistently. `check_guide` still prints "all 16 code blocks are in the host probe" and exits 0.
- CV3 runs its own third copy. Nothing calls the probe's copy.
- **Fix:** accept it, or have CV3 extract the recipe's body from `docs/host-guide.md` and compare it with its own copy.

**F-8 — nit (CHANGELOG) — `CHANGELOG.md` Unreleased: two behaviour changes to existing API are unlisted.**
- `fitToView()`'s fit now reads the view's size when it is performed, not when it is requested (Z7, V-7; `planner_view.dart:169-171`).
- The picker now skips a table whose box has a non-finite corner (Z0). Such a table was pickable at 0.2.0.
- Both are improvements, but a host can observe both.
- **Fix:** one line each.

**F-9 — nit (results note) — `docs/superpowers/notes/2026-10-08-zone-focus-results.md`, "Accepted gaps".**
- "R-5: the demo's toggle keeps its zone after *Fit*" does not say whose R-5 it is (it is Task 3's review).
- The Task 2 review's R-7, a far table through CanvasKit's `Path.combine`, is recorded under "Found, not fixed". It belongs in **Owed** too, so it is not lost at merge.

## Probes (scenarios, not mutants)

These were temporary tests appended to `test/host/view_test.dart` in the mutant clone, then restored (`cmp=0`).

| Probe | Scenario | Output |
|---|---|---|
| PX1 design | a mounted view, `load(json); fitToTables({'3'})` in one step | passed: `expectFramed` on 3 |
| PX1 selection | the same in the selection mode | passed |
| PX2 | B4's node set to `visible: false` in the JSON | `PX2 fitToTables(B4) = true, visible = true` → F-6 |

## Mutants

**Method:**
1. `/tmp/zone-final/scripts/mut.py` applies each mutant by exact replacement, asserting that the anchor occurs exactly once.
2. It runs 9 files with `flutter test --file-reporter json:` (138 tests):
   - `test/host/{view,controller,table_fit,table_groups_look,seams,barrel}_test.dart`;
   - `test/service/{table_focus_painter,table_group_painter,table_picker}_test.dart`.
3. It classifies each result from the JSON and restores each file from a snapshot, checked with `cmp`.

The 9 files were green before any mutant (`00:51 +138: All tests passed!`).

| # | Aimed at (across tasks) | Mutation | Result: killers |
|---|---|---|---|
| X1 | the veil and the camera | `_c.camera` dropped from the veil's repaint merge (`service_view.dart`) | **red**: VF4 |
| X2 | the groups and the focus, wired in the view | `ServiceView` stops passing `tableFocus` to the group painters | **red**: TG-Z3 |
| X3 | framing and the service copy | `_tablesBounds` reads `_design.document` | **red**: VZ3, VF6 |
| X4 | a non-finite framing | `framingFor`'s finite check reduced to `m.a.isNaN` | **red**: VF6 |
| X5 | overflow-safe centre | `frameTables`' centre computed as `(min + max) / 2` | **red**: VF6 |
| X6 | the framed box | `TableCandidate.worldBounds` skips the fourth corner | **red**: 13 tests (CZ1, CZ2, CZ4, VZ1, VZ3, VZ4, VZ6, VZ7, …) |
| X7 | the focus and a restore | `restoreServiceLayout` clears the focus | **red**: CF3 |
| X8 | the focus and `newPlan` | `newPlan` clears the focus | **red**: CF3 |
| X9 | the frame path's allocation | the veil never stores `_builtFor`, so it rebuilds every frame | **red**: FP3, FP4, FP5, VF4, RV1, RV2 |
| X10 | framing and a mode switch | `setMode` clears the fit target | **red**: VZ10 |
| X11 | Z10's "every call notifies" | `_Focus.replace` notifies only on a changed set | **red**: CF1, VF2 |
| X12 | the veil, then all focused | `_region` cleared only for a null focus | **survived** → F-2; **red** under FX1 |
| X13 | `visible` in the selection mode | `tables` reads layers from `_design.document` | **survived; equivalent** (above) |
| X14 | the group fade with an empty focus | `focus.isNotEmpty &&` added to the fade test | **red**: TG-Z1 |
| X15 | the framing and `load` | `_replaceDesign` keeps `_fitTarget` | **red**: VZ2 |
| X16 | the guide recipe, executed | `table.visible &&` dropped in the guide and the probe consistently; `check_guide` run | **survived** (exit 0) → F-7 |

Tally: 13 red, 2 survived (X12 and X16; X12 now has a verified killer), 1 equivalent (X13).

## Gates (run by me, at `03a6805`)

From `/tmp/zone-final/repo`, after `flutter pub get`, with `PATH=/root/sdk/flutter/bin:$PATH CI=true`.

**Planner** (`flutter test --file-reporter json:/tmp/zone-final/out/planner.json`):

```
04:05 +1436: All tests passed!
flutter test exit=0
```

**Planner, then the demo, `tool/ci`, the floor planner and the engine/render diff**, as one script's output, verbatim. The stray `0` line is a leftover no-op `grep -c . /dev/null` in my script.

```
=== planner
flutter test exit=0
0
packages/jet_cad_floor_plan: 1436 tests; the standing failures and skips, exactly
expect_failures exit=0
No issues found! (ran in 7.2s)
analyze exit=0
Formatted 242 files (0 changed) in 0.92 seconds.
format exit=0
=== demo
00:24 +39: All tests passed!
test exit=0
apps/restaurant_demo: 39 tests; the standing failures and skips, exactly
expect_failures exit=0
No issues found! (ran in 3.8s)
analyze exit=0
Formatted 4 files (0 changed) in 0.04 seconds.
format exit=0
=== tool/ci
00:04 +58: All tests passed!
test exit=0
No issues found!
Formatted 11 files (0 changed) in 0.02 seconds.
format exit=0
docs/host-guide.md: all 16 code blocks are in the host probe
check_guide exit=0
=== floor_planner
No issues found! (ran in 4.6s)
analyze exit=0
=== engine/render diff
0
```

The last `0` is `git diff --stat 14616d9..03a6805 -- packages/jet_cad_2d packages/jet_cad_2d_flutter packages/jet_cad_2d_gpu | wc -l`.

**The base count, at `14616d9`:** `03:52 +1380: All tests passed!`

**Host probe**, at the full SHA (`tool/ci/host_probe.sh "file://$PWD" "$(git rev-parse HEAD)"`, mutant clone, clean tree). The last lines:

```
/tmp/zone-final/mut/tool/ci/host_probe/pubspec.lock: 40 packages, none of flutter_scene, flutter_gpu, flutter_gpu_shaders, scene, jet_cad_2d_gpu
No issues found! (ran in 4.1s)
...
Compiling lib/main.dart for the Web...                             51.7s
✓ Built build/web
host probe: no GPU renderer, no build hook; build/web is 42M
probe exit=0
```

**Cleanup:**
- The probe's `build/`, `.dart_tool/`, `pubspec.lock`, `pubspec.yaml` and `.flutter-plugins-dependencies` are removed. `git status --short --ignored tool/ci/host_probe` is empty.
- The pub cache holds a git cache for `file:///tmp/zone-final/mut`, which only this review used.

## For the fixes

| # | Severity | What to do |
|---|---|---|
| F-1 | minor | the guide's inert recipe gains `onGroupTap` and `onMergeRequested` |
| F-2 | minor | land FX1 |
| F-3 | minor | the guide: trim the codes; "never writes such a number" |
| F-4 | minor | the guide: set the focus again after a load |
| F-5 | nit | the demo's `_revert` re-applies the zone |
| F-6 | nit | `Node.visible` in Z0 and `visible`, or record it as accepted |
| F-7 | nit | accept, or tie CV3 to the guide's text |
| F-8 | nit | two CHANGELOG lines |
| F-9 | nit | the results note: "Task 3's R-5"; Task 2's R-7 under Owed |

None of these changes behaviour that a test pins, except F-5 (a demo change) and F-6 if it is taken. Either one needs its own test, with the named mutant seen red.

---

## Controller's disposition

F-1, F-2, F-3, F-4, F-5, F-8, F-9 applied in the commit after `03a6805`:
FX1 red under X12; CV3's trimmed codes red under the untrimmed recipe.
F-6 and F-7 (X16) accepted and recorded in the results note.
