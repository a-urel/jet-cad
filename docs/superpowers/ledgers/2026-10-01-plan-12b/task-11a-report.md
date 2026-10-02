# Task 11a report — 10b, end to end, sweep, results note, status

Implementer. Started at HEAD 5ef5673. Scratch: scratchpad/l11/.

(Appended as work proceeds.)

## 1. 10b — commit c3ab7ca `test(app): Task 10 review follow-ups`

Files: apps/floor_planner/lib/layers/{layer_panel,layer_picker}.dart,
lib/parametric/catalog.dart, test/layers/{layer_panel,layer_picker}_test.dart.

- Finding 1: new test "every registered parametric type ... alone": layerFixture() (room on A,
  dimension on B) plus a box on a new visible layer D (rotated, translated group) and a separator
  on layer 0 (rotated group); each alone -> enabled, not the plain-group tooltip, label D/A/B/0/A/B;
  then the separator is moved 0 -> D (its children follow). Comments on `parametricCatalog` and on
  `isParametricObject` name each other.
- Finding 2: custom sets {transform, geometry, structure; no components} -> disabled with
  kLayerPickerReadOnly; {components only} -> enabled, one choice moves a line and a wall (children
  stamped) in one undo step.
- Finding 3: a wall whose ObjectLayer names a non-layer handle (shown on 0, children on 0) ->
  layerMoveCommand(..., 0) is a SetComponentCommand<ObjectLayer> and the picker writes
  ObjectLayer(0) (depth 1); a wall with its ObjectLayer detached -> null, and the picker dispatches
  nothing.
- Info 5: `_choose` wraps execute in `on ArgumentError` / `on StateError` (the Selection section's
  own pattern, e.g. `_setKind`, `_setJustification`). Test: a room broken as only a file can be
  (system disposed, a second fill owned by the room naming a root region's boundary, system
  reinstalled); premise: the move throws StateError (`_ownBoundaryOf` on the surplus fill); through
  the picker: no exception, depth 0, bytes equal.
- Info 6: `kLayersLocked = 'Layers cannot be changed in this document'` for the disabled delete;
  the 9b test asserts the literal.
- Info 7: `fieldsOf` / `recordReason` in layer_panel_test; the 7 full-record expects carry it.
  Seen on O1: `record {handle 13, name "Kitchen", IndexedColor(5), linetype 4, lineweight -3, transparency 0, ...`

App gate at c3ab7ca: `03:32 +990: All tests passed!` (986 + 4), `No issues found! (ran in 1.6s)`,
`Formatted 174 files (0 changed) in 0.82 seconds.`

### 10b mutants (scratchpad/l11/mut.sh; each diff=0 after restore)

| id | mutation | red test | real output |
|---|---|---|---|
| R-own-5 | layer_picker.dart:37-38 Separator, Room -> `false` | every registered type (and the refused-move test) | `Expected: true` `Actual: <false>` `00:05 +19 -2: Some tests failed.` |
| R-own-2 | :83 `Capability.components` -> `transform` | components not transform | `Expected: false` `Actual: <true>` `00:04 +12 -1: Some tests failed.` |
| R-own-3 | :150 skip via `objectLayer(doc, o)` | stored ObjectLayer no-op rule | `Expected: <Instance of 'SetComponentCommand<ObjectLayer>'>` `Actual: <null>` `00:03 +12 -1` |
| M10b-catch | :194 `on StateError` -> `on ArgumentError` (StateError not caught) | refused move caught | `00:04 +12 -1: a move the document refuses ... [E]` |
| M10b-tip | layer_panel.dart:17 kLayersLocked -> 'Read-only document' | read-only (M-12a) | `Expected: 'Layers cannot be changed in this document'` `Actual: 'Read-only document'` |
| O1 (re-fired for info 7) | :272 rename also flips locked | Enter on B; blur+lock | `record {handle 13, name "Kitchen", IndexedColor(5), ...` `00:08 +22 -2: Some tests failed.` |

## 2. End to end — commit 1f2788a `test(app): layers end to end`

File: apps/floor_planner/test/layers/layers_end_to_end_test.dart (new, 1 test).

`FloorPlannerApp` via `pumpApp` (document_rig) over `FakeDocumentFiles`; camera rotated 0.3 rad at
0.1 px/mm, centred on (8400.5, 5300.25). Steps: a line on layer 0 (the "keep" line); `layers-add`
-> `Layer 1`, renamed `Furniture` in its open field, recoloured ACI 3 by the swatch menu; made
current by `layer-current-<hex>`; a line (palette Line tool, two clicks, Escape x2) and a wall
(palette Wall tool, two clicks, Enter, Escape) -> the line on L, the wall's ObjectLayer L and every
generated child on L. Frame probe: `DraftCanvasState.painter.debugOnVisit` (Task 7's probe) on the
app's live canvas (`tiles: false` in PlannerView). Premise: L's eye is disabled while L is current
(decision 7), so layer 0 is made current, then L hidden: the repainted frame contains the keep
line and neither the line nor any wall child; shown: all back. The wall selected by a click on its
middle, the picker shows `Furniture`, item 0 chosen: one undo step, ObjectLayer 0, children on 0,
the line stays on L. L made current again (so the file's current layer is not 0). Save (asks),
Open the written bytes, the current layer L, every layer (name, colour, visible, locked) kept, the
panel shows L current; Save in place: `files.writes[1].bytes == first`.

Note vs the plan's wording: "make it current, draw, hide the layer" cannot be done literally (the
current layer cannot be hidden, decision 7); the test makes layer 0 current before the hide and
asserts the disabled eye as a premise.

Gates at 1f2788a (CI=true, PATH=/root/flutter/bin):
- Engine: `00:18 +1225 -2: Some tests failed.` — the 2 standing: `test/testing/generate_document_test.dart: the default document is the one Plan 2 measured, byte for byte [E]`, `...: both text fractions default to zero and change nothing [E]`. `No issues found!`, `Formatted 168 files (0 changed) in 0.60 seconds.`
- Render: `01:00 +1187 ~1 -7: Some tests failed.` — the 7 standing: text ladder rungs 1-5, text lod ladder rungs 1-2 (canvas). `No issues found! (ran in 1.6s)`, `Formatted 208 files (0 changed) in 0.65 seconds.`
- App: `03:40 +991: All tests passed!`, `No issues found! (ran in 1.8s)`, `Formatted 175 files (0 changed) in 0.91 seconds.`
- dev_harness_2d: `No issues found! (ran in 1.1s)`.

### E2E mutants (scratchpad/l11/mutp.sh, the e2e file only; each diff=0)

| id | mutation | real output |
|---|---|---|
| E2E/M-LP-12 | engine json_codec.dart:176 `..currentLayer = header.currentLayer` dropped | `Expected: <19>` `Actual: <1>` `00:04 +0 -1: E2E ... [E]` |
| E2E/M-LP-16 (drafting) | render line_tool.dart:46 `drawingLayer(ctx.document)` -> `layerZero` | `Expected: <19>` `Actual: <1>` `00:03 +0 -1` |
| E2E/M-LP-16 (parametric) | app wall_tool.dart:231 `ObjectLayer(drawingLayer(doc))` -> `ObjectLayer(layerZero)` | `Expected: <19>` `Actual: <1>` `00:04 +0 -1` |
| E2E/M-LP-1 | engine spatial_index.dart:247 `_filters.invalidate()` dropped from `_beginQuery` | `Expected: not contains <20>` `Actual: Set:[18, 20, 22, 23, 24]` `00:04 +0 -1` |
| E2E-picker | layer_picker.dart:186 `_choose` never executes | `Expected: <11>` `Actual: <10>` (one undo step) `00:04 +0 -1` |

## 3. Sweep (report only, at 1f2788a)

- `git diff 7330c7b -- packages/jet_cad_2d/test/invariants/query_allocation_test.dart packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart | wc -c` -> `0` (unedited); both green in the engine and render runs above.
- `git diff --stat 7330c7b | grep analysis_options` -> empty (exit 1).
- `git diff --stat 7330c7b -- '*.png'` -> empty: no golden PNG changed.
- Non-.dart/.md changes vs 7330c7b: only `apps/floor_planner/assets/library/furniture.jetlib | 2 +-` (R-12b-2, expected). `94 files changed, 9735 insertions(+), 191 deletions(-)` at this point.
- Golden tag: render at exactly the 7 standing failures (text_ladder 1-5, text_lod_ladder 1-2), as at the branch point.
- `git status --short` empty after every mutant.

Web at 1f2788a: `Compiling lib/main.dart for the Web... 54.6s`, `✓ Built build/web`.
Golden tag at 1f2788a: `flutter test --tags golden` -> `00:33 +28 -7: Some tests failed.` (text ladder rungs 1-5, text lod ladder rungs 1-2, the 7 standing; no other).
Fingerprint constants unchanged at generate_document_test.dart:66, :68, :251, :253 (line numbers checked on the branch).

## 4. Docs — commit 35af9b9 `docs: plan 12b results`

- docs/superpowers/notes/2026-10-01-plan-12b-results.md (new; plan 13's form): delivered, the task/commit/review
  table, what execution found (R-12b-1..9 and the review-driven changes), gates of record at 1f2788a (this commit
  is docs only), the mutant table (28 named incl. M-12a, M-12e; notable own mutants with every first-survivor and
  its fix; M-12e's product form and the add-only bypass killed by tables_revision_test; M3b-4 cost-only),
  found-not-fixed (all the brief's items), risks, and the human's look list (macOS fingerprint step first; the
  Wall tool's hidden-join open question last). The final whole-branch review is marked owed in the note.
- The spec: "Amended at execution (Plan 12b)" (21 bullets).
- roadmap/12-app-shell.md: 12b status paragraph ("executed on plan-12b/layer-panel ... awaiting the human's look
  and merge"); the layer panel and the dimensions layer removed from "still open"; the "A layer for dimensions"
  question closed as decision 9. roadmap/00-README.md: the 12 row and the summary line name 12b likewise.

Gates at the tip 35af9b9: the code is that of 1f2788a (docs-only commit); gates as recorded in section 2 + web
and golden tag above. `git status --short` empty.

## Spec / plan points (for the controller)

1. Plan Task 11's e2e order ("make it current ... hide the layer") is impossible literally (decision 7): the test
   makes layer 0 current first and asserts the disabled eye as a premise.
2. Task 10 review info 5 said "the guard the panel's other commits use": LayerPanel itself has no catch; the
   pattern is SelectionPanel's (`_setKind`, `_setJustification`, `_flip`). Matched that. A cheap test exists:
   a room broken behind the parametric system's back (a second fill naming a root boundary) makes the move throw
   StateError from `_ownBoundaryOf`.
3. The results note leaves the final whole-branch review's verdict and sample as owed (that review runs after this
   task), and the ledger archive is not done here (plan: after the final review).
