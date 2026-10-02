# Task 10 review — 9b + LayerPicker (8eef675, 5ef5673 on 7e83eae)

Reviewer: independent, in the detached worktree `.claude/worktrees/plan-12b-review` at 5ef5673. Scratch: `scratchpad/r10-12b/` (mut.sh, the probe test). Each mutant was restored by `cp` and checked with `diff` (exit 0). The temporary probe test was moved to scratch afterwards. `git status --short` was empty after every run, and no analysis_options rewrite was left behind.

## Verdict: **Approved with notes**

9b closes Task 9 review findings 1–3 and 6 exactly as asked, and every 9b mutant is red. The picker follows D12, D11, R-5, R-6, R-14, S-8, S-13 and S-14:
- the per-key mapping is correct;
- the region moves in both directions, including every fill of the boundary;
- ATTRIB keys collapse into their instance;
- objects move through `ObjectLayer`;
- a plain group disables the picker;
- no-op members are skipped;
- the result is one command or one compound, so one undo step.

M-LP-5, M-LP-17 and the re-fired O-mutants are red. I found no product defect. There are three test gaps (findings 1–3), one of which (finding 1) would let a user-visible regression through. They should land as 10b, Task 11's first commit.

## What I checked

- **9b.** `_update(h, f)` reads `_doc.tables.layers[h]` at dispatch and dispatches nothing for a layer that is gone. The eye, lock, colour (null means no-op) and rename all go through it; only the mark still uses the build-time `r`, and its command carries no record. When the panel is not allowed, `blocked` is set to 'Read-only document', so `onPressed` is null and the tooltip gives the reason (`allowed && blocked == null` became `blocked == null`, which is equivalent). The tests cover the reviewer's same-frame probe, a full-record rename on B, full-record eye, lock and colour, and the hidden, empty, stored-current C, which can be deleted.
- **Mapping (layer_picker.dart:108-156).**
  - InstanceNode → instances.
  - Root parametric group → objects.
  - Any other node → skipped (the picker is disabled by `layerPickerBlocked`).
  - Entity owned by an InstanceNode → its owner, collected in a Set so duplicates collapse.
  - Otherwise, the entity plus its live boundary plus `fillsOf(boundary)`. From a boundary, `_boundaryOfFill` is null, so it uses `h` and `fillsOf(h)`. From a fill, it uses the boundary and every sibling fill, and `h` itself is included. A fill whose boundary is dangling moves alone.
  - Keys come only from `resolveHit` and the marquee, and both are root keys. The marquee never yields an ATTRIB key because its owner is not root, which is the S-14 click-only case. So "root entity" holds.
- **No-op skip.** Exact `==` on the stored value for each member: entity `layerAt`, instance `.layer`, object component or layer 0. 0 members → null, 1 → the command alone, more → `CompoundCommand('Move to layer')`.
- **Capabilities.** `SetEntityLayerCommand` and `SetInstanceLayerCommand` need `components`, and `SetComponentCommand<ObjectLayer>` needs `components`. `ParametricEdit.capabilities` adds `editCapability` only for a command a registered type `owns`, and `ObjectLayer` is not one of those (`parametric_system.dart:682-707`). So runtime can move anything the picker offers, which the runtime test confirms. readOnly disables the picker, and `_choose` checks again before it dispatches.
- **Choose time.** `_choose` reads `selection.keys`, the permission, the layer's existence and the command from the live document. `PopupMenuButtonState` calls `widget.onSelected` from the current widget when the menu completes, so a rebuild while the menu is open does not leave a stale document.
- **SelectionPanel.** The picker shows when the selection is non-empty, `!_toolMode` and `_openingToolMode == null`. It is appended after every type section with a 12 px gap. The single-object sections are untouched, and the only change is the early-return condition. `_sync` already runs `setState` on every selection and command change, so the label follows undo, rename and prune.
- **Layout probe** (`zz_review_probe_test`, removed). The app at 1280×640 and 1280×600, with 8 extra layers that have long names and a door on one of them selected: `REVIEW Size(1280.0, 640.0) picker=1 rect=Rect.fromLTRB(1095.3, 256.0, 1268.0, 292.0) ... exc=null`, `REVIEW menu exc=null items=12`. The same at 600. The probe also showed that the fixture's wall, door, room and dimension are all `isParametricObject`, and that `layerMoveCommand` moves the room by `ObjectLayer` in one undo step (`REVIEW room moved to B: true depth=1`).

## Rulings on the implementer's points

1. **The hard-coded list of six types in `isParametricObject`: accepted, with a recorded risk.** The engine exposes only `names<T>`, and the engine is frozen. The failure mode is safe: an unlisted seventh type is treated as a plain group, so the picker is disabled and nothing moves wrongly. But the reason shown would be wrong, and today nothing pins the list (finding 1). Record it for the results note. In a later engine plan, a `ParametricCatalog.isObject(target, h)` (any registration) should replace it, and the render selection's "every group is an object" (R-12b-8) could use it too.
2. **A split region is labelled by its boundary but moved fully: confirmed.** "A region never splits across layers; its layer is its boundary's" (D12), and D8's prune uses the boundary as well. Choosing the shown layer repairs the split, so it is not a no-op. This only happens in a file.
3. **Absent `ObjectLayer` moved to 0 is a no-op; a dangling one is rewritten to `ObjectLayer(0)`: confirmed.** Stored values are compared with exact `==` (CLAUDE.md), and this repairs the stored value. It is not tested (finding 3).
4. **Tool mode is reachable only by code: confirmed.** The tightened in-app test asserts the premise (the opening section shows and the selection has length 2), and O-12 / O-12b are red.
5. **room_panel_test RN1: accepted.** The assertion it replaces (`selection-panel` absent for a separator) is exactly the behaviour D12 changes ("including when no type section shows"). The new form still pins that there is no type section (`wall-section` absent, and the existing `section` absent) and adds the picker's presence. The test was not weakened.
6. **No colour swatches in the menu: accepted.** Put it on the look list.
7. **Look-list additions: accepted.**

## Findings

1. **Minor (test gap that hides a user-visible regression): `isParametricObject` is pinned for only two of its six types.** My mutant **R-own-5** (layer_picker.dart:33-34, Separator and Room → `false`) **survives** both files that reference the picker (`layer_picker_test.dart`, `room_panel_test.dart`): `00:16 +48: All tests passed!`. With that mutant, selecting a room or a separator disables the picker with "A plain group has no layer". **Fix (10b):** add one test that builds one live object of each registered type (box, wall, opening, separator, room, dimension; `layerFixture()` already has a room and a dimension, so add a box and a separator), selects each one alone, and asserts that the picker is enabled and shows that object's `objectLayer` name (use a non-A layer for at least one). Put a comment on `parametricCatalog` saying that `isParametricObject` must list every registration. Moving the predicate into `live_objects.dart`, next to the catalog, is optional.

2. **Minor (test gap): the D11 capability is pinned only against presets that cannot tell `components` from `transform`.** Mutant **R-own-2** (`:79` `Capability.components` → `Capability.transform`) **survives**: `00:03 +9: All tests passed!`. `readOnly` and `runtime` agree on both capabilities. **Fix (10b):** add two assertions with custom sets. `DraftPermissions(transform: true, components: false, geometry: true, structure: true)` must disable the picker with `kLayerPickerReadOnly`. `DraftPermissions(transform: false, components: true, geometry: false, structure: false)` must leave it enabled and let one choice move a line and a wall.

3. **Minor (test gap): point 3's stored-value rule for objects is unpinned.** Mutant **R-own-3** (`:146` compare `objectLayer(doc, o)` instead of the stored component) **survives**: `00:03 +9: All tests passed!`. **Fix (10b):** add a test where an object's `ObjectLayer` names a layer that has been removed (`SetComponentCommand.restore` or a file), then call `layerMoveCommand(doc, [key], layer0)`. The result must be a `SetComponentCommand<ObjectLayer>`, not null. Also cover an object with no `ObjectLayer`, where the same call must return null.

4. **Info (file-only): an ATTRIB key's label differs from render D8's effective layer when the ATTRIB has its own non-zero layer.**
   - The picker always shows and moves the instance (S-14).
   - `SelectionController._effectiveLayerOf` uses the ATTRIB's own layer when it is not 0.
   - So in such a file, moving the instance to a hidden layer leaves the ATTRIB key selected.
   - No app path makes an ATTRIB (the library refuses them), so this can only come from a file or a future DXF import. Record it as a known limitation.

5. **Info: `_choose` executes without the `on ArgumentError` / `on StateError` guard that the panel's other commits use.** The preconditions are rechecked (permission, layer exists, live keys), so the main remaining case is a regeneration that throws on a broken file. Consider the same catch, which would mean nothing changed.

6. **Info (wording): under `runtime`, LayerPanel's disabled delete reads "Read-only document"** while the picker in the same window is enabled and moves things. "Layers cannot be edited here" or similar would be accurate for both presets. Look list.

7. **Info: `LayerRecord` has no `toString`.** The 9b full-record failures print `Expected: <Instance of 'LayerRecord'>` `Actual: <Instance of 'LayerRecord'>`, which is red but opaque. Optional, and outside the engine freeze: put a `reason:` naming the field on those expects.

## Gates at 5ef5673 (re-run by the reviewer, CI=true, PATH=/root/flutter/bin)

- Engine: `00:17 +1225 -2: Some tests failed.` The 2 failures are the standing ones, `test/testing/generate_document_test.dart: both text fractions default to zero and change nothing` and `...: the default document is the one Plan 2 measured, byte for byte`. Also `No issues found!` and `Formatted 168 files (0 changed) in 0.58 seconds.`
- Render: `01:06 +1187 ~1 -7: Some tests failed.` The 7 failures are the standing canvas rungs: text_ladder 1–5 and text_lod_ladder 1–2. Also `No issues found! (ran in 2.4s)` and `Formatted 208 files (0 changed) in 0.70 seconds.`
- App: `03:36 +986: All tests passed!`, `No issues found! (ran in 2.7s)`, `Formatted 174 files (0 changed) in 0.87 seconds.`
- dev_harness_2d: `No issues found! (ran in 1.2s)`.
- Web at the tip: `Compiling lib/main.dart for the Web... 54.5s` and `✓ Built build/web`.
- `git status --short` was empty.

## Mutants (scratchpad/r10-12b/mut.sh; diff=0 for each)

| id | mutation | real output |
|---|---|---|
| M9b-1 | layer_panel.dart:253 lock from the captured `r` | `00:04 +11 -1: rename a blur-rename then a tap on the same row's lock ... [E]` `00:08 +23 -1: Some tests failed.` |
| O3 | :182 `drawingLayer(_doc)` → `_doc.header.currentLayer` | `Expected: true` `Actual: <false>` `00:03 +5 -1: delete: a stored current layer that is hidden and empty ... [E]` |
| O1 | :266 rename also flips `locked` | `00:04 +10 -1: rename Enter on B (ACI 5, locked) ... [E]` `00:08 +22 -2: Some tests failed.` |
| O2 | :266 rename also sets ACI 7 | `00:08 +22 -2: Some tests failed.` (the same two tests) |
| M-LP-5 | layer_picker.dart, before :132, `if (h.value > 0) { entities.add(h); continue; }` (the implementer's replacement does not compile here, so this is the insert form) | `Expected: <43>` `Actual: <18>` ×2 `00:03 +7 -2: Some tests failed.` |
| M-LP-17 | :182 execute each child of the compound | `Expected: <1>` `Actual: <6>`; `<1>`/`<3>`; `<1>`/`<2>` ×2 (mixed, boundary, hidden, runtime) |
| O-2 | :135 `fillsOf` only when the boundary was picked | `Expected: <43>` `Actual: <18>` `00:03 +8 -1` |
| O-4 | :111 instances a List | `Expected: <Instance of 'SetInstanceLayerCommand'>` `Actual: <Instance of 'CompoundCommand'>` |
| O-6 | :72 a fill labelled by its own layer | `Expected: 'A'` `Actual: 'D'` |
| O-10 | :84 plain-group check → `false` | `Expected: false` `Actual: <true>` `00:02 +7 -1: a plain (non-parametric) group ... [E]` |
| O-12 | selection_panel.dart:787 opening-tool condition → `true` | `Expected: no matching candidates` `Actual: ... Found 1 widget with key [<'layer-picker'>]` `00:04 +8 -1` |
| R-own-1 | selection_panel.dart:785 `keys.isNotEmpty` → `true` | `Found 1 widget with key [<'layer-picker'>]` ×2 `00:05 +15 -2: Some tests failed.` |
| R-own-4 | layer_picker.dart:197 `mixed = true` → `false` | `Expected: 'Mixed'` `Actual: 'A'` |
| R-own-2 | :79 `components` → `transform` | **survives** `00:03 +9: All tests passed!` (finding 2) |
| R-own-3 | :146 skip via `objectLayer(doc, o)` | **survives** `00:03 +9: All tests passed!` (finding 3) |
| R-own-5 | :33-34 Separator and Room dropped from `isParametricObject` | **survives** `00:16 +48: All tests passed!` (finding 1) |

## Non-degeneracy

- **Fixture.** It uses P-6's layers: A (ACI 1), B (ACI 5, locked), C (ACI 3, hidden), plus a visible D (ACI 2) as the target that keeps the selection.
- **Positions and transforms.** The line, the region (at 7300, 2100) and the symbol are away from the origin. The symbol is turned 0.4 rad, and the walls are in rotated groups at the corpus far origin. The plain group is rotated and translated.
- **Region.** It has a second fill naming the same boundary, so S-8's "every fill" is observable (O-2 is red). The split-region label sets fill D against boundary A (O-6 is red).
- **ATTRIB.** It is on layer 0 under an instance on A, so the instance mapping is observable (O-5 and O-7 per the implementer). Layer 0 is a target in only one test; the mixed move targets D and checks that nothing else moved (the wall on A, the door on B).
- **Undo.** It is checked byte for byte against the encoded document.
- **Weak spots.** The object-type list (only Wall and Opening are exercised), the permission sets (only presets that agree on components and transform) and the absent/dangling `ObjectLayer` rule. These are findings 1–3.
