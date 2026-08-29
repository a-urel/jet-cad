# 13 — Export and print

**Status:** not started
**Depends on:** 04 (hard — "print this" is undefined without a page)
**Blocks:** nothing
**Size:** M

---

## What this delivers

Getting the drawing out: PDF, PNG, and the system print dialog, at the page
size and orientation 04 defines, with correct plotted lineweights.

## Why it exists

A floor plan that cannot leave the application is not a deliverable.

## What already exists

- **`DraftPainter`** — `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart`.
  Draws a document to any `Canvas` through the `DrawSink` seam. Export is a
  different `Canvas`, not a different renderer.
- **`CanvasDrawSink`** — `canvas_draw_sink.dart`. The `drawPath`-based sink.
  **It is not dead code**: it is the fallback and it takes text on every frame.
- `VerticesDrawSink` — `vertices_draw_sink.dart`. The default at runtime.
- **Lineweight is already paper-based** —
  `lineweightHundredths / 100 * pixelsPerPaperMm * lineweightScale`, with no
  camera scale term. Plotted widths are correct in principle already.
- `reference_walk.dart` — an independent implementation of the walk, used as a
  differential oracle. **This is the instrument that can verify an exported
  drawing is the drawing.**
- `extents.dart` — for fit-to-page.
- The golden test suite — `flutter test --tags golden`, 35 tests. **No
  pre-existing golden PNG may be regenerated.**

## What does not exist

- Any export path, of any kind.
- Any print integration.
- Any DXF writer. `OriginComponent` (`origin_component.dart`) preserves DXF and
  IFC identifiers and `GroupNode.exportAsDxfGroup` (`node.dart:72`) exists —
  the model is prepared for a DXF writer that has never been built. There is no
  DXF **reader** either.

## Decisions already made

1. **Export uses `CanvasDrawSink`, not `VerticesDrawSink`.** Two reasons, both
   recorded in `STATUS.md`: `drawVertices` **ignores `isAntiAlias`** — there is
   no `isAntiAlias` anywhere in `vertices_draw_sink.dart` because that path
   cannot honour it, and edge quality is the surface's MSAA and nothing else —
   while Skia's `Paint.isAntiAlias` defaults to true on the canvas path. And
   the vertices sink exists to make an interactive frame fast, which an export
   is not.
2. **The tile cache is off for export.** It is a screen optimisation and its
   tile boundaries have their own open seam question (gap G1).
3. **Export renders the page, not the viewport.** The camera used for export is
   derived from the page, not from what the user is looking at.

## Open questions — these are the spec

- **Vector PDF or rasterised PDF?** Vector is the right answer for a CAD
  drawing — it stays sharp and prints at the device's resolution — and it means
  a `DrawSink` implementation that emits PDF operators rather than drawing to a
  `Canvas`. Rasterised is far less work and is a worse product. **Price both
  before choosing.**
- **Which library?** The `pdf` package, `printing`, or the platform's own
  print pipeline. A vector path constrains this choice; a raster path does not.
- **PNG resolution** — a DPI setting, or a pixel size?
- **What is exported** — the whole drawing fitted to the page, the current
  page, all pages, or a user-chosen window?
- **Are the grid and rulers exported?** They are chrome (04) and should default
  to off, but a page border and a title block may be wanted.
- **Is there a title block?** Every real CAD deliverable has one. It may be a
  block from 09 placed on the page.
- **DXF export.** The model has been carrying `OriginComponent` and
  `exportAsDxfGroup` for it. It is a substantial sub-project on its own and
  should not be smuggled in here — if it is wanted, it becomes file 14.
- **How is an export verified?** `reference_walk.dart` is the differential
  oracle for the screen path; whether it can be pointed at an export is the
  question that decides whether this sub-project has a real gate or a visual
  check.

## Exit criteria sketch

- A PDF export at a known page size contains the drawing at the correct scale,
  with lineweights measurable and correct in millimetres.
- A PNG export at a known DPI has the expected pixel dimensions.
- The exported drawing matches the on-screen drawing — verified
  differentially, not by eye, if the oracle can be pointed at it.
- Export uses `CanvasDrawSink` — assert it, do not assume it.
- The tile cache is off during export — assert it.
- Export does not mutate the document: the document is byte-identical before
  and after.
- The 35 golden tests still pass, and **no golden PNG is regenerated**.

## Named mutants to fire

- **M-13a:** export with `VerticesDrawSink`. An assertion on the sink in use
  must go red. If nothing goes red, decision 1 is unenforced.
- **M-13b:** drop `pixelsPerPaperMm` from the export transform. The
  lineweight-in-millimetres test must go red.
- **M-13c:** include the camera scale in the lineweight computation. Must go
  red — **impossible at camera scale 1.0**, so export from a zoomed camera.
- **M-13d:** export the viewport rather than the page. Must go red —
  **impossible if the fixture's viewport happens to equal its page.**
- **M-13e:** leave the tile cache on. A counter assertion must go red.

## Traps

- **`drawVertices` ignores `isAntiAlias`**, and the default runtime backend is
  `RenderBackend.vertices`. An export that silently uses the default sink
  produces aliased output on a deliverable. `STATUS.md` records this as
  established and not a defect — for the screen. For an export it is a defect.
- **No pre-existing golden PNG may be regenerated.** If an export change moves
  a golden, the change is wrong or the golden needs a human decision — not a
  regeneration.
- **Lineweight already has no camera-scale term.** Adding one "to make export
  match the screen" breaks the plotted-width property that makes lineweight
  mean anything.
- Do not smuggle DXF export in. It is its own sub-project.

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
