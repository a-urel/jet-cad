# Slice 2, Task 3 review: `designChanges` (E-5)

Commit under review: `69d56fc` (parent `a148b51`) on `claude/exciting-pasteur-9m22jv`.
My clones are `/home/user/review-s2t3` (gates) and `/home/user/review-s2t3-mut` (mutants, plus probe tests that are not for commit). I edited, committed and pushed nothing in `/home/user/jet-cad` except this file.
Flutter `/root/sdk/flutter/bin` (3.47.6), `CI=true`.

## Verdict: **Approve with fixes**

- The diff is Task 3 and nothing else, and P-1 and invariant 5 hold.
- Every gate is green, and the engine and render standing sets match exactly.
- All five named mutant forms are red, including the M-H25 variants.
- 15 of my own 20 mutants are red against the committed suite.
- The code is correct on every behaviour I probed (§2). I wrote nine probe tests, P1–P9, plus P10, and all pass on `69d56fc`.

The fixes are three test gaps (R-1 to R-3) and a doc comment (R-4). Three of my mutants survive the committed suite, and a probe of a few lines kills each one. The other two survivors are equivalent (R-5). None of the fixes is a defect in the committed code.

## 1. Scope and P-1

`git diff --stat a148b51 69d56fc` shows 5 files, all in `packages/jet_cad_floor_plan`:
- the barrel;
- new `lib/src/host/design_changes.dart`;
- `lib/src/host/floor_plan_controller.dart`;
- `test/host/barrel_test.dart`;
- new `test/host/design_changes_test.dart`.

`--diff-filter=M` lists exactly one existing test, `barrel_test.dart`. Its diff is B1's five names plus a new test, B6. No other existing test changed. The engine and `jet_cad_2d_flutter` are untouched, and no `analysis_options.yaml` was committed.

- **Barrel.** It gains exactly one export of `design_changes.dart`: `show FloorPlanDesignChange, FloorPlanPlanReplaced, FloorPlanTableAdded, FloorPlanTableChanged, FloorPlanTableRemoved`. B1's exact set matches. `diffTableDetails` (it takes `Handle`s) is not exported.
- **Invariant 5.** No handle crosses the barrel. The four changes carry only `FloorPlanTableDetail`, which has no handle. `_DesignBaseline` is private.
- **Classes.**
  - The base is a `sealed` class with a const constructor, `@immutable`, and the four `final class`es extend it (P-9 prefix).
  - `==` is by type and fields, and `Changed` is ordered.
  - `hashCode` is `Object.hash(Type, …)`, and `PlanReplaced` uses its type's hash.
  - `toString` is `Name(detail)` / `Name(before, after)` / `FloorPlanPlanReplaced()`.
  - DC13 pins each of these on non-default details, equal but not identical.
- **P-1.** No public signature changes. `_detailsOf` (private) gains the survey it reads, and `tableDetails` passes `_tables`, so its behaviour is the same.

## 2. Correctness

How it works:
- A merge-walk over two lists that are each ascending by instance. `TableSurvey.tables` is "ascending by handle" (`table_index.dart:49`, `:75-87`).
- Output is in ascending instance order, O(n + m).
- `Changed` only where the details differ by `==`.

Each point below was checked by reading the code and by a test or a probe.

| Point | Result | Evidence |
|---|---|---|
| Delete → `[Removed]`; undo → `[Added]` equal to it, data included; redo | ✔ | DC5 |
| Move of either 7 → one `Changed` of that instance | ✔ | DC6 |
| Renumber → one `Changed`, data kept | ✔ | DC3 |
| Data-only edit; the same data again → nothing | ✔ | DC1, DC4 |
| Layer lock → one `Changed` per table on it; undo reverses | ✔ | DC2 (8 tables) |
| Layer edits reach it: `SetLayerCommand` moves `stateId` and fires `changes` | ✔ | DC2, P7 |
| Hidden layer shown → `5` gains geometry | ✔ | DC2 |
| A layer hidden → tables lose `center`, one `Changed` each | ✔ | P7 (the locked layer hidden; layer `0` is current and cannot be hidden) |
| Only while listened; one scan per moved design; none after the last cancel | ✔ | DC11 |
| Re-listen takes a fresh baseline | ✔ | DC11 (third listener), O4 |
| An edit and its undo in one synchronous step → nothing (`stateId` returns to the same id, `undo.dart:170-185`) | ✔ | P6 |
| `PlanReplaced` on `load`/`newPlan` in either mode, after the old design's pending diff | ✔ | DC8, DC9, DC10, P3 |
| A failed `load` (FormatException) emits nothing and loses nothing owed: decode fails before `_replaceDesign` | ✔ | P1 (not in the suite: R-3) |
| Service move, undo, redo, `resetLayout`, `restoreServiceLayout` → nothing | ✔ | DC7 |
| A mode switch emits nothing and scans nothing | ✔ | DC7, P9 |
| Listening first in selection mode after a service move, then a design edit → only that edit | ✔ | P2 (not in the suite: R-1) |
| An edit then `setMode(selection)` in one step → reported at once | ✔ | P10 (not in the suite: R-2) |
| Dispose closes the stream; nothing after; a listen after dispose gets `done` and no baseline | ✔ | DC12, P8 |
| A host listener that throws breaks nothing: delivery is async, the error goes to the listener's zone, the other listener hears all, undo works | ✔ | P4 |

**What does a listener that subscribes later see first?**
- The first listener's baseline is the design at the moment it listens. An edit queued just before that is not reported (DC11). Nothing like a snapshot is sent.
- A listener added while another already listens shares the existing baseline. Its first event can therefore be a change made *before* it subscribed (P5: listener A, an edit, listener B, a pump, and B hears the edit). That is harmless, because `before`/`after` carry everything. But the doc comment says otherwise (R-4).

**Cache interplay with `tableDetails`.**
- In design mode, `_designNow` reads `tableDetails` and then `_detailInstances`. That is the same cache the host and the overlays read, keyed on (document, `stateId`, layer revision), so a diff never computes the list twice.
- Reading `_detailInstances` before `tableDetails` would use stale instances. That mutant (O14) is red.
- In selection mode, the design's list is built from `TableSurvey.of(design)` on the design document. It is built only at listen and at a replacement, because the design does not move in that mode otherwise.
- Nothing runs on the frame path. With a listener, the cost is one scan per synchronous batch of design edits. Without a listener, it is zero (DC11's counter).

**Dispose.** `_disposed` is set first. The plans are detached, `_baseline` is cleared, and the controller is closed with `unawaited(close())`. The `_attach` listener returns once `_disposed` is set, so nothing can `add` after close.

## 3. Gates (my runs on `/home/user/review-s2t3` at `69d56fc`)

| Package | Result |
|---|---|
| `packages/jet_cad_floor_plan` | `flutter test`: **+1556 All tests passed!**; `flutter analyze`: No issues found; format: 255 files, 0 changed, exit 0 |
| `apps/restaurant_demo` | **+47 All tests passed!**; No issues found; format exit 0 |
| `apps/floor_planner` | **+212 All tests passed!**; No issues found; format exit 0 |
| `packages/jet_cad_2d` | `dart test --file-reporter json:…` exit 1; `dart run tool/ci/expect_failures.dart --package packages/jet_cad_2d --root packages/jet_cad_2d engine.json`: "packages/jet_cad_2d: 1258 tests; the standing failures and skips, exactly" (exit 0) |
| `packages/jet_cad_2d_flutter` | `flutter test --file-reporter json:…` exit 1; comparison: "packages/jet_cad_2d_flutter: 1374 tests; the standing failures and skips, exactly" (exit 0) |

These match the implementer's counts.

## 4. Mutants

**How they were run.**
- Each mutant is applied by script (`scratchpad/mut/mutants.py`, `run.py`) in `/home/user/review-s2t3-mut`.
- Each is run against two sets:
  - "suite": `design_changes_test.dart` and `barrel_test.dart`;
  - "probe": my `test/host/review_dc_probe_test.dart`, with P1–P9, which is not for commit.
- After each run the original file is copied back, and an assertion checks it byte for byte. `git status` is clean afterwards except for the untracked probe files.
- A baseline run first gave suite +20 and probe +9, all green.

### Named (plan, "Mutants per task", Task 3)

| Mutant | Suite | Killer(s) |
|---|---|---|
| M-H25, diff keyed by list index | RED | **DC5**, DC14 |
| M-H25, keyed by number, last wins | RED | **DC6**, DC2, DC3, DC14 |
| M-H25, keyed by number, first wins | RED | **DC6**, DC2, DC3, DC14 |
| M-H25, diff by value | RED | **DC6**, DC1–DC4, DC7, DC9, DC11, DC14 |
| M-H29(service moves), full form (trigger, list and `isAt` key on `_active`) | RED | **DC7** |
| M-H29(service moves), trigger only (`identical(plan, _active)`) | **survived** | none in the suite. P10 kills it (R-2) |
| M-H29(PlanReplaced in the selection mode) | RED | **DC10** |

### My own

| # | Mutant | Suite | Notes |
|---|---|---|---|
| O1 | Diff output reversed (order of emission) | RED | DC1, DC2, DC14 |
| O2 | No flush in `_replaceDesign` | RED | DC9 |
| O3 | `PlanReplaced` emitted before the flush | RED | DC9 |
| O4 | Baseline kept across cancel and re-listen (`onCancel` no-op, `??=`) | RED | DC11 |
| O5 | `Changed` emitted when equal | RED | 10 tests |
| O6 | `PlanReplaced` emitted on `setMode` | RED | DC7 (P2, P3, P9) |
| O7 | `_designNow` always reads the active plan's list (the service copy's in selection mode) | **survived** | P2 kills it (R-1) |
| O8 | `dispose` flushes the owed diff (emits at dispose) | RED | DC12 |
| O9 | `dispose` does not close the stream | RED | DC12 |
| O10 | A failed `load` emits `PlanReplaced` | **survived** | P1 kills it (R-3) |
| O11 | Design list in selection mode built from the service copy's survey (`_tables`) | survived | equivalent (R-5) |
| O12 | No `isAt` skip | RED | DC11 |
| O13 | `isAt` ignores `stateId` | RED | DC1, DC3–DC7, DC9, DC11 |
| O14 | Instances read before `tableDetails` (stale) | RED | DC5, DC6, DC7, DC11 |
| O15 | `Added` and `Removed` swapped | RED | DC5, DC14 |
| O16 | No new baseline after a replacement | RED | DC8, DC9 |
| O17 | `PlanReplaced` emitted and scanned with no listener | RED | DC11 |
| O18 | `isAt` ignores the layer revision | survived | equivalent (R-5) |
| O19 | `Changed(after, before)` | RED | 9 tests |
| O20 | Baseline not moved after a report | RED | DC2–DC6, DC11 |

For the trigger-only M-H29 and for O7, O10 and P10, I confirmed separately that the probe passes on the unmutated code and goes red under the mutant. For example, under the trigger-only mutant P10 fails with `Expected: an object with length of <1>  Actual: []`.

## 5. Findings

### R-1 (Minor, test gap): a baseline taken in selection mode is not pinned to the design (O7 survives)

`_designNow` correctly builds the design's own list when the design is not active. But no committed test takes a baseline in selection mode after a service move:
- DC10 listens in selection mode with nothing moved.
- DC7 listens in design mode.

A mutant that reads `tableDetails` (the **service copy's** list) for the baseline survives. The leak it allows is a P-5 / invariant 4 breach: a service move shows up as a `Changed` on the next design edit.

**Fix:** add P2 as a DC test:
1. `setMode(selection)`.
2. Move `1` in the copy (`TransformNodeCommand` on `activeDocument`, or a drag) and check `serviceEdited`.
3. Listen.
4. `setMode(design)`, pump, expect nothing.
5. `setTableData('2', …)`, pump, expect exactly one `Changed` for `2`.

### R-2 (Minor, test gap): the plan's literal M-H29(service moves) survives, and it is not equivalent

The implementer's finding 3 says the trigger-only form "survives because the diff reads the design, which never moved". That is not quite right. Under that mutant, a design edit followed by `setMode(selection)` in the same synchronous step is **not reported**: its event arrives when the design is no longer active. The change is withheld until the next design event or replacement, which may never come if the host stays in service. The committed code reports it at once (P10).

**Fix:** add P10 as a DC test: listen; `setTableData('2', {...})`; `setMode(FloorPlanMode.selection)`; pump; expect exactly one `Changed` for `2` with the new data. Keeping the full form as the recorded mutant is fine. The trigger alone should also be pinned.

### R-3 (Minor, test gap): "a failed load emits nothing" is not pinned (O10 survives)

`load` decodes before `_replaceDesign`, so a `FormatException` emits nothing and keeps the owed change. No test proves it: a mutant that emits `PlanReplaced` in `load`'s `catch` survives.

**Fix:** add P1 as a DC test: listen; `setTableData('1', …)`; `expect(() => c.load('not json'), throwsFormatException)`; pump; expect exactly `[Changed(1)]` (no `PlanReplaced`).

### R-4 (Minor, doc): `designChanges`' last paragraph

The doc says "a listener hears the changes made after it started listening". That is true for the first listener. A listener added while another listens shares the baseline, and can first hear changes made just before it subscribed (P5).

Two more points a host needs:
- There is no starting snapshot. In selection mode, `tableDetails` is the **service copy's** list, not the design's, so a host that snapshots there and then applies `Changed` gets mixed sources.
- An edit not yet reported when `dispose` runs is dropped (implementer finding 5).

**Fix:** reword along these lines: "The first listener starts from the design as it is when it listens; a listener added while another listens starts where that one is, so its first report may include a change made just before it listened. Nothing is sent on listen: read the starting tables yourself, in the design mode (`tableDetails` reads the service copy in the selection mode). Changes not yet delivered when [dispose] runs are dropped."

### R-5 (Info): two equivalent survivors

- **O11** (the selection-mode design list built from the service copy's survey). The survey contributes only number, seats, symbol and instance. Geometry, layer and data come from the design document. The copy is a decode of the design's encoding, so its handles are the same, and the selection mode cannot renumber. Equivalent today; the committed form (the design's own survey) is right.
- **O18** (`isAt` without the layer revision). Every layer edit that fires `changes` is a command and moves `stateId`.

No change needed.

## 6. Rulings on the implementer's findings

1. **DC1's fixture changed** (` 7 ` trims to the ambiguous `7`, so `setTablesData` returns false by E-6): **accepted.** The plan's fixture could not work. `L`, `4`, ` 1 ` is stronger: the keys are in descending instance order, so a report in edit order shows up, and `L` is locked. O1 is red on DC1.
2. **DC6 also moves `7`**: **accepted.** Both number variants (first wins and last wins) are red on DC6. With only ` 7 `, the last-wins map survives, as the implementer says.
3. **M-H29(service moves) only red in its full form**: **accepted as the recorded mutant, with R-2.** The trigger-only form is not equivalent. It delays an edit made just before entering selection mode, and P10 kills it. Add that test.
4. **Asynchronous delivery, one report per synchronous batch**: **accepted.**
   - It matches the dispatcher's own stream.
   - It never calls the host back from inside `load` or an edit.
   - It is documented.
   - Coalescing is net-correct: an edit and its undo in one step report nothing (P6), because `stateId` returns to the same id.
5. **An edit just before `dispose` is not reported (DC12)**: **accepted.** It is consistent with tearing down, and O8 shows DC12 pins the choice. Document it (R-4).
6. **`unawaited(cancel())` in DC11 because of a harness hang**: **accepted; reproduced, and not the controller's fault.** In `testWidgets`, `await sub.cancel()` followed by `tester.pump()` times out:
   - on `designChanges`, and also on a plain `StreamController<int>.broadcast()` with no controller code involved;
   - both runs failed with "TimeoutException after 0:01:00.000000" under a 60 s timeout (`test/host/review_cancel_probe_test.dart` in my mutant clone).

   The cancel itself is synchronous, so not awaiting it is right.
7. **Purge not handled**: **accepted.** No `purge(` call exists in `packages/jet_cad_floor_plan/lib` or in the apps the controller serves (the only call is in `apps/dev_harness_2d`). A future purge path in the controller would have to emit `PlanReplaced` (handles compact). That is worth a line in the plan's notes if one is ever added.
8. **`hashCode` includes the type**: fine. It is not a contract, and nothing asserts it.

## 7. What to change

Add three tests to `design_changes_test.dart` (R-1 P2, R-2 P10, R-3 P1), each seen red under its mutant (O7, M-H29 trigger-only, O10), and reword `designChanges`' last paragraph (R-4). No code change is needed.
