# Ledgers — the raw per-task record

`notes/` holds **results of record**: the conclusions, written to be read.
This directory holds the **working record they were drawn from** — the
per-task ledger, the implementer briefs, the reviewer reports, and the
`review-<from>..<to>.diff` package each review was taken against.

It exists because the SDD workflow keeps that material in
`.superpowers/sdd/<plan-slug>/`, which is **git-ignored** and lives inside a
worktree. When a plan's branch is merged and its worktree removed, everything
in it is gone — and for Plan 3c the ledger was the only place several findings
were written down at all, because TodoWrite was unavailable in the sessions
that ran it.

**Archived on merge, not maintained.** A ledger here is a snapshot of what was
true when the branch landed. Nothing appends to it afterwards; if a later plan
revisits a decision, the record of that lives in that plan's own ledger. The
live one for a plan in flight is still `.superpowers/sdd/<plan-slug>/` in its
worktree.

## What is here

| Plan | Contents |
|---|---|
| `2026-08-17-jet-cad-2d-plan-3c-text/` | Plan 3c (text), 15 tasks. `progress.md` carries **56 numbered rulings** — the decisions taken while executing, each with its cost-if-wrong — plus every task's mutation table. Beside it, task briefs, task reports, and ten review diffs. |
| `2026-08-20-jet-cad-2d-plan-3d-vertices-sink/` | Plan 3d (the vertices sink), 15 tasks. `progress.md` carries **14 rulings** and the finding from every review round — including five mutations that reviewers ran and implementers had not, each of which left a green suite hiding a real gap. Beside it, task briefs, task reports, the whole-branch fix report, and twenty-six review diffs. Its own `README.md` says what the directory holds and what was committed to the repository proper instead. |

Plans 1, 2, 3a and 3b were merged before this directory existed and their
ledger scratch was deleted; their conclusions survive in `notes/`
(`plan-3a-ledger.md` is a hand-written summary, not the raw material).
