# Task 2 report — the layer commands and ObjectLayer

Implementer: fresh agent. Base HEAD a6cd4bb. Scratch: .../scratchpad/l2/ (mutant runner `mut.py`).

## Commit

`ab7a225 feat(engine): layer commands and ObjectLayer` (one commit; amended once before any review to
strengthen the duplicate-handle test after mutant O11 survived, see below). Not pushed.

Files (all engine, `packages/jet_cad_2d`):
- `lib/src/document/object_layer.dart` (new): `ObjectLayer`, typeId `jet_cad.object_layer`, `toJson {'layer': h}`, value `==`.
- `lib/src/document/component.dart`: `registerBuiltIns` registers it, not internal.
- `lib/src/document/layer_commands.dart`: `objectLayer`, `layerIsEmpty`, the six D1 commands.
- `lib/src/document/validate.dart`: `warning()` helper, `ValidationCodes.currentLayerUnusable`
  (`header.current_layer_unusable`) and `objectLayerMissing` (`component.object_layer_missing`), step 8.
- `lib/jet_cad_2d.dart`: export of `object_layer.dart`.
- `test/document/layer_commands_test.dart` (new, 39 tests), `test/document/layer_validate_test.dart` (new, 7 tests).

The two allocation invariant tests: untouched (`git diff --stat a6cd4bb HEAD` lists only the 7 files above).
No `analysis_options.yaml` staged.

## Gates (at ab7a225's tree)

- engine `dart test`: `00:17 +1184 -2: Some tests failed.` (1138 + 46 new); the two failing are the standing
  `test/testing/generate_document_test.dart: the default document is the one Plan 2 measured, byte for byte [E]`
  and `...: both text fractions default to zero and change nothing [E]`. `dart analyze`: `No issues found!`;
  format: `Formatted 165 files (0 changed)`.
- render `flutter test`: `00:58 +1154 ~1 -7: Some tests failed.` — text ladder rungs 1-5 and text lod ladder
  rungs 1-2 (canvas), the standing seven. analyze `No issues found! (ran in 2.4s)`; format `Formatted 200 files (0 changed)`.
- app: `03:18 +934: All tests passed!`; `No issues found! (ran in 4.3s)`; `Formatted 165 files (0 changed)`.
- dev_harness_2d analyze: `No issues found! (ran in 1.1s)`.

## Design as built

- P-2 forms: public unnamed user constructor + public `.restore(...)`, private `final bool _restore`.
  Every inverse is `.restore` (6 sites). User-rule failures throw `ArgumentError` (missing target layer,
  D4 name, layer 0 rename, decision 7, D5 in use, layer 0 / current delete). Integrity failures throw
  `StateError` in both forms (missing entity, non-instance node; restore form's missing layer record) —
  as every command in `commands.dart` does; `AddLayerCommand`'s used handle throws `DuplicateHandleError`
  (as `AddNodeCommand`).
- Capabilities: table commands `structure`/`{structure}`; `SetEntityLayerCommand`/`SetInstanceLayerCommand`
  `capability geometry`, `capabilities {components}` (overrides the base getter).
- touched: layer handle; `{old, new}` for SetCurrentLayer; the entity / node for moves.
- `SetLayerCommand` checks everything before `remove`: user form = exists, `layerNameError(self)`, layer 0's
  name (exact `!=`), decision 7; restore form = exists + no other layer holds the new name under
  `toLowerCase()` (the only thing `TableSection.add` could refuse after the remove).
- Labels: "Add layer", "Delete layer", "Set current layer", "Move to layer"; SetLayerCommand by what changed:
  "Rename layer", "Change layer colour", "Hide layer"/"Show layer", "Lock layer"/"Unlock layer", else "Edit layer"
  (several fields at once, or none). The label is computed in `apply` from the old record (the dispatcher reads
  `label` after apply for the DocChange); before apply it reads "Edit layer" (only a PermissionDeniedError
  message sees that).
- Both forms of `AddLayerCommand` raise the handle seed past the record's handle (as `AddNodeCommand`); the user
  form also refuses a handle naming a layer, node, definition or entity.
- `layerIsEmpty`: false for layer 0 and `drawingLayer`; one pass over `entities.liveSlots` (root + definition
  leaves), `tree.nodes` (InstanceNodes, including those inside definitions), and `withComponent<ObjectLayer>()`
  skipping handles with no node (`tree[h] == null` = dead).
- validate step 8: warnings appended after the fills step, so existing order is unchanged.

## Decisions / where the spec or plan was loose

1. **Decision 7 as a transition.** The user form refuses `SetLayerCommand` only when it *hides* the effective
   current layer (`old.visible && !record.visible && handle == drawingLayer`). Read literally ("`visible: false` on
   it is refused"), recolouring or locking a hidden layer 0 that is the effective current layer (the S-6 file state:
   hidden layer 0, no usable stored current) would also be refused, a needless dead end; the transition reading
   keeps M-LP-9's case red and allows those edits. Reviewer to confirm.
2. **Missing entity/node in the user form = StateError, not ArgumentError.** P-2 says the user form "throws
   ArgumentError"; I kept ArgumentError for the *user rules* (incl. a missing target layer, which the spec lists
   among them) and StateError for integrity (the entity/node does not exist), matching every other command.
3. **A seventh restore test and an instance one.** Beyond spec (a)-(d), tests cover undo of moving an *instance*
   off a missing layer and undo of an `AddLayerCommand` whose handle the stored current layer already names (the
   only way the Remove inverse meets a user rule; it is the R-12b-3 state). They give M-LP-7 a red test for all six
   inverses.
4. **Restore form's name-collision check in SetLayerCommand is defensive and has no red test**: no command
   sequence can reach it (only a direct table write between a command and its undo). Recorded, not gated.
5. Plan said `.restore` checks "only that the handle it needs exists"; `SetCurrentLayerCommand.restore` checks
   nothing (the stored value may name no layer — that is case (a)), and `AddLayerCommand.restore` relies on
   `TableSection.add`'s own pre-mutation checks.

## Mutants (engine; cp backup, one-line mutation, test file in the foreground, cp back, `diff` exit 0 each — all `diff= 0`)

| id | file: site | mutation | test file | result (real lines) |
|---|---|---|---|---|
| M-LP-7a | layer_commands.dart SetCurrentLayer inverse | `.restore(old)` -> user form | layer_commands_test | RED `the restore form (a) undo of picking a current layer while the stored one dangles [E]` |
| M-LP-7b | SetLayer inverse | user form | layer_commands_test | RED `the restore form (b) undo of showing a loaded hidden current layer [E]` |
| M-LP-7c | RemoveLayer inverse (`AddLayerCommand.restore(record)`) | user form | layer_commands_test | RED `the restore form (c) undo of deleting a loaded layer whose name fails D4 [E]` |
| M-LP-7d | SetEntityLayer inverse | user form | layer_commands_test | RED `the restore form (d) undo of moving an entity off a missing layer [E]`, `+38 -1: Some tests failed.` |
| M-LP-7e | SetInstanceLayer inverse | user form | layer_commands_test | RED `the restore form undo of moving an instance off a missing layer [E]`, `+38 -1` |
| M-LP-7f | AddLayer inverse (`RemoveLayerCommand.restore`) | user form | layer_commands_test | RED `the restore form undo of adding a layer the stored current layer already names [E]`, `+38 -1` |
| M-LP-8 | SetLayer user form | `layerNameError(...)` -> `const String? reason = null;` | layer_commands_test | RED `SetLayerCommand a rename to a case-folded duplicate is refused and keeps the record (M-LP-8) [E]`, `... a rename to an invalid name ... [E]`, `+37 -2` |
| M-LP-9 | SetLayer decision 7 | `if (false) {` | layer_commands_test | RED `SetLayerCommand the effective current layer cannot be hidden (M-LP-9) [E]`, `+38 -1` |
| M-LP-10a | layerIsEmpty ObjectLayer | `if (false) {` (ignores ObjectLayer) | layer_commands_test | RED `RemoveLayerCommand refuses a layer an ObjectLayer on a live node uses (M-LP-10) [E]`, `+38 -1` |
| M-LP-10b | layerIsEmpty entity loop | skip slots whose owner is a definition | layer_commands_test | RED `RemoveLayerCommand refuses a layer a definition leaf uses (M-LP-10) [E]`, `+38 -1` |
| M-LP-10c | layerIsEmpty ObjectLayer | drop the dead-node skip (counts a dead node's ObjectLayer; dead handle made by a direct `components.attach`) | layer_commands_test | RED `RemoveLayerCommand an ObjectLayer on a dead handle does not keep a layer (M-LP-10) [E]`, `+38 -1` |
| O1 | SetEntityLayer capabilities | `{components}` -> `{geometry}` | layer_commands_test | RED `...the moves need components and report geometry [E]`, `runtime refuses the table commands and allows the moves [E]`, `+37 -2` |
| O3 | SetCurrentLayer touched | `{old, layer}` -> `{layer}` | layer_commands_test | RED `touched is never empty: the layer, {old, new}, the moved thing [E]` |
| O4 | validate hidden current | `else if (false)` | layer_validate_test | RED `header.current_layer_unusable is a warning when the stored current layer is hidden [E]`, `+6 -1` |
| O5 | validate ObjectLayer | live handles only | layer_validate_test | RED `component.object_layer_missing is a warning for an ObjectLayer on a dead handle too [E]` |
| O6 | registerBuiltIns | `internal: true` | layer_commands_test | RED `ObjectLayer serialises its layer, compares by value and is registered [E]` |
| O7 | objectLayer | return `component.layer` unchecked | layer_commands_test | RED `ObjectLayer objectLayer: the component layer, else layer 0 [E]` |
| O9 | SetLayer label | always `'Hide layer'` for a visibility change | layer_commands_test | RED `SetLayerCommand rename, recolour, hide, show, lock and unlock ... label naming what changed [E]` |
| O11 | AddLayer user form | drop `tree[handle] != null` | layer_commands_test | first fire: **survived** (`+39: All tests passed!` — the test only used an entity handle). Test strengthened to loop over an entity, a group node, a definition and a layer handle; re-fired: RED `AddLayerCommand refuses a duplicate name ..., an invalid name and a used handle [E]`, `+38 -1` |
| O11b | AddLayer user form | drop `tree.definition(handle) != null` | layer_commands_test | RED (same test), `+38 -1` |
| O12 | layerIsEmpty | drop the InstanceNode check | layer_commands_test | RED `RemoveLayerCommand refuses a layer an instance uses [E]` |
| O13 | validate warning() | severity `error` | layer_validate_test | RED 3 tests, `+4 -3` |

Named: 11 fired (M-LP-7 x6, M-LP-8, M-LP-9, M-LP-10 x3), 11 red. Own: 11 fired, 11 red after the O11 test fix
(1 survivor before it, fixed in the amended commit). Tree clean after (`git status --short` empty).
