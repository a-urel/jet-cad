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
| `2026-08-25-jet-cad-2d-plan-3h-pan-frame/` | Plan 3h (the pan frame), 8 tasks — though Task 1 was dissolved into Tasks 7 and 8, and Task 8 itself split into 8a/8b, both times because Low Power Mode blocked device work. `progress.md` carries **19 numbered rulings**, one of which (15) was later withdrawn on hard evidence and reversed by Ruling 19. Six mutants ran; two survived, one of them (M5) found by a reviewer after the plan was written and initially thought to have no unit witness until it turned out to also kill a fourth mutant (M4) the plan had asserted was unwitnessed. The headline criterion missed its gate (2.35 against 2.4) and the controller ruled the miss stands rather than move the gate. The final whole-branch review found a shipped line, `canvas.translate`, with no test witness at all; the fix wave that gave it one also found the anti-vacuity clause meant to catch that class of gap was itself measuring the wrong rectangle, recorded as gap H7. Beside `progress.md`: every task brief and report, `final-fix-report.md`, a second `record-fix-report.md` for a prose-only correction pass, and fourteen review diffs. Its own `README.md` walks the chain of rulings in full. |

| `2026-08-26-jet-cad-2d-plan-3i-zoom-frame/` | Plan 3i (the zoom frame), 14 tasks, plus eight fix waves (A–H) and a whole-branch review that ran **before** the device runs. `progress.md` carries **21 numbered rulings**. Thirty-nine mutants fired across thirty-six entries in the mutation log; thirty-seven died, and the two survivors are both deliberate — **M8** declared a survivor before it was fired, and **M24** proved unkillable because the ceiling property it targets is held by the rest bake's up-front pricing rather than by the recency stamp it deletes. Its exit gate is **9 of 11**: criteria 8 and 9 both miss and neither threshold was moved. Two of the plan's own instruments were found vacuous by firing a mutant and watching it live (`captureLive` returned the tiled image byte for byte; `pumpTiled`'s canvas was never the viewport it claimed), and Ruling 21 records a whole n=9 device run that was **taken, read and discarded** because its arms were wired around a phase the flag cannot reach — the log for it is kept. Beside `progress.md`: every task brief and report, eight fix-wave reports, fifteen review diffs, and a `measurement-logs/` directory holding the eight raw `KEEP_*.log` device transcripts behind every published figure, the discarded run included. |

Plans 1, 2, 3a and 3b were merged before this directory existed and their
ledger scratch was deleted; their conclusions survive in `notes/`
(`plan-3a-ledger.md` is a hand-written summary, not the raw material).
