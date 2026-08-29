# 11 — Dimensions

**Status:** not started
**Depends on:** 06, 03
**Blocks:** nothing
**Size:** M

---

## What this delivers

Associative dimensions: a measurement annotation that **follows the geometry
it measures**. Move the wall, the number changes.

## Why it exists

It is the difference between a drawing and a document someone can build from,
and associativity is why it belongs to the parametric half of the roadmap
rather than to the drawing tools.

## What already exists

- 06's mechanism. A dimension is a parametric object whose dependency edge
  points at what it measures.
- Text, fully wired by Plan 3c — the dimension value is an ordinary text
  entity, laid out once at `kNominalTextPixels` with every attribute as a
  transform.
- `EntityKind.line`, `polyline`, `fill` — extension lines, the dimension line,
  and arrowheads.
- `distance.dart`, `primitives.dart` — the measurement itself.
- `HitPath.chain` — the reference mechanism, see the first open question.
- `OriginComponent` (`origin_component.dart`) — an example of a component that
  preserves a foreign identifier; worth reading as a pattern.

## What does not exist

- Any dimension entity. **Note:** DXF has a `DIMENSION` entity; this engine
  deliberately does not, and `EntityKind` is not to grow one — see 06's
  doctrine.
- Any arrowhead geometry.
- Any dimension style.

## Decisions already made

1. **A dimension is a parametric object (06).** The component holds what is
   being measured and the style; the lines, arrows and text are generated.
2. **`EntityKind` does not grow a `dimension` kind.** Same reasoning as walls.

## Open questions — these are the spec

- **The reference model, and it is the hard problem in this file.** What does a
  dimension point *at*? A `(handle, vertex index)` pair is the obvious answer
  and it is fragile: deleting a polyline vertex silently changes what every
  later index means. Options: reference by handle plus a stable vertex
  identity; reference geometrically and re-resolve on regeneration; reference a
  wall's junction rather than a raw vertex. **Whatever is chosen, specify what
  happens when the referent is deleted.**
- **Which dimension types are in v1?** Linear, aligned, angular, radial,
  diameter, ordinate, continued and baseline are the full CAD set. Aligned plus
  linear is a defensible v1.
- **Dimension style.** Text height, arrow size and type, extension-line
  overshoot and gap, unit format and precision, whether text sits above or
  breaks the line. This is a table, and the engine already has style tables
  (`tables.dart`) — decide whether to use them or keep it in a component.
- **Arrowheads.** Filled triangles (`EntityKind.fill`), open ticks (lines), or
  architectural slashes? The architectural convention for a floor plan is the
  slash.
- **Are dimensions on a fixed layer**, so they can be hidden as a set?
- **Do rooms (10) auto-dimension?** The screenshot's `12 x 12` may be a room
  label rather than a dimension. If 10 already produces it, this sub-project is
  only about user-placed dimensions — say so.
- **Does dimension text scale with the camera or with the paper?** Paper, like
  lineweight (`pixelsPerPaperMm`), is the CAD answer, and it interacts with 04's
  unit decision.

## Exit criteria sketch

- A linear dimension between two points shows the correct distance in the
  document's unit and precision.
- Moving a referenced point updates the value and the geometry in one undo step.
- Deleting the referent produces the documented behaviour.
- An aligned dimension on a non-axis-aligned pair reads the true distance, not
  a projected one.
- Save → load → regenerate is byte-identical, with the reference intact.
- Dimension text height is correct in paper units at two different camera
  scales.

## Named mutants to fire

- **Required fixture properties:** at least one **non-axis-aligned** dimension
  — an axis-aligned one cannot distinguish linear from aligned; at least two
  different camera scales for the text-height assertion; the geometry at the
  corpus's far origin.
- **M-11a:** compute an aligned dimension as the axis-projected distance. Must
  go red — **impossible on an axis-aligned fixture.** This is this file's
  most important mutant.
- **M-11b:** scale dimension text with the camera rather than with the paper.
  The two-camera-scale test must go red.
- **M-11c:** cache the measured value in the component and never recompute it.
  The move test must go red.
- **M-11d:** resolve the referent by handle only, ignoring the vertex index.
  Must go red — **impossible if the referenced entity has only one vertex**, so
  reference a polyline vertex that is not its first.
- **M-11e:** round the displayed value with a different rule than specified
  (truncate rather than round-half-up). A test with a value at exactly `.5`
  must go red.

## Traps

- **An axis-aligned fixture cannot tell linear from aligned dimensions.** They
  produce identical numbers, and half the implementation is untested.
- **Vertex indices are not stable identities.** Any reference model built on
  raw indices will break under editing, quietly, and the failure will look like
  a rendering bug.
- **DXF text height is cap height** (`kCapHeightRatio = 0.7`), and dimension
  text is the place a 43% error looks most plausible.
- Deriving the expected distance from the same code under test is the vacuous
  gate. Put the arithmetic in the test.

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
