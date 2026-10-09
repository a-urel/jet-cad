# Slice 2: independent final review (events, host data on a table, schema 9)

Range: `672ae52..ec4956b` on `claude/exciting-pasteur-9m22jv`.

**Clones:**
- `/home/user/review-s2-final` at `ec4956b`: gates, host probe and docs.
- `/home/user/review-s2-mut`: mutants and probes.
- `/home/user/review-s2-diff` at `ec4956b`: the differential and probes.
- `/home/user/review-s2-base` at `672ae52`, then at `v0.3.0` for one run: the differential's other sides.

Probe files live only in those clones (`test/zz_review/`) and in my scratchpad.
I edited, committed and pushed nothing in `/home/user/jet-cad`; this file is the only thing written there.
Flutter is `/root/sdk/flutter/bin` (3.47.6), run with `CI=true`.

## Verdict: **Approve with fixes**

**Where the tasks meet, the code is right on every path I traced and probed:**
- table data × the delete expander × `designChanges`;
- schema 9 × loading an 8 plan × `PlanReplaced`;
- the service copy × data × `onTablesMoved` and the double tap;
- the Revert in the demo.

**Checks that came out clean:**
- **P-1:** holds.
- **Edited tests:** only the existing tests the plan allows were edited.
- **Gates:** every gate is green, and the standing sets are exact.
- **Differential:** a host that passes none of the new parameters sees **identical** behaviour on `v0.3.0`, `672ae52` and `ec4956b`, over 10,314 scripted gestures.
- **Saved plans:** they differ from `672ae52`'s only in `schemaVersion`.

**What the findings are:**
- **Two doc claims are not true as written:**
  - F-1: "changes not yet delivered are dropped" on `dispose`.
  - F-2: "a pick allocates nothing per table".
- **One guide recipe can read the wrong id (F-3).**
- **Three test gaps:** each is a survivor of mine on a seam the brief named (F-4, F-5, F-6).
- **Bookkeeping nits (F-7).**

None of them needs a redesign.

## 1. P-1 and invariant 1

**v0.3.0's probe.**
- `tool/ci/host_probe.sh file:///home/user/review-s2-final ec4956bda630cbdf64b1a91e117c5db7da62a34b` exits 0:
  - the lock has "40 packages, none of flutter_scene, flutter_gpu, flutter_gpu_shaders, scene, jet_cad_2d_gpu";
  - `flutter analyze` reports "No issues found!";
  - the web build passes: "host probe: no GPU renderer, no build hook; build/web is 42M".
- `tool/ci/old_host_probe.sh v0.3.0` prints "No issues found!" and "old host probe: v0.3.0's main.dart analyses against ec4956bda630cbdf64b1a91e117c5db7da62a34b", then exits 0.

**Barrel (`lib/jet_cad_floor_plan.dart`).**
- The diff adds exactly one `export … show` of the five `design_changes.dart` names and nothing else.
- `FloorPlanTableDetail`'s `==`, `hashCode` and `toString` are byte-unchanged. They already compared `data` with `mapEquals` at `672ae52`.
- `tableDetailOf` and `tableDetailWithoutGeometry` gain an optional named `data`.
- `FloorPlanView` gains four optional named callbacks.

**`lib/editor.dart`.**
- The file itself is unchanged.
- It exports `table_numbers.dart` and `table_index.dart` whole, so it gains `isControlCodeUnit` and `TableDiagnosticCodes.invalidData`. Both are additive.
- `TableSurvey`'s new field sits behind its private constructor.

**`jet_cad_2d_flutter`.**
- Its exports are unchanged.
- `ToolPointerEvent` (a `final class` with no `==`) gains `timeStamp = Duration.zero`.
- `_event` is private.

**`jet_cad_2d`.**
- Only `kSchemaVersion` and its comment change.

**Edited pre-existing tests** (`git diff --stat 672ae52 ec4956b -- '**/test/**'`, `--diff-filter=M`):

| File | Change | Allowed by the plan? |
|---|---|---|
| `json_codec_test.dart` | name, comments and pins 8→9 | yes |
| `instance_style_codec_test.dart` | same | yes |
| `page_component_roundtrip_test.dart` | same | yes |
| `layer_header_test.dart` | same | yes |
| `generate_document_test.dart` | comments only | yes |
| `barrel_test.dart` | five names in B1, plus a new B6 | yes |
| `controller_test.dart` | additions only | yes |
| `table_picker_test.dart` (TP14) | additions only | yes |

- For the last three, `grep '^-'` on their diffs is empty.
- Everything else under `test/` is a new file.

## 2. Interplay

### Table data × `designChanges`

- **Data-only changes.** A data-only edit is one `Changed` (DC4).
- **Delete and undo.** A delete reports `Removed` with the table's data, and its Undo reports an equal `Added` (DC5).
- **One synchronous step.** An edit followed by a `load` in the same step is reported as the edit's `Changed`, then `PlanReplaced` (DC9).
- **The expander's detach.** It happens inside the delete's own step and is restored by its replay. TD tests and HD12 cover this. My R15 (detach a live node's data too) is red.
- **Two edits in one step.** A `setTableData` and a Delete in one synchronous step report from the baseline taken before both. So that `Removed` carries the *old* data, and its Undo's `Added` then differs from it.
  - This is consistent with the documented "one report per synchronous step".
  - The editor cannot do both in one step: a key event flushes microtasks.

### Renumber × data × events

- DC3 and HD10 cover it: one `Changed` (number only, data kept).
- In the service, the moved and double-tapped detail reads the renumbered number and the data (my P2 probe).

### `onTablesMoved` carries data

- **Code:** correct. P2 sets `{'zeta','id','alpha'}` on `1` in the design, enters the service and drags `1`.
  - The moved detail's `data` equals the map, with keys `[alpha, id, zeta]`.
  - A double tap right after reads it from `tableDetails` in the callback.
  - `setTableData` there throws `StateError`.
  - Back in the design, the data is unchanged.
- **Tests:** untested (F-4).

### Double tap on a table whose data was just set

- It works. The service copy is re-encoded from the design at the switch, data included (P2).

### Schema 9 × loading an 8 plan × `designChanges`

- P3: `load` of the fixture with its version set to 8 reports exactly `[FloorPlanPlanReplaced()]`.
- `designJson()` is then byte-equal to the schema-9 encoding, and `dirty` is false.
- A later `setTableData` is one `Changed`.

### Service copy and service moves

- **Data is read only in the service.** HD5 and HD4 cover it, and so does P2.
- **Service moves never reach `designChanges`.** DC7 and DC16 cover it, and my R03 and R04 are red.

### `setTableData` in the selection mode throws

- HD4 covers it. My R09 (the limits checked before the mode) is red.

### The demo's Revert

The layout restore now happens on the asynchronous `PlanReplaced` (`apps/restaurant_demo/lib/main.dart:344-361`, `:472-487`). I find it correct on every path:

- **Revert in the design mode.**
  - `PlanReplaced` arrives with the mode at design, so no restore is attempted.
  - Without the mode check, `restoreServiceLayout` would throw `StateError` asynchronously once the area keeps a layout. My P5 probe shows this: service, drag, design, Revert. It is green as committed and red with the mode check removed.
  - The committed suite does not cover this path (F-5).
- **No listener.**
  - The demo subscribes every area in `initState` and cancels before it disposes the controllers (`main.dart:290`, `:299-301`). So no state of the demo has a Revert without a listener.
  - A host copying the pattern must keep that invariant; the comment at `:337-343` says so.
- **A failed load.**
  - `load` throws before `_replaceDesign`, so no `PlanReplaced` and no restore.
  - The old code also threw before its restore, so this is unchanged.
- **Order against `showZone`.**
  - The restore now runs after `showZone` instead of before it.
  - Both run before the next frame. `restoreServiceLayout` touches neither `_fitTarget` nor the focus, and the framing is computed post-frame on the active copy. So the result is the same.
- **A restore for any replacement in the service.** Revert is the demo's only replacement.

## 3. Frame path

**Both allocation invariants are green and ran rather than skipping** (JSON reporter, `skipped: false`):
- `query_allocation_test`: all 7 tests and their setUp/tearDown pass.
- `paint_allocation_test`: all 3 tests pass.

**Nothing new on pan or zoom.**
- `TableSelectTool` is not on either measured path.
- The view events add nothing to the painters or the camera listener.

**The hover path, per mouse move, at `ec4956b`:**
- `events()` returns identity-cached records: `FloorPlanView._serviceEvents` (`floor_plan_view.dart:268-280`) and `ServiceView._toolEvents` (`service_view.dart:115-128`). Both are tear-offs made at build or `initState`, not per move.
- With no callback there is no pick.
- With one, `TablePicker.candidates` is a cache check, then the pick.
- `_tap` allocates an `Offset` and a record per tap, at tap rate, which is fine.

**Reading the code would say the pick no longer allocates per table. Measured, it does, in the JIT: see F-2.**

## 4. Docs against code

**Checked true.** The guide's new section, § 4, § 7's `unplacedIds`, § 8, § 11's schema 9 bullet, the CHANGELOG's Unreleased and `schema_version.dart`'s entry 9 match the code on all of these points:
- **Limits:** 32 keys; a key of `^[a-z0-9_.-]{1,64}$`; a value of at most 1024 code units, with `isControlCodeUnit`; an empty value allowed.
- **Return values:**
  - false for an unknown or ambiguous number, or for two keys that trim to one number;
  - true with no step for equal data.
- **Exceptions:**
  - `StateError` in the selection mode, checked before the limits;
  - `ArgumentError` before anything changes.
- **Flags:** `dirty` and `canUndo` are synchronous on return.
- **Ordering:**
  - `onTablesMoved` is ascending by handle, which is `controller.tables`' order, and comes after `onLayoutChanged`;
  - `onFloorTap` comes after the selection logic.
- **Delivery:**
  - asynchronous, through a non-sync broadcast controller;
  - `_replaceDesign` flushes first, and a failed `load` reports nothing.
- **Hover:** no reach, null over an interactive overlay.
- **Data:**
  - the component shape, keys written sorted;
  - Delete drops it and Undo restores it;
  - a payload outside the limits is kept as read (re-encoded).
- **Schema 9:** refused by 0.3.0 and 0.2.0; 8 and 7 open.
- **Probe and guide:** `check_guide` reports "docs/host-guide.md: all 32 code blocks are in the host probe".
  - My mutant on a guide-only block (`data['id']` → `data['ref']` in `designChanged`) made it exit 1 with "not in the host probe: dart: /// The designed floor changed: …". Restoring the guide brought it back to exit 0.

**Libraries and spec references.**
- Both libraries are re-encoded with only the version changed. `git show 672ae52:<f> | sed 's/"schemaVersion":8/"schemaVersion":9/' | cmp - <f>` is equal for `furniture.jetlib` and `restaurant.jetlib`.
- Each sample plan's diff is the version line alone.
- **O-10:** `tree.dart:557-570` is `_link`, which appends.
- **O-11:** `_paintGrips` is at `selection_overlay.dart:248`.

**Not true:**
- the `dispose` sentence (F-1);
- the "allocates nothing per table" sentence (F-2);
- the guide's `idOf` recipe on a duplicated number (F-3).
- The spec also misses four Task 4 rulings (F-7).

## 5. Gates at `ec4956b` (rerun by me)

| Package | Result |
|---|---|
| `jet_cad_2d` | `dart test` `+1256 -2` (exit 1, as designed); `expect_failures.dart --package packages/jet_cad_2d --root packages/jet_cad_2d`: "1258 tests; the standing failures and skips, exactly", exit 0; `dart analyze --fatal-infos` No issues; format 170 files, 0 changed |
| `jet_cad_2d_flutter` | `+1371 ~1 -7`; comparison "1379 tests; the standing failures and skips, exactly", exit 0; analyze No issues; format 224 files, 0 changed |
| `jet_cad_2d_gpu` | `+20: All tests passed!`; comparison "20 tests; the standing failures and skips, exactly"; analyze No issues; format 10 files, 0 changed |
| `jet_cad_floor_plan` | `05:40 +1592: All tests passed!` (Task 5's 1585, plus `ec4956b`'s 7: VE14–17, SE14, SE15, TP14); analyze No issues; format 257 files, 0 changed |
| `jet_cad_restaurant_symbols` | `+97: All tests passed!`; analyze No issues; format 15 files, 0 changed |
| `apps/restaurant_demo` | `+55: All tests passed!`; analyze No issues; format 6 files, 0 changed |
| `apps/floor_planner` | `02:16 +212: All tests passed!`; analyze No issues; format 47 files, 0 changed |
| `tool/ci` | `dart test` `+62: All tests passed!`; CI's analyze list No issues; CI's format list 11 files, 0 changed; `check_guide` exit 0 (32 blocks) |
| host probe | as in §1: exit 0, 40 packages, web 42M; v0.3.0's probe analyses |

## 6. Differential (a host that passes none of the new parameters)

**The script.**
- File: `review-s2-diff/packages/jet_cad_floor_plan/test/zz_review/differential_test.dart`, with a copy in the scratchpad.
- It uses only 0.3.0's barrel API: `FloorPlanView(controller, onTableTap, onLayoutChanged, serviceMoves, onTableContextMenu, longPress, onGroupTap, onMergeRequested, onSplitRequested)`.
- Setup: a group set with `setTableGroups`, in the selection mode, at 1440×900, the camera at the view's own fit.
- Plans, both at schema 8 as `672ae52` wrote them, fed as the same bytes to every build:
  - the non-degenerate embedding fixture, with group `{1, 2}`;
  - the Salon, with group `{3, 4}`.

**At each point of a grid over the canvas** (step 56 px with default options; step 80 px with `serviceMoves: false` and `longPress: contextMenu`):
1. a mouse tap;
2. a Shift tap;
3. a quick double mouse tap;
4. a touch tap;
5. a mouse hover;
6. a secondary click;
7. a touch long press;
8. a mouse drag, with `serviceLayoutJson` logged;
9. a touch drag, with `serviceLayoutJson` logged.

Every third column adds `undo()` and `resetLayout()`, and each point ends with `fitToView()` so that the floor's pans do not drift the plan away.

**What is logged:** every callback, then the sorted selection, `selectedGroup`, `dirty` and `canUndo` after each gesture.

**Results.**
- **10,314 cases** (3,375 + 1,782 per plan): `cmp` reports the logs of `672ae52` and `ec4956b` **identical**, and those of `v0.3.0` and `672ae52` identical too.
- The run is not a vacuous one: it logged 292 `onTableTap`, 105 context menus, 89 group taps, 228 non-empty service layouts and 848 gesture lines with a non-empty selection, all identical across the three commits.
- **Saved plans:**
  - `designJson()` of both plans, and of an empty controller, at `ec4956b` equals `672ae52`'s once `"schemaVersion":9` is read back as 8. The byte diff is at char 18 of line 1 only.
  - `v0.3.0` and `672ae52` are byte-identical.
  - The service layout JSON is identical on all three.

## 7. Findings

### F-1 (Minor): after `dispose()`, changes already reported are still delivered, so the guide's "no cancel" recipe can touch disposed state

**Evidence.**
- `designChanges`' doc says "Closed by [dispose]: changes not yet delivered then are dropped" (`floor_plan_controller.dart:1310-1311`).
- The guide says "`dispose()` closes it, so a listener on a controller you dispose needs no cancel; changes not yet delivered then are dropped" (`docs/host-guide.md`, "The design's changes", last bullet).
- **Why this is not so:** `_replaceDesign` adds the flushed `Changed`s and `FloorPlanPlanReplaced` to the non-sync broadcast controller synchronously (`:951`, `:965-968`). `dispose` only `close()`s it (`:1726`), and a broadcast controller delivers pending data before done.
- **Probe P1** (listen; `load`; `dispose()`; pump): `seen=[FloorPlanPlanReplaced()] done=true`.
- **Probe P1b**, the guide's own `designChanged`, with `hovered` disposed after the controller as the guide's § 4 dispose block does:
  - setup: `setTableData('1', …)`, then `load`, then `dispose`, all in one step;
  - the handler runs after dispose with the flushed `FloorPlanTableChanged(…data: {}…, …data: {id: a})` and `PlanReplaced`;
  - `hovered.value = null` then throws a `FlutterError` ("used after being disposed").
- DC12 pins only an edit whose dispatcher event was still queued, and that one is dropped.

**Fix: make the doc true in code.**
- Keep the controller `broadcast(sync: true)`.
- In `_reportDesign` and `_replaceDesign`, queue the changes and deliver them from one `scheduleMicrotask` that returns when `_disposed`. That keeps "one report per synchronous step" and the asynchronous delivery.
- Add DC12b: `load` then `dispose()` in one step delivers nothing, then done.
- *Alternatively*, reword both sentences: "changes already reported are still delivered after `dispose()`; cancel first if your handler touches what you dispose".

### F-2 (Minor): "a pick allocates nothing per table" is true for `Vector2` but not as measured: the JIT boxes about two doubles per candidate visited, before and after `ec4956b`

**Evidence.**
- **The claims:**
  - `TablePicker`'s doc (`table_picker.dart:173-175`, `:289-292`);
  - `ec4956b`'s message ("allocates no Vector2 per table" and, in the class doc, "allocates nothing per table").
- **What the tests prove:** SE15 and TP14 count inverses through the new `invert` seam. They prove that `transformPoint` is no longer called and that the candidates are not rebuilt. They do not measure allocation.

**Measurement.**
- The engine's own `AllocationMeter` (`jet_cad_2d/test/invariants/vm_allocation_meter.dart`), copied into a probe, does reach the VM profiler in this package under `flutter test --enable-vmservice`. Without the flag it skips.
- Setup: `rowOfTables(60)` after a warm-up of 6,000 picks, measuring 1,000 picks each of a floor point, a top and a floor point with reach.
- **At `ec4956b`:** `_Double` 120,055 per 1,000 picks in each case, about 2 per candidate visited. Vector2 is 3, which is not per pick.
- **With `c276271`'s picker** (the old `transformPoint` code): the same 120,055, and Vector2 also 3. The JIT had already sunk the `Vector2`.
- **One table:** 2,055 both ways.
- **The numbers move with the JIT's state:**
  - one run read 41,865 for the floor case at the tip;
  - a variant that dispatches `contains` monomorphically (`top is PolygonTop && top.contains(…)`, then the same for `CircleTop`) read 55 in one run and 77,165 in another.
- So R-5's per-mouse-move O(tables) allocation is not shown fixed by this repository's own measure. AOT and the web are likely unaffected, but nothing measures them.

**Fix.**
- Either soften the doc and the class comment to "no `Vector2` per table" and record the JIT boxing, as `query_allocation_test`'s header does for its own bounded costs.
- Or make it true and measure it:
  - avoid passing the local point as doubles through the polymorphic `TableTop.contains`. For example, write it into a picker-owned `Float64List(2)` scratch that `contains` reads, or switch on the sealed type to static, inlinable helpers;
  - land an allocation test using `AllocationMeter` under a tag run with `--enable-vmservice`, skipping when the profiler is unreachable, as the engine's do.

### F-3 (Minor): the guide's `idOf` recipe (and the demo's `_opened`) reads the first table's id for a duplicated number

**Evidence.**
- `idOf` in the guide ("Your data on a table") and `DemoHomeState._opened` (`apps/restaurant_demo/lib/main.dart:400-409`) both return the first `tableDetails` entry with the number.
- **How it happens:** link `3` and `4` (ids differ), then renumber `4` to `3` in the editor, which `numberingWarnings` reports but allows.
  - A double tap on the second `3` reports `onTableDoubleTap('3')` (P-2: callbacks carry numbers).
  - The recipe then answers the *first* table's id, so the host opens the other table's bill.
- `setTableData` refuses exactly this ambiguity. The read recipe guesses instead.

**Fix.**
- `idOf` returns null when more than one detail carries the number. The demo does the same and logs "(ambiguous)".
- Add one guide sentence: "a number on two tables names neither: mend the numbering (`numberingWarnings`)". This mirrors `setTableData`'s refusal.

### F-4 (Minor): `onTablesMoved`'s details are never tested with data (a seam the brief named)

**Evidence.**
- My R19 replaces `_moved`'s details with copies that drop `data` (`service_view.dart:135-146`).
- It **survives** the planner's host and service suites (+117) and the whole planner and demo suites (§8).
- VE8 compares the moved detail with `c.tableDetails`'s, but on a table that carries no data.
- The code is right: P2.

**Fix.** Add VE18:
- `setTablesData({'1': …})` in the design, then the selection mode and a drag of `1`;
- expect `moved.single.single.data` to equal the map, with its keys in order;
- R19 as its mutant.

### F-5 (Minor): the demo's Revert in the design mode with a kept layout is untested

**Evidence.**
- My D01 drops the mode check in `_designChanged` (restore on any `PlanReplaced`). It **survives** all 55 demo tests.
- DE7's design Revert runs before the area has kept a layout, so `_restoreLayout` returns at `layout == null`.
- P5 (service, drag, design, Revert):
  - green on `ec4956b`;
  - red under D01 with `StateError` from `restoreServiceLayout` in the asynchronous handler.

**Fix.** Add P5 to `events_test.dart` as DE9:
- `takeException()` is null;
- the log reads "plan replaced", "reloaded";
- entering the service puts the kept move back.

### F-6 (Nit): the double tap's slop is not pinned to the down, rather than the up

**Evidence.**
- My R17 keeps `_lastScreen` (the last position before the up) as the chain's point instead of `_pressScreen`.
- It **survives** the host and service suites and the whole planner suite.
- The spec (E-2, S-6) says the slop is measured between the two downs. Every test's tap has up == down.

**Fix.** In SE2, let the first tap move 15 px (within `kTouchSlop`) before its up, so that the up-based distance crosses 100 px while the down-based one stays at 99.

### F-7 (Nit): bookkeeping

**Spec E-1 and E-4 do not record four Task 4 review rulings** that the dartdoc and the guide now promise:
- `onTablesMoved` is not called when `onLayoutChanged` replaced the plan;
- the moved list is unmodifiable;
- a hover has no reach;
- a hover reads null over an interactive overlay.

The spec's "Settled by Slice 2's plan" paragraph names only S-1 to S-6. Add an "Amended during Slice 2's implementation" line, as Slice 1 has.

**Still owed by the plan's Task 5 and its exit gate:**
- STATUS's resume point still says "Task 1 (schema 9)";
- the results note `docs/superpowers/notes/2026-10-09-embedding-slice-2-results.md`;
- the roadmap's row 14.

## 8. Mutants of my own

Each mutant was applied by exact single-anchor replacement in `/home/user/review-s2-mut`, run, and restored from a copy with an equality assert. The scripts are in `scratchpad/mut2/` (`mutants.py`, `run.py`, `run_wide.py`).
- "Host and service" means `design_changes_test`, `host/table_data_test`, `tables/table_data_test`, `view_events_test`, `service_events_test`, `barrel_test` and `controller_test` (+117).
- Survivors were rerun against the whole planner suite, with my probes moved out first (`05:1x +1592: All tests passed!` under each of R11, R16, R17 and R19), and R19 also against the demo (`+55: All tests passed!`).

| # | Mutant | Result |
|---|---|---|
| R01 | `_replaceDesign` does not flush the old design before the drop | **red**: DC9 |
| R02 | the baseline is not moved to the new plan after `PlanReplaced` | **red**: DC9 |
| R03 | the diff is fed by the active plan's events, not the design's | **red**: DC16 |
| R04 | `_designNow` always reads the active `tableDetails` | **red**: DC15 |
| R05 | the service copy reads no data | **red**: HD6 and others |
| R06 | a table with no geometry (hidden) drops its data | **red**: HD8 |
| R07 | `setTablesData`: two keys trimming to one number not refused | **red**: HD7 |
| R08 | `setTablesData`: `_refreshFlags` dropped | **red**: HD11 |
| R09 | `setTablesData`: the selection mode not refused before the limits | **red**: HD4 |
| R10 | `dispose` does not close the stream | **red**: DC12 |
| R11 | `_DesignBaseline.isAt` ignores the layers revision | **survived** (whole suite): equivalent today, because every layer change is a command and moves `stateId`; it is a defensive check |
| R12 | the diff reports `Changed` only when the `FloorPlanTable` differs | **red**: DC1, DC2, DC4 and 7 more |
| R13 | `FloorPlanTableData ==` compares keys only | **red**: TD3 |
| R14 | `fromJson` keeps a stored map unsorted | **red**: TD5 |
| R15 | the expander also detaches a live node's data | **red**: several |
| R16 | a detach alone raises the capability (the old `_stamped`) | **survived** (whole suite): equivalent, because a detach only follows a node removal, whose capability is already above `geometry` |
| R17 | double-tap slop measured from the up's point | **survived** (whole suite): F-6 |
| R18 | hover for the mouse only (stylus dropped) | **red**: SE12 |
| R19 | `onTablesMoved` details lose their data | **survived** (whole planner and demo suites): F-4 |
| R20 | the box pass's local point computed transposed | **red**: TP10, VE16 |
| D01 | demo: restore on `PlanReplaced` whatever the mode | **survived** all 55 demo tests: F-5 (my P5 is red) |
| D02 | demo: Revert also restores synchronously (a double restore) | **red**: DE7 |
| D03 | demo: Link tables drops the table's other keys | **red**: DE1 |
| G01 | a guide-only block edited (`data['id']` → `data['ref']`) | **red**: `check_guide` exit 1 |

That is 24 mutants: 18 red and 6 survived. Of the survivors, 2 are equivalent (R11, R16) and 4 are test gaps (R17, R19, D01; R19 and D01 are probed correct).

The probes P1, P1b, P2, P3, P4 (allocation) and P5 are under `test/zz_review/` in my clones and are not for commit.
