# 04 — Page, grid and rulers

**Status:** not started
**Depends on:** 01
**Blocks:** 13
**Size:** M

---

## What this delivers

The paper the drawing sits on: page size (Letter, A4, …), orientation, page
break lines, background colour. The two ruler bars along the top and left with
the current units. An adaptive grid. Snap-to-grid.

## Why it exists

It is roughly half of what the target screen looks like, it is independent of
every other sub-project except the app itself, and it is small. Early visible
progress with no coupling cost.

It also has to exist before export (13) can mean anything: "print this" is
undefined without a page.

## What already exists

- `DraftCanvas.pixelsPerPaperMm` —
  `packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart:115` — and
  `lineweightScale` at `:119`. **Lineweight is already paper-based**:
  `lineweightHundredths / 100 * pixelsPerPaperMm * lineweightScale`, with no
  camera scale term, so plotted line widths are already correct in principle.
- `Component` and `ComponentRegistry` —
  `packages/jet_cad_2d/lib/src/document/component.dart` — the mechanism for
  attaching page settings to the document.
- `SetComponentCommand<T>` — `commands.dart:400` — an undoable component edit.
- `extents.dart` — document extents, for zoom-to-fit.
- `ViewportTransform` and `CameraController.zoomAt` — for ruler tick placement
  and for fitting the page to the window.

## What does not exist

- Any page or sheet concept, in the engine or the render layer.
- Any grid, in any form.
- Any ruler.
- Any unit system. The engine's coordinates are bare doubles with no declared
  unit anywhere.

## Decisions already made

1. **Page settings are document data and must be saved**, so they live in a
   `Component` on the document root handle, registered by the application via
   `ComponentRegistry.register`. Not a field on `DraftDocument` — that would be
   an engine change and a codec schema bump for what is application data.
2. **The grid and the rulers are view chrome, not entities.** They are drawn
   outside the cached document canvas and never enter the entity store. If they
   were entities they would enter the R-tree, take part in draw order, be
   selectable, be saved, and be picked by every query — four kinds of wrong.
3. **Page breaks are chrome too**, drawn from the page component, not stored as
   geometry.

## Open questions — answer these in the spec

- **The unit system.** This is the biggest question in this file and it leaks
  into 07, 10, 11 and 13. The target screenshot shows Letter (inches) as the
  page and `12 x 12` (feet) as room dimensions. Options: model in millimetres
  and display in the user's unit; model in the display unit; model unitless
  with a document-level scale. **Recommendation: model in millimetres,
  display-convert.** `pixelsPerPaperMm` already assumes millimetres on the
  render side, so anything else creates two conventions.
- **Ruler origin.** The page corner or the world origin? They differ as soon as
  the drawing is not placed at the page corner.
- **Grid subdivision rule.** How the grid picks its spacing as the camera
  zooms, and when it draws minor lines. Note `camera_controller.dart:19-31`
  already contains a power-of-two span quantiser -- read it before writing
  another. `flutter_diagram_editor`'s `GridPainter` (MIT,
  <https://github.com/Arokip/flutter_diagram_editor>) is a short worked example
  worth reading first.
- **Single page or multiple.** The screenshot has a "Page Breaks" checkbox,
  which implies a drawing larger than one sheet tiled across several. Deciding
  "single page" now is fine; deciding it implicitly is not.
- **Is the grid snappable, and does grid snap combine with the entity snapping
  of 03 or override it?**
- **Where does the background colour live** — the page component, or app
  preferences? It is on the page settings panel in the target, which argues for
  the component.

## Exit criteria sketch

- Page size and orientation are set, saved, reloaded and round-trip
  byte-identically through the codec.
- Changing page size is one undo step and restores exactly.
- Rulers show correct positions at a camera that is both zoomed and panned —
  not at the identity.
- The grid's spacing changes at documented zoom thresholds and never draws more
  than a bounded number of lines per frame.
- The grid and rulers add **zero** entities to the document — assert the entity
  count is unchanged after they are turned on.
- `query_allocation_test.dart` and `paint_allocation_test.dart` still pass.

## Named mutants to fire

- **M-04a:** drop the camera translation from ruler tick placement. Must go red
  — **cannot be caught with the camera at the origin.**
- **M-04b:** drop the camera scale from ruler tick spacing. Must go red —
  **cannot be caught at scale 1.0.**
- **M-04c:** remove the grid's spacing quantiser so spacing is continuous. A
  test asserting a bounded line count at extreme zoom-out must go red.
- **M-04d:** omit the page component from the codec's registered types. The
  round-trip test must go red. **Note:** it may *not* go red, because unknown
  component types are preserved verbatim (`component.dart:66`) — verify which,
  and if the round-trip survives, the test must assert the *typed* value came
  back, not the bytes.
- **M-04e:** swap portrait and landscape. Must go red — impossible on a square
  page, so do not use one.

## Traps

- **`component.dart:66` preserves unknown component types verbatim.** A codec
  round-trip test can therefore pass even when the component type was never
  registered. Assert the deserialized value is the typed object, not just that
  the bytes survived.
- Anything drawn into the document canvas participates in the tile cache and
  the frame-path allocation invariant. Chrome must be drawn outside it.
- `pixelsPerPaperMm` already means millimetres. A different model unit creates
  two conventions and a conversion nobody will remember.

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
