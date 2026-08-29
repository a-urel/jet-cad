# 03 — Grips and transform

**Status:** not started
**Depends on:** 02
**Blocks:** 05, 11
**Size:** M

---

## What this delivers

A selected object shows grips. Dragging a grip moves, rotates, scales or
reshapes it, with a live preview and with snapping active during the drag. One
undo step per completed drag.

## Why it exists

Selection without manipulation is a viewer. This is the first sub-project
where the user changes the drawing, so it is where the command, undo and snap
paths are first exercised by a human rather than a test.

## What already exists

- `TransformNodeCommand` —
  `packages/jet_cad_2d/lib/src/document/commands.dart:278`. Moves or rotates a
  `GroupNode` or `InstanceNode`.
- `SetEntityGeometryCommand` — `commands.dart:441`. Changes a leaf's
  coordinates.
- **The whole snap engine.** `SnapKind` —
  `packages/jet_cad_2d/lib/src/index/snap.dart:23` — with nine kinds:
  `endpoint, midpoint, center, quadrant, insertion, perpendicular, tangent,
  intersection, nearest`. `SnapMask` at `:37`, with `SnapMask.cheap` (`:53`,
  `endpoint..insertion`) and `SnapMask.all` (`:58`). `SnapResult` at `:77`.
  The index carries dedicated scratch vectors for snapping
  (`spatial_index.dart:416-429`) so snap queries do not allocate.
- `Transform2` — `packages/jet_cad_2d/lib/src/geometry/transform2.dart`.
- `distance.dart`, `primitives.dart`, `aabb2.dart` in `geometry/`.
- `Capability.transform` and `Capability.geometry` are already distinct
  (`command.dart:16-27`), so "may move it but may not reshape it" is already
  expressible.

## What does not exist

- Grip definition, placement or rendering.
- Any drag interaction or live preview.
- Any snap indicator UI. The engine computes snaps; nothing displays them.

## Decisions already made

1. **A live drag executes no commands.** It draws into 02's overlay. **One**
   command is dispatched on release. Two reasons, both load-bearing: the undo
   stack would otherwise take hundreds of entries per drag, and — if tiles are
   ever enabled — every intermediate frame would retire a tile generation.
2. **Moving a group or instance is `TransformNodeCommand`; moving a bare leaf
   is `SetEntityGeometryCommand`.** These are genuinely different operations
   because **leaves carry no transform** — see the doc comment at
   `command.dart:13`, which explains that this is precisely what makes the
   capability split possible.
3. **Escape cancels a drag with no document change**, restoring the pre-drag
   state from the overlay only. No command, no undo entry.

## Open questions — answer these in the spec

- **The grip set per entity kind.** Line: two endpoints and a midpoint? Circle:
  centre and four quadrants? Polyline: every vertex, plus segment midpoints for
  insertion? Arc: endpoints, midpoint, centre?
- **Rotation and scale.** Are they grips, a modal tool, or a modifier key on a
  move grip? Where does the rotation grip sit, and about what point does it
  rotate — the selection centroid, the object's base point, or a user-set base?
- **Snap priority.** When several snap candidates fall within tolerance, which
  wins? The conventional answer is a fixed precedence
  (endpoint > midpoint > intersection > center > ... > nearest), not
  nearest-distance. Decide and pin it.
- **Which `SnapMask` is live during a drag,** and whether the user can toggle
  kinds. `SnapMask.cheap` exists for a reason — measure before defaulting to
  `all`.
- **Snap marker visual language.** Square for endpoint, triangle for midpoint,
  circle for centre is the AutoCAD convention. Are markers drawn in 02's
  overlay?
- **Multi-selection drag.** One `TransformNodeCommand` per node means N undo
  entries for N objects. **This is the same problem 06 must solve** (no
  compound command exists) — either solve it here and let 06 reuse it, or
  restrict v1 to single-object drags and let 06 solve it. Decide explicitly;
  do not discover it.
- **Are the grips widgets or painted?** The 2026-08-29 widget-per-entity spike
  ([note](../docs/superpowers/notes/2026-08-29-widget-per-entity-spike.md))
  rejected one widget per *entity*, but its concession applies squarely here: a
  selection has eight to twenty grips, not five thousand, so the scale argument
  does not hold. As widgets they get hit testing, hover, cursor changes via
  `MouseRegion`, focus, keyboard and accessibility for free; in a
  `CustomPainter` every one of those is hand-written. **The recommended shape is
  hybrid** — the painted canvas with a small number of widget overlays above it
  — and this sub-project is where that is decided.
- **Ortho and polar tracking** — in v1 or not?

## Exit criteria sketch

- Dragging an endpoint grip of a line moves that endpoint and nothing else.
- One drag produces exactly one undo entry, and undo restores the pre-drag
  geometry exactly (`==`, not within tolerance — these are stored values).
- With snapping on, a drag released near an endpoint lands **exactly** on it.
- Escape mid-drag leaves the document byte-identical to before the drag.
- Dragging an instance moves the instance and leaves the definition untouched.

## Named mutants to fire

- **M-03a:** apply the drag delta in screen space without the inverse camera
  transform. Must go red — **cannot be caught at camera scale 1.0 with no
  rotation**, so the fixture's camera must be zoomed and panned.
- **M-03b:** snap to the nearest candidate by distance instead of by
  precedence. The priority test must go red.
- **M-03c:** in the drag of an instance, transform the definition's leaves
  rather than the instance node. Must go red — and it cannot be caught if the
  definition has exactly one instance, so place two.
- **M-03d:** dispatch a command per pointer-move event instead of on release.
  The one-undo-entry test must go red.
- **M-03e:** compare restored geometry within `Tolerance` instead of `==` in
  the undo assertion. The test must **still pass** — then verify with a
  deliberate 1-ulp perturbation that `==` is what the test actually enforces.

## Traps

- **Leaves carry no transform.** Moving a leaf edits its coordinates; there is
  no matrix to compose. `command.dart:13` states this as the reason the
  capability split works.
- **`Tolerance` versus `==`.** "Is the pointer near this endpoint?" is a
  geometric **decision** and uses `Tolerance`. "Did undo restore the stored
  coordinate?" is a **stored value** comparison and uses `==`. `CLAUDE.md`
  names this split as a non-negotiable.
- **The snap scratch vectors are shared and reused** (`spatial_index.dart:416`
  onward). Holding a reference to a `SnapResult`'s vector across queries reads
  a later query's data.
- **`QueryReentrancyError`** — a drag that queries for snaps must not mutate
  during the query.

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
