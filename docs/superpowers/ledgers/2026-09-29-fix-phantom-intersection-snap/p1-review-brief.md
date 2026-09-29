# P1 review brief — independent review of c7e4ac3

You are the independent reviewer of fix P1 on `fix/phantom-intersection-snap`.
Review in the **detached** worktree
`/home/user/jet-cad/.claude/worktrees/fix-phantom-snap-review` (at `c7e4ac3`);
fire mutants only there. Do not commit, do not push. Read `CLAUDE.md` first.

Inputs:
- the implementer's brief: `/home/user/jet-cad/.claude/worktrees/fix-phantom-snap/.superpowers/sdd/fix-phantom-snap/p1-brief.md`
- the implementer's report: `/home/user/jet-cad/.claude/worktrees/fix-phantom-snap/.superpowers/sdd/fix-phantom-snap/p1-report.md`
- the diff: `git -C <review worktree> show c7e4ac3`

Claims are not evidence: verify independently. Never synthesize output.

## What to establish
1. **Correctness of the fix.** Every segment the intersection pass measures or
   intersects is in world space, for every leaf of the root container, with a
   null or non-null `transformOfLeaf`, through a fresh build and through the
   dirty overlay (`noteLeaf` updating `_leafTransforms`). Check
   `_composeLeafTransform(Transform2.identity(), …)`: is
   `Transform2.identity()` really a canonical/const instance, not a
   construction per call (read `Transform2`)? Check the pair loop's ordering
   and tie behaviour are unchanged for ungrouped input (the old tests pass, but
   read it). Check the buffer growth path copies what was written.
2. **The AM2 deviation** (`apps/floor_planner/test/dimension_attach_test.dart`,
   C6). The implementer changed a Plan 11 test's premise because the fix makes
   a real crossing appear 1.16e-9 off q at a far turned placement. Is the new
   premise ("an intersection within 1e-5 of the crossing at every placement")
   right, as sharp as the old one where it can be, and does its comment tell
   the truth? Does spec 11 (`docs/superpowers/specs/2026-09-28-dimensions-design.md`,
   the Q3c amendment near line 1170) or the plan now say something false?
   (Docs are the controller's to fix in the closing commit — report, do not
   edit.)
3. **Test sharpness.** Are the new fixtures non-degenerate (not identity, not
   origin, not symmetric linear parts where that would hide a transpose)? Does
   the aimed differential test really derive its targets independently of the
   index? Does it hold the oracle's independence (`reference_query.dart`
   unchanged)? Is the app test's world geometry derived independently of the
   engine's own composition?
4. **The open question** from the report: the oracle's candidate box is
   `entityBounds(local).transformedBy(composed)`; how does the index box a
   grouped leaf (`ContainerIndex.build`'s `addLeaf`, `noteLeaf`)? Can the two
   choose different candidates under `kIntersectionCandidateCap` (> 64
   line-like entities touching one query square)? Pre-existing or new? A probe
   settles it better than a reading.
5. **Allocation.** The frame path allocates nothing per entity. Confirm the
   new fixture actually drives transformed leaves through the pass, and weigh
   the report's M-P9b/M-P9c survivors (a non-escaping `Transform2`): is the
   stated reason plausible, and does the committed code build none?
6. **Re-fire** at least M-P1, M-P2, M-P8 and M-P9 yourself, plus at least two
   mutants of your own at seams the implementer's list does not cover (e.g.
   the `_nearSegmentStart` offsets, the carried start point at a polyline's
   second segment, the winning-slot naming, the mask gate). Procedure
   (binding): `cp` the file to a backup under
   `/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/p1r-`
   (this prefix is yours alone), mutate, run, `cp` back, `diff` (exit 0).
   NEVER `git checkout --` a .dart file.
7. **Gates.** Re-run at least [engine] and [app] (the lines are in the
   implementer's brief; `CI=true` on every test command) and report the
   summaries and exit codes. Standing failures: engine −2, render ~1 −7.

## Verdict
Write `.superpowers/sdd/fix-phantom-snap/p1-review.md` in the **branch**
worktree (`/home/user/jet-cad/.claude/worktrees/fix-phantom-snap`; that file
only) and return it: Approved / Needs fixes; Important findings (each with a
reproduction); Minor findings; what you re-fired and what went red; the gates.
