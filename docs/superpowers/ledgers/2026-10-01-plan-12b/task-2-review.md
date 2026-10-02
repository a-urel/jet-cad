# Task 2 review — the layer commands and ObjectLayer

Reviewer: independent agent, detached worktree `.claude/worktrees/plan-12b-review` at `ab7a225` (base `a6cd4bb`).
Scratch: `.../scratchpad/r2/t2/` (runner `mut.py`: cp backup, one exact-string mutation asserted unique, test file in the
foreground, cp back, `diff` exit code printed). Tree clean after (`git status --short` empty).

## Verdict: **Approved with notes**

No product defect found. The commands meet D1's table, P-2's two forms and the "complete or untouched" contract; D5's
emptiness and D3's warnings match the spec. All named mutants go red. Three of my own mutants survive. All three are
gaps in the tests, not in the code (findings 1–3). They are cheap test-only additions, and I recommend landing them in
a small amend or at the start of Task 3, before the panel (Task 9) starts relying on these paths.

## Gates (re-run here, CI=true, real tails)

- engine `dart test`: `00:18 +1184 -2: Some tests failed.`. The two failures are the standing ones:
  `the default document is the one Plan 2 measured, byte for byte [E]` and
  `both text fractions default to zero and change nothing [E]`. `dart analyze`: `No issues found!`. Format:
  `Formatted 165 files (0 changed) in 0.67 seconds.`
- render `flutter test`: `01:03 +1154 ~1 -7: Some tests failed.`. The seven failures are text ladder rungs 1–5 and
  text lod ladder rungs 1–2 (canvas). analyze `No issues found! (ran in 2.1s)`; format `Formatted 200 files (0 changed)`.
- app: `03:17 +934: All tests passed!`; `No issues found! (ran in 4.0s)`; `Formatted 165 files (0 changed)`.
- dev_harness_2d analyze: `No issues found! (ran in 1.4s)`.
- No `analysis_options.yaml` was modified (`git status --short` was empty after all gates).

## Diff check against the spec and the plan

- **ObjectLayer**: typeId `jet_cad.object_layer`, `toJson {'layer': int}`, `fromJson`, value `==`/`hashCode`.
  It is registered in `registerBuiltIns` without `internal` (S-16). The circular import between component.dart and
  object_layer.dart is harmless in Dart. A codec round trip is byte-identical (tested).
- **objectLayer**: returns the component's layer when the table contains it, else layer 0, and never refuses. Matches D2.
- **Capabilities** match D1's table exactly. The four table commands are `structure`/`{structure}`. The two moves
  override `capabilities` to `{components}` and keep `capability == geometry`. A
  `CompoundCommand[SetComponentCommand<ObjectLayer>, moves]` has `{components}` / `geometry` (tested).
- **touched** is never empty: the layer handle for the table commands, `{old, layer}` for `SetCurrentLayerCommand`
  (one element when they are equal, still non-empty), and the entity or node for the moves.
- **Complete or untouched**:
  - `AddLayerCommand`: user checks run first. `TableSection.add` then checks the handle and the folded name before
    it writes. `raiseTo` cannot throw. Moving the seed after the add is therefore safe, and it matches
    `AddNodeCommand`/`AddEntityCommand`.
  - `RemoveLayerCommand`: all checks run before `remove`.
  - `SetLayerCommand`: the user form checks existence, `layerNameError(self)`, layer 0's name and decision 7. The
    restore form checks existence and the folded-name holder. Both run before `remove`. After the remove,
    `TableSection.add` can refuse only a duplicate handle (impossible, the handle was just removed) or a folded name
    held by another record. That is exactly what the restore form pre-checks and what `layerNameError(self)` covers
    in the user form.
  - Moves: the slot or node check and the layer check run before `replace`/`replaceNode`. `replaceNode` with the same
    parent does not re-link (`_link` has a `contains` guard), so the bytes round-trip (tested).
- **P-2 exact restore**: all six inverses are `.restore` with the old stored value (the record, the header value, the
  layer column, the node's layer). `TableSection.records` is sorted by handle, so remove-then-add does not reorder
  the encoded bytes. The bytes-equal round trips in the tests confirm it.
- **D5**:
  - Returns false for layer 0 and for `drawingLayer`.
  - `entities.liveSlots` covers root entities and definition leaves.
  - `tree.nodes` covers every `InstanceNode`.
  - `withComponent<ObjectLayer>()` is filtered by `tree[h] != null` (live nodes only).
  - It is O(n), off the frame path.
- **Validate**: `warning()` helper; `header.current_layer_unusable` for a dangling or a hidden stored current layer;
  `component.object_layer_missing` for any handle, live or dead. It is appended as step 8, so existing diagnostic
  order is unchanged.
- **Dispatcher**: `execute` runs `_require(effective)` on `capabilities`, then reads `label` after `apply` for
  `CommandApplied`. Undo and redo read `inverse.label` after its `apply`. So `SetLayerCommand`'s computed label is
  what the DocChange carries. The only pre-apply read is `PermissionDeniedError`'s message, which reads
  "Edit layer". That is acceptable. A refused user form throws before any mutation, and `execute` pushes no history
  (tested: `undoDepth` is unchanged).

## Rulings on the implementer's points

1. **Decision 7 as a transition (R-12b-4): confirmed.** D9 requires it. In the S-6 file state (a hidden layer 0 that
   is the effective current layer), D9 keeps the lock and the colour swatch enabled and disables only the *hide*
   direction of the eye. Under the literal reading those two controls would throw on that row. Refusing only
   `old.visible && !record.visible` on `drawingLayer` is the closest reading inside the spec. It is unpinned, though:
   see finding 2.
2. **Missing entity or node = `StateError` in the user form: accepted.** D1 lists only a *missing target layer* among
   the user rules. An absent entity or node is an integrity failure, which every command in `commands.dart` treats
   as `StateError`, and the panel never builds one.
3. **The extra restore tests: good.** They give every one of the six inverses a red test.
4. **The defensive name check in `SetLayerCommand.restore`: keep it, but test it.** It is the only thing that keeps
   the restore path complete-or-untouched. Without it, `remove` succeeds, `add` throws
   `DuplicateTableNameError` and the record is lost. No command sequence reaches it, because linear history keeps
   collisions out. A direct table write can reach it, and the spec says the engine allows one (D9: "a direct table
   write, which no shipped code makes but the engine allows"). Mutant R4 survives. See finding 3.
5. **`SetCurrentLayerCommand.restore` checks nothing: correct.** Case (a) is exactly a stored value that names no
   layer.

## Mutants (real output lines)

Named (layer_commands_test.dart):

| id | mutation | result |
|---|---|---|
| M-LP-7a | SetCurrentLayer inverse → user form | RED `the restore form (a) undo of picking a current layer while the stored one dangles [E]` |
| M-LP-7b | SetLayer inverse → user form | RED `the restore form (b) undo of showing a loaded hidden current layer [E]` |
| M-LP-7c | RemoveLayer inverse → `AddLayerCommand(record)` | RED `the restore form (c) undo of deleting a loaded layer whose name fails D4 [E]` |
| M-LP-7d | SetEntityLayer inverse → user form | RED `the restore form (d) undo of moving an entity off a missing layer [E]` |
| M-LP-8 | `layerNameError(...)` → `const String? reason = null;` | RED `... a rename to a case-folded duplicate is refused and keeps the record (M-LP-8) [E]`, `... a rename to an invalid name ... [E]` |
| M-LP-9 | decision 7 → `if (false) {` | RED `SetLayerCommand the effective current layer cannot be hidden (M-LP-9) [E]` |
| M-LP-10a | ObjectLayer test → `if (false) {` | `00:00 +38 -1: Some tests failed.` RED `RemoveLayerCommand refuses a layer an ObjectLayer on a live node uses (M-LP-10) [E]` |
| M-LP-10b | entity loop skips slots whose owner is a definition | `00:00 +38 -1` RED `RemoveLayerCommand refuses a layer a definition leaf uses (M-LP-10) [E]` |
| M-LP-10c | drop `if (target.tree[handle] == null) continue;` | `00:00 +38 -1` RED `RemoveLayerCommand an ObjectLayer on a dead handle does not keep a layer (M-LP-10) [E]` |

All `diff=0` after restore.

Own:

| id | mutation | result |
|---|---|---|
| R1 | `layerIsEmpty`: drop the layer 0 early return | **SURVIVED** `00:00 +39: All tests passed!` |
| R2 | `RemoveLayerCommand`: layer 0 check → `if (false) {` | **SURVIVED** `00:00 +39: All tests passed!` |
| R3 | decision 7: drop `old.visible &&` (literal reading) | **SURVIVED** `00:00 +39: All tests passed!` |
| R4 | `SetLayerCommand.restore` holder check never fires (`holder.handle == Handle(0)`) | **SURVIVED** `00:00 +39: All tests passed!` (a first `if (false) {` variant failed to load, `+0 -1 loading ... [E]`, and was re-fired compilable) |
| R5 | decision 7 against `header.currentLayer` instead of `drawingLayer` | RED `00:00 +38 -1` `... the effective current layer cannot be hidden (M-LP-9) [E]` |
| R6 | AddLayer: drop `handleSeed.raiseTo` | RED `00:00 +38 -1` `AddLayerCommand raises the seed past its handle [E]` |
| R7 | SetCurrentLayer user form: drop the hidden check | RED `00:00 +38 -1` `... a locked layer may be current; a hidden or missing one may not [E]` |
| R8 | SetCurrentLayer touched `{old, layer}` → `{layer}` | RED `00:00 +38 -1` `... touched is never empty ... [E]` |
| R9 (validate) | hidden-current branch tests `locked` instead of `!visible` | RED `00:00 +2 -5` incl. `a clean document ... reports nothing [E]` |
| R10 | SetLayer user form: drop `self: handle` | RED `00:00 +33 -6` incl. `SetLayerCommand a case-only rename of self is valid [E]` |

All `diff=0` after restore.

## Findings

1. **(Minor, test) The layer 0 guards are hidden by a degenerate fixture (R1, R2 survive).** In every test that
   asserts layer 0 cannot be deleted or is not empty, layer 0 is also the default current layer, so the
   `drawingLayer` check refuses it first. **Fix:** in `layerIsEmpty: an unused layer is, layer 0 and the effective
   current are not`, set `currentLayer = f.a` before `expect(layerIsEmpty(f.doc, ReservedHandles.layerZero), isFalse)`
   (R1 then goes red). In `refuses layer 0, ...`, set `currentLayer = f.a` first and assert the reason, e.g.
   `throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('Layer 0')))`, so R2 goes red. R2 is
   otherwise equivalent, because `layerIsEmpty` also refuses layer 0.
2. **(Minor, test) The transition reading of decision 7 is not pinned (R3 survives).** Add a test with stored current
   = `C` (hidden), so layer 0 is the effective current layer, and layer 0 hidden by a direct table write. Then show
   that `SetLayerCommand(zero.copyWith(color: IndexedColor(3)))` and `...copyWith(locked: true)` apply. That is the S-6
   state D9 depends on. R3 then goes red.
3. **(Minor, test) The restore form's name-collision guard has no test (R4 survives).** Test it with a direct table
   write between execute and undo:
   1. Rename `A` to `Walls` with the user form.
   2. Do `f.doc.tables.layers.add(record(newHandle, 'A', 2))`.
   3. Expect `undo()` to throw `StateError`, the bytes to be unchanged, `f.layer(f.a).name == 'Walls'` (the record is
      not lost), and `canUndo` still true.

   R4 then goes red: the remove succeeds and the add throws `DuplicateTableNameError`.
4. **(Info, for Task 3/9) `SetLayerCommand` fires `tables.changes` twice, with a gap where the record is missing.** It
   is a remove followed by an add, and each one bumps synchronously. A listener that reads the layer table inside
   the `tables.changes` callback sees the record absent during the gap. Today the only consumer is the canvas
   repaint, which is deferred. Task 3's revision check and Task 9's panel must read on the next frame or on the
   DocChange, never synchronously inside the callback. That is worth one line in Task 3's brief.
5. **(Info) `AddLayerCommand`'s user form does not check the handle against the other five table sections**
   (linetypes, text styles, …). The panel takes `handleSeed.next()`, so this is unreachable. Leave it.
6. **(Info) `object_layer_missing` warnings come in component-store order, not ascending handle.** Nothing specifies
   an order, and the tests read single diagnostics. Leave it.
