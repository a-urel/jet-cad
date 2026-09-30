# Task 1 report: engine, the state identity (plan 12a, spec D3)

**Commit:** `f8e296d` `feat(engine): the dispatcher numbers the states it moves between`
on `plan-12a/document-lifecycle`, parent `d499615`. Not pushed. The commit ends
with both trailers. Files: `packages/jet_cad_2d/lib/src/document/undo.dart`
(+137/-32 incl. docs) and the new `packages/jet_cad_2d/test/document/undo_state_test.dart` (326 lines).
The worktree is clean after the commit. No render or app file was touched, and no `analysis_options.yaml` was committed.

## API as landed (`undo.dart`)

`UndoStack` (still public and exported):
- Entries are `typedef _Entry = ({DraftCommand command, int returnsTo})`. The typedef is private, so it adds no public API.
- New fields: `int _state = 0`, `int _next = 0`, `int get state => _state`.
- `void recordExecute(DraftCommand inverse)` pushes `(inverse, _state)` and sets `_state = ++_next`. It then evicts the oldest entry if `length > limit` and clears redo.
- `DraftCommand beginUndo() => _undo.last.command` (not popped).
- `void commitUndo(DraftCommand redoInverse)` pops the entry, pushes `(redoInverse, _state)` on redo, then sets `_state = entry.returnsTo`.
- `void abortUndo() {}` is an explicit no-op.
- `beginRedo()`, `commitRedo(DraftCommand undoInverse)` and `abortRedo() {}` are symmetric. `commitRedo` pushes onto undo without clearing redo and does no eviction; the dartdoc says why (undo + redo ≤ limit).
- `clear()` drops both stacks and keeps `_state` (and `_next`).
- `canUndo`, `canRedo`, `undoDepth` and `limit` are unchanged.
- Removed (P-2): `push`, `takeUndo`, `pushRedo`, `takeRedo`, `pushUndoOnly`.

`CommandDispatcher`:
- `int get stateId => _history.state`. The dartdoc follows spec D3:
  - the id is opaque, and only equality within one dispatcher means anything;
  - execute gives a never-used id, and undo/redo return to the recorded id;
  - ids are never reused, and states lost to eviction or a cleared redo stack are never reached again;
  - a failed undo/redo leaves the id unchanged;
  - `clearHistory`/`notifyLoaded`/`notifyPurged` keep it;
  - table edits, `DraftDocument.purge` and the handle seed do not move it, so equal ids do not mean byte-equal documents.
- `execute` calls `recordExecute`.
- `undo` and `redo` are now take (`begin*`) → `_require` + `apply` → `commit*`, or `abort*` then rethrow on any throw. The `DocChange`s, their order and the `onAfterMutate` placement are unchanged. The comment in `undo()`'s catch was reworded to match: the entry now stays in place instead of being restored.

## Tests (`test/document/undo_state_test.dart`, 10 cases, all green)

Fixture: a real `DraftDocument.empty` with two lines well off the origin, (1250.5,-730.25)-(1810,-415.75) and (-2230,940.5)-(-1675.25,1320). The fixture's own adds are cleared from history. Every edit is a `SetEntityGeometryCommand` writing coordinates no earlier edit wrote, so content equality holds exactly when two states are the same state.

1. **L76 `execute, undo and redo move the id and return it exactly`**
   - s0, s1 and s2 are distinct.
   - undo→s1→s0, then redo→s1→s2, then a second full round over re-recorded entries.
   - Content is checked at each step.
2. **L115 `an edit then an undo reads the pre-edit id`**: the spec's own rule as its own case.
3. **L127 `an edit after an undo never returns to the undone id`**
   - edit, undo, then a new edit: the new id is neither s1 nor s0, and canRedo is false.
   - An undo afterwards returns to s0.
4. **L144 `a long walk …`**: a differential test against the document content instead of a second model of the stack.
   - Setup: `undoLimit: 7`, `Random(0x12a)`, 600 steps mixing edits, undos, redos and denied (readOnly) undo/redo.
   - Asserts:
     - every edit's id is unseen;
     - a denied replay leaves the id unchanged;
     - id→content and content→id are both functions, so equal ids hold exactly when content is equal.
   - Anti-degeneracy floors: edits >100, undos >50, redos >20, failures >20, an undo reaching an evicted bottom (a bottom other than the initial id) >0, and `seen.length == edits + 1`. The measured mix was 210/195/47/46/4.
5. **L206 `eviction at undoLimit: 3 never returns to an evicted state`**
   - After 5 edits the 6 ids are distinct and depth is 3.
   - Undo to the bottom: id `== ids[2]`, content `== contents[2]`, and the id is not `ids[0]` or `ids[1]`.
   - Redo x3 gives `ids[5]`.
   - Back at the bottom, a new edit's id is not in `ids`.
6. **L243 `a failed undo, then a successful one, lands on the pre-edit id`**
   - Setup: edit b → A, then edit a → B.
   - With readOnly, undo throws `PermissionDeniedError`; the id is still B, the content is still B's, canUndo is true and canRedo is false.
   - With all permissions, undo gives id `==` A with A's content; a redo then gives B.
7. **L267 `a failed redo, then a successful one, lands on the redone id`**
   - Setup: A→B, then undo to A.
   - With readOnly, redo throws; the id is still A and canRedo is true.
   - With all permissions, redo gives B with B's content; an undo then gives A.
8. **L292 group `clearing history keeps the id`**, three cases: `clearHistory`, `notifyLoaded`, and `notifyPurged` through the real `DraftDocument.purge()`.
   - Setup: 3 edits and an undo, so the redo stack is non-empty.
   - After the clear: id and content are unchanged, and canUndo and canRedo are both false.
   - A new edit's id has not been seen before, and an undo returns to the kept id.

The meaning of `undoDepth`/`canUndo`/`canRedo` is pinned by the existing tests, which stay green untouched (`command_test.dart` and the rest of the engine suite).

## Mutants

Procedure for each mutant:
- `cp undo.dart` to `…/scratchpad/p12t1-undo.dart.bak` (a second copy is `.bak2`), and check with `diff` that the two copies are identical;
- apply the mutant with a Python string replace (`p12t1-mut.py`, which asserts the target occurs exactly once);
- run `CI=true dart test test/document/undo_state_test.dart test/document/command_test.dart`;
- `cp` the backup back, then `diff` it against the file (exit 0 every time).

Red lines are the test file lines above. `command_test.dart` stayed green under every mutant.

| Mutant | Change | Red (test: line) |
|---|---|---|
| **M-12a-5** | `state => _undo.isEmpty ? 0 : identityHashCode(_undo.last.command)` | **exact-return: L97** (first redo after undo, `expect(f.id, s1)`); also walk L193, eviction L224, failed-undo L264, failed-redo L286, clear×3 L313. 8 red. |
| **M-12a-6 (a) depth** | `state => _undo.length` | **eviction: L215** (6 ids not distinct); edit-after-undo L138; walk L161; clear×3 L313. 6 red. |
| **M-12a-6 (b) eviction keeps a reachable id** | on eviction, the new bottom entry takes the evicted entry's `returnsTo` | **eviction: L224** (`expect(f.id, ids[2])`); walk L191. 2 red. |
| **M-12a-14 (undo)** | `abortUndo` restamps the top undo entry with `_state` | **failed-undo-then-undo: L261** (`expect(f.id, a)`); walk L191. 2 red. |
| **M-12a-14 (redo)** | `abortRedo` restamps the top redo entry with `_state` | **failed-redo-then-redo: L286** (`expect(f.id, b)`); walk L191. 2 red. |
| extra: clear resets `_state = 0` | in `clear()` | clear×3 L313. 3 red. |
| extra: clear resets `_next = 0` | in `clear()` | clear×3 L319; exact-return L86; edit-after-undo L139; walk L161; eviction L215. 7 red. |
| extra: `commitUndo` keeps the current id | drops `_state = entry.returnsTo` | pre-edit-id L123 (and all 10 tests red: L89, L133, L191, L224, L261, L276, L322×3). |
| extra: `commitUndo` sets a fresh id | `_state = ++_next` | pre-edit-id L123 (and all 10 red: L89, L133, L193, L224, L261, L276, L322×3). |

Every mutant went red. No survivors.

## Gates (`export PATH=/root/flutter/bin:$PATH`, `CI=true` on every command)

- **Engine** (`packages/jet_cad_2d`):
  - `dart test`: `+1105 -2: Some tests failed.` (exit 1). The baseline taken before any change was `+1095 -2`, and the +10 are the new file. The 2 failures are the standing ones, both in `test/testing/generate_document_test.dart` ("both text fractions default to zero and change nothing", "the default document is the one Plan 2 measured, byte for byte").
  - `dart analyze`: `No issues found!` (exit 0).
  - `dart format --output=none --set-exit-if-changed .`: `Formatted 159 files (0 changed)` (exit 0).
- **Render** (`packages/jet_cad_2d_flutter`):
  - `flutter test`: `+940 ~1 -7: Some tests failed.` (exit 1). The 7 are the standing ones: `text_ladder` rungs 1–5 and `text_lod_ladder` rungs 1–2. Count unchanged.
  - `flutter analyze`: `No issues found!` (exit 0).
  - `dart format`: `Formatted 177 files (0 changed)` (exit 0).
- **App** (`apps/floor_planner`):
  - `flutter test`: `+514: All tests passed!` (exit 0). Count unchanged.
  - `flutter analyze`: `No issues found!` (exit 0).
  - `dart format`: `Formatted 104 files (0 changed)` (exit 0).

Logs are in the scratchpad as `p12t1-gate-*.log` and `p12t1-<mutant>.log`.

## Deviations

- **None from the checklist.** The one choice beyond it: the entry record type is a private typedef (`_Entry`), so the only public additions are the transitions, `UndoStack.state` and `CommandDispatcher.stateId`.
- **Behaviour note, not a change in results.** During an undo or redo `apply`, the entry now stays on its stack; before, it was popped while `apply` ran.
  - Results are identical, because `apply` works on the `CommandTarget`, not the dispatcher.
  - Only a command that re-entered the dispatcher or read `undoDepth`/`canUndo` from inside its own `apply` could see the difference. None does: the engine suite and the render and app suites are green.

## Found outside scope (reported, not fixed)

- `packages/jet_cad_2d/test/document/command_test.dart:365` still has a **comment** that names the removed `pushUndoOnly` ("redo() uses pushUndoOnly rather than push"). It is only a comment, and the test's behaviour is still correct, since `commitRedo` does not clear redo. I left it because the plan says the existing undo tests stay "untouched". Task 9's grep ("UndoStack's removed primitives nowhere") will match it, so Task 9 or the reviewer should reword the comment (for example, "redo() uses commitRedo, which does not clear the redo stack").
- Docs outside the code still name the old primitives, which is expected history:
  - `docs/superpowers/plans/2026-07-27-jet-cad-2d-plan-1-core.md`;
  - `roadmap/06-parametric-layer.md:85` (`takeUndo`).

  Spec 02's history note on the API change is Task 9's (P-2).
