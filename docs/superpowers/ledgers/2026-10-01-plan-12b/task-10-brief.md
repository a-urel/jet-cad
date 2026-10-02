# Task 10 brief — LayerPicker (spec D12) — preceded by 9b
Read common.md in this directory first and follow it. HEAD 7e83eae. Scratch prefix: /tmp/claude-0/-home-user-jet-cad/436a473c-2fd9-5dea-b1ee-ba84afc1ba81/scratchpad/l10/ (use only that directory).

## First, as its own commit: 9b (Task 9's review findings 1-3, 6)
Read task-9-review.md. Probe tests are in scratchpad/r9-12b/.
1. layer_panel.dart: every row callback reads the LIVE record at dispatch time (one `_update(h, f)` helper over `_doc.tables.layers[h]`), not the record captured at build; skip if the record is gone. Land the reviewer's probe as a test (rename A to Hall, tap A's lock with no frame between down and up -> name Hall and locked). Mutant: revert to the captured record -> red.
2. Full-record checks: rename B (ACI 5, locked) and assert the whole record equals before.copyWith(name: ...); the same for eye, lock and colour. Re-fire the reviewer's O1 and O2 -> red.
3. Delete vs drawingLayer: a file whose stored current layer C is hidden and empty -> delete enabled for C, one tap removes it. Re-fire O3 -> red.
4. (info 6) In read-only the disabled delete button's tooltip gives a reason (e.g. "Read-only document"); one assertion.
Commit `fix(app): Task 9 review follow-ups` (9b).

## Then plan Task 10 exactly
- apps/floor_planner/lib/layers/layer_picker.dart; SelectionPanel (lib/selection_panel.dart) renders it for a non-empty selection whenever no tool-settings section shows, INCLUDING where build returns SizedBox.shrink() today (selection_panel.dart ~:304-310, :776-786) — a line, a text, a symbol, a multi-selection.
- It shows the selection's common layer (a region's is its boundary's; an ATTRIB key's is its instance's; a parametric object's is objectLayer) or "Mixed".
- Choosing a layer dispatches ONE command: per key — a root entity: SetEntityLayerCommand; a drafted region (fill or boundary picked): every record — from a fill, its boundary (boundaryHandleOf on the fill's payload; find the real API) and every fill naming that boundary; from a boundary, every fill in document.fills.fillsOf(boundary); a root InstanceNode: SetInstanceLayerCommand; an ATTRIB key: mapped to its owning instance (duplicates collapse); a parametric object (isLiveObject of a registered type, or simply a root group carrying a registered parametric component): SetComponentCommand<ObjectLayer>; a plain non-parametric GroupNode key disables the picker with a tooltip. Members already on the target are skipped; all no-op -> nothing dispatched; one member -> its command alone; more -> CompoundCommand. One undo step.
- Disabled when !permissions.allows(Capability.components) (read permissions from document.commands.permissions).
- Moving to a hidden or locked layer is allowed; the selection then prunes (render D8).
- Tests (test/layers/layer_picker_test.dart): shown for a line-only selection; a mixed selection (a line, a drafted region picked on its fill, a symbol, a wall) moves in one undo step with both region records moved; "Mixed" shown for mixed layers; all-no-op dispatches nothing; moving to a hidden layer empties the selection; read-only and runtime: runtime allows (components), readOnly disables; a plain group disables.
- Web build.
Mutants: M-LP-5, M-LP-17, plus your own. Gates: all packages + web.
