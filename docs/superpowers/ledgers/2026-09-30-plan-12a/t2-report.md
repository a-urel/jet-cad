# Task 2 report — render layer: `Tool.isMidShape` (plan 12a, spec D6, U-1)

## Commit

`1fce8b7` `feat(render): Tool.isMidShape` on `plan-12a/document-lifecycle`
(parent `f8e296d`, Task 1). Not pushed. It ends with the two trailers
(Co-Authored-By, Claude-Session). It touches 4 files, +274: three `lib` files and one
new test. No engine or app file changed, and no `analysis_options.yaml`.

## API as landed

- `packages/jet_cad_2d_flutter/lib/src/tool.dart:88-91`, on `abstract class Tool`:
  ```dart
  /// True while the tool is part-way through a shape; the shell disables
  /// its commands (spec 12a D6). False by default. A tool that changes it
  /// notifies, so a listener on [ToolController] sees every change.
  bool get isMidShape => false;
  ```
- `lib/src/draw/placement_tool.dart:72-76`: `@override bool get isMidShape => isPending;`
  The dartdoc says the base class's paths that change `points`
  (`onPointerDown`, Enter and Escape in `onKey`, `cancel`) each notify.
- `lib/src/draw/text_tool.dart:39-43`: `@override bool get isMidShape => false;`
  The comment says the Text tool's pending state is the open entry, and the shell's
  flows commit it (spec 12a D2) rather than wait on it.
- **Notifications: checked, none added.** The mutants MNd, MNe and MNc below
  remove the `notifyListeners()` calls in `onPointerDown`, Enter and `cancel`, and
  each one turns a test red. `ToolController.activate`'s own notification is
  covered by MS3.

## Tests

New file: `packages/jet_cad_2d_flutter/test/draw/mid_shape_test.dart`, 34 tests.
- Every test runs for `flipY` true and false.
- The fixture is `drawScene()`: a 1:20 page anchored at (7000, 3000), and an anchor
  line off every lattice.
- Clicks land at off-origin, off-lattice, non-collinear world points
  (7020.5, 3030.25), (7090.75, 3075.5) and (7040.125, 3110.375).
- `_record` adds a listener to the `ToolController` and logs
  `tools.active.isMidShape` at each notification. That is the value a shell
  listening to the controller would read.

| Test | Tools | What it pins |
|---|---|---|
| MS1 (×5 tools ×2) | Line, Polyline, Rectangle, Circle, Arc | <ul><li>Not mid-shape when fresh, on the tool and through `tools.active`.</li><li>After the first click: exactly one point placed, mid-shape, and the controller's last notification read `true`.</li><li>Escape returns `handled`, the tool is no longer mid-shape, a new notification fired and read `false`.</li><li>The document is byte-identical afterwards (`snapshot`).</li></ul> |
| MS2 (×5 ×2) | same | <ul><li>Mid-shape after every intermediate click, and the last notification read `true`.</li><li>Rectangle and Circle finish on the 2nd click, Arc on the 3rd. Line (it chains) and Polyline stay mid-shape after 2 clicks and finish on Enter.</li><li>At the end, `undoDepth` grew (the shape was committed, not cancelled), the tool is not mid-shape, and the last notification read `false`.</li></ul> |
| MS3 (×5 ×2) | same | <ul><li>Mid-shape after one click.</li><li>`tools.activate(SelectTool())`: the outgoing tool is no longer mid-shape, the active tool is not mid-shape, and exactly one new notification fired, reading `false`.</li></ul> |
| MS4 (×2) | Text | <ul><li>A click opens the entry: `pending.value != null` and `isPending` is true, but `isMidShape` is false on the tool and through the controller (U-1).</li><li>Enter with "Kitchen" commits (`undoDepth +1`) and it stays false.</li><li>Every notification read `false`.</li></ul> |
| MS5 (×2) | Select | <ul><li>Never mid-shape through a press on the anchor line, a move-drag that commits (`undoDepth == 1`), a release, a band drag from empty page, and Escape during the band.</li><li>The fixture asserts it reached every `ToolPhase` (idle, pressed, dragging).</li><li>Every notification read `false`. This also pins the base default.</li></ul> |

## Mutants

Procedure: `cp` a backup to `…/scratchpad/p12t2-<file>`, `sed`, run
`CI=true flutter test test/draw/mid_shape_test.dart`, `cp` back, then `diff`.
- Every restore diff exited 0.
- Before the final run I confirmed the backups matched the files.
- The line numbers below come from the final, committed test file.

| # | Mutation | Result | Red tests : line |
|---|---|---|---|
| **MT (the plan's)** | `text_tool.dart:43` `isMidShape => isPending` | +32 -2 | MS4 Text ×2 : `mid_shape_test.dart:177` |
| MX | delete TextTool's override (`text_tool.dart:39-44`), so it inherits `isPending` | +32 -2 | MS4 Text ×2 : `:177` |
| MP1 | `placement_tool.dart:76` `=> false` | +4 -30 | MS1, MS2, MS3 for all 5 tools ×2 : `:82`, `:116`, `:123`, `:153` |
| MP2 | `placement_tool.dart:76` `=> points.length > 1` | +4 -30 | same : `:82`, `:116`, `:123`, `:153` |
| MB | `tool.dart:91` base default `=> true` | +22 -12 | MS3 ×10 : `:157`, MS5 Select ×2 : `:224` |
| MNd | `placement_tool.dart:163` (`onPointerDown`'s `notifyListeners()`) removed | +14 -20 | MS1 ×10 : `:85`, MS2 ×10 : `:117`, `:124` |
| MNe | `placement_tool.dart:195` (Enter's `notifyListeners()`) removed | +30 -4 | MS2 Line, Polyline ×2 : `:135` |
| MNc | `placement_tool.dart:229` (`cancel`'s `notifyListeners()`) removed | +24 -10 | MS1 ×10 : `:95` |

**The first notification mutant was aimed at the wrong line.** It removed line 261, which is
`_reresolve`'s notify (hover and camera re-resolve), not `cancel`'s. It
survived (+34), which is correct: that path never changes `points` or the
mid-shape value. I re-aimed it at `cancel` (line 229) as MNc.

## Gates

`export PATH=/root/flutter/bin:$PATH`, with `CI=true` on every command.

| Package | test | analyze | format |
|---|---|---|---|
| Engine (`packages/jet_cad_2d`) | `+1105 -2`, exit 1. The two failures are the standing `test/testing/generate_document_test.dart` ones, unchanged from Task 1. | "No issues found!", exit 0 | 159 files, 0 changed, exit 0 |
| Render (`packages/jet_cad_2d_flutter`) | `+974 ~1 -7`, exit 1. That is 940 + 34 new, 1 skip, and the 7 standing failures (`text_ladder` rungs 1–5, `text_lod_ladder` rungs 1–2), nothing else. | "No issues found!", exit 0 | 178 files, 0 changed, exit 0 |
| App (`apps/floor_planner`) | `+514: All tests passed!`, exit 0 | "No issues found!", exit 0 | 104 files, 0 changed, exit 0 |

- The first render analyze found 2 issues in my new test: an unused
  `jet_cad_2d` import, and an optional parameter that was never passed. I fixed both.
- After the fix I re-ran the render gate in full and re-fired all eight mutants.
- The engine gate ran before that test-only fix. Nothing outside the render test
  file changed after it.

## Deviations

- The plan's "Files" row names `test/…/mid_shape_test.dart`. It landed at
  `test/draw/mid_shape_test.dart`.
- There are more tests than the checklist asks for: MS2 (the shape finished by
  its last click or Enter) and MS3 (switching tools), plus notification
  assertions. I added them to turn the "verify, do not add" check on
  notifications into mutant-backed tests.
- No production deviation.

## Found outside scope (reported, not fixed)

- The spec cites `placement_tool.dart:199-204` for the mid-shape key swallow, at
  lines 365 and 632. The 7 lines inserted above it moved that block to `:206-211`.
  - `placement_tool.dart:70` (`isPending`) and `text_tool.dart:37` are unchanged.
  - Task 9's spec amendments may want to update the citation.
- The app's Wall, Separator, Dimension and Box mid-shape checks belong to
  Task 6. They inherit `isPending` from `PlacementTool` unless they override
  it, which I did not check here.
