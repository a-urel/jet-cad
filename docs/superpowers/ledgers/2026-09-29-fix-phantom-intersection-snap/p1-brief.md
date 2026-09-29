# P1 brief — intersection snaps map grouped segments to world

You are the implementer for fix P1 on branch `fix/phantom-intersection-snap`,
worktree `/home/user/jet-cad/.claude/worktrees/fix-phantom-snap`. Work only
there. Read `CLAUDE.md` first; its non-negotiables bind you. Commit on the
branch; do NOT push.

## The defect (post-11 found item (a))
`packages/jet_cad_2d/lib/src/index/spatial_index.dart`:
`SpatialIndex._considerIntersections` and `_collectNearSegments` read each
candidate's `payload.coords` as world coordinates. A root-container leaf that
sits inside a flattened `GroupNode` stores its coordinates in the group's
space; `ContainerIndex.transformOfLeaf(slot)` (null when identity) carries them
into the root container's space, which is world. `_descend`'s leaf walk
composes it (`_composeLeafTransform`); the intersection pass never does.

Consequences: after a group is moved or turned, intersection snaps appear where
no geometry crosses, and real crossings of grouped geometry are missed. The
candidate *selection* is already right (leaf boxes are indexed in container
space); only the segment coordinates are wrong. The floor planner stores every
wall, opening, room and dimension as a root-level group, so it reaches the app
through `resolveDragPoint` (placement tools, select-tool drags). Evidence of
record: `docs/superpowers/notes/2026-09-28-plan-11-results.md`, "Found, not
fixed" (a) — the sample plan with P1 moved −300 gave 7 distinct phantom points
at 0.05 px/mm, the worst 240 mm from any wall line.

## Why nothing caught it (read before writing tests)
The differential oracle `test/invariants/reference_query.dart`
(`_considerIntersections`) is already correct — it maps through
`toRootSpace`. It missed the defect because the corpus
(`test/invariants/corpus.dart`) puts only a circle inside its root-level groups
(`groot`, `groot2`), and `differential_test.dart`'s snap test samples 200
random points at radius 2, which almost never land on a crossing. That is the
degenerate-fixture failure mode CLAUDE.md names. Do NOT change the oracle's
logic (its independence is the point; read its header).

## Scope
1. **The fix, in the engine.** Map every candidate segment through its leaf's
   `root.transformOfLeaf(slot)` before it is measured (`_collectNearSegments`'s
   distance test) and before it is intersected (the pair loop). Transform
   first, measure second — never the other way round, as everywhere else in
   this class. Zero allocation per candidate or per segment in steady state
   (grow-once scratch, raw coefficients — see `_composeLeafTransform` and the
   `_near*` buffers' doc comments). One sound shape: have `_collectNearSegments`
   write each near segment's world endpoints into a grow-once `Float64List`
   (4 doubles per near segment), so each segment is transformed once, and have
   the pair loop read those. Your call, justified in the report.
2. **Doc comments.** `_considerIntersections`' "Root-level only" paragraph
   must say precisely what is in scope now: the root container's leaves,
   including those in flattened groups (mapped through their group transform);
   instance contents are still never candidates. Update `_collectNearSegments`'
   comment and any `kIntersectionCandidateCap` / `snapInto` sentence your
   change makes false. Do not touch comments that stay true.
3. **The differential corpus.** Add a corpus document whose root-level groups
   hold crossing lines and polylines under non-degenerate transforms: at least
   a rotation with translation, a non-uniform scale, a mirror (negative
   determinant), a group nested in a group, and a crossing between a grouped
   leaf and an ungrouped root leaf (group transform null on one side). Make the
   differential snap test **aim at crossings**: in addition to the random
   points, query points at (and within the radius of) every world crossing in
   the document, and at the phantom points (where the stored, untransformed
   coordinates cross). Derive those points independently of the index (e.g.
   from the oracle's own leaf list, or listed by hand with their arithmetic).
   Check the existing fixtures that iterate all corpus documents still pass
   (pick, band, forEachInRect, allocation, etc.).
4. **Named unit tests** (in `test/index/snap_advanced_test.dart` or a new
   `test/index/snap_intersection_group_test.dart`): at least
   - a crossing of two lines in one turned-and-moved group snaps at the
     world crossing, `kind == intersection`, point within 1e-9 of the
     hand-computed value;
   - no intersection snap at the phantom point (where the stored
     coordinates cross), with a mask of intersection only;
   - a grouped line crossing an ungrouped root line;
   - two different groups' lines crossing (different transforms per side);
   - a polyline whose world-near segment is not its stored-near segment
     (this is what distinguishes the near filter from the pair loop);
   - a mirrored group;
   - after `MoveCommand`/`TransformCommand` (whatever the engine's command for
     changing a group's transform is) and after its undo: the snap follows
     (the dirty overlay route, not only a fresh build).
5. **The allocation harness** (`test/invariants/query_allocation_test.dart`):
   if no fixture drives the intersection pass over leaves with a non-null
   leaf transform, add that case (or extend the existing `snapInto`
   `SnapMask.all` fixture) so that a per-segment allocation in the new code is
   caught. Show the mutant that proves it (M-P9 below).
6. **The app.** In `apps/floor_planner`, add one regression test that reproduces
   the reported symptom: the startup/sample plan with a wall group moved
   (the note's probe moved P1 by −300; find the probe's shape in the Plan 11
   ledger `docs/superpowers/ledgers/2026-09-28-dimensions/` if it helps), then
   every intersection snap the engine offers over a grid of query points lies
   on (within `Tolerance`) two wall lines' world geometry — or, simpler and
   equally sharp, `snapInto` with an intersection-only mask at the old phantom
   points finds nothing and at the real moved crossings finds them. Check
   `apps/floor_planner/test/dimension_attach_test.dart`'s `AM2` still passes
   (its assertion is "none, or an intersection exactly at q"); report whether
   the fix changes which branch of it holds at turned placements.

Out of scope: every other post-11 found item; `reference_query.dart`'s logic;
the render layer (`packages/jet_cad_2d_flutter`) except that its gate must
stay green.

## Mutants (the testing bar: a test lands only if a named mutant turns it red)
Procedure (binding): `cp` the file to a backup under
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/p1-`
(this prefix is yours alone), mutate, run the killing test(s), `cp` back,
`diff` the file against the backup (exit 0). NEVER `git checkout --` a .dart
file. Record for each: the mutation, the red test name and line, or "survived"
with an honest reason.
- M-P1: the pair loop reads stored coordinates (no transform), the near filter
  still maps.
- M-P2: the near filter reads stored coordinates, the pair loop maps.
- M-P3: both sides use slot A's transform.
- M-P4: a null transform on either side skips the mapping for both.
- M-P5: translation dropped (only the linear part applied).
- M-P6: the linear part transposed (b and c swapped).
- M-P7: the inverse transform applied.
- M-P8: the fix reverted entirely (the original code) — the differential test
  must be red on its own, not only the unit tests. Paste that red.
- M-P9: one `Vector2` (or `Transform2`) allocated per segment in the new
  code — the allocation harness must go red.
- Add your own where your shape has seams these do not cover.

## Gates (every task ends green)
From the worktree root, Linux container:
```sh
export PATH=/root/flutter/bin:$PATH
(cd packages/jet_cad_2d         && CI=true dart test ; CI=true dart analyze && CI=true dart format --output=none --set-exit-if-changed .)
(cd packages/jet_cad_2d_flutter && CI=true flutter test ; CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .)
(cd apps/dev_harness_2d         && CI=true flutter test --concurrency=1 && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .)
(cd apps/floor_planner          && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed . && CI=true flutter build web --release)
```
Branch-point counts (main 7b6630c): engine 1,041 + the 2 standing Linux-only
hash failures (`test/testing/generate_document_test.dart`); render 940 + 1
skip + 7 standing (the `text_ladder` / `text_lod_ladder` goldens); harness 82;
app 490. Anything else red is real. Paste each summary line and exit code.
Never synthesize output. `flutter pub get` rewrites `analysis_options.yaml`
files: never commit them (`git status` before each commit).

## Commit
One commit (or a fix commit plus a test commit if that reads better), message
in English, e.g. `fix(engine): intersection snaps map grouped segments to
world (post-11 (a))`, ending with:
```
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_013XiH3QE4FtMMNUjbASxiEv
```

## Report
Write it to `.superpowers/sdd/fix-phantom-snap/p1-report.md` in the worktree
and return it: the commit hash(es); the fix's shape and why; the red before the
fix (the new tests on the unfixed code, pasted); every mutant's outcome; the
four gate summaries with exit codes; the AM2 answer; deviations from this brief
and anything you found outside scope (reported, not fixed).
