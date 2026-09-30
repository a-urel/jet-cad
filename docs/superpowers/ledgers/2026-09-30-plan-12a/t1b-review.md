# Task 1b review — plan 12a, the Task 1 review's I-1 (06c9c44)

Reviewer: independent. I worked in the detached worktree
`.claude/worktrees/plan-12a-review` at HEAD `06c9c44` (parent `1fce8b7`).

What I read:
- CLAUDE.md;
- `t1b-review-brief.md`, `t1b-brief.md`, `t1b-report.md`;
- `t1-review.md` (I-1 and its "To approve");
- the spec's D3 lines on fresh ids and the save point.

I verified every claim below myself. Nothing was committed or pushed. The only
tracked change left in the review worktree is the known
`packages/jet_cad/analysis_options.yaml` rewrite.

## Verdict: **Approved**

The commit adds the one case I-1 asked for, and nothing else. r1 and r2, the
two mutants that survived the Task 1 review, are now red on that case at L345.
All five named mutants are still red on the recorded tests and lines. The
engine gate is `+1106 -2`, which is Task 1's `+1105 -2` plus the one case.

**Task 1 (`f8e296d` + `06c9c44` together) can now be Approved.** The code was
already correct, and I-1 was the only Important finding. It is closed. The
minors m-1 to m-3 need no action in Task 1: m-1 is ruled to Task 9, and m-2
and m-3 are notes.

## Scope and conformance

- `git show --stat 06c9c44`: one file,
  `packages/jet_cad_2d/test/document/undo_state_test.dart`, +31.
  - `git diff f8e296d 06c9c44 -- packages/jet_cad_2d` shows only that file, so
    no engine `lib` file changed since Task 1.
  - Task 2's `1fce8b7`, which sits between them, touches no engine file.
- No `analysis_options.yaml` was committed.
- The commit message is the one the brief gives, with both trailers.
- The case is appended after the last group and starts at L327, so the
  earlier cases keep their line numbers. This matches the report.
- It is the case I-1 specified:
  1. It starts from a bare `DraftDocument.empty()`, with no `Fixture` and so no
     history.
  2. It reads `initial = stateId` before any command.
  3. It asserts the new handle has no slot yet.
  4. It runs one `AddEntityCommand` of an off-origin line
     (1250.5,-730.25)-(1810,-415.75).
  5. It asserts `edited != initial` (L345, with a reason) and checks the
     coordinates.
  6. On undo it asserts `stateId == initial` exactly (L349), that the slot is
     gone and that `canUndo` is false.
  7. On redo it asserts `stateId == edited` (L354) and checks the coordinates
     again.
- This matches spec D3: "fresh id" on execute, "never reused", and undo and
  redo restore the recorded id. It also covers the D5 use of the initial id as
  the save point of a new document.
- The fixture is not degenerate:
  - the coordinates are off-origin and non-integer;
  - it uses a real `DraftDocument`, not a fake;
  - it asserts content as well as ids.

## Mutants fired

Procedure for every mutant:
1. `cp undo.dart` to `scratchpad/p12r1b-undo.dart.bak`, then `diff` to
   confirm the copy.
2. Apply one exact-once replace with `p12r1b-mut.py`, which asserts the target
   occurs exactly once.
3. Run `CI=true dart test test/document/undo_state_test.dart test/document/command_test.dart`.
4. `cp` the backup back and `diff`. **The diff exited 0 after all 13 mutants.**

The driver is `p12r1b-run.sh` and the logs are `p12r1b-<mutant>.log`. Before
mutating, the baseline was `+31: All tests passed!`. `command_test.dart` stayed
green under every mutant.

| Mutant | Change | Result | Red (test: line) |
|---|---|---|---|
| **r1** | `recordExecute`: `_state = ++_next` → `_state = _next++` | `+30 -1` | **new case L345**, `Expected: not <0> Actual: <0>`, reason "the first edit is a new state" |
| **r2** | `int _next = 0` → `int _next = -1` | `+30 -1` | **new case L345**, `Expected: not <0> Actual: <0>` |
| M-12a-5 | `state => _undo.isEmpty ? 0 : identityHashCode(_undo.last.command)` | `+22 -9` | L97, L193, L224, L264, L286, L313 ×3, **new case L354** |
| M-12a-6 (a) | `state => _undo.length` | `+25 -6` | L138, L161, L215, L313 ×3 |
| M-12a-6 (b) | eviction hands the evicted `returnsTo` to the new bottom | `+29 -2` | L191, L224 |
| M-12a-14 (undo) | `abortUndo` restamps the top undo entry with `_state` | `+29 -2` | L191, L261 |
| M-12a-14 (redo) | `abortRedo` restamps the top redo entry with `_state` | `+29 -2` | L191, L286 |
| q1 (reviewer) | `int _state = 0` → `int _state = 1`, so the initial id collides with the first fresh id | `+30 -1` | **new case L345 only**, `Expected: not <1> Actual: <1>`. It is a third form of I-1's gap, and it would have survived before this commit. |
| q2 (reviewer) | `recordExecute` keeps `_state` when the undo depth becomes 1 | `+23 -8` | L86, L138, L161, L215, L319 ×3, new case L345 |
| q3 (reviewer) | `commitUndo` sets `_state = 0` when the undo stack empties | `+24 -7` | L92, L133, L193, L224, L322 ×3 |
| q4 (reviewer) | `commitRedo` moves to `_next` instead of `entry.returnsTo` | `+29 -2` | L97, L191 |
| q5 (reviewer) | `recordExecute` records `returnsTo: _next` instead of `_state` | `+26 -5` | L141, L191, L322 ×3 |
| q6 (reviewer) | `commitUndo` keeps `_state` when the undo stack empties | `+23 -8` | L92, L133, L191, L224, L322 ×3, **new case L349** (`Expected: <0> Actual: <1>`) |

What the table shows:
- The report's mutant table is reproduced exactly: the same counts, and the
  same tests and lines.
- Each of the new case's three id assertions is load-bearing against a
  different mutant:
  - **L345**: r1, r2 and q1. For all three it is the **only** red test in the
    two files. Without this case they would survive.
  - **L349**: q6.
  - **L354**: M-12a-5.
- q3 is not caught by the new case. A fresh document's initial id is 0, so
  "reset to 0 on empty" is equivalent there. The existing fixture cases,
  which start at id 1, catch it. This is not a gap.

## Findings

### Important

None.

### Minor

None that need action.

- **n-1 (note):** q1 shows the new case also pins the initial `_state`
  against the fresh-id sequence, and not only `_next`. This is worth a line in
  the ledger next to r1 and r2. No test change is needed.

## Gates (run by me; `export PATH=/root/flutter/bin:$PATH`; `CI=true` on every command)

I ran the gates after all mutants were restored. At that point
`git diff --quiet -- lib` was clean. The logs are
`scratchpad/p12r1b-gate-*.log`.

- **Engine** (`packages/jet_cad_2d`):
  - `dart test` → `+1106 -2: Some tests failed.` (exit 1).
    - The 2 failures are the standing ones in
      `test/testing/generate_document_test.dart`: "the default document is the
      one Plan 2 measured, byte for byte" and "both text fractions default to
      zero and change nothing".
    - `+1106` is Task 1's `+1105` plus the one new case.
  - `dart analyze` → `No issues found!` (exit 0).
  - `dart format --output=none --set-exit-if-changed .` →
    `Formatted 159 files (0 changed)` (exit 0).
- **Render and app: not re-run.**
  - `06c9c44` changes only an engine test file.
  - `git diff f8e296d 06c9c44 -- packages/jet_cad_2d` shows no `lib` change,
    so neither package can see this commit.
  - The Task 1 review's render and app gates therefore still stand for the
    engine.
  - The render change in `1fce8b7` belongs to the separate Task 2 review.
