# Task 2 review — render layer: `Tool.isMidShape` (plan 12a, spec D6, U-1)

Reviewer: independent, detached worktree `.claude/worktrees/plan-12a-review`
at `1fce8b7` (parent `f8e296d`, Task 1, reviewed separately).

## Verdict: **Approved**

The code matches the plan's Task 2 and spec D6 / U-1. Nothing was found that
needs fixing before merge. There are two minor findings; neither blocks.

## Scope and conformance

- `git diff f8e296d HEAD --stat`: 4 files, +274, 0 deletions. They are
  `tool.dart`, `draw/placement_tool.dart`, `draw/text_tool.dart` and the new
  `test/draw/mid_shape_test.dart`. No engine file, app file or
  `analysis_options.yaml` changed. The only `isMidShape` definitions in `lib/`
  are the three the plan names.
- **`tool.dart:91`**: `bool get isMidShape => false;` on `Tool`. The dartdoc
  carries the plan's wording ("part-way through a shape; the shell disables
  its commands") and adds the notify contract.
- **`placement_tool.dart:76`**: `isMidShape => isPending`. This matches spec
  D6: `points` not empty.
- **`text_tool.dart:43`**: `isMidShape => false`. Its comment says the open
  entry is committed by the shell's flows (spec 12a D2), as the plan asks and
  as U-1 requires. `isPending` is unchanged at `text_tool.dart:37`.
- **Notifications: "verify, do not add" was honoured.** No `notifyListeners`
  was added. I read every path that changes `points` in the five render tools:
  - Each `accept` runs under `onPointerDown`, which notifies at `:163`.
  - `LineTool.finish` / Polyline's commit runs under Enter, which notifies at `:195`.
  - Escape and `activate` go through `cancel`, which notifies at `:229`.
  - `ToolController.activate` notifies once for the swap (`tool.dart:129`).
  - `_reresolve` (`:261`) does not change `points`.
- The app's `RoomTool` and `OpeningTool` inherit `isPending`, and neither adds
  to `points`. So they read false by construction, as D6 says for Door, Window,
  Gap and Room. `BoxTool extends RectangleTool`. I checked this by reading only;
  Task 6 pins it with tests. It is consistent with the spec.

## Tests (non-degeneracy)

- 34 tests; my baseline run was `+34: All tests passed!`.
- Every test runs with `flipY` true and false.
- The scene is off the origin (page anchored at 7000, 3000). Clicks land at
  off-lattice, non-collinear world points. Escape is checked against a
  byte-exact `snapshot`. Each finish is checked as a real commit
  (`undoDepth` grows).
- Every mid-shape value is read twice: on the tool, and through a listener on
  the `ToolController`. The listener reads the value the shell will read.
  This is what lets the notification mutants go red.
- MS5 asserts that the Select fixture really reaches every `ToolPhase`. It also
  asserts a real move commit (`undoDepth == 1`).
- The fixture's root is the identity transform. That is irrelevant here:
  `isMidShape` does not depend on any transform.

## Mutants

Procedure: `cp` a backup to `scratchpad/p12r2-<name>-<file>`, apply the
mutation with a python replace that asserts it applied, run
`CI=true flutter test test/draw/mid_shape_test.dart`, `cp` back, `diff`.
Every restore diff exited 0. Afterwards `git status` shows only the known
`packages/jet_cad/analysis_options.yaml` rewrite.

### The implementer's mutants, re-fired (all reproduce the report exactly)

| # | Mutation | Result | Red : line (count) |
|---|---|---|---|
| **MT (plan)** | `text_tool.dart:43` `=> isPending` | +32 -2 | MS4 ×2 : `mid_shape_test.dart:177` |
| MX | delete TextTool's override (`:39-44`) | +32 -2 | MS4 ×2 : `:177` |
| MP1 | `placement_tool.dart:76` `=> false` | +4 -30 | `:82` (10), `:116` (6), `:123` (4), `:153` (10) |
| MP2 | `:76` `=> points.length > 1` | +4 -30 | same as MP1 |
| MB | `tool.dart:91` `=> true` | +22 -12 | MS3 `:157` (10), MS5 `:224` (2) |
| MNd | delete `placement_tool.dart:163` notify (`onPointerDown`) | +14 -20 | `:85` (10), `:117` (6), `:124` (4) |
| MNe | delete `:195` notify (Enter) | +30 -4 | MS2 Line/Polyline `:135` (4) |
| MNc | delete `:229` notify (`cancel`) | +24 -10 | MS1 `:95` (10) |

### My own mutants, at seams the task's list misses

| # | Mutation | Result | Red : line |
|---|---|---|---|
| R1 | `tool.dart:129` delete `activate`'s `notifyListeners()` | +24 -10 | MS3 `:158` (10) |
| R2 | `activate`: unhook the listener *after* `cancel`, so the outgoing tool's cancel notification is forwarded (two notifications) | +24 -10 | MS3 `:158` (10) |
| R3 | `text_tool.dart:43` `=> isPending && controller.text.isNotEmpty` | **+34, survives** | none (see m-1) |
| R4 | `SelectTool` adds `isMidShape => phase != ToolPhase.idle` | +32 -2 | MS5 `:209`, `:229` |
| R5 | `placement_tool.dart:224` delete `cancel`'s `clearShape()` | +12 -22 | MS1 `:93` (10), MS3 `:156` (10), MS4 `:186` (2) |
| R6 | `onPointerDown`'s notify moved *before* `accept`, so it fires with the old value | +14 -20 | `:85` (10), `:117` (6), `:124` (4) |
| R7 | Enter's notify moved *before* `finish` | +30 -4 | MS2 `:135` (4) |

## Findings

### Important

None.

### Minor

**m-1. The typed-entry state is never read (R3 survives).**
- MS4 reads `isMidShape` with the entry open and empty (`:177-178`), then sets
  `controller.text = 'Kitchen'` (`:180`), then presses Enter. It never reads
  `isMidShape` in between.
- That in-between state (entry open, text typed, not committed) is exactly
  what U-1 and Task 7's settle are about. An override that turns true once text
  is typed passes all 34 tests. That is R3: +34.
- **Probe.** In the review worktree, restored afterwards (both diffs exit 0), I
  inserted two lines after `:180`:
  ```dart
  expect(tool.isMidShape, isFalse, reason: 'typed, not yet committed');
  expect(rig.tools.active.isMidShape, isFalse);
  ```
  The result is +34 on the unmutated code, and R3 goes red at `:181` (×2).
- **Mitigation already planned.** Task 7's app-level M-12a-28 test types text
  before the toolbar Save, so R3 would most likely also go red there.
- **Recommendation.** Optional: add these two lines when a later task next
  touches this file (for example Task 9's sweep). No fix is needed for this
  approval.

**m-2. The spec's line citation has moved; the implementer's claim is confirmed.**
- At `f8e296d`, `placement_tool.dart:199-204` is the F-2 tail and the
  mid-shape swallow (`return KeyEventResult.handled` at `:204`).
- At `1fce8b7` the same block is `:206-211` (+7).
- The spec cites `:199-204` in D6 (line 365) and in the limits (line 632).
  This is for Task 9's amendments, as the ledger already notes.

### Report accuracy

I checked each of the report's claims myself:
- The API, the test count, the eight mutants with their counts and lines, the
  gate numbers, the file-path deviation (`test/draw/`), and the citation
  shift all hold.
- MNc's first aim at `:261` (`_reresolve`) surviving is correct: that path
  never changes `points`.

## Gates (run in the review worktree at `1fce8b7`, `CI=true`, `PATH=/root/flutter/bin:$PATH`)

| Package | test | analyze | format |
|---|---|---|---|
| Engine `packages/jet_cad_2d` | `+1105 -2`, exit 1. Both failures are the standing `test/testing/generate_document_test.dart` ones (byte-for-byte default document; text fractions). | No issues found, exit 0 | 159 files, 0 changed, exit 0 |
| Render `packages/jet_cad_2d_flutter` | `+974 ~1 -7`, exit 1. The 7 are the standing ones: `text_ladder` rungs 1–5 and `text_lod_ladder` rungs 1–2. That is 940 + 34 new. | No issues found, exit 0 | 178 files, 0 changed, exit 0 |
| App `apps/floor_planner` | `+514: All tests passed!`, exit 0 | No issues found, exit 0 | 104 files, 0 changed, exit 0 |

The counts match the plan's branch point plus Task 1's 10 engine tests
(1,095 + 10) and Task 2's 34 render tests. The app is unchanged at 514.
