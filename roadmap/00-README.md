# jet-cad roadmap — the parametric floor planner

**Created:** 2026-08-29, on `main` at `1d71d61`.
**Last updated:** 2026-09-21, on `main` at `2bc80f6` — the GPU-resident render
line (Plans A–F) ran after this folder was written; see
[Since this folder was written](#since-this-folder-was-written-the-gpu-resident-line-plans-af).
**Target chosen by the human on 2026-08-29: option B — a parametric floor
planner.** Not a stencil diagramming tool. Walls have thickness and clean up
at their corners, openings cut the walls that host them, rooms follow the
walls that enclose them, and dimensions follow the geometry they measure.

---

## What this folder is

A **decomposition**, not a plan and not a spec. The target is far too large
for one design document, so it is broken into thirteen sub-projects, each of
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
| Rendering: three backends (`vertices` default, `canvas`, `residentGpu`), tile cache, text, dashes, fills | done, and over-built for this target |
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

### Since this folder was written: the GPU-resident line (Plans A–F)

This folder was written on 2026-08-29. Between then and 2026-09-06 the repo
executed **six of the seven plans** of the GPU-resident render backend spec,
[2026-08-29-gpu-resident-render-backend-design.md](../docs/superpowers/specs/2026-08-29-gpu-resident-render-backend-design.md),
all merged `--no-ff` into `main`: A seam and strokes (`cd5bc98`), B joins and
hairlines (`72b162d`), C dashes in the shader (`3a61b45`), D fills
(`de962bd`), E text as patches (`4921619`), F rebuild triggers and the band
(`a8208d1`). **Plan G (web) is the seventh and is unwritten.** `STATUS.md`
carries every number; this section carries only what a sub-project needs to
know.

**What exists now.** `RenderBackend` has three values
(`packages/jet_cad_2d_flutter/lib/src/render_backend.dart`): `vertices` is the
default on every platform, `canvas` is the fallback an explicit argument can
choose, and **`residentGpu`** uploads the document's geometry once, keeps the
camera as a uniform, and draws one instanced call per frame. It is **explicit
only, never a default and never automatic**; `resolveBackend` routes it back
to `vertices` where Flutter GPU is absent (web included — `flutter_gpu` cannot
compile there). `DraftCanvas(backend: RenderBackend.residentGpu)` is real
since Plan F: it collects over the document's whole extents at the live
scale, rebuilds on the spec's five triggers (document change, table revision,
device pixel ratio, band exit — **never on a pan**), and paints through the
vertices sink until the first rebuild lands or if an upload fails.

**What this changes for the sub-projects — one decision, moved to 01.** The
"tiles off" default above now has a third option. The recommendation stands:
**default `backend` unset (`vertices`) and tiles off**, and treat `residentGpu`
as a measured choice at 01's brainstorm, for three reasons that a floor
planner makes sharper than the harness did:

- **It rebuilds on every document edit.** Plan F measured `CommandApplied` at
  **26.93 ms** at 10,000 entities, and 6 of its 10 triggers over the 16.67 ms
  frame budget. A planner edits constantly; a harness pans. At 500–5,000
  entities the rebuild is unmeasured — it will be smaller, and a spec for 01
  that wants `residentGpu` owes that number.
- **The band is `[1.0, 1.0]`.** The spec's watermark band, which was to let
  a zoom drift 2× before a rebuild, measured no width at all: criterion 2
  MISSes by the spec's own design (two frozen rows — chord count and text
  culling — step at every threshold). The decision on it is the human's and
  still open; it does not block anything here.
- **It does not run on web.** If the floor planner must ship on web, Plan G
  is on the critical path and its web arm has never been run; if it must
  not, Plan G can wait behind the product work indefinitely.

**Still open on the render line, all the human's** (listed in `STATUS.md`'s
"Resume here" with the launch entries): five looks at the running window
(Plan F's four checks and Plan E's fifth), the criterion-2 design decision,
and then Plan G itself.

**The measurements above are still the right ones.** They were taken on the
`vertices` sink, which is still the default, and nothing in Plans A–F changed
that sink — `vertices_draw_sink.dart` and `canvas_draw_sink.dart` are the
oracle every GPU differential is measured against and were never edited.

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

### "Why not one widget per entity?" — asked, measured, settled

It will be asked again, so the answer is recorded rather than re-derived:
[docs/superpowers/notes/2026-08-29-widget-per-entity-spike.md](../docs/superpowers/notes/2026-08-29-widget-per-entity-spike.md).

First, the premise: **`DraftCanvas` already is a widget** —
`RepaintBoundary(child: CustomPaint(...))` — on the same pipeline and the same
Impeller as everything else. No accelerated path is being missed.

Second, the measurement, and it went **against** the prediction: at ~4,800 drawn
primitives, one render object per entity fits the frame budget comfortably, even
in Low Power Mode on battery (~6-8 ms build+raster on a pan against 16.67 ms).
Timing is not what decides this.

Third, what does decide it, none of which a number can move: the columnar store
exists to avoid exactly those objects (`entity_store.dart:23`); the spatial
index is needed anyway, so a widget tree is a second model to keep in sync; the
per-entity zero-allocation invariant dies by construction; draw order is
ascending handle value, not tree order; and the engine stays pure Dart.

**The painted-canvas architecture stays. The concession is real, though: grips
and overlay UI should be widgets** — eight to twenty of them, not five thousand,
and as widgets they get hit testing, hover, cursor and focus for free. That is an
open question in `03-grips-and-transform.md`.

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
| 01 | app skeleton | [2026-09-21](../docs/superpowers/specs/2026-09-21-floor-planner-app-skeleton-design.md) (rev 2) | [2026-09-21](../docs/superpowers/plans/2026-09-21-floor-planner-app-skeleton.md) | [2026-09-21](../docs/superpowers/notes/2026-09-21-plan-01-results.md) (merged `bae5f73`, look done: macOS, Chrome, Firefox LGTM) |
| 02 | interaction core | [2026-09-21](../docs/superpowers/specs/2026-09-21-interaction-core-design.md) (rev 2, amended at execution) | [2026-09-21](../docs/superpowers/plans/2026-09-21-interaction-core.md) | [2026-09-21](../docs/superpowers/notes/2026-09-21-plan-02-results.md) (merged `8c62db3`, 2026-09-22, gate 15/15, look done: macOS, Chrome, Firefox LGTM after the `CompoundCommand` fix) |
| 03 | grips and transform | [2026-09-23](../docs/superpowers/specs/2026-09-23-grips-and-transform-design.md) (rev 2, amended at execution) | [2026-09-23](../docs/superpowers/plans/2026-09-23-grips-and-transform.md) | [2026-09-23](../docs/superpowers/notes/2026-09-23-plan-03-results.md) (MERGED into `main` at `c5173e0`. Gate 16/16: the look was LGTM on 2026-09-23) |
| 04 | page, grid, rulers | [2026-09-22](../docs/superpowers/specs/2026-09-22-page-grid-rulers-design.md) (rev 2, amended at execution) | [2026-09-22](../docs/superpowers/plans/2026-09-22-page-grid-rulers.md) | [2026-09-22](../docs/superpowers/notes/2026-09-22-plan-04-results.md) (merged `e4e3f80`, 2026-09-22, gate 16/16, look done 2026-09-23: macOS, Chrome, Firefox LGTM) |
| 05 | drawing tools | [2026-09-23](../docs/superpowers/specs/2026-09-23-drawing-tools-design.md) (rev 2, amended at execution) | [2026-09-23](../docs/superpowers/plans/2026-09-23-drawing-tools.md) | [2026-09-23](../docs/superpowers/notes/2026-09-23-plan-05-results.md) (MERGED into `main` at `fb0f87d`. Gate 14/14: the look was LGTM on 2026-09-24, after `fix/counter-doorway`, `1a352cc`) |
| 06 | parametric layer | [2026-09-24](../docs/superpowers/specs/2026-09-24-parametric-layer-design.md) (rev 2, amended at execution) | [2026-09-24](../docs/superpowers/plans/2026-09-24-parametric-layer.md) | [2026-09-24](../docs/superpowers/notes/2026-09-24-plan-06-results.md) (MERGED at `a6837d0`; gate 13/14; look OWED) |
| 07 | walls | [2026-09-24](../docs/superpowers/specs/2026-09-24-walls-design.md) (rev 1, amended at execution) | [2026-09-24](../docs/superpowers/plans/2026-09-24-walls.md) | [2026-09-24](../docs/superpowers/notes/2026-09-24-plan-07-results.md) (merged `63c3878`; its deferred defects fixed on `fix/post-07`, merged `1ae83f9`) |
| 08 | openings | [2026-09-25](../docs/superpowers/specs/2026-09-25-openings-design.md) (rev 1, amended at execution) | [2026-09-25](../docs/superpowers/plans/2026-09-25-openings.md) | [2026-09-25](../docs/superpowers/notes/2026-09-25-plan-08-results.md) (executed on `plan-08/openings`, NOT merged; gate 15/17; macOS build and look OWED) |
| 09 | symbol library | — | — | — |
| 10 | rooms and area | — | — | — |
| 11 | dimensions | — | — | — |
| 12 | app shell | — | — | — |
| 13 | export and print | — | — | — |

**01–05 are executed, merged and looked at; 06 is merged (`a6837d0`) with its look OWED; 07 is merged (`63c3878`), with its deferred defects fixed on `fix/post-07` (`1ae83f9`); 08 is executed on `plan-08/openings` and not merged, its macOS build and look OWED**; the other five have not started. Update
this table as specs and plans land; `STATUS.md` at the repo root stays the
authority on what is in flight. The render line's own plan table lives there,
not here: six of seven merged, Plan G (web) unwritten, see the section above.

**Two lines, and the choice between them is now partly made.** Nothing on the
render line blocks 01, and 01 blocks nothing on the render line. But **the
human decided on 2026-09-21 that the product targets web**, which resolves the
one coupling in the render line's favour of urgency: **Plan G is on the
critical path.** 01's spec closes the `residentGpu` question this file left
open for its brainstorm — the product runs on the `vertices` sink, which is
already the web default, so Plan G does not block 01; it blocks ever shipping
`residentGpu` anywhere.

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
  `unused_import` and `unused_element` are **errors**, not warnings. Depends
  on `flutter_scene` **for its `flutter_gpu` shim only** (never its scene
  graph); every GPU import is confined to `lib/src/gpu/gpu_facade.dart`, the
  resident backend lives under `lib/src/gpu/`, and its shaders are
  `shaders/cad_stroke.{vert,frag}` (GLSL ES 100, at most eight attributes,
  bundled at `assets/shaders/cad.shaderbundle`).
- `apps/dev_harness_2d` — the measurement harness. It is an instrument, not a
  product. Do not grow the product inside it. Its GPU spike and its
  `BACKEND=residentGpu` main view are launch entries in `.vscode/launch.json`;
  `SPIKE_FILL_SCALE=20` is for the eye and is never used for a timing number.

**Non-negotiables (`CLAUDE.md`):**

- The frame path allocates **nothing per entity** in steady state, and O(1) per
  flush. Measured by
  `packages/jet_cad_2d/test/invariants/query_allocation_test.dart` and
  `packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart`.
- **Draw order is ascending handle value**, stable across undo, save, load and
  purge. In the resident GPU buffer that is **emission order — never sort the
  buffer**.
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
