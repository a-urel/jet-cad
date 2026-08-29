# 05 — Drawing tools

**Status:** not started
**Depends on:** 02, 03
**Blocks:** 09
**Size:** M

---

## What this delivers

Tools that create geometry: line, polyline, rectangle, circle, arc and text
placement. Each with a live rubber-band preview, snapping while placing, and
one undo step per completed entity.

## Why it exists

Walls (07) are parametric and do not go through these tools, but everything
else in a floor plan does — furniture outlines the library does not cover,
annotation leaders, site boundaries, and the symbols of 09, which have to be
**drawn** before they can be placed. Authoring the stencil content requires a
drawing tool.

## What already exists

- `AddEntityCommand` —
  `packages/jet_cad_2d/lib/src/document/commands.dart:35`. Undoable entity
  creation.
- Every entity kind: `EntityKind { point, line, polyline, circle, arc, text,
  attrib, fill }` — `packages/jet_cad_2d/lib/src/store/entity_store.dart:13`.
- `EntityRecord` — `entity_store.dart:31`. Note the doc comment at `:23`: it is
  a **view**, constructed on demand, never the stored representation.
- `GeometryPayload` and the columnar `geometry_store.dart`.
- `HandleSeed` — handle allocation; see `AddRegionCommand.allocate`
  (`commands.dart:516`) for the established allocation idiom.
- **Text is fully wired** by Plan 3c: `text_geometry.dart`, `text_metrics.dart`,
  `text_scalars.dart`, `SetEntityTextCommand` (`commands.dart:235`),
  `FlutterTextMeasurer`, and a paragraph cache. Every text attribute — height,
  rotation, width factor, oblique, justification — is a **transform** on a
  paragraph laid out once at `kNominalTextPixels = 100.0`.
- The full snap engine, described in `03-grips-and-transform.md`.
- `AddRegionCommand` (`commands.dart:506`) creates a fill plus its boundary as
  a pair — the idiom for anything closed and filled.

## What does not exist

- Any tool. Nothing in any package creates an entity from user input.

## Decisions already made

1. **Each tool is a state in 02's tool state machine**, not a separate
   interaction system. If 02's interface cannot express these six tools, 02 is
   wrong and should be fixed there, not worked around here.
2. **The preview uses 02's overlay**, the same one 03's drag preview uses. No
   entity exists until the tool completes.
3. **One `AddEntityCommand` per completed entity**, dispatched on completion.
4. **A rectangle is a closed polyline**, not a new kind. The engine's entity
   set is deliberately DXF-shaped and does not grow for convenience.

## Open questions — answer these in the spec

- **Arc input method.** Three-point, start-centre-end, start-end-radius, or
  several? Pick the minimum for v1.
- **Polyline termination.** Double-click, Enter, Escape, or clicking the start
  point? And does clicking the start point close the polyline (setting the
  closed flag) or just place a coincident vertex?
- **Text defaults.** Which text style, what height, and what justification does
  a freshly placed text get? Is height in model units or paper units?
- **Ortho and polar tracking.** Deferred from 03 — decide here at the latest,
  because a line tool without ortho is noticeably worse than one with it.
- **Does a tool stay active after completing, or revert to select?** CAD
  convention is stay-active; most consumer tools revert. This is a product
  decision.
- **Numeric entry.** Typing an exact length or angle while placing. Powerful,
  and a whole subsystem — probably not v1, but say so.
- **Which layer and style do new entities take?** A current-layer concept has
  to exist somewhere; it may belong to 12, in which case v1 hard-codes it.

## Exit criteria sketch

- Each tool creates the documented entity with the documented geometry.
- One completed entity is exactly one undo entry; undo removes it and redo
  restores it with the **same handle**.
- With snapping on, a line started near an existing endpoint begins **exactly**
  on it (`==`, a stored-value comparison).
- Escape mid-placement leaves the document byte-identical.
- A rectangle round-trips through the codec as a closed polyline.
- Placed text renders at the requested cap height, verified against
  `kCapHeightRatio`.

## Named mutants to fire

- **M-05a:** create the entity in screen coordinates without the inverse camera
  transform. Must go red — **cannot be caught at the identity camera.**
- **M-05b:** drop the closed flag on a rectangle. The round-trip test must go
  red.
- **M-05c:** treat DXF text height as em height rather than cap height (that
  is, drop `kCapHeightRatio = 0.7`). The text height test must go red.
- **M-05d:** allocate the handle before the command rather than through
  `HandleSeed`. A redo test asserting handle stability must go red.
- **M-05e:** in the arc tool, swap the start and end angles. Must go red —
  **cannot be caught by a semicircular fixture**, so use an asymmetric arc.

## Traps

- **DXF text height is cap height, not em height.** `kCapHeightRatio = 0.7`,
  and the paragraph transform's scale is `effectiveHeight / metrics.capHeight`.
  Getting this wrong produces text that is 43% too large and looks plausible.
- **The paragraph cache key is `(string, textStyle handle, ResolvedStyle.argb)`
  and carries no height, angle or width factor** — because those are transforms.
  Adding a tool that varies them does not grow the cache.
- **Draw order is ascending handle value.** A tool cannot control z-order by
  creation order alone beyond that rule.
- `EntityRecord` is a view. Do not hold one and expect it to track the store.

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
