# Task 1 review — plan 12a, the engine's state identity (f8e296d)

Reviewer: independent, detached worktree `.claude/worktrees/plan-12a-review` at
HEAD `f8e296d` (parent `d499615`). I read CLAUDE.md, the plan (header, P-2,
global constraints, gates, Task 1, mutant table, Task 9), spec D3 with its
Testing and Named-mutant entries (M-12a-5, 6, 14), `t1-brief.md` and
`t1-report.md`. I verified every claim below myself. Nothing was committed or
pushed. The only tracked change left in the review worktree is the known
`packages/jet_cad/analysis_options.yaml` rewrite from `flutter pub get`.

## Verdict: **Needs fixes** (one Important finding, which is a test gap; the code is correct)

The implementation matches the plan and spec D3 exactly. All five named
mutants are red where the report says. The gates reproduce.

One mutant at a seam the named ones miss **survives the whole suite**: the
first `execute` on a fresh dispatcher reuses the initial id. The cause is a
degenerate fixture, the failure mode CLAUDE.md names. The fix is a single test
case (I-1).

## Scope and conformance

- The diff touches only `packages/jet_cad_2d/lib/src/document/undo.dart` and
  the new `test/document/undo_state_test.dart`, as Task 1's file list says.
  No render or app file changed, and no `analysis_options.yaml` was committed.
  The commit message is the plan's and ends with both trailers.
- Checklist against spec D3:
  - Entries are `({DraftCommand command, int returnsTo})` (a private typedef).
  - `_state` and `_next` start at 0, and `state` exists.
  - `recordExecute` pushes `(inverse, _state)`, sets `_state = ++_next`,
    evicts past `limit` and clears redo.
  - `beginUndo`/`beginRedo` do not pop.
  - `commitUndo` pops, pushes `(redoInverse, _state)` on redo and sets
    `_state = entry.returnsTo`. `commitRedo` does the symmetric thing, without
    clearing redo and without eviction.
  - `abortUndo`/`abortRedo` are explicit no-ops.
  - `clear()` keeps `_state` and `_next`.
  - The five old primitives are removed (P-2).
  - `CommandDispatcher.stateId` is there, with dartdoc covering opaque, one
    dispatcher only, never reused, and not moved by table edits, purge or the
    handle seed.
  - All conform.
- The invariant `undo + redo ≤ limit` holds:
  - `recordExecute` leaves `undo ≤ limit` with redo empty.
  - `commitUndo` and `commitRedo` each move one entry across.
  - `clear` empties both.
  - So `commitRedo` needs no eviction, as its dartdoc says. An eviction added
    there would be an equivalent mutant.
- Behaviour note in the report: the entry now stays on its stack during
  `apply`. Checked:
  - `apply` receives the `CommandTarget`, not the dispatcher.
  - The only `CommandTarget` implementations are `DraftDocument` and two test
    fakes.
  - Nothing in `packages/jet_cad_2d/lib` reaches `commands.` from inside a
    command. The `onAfterMutate`/`onBeforeMutate` placements are unchanged.
  - The DocChanges and their order are unchanged. Accepted.
- Grep for removed primitives (`push`/`takeUndo`/`takeRedo`/`pushRedo`/
  `pushUndoOnly`) across `*.dart`: only the **comment** at
  `packages/jet_cad_2d/test/document/command_test.dart:365` remains. The
  ledger already rules that Task 9 rewords it. `stateId` has no reader outside
  the new test yet.

## Findings

### Important

**I-1. A fresh dispatcher's initial id is never observed. The first edit can
reuse it and the suite stays green (surviving mutants r1 and r2).**

Every `Fixture` runs two `AddEntityCommand`s and then `clearHistory()` before
any test reads an id. The long walk and every other case start from that
post-fixture id (1 on HEAD), never from the id a `DraftDocument.empty()`
dispatcher is born with (0).

Both mutants below make the **first** `execute` on a new dispatcher land on
the initial id 0:
- **r1:** `_state = ++_next;` → `_state = _next++;` in `recordExecute`.
- **r2:** `int _next = 0;` → `int _next = -1;`.

Both leave `undo_state_test.dart` + `command_test.dart` at `+30: All tests
passed!` (logs `p12r1-r1.log`, `p12r1-r2.log`). `stateId` has no other reader,
so the full suite cannot catch them either.

Both break spec D3's "`_state` becomes a fresh id" and "ids are never reused
within a dispatcher". They also break the app's central use of the id (D2/D4):
- a new or launch document takes `stateId` as its save point;
- a mutant engine then reports the document **clean after its first edit**.

Evidence the gap is real and the fix is cheap: I added a temporary probe test
and deleted it afterwards (copy at `scratchpad/p12r1_probe_test.dart`). The
probe does this:
1. `DraftDocument.empty()`, then read `initial = stateId`.
2. One `AddEntityCommand` of a line at (1250.5,-730.25)-(1810,-415.75).
3. Expect `stateId` is not `initial`.
4. Undo, then expect `stateId == initial`.

Results:
- HEAD: `+1: All tests passed!`
- Under r1: red at `p12r1_probe_test.dart 30:5`, `Expected: not <0> Actual: <0>` (log `p12r1-probe-r1.log`).
- Under r2: red at the same line with the same values (log `p12r1-probe-r2.log`).

**Fix:** add an engine case such as *"a new dispatcher's first edit leaves its
initial id"*:
- Start from a `DraftDocument.empty()` with no fixture history.
- Read the id before any command.
- Execute one off-origin edit and assert the new id is not the initial one.
- Undo back to the initial id exactly (content too).
- Redo to the post-edit id.

An alternative is to also seed the long walk's `seen` set from a fresh
document's id before the fixture's own adds. Re-fire r1 and r2 and record the
red line. Keep the rest of the file as it is.

### Minor

- **m-1** (already ruled, recorded for completeness):
  `command_test.dart:365`'s comment names `pushUndoOnly` and `push`. Task 9
  rewords it per the ledger ruling.
- **m-2** (note, no action): `abortUndo`/`abortRedo` are no-ops by design
  (plan: "kept as an explicit call"). Deleting the calls in the dispatcher is
  an equivalent mutant. What is testable about the abort path is that the
  entry keeps its `returnsTo`, and M-12a-14 pins that.
- **m-3** (note, no action): the failure cases and the walk's failures all go
  through the permission denial, which throws before `apply`. A replay whose
  `apply` throws goes through the same `catch`. `command_test.dart`'s
  "inverse whose apply throws" tests still pin that it does not strand the
  entry (red under r8/r9 below).

## Mutants fired

Procedure for every mutant:
- `cp undo.dart` to `scratchpad/p12r1-undo.dart.bak` and check with `diff`
  that the two are identical;
- apply one exact-once string replace (`p12r1-mut.py` asserts the target
  occurs exactly once);
- run `CI=true dart test test/document/undo_state_test.dart test/document/command_test.dart`;
- `cp` the backup back and `diff` it against the file: **exit 0 every time**.

The baseline run before mutating was `+30: All tests passed!`. Line numbers
below are the first failing `expect` of each red test.

| Mutant | Change | Result (test: line) |
|---|---|---|
| **M-12a-5** | `state => _undo.isEmpty ? 0 : identityHashCode(_undo.last.command)` | **red**, 8. Exact-return **L97** (the first redo); walk L193; eviction L224; failed-undo L264; failed-redo L286; clear ×3 L313. Matches the report. |
| **M-12a-6 (a)** | `state => _undo.length` (the id from depth) | **red**, 6. Eviction **L215**; edit-after-undo L138; walk L161; clear ×3 L313. Matches. |
| **M-12a-6 (b)** | eviction hands the evicted entry's `returnsTo` to the new bottom | **red**, 2. Eviction **L224**; walk L191. Matches. |
| **M-12a-14 (undo)** | `abortUndo` restamps the top undo entry with `_state` | **red**, 2. Failed-undo-then-undo **L261**; walk L191. Matches. |
| **M-12a-14 (redo)** | `abortRedo` restamps the top redo entry with `_state` | **red**, 2. Failed-redo-then-redo **L286**; walk L191. Matches. |
| r1 (reviewer) | `recordExecute`: `_state = _next++` | **SURVIVES** (`+30`). See I-1. The probe goes red at L30. |
| r2 (reviewer) | `int _next = -1` | **SURVIVES** (`+30`). See I-1. The probe goes red at L30. |
| r3 (reviewer) | `commitRedo` also clears redo | red. Exact-return L100; eviction L232; `command_test` L378. |
| r4 (reviewer) | eviction `>` → `>=` | red. Eviction L216; `command_test` L258. |
| r5 (reviewer) | `commitUndo` records `entry.returnsTo` instead of `_state` on redo | red, 5. L97, L191, L232, L264, L286. |
| r6 (reviewer) | `commitRedo` moves to a fresh id (`++_next`) | red, 5. L97, L193, L232, L264, L286. |
| r7 (reviewer) | `recordExecute` does not clear redo | red. Edit-after-undo L137; walk L191; `command_test` L235. |
| r8 (reviewer) | the dispatcher's undo `catch` commits instead of aborting | red. Walk L185; failed-undo L254; `command_test` L301, L341. |
| r9 (reviewer) | the dispatcher's redo `catch` commits instead of aborting | red. Walk L185; failed-redo L280; `command_test` L320, L359. |

The report's claims hold:
- Every named mutant is red where it says.
- The fixture is off-origin and uses a real `DraftDocument`.
- The walk's anti-degeneracy floors assert and pass. The test itself pins
  the floors (edits >100, undos >50, redos >20, failures >20, an evicted
  bottom >0, `seen.length == edits + 1`).
- The purge case goes through the real `DraftDocument.purge()`, which calls
  `notifyPurged()` unconditionally (`draft_document.dart:209`).

## Gates (run by me, `export PATH=/root/flutter/bin:$PATH`, `CI=true` on every command)

`flutter pub get` ran first in the fresh review worktree. Logs are
`scratchpad/p12r1-gate-*.log`.

- **Engine** (`packages/jet_cad_2d`):
  - `dart test` → `+1105 -2: Some tests failed.` (exit 1). The two failures
    are the standing ones in `test/testing/generate_document_test.dart`
    ("the default document is the one Plan 2 measured, byte for byte" and
    "both text fractions default to zero and change nothing"). The count is
    the branch point's 1,095 plus the 10 new cases.
  - `dart analyze` → `No issues found!` (0).
  - `dart format` → `Formatted 159 files (0 changed)` (0).
- **Render** (`packages/jet_cad_2d_flutter`):
  - `flutter test` → `+940 ~1 -7: Some tests failed.` (exit 1). The 7 are
    exactly `text_ladder` rungs 1–5 and `text_lod_ladder` rungs 1–2. The count
    is unchanged.
  - `flutter analyze` → `No issues found!` (0).
  - `dart format` → `Formatted 177 files (0 changed)` (0).
- **App** (`apps/floor_planner`):
  - `flutter test` → `+514: All tests passed!` (0). The count is unchanged.
  - `flutter analyze` → `No issues found!` (0).
  - `dart format` → `Formatted 104 files (0 changed)` (0).

I ran the mutants only after the render and app gates had finished, so no
mutant was compiled into a gate run.

## To approve

Land I-1's case in `undo_state_test.dart`. Show r1 and r2 red with the test
and the line, and all other mutants still as recorded. Engine gate
`+1106 -2` (or +N for N new cases), with render and app unchanged.
