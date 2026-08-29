# jet-cad roadmap — the parametric floor planner

**Created:** 2026-08-29, on `main` at `1d71d61`.
**Target chosen by the human on 2026-08-29: option B — a parametric floor
planner.** Not a stencil diagramming tool. Walls have thickness and clean up
at their corners, openings cut the walls that host them, rooms follow the
walls that enclose them, and dimensions follow the geometry they measure.

---

## What this folder is

A **decomposition**, not a plan and not a spec. The target is far too large
for one design document, so it is broken into fourteen sub-projects, each of
which gets its **own** brainstorm → spec → plan → execution cycle under the
repo's normal SDD workflow.

Each numbered file is written to be **self-sufficient for a fresh session**.
It carries the standing repo context, what already exists with file pointers,
what is missing, the design decisions already made, the design questions still
open, a sketch of the exit criteria, and the traps specific to that area.

**A numbered file is an input to brainstorming, not an output of it.** Do not
implement from one. Read it, run `superpowers:brainstorming` on it, produce a
spec in `docs/superpowers/specs/`, then a plan, then execute.

---

## Where the project actually stands

**The engine is far more finished than the product.** An honest split:

| Layer | State |
|---|---|
| Document model, entities, blocks, layers, styles | done |
| Commands with undo/redo (10 commands) | done |
| Spatial index, hit-testing, 9 snap kinds | done |
| Deterministic versioned JSON codec | done |
| Rendering: two sinks, tile cache, text, dashes, fills | done, and over-built for this target |
| **Interaction: selection, grips, tools** | **does not exist** |
| **Any product UI at all** | **does not exist** |
| **Parametric behaviour (walls, openings, rooms, dimensions)** | **does not exist** |

`DraftCanvas` has no gesture handling of any kind — not one
`GestureDetector`. The measurement harness binds its own `Listener`. Every
pixel of product UI is unwritten.

### The render work is ahead of this target, and that is good news

Plans 3d through 3i fought for smooth pan and zoom at **500,000 entities**. A
floor plan is **500 to 5,000**. The repo's own measurements at that scale:

- 10,000 entities, vertices sink: build 5.71 ms / raster 6.68 ms
- a 10,000-entity frame at `DASHED=0`: 9.5 ms, inside the 16.67 ms budget

So at floor-plan scale, direct drawing already holds 60 fps and **the tile
cache is not needed**. Plan 3i's blurry-zoom problem is a 500,000-entity
problem. Smooth pan and zoom, the human's stated UX requirement, is a solved
problem at this target's scale — the sub-projects below should default tiles
**off** and turn them on only if a measurement says otherwise.

The answer to "if C# can do this, Flutter should too" is yes, and the evidence
is already in this repository. The engine is not the risk. The risk is the
three unwritten layers.

---

## The architectural keystone

The engine's own doc comment on `Component` states the doctrine this whole
roadmap is built on:

> *"Data only, never behavior. Behavior lives in application-side systems, so
> that the document stays serializable, deterministic and undoable."*
> — `packages/jet_cad_2d/lib/src/document/component.dart:12`

Therefore: **a wall is not a new `EntityKind`.**

A parametric object is a `GroupNode` holding ordinary core entities (lines,
arcs, fills) that were **generated** from parameters carried in a `Component`
on that group's handle. An application-side regeneration system recomputes the
geometry when the parameters or the object's neighbours change.

What this buys, for free and unchanged:

- rendering — the generated geometry is ordinary geometry
- the spatial index, hit-testing and snapping — likewise
- undo/redo — regeneration is expressed as existing commands
- save/load — the codec already persists components, and **preserves unknown
  component types verbatim** (`component.dart:66`), so forward compatibility
  is already handled
- permissions — `Capability.components` is already distinct from
  `Capability.geometry` (`command.dart:16-27`)

What must be built to make it work is in **`06-parametric-layer.md`**, and it
is the riskiest file in this folder. Read it before committing to the order.

---

## The sub-projects

| # | File | Depends on | Size |
|---|---|---|---|
| 01 | `01-app-skeleton.md` — the product app exists and pans and zooms | — | S |
| 02 | `02-interaction-core.md` — selection, hover, rubber band, tool state machine | 01 | L |
| 03 | `03-grips-and-transform.md` — grips, move/rotate/scale, snapping while dragging | 02 | M |
| 04 | `04-page-grid-rulers.md` — paper, grid, rulers, page breaks, background | 01 | M |
| 05 | `05-drawing-tools.md` — line, polyline, rectangle, circle, arc, text | 02, 03 | M |
| 06 | `06-parametric-layer.md` — **the keystone**: components + regeneration + compound undo | 02 | L |
| 07 | `07-walls.md` — thickness, justification, corner cleanup at L/T/X junctions | 06 | L |
| 08 | `08-openings.md` — doors and windows that cut their host wall | 07 | M |
| 09 | `09-symbol-library.md` — the stencil palette, drag to place | 02, 05 | M |
| 10 | `10-rooms-and-area.md` — closed wall loops become named rooms with area | 07 | M |
| 11 | `11-dimensions.md` — associative dimensions | 06, 03 | M |
| 12 | `12-app-shell.md` — menus, property panel, layer panel, file open/save | 02, 04, 05 | L |
| 13 | `13-export-and-print.md` — PDF, PNG, print | 04 | M |

### Dependency graph

```
01 app skeleton
├── 04 page/grid/rulers ──────────────── 13 export/print
└── 02 interaction core
    ├── 03 grips/transform ── 05 drawing tools ── 09 symbol library
    ├── 06 parametric layer  (KEYSTONE)
    │   ├── 07 walls
    │   │   ├── 08 openings
    │   │   └── 10 rooms/area
    │   └── 11 dimensions
    └── 12 app shell
```

### Recommended order

`01 → 02 → 04 → 03 → 05 → 06 → 07 → 08 → 10 → 09 → 11 → 12 → 13`

Reasoning:

- **01 first** because everything needs somewhere to land, and it is small.
- **02 before everything else of substance** because selection is what every
  later tool is built on.
- **04 early** because it is independent, small, and it is half of what the
  target screen looks like — an early visible win.
- **06 is the risk, and it is deliberately not first.** It cannot be evaluated
  without a way to create and select objects. But see the warning below.
- **09 after 08** because openings host symbols, so the library's requirements
  are only fully known once openings exist.
- **12 late** because a shell built before the things it wraps is written
  twice. Each earlier sub-project adds its own thin UI affordance to the 01
  skeleton; 12 is the consolidation, not the first appearance of chrome.

### A warning about 06

**Consider a throwaway spike before writing 06's spec.** Build one trivial
parametric object end to end — a rectangle with `width` and `height`
parameters — and drive it through parameter edit, undo, redo, save, load and
regenerate. Three things will be under test that nothing in this repo has ever
exercised: compound undo (which does not exist), regeneration determinism, and
re-entrancy against `QueryReentrancyError`. Learning that from a spike is
cheap; learning it from a half-executed Plan is not.

---

## Status

| # | Sub-project | Spec | Plan | Executed |
|---|---|---|---|---|
| 01 | app skeleton | — | — | — |
| 02 | interaction core | — | — | — |
| 03 | grips and transform | — | — | — |
| 04 | page, grid, rulers | — | — | — |
| 05 | drawing tools | — | — | — |
| 06 | parametric layer | — | — | — |
| 07 | walls | — | — | — |
| 08 | openings | — | — | — |
| 09 | symbol library | — | — | — |
| 10 | rooms and area | — | — | — |
| 11 | dimensions | — | — | — |
| 12 | app shell | — | — | — |
| 13 | export and print | — | — | — |

**Nothing has started.** Update this table as specs and plans land; `STATUS.md`
at the repo root stays the authority on what is in flight.

---

## References

### `flutter_diagram_editor` (Arokip) — MIT, ~143 stars

<https://github.com/Arokip/flutter_diagram_editor>

**Not a foundation. A reference for sub-project 02 only, and a good one.**

**Why it cannot be the base.** It renders each node as a **widget** through a
`componentBuilder` callback. This repository's entire render line — the
columnar geometry store, the `DrawSink` seam, the vertices sink, the
per-entity zero-allocation invariant, the tile cache — exists specifically to
avoid one object per entity; `EntityRecord`'s own doc comment
(`entity_store.dart:23`) says so in as many words. Its data model is
`ComponentData` (position, size, z-order) plus `LinkData` edges, which cannot
express an arc with a lineweight on a layer, let alone a block instance. Its
z-order is mutable (`bringToFront`, `sendToBack`) where **draw order here is
ascending handle value and is a non-negotiable**. It has no undo, no snapping,
and no tolerance model. The whole links-and-edges half has no counterpart in a
floor plan.

**What is worth reading, and where it applies:**

| What | Relevant to |
|---|---|
| The gesture split — canvas vs. component vs. per-element callbacks | **02** — the tool state machine's shape, its hardest open question |
| `ComponentHighlightPainter` | **02** — the overlay-painter decision, made there as decision 3 |
| Scale bounds, default `0.2–5.0` | **01** — the open question on zoom limits; a real-world answer to steal |
| `GridPainter` | **04** — grid rendering |
| Controller as a `Listenable` + `ListenableBuilder` | already congruent — `CameraController extends ValueNotifier` and `DocChangeNotifier extends ChangeNotifier` here |
| Typed generic payloads via `JsonCodec` | contrast with **06** — the `Component` registry solves the same problem with value equality and fixed key order, which this package does not require |

MIT, so borrowing code is permitted with attribution. Borrow interaction
patterns; do not borrow the rendering or the data model.

---

## Standing context — every session needs this

**Repo:** `/Users/ahmeturel/Projects/oss/jet-cad`, a Dart/Flutter workspace,
branch `main`.

**Read first:** `STATUS.md` (where the project stands and the exact resume
point), then `CLAUDE.md` (the non-negotiables).

**Workflow — superpowers SDD.** A design spec is approved, an implementation
plan is written from it, then the plan is executed task by task with a fresh
implementer and an independent reviewer per task.

- Specs, the binding authority: `docs/superpowers/specs/`
- Plans, what the implementer follows: `docs/superpowers/plans/`
- Measurement and mutation notes, results of record: `docs/superpowers/notes/`
- Per-task ledger while a plan is in flight: `.superpowers/sdd/<plan-slug>/`
  (git-ignored, lives in the worktree)
- The same material for a merged plan: `docs/superpowers/ledgers/`

**Packages:**

- `packages/jet_cad_2d` — the pure-Dart engine. **No Flutter, no `dart:ui`,
  ever.** Dependencies: `meta`, `vector_math`; dev: `test`, `vm_service`.
- `packages/jet_cad_2d_flutter` — the Flutter render layer. In this package
  `unused_import` and `unused_element` are **errors**, not warnings.
- `apps/dev_harness_2d` — the measurement harness. It is an instrument, not a
  product. Do not grow the product inside it.

**Non-negotiables (`CLAUDE.md`):**

- The frame path allocates **nothing per entity** in steady state, and O(1) per
  flush. Measured by
  `packages/jet_cad_2d/test/invariants/query_allocation_test.dart` and
  `packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart`.
- **Draw order is ascending handle value**, stable across undo, save, load and
  purge.
- Geometric **decisions** use `Tolerance`; **stored value** comparisons are
  exact `==`.
- **Never commit `analysis_options.yaml`** — `flutter pub get` rewrites three
  of them in this workspace.
- **Never synthesize test output.** Reviewers verify claims independently; a
  fabricated transcript invalidates the task.
- Code, comments and commit messages in English.

**Every task ends green:**

```sh
cd packages/jet_cad_2d          && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd packages/jet_cad_2d_flutter  && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

**Prefix test commands with `CI=true`.** Otherwise Dart's analytics
phone-home blocks the runner for minutes at roughly zero CPU.

**Never `git checkout` a file to revert a mutation.** Copy the file aside with
`cp`, mutate, restore from the copy, and `diff` to verify. A sandbox classifier
additionally blocks `git checkout` here.

**The testing bar.** Defects in this codebase surface through **mutation
testing and differential testing**, not through reading. The dominant failure
mode is the **degenerate fixture** — a test that passes because every fixture
sits at the identity transform, the origin, or a default attribute. A new test
is only worth landing if a **named mutation** makes it go red. This repository
has caught, repeatedly, instruments that could not fail; assume yours is one
until a mutant proves otherwise.

**Known carried failure, not a regression:**
`dart run benchmark/query_throughput.dart` has one failing row, `snap at dirty
threshold`, carried forward from Plan 2.
