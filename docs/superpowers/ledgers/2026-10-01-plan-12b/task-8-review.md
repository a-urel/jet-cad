# Task 8 review — tools and hosts in the app (27db262 on 4c7eca3)

Reviewer: independent, in the detached worktree `.claude/worktrees/plan-12b-review` at 27db262. No tracked file left modified (`git status --short` empty after every run; every mutant restored by `cp` and checked with `diff`, exit 0).

## Verdict: **Approved with notes**

No product defect. The creation compounds, the placer, the attach gate and the host filter all do what D2, D6 (R-7), D7 and S-11 say, and the named mutants are red. The notes are two test gaps (one a file-only state) and one open question for the human's look list.

## What I checked in the diff

- **Creation compounds (six tools).** `SetComponentCommand<ObjectLayer>(h, ObjectLayer(drawingLayer(doc)))` is the last child of each tool's existing `CompoundCommand`. `ParametricSystem._expand` wraps the whole compound in **one** `ParametricEdit`, and `_run` regenerates once after the inner compound has applied. So the ObjectLayer write does not cause a second regeneration. On creation every child is *added*, through `_recordOf` with the object's layer, so the stamp's matched-child step plans nothing. Where the component sits relative to the params makes no difference. `SetComponentCommand.capability` is `components`, which is already in every tool's `needs` set. The permission surface is therefore unchanged: a runtime that holds `components` but lacks `structure`/`geometry` was already refused, and a read-only session is still refused. Undo removes the group, the children and the component in one step, as tested.
- **Symbol placer.** `InstanceNode.layer: drawingLayer(doc)`. The definition leaves stay on layer 0, as D7 says. Tested.
- **dimension_attach.** The new gate costs one component lookup plus one table lookup per *distinct* host wall found (the `walls` set dedups), and it runs only after `acceptsNode` passes. That is O(1) and allocates nothing. It matches D6: visible only, not locked, because "attaches only to what is drawn" and a locked wall is drawn. The doc comment is accurate and the residual is narrowed correctly. M-LP-20 is red and `acceptsNode` alone does not cover it, so the gate is not redundant. The dimension grips call `attachCandidates`, so they inherit the gate.
- **Opening tool host.** `isUsableHost` is a top-level function: its tear-off is canonical and allocates nothing. `accept` is called only for a wall whose band contains the point. Hover, self-snap and click all go through `_hostAt`, so the preview and the commit agree. The memo key `tables.mutationRevision` is cheap. In the running app the change stream delivers in a microtask between pointer events, so the key matters mainly for a **direct table write**, which emits no `DocChange` but does bump the revision (D6 names that path), and for a same-task edit as in the test. Worth keeping.
- **Grips.** `opening_grips` slides an opening along `p.host` only and never re-chooses the host, so a grip cannot move an existing opening onto another wall, hidden or locked. Sliding an opening along a host that has since been hidden is decision 8 ("still cut by its openings"). S-11 names the tool's choice of host, so this is out of scope and not a defect.
- **Other creation paths (decision 9).** I grepped `apps/floor_planner/lib` for `AddNodeCommand`/`AddEntityCommand`/`InstanceNode(`. The only hits are the six tools, the placer, `build_library` (library definitions, layer 0 by the library's rule) and `startup_plan` (the sample, layer 0 explicitly per D7/R-13). The app has no paste, duplicate or import-merge path. Opening a file loads what is stored. Nothing is missing.

## Rulings

- **R-12b-9 — confirmed.** Skipping a wall that may not host, so that the next band in handle order hosts, is the reading that fits S-11's rationale ("a door cannot be placed on a wall the user cannot see or select"). Refusing at the lowest-handle wall would let an invisible wall block a visible one. A locked wall at a corner is visible, but the preview shows the host actually chosen, so the user is not misled. Leaving the Wall tool's `joinInto` unfiltered stays inside the spec's bounds, since S-11 names only the opening tool. See note 3.
- **Point 2 (memo key)** — confirmed, with the nuance above: its real value is the direct-table-write path.
- **Point 3 (a missing record counts as visible and unlocked)** — confirmed: this is how `FilterEvaluator` counts it, and `objectLayer` already falls back to layer 0, so only a document with no layer 0 reaches it.
- **Point 4 (fixture layers for the room and the dimension)** — confirmed. P-6 is silent on them. Using B (locked) as the current layer in the tools test is the stronger choice: the expected layer is neither 0 nor A, and D3 keeps a locked current layer usable.
- **Point 5 (wall_bands.dart not in the plan's file list)** — accepted. It is the natural place for the filter.

## Findings

1. **Minor (test gap).** `attach_layer_test` does not tell `objectLayer(doc, host)` apart from the stored component. My mutant **R2** (`_layerVisible(doc, doc.components.get<ObjectLayer>(host)?.layer ?? layerZero)`) survives with `00:00 +2: All tests passed!`. The two differ only when a wall's component names a missing layer *and* layer 0 is hidden, which only a file can produce, so there is no product impact. **Fix (Task 9's first commit, "8b"):** one more case in `attach_layer_test`: wall S with `ObjectLayer(Handle(0x7A7A))` (a dangling handle) and layer 0 hidden, so `attachCandidates` is empty at S/0's points. This mirrors the existing `isUsableHost` case in `opening_host_layer_test`.
2. **Minor (test gap, decision 8).** No app test pins that the Wall tool's band join stays unfiltered. My mutant **R3** (`joinInto` filters by a visible object layer) survives over `test/layers` + `test/wall_tool_test.dart`: `00:08 +38: All tests passed!`. **Fix (8b):** if the human keeps R-12b-9's second half (see 3), add one test: a wall on hidden C, and a Wall tool click in its band joins its end (the new wall's start equals C's wall end bitwise).
3. **Info (look list / results note).** On the Wall tool's join: a click inside the band of a wall on a hidden layer snaps the new wall's end to that invisible wall. That is as selection-like as S-11's case, but decision 8 ("still joins") and S-11's wording leave it unfiltered. Record it as an open question for the human, not a code change in this plan.
4. **Info.** If a wall's ObjectLayer is moved in the same synchronous task as a re-hover of the same point, the memo can serve a stale host: the move bumps neither the table revision nor the band generation until the stream delivers. A click always invalidates, and in the app the stream delivers between events. No action.

## Gates (re-run at 27db262, CI=true, PATH=/root/flutter/bin)

- engine: `00:17 +1225 -2: Some tests failed.`. The two failures are the standing ones in `test/testing/generate_document_test.dart` (`the default document is the one Plan 2 measured, byte for byte`, `both text fractions default to zero and change nothing`). `No issues found!`; `Formatted 168 files (0 changed) in 0.56 seconds.`
- render: `01:04 +1187 ~1 -7: Some tests failed.` (the 7 standing text-ladder failures); `No issues found! (ran in 1.5s)`; `Formatted 208 files (0 changed) in 0.66 seconds.`
- app: `03:13 +951: All tests passed!`; `No issues found! (ran in 2.0s)`; `Formatted 169 files (0 changed) in 0.81 seconds.`
- dev_harness_2d: `No issues found! (ran in 1.3s)`.
- `git status --short` empty afterwards (no analysis_options rewrite left).

## Mutants (scratchpad/r8-12b/mut.sh; one edit, the named test file in the foreground, cp back, `diff=0` for each)

| id | mutation | test | real output |
|---|---|---|---|
| M-LP-16 room | room_tool.dart:209 `ObjectLayer(drawingLayer(doc))` -> `ObjectLayer(ReservedHandles.layerZero)` | tools_layer | `00:00 +8 -1: Some tests failed.` `Expected: <19> Actual: <1>`, in "the Room tool creates its room, its tint and its labels on the current layer" |
| M-LP-16 separator | separator_tool.dart:103 same | tools_layer | `00:00 +8 -1: Some tests failed.` `Expected: <19> Actual: <1>`, in "the Separator tool creates its separator on the current layer" |
| M-LP-16 dimension | dimension_tool.dart:308 same | tools_layer | `00:00 +8 -1: Some tests failed.` `Expected: <19> Actual: <1>`, in "the Dimension tool creates its dimension…" |
| M-LP-16 symbol | symbol_placer.dart:130 `layer: drawingLayer(doc)` -> `layer: ReservedHandles.layerZero` | tools_layer | `00:00 +8 -1: Some tests failed.` `Expected: <19> Actual: <1>`, in "the symbol placer puts the instance on the current layer…" |
| M-LP-20 | dimension_attach.dart:142-143 drop `&& _layerVisible(...)` | attach_layer | `00:00 +0 -2: Some tests failed.` `Expected: empty Actual: [AttachedEnd:19/0/left]` |
| M-LP-25 | opening_tool.dart:286 `accept: isUsableHost` dropped | opening_host_layer | `00:00 +2 -4: Some tests failed.` `Expected: null Actual: <29>` |
| R1 (own) | opening_tool.dart:449 `isUsableHost` ignores visibility (lock only) | opening_host_layer | `00:00 +3 -3: Some tests failed.` `Expected: null Actual: <29>` |
| R5 (own) | dimension_attach.dart:142 `&&` -> `\|\|` | attach_layer | `00:00 +0 -2: Some tests failed.` `Expected: empty Actual: [AttachedEnd:19/0/left]` |
| R2 (own) | dimension_attach.dart:143 stored component instead of `objectLayer` | attach_layer | **survives** `00:00 +2: All tests passed!` (finding 1) |
| R3 (own) | wall_bands.dart:98 `joinInto` filters by a visible object layer | test/layers + wall_tool_test | **survives** `00:08 +38: All tests passed!` (finding 2) |

## Non-degeneracy

The fixture uses layers A (ACI 1), B (ACI 5, locked) and C (ACI 3, hidden; not layer 0). Every wall sits in its own group, rotated 23° at the corpus far origin; the premise test asserts that no wall's transform is the identity. Clicks are at fractional plan coordinates away from the origin. The current layer in the tools test is B, so the mutant targets (layer 0, and the walls' A) are distinct from the expected value, and the hidden-stored-current test separates `drawingLayer` from `header.currentLayer`. The attach test keeps the door on a visible-but-locked layer, which separates "hidden" from "locked". It also asserts the premises: the door is drawn near the point, the wall is not drawn, and the brute oracle still has the point. Each new test is killed by a named mutant, except for the two gaps above.
