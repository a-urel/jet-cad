# Standing brief — every reviewer on plan-08/openings

You review in the DETACHED worktree
`/home/user/jet-cad/.claude/worktrees/plan-openings-review` (the controller
has put it at the commit under review; dependencies fetched). Work only
there; never touch `/home/user/jet-cad/.claude/worktrees/plan-openings`
(the implementers' worktree) or `/home/user/jet-cad`. No commits, no
pushes, no subagents. Leave the tree at the reviewed commit and clean
(`git status --short` empty; restore only an `analysis_options.yaml` that
`flutter pub get` dirtied).

Read `CLAUDE.md`, the plan `docs/superpowers/plans/2026-09-25-openings.md`
(header, rulings, Global Constraints, Review Focus, the task under review),
and the spec sections it cites
(`docs/superpowers/specs/2026-09-25-openings-design.md`). Verify the
implementer's claims; do not trust them.

Check at least:
1. Correctness against the spec and plan; anything missing or wrong.
2. Tests are non-degenerate (far origin, rotated groups, non-axis-aligned,
   non-central, two openings, asymmetric thickness — whatever the task's
   fixture properties require) and each owned mutant is real: re-fire the
   key ones yourself, and devise at least two of your own that the tests
   might miss.
3. Non-negotiables: pure-Dart engine; no per-entity allocation on the frame
   path; draw order ascending handle; Tolerance for decisions, `==` for
   stored values.
4. Run the gates yourself (`CI=true`; Flutter/Dart at `/root/flutter/bin`):
   engine `dart test; dart analyze && dart format --output=none --set-exit-if-changed .`
   in `packages/jet_cad_2d`; the same with flutter in
   `packages/jet_cad_2d_flutter` and `apps/floor_planner` (plus
   `flutter build web --release` in the app). Standing failures only:
   engine -2 (two hash tests), render ~1 -7 (text_ladder 1-5,
   text_lod_ladder 1-2).
5. Code reads like the surrounding code; commit message English with both
   trailers; no `analysis_options.yaml` committed.

Mutant procedure: `cp` the file to a backup under
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/plan08/`
with an `rv-` prefix, mutate, run, `cp` back, `diff` exit 0. NEVER
`git checkout --` a .dart file.

Report: verdict (Approved / Needs fixes); findings as Important / Minor
with concrete evidence (file:line, reproduction, real output copied
verbatim — never synthesize); gate lines verbatim; mutants fired with red
test and line; confirmation the tree is clean at the reviewed commit.

Scratch files: name every script, backup and log you write under the scratchpad with a prefix unique to you (e.g. `t6-` for Task 6 implementer, `rv6-` for its reviewer); never overwrite another agent's files there.
