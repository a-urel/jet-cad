# 10 — Rooms and area

**Status:** not started
**Depends on:** 07, and 08 (a doorway must not break a room)
**Blocks:** nothing
**Size:** M

---

## What this delivers

Closed loops of walls become **rooms**: named, with a computed area, and
labelled on the drawing — the `Living Room 19 x 15` of the target screenshot.
Move a wall and the room's shape, area and label follow.

## Why it exists

Area is the number a floor plan exists to produce. It is also the clearest
demonstration that the parametric layer is real: a room is derived from walls
it does not own and cannot be drawn by hand.

## What already exists

- 06's mechanism and 07's wall graph. The wall connectivity 07 already
  maintains **is** the graph loop detection runs on; do not build a second one.
- **`AddRegionCommand.allocate`** — `commands.dart:516`. Creates a fill and its
  boundary as a pair, fill first, taking `boundaryKind`, `boundaryPayload`,
  `layer`, `fillColor`, `boundaryColor`, `fillTransparency` and
  `boundaryLineweight`. This is the room's geometry.
- `RemoveRegionCommand` — `commands.dart:664`.
- `fill_index.dart` and `triangulate.dart` — fills are already rendered and
  already hit-tested (`HitKind.fill`).
- `extents.dart`, `aabb2.dart` — bounds for label placement.
- Text is fully wired (Plan 3c) — the label is an ordinary text entity.

## What does not exist

- Loop detection over the wall graph.
- Area computation.
- Any room concept.
- Label placement logic.

## Decisions already made

1. **A room is a parametric object (06).** `RoomComponent` holds the name and
   the derived area; the fill, the boundary and the label are generated.
2. **Rooms are derived from the wall graph 07 maintains**, not from a separate
   geometric search. If 07's connectivity is right, this is a cycle search on a
   graph that already exists.
3. **The label is a generated text entity**, so it is rendered, hit-tested and
   exported by the existing paths with no new work.

## Open questions — these are the spec

- **Which boundary bounds the area?** Building convention is the **inner face**
  of the walls, not the centreline. The difference is significant and it is a
  domain decision, not a technical one — pick it deliberately and write down
  why.
- **Do doorways break a room?** They must not: a wall with an opening still
  encloses. So loop detection runs on the **wall graph**, not on the generated
  face geometry — which is another argument for decision 2.
- **What about a genuinely open plan**, where a kitchen flows into a living
  room with no wall between? Real floor planners let the user draw a "room
  separator" line. In v1 or not?
- **Rooms inside rooms** — a closet inside a bedroom. Does the bedroom's area
  subtract the closet?
- **Label placement.** The centroid fails badly for L-shaped rooms (it can land
  outside the room). The robust answer is the pole of inaccessibility — the
  centre of the largest inscribed circle. Is that worth it in v1, or is a
  user-draggable label enough?
- **Area units and display format.** The screenshot shows `19 x 15`, which is
  a bounding dimension in feet, not an area. Both? Which is the default?
- **Naming.** Auto-numbered (`Room 1`) until the user renames? Where is the
  name edited — in place, or the property panel (12)?
- **What happens when a loop opens** because a wall was deleted? Delete the
  room, or keep it and mark it invalid?

## Exit criteria sketch

- A closed rectangle of four walls produces one room with the correct area.
- An L-shaped six-wall loop produces one room with the correct area, and its
  label lands **inside** the room.
- A wall with an opening does **not** break the room.
- Moving a wall updates the room's shape, area and label in one undo step.
- Deleting a wall performs the documented behaviour for the now-open loop.
- Two adjacent rooms sharing a wall are two rooms, each with the correct area.
- Save → load → regenerate is byte-identical.

## Named mutants to fire

- **Required fixture properties:** at least one **L-shaped** (non-convex) room
  — a rectangle-only fixture cannot catch centroid or winding errors; at least
  one pair of **adjacent** rooms sharing a wall; at least one room bounded by
  a wall carrying an **opening**; walls of **differing thickness** on one room,
  so inner-face and centreline areas differ measurably; the plan at the corpus's
  far origin.
- **M-10a:** compute the area from the wall centrelines rather than the inner
  faces. Must go red — **impossible if the test's expected area was itself
  computed from centrelines**, so derive the expected value independently by
  hand and put the arithmetic in the test.
- **M-10b:** use the shoelace formula without the absolute value, so winding
  order flips the sign. Must go red — **impossible if every fixture loop is
  wound the same way.**
- **M-10c:** place the label at the bounding-box centre instead of inside the
  polygon. The L-shaped room's label-inside test must go red.
- **M-10d:** run loop detection on the generated face geometry instead of the
  wall graph. The opening test must go red.
- **M-10e:** treat a shared wall as belonging to only one of two adjacent
  rooms. The two-room test must go red.
- **M-10f:** regenerate the room but not its label. A move test must go red.

## Traps

- **A rectangular fixture is this feature's degenerate fixture** and it hides
  winding-order bugs, centroid bugs and non-convex handling all at once.
- **Deriving the expected area from the same code that computes it** is the
  vacuous-gate failure this repository has caught repeatedly. Compute it by
  hand, show the arithmetic in the test, and let a reader disagree.
- Loop detection on face geometry rather than on the wall graph looks simpler
  and breaks the moment a doorway exists.
- `AddRegionCommand` allocates **fill first**, then boundary — and draw order
  is ascending handle value, so the fill draws under its boundary by
  construction. Do not allocate them the other way round.

---

## Standing context — read before touching anything

**Repo:** `/Users/ahmeturel/Projects/oss/jet-cad`, Dart/Flutter workspace,
branch `main`. **Read `STATUS.md` first**, then `CLAUDE.md`. The full roadmap
context, the target and the dependency graph are in `roadmap/00-README.md`.

**The target:** a **parametric** floor planner. Walls have thickness and clean
up at their corners, openings cut the walls that host them, rooms follow the
walls that enclose them. Chosen by the human on 2026-08-29 over the
stencil-diagram alternative.

**This file is an input to `superpowers:brainstorming`, not a plan.** Read it,
brainstorm, write a spec into `docs/superpowers/specs/`, write a plan into
`docs/superpowers/plans/`, then execute it task by task with
`superpowers:subagent-driven-development`.

**Packages:**

- `packages/jet_cad_2d` — the pure-Dart engine. **No Flutter, no `dart:ui`,
  ever.**
- `packages/jet_cad_2d_flutter` — the Flutter render layer. Here
  `unused_import` and `unused_element` are **errors**.
- `apps/dev_harness_2d` — the measurement harness. An instrument, not a
  product; do not grow the product inside it.

**Non-negotiables (`CLAUDE.md`):**

- The frame path allocates **nothing per entity** in steady state, O(1) per
  flush. Gated by `query_allocation_test.dart` and `paint_allocation_test.dart`.
- **Draw order is ascending handle value**, stable across undo, save, load and
  purge.
- Geometric **decisions** use `Tolerance`; **stored value** comparisons are
  exact `==`.
- **Never commit `analysis_options.yaml`** — `flutter pub get` rewrites three
  of them in this workspace.
- **Never synthesize test output.**
- Code, comments and commit messages in English.

**Every task ends green:**

```sh
cd packages/jet_cad_2d          && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd packages/jet_cad_2d_flutter  && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

**Prefix test commands with `CI=true`** — otherwise Dart's analytics
phone-home blocks the runner for minutes at roughly zero CPU.

**Never `git checkout` a file to revert a mutation.** Copy aside with `cp`,
mutate, restore from the copy, `diff` to verify.

**The testing bar.** Defects here surface through **mutation and differential
testing**, not through reading. The dominant failure mode is the **degenerate
fixture** — a test that passes because every fixture sits at the identity
transform, the origin, or a default attribute. A new test is worth landing only
if a **named mutation** makes it go red. This repository has repeatedly caught
instruments that could not fail; assume yours is one until a mutant proves
otherwise.

**Scale note.** A floor plan is 500–5,000 entities, not 500,000. The repo's own
figures: a 10,000-entity frame is 9.5 ms at `DASHED=0`, and the vertices sink
draws 10,000 entities in 5.71 ms build / 6.68 ms raster. **Default the tile
cache off** (`DraftCanvas(tiles: false)`) and turn it on only if a measurement
demands it. Plan 3i's blurry-zoom behaviour is a 500,000-entity problem.
