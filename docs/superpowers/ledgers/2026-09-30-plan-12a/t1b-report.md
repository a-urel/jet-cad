# Task 1b report: the Task 1 review's I-1 (a fresh dispatcher's initial id)

**Commit:** `06c9c44` `test(engine): a new dispatcher's first edit leaves its initial id`
on `plan-12a/document-lifecycle`, parent `1fce8b7`. Not pushed. The commit has both trailers.
- It changes one file: `packages/jet_cad_2d/test/document/undo_state_test.dart` (+31).
- No `lib` file changed (`git diff --quiet -- lib` before the gates). No `analysis_options.yaml` was committed.
- The worktree is clean after the commit. The Task 2 review worktree was not touched.

## The case (L327, appended after the group so the earlier cases keep their line numbers)

`a new dispatcher's first edit leaves its initial id`:
- A bare `DraftDocument.empty()`, with no `Fixture` and so no history before the case.
- `initial = stateId` is read before any command. The new handle is not in the table yet.
- One `AddEntityCommand` of a line at (1250.5,-730.25)-(1810,-415.75), off the origin.
  - `edited != initial` (**L345**).
  - The coordinates are the line's.
- Undo:
  - `stateId == initial` exactly (L349);
  - the entity is gone (`slotOf` is null);
  - `canUndo` is false.
- Redo: `stateId == edited` (L354) and the coordinates are back.

Baseline: `undo_state_test.dart` + `command_test.dart` gave `+31: All tests passed!` (30 before, plus 1).

## Mutants

Procedure:
- `cp undo.dart` to `scratchpad/p12t1b-undo.dart.bak`, then `diff` (identical).
- Apply one exact-once replace with `p12t1b-mut.py`. It is `p12t1-mut.py` plus r1 and r2, and it asserts the target occurs once.
- Run `CI=true dart test test/document/undo_state_test.dart test/document/command_test.dart`.
- `cp` the backup back, then `diff`: **exit 0 for all seven**.

Driver: `p12t1b-run.sh`. Logs: `p12t1b-<mutant>.log`.

| Mutant | Change | Result | Red (test: line) |
|---|---|---|---|
| **r1** | `recordExecute`: `_state = ++_next` → `_state = _next++` | `+30 -1` | **new case L345**, `Expected: not <0> Actual: <0>` ("the first edit is a new state") |
| **r2** | `int _next = 0` → `int _next = -1` | `+30 -1` | **new case L345**, `Expected: not <0> Actual: <0>` |
| M-12a-5 | `state => _undo.isEmpty ? 0 : identityHashCode(_undo.last.command)` | `+22 -9` | exact-return L97; walk L193; eviction L224; failed-undo L264; failed-redo L286; clear×3 L313; **new case L354** (the redo id) |
| M-12a-6 (a) | `state => _undo.length` | `+25 -6` | edit-after-undo L138; walk L161; eviction L215; clear×3 L313 |
| M-12a-6 (b) | eviction hands the evicted `returnsTo` to the new bottom | `+29 -2` | walk L191; eviction L224 |
| M-12a-14 (undo) | `abortUndo` restamps the top undo entry with `_state` | `+29 -2` | walk L191; failed-undo L261 |
| M-12a-14 (redo) | `abortRedo` restamps the top redo entry with `_state` | `+29 -2` | walk L191; failed-redo L286 |

- r1 and r2 survived the review. Both are now red, and only on the new case, which shows it closes exactly that gap.
- The named mutants are red on the same tests and lines that `t1-report.md` and `t1-review.md` record.
- The one addition is that M-12a-5 also turns the new case red, at L354.
- `command_test.dart` stayed green under every mutant, as before.

## Gates (engine; `export PATH=/root/flutter/bin:$PATH`, `CI=true` on every command)

Run after the mutants were restored. Logs are `p12t1b-gate-*.log`.
- `dart test`: `+1106 -2: Some tests failed.` (exit 1).
  - That is the `+1105 -2` of `f8e296d` plus the one new case.
  - The 2 failures are the standing ones in `test/testing/generate_document_test.dart`: "the default document is the one Plan 2 measured, byte for byte" and "both text fractions default to zero and change nothing".
- `dart analyze`: `No issues found!` (exit 0).
- `dart format --output=none --set-exit-if-changed .`: `Formatted 159 files (0 changed)` (exit 0).

I did not run the render or app gates. The change is one engine test file and no `lib`.

## Deviations

None.
