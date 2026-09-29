# P1b brief — the P1 review's fixes

You are a fresh implementer on branch `fix/phantom-intersection-snap`, worktree
`/home/user/jet-cad/.claude/worktrees/fix-phantom-snap` (HEAD `c7e4ac3`). Work
only there. Read `CLAUDE.md`, then `.superpowers/sdd/fix-phantom-snap/p1-review.md`
(the review), then the ledger's rulings at the end of
`.superpowers/sdd/fix-phantom-snap/progress.md`. Commit; do NOT push.

## Scope (the rulings, binding)
1. **I-1** — `packages/jet_cad_2d/test/invariants/query_allocation_test.dart`,
   the `_groupedCrossingDocument` doc comment: state what the case catches as
   measured — a per-segment `Vector2` reads about 0.95–4.05 per call when the
   file runs in order (budget 0.5), and the same mutant passes when the case
   runs alone (0.014: the JIT scalar-replaces it), so the kill depends on the
   file's order. Re-measure it yourself (M-P9 in the review) and quote your own
   numbers, not the review's, if they differ. No logic change.
2. **M-1** — a unit test in
   `packages/jet_cad_2d/test/index/snap_intersection_group_test.dart`: a
   one-point root polyline, drawn last, near a grouped crossing; the snap is the
   crossing and names the later-drawn line of the crossing pair, not the
   one-point polyline. The review's probe is in
   `/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/p1r-probe_test.dart`
   ("probe R4"). Fire R4 (move `_nearSegmentStart[k] = written` after the
   `points < 2` guard in `_collectNearSegments`) and show it red.
3. **M-2** — `apps/floor_planner/test/dimension_attach_test.dart`, AM2's C6
   premise: exact `==` at the origin placement; at the other placements an
   intersection within **1e-8** of the crossing (spec 11's AP3 bound). Keep the
   checks at the resolved point. Fix the comment's "1.2e-9" to the measured
   value. Show a mutant that the exact origin clause kills and the old 1e-5
   one did not (e.g. offset the found point by 1e-7 at the origin only, if you
   can reach it cheaply; otherwise say what you fired).
4. **M-4** — `_considerIntersections`' first doc sentence: align "root-level"
   with the scope paragraph (the root container's leaves, a flattened group's
   included). Comment only.

Out of scope: spec, plan, notes, STATUS (the controller's).

Mutant procedure (binding): `cp` to a backup under
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/p1b-`
(yours alone), mutate, run, `cp` back, `diff` (exit 0). NEVER `git checkout --`
a .dart file. Prefix every test command with `CI=true`. Never synthesize
output. Never commit `analysis_options.yaml`.

## Gates
[engine] and [app] as in `p1-brief.md` (engine +1078 -2 expected after your
test; app 491). Paste summaries and exit codes.

## Commit
`test(engine): P1 review fixes -- ...` (English), ending with:
```
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_013XiH3QE4FtMMNUjbASxiEv
```

## Report
Write `.superpowers/sdd/fix-phantom-snap/p1b-report.md` and return it: hash,
what changed, mutants and their red lines, gates, deviations.
