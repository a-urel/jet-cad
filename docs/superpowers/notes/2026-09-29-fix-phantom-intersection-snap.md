# fix/phantom-intersection-snap: intersection snaps in moved groups

**Branch:** `fix/phantom-intersection-snap`, cut at `7b6630c` (`main`,
after the Plan 11 merge).
**Source:** [the Plan 11 results note](2026-09-28-plan-11-results.md),
"Found, not fixed", item (a); the human ruled it a separate `fix/` branch
after 11 merged (2026-09-29).
**Ledger:** [`ledgers/2026-09-29-fix-phantom-intersection-snap/`](../ledgers/2026-09-29-fix-phantom-intersection-snap/).

One fix, `c7e4ac3`, and its review's fixes, `ebdf819`. Each commit had a
fresh implementer and an independent reviewer, who re-ran the gates and
re-fired the mutants in a separate, detached worktree.

## The defect

`SpatialIndex._considerIntersections` and `_collectNearSegments` read each
candidate's stored coordinates as world coordinates. A leaf of the root
container that sits inside a flattened `GroupNode` stores its coordinates in
the group's space; `ContainerIndex.transformOfLeaf(slot)` carries them to the
root's space, which is world. The leaf walk (`_descend`) composed that
transform; the intersection pass never did. The candidates were chosen
right (leaf boxes are indexed in container space); their segments were
measured and intersected in the wrong space.

After a group was moved or turned, intersection snaps appeared where no
geometry crosses, and real crossings of grouped geometry were missed. The
floor planner keeps every wall, opening, room and dimension as a root-level
group, so it reached the app through `resolveDragPoint`: the placement
tools and the select tool's drags.

## The fix

`_collectNearSegments` maps each point of each candidate once, through
`_composeLeafTransform(Transform2.identity(), root.transformOfLeaf(slot))`
(the identity is a canonical `const`), and writes each near segment's world
end points into a grow-once `Float64List` (four doubles per segment). The
pair loop reads those rows and no longer touches the payloads, so it
intersects exactly the segments the near test measured, in the space it
measured them in. Nothing is allocated per candidate or per segment.
Ungrouped input is bit-identical to before (`1·x + 0·y + 0`), and the pair
order and tie-breaks are unchanged.

In scope now: every line and polyline leaf of the root container, a
flattened group's included. An instance's contents are still never
intersection candidates.

## Why nothing caught it

The differential oracle (`test/invariants/reference_query.dart`) was already
right: it maps through `toRootSpace`. It missed the defect because the
corpus's only root-level groups held a single circle, and the snap test's
200 random points at radius 2 almost never land on a crossing. That is the
degenerate-fixture failure mode `CLAUDE.md` names. The oracle's logic is
unchanged; the corpus and the queries are what changed.

## The tests

- **The corpus:** `groupedCrossings`, whose root-level groups hold crossing
  lines and polylines under a rotation with translation, a non-uniform scale,
  a mirror, and a group nested in a group, plus ungrouped root leaves. Its
  builder asserts its own premises without the index (every pair category
  crosses in world, no crossing at a segment end, a phantom more than the
  radius from every real crossing, at least ten crossings).
- **The aimed differential test**, over every corpus document: queries at and
  around every world crossing and every phantom (the crossings of the stored
  coordinates), under three masks. Targets come from the oracle's own leaf
  list. On the unfixed engine it is red on its own (22 expected, 19 found).
- **Unit tests** (`test/index/snap_intersection_group_test.dart`, 12): a
  turned and moved group, no snap at the phantom, grouped against ungrouped,
  two groups, a polyline whose world-near segment is not its stored-near one,
  a mirrored group, a nested group, a group move and its undo, a grouped
  leaf's edit through the dirty overlay, the buffer's growth, and a one-point
  polyline among the candidates (the review's seam).
- **The allocation harness:** 24 root-level groups, every leaf transformed,
  `SnapMask.all`.
- **The app** (`apps/floor_planner/test/intersection_snap_test.dart`): the
  sample plan with P1 moved −300 mm, at a 200 mm aperture. None of the 14
  bare phantoms snaps through `resolveDragPoint`; all 13 real crossings of
  P1's moved geometry are found within 1e-6.

## A Plan 11 test changed

`AM2`'s X crossing (`dimension_attach_test.dart`, C6) asserted "none, or an
intersection exactly at `q`" at every placement. The "none" held only
because of this defect. With the fix, the snap finds the crossing at every
placement: exactly at `q` at the origin, and 1.16e-9 mm off it at the corpus
far origin turned in own groups (rounding at a magnitude of 4.5e6). The
premise is now `==` at the origin and within 1e-8 mm elsewhere (spec 11's
`AP3` bound at the same placement), with the empty candidate set checked at
`q` and at the resolved point. An X crossing still never attaches: no wall
end point is there. Spec 11 D10's amendment and its non-goal are amended.

## Mutants

Every mutant was fired as copy, mutate, run, copy back, diff.

- **The implementer's (P1):** M-P1 (the pair loop reads stored
  coordinates), M-P2 (the near filter does), M-P3 (one candidate's
  transform for all), M-P4 (a null transform turns mapping off), M-P5
  (translation dropped), M-P6 (b and c swapped), M-P7 (the inverse
  transform), M-P8 (the original file: the differential test alone is red),
  M-P9 (a `Vector2` per segment), M-P10 (growth drops the rows written; its
  test was added), M-P11 (the carried start point not advanced): all
  killed. M-P3 and M-P4 are per-query stand-ins, since the fix maps per
  candidate and has no per-pair transform.
- **The reviewer's:** R1 (the carried point half advanced), R2 (a stale
  buffer after growth), R3 (the winning slot inverted), R5 (the end marker
  dropped), R6 (the translation's x and y swapped), R7 (the mask gate
  opened): all killed. R4 (a candidate's offset written after the
  one-point guard) survived, and its test landed in `ebdf819`.
- **P1b's:** M-2a and M-2b, a 1e-7 offset on the found crossing at the
  origin only and at the far placement only: both red on the new `AM2`
  premise, both green on the 1e-5 premise it replaced.
- **Surviving:** M-P9b and M-P9c, a `Transform2` per segment or per
  candidate that never escapes. The profiler reads the baseline under both;
  evidently the JIT scalar-replaces it (inferred, not observed). The fix
  builds none.

## Known limits and debt

- **The allocation kill depends on the file's order.** A per-segment
  `Vector2` reads 0.95–5.49 per call when
  `query_allocation_test.dart` runs in order (budget 0.5; red 15 of 15, and
  red in every package-gate run the implementer and the re-review made). The
  same mutant reads the 0.014 baseline, and passes, when the case runs
  alone; evidently the JIT scalar-replaces it (inferred, not observed). A
  per-point `Transform2(…).transformPoint(Vector2(…))` was red only 12 times
  in 13 in file order. Making the case independent of the order is a harness
  question, not this fix's.
- **A NaN distance** now rejects a segment where it used to accept it. The
  difference needs non-finite coordinates.
- **Candidate selection under the cap** was checked, not changed: the index
  and the oracle box a grouped leaf the same way
  (`entityBounds(…).transformedBy(composed)`, on the build and the overlay
  routes alike). The review's probe put 130 root leaves in one query square
  (the cap is 64) and found no disagreement, fresh or after 20 overlay
  edits; the unfixed engine disagreed at all 2,401 grid points.
- **Out of scope, still open:** the other post-11 found items: 07's throw at
  turned placements, the orphan component, `wall_grips.dart`'s liveness
  filter, the palette's `drawing` flag, and a tapered piece under a scaled
  group.

## Gates (Linux container)

Branch point (`7b6630c`): engine 1,041 (+ the two standing Linux-only hash
failures in `test/testing/generate_document_test.dart`), render layer 940 +
1 skip + 7 standing goldens, harness 82, app 490.

- **engine** 1,078 + 2 standing (`ebdf819`, run by P1b and again by the
  re-review; analyze and format clean). +37: 12 unit tests, the aimed
  differential test over 20 documents, 4 differential tests for the new
  document, 1 allocation case.
- **render layer** 940 + 1 skip + 7 standing, **harness** 82 (`c7e4ac3`,
  run by P1 and the render line again by its review; nothing after it
  changes their files or the engine's code, only one engine doc comment).
- **app** 491 (`ebdf819`, P1b and the re-review; analyze and format clean),
  +1: `intersection_snap_test.dart`.
- **web** `flutter build web --release` `✓ Built` (`ebdf819`, P1b).

On the human's machine: the standing macOS lines. The fix changes no
drawing, only where an intersection snap lands. The one look worth a glance: move a wall in the sample
plan, then drag near where its faces used to cross another wall; no
intersection marker should appear there, and one should appear where they
cross now.
