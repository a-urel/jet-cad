# Final whole-branch review brief — plan 12a (the document lifecycle)

You are the independent final reviewer of plan 12a, branch
`plan-12a/document-lifecycle`. Review in the detached worktree
`/home/user/jet-cad/.claude/worktrees/plan-12a-review` (HEAD `da20206`).
Scope: `cac7765..da20206` (the spec and plan commits `2be9233`, `d499615`
and every task since). Do not commit, do not push; do not touch the branch
worktree `/home/user/jet-cad/.claude/worktrees/plan-12a` except to write
your review into its `.superpowers/sdd/plan-12a/final-review.md`.

Read `CLAUDE.md`; the spec `docs/superpowers/specs/2026-09-30-document-lifecycle-design.md`
whole (revision 4 plus its closing "Amended at execution" section); the
plan `docs/superpowers/plans/2026-09-30-document-lifecycle.md`; the ledger
`.superpowers/sdd/plan-12a/progress.md` (every ruling) and the reports and
reviews it cites; the results note `docs/superpowers/notes/2026-09-30-plan-12a-results.md`;
the edits to `STATUS.md`, `roadmap/00-README.md`, `roadmap/12-app-shell.md`
and `docs/superpowers/specs/2026-09-26-rooms-design.md` in `2d57d22`.
Nothing a report or review says is evidence: verify it.

## What to check

1. **Task 9b (`da20206`) in full, as its task review:** `t9b-brief.md`,
   `t9b-report.md`. Re-fire its mutants A, B, C, E, F, G and add your own at
   seams they miss; measure the first-overflow width yourself (a
   temporary probe, deleted afterwards).
2. **The whole branch against the spec**, decision by decision (D1–D14,
   R-1–R-10, as amended): cross-task seams no single task review saw —
   the session/host/shell/app lifetimes across a swap; busy, settle and
   the dirty decision across New, Open, Open sample, Save, Save As, the
   replace dialog and exit; shortcuts and the toolbar under every overlay
   (the replace dialog, the error dialog, a text entry, mid-shape); web vs
   macOS code paths (conditional imports; the web build must compile the
   `_web` files).
3. **Non-negotiables:** the frame path allocates nothing per entity (the
   two invariant tests unedited and green); draw order; Tolerance vs `==`;
   no `analysis_options.yaml` committed; every commit carries the two
   trailers (`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`,
   `Claude-Session: https://claude.ai/code/session_013XiH3QE4FtMMNUjbASxiEv`);
   no model identifier anywhere in the diff or messages.
4. **Mutants:** re-fire a sample of the 32 named (M-12a-1 … 31, 7b) —
   at least 2, 10, 11, 13, 19, 24, 25, 26, 28, 29 — and add your own at
   cross-task seams. A survivor is a finding.
5. **Docs:** the results note, the spec amendment, STATUS, the roadmap
   rows faithful to the ledger and to the tree (figures re-printed by
   you: gates, mutant red lines you fired, the found-not-fixed list, the
   human's owed look — nothing ticked on the human's behalf). The results
   note's Task 9 row says "→ 9b"; say what it should read, and whether the
   note's narrow-window and mutant sections need 9b's facts.

Procedure (binding): mutants by `cp` to a backup under
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/p12rF-`,
mutate, run, `cp` back, `diff` exit 0. NEVER `git checkout --` a .dart
file. `CI=true` on every test command; `export PATH=/root/flutter/bin:$PATH`.
pub get may be needed; leave no tracked change but the known
`analysis_options.yaml` rewrites. Never synthesize output.

Gates: engine, render, app (test, analyze, format) and `flutter build web
--release`. Standing failures at the branch point: engine 2
(`generate_document_test`), render 7 (the text ladders) + 1 skip.

Write `final-review.md`: verdict (Ready to merge / Ready with fixes / Not
ready), Important and minor findings with evidence and a proposed fix,
mutants fired with red test and line, gates, and the docs corrections.
Return it.
