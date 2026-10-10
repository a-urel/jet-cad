# Task 3 report: docs, results and the record

Status: DONE. Commit a39a2906 "docs: node-components results, CHANGELOG and STATUS" on fix/node-components-on-delete. 4 files; no analysis_options.yaml (git status checked before commit, clean after). Not pushed, not merged.

## Changed
- CHANGELOG.md: Unreleased carries the brief's two bullets verbatim.
- docs/superpowers/notes/2026-10-10-node-components-results.md (new): what changed, commits, tests, the seven re-pins, the rulings, M-1..M-17 table with killers and red lines, gates, what it discharges (F-14, Slice 2 note, O-8, the overstated 587-589 line per spec F-8), O-1..O-7 unchanged, "Left for the final review".
- STATUS.md: the In flight entry (plan, branch, results note, next = whole-branch review, human's look, merge on their word, ledger archived before merge).
- The spec's status line: implemented on the branch, not merged, results linked.

## Where results came from
Every gate line and mutant red line is copied from task-1-report.md (M-1..M-16, Task 1 gates, fix round 1 gates) or task-2-report.md (M-17, floor plan re-runs of M-1/M-2/M-15, Task 2 gates, TD10). Rulings from progress.md. Nothing was re-run.

## Rulings applied
M-5 = N-2, N-5; N-4 seed order; P-1..P-3 compare canon ("byte for byte, entities in handle order"); P-2 not a killer of M-12 (PG1 is); stamp order A before B.

## Concerns
- M-3: the spec lists TD7 as a killer ("review run"); no report ran it, so the table records N-2, N-5, N-6 only, with a note.
- No single all-package gate run at the final tip: Task 1 gates are at 90044db, Task 2's at 391d967 (jet_cad_2d/_flutter/_gpu untouched by Task 2; d082640 is doc-only with its own analyze/format/test lines). The whole-branch review should re-run if wanted.
- M-4's spec killer P-1 and M-1's P-2 etc. are recorded only where a report shows them.
