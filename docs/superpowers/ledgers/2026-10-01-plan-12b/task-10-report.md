# Task 10 report — 9b + LayerPicker

Implementer relaunched after a container restart. Inherited HEAD 7e83eae with an
uncommitted partial 9b edit in apps/floor_planner/lib/layers/layer_panel.dart
(`_update(h, f)` reading the live record at dispatch, the row callbacks routed
through it, the read-only delete tooltip). Inspected with `git diff`: correct,
kept as is (only `dart format` reflowed it).

## 9b (Task 9 review findings 1-3, 6)

Files: apps/floor_planner/lib/layers/layer_panel.dart,
apps/floor_planner/test/layers/layer_panel_test.dart.

- Finding 1: `_update(Handle, LayerRecord? Function(LayerRecord))` reads
  `_doc.tables.layers[h]` at dispatch; a gone layer dispatches nothing; the
  colour's same-colour no-op is the `null` return. New test: the reviewer's
  probe (open A's field, type Hall, `tester.tap` A's lock, no frame between
  down and up) -> record == before.copyWith(name: 'Hall', locked: true), depth 2.
- Finding 2: new rename test on B (ACI 5, locked): record == before.copyWith(name: 'Kitchen').
  The "each one command" test now compares the WHOLE record for eye, lock and
  colour (the colour step moved from A to B so a stray `locked` change shows).
- Finding 3: new test: C stored current (restore form), hidden and empty;
  drawingLayer is layer 0; delete enabled, tooltip 'Delete layer', one tap removes C.
- Info 6: read-only delete tooltip 'Read-only document', asserted in the
  read-only test (both readOnly and runtime).

### 9b mutants (scratchpad/l10/mut.sh: sed one line, run layer_panel_test.dart in the foreground, cp back, diff=0)

| id | mutation | red test | real output |
|---|---|---|---|
| M9b-1 | layer_panel.dart:253 lock builds from the captured `r` | blur-rename then same-frame lock | `00:04 +11 -1: rename a blur-rename then a tap on the same row's lock ... [E]` `00:08 +23 -1: Some tests failed.` |
| O1 | :266 rename also flips locked | Enter on B (and the probe) | `00:09 +22 -2: Some tests failed.` |
| O2 | :266 rename also sets ACI 7 | Enter on B (and the probe) | `00:09 +22 -2: Some tests failed.` |
| O3 | :182 `drawingLayer(_doc)` -> `_doc.header.currentLayer` | delete: stored current hidden and empty | `Expected: true` `Actual: <false>` `00:07 +23 -1: Some tests failed.` |
| M9b-4 | :201 read-only reason -> 'Select a layer to delete it' | read-only | `Expected: 'Read-only document'` `Actual: 'Select a layer to delete it'` `00:07 +23 -1` |
| M9b-2e | :251 eye also sets locked: true | each one command | `00:01 +1 -1: the current mark, the eye, ... [E]` `00:07 +23 -1` |
| M9b-2c | :258 colour also sets locked: false | each one command | `00:02 +1 -1: the current mark, the eye, ... [E]` `00:07 +23 -1` |

All diff=0 after restore.

### 9b gates (app only; 9b touched only the app)
- App: `03:19 +977: All tests passed!`, `No issues found! (ran in 14.1s)`, `Formatted 172 files (0 changed) in 0.84 seconds.`
- Commit: **8eef675** `fix(app): Task 9 review follow-ups`. (Engine/render/harness were re-run at the Task 10 tip, below.)

## Task 10 — LayerPicker (spec D12)

Commit: **5ef5673** `feat(app): move the selection to a layer` (amended once, before any review, to tighten the in-app test after O-12 survived; never pushed).

Files:
- apps/floor_planner/lib/layers/layer_picker.dart (new): `LayerPicker` (stateless; `SelectionPanel` rebuilds it), and the pure helpers `isParametricObject`, `layerOfKey`, `layerPickerBlocked`, `layerMoveCommand`, constants `kMixedLayers`, `kLayerPickerReadOnly`, `kLayerPickerPlainGroup`.
- apps/floor_planner/lib/selection_panel.dart: `picker = keys.isNotEmpty && !_toolMode && _openingToolMode == null`; the panel no longer returns `SizedBox.shrink()` when only the picker shows; the picker sits after the type sections; class doc gains the Layer bullet.
- apps/floor_planner/test/layers/layer_picker_test.dart (new, 9 tests).
- apps/floor_planner/test/support/layer_fixture.dart: `addLineOn`, `addRegionOn` (circle region + a second fill naming the same boundary), `addSymbolOn` (definition with a layer-0 line, a turned root instance on the given layer, an ATTRIB on layer 0).
- apps/floor_planner/test/room_panel_test.dart (RN1): the "a separator has no section" assertion expected `selection-panel` to be absent; with D12 the panel now shows the picker for a separator. Changed to: no `wall-section`, and `layer-picker` found. This is the only edit to an existing test; it follows directly from D12 ("including when no type section shows").

Behaviour:
- Keys: an `InstanceNode` -> `SetInstanceLayerCommand`; an entity owned by an `InstanceNode` (ATTRIB) -> its owner instance (set, so duplicates collapse); a root `GroupNode` that `isParametricObject` -> `SetComponentCommand<ObjectLayer>`; any other `GroupNode` -> picker disabled ("A plain group has no layer: it cannot be moved"); another entity -> itself plus, if a fill with a live boundary, that boundary, plus `fills.fillsOf(boundary)` (so from a boundary every fill, from a fill the boundary and every sibling fill).
- No-op skip by exact `==` on the stored value: entity `layerAt`, instance `.layer`, object `components.get<ObjectLayer>()?.layer ?? layer 0`. 0 -> nothing; 1 -> the command alone; more -> `CompoundCommand(label: 'Move to layer')` (records, then instances, then objects).
- Label: per key, an instance's layer, an ATTRIB's instance's, an object's `objectLayer`, a fill's boundary's, else the entity's own; plain groups ignored for the label; differing -> "Mixed".
- `_choose` rebuilds the command from the live document and the live selection at the choice (Task 9's finding-1 lesson) and does nothing if the chosen layer is gone or the picker is now blocked.
- Disabled (tooltip "Read-only document") when `!document.commands.permissions.allows(Capability.components)`.

### Gates at 5ef5673 (CI=true, PATH=/root/flutter/bin)
- Engine: `00:17 +1225 -2: Some tests failed.` — the 2 standing: `test/testing/generate_document_test.dart: both text fractions default to zero and change nothing`, `...: the default document is the one Plan 2 measured, byte for byte`. `No issues found!`, `Formatted 168 files (0 changed) in 0.56 seconds.`
- Render: `00:56 +1187 ~1 -7: Some tests failed.` (the 7 standing text_ladder_golden_test rungs). `No issues found! (ran in 1.9s)`, `Formatted 208 files (0 changed) in 0.68 seconds.`
- App: `03:16 +986: All tests passed!` (974 at 7e83eae + 3 in 9b + 9 picker), `No issues found! (ran in 1.6s)`, `Formatted 174 files (0 changed) in 0.82 seconds.`
- dev_harness_2d: `No issues found! (ran in 1.6s)`.
- Web: `Compiling lib/main.dart for the Web... 59.8s`, `✓ Built build/web` (built at 908d3a5; the amend changed only a test file).
- Allocation invariant tests: not touched (no engine/render change). No analysis_options.yaml staged; `git status --short` clean after commit.

### Task 10 mutants (scratchpad/l10/mut.sh; each diff=0 after restore)

| id | mutation | red test | real output |
|---|---|---|---|
| **M-LP-5** | layer_picker.dart:132 only the picked record (`entities.add(h); continue;`) | mixed selection; region from boundary | `Expected: <43>` `Actual: <18>` `00:02 +7 -2: Some tests failed.` |
| **M-LP-17** | layer_picker.dart:182 execute each child of the compound separately | mixed (`Expected: <1>` `Actual: <6>`), boundary (`<3>`), hidden (`<2>`), runtime (`<2>`) | `... -4` |
| O-1 | :135 from a boundary, no `fillsOf` | mixed; boundary | `00:03 +7 -2: Some tests failed.` |
| O-2 | :135 `fillsOf` only when the boundary was picked (fill -> no sibling fills) | mixed (secondFill) | `00:02 +8 -1: Some tests failed.` |
| O-3 | :140 entity no-op skip dropped | already on target | `Expected: <0>` `Actual: <1>` |
| O-4 | :111 instances a List (no collapse) | ATTRIB + instance one member | `Expected: <Instance of 'SetInstanceLayerCommand'>` `Actual: <Instance of 'CompoundCommand'>` |
| O-5 | :128 ATTRIB not mapped to its instance | already on target | `Expected: <0>` `Actual: <1>` |
| O-6 | :71 label: a fill shows its own layer | label | `Expected: 'A'` `Actual: 'D'` |
| O-7 | :70 label: an ATTRIB shows its own layer | label | `Expected: 'A'` `Actual: '0'` |
| O-8 | :79 permission `components` -> `structure` | runtime | `Expected: true` `Actual: <false>` |
| O-9 | :79 no permission check | read-only | `Expected: false` `Actual: <true>` (red at the enabled assertion, no PermissionDeniedError caught) |
| O-10 | :84 plain group treated as parametric | plain group | `Expected: false` `Actual: <true>` |
| O-11 | selection_panel.dart:793 no panel when only the picker would show | line-only (and 7 others) | `Found 0 widgets with key [<'layer-picker'>]` `00:02 +1 -8` |
| O-12 | selection_panel.dart:787 opening-tool condition dropped | in the app | first fire **survived** (`00:02 +9: All tests passed!`): the app clears the selection when a drawing tool activates, so the premise was degenerate. Test tightened (re-select while the tool is active, premise asserted); re-fired: `Expected: no matching candidates` `Actual: ... Found 1 widget with key [<'layer-picker'>]` `00:03 +8 -1` |
| O-12b | selection_panel.dart:786 Wall-tool condition dropped | in the app | `Found 1 widget with key [<'layer-picker'>]` `00:03 +8 -1` |
| O-13 | :143 instance no-op skip dropped | already on target | `Expected: <0>` `Actual: <1>` |
| O-14 | :148 object no-op skip dropped | already on target | `Expected: <0>` `Actual: <1>` |

(Handles print as their int values in `Expected`/`Actual`: the expected value is the target layer's handle, the actual the record's unmoved layer.)

## Spec / plan points, decisions
1. **No engine "any registered type" query.** `ParametricCatalog` exposes only `names<T>` (its `_naming` is private). The picker's `isParametricObject` ORs `isLiveObject<T>` over the app's six registered types (Box, Wall, Opening, Separator, Room, Dimension). A type registered later must be added there too. The brief allowed this ("or simply a root group carrying a registered parametric component"); not an engine change (engine frozen).
2. **D12 "the region's layer is its boundary's" vs the no-op skip.** The label is per key (a fill key shows its boundary's layer); the skip is per record. So a file-split region (fill on D, boundary on A) shows "A", and choosing A still moves the fill: not a no-op. Consistent with "a region never splits across layers".
3. **An object with no `ObjectLayer`, moved to layer 0, is a no-op** (absent means layer 0, D2). An `ObjectLayer` naming a missing layer is not equal to 0, so moving it to 0 writes `ObjectLayer(0)` (repairs the stored value).
4. **Tool mode is only reachable by code in the app**: `_activate` clears the selection for every drawing tool (main.dart:652). The S-13 condition is kept and pinned by programmatic selection while the tool is active.
5. **Existing test edit:** room_panel_test RN1 (above): its "separator has no section" premise was `selection-panel` absent; D12 makes the picker show there.
6. **No colour swatches in the picker menu:** `SelectionPanel` has no paper foreground (ACI 7) to draw them; names only, in `layersInPanelOrder`. For the human's look list.
7. **Look list additions:** the picker row ("Layer" + menu) under each type section; a long layer name ellipsised; the disabled tooltip on a plain group (file-only).
