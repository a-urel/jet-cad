# Plan 10, Task 14b: a doubled edge splits into a hole before the tint is cut (decision 29)

A task added during execution by the human's decision 29. It is not in the plan
file; this brief is its authority, together with the spec and the plan's global
constraints. Read the standing brief first:
`/home/user/jet-cad/.claude/worktrees/plan-rooms/.superpowers/sdd/2026-09-26-rooms/standing-brief.md`.

## The defect

When one separator (or any zero-width input) ties a freestanding island — a
column, a kitchen island — to the room's ring, the traced ring walks out along
the separator, round the island and back along the same separator. The ring then
carries a **doubled edge** (the same segment traversed in both directions). That
is structurally an exact keyhole with slit 0: the engine's triangulator refuses
it, `tintOf`/the local guard fall through D9's chain to **step 3**, and the room
shows an unfilled outline plus `room.tint`. Users hit it with a single tie from a
wall to a column, and transiently while drawing wall→column→wall.

Reviewer's minimal reproduction (Task 14 review, probe at
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/plan10/rv14_probe_test.dart`):
`boxWalls`, a freestanding column `W(5000,2000,5400,2000,400)`, a room seeded at
(2000.5, 2000.25), then a separator from (5200.5, 100) to (5200.5, 1800). Output
at origin, corpus and corpusGroups: kinds `[text, text, polyline]`, labels
`[Room 1, 29.48 m²]`, `room.tint` ("its face does not triangulate"); ring 12
points, 0 holes, one doubled edge (the separator), 2 pinches. The reviewer showed
that dropping both half-edges of the doubled edge and taking the inner loop as a
hole gives `tintOf` **step 1** with the area unchanged (29,480,000), and step 1 in
all 60 real step-3 cases of FZ1. A stub wall (with thickness) off the column
already keeps the fill. Two columns tied by a free separator give step 2.

## What to do

1. **Spec first.** Amend `docs/superpowers/specs/2026-09-26-rooms-design.md`:
   an "Amended at execution (Plan 10, decision 29)" paragraph in D9 (and D5/D6
   where they define the ring and holes) stating the rule you implement, where
   it runs (the tracer's clean-up, or in the tint builder before keyholing —
   choose, and say why), that the traced ring, its sources, area, label pole and
   D22's room.tint follow from it, and what remains for step 3. Keep the area
   exact: a doubled edge encloses zero area, so the room's area must not change.
2. **The rule.** Split every doubled edge (a segment traversed once in each
   direction by the same ring) out of the ring: remove both half-edges and turn
   the enclosed sub-loop(s) into hole(s) (or into nothing, if a sub-loop has no
   area — D6's "a component with no area is not a hole"). Handle: one tie; two
   ties to the same island (no doubled edge — must still be right); a chain of
   separators tying an island; an island tied by a separator that itself has a
   T-branch; two islands tied to each other and to the wall; a doubled edge whose
   inner loop is itself pinched. Everything in the room's seed-relative frame and
   `roomTrace` tolerance; canonical order (Ruling 10-7) must hold for the new
   holes; sources move with their edges.
   Decide deliberately whether the *traced ring* reported by the tracer changes
   (ring vs holes) or only the tint's input does, and make the label pole
   consistent with the decision (the pole should avoid the island). State it in
   the spec paragraph.
3. **Tests** (non-degenerate: all six placements where geometric; far origin,
   turned own groups):
   - the reviewer's reproduction → step 1, area 29,480,000, one hole, no
     room.tint, drift empty, the label clear of the column;
   - the transient: wall→column separator drawn (fill kept), then column→wall
     second separator (fill kept, correct holes);
   - a chain of two collinear separators tying an island; a tie with a T-branch;
     two islands tied together and to a wall;
   - LZ1-style bit-for-bit agreement between the localised and the all-inputs
     trace on these fixtures;
   - re-run Task 14's FZ1 (seed 1010) and report its new step census: step-3
     outlines should drop from 60 toward 0; report the count honestly and
     explain any that remain.
4. **Mutants** (name them X14b-…): the split disabled; only one half-edge
   removed; the inner loop dropped instead of made a hole; the hole's sources
   not carried; the split applied to non-doubled coincident edges (two different
   inputs overlapping). Each must go red on a named test; fire and restore
   (cp backup, mutate, run, cp back, diff).
5. **Gates**: engine, render, app (with `flutter build web --release`), CI=true,
   Flutter at /root/flutter/bin. Packages stay frozen — if the fix needs a
   package change, stop and report.

## Where

Worktree `/home/user/jet-cad/.claude/worktrees/plan-rooms`, branch
`plan-10/rooms`. Scratch prefix `t14b-` under the scratchpad's `plan10/`.
Commit(s) on plan-10/rooms (never push): the spec amendment may be its own
`docs(spec-10): …` commit. Report: SHAs, the rule and where it lives, the spec
paragraph, gate lines, mutants with red lines, the FZ1 census before/after.

## Carried (Task 14 re-review, m-r1)

`room_follow_test.dart` imports `expectSameTrace` from `room_localise_test.dart`;
move the helper to `test/support/` (e.g. `room_fixture.dart`) and import it from
there in both files.
