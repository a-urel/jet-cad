# 09 — Symbol library

**Status:** not started
**Depends on:** 02, 05
**Blocks:** nothing, but 08 may depend on it — see 08's first open question
**Size:** M

---

## What this delivers

The left panel of the target screen: searchable, categorised stencils — doors
and walls, dining room, kitchen, bedroom — that are dragged onto the canvas and
become placed instances.

## Why it exists

A floor planner without furniture is a wall diagram. This is also where the
target screenshot puts most of its screen area.

## What already exists — the mechanism is complete

**This is the sub-project with the largest gap between "mechanism exists" and
"feature exists".** The engine's block system is precisely a stencil system:

- **`Definition`** — `packages/jet_cad_2d/lib/src/document/node.dart:325`.
  Carries `handle`, `name` (`:327`), **`basePoint`** (`:328`, i.e. the
  insertion point), `children` (`:335`), and `isXref` / `xrefPath` (`:340`,
  `:341`) for external references.
- **`InstanceNode`** — `node.dart:153`. Carries `definition` (`:154`), `layer`
  (`:155`), `transform` (inherited from `Node`, `:26`), and a full style
  override set: `color` (`:163`), `lineweight` (`:173`), `transparency`
  (`:177`), `linetype` (`:182`), `linetypeScale` (`:192`).
- **`SnapKind.insertion`** — `snap.dart:23`. Snapping to a block's insertion
  point already exists, and is inside `SnapMask.cheap`.
- **`DocumentTree.addNode` guards definition cycles** — an instance cannot be
  added that makes its enclosing definition reach itself (`tree.dart`).
- **`AddNodeCommand`** — `commands.dart:328`. Undoable instance placement.
- **`SpatialIndex.forEachInstanceInRect`** — `spatial_index.dart:299`.
  Instance-aware queries already exist.
- **`EntityKind.attrib`** — attribute entities, the DXF mechanism for a block
  carrying editable labels.
- The codec serializes definitions and instances already.

## What does not exist

- Any library **format** or on-disk layout.
- Any authored **content**. Not one symbol has been drawn.
- The palette UI, search, categories, thumbnails.
- Drag-and-drop from a panel onto a canvas.

## Decisions already made

1. **A library is a `DraftDocument` whose definitions are the masters.** Reuse
   the existing deterministic codec; do not invent a second format. A `.json`
   library file is a document that happens to contain only definitions.
2. **Placing a symbol is `AddNodeCommand` with an `InstanceNode`.** The
   definition is copied into the target document on first use, so the saved
   file is self-contained.
3. **Thumbnails render through the existing `DraftPainter`** into an image.
   There is no second render path and there must not be one.

## Open questions — these are the spec

- **Categories: folders or tags?** The screenshot shows collapsible groups
  ("Doors and Walls", "Dining Room", "Kitchen", "Bed Room"), which reads as one
  category per symbol — but tags scale better and search wants them.
- **Who draws the content?** This is a real question, not a technical one. Two
  hundred furniture symbols is weeks of drafting. Options: draw a minimal set
  by hand with 05's tools; import from an existing open-licensed library;
  generate parametrically. **The licence of any imported content must be
  checked before it lands in this repository.**
- **Do symbols carry components?** A parametric chair (06) placed from the
  library is a different thing from a static block. Deciding "static in v1" is
  fine.
- **Definition name collisions** when a symbol is copied into a document that
  already has a definition of that name from a different library version.
- **Does the library support `attrib`** for editable labels (a table number, a
  room name)? The engine has the entity kind; nothing uses it yet.
- **Search index** — over names only, or over tags and categories too?
- **Thumbnail caching and invalidation.**
- **Is `isXref` / `xrefPath` used** to reference a library rather than copy
  from it? It exists in the model and nothing uses it.

## Exit criteria sketch

- A library file loads and lists its definitions.
- Dragging a symbol onto the canvas creates an instance at the drop point, with
  the definition's `basePoint` at the cursor.
- Placement is one undo step; undo removes the instance and, if it was the
  first use, the copied definition too.
- Placing the same symbol twice creates **two** instances of **one**
  definition — assert the definition count.
- Save → load round-trips instances and definitions byte-identically.
- A definition copied into a document that already contains one of that name
  resolves per the documented rule.
- Thumbnails render and match the definition's geometry.

## Named mutants to fire

- **M-09a:** ignore the definition's `basePoint` when placing. Must go red —
  **impossible if every fixture definition has `basePoint` at the origin**,
  which is the obvious way to author one. Give the fixture a non-origin base
  point.
- **M-09b:** copy the definition on every placement instead of reusing it. The
  definition-count test must go red.
- **M-09c:** drop the instance transform when rendering or querying. Must go
  red — impossible at the identity transform, so place instances rotated and
  scaled.
- **M-09d:** ignore the instance's style overrides, using the definition's.
  Must go red — **impossible if the fixture's overrides equal the defaults.**
  Set a distinct colour and lineweight on the instance.
- **M-09e:** remove the definition-copy step so placement references a
  definition that is not in the document. A save-then-load test must go red.

## Traps

- **`addDefinition` and `replaceDefinition` are unguarded for cycles.** The
  doc comment in `tree.dart` states this explicitly: only `addNode` guards, and
  `replaceDefinition(def.copyWith(children: [...]))` can list an instance that
  closes a cycle with no exception raised. **A library importer must not rely
  on the tree to reject a malformed library.**
- **`childNodesOf` filters leaf handles out of `children`** — older files and
  anything read from a DXF BLOCK do name leaf handles there, and they are
  tolerated in memory but filtered wherever `children` is walked. An importer
  that writes leaf handles into `children` will appear to work and then lose
  them.
- **A definition whose `basePoint` is the origin is this feature's degenerate
  fixture.** It is also the natural thing to author.
- Draw order is ascending handle value, so a definition's internal draw order
  is fixed by its handles, not by placement.

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
