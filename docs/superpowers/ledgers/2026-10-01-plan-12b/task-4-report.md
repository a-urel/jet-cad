# Task 4 report (with 3b)

Implementer: Task 4 agent. HEAD at start: af87621. Scratch: .../scratchpad/l4/ (`mut.py`: cp backup, one
exact-string mutation asserted unique, run the named test file in the foreground, cp back, print `diff` exit).

## 3b — commit `540f9cf` `fix(engine): Task 3 review follow-ups`

Files: `packages/jet_cad_2d/lib/src/index/spatial_index.dart` (the `_reconcile` skip),
`packages/jet_cad_2d/test/index/layer_filter_test.dart` (+7 tests, two local helpers `_layerAt`, `_add`/`_addLine`).

1. **Finding 1.** The skip now reads `layers[h] != null && !entities.containsHandle(h) && _lastKnownSlot[h] == null
   && tree[h] == null && tree.definition(h) == null` (real API names on the branch). The reviewer's regression test
   (a layer record at `lineA`'s handle; `SetEntityGeometryCommand` moves lineA; the index follows) landed. **But it
   alone cannot catch "drop the containsHandle check"**: an edited entity is also in `_lastKnownSlot` (every live
   slot is recorded on rebuild), so that conjunct still guards an edit. The containsHandle conjunct is the only one
   guarding an entity *add* at a layer's handle, so I added one test per conjunct: edit, add, removal (only
   `_lastKnownSlot` guards it), and an instance add (only `tree[h]` guards it).
2. **Finding 2.** A layer-0 ATTRIB ('LEG') owned by `f.nested`, at nested-local (-50, 35). With layer 0 hidden it is
   still picked (chain length 1, the root instance: it is a leaf of Table's container), and a crossing band with the
   *rendering* filter selects the instance on A; locking A unpicks it. Note: a 2-unit band inside the glyph box does
   not cross a text leaf (crossing tests the box edge); the band is ±3 around the probe, crossing the box's left edge.
3. **Finding 3. The review's suggested test cannot catch O2.** The test landed as written (D line in Leg, lock A,
   pick null), and it passes, but **O2 survived it**. The reason: locking A prunes the *root* instance on A before
   the nested one is reached. In general a locked context means a locked ancestor, which is already pruned by the
   same check. O2 is only visible in the converse case: **layer 0 locked, A unlocked**. Then a nested instance tested
   by its stored layer 0 is wrongly pruned. I added that test: make A current, lock layer 0, and the D line, the leg
   line and the table line inside the instance on A all stay pickable, while the root line on 0 is not. O2 goes red
   on it. The reviewer's literal test is given its own mutant (O2b: drop the instance lock check).

### Gates after 3b (CI=true, real tails)
- engine `dart test`: `00:19 +1211 -2: Some tests failed.` The 2 are the standing `generate_document_test.dart`
  ones (`both text fractions default to zero and change nothing`, `the default document is the one Plan 2
  measured, byte for byte`). 1204 + 7 new. `dart analyze`: `No issues found!`. Format:
  `Formatted 167 files (0 changed) in 0.57 seconds.`
- render `flutter test`: `01:02 +1154 ~1 -7: Some tests failed.` (7 standing text ladders). analyze
  `No issues found! (ran in 1.4s)`. Format `Formatted 200 files (0 changed) in 0.65 seconds.`
- app `flutter test`: `03:25 +934: All tests passed!`. analyze `No issues found! (ran in 1.8s)`. Format
  `Formatted 165 files (0 changed) in 0.79 seconds.`
- dev_harness_2d analyze: `No issues found! (ran in 1.2s)`

### 3b mutants (layer_filter_test.dart; every one `diff= 0`)
| id | file: mutation | result |
|---|---|---|
| M3b-0 | spatial_index.dart `_reconcile`: the guard back to `if (document.tables.layers[handle] != null) {` | RED `00:00 +5 -1: ... an entity that shares its handle with a layer record: an edit to it still reaches the index (Task 3 review, finding 1) [E]` (+ add, removal, instance; `00:01 +19 -4`) |
| M3b-1 | drop `!document.entities.containsHandle(handle) &&` | RED `00:00 +6 -1: ... an entity added at a layer record's handle is indexed (the containsHandle guard) [E]` |
| M3b-2 | drop `_lastKnownSlot[handle] == null &&` | RED `00:00 +7 -1: ... an entity removed at a layer record's handle leaves the index (the last-known-slot guard) [E]` |
| M3b-3 | drop `document.tree[handle] == null &&` | RED `00:00 +8 -1: ... an instance added at a layer record's handle is indexed (the node guard) [E]` |
| M3b-4 | drop `document.tree.definition(handle) == null` | SURVIVED `00:01 +23: All tests passed!`. Not pinned: an empty definition added at a layer's handle changes no answer by itself, and its first leaf or instance reaches the index through its own handle. Kept for the "purely a layer" rule the review stated. |
| O1 | query_filter.dart: `ownLayer != Handle.none && ownLayer != ReservedHandles.layerZero` -> `ownLayer != Handle.none` | RED `00:00 +18 -1: ... with layer 0 hidden, an ATTRIB on layer 0 owned by the nested instance on layer 0 follows the instance on A; locking A unpicks it (Task 3 review, finding 2) [E]` |
| O2 | query_filter.dart `acceptsNodeOnLayer`: `_lockedLayer(layer)) {` -> `_lockedLayer(resolved.layer)) {` | first SURVIVED `00:01 +23: All tests passed!` with the review's lock-A test; after the layer-0-locked test, RED `00:00 +20 -1: ... with layer 0 locked, the nested instance on layer 0 follows the unlocked A: its leaves on D and on layer 0 stay pickable (Task 3 review, finding 3; O2) [E]` |
| O2b | `acceptsNodeOnLayer`: `resolved is InstanceNode && _lockedLayer(layer)` -> `... && false` | RED `00:00 +19 -1: ... a line on an unlocked layer D inside Leg is unpickable once A is locked ... (Task 3 review, finding 3) [E]` |

## Task 4 — commit `4a735fb` `refactor(engine): drafting takes the layer explicitly`

`drafting.dart`: `draftRecord`, `addDrafted` and `addDraftedRegion` each take `required Handle layer` (named, no
default). The parameter replaces the hard-coded `ReservedHandles.layerZero` in the record and in
`AddRegionCommand.allocate`, and `addDrafted` passes it on to `draftRecord`. The doc comment on `draftRecord` says
"on [layer]" instead of "on layer 0". Nothing else in the file changed.

**How the callers were found and edited.** The compiler found them: `dart analyze --format=machine`
`MISSING_REQUIRED_ARGUMENT ... 'layer'`. There were 34 in the engine, 4 in render, 18 in the app and 0 in
dev_harness_2d (its analyze was clean before any edit to it, and `grep -rn "draftRecord\|addDrafted"
apps/dev_harness_2d` gives 0). A script (scratch `addlayer.py`) inserted `layer: ReservedHandles.layerZero` into
each call, then `dart format`. **No import was needed**: every file already resolves `ReservedHandles`.

**Proof that the hunks are mechanical** (scratch `check.py`). For each changed file except `drafting.dart`, I
stripped all whitespace from `HEAD` and from the working copy and diffed character by character. Every non-equal
opcode is an insert of exactly `,layer:ReservedHandles.layerZero` or `layer:ReservedHandles.layerZero,`. The script
printed `OK` for all 33 files and `total inserts 56`, which matches spec D7's "about 55 call lines". The reflowed
lines in the diff are formatter-only. `_recordOf` (regeneration.dart:445) is one of the 56, as P-8 asks ("for
now").

`git diff HEAD~1 --stat` (34 files, 133 insertions, 74 deletions):
```
apps/floor_planner/lib/startup_plan.dart           |  4 ++-
apps/floor_planner/test/dimension_object_test.dart |  3 +-
apps/floor_planner/test/dimension_tool_test.dart   |  3 +-
apps/floor_planner/test/opening_cost_test.dart     |  3 +-
apps/floor_planner/test/opening_tool_test.dart     |  7 ++--
apps/floor_planner/test/planner_draw_test.dart     |  3 +-
apps/floor_planner/test/room_cost_test.dart        |  3 +-
apps/floor_planner/test/room_grips_test.dart       |  3 +-
apps/floor_planner/test/room_panel_test.dart       |  3 +-
apps/floor_planner/test/room_tool_test.dart        |  3 +-
apps/floor_planner/test/selection_panel_test.dart  |  6 ++--
apps/floor_planner/test/separator_tool_test.dart   |  3 +-
.../test/symbols/symbol_place_tool_test.dart       |  3 +-
apps/floor_planner/test/wall_tool_test.dart        | 13 +++----
packages/jet_cad_2d/lib/src/document/drafting.dart | 18 ++++++----
.../lib/src/parametric/regeneration.dart           | 14 ++++----
.../jet_cad_2d/test/codec/json_codec_test.dart     |  3 +-
.../jet_cad_2d/test/document/drafting_test.dart    | 40 ++++++++++++++--------
.../jet_cad_2d/test/document/expander_test.dart    |  3 +-
.../test/document/layer_commands_test.dart         |  4 ++-
.../jet_cad_2d/test/parametric/cascade_test.dart   | 12 ++++---
.../jet_cad_2d/test/parametric/diagnose_test.dart  |  9 +++--
.../jet_cad_2d/test/parametric/guards_test.dart    |  9 +++--
.../test/parametric/live_object_rule_test.dart     |  3 +-
.../jet_cad_2d/test/parametric/misplaced_test.dart |  3 +-
.../test/parametric/neighbour_cost_test.dart       |  3 +-
.../test/parametric/neighbourhood_test.dart        |  3 +-
.../jet_cad_2d/test/parametric/place_test.dart     |  3 +-
.../test/parametric/references_test.dart           |  3 +-
.../test/parametric/regeneration_test.dart         |  3 +-
.../jet_cad_2d/test/parametric/regions_test.dart   |  3 +-
.../jet_cad_2d_flutter/lib/src/draw/line_tool.dart |  3 +-
.../lib/src/draw/placement_tool.dart               |  6 ++--
.../jet_cad_2d_flutter/lib/src/draw/text_tool.dart |  2 +-
34 files changed, 133 insertions(+), 74 deletions(-)
```
Inserts per file (from check.py): startup_plan 1; dimension_object 1, dimension_tool 1, opening_cost 1,
opening_tool 2, planner_draw 1, room_cost 1, room_grips 1, room_panel 1, room_tool 1, selection_panel 2,
separator_tool 1, symbols/symbol_place_tool 1, wall_tool 3; regeneration.dart 1; json_codec 1, drafting_test 12,
expander 1, layer_commands_test 1, cascade 4, diagnose 3, guards 3, live_object_rule 1, misplaced 1,
neighbour_cost 1, neighbourhood 1, place 1, references 1, regeneration_test 1, regions 1; line_tool 1,
placement_tool 2, text_tool 1.

The blast radius goes beyond spec D7's list in one place: `test/document/layer_commands_test.dart` (Task 2's file,
1 call), which did not exist when the spec was written. All the others are on D7's list.

### Gates after Task 4 (CI=true, real tails). The counts are unchanged from 3b.
- engine: `00:18 +1211 -2: Some tests failed.` The same 2 standing failures (`generate_document_test.dart: both
  text fractions default to zero and change nothing`, `... the default document is the one Plan 2 measured, byte
  for byte`). `No issues found!`. `Formatted 167 files (0 changed) in 0.63 seconds.`
- render: `00:59 +1154 ~1 -7: Some tests failed.` `No issues found! (ran in 1.5s)`. `Formatted 200 files (0
  changed) in 0.62 seconds.`
- app: `03:15 +934: All tests passed!` `No issues found! (ran in 1.9s)`. `Formatted 165 files (0 changed) in 0.79
  seconds.`
- dev_harness_2d analyze: `No issues found! (ran in 1.1s)`
- Invariant tests: neither file is edited (`git diff af87621 --stat -- packages/*/test/invariants` is empty), and
  both are inside the green counts. `analysis_options.yaml`: not modified and not staged.

No mutant for Task 4 (mechanical, per the plan).

## Things the spec, plan or review got wrong or left open
1. **Review finding 3's suggested test cannot catch O2.** Locking A prunes the root instance before the nested one
   is reached, so a locked context always has a locked ancestor that is already pruned. O2 shows only in the converse
   case (layer 0 locked, its context A unlocked), where the mutant wrongly prunes. Both tests landed; see 3b above.
2. **Review finding 1's single test cannot catch "drop containsHandle"**, because `_lastKnownSlot` also guards an
   edit. One test per conjunct was added. The definition conjunct is unpinned (M3b-4 survives), as explained in the
   mutant table.
3. Spec D7's blast-radius list misses `layer_commands_test.dart`, a Task 2 file that came later. Otherwise the list
   is exact, and dev_harness_2d has no caller, as the spec says.
