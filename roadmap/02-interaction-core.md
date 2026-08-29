# 02 — Interaction core

**Status:** not started
**Depends on:** 01
**Blocks:** 03, 05, 06, 09, 12 — everything with a user in it
**Size:** L

---

## What this delivers

Clicking an entity selects it. Clicking empty space and dragging draws a
rubber band that selects what it encloses or crosses. Hovering highlights what
would be picked. Selected and hovered things are drawn distinctly. A **tool
state machine** exists, with select as its first tool, that every later tool
plugs into.

## Why it exists

Selection is the substrate. Grips (03), every drawing tool (05), parameter
editing (06), symbol placement (09) and the property panel (12) all begin with
"what is selected". Building any of them first would mean building a private,
incompatible answer to that question.

## What already exists

- **The whole query side is done and fast.**
  `SpatialIndex.forEachInRect` —
  `packages/jet_cad_2d/lib/src/index/spatial_index.dart:271`;
  `forEachInstanceInRect` — `:299`.
- `HitPath` — `packages/jet_cad_2d/lib/src/index/hit.dart:27`. Carries a
  `Uint32List chain` (`:31`) and a `Vector2 worldPoint` (`:42`).
  `HitKind { vertex, edge, fill }` at `:11`.
- `QueryFilter` / `FilterEvaluator` —
  `packages/jet_cad_2d/lib/src/index/query_filter.dart`, reachable from the
  index at `spatial_index.dart:246`. Layer and kind filtering already exists;
  do not write a second one.
- `convenience_queries.dart` — higher-level query helpers worth reading before
  adding any.
- The **zero-allocation query invariant**, gated by
  `packages/jet_cad_2d/test/invariants/query_allocation_test.dart`.
- `QueryReentrancyError` — `spatial_index.dart:33`, with `_beginQuery` at
  `:210` and `_guardMutation` at `:183`.
- Text picks as `HitKind.fill` — established by Plan 3c, Task 6.

## What does not exist

- Any selection model, anywhere, in any package.
- Any highlight or overlay rendering. `DraftPainter` draws the document and
  nothing else.
- Any tool concept.
- Any pointer handling beyond the camera gestures 01 delivers.

## Decisions already made

1. **Selection is application state, not document state.** It is not
   undoable, not serialized, and never reaches the codec. Rationale: selection
   is not a fact about the drawing, and putting it in the document would put
   view state into a byte-deterministic format that three plans have worked to
   keep clean.
2. **Selection stores `HitPath` chains, not bare handles.** The same leaf
   handle appears under every instance of its definition; a bare handle cannot
   say *which* chair was clicked. `HitPath.chain` is exactly this
   disambiguation and it already exists.
3. **Highlight is drawn by a separate overlay painter above the document
   canvas**, not by threading a "selected" flag through `DraftPainter`'s walk.
   Rationale: the frame path's per-entity zero-allocation invariant, and the
   fact that selection changes must not invalidate the tile cache when tiles
   are on.

## Open questions — answer these in the spec

- **Pick tolerance.** A screen-pixel radius converted to world, or a world
  tolerance? Screen-pixel is what users expect (the target stays constant as
  you zoom), but it interacts with `Tolerance`'s role in geometric decisions.
- **Window versus crossing.** The CAD convention is left-to-right drag =
  window (fully enclosed only), right-to-left = crossing (anything touched).
  Recommended, but it is a product decision.
- **Groups and instances.** Does clicking inside a group select the group or
  the leaf? Is there a double-click-to-enter model? What does selecting an
  `InstanceNode` mean when the definition is shared?
- **Overlay mechanism.** A second `CustomPainter` in a `Stack` above the
  canvas, a `RepaintBoundary` sibling, or a foreground painter on the same
  `CustomPaint`? This decides whether a selection change repaints the drawing.
- **Selection filtering.** Locked layers, hidden layers (`Node.visible` at
  `node.dart:27`), and `DraftPermissions` — is a read-only document selectable?
- **The tool state machine's shape.** What a tool is, how it receives pointer
  and key events, how it is cancelled (Escape), and how it renders its own
  preview. Every one of 03, 05, 09 and 11 is a client; get the interface right
  here or pay for it five times.
  **Read `flutter_diagram_editor` (MIT,
  <https://github.com/Arokip/flutter_diagram_editor>) before answering this.**
  It solves exactly this problem and nothing else this repository needs: its
  gesture split between canvas-level, component-level and element-level
  callbacks, and its `ComponentHighlightPainter`, are the two pieces worth
  studying. **Do not take its rendering or its data model** -- it builds one
  widget per node via `componentBuilder`, which is the precise opposite of the
  columnar, no-object-per-entity decision this engine is built on
  (`entity_store.dart:23`), and its mutable z-order contradicts the
  ascending-handle draw-order non-negotiable. See the References section of
  `roadmap/00-README.md`.

## Exit criteria sketch

- Clicking an entity selects exactly it; clicking empty space clears.
- Window and crossing rubber bands select the documented sets.
- Selecting the same leaf handle under two different instances yields two
  distinct selections.
- Selection change does **not** re-walk the document (assert a paint counter,
  or assert the tile cache did not retire a generation).
- `query_allocation_test.dart` and `paint_allocation_test.dart` still pass.

## Named mutants to fire

- **M-02a:** swap the window and crossing predicates. Must go red — and it
  cannot if the fixture's rubber band fully encloses everything it touches, so
  build a fixture with one entity straddling the band edge.
- **M-02b:** drop the instance transform when resolving a `HitPath` to world
  coordinates. Must go red — **impossible to catch if every instance is at the
  identity transform**, which is this repository's signature degenerate
  fixture. Place instances at non-identity, non-origin transforms.
- **M-02c:** compare bare handles instead of `HitPath` chains for selection
  identity. The two-instances test must go red.
- **M-02d:** widen the pick tolerance by 10×. Some test must go red; if none
  does, no test constrains the tolerance at all.
- **M-02e:** make the overlay painter's `shouldRepaint` return `false`
  unconditionally. Highlight tests must go red. **Note:** `DraftCanvas`'s own
  `shouldRepaint` is unconditionally false, and Plan 3i found an instrument
  that silently compared a frame with itself because of it — verify the overlay
  actually produces a distinct element.

## Traps

- **`QueryReentrancyError`.** The document cannot be mutated during a query
  walk. Anything that reacts to a hit by editing must defer past the walk.
- **The allocation invariant.** Selection sets allocate. Keep them out of the
  frame path — build them on pointer events, read them in paint.
- **`shouldRepaint` is unconditionally false on the existing canvas painter.**
  Plan 3i's `captureLive` returned the tiled image byte for byte because of
  this, and six mutants read zero differing pixels before anyone noticed. If a
  test compares two rendered frames, force distinct elements with distinct
  `ValueKey`s.
- **`pumpWidget` gives tight constraints.** A `SizedBox` under them is inert —
  Plan 3i ran every tiled test at 800x600 instead of the 400x300 it claimed,
  for twelve tasks. If a test asserts a viewport size, assert it, do not
  assume it.

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
