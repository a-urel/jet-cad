# 07 — Walls

**Status:** not started
**Depends on:** 06 (hard — this is 06's first real client)
**Blocks:** 08, 10
**Size:** L

---

## What this delivers

A wall: a centreline with a thickness and a justification, drawn as two face
lines, that **cleans up automatically** where it meets other walls — mitred at
an L, butted at a T, crossed at an X. Move one wall and its neighbours' corners
follow.

## Why it exists

This is the feature that makes the target a floor planner rather than a
drawing program. It is also the reason target B was chosen over the
stencil-diagram alternative: in B, walls are objects that know about each
other.

## What already exists

- **`06-parametric-layer.md`'s whole mechanism** — components, regeneration,
  compound undo, the dependency graph. If 06 is not done, this cannot start.
- `EntityKind.polyline` and `EntityKind.line` — the generated faces.
- `EntityKind.fill` and `AddRegionCommand` (`commands.dart:506`) — if walls are
  to be drawn as filled poché rather than as two lines.
- `packages/jet_cad_2d/lib/src/geometry/`: `segment_clip.dart`,
  `distance.dart`, `primitives.dart`, `transform2.dart`, `aabb2.dart`,
  `triangulate.dart`.
- `Tolerance` — `packages/jet_cad_2d/lib/src/core/tolerance.dart`. The
  "do these two centreline endpoints coincide?" decision uses it.
- The snap engine, so the centreline is snappable once it is a real entity.
- `SpatialIndex.forEachInRect` — for finding candidate neighbours.

## What does not exist

- Any wall concept whatsoever.
- Any join or cleanup geometry.
- Any notion of connectivity between objects.

## Decisions already made

1. **A wall is a parametric object under 06**: a `GroupNode`, a
   `WallComponent` on its handle, generated children.
2. **The centreline is a real `polyline` entity inside the group, not data
   hidden in the component.** Rationale, and it is the strongest argument in
   this file: as a real entity it is snappable, pickable, indexable and
   hideable by layer **for free**, using machinery that already exists and is
   already fast. As component data, every one of those has to be reinvented.
3. **The face lines are generated and are not directly editable.** Editing the
   wall means editing the centreline or the parameters.
4. **Junction detection is geometric, cached in the component.** Walls connect
   because their centrelines touch, not because someone declared a link — which
   is how a user expects dragging one wall onto another to behave. The derived
   connectivity is cached so regeneration does not re-query the world.

## Open questions — these are the spec

- **`WallComponent`'s fields.** Thickness; justification (centre / left /
  right, i.e. which side of the centreline the wall body sits on); height (2D
  now, but a floor planner usually grows a 3D view); layer or material.
- **Wall body representation.** Two face lines, or a closed filled polyline
  (architectural poché)? The target screenshot shows walls as **solid black
  bands**, which argues for a fill. `AddRegionCommand` creates the fill and its
  boundary as a pair and is the established idiom.
- **The junction cases, each with its own geometry:**
  - **L** — two wall ends meet: mitre both faces to the angle bisector.
  - **T** — one wall's end meets another's side: butt the ending wall to the
    through wall's near face.
  - **X** — two walls cross: both continue, both sets of faces trimmed.
  - **3+ walls at one point** — what does a mitre mean? This is the case that
    breaks naive implementations. Decide it explicitly.
- **Walls of different thickness meeting.** The mitre is asymmetric and the
  bisector is no longer the answer.
- **Justification on a join.** Two walls with different justifications meeting
  at a corner do not share a centreline point in the same way.
- **Curved walls** — an arc centreline. In v1 or not? Saying "not v1" is fine;
  discovering it late is not.
- **Very short walls and very shallow angles.** A mitre at 179° runs to
  near-infinity. What is the clamp, and what happens beyond it?
- **What is the tolerance for "these endpoints coincide"?** It is a geometric
  decision, so `Tolerance` — but at what magnitude, and is it absolute or
  relative to wall thickness?
- **Drawing a wall.** Is there a wall tool (a 05-style tool that emits a
  parametric object), and does it chain — click, click, click to draw a
  connected run, as every floor planner does?

## Exit criteria sketch

- A single wall generates the documented faces for its thickness and
  justification.
- An L junction mitres; a T butts; an X crosses. Each verified geometrically,
  not by pixel comparison.
- Moving one wall of a junction regenerates its neighbours in **one** undo step.
- Deleting one wall of a junction regenerates the survivors correctly.
- Save → load → regenerate is byte-identical.
- A three-way junction produces the documented result and does not hang.
- Walls of differing thickness produce the documented asymmetric mitre.

## Named mutants to fire

**The anti-degenerate clauses here matter more than in any other file.** A
floor plan fixture built from axis-aligned walls of equal thickness at 90°
corners will pass a wall implementation that is deeply wrong.

- **Required fixture properties:** at least one junction at a **non-right,
  non-45°** angle; at least one pair of walls with **different thicknesses**;
  at least one **T** and one **X**; at least one wall with **non-centre**
  justification; the whole plan at the measurement corpus's **far origin**, not
  near `(0,0)`.
- **M-07a:** compute the mitre along the average of the two directions instead
  of the angle bisector. Must go red — **identical for perpendicular walls**,
  so a 90°-only fixture cannot kill it. This is the single most important
  mutant in this file.
- **M-07b:** use one wall's half-thickness for both sides of an asymmetric
  join. Must go red — **impossible with equal-thickness walls.**
- **M-07c:** treat every junction as an L. The T and X tests must go red.
- **M-07d:** compare centreline endpoints with `==` instead of within
  `Tolerance`. A junction test with endpoints one ulp apart must go red.
- **M-07e:** compare stored generated coordinates within `Tolerance` instead of
  `==` in the round-trip assertion. Verify with a 1-ulp perturbation that the
  test actually enforces `==`.
- **M-07f:** ignore justification, always centring the body. Must go red —
  **impossible if every fixture wall is centre-justified.**
- **M-07g:** regenerate only the moved wall, not its neighbours. Must go red —
  this is 06's M-06d arriving with real geometry.
- **M-07h:** drop the group transform when generating faces. Must go red —
  impossible at the identity transform.

## Traps

- **`Tolerance` for decisions, `==` for stored values.** "Do these endpoints
  coincide?" is a decision. "Did the round-trip preserve this coordinate?" is a
  stored value. `CLAUDE.md` names this as a non-negotiable and this file is
  where it bites hardest.
- **The 90° fixture is this feature's degenerate fixture**, and it is the
  natural one to write. Bisector and average coincide; asymmetric and symmetric
  mitres coincide; left and centre justification differ only in a direction the
  fixture never exercises. Half of a wrong implementation passes.
- **A mitre is a mutual dependency.** Wall A's corner depends on B and B's on
  A. This is 06's cycle question, and if 06 chose single-pass propagation
  rather than two-phase, it will fail here.
- **`QueryReentrancyError`** — junction detection queries the index; collect
  neighbours first, mutate after.
- **Draw order is ascending handle value.** Wall fills drawn over neighbouring
  wall fills depend on handle order, which is not the drawing order the user
  expects. If poché fills are used, this needs an answer.

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
