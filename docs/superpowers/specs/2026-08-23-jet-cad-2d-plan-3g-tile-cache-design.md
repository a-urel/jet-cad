# Plan 3g — the rasterised tile cache

**Date:** 2026-08-23
**Status:** design, approved section by section
**Measurement of record:**
[docs/superpowers/notes/2026-08-23-picture-cache-price-spike.md](../notes/2026-08-23-picture-cache-price-spike.md)
**Supersedes:** the parent architecture spec's definition/tile *picture* cache,
for the reason the spike measured.

---

## What this plan is

A screen-space, world-anchored **tile cache of rasterised `ui.Image`s**, behind
a flag, that removes the walk and the rasterisation from a pan and from a
settled frame.

## What this plan is not

- **Not a definition `Picture` cache.** The spike priced that route and it is
  mechanically fine — 702 `drawVertices` calls cost the same raster as 20 — but
  it attacks build, and every frame ever measured here is raster-bound. Its
  ceiling is a raster time already over budget.
- **Not a triangle-reduction plan.** Under a zoom gesture a tile cache buys 11%
  at 50,000 entities and 26% at 500,000, measured. Getting a zoom frame under
  budget means drawing fewer or simpler triangles, and that is **Plan 3h**.
- **Not a default flip.** The flag defaults off. Flipping it is a separate,
  measurement-backed decision, the way Plan 3d flipped the backend.

## Why, in numbers

Plan 3d's clean rows and this session's confirmation, `BACKEND=vertices`:

| corpus | build | raster | total |
|---|---|---|---|
| 50,000 | 7.46 | 8.30 | **15.04 ms** |
| 500,000 | 17.79 | 22.40 | **40.27 ms** |

Probe D, same session, same driver:

| corpus | mode | total | vs live |
|---|---|---|---|
| 50,000 | blit | **1.49 ms** | 10.1× |
| 50,000 | rebake every frame | 13.56 ms | 1.11× |
| 500,000 | blit | **1.61 ms** | 25.0× |
| 500,000 | rebake every frame | 32.06 ms | 1.26× |

The blit is **corpus-independent** — 0.86 ms of raster at 10,000 entities, 0.97
at 50,000, 0.97 at 500,000 — so the margin widens with the drawing. The rebake
column is the boundary: a tile is a **pan-and-settle** optimisation and this
plan says so out loud rather than discovering it.

---

## Decisions

### D1 — A tile is a device-resolution `ui.Image` covering a fixed world rect

Baked by running the existing `DraftPainter` into a `PictureRecorder` through
the configured sink, then `Picture.toImageSync`. The painter does not change.

### D2 — The key is `(scaleGeneration, x, y)`

A tile is `kTileDevicePixels` square. At scale `S` and device pixel ratio `dpr`
it therefore covers `kTileDevicePixels / (S · dpr)` world units, so **the world
extent of a tile is a function of the scale**. A scale change bumps the
generation and drops every tile.

This is not an extra mechanism; it is the same rule as D3, expressed in the key.

**It closes two carried traps at no cost:**

- **Trap 3** (`STATUS.md:988`, a baked picture is not scale-invariant now that
  dashes exist) needed a new invalidation axis. It does not: scale is already
  in the key, so dash phase, stroke width and the text level-of-detail decision
  all bake at the one scale they are correct for.
- **Plan 3f's unanswered question** — may a cached picture contain text at all —
  falls out of the same fact. Text was a problem for a *definition* picture
  because that picture is shared across scale bands. A tile shares nothing:
  each generation has exactly one scale. **Text goes in the tile.**

### D3 — During a zoom gesture, blit the stale generation, scaled; rebake on settle

Pixels are wrong during the gesture: stroke widths grow with the zoom
(a lineweight is a paper quantity and must not), text softens, and text the new
scale would newly reveal is absent. All of it is transient and self-correcting.

This is the standard map/CAD behaviour and it is the only option that makes zoom
*cheaper*; rebaking per frame was measured at 11–26%, which is not a win, and
drawing live leaves zoom exactly where it is today.

**It opens a correctness surface**, and D12 is what pins it.

### D4 — Scale bands are rejected

A narrow band rebakes nearly every frame — measured at 11–26%, near worthless. A
wide band shows the error the carry-forward note already characterised
([item 5](../notes/2026-08-17-carry-forward-additions.md)): a stroke-width error
of that size is invisible, a **period** error is not, because the dash period
beats against segment length and a pattern that no longer divides a wall the way
it did one band ago reads as the pattern shifting. Each end degenerates into one
of the other two options, without their clarity.

### D5 — Tiles are world-anchored on a grid, not one oversized texture

A single texture with a 1.5× margin rebakes in full when the margin is crossed:
~30 ms at 500,000 entities — two dropped frames, repeating roughly every half
viewport of travel. That lands directly on this plan's stated goal.

A grid bakes only the newly exposed strip.

**Memory is not the discriminator.** For a representative 1600×1200 logical
viewport at `dpr` 2 (3200×2400 device pixels), covering the visible set at an
arbitrary alignment needs `ceil(extent / tile) + 1` tiles per axis:

| tile | tiles | bytes | blits per frame |
|---|---|---|---|
| 128 px | 26 × 20 = 520 | 34.1 MB | 520 |
| **256 px** | 14 × 11 = 154 | **40.4 MB** | 154 |
| 512 px | 8 × 6 = 48 | 50.3 MB | 48 |
| 1024 px | 5 × 4 = 20 | 83.9 MB | 20 |
| *viewport area* | — | *30.7 MB* | — |

Larger tiles cost **more** memory, not less: the partial-coverage waste grows
with the square. 1024 px spends 2.4× what 128 px does.

### D6 — `kTileDevicePixels` starts at 256 and the plan measures it

Probe D measured **one** viewport-sized blit at 0.97 ms of raster. Whether 154
blits of 1/154 the area cost the same total, or whether per-call overhead
dominates, is **not measured**. Probe A's break at 2,507 calls was
`drawVertices`; `drawImageRect` is a different call.

A task sweeps the tile size against blit cost and reports the table. **This also
subsumes the spike's open upload-bound-versus-fill-bound question**, which
existed only because it decides tile size — the sweep answers the decision
directly instead of the mechanism behind it.

### D7 — `kTileDevicePixels` is injectable, and that is a testing requirement

Production uses 256. **Tests use 64.** The ink comparison must run in
`flutter test`, and `vertices_draw_sink.dart`'s header records that software
Skia takes minutes on a large `drawVertices`, so the fixture must stay small. A
small fixture on a small grid **crosses tile boundaries by construction** — the
degenerate-fixture failure mode is closed by the test's geometry rather than by
the author's attention.

### D8 — Tile bakes clip with `doAntiAlias: false` on the integer device-pixel grid

An entity crossing a tile boundary is drawn into both tiles and clipped. If the
clip edge is antialiased, each tile contributes partial coverage and their
`source-over` does not reach full coverage: a visible seam.

A hard clip on the pixel grid is exact for **any** content — strokes, fills and
glyphs alike — because the geometry's own rasterisation is unaffected and each
tile keeps exactly the pixels it owns.

**What can and cannot be proven about this, see G1.**

### D9 — The blit is snapped to whole device pixels

A world-anchored tile lands at a fractional device offset under pan. Snapping
costs up to half a device pixel of global position error; resampling costs
softness on every static pixel. Nothing on screen provides a reference against
which the half-pixel could read as jitter — there is no live overlay layer — and
crispness is what a CAD user sees.

**Snapping earns the strongest correctness claim available.** At settle the
camera is exactly where the tiles were baked, the offset is exactly zero, and
the blit is a 1:1 texel-to-pixel copy. The settled tiled frame can therefore be
required to match the live frame with **zero stray and zero uncovered pixels** —
not a tolerance.

### D10 — Invalidation by document edit is two-directional and per tile

`DocChange` carries `Set<Handle> touched` and no previous geometry
(`doc_change.dart:11-12`). Both directions are needed, for the reason
`_letBoundRecede` exists:

- **Old position.** Each tile records the handles it baked as an ascending
  `Uint32List` — free, because the queries already return in that order — and a
  change binary-searches it.
- **New position.** Tiles intersecting the touched handles' new boxes.

`DocChange.touched` is documented as "empty when the whole document changed",
which is already the whole-document signal: an empty set drops the generation.

### D11 — An edit to anything owned by a definition drops the generation

**Trap 2 dissolves at tile granularity.** The carry-forward note
([item 4](../notes/2026-08-17-carry-forward-additions.md)) proposed that a tile
record which definitions it baked and that a touched definition-owned handle be
mapped through that definition's placements before the intersection test. The
mapping is unnecessary: if a tile baked definition `D` and `D` changed, every
instance of `D` in that tile changed. Invalidation by definition is **exact** at
tile granularity, not coarse.

One case survives: an edit that grows a definition's content bounds grows its
instances' world boxes, which may now spill into a tile that never baked `D`.
Resolving that exactly means enumerating `D`'s instances and recomputing boxes.

**This plan does not. A definition edit drops the generation.** A definition edit
is a block edit, not ordinary drawing, and it is rare; the cost is one rebake of
the visible set, which D13 already amortises. The rule is simpler than the
mechanism it replaces and its cost is measured rather than assumed.

### D12 — `documentRevision` finally gets a definition, and it needs a new source

Trap 1 (`STATUS.md`) says `documentRevision` does not exist and nothing says what
bumps it. Verified against the tree, the situation is worse than "does not
exist":

**`DocChange` is emitted only by `undo.dart:112` and `undo.dart:140`** — when a
command is applied or undone. Layer and linetype table mutations go through
`tables.dart`'s `add`/`remove`, outside the command system, and emit **nothing**.
A layer colour change today would leave every tile stale with no signal.

So `documentRevision` is defined here as: **a counter on the document's tables,
bumped by table mutation alone, read by the cache once per frame.** One integer
compare per frame, no `undo.dart` involvement, no new command class. It is the
only change this plan makes to `packages/jet_cad_2d`.

And the direction trap 1 actually cared about becomes criterion 5: **a geometry
edit inside one tile must invalidate no other tile.**

**Residual risk, stated:** this covers table `add` and `remove`. If a table
record can be mutated in place without passing through either, that mutation
remains invisible. The plan's first task verifies which it is and says so in the
results note.

### D13 — The settle rebake is spread across frames

When a zoom settles, the whole visible set is stale. Baking it in one frame is a
60 ms hiccup at 500,000 entities — the cost this plan exists to remove, moved
rather than removed.

`kTilesBakedPerFrame` bounds how many tiles bake per frame; the rest continue to
show the stale scaled generation until replaced. The gesture already showed
stale pixels, so extending that by a few frames opens no new class of error.

### D14 — Behind a flag; correctness by ink comparison, not by goldens

`DraftCanvas` takes `tiles`, defaulting off. The golden suite stays at 40 PNGs.

Goldens are bound to the platform that produced them, and a tiled frame adds a
resampling axis that would make every PNG more platform-fragile. The ink
comparison is the right instrument: it is what Plan 3d used to earn the
two-backend decision, and D9 lets this plan demand its strictest setting.

---

## Architecture

**New file:** `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`.

**Owner:** `_DraftCanvasState`, alongside the sinks, so the cache outlives the
frame.

**Engine change:** one revision counter on the tables (D12). Nothing else in
`packages/jet_cad_2d` moves.

### The frame path

```
paint(canvas, size):
  if (!tiles) → today's path, unchanged

  cache.beginFrame(camera, size, devicePixelRatio, tablesRevision)
    → drops the generation on a scale, viewport, dpr or table change

  if (the generation is stale for scale):
     blit the previous generation scaled, and bake nothing
     (the settle will start the new generation)
  else:
     for each visible tile key, in a fixed order:
        image = cache[key]
          ?? (baked, if this frame's bake budget allows)
          ?? the previous generation's covering pixels
        blit at the snapped destination
```

### Allocation

`CLAUDE.md` requires the frame path to allocate **nothing per entity** in steady
state and **O(1) per flush**. A tiled frame allocates per *tile*: the `Rect`
pair each `drawImageRect` takes. The tile count is bounded by the viewport
divided by `kTileDevicePixels` — a constant for a given window, independent of
entity count.

**This is compliant and the spec says so explicitly**, so a later review is not
left to decide whether "per tile" means "per entity". A `Paint` is built once and
held, as `CanvasDrawSink` and `VerticesDrawSink` both already do.

---

## Exit gate — thirteen failable criteria

### Correctness — ink comparison, zero stray and zero uncovered pixels

1. A settled tiled frame equals the live frame, at a **non-identity camera**.
2. The same, with a fixture that **crosses tile boundaries** (D7 makes this
   unavoidable rather than optional).
3. The same, with a fixture carrying **text**.
4. The same, with **overlapping translucent** strokes.

### Invalidation — structural, always-on

5. A geometry edit inside one tile invalidates **no other tile**.
6. An edit to a definition-owned handle drops the generation — **and nothing
   less than that does**.
7. A table mutation drops the generation.
8. A scale change drops the generation; a pan drops **nothing**.
9. Undo travels the same path as the edit it reverses.

### Budget and performance

10. The 500,000-entity settled frame, read from **`totalSpan`**.
11. A pan frame that is baking a newly exposed strip, same column.
12. Peak live tile bytes stay under the declared cap.
13. Frame-path allocation: nothing per entity, viewport-bounded per frame.

**Criteria 10 and 11 are read from `totalSpan` and not `rasterDuration`**, and
the reason is Probe D: its rebake arm rasterised 217,758 triangles into a texture
on every frame while `rasterDuration` read 0.87 ms — indistinguishable from a
bare blit — because `toImageSync` returns before the GPU work it schedules.
`totalSpan` read 13.56 ms for the same arm. **A gate written against
`rasterDuration` would pass while the work happened.**

`report()` gained the third column on `main` at `2218eab`.

### R4a and R4b run with tiles on

The dev harness already carries R4a (a leaf edit per frame) and R4b (an instance
drag per frame), written for Plan 3d. They are the edit-regime form of criteria
10 and 11, and a bad invalidation rule — dropping the generation on every edit —
shows up in them immediately as a full rebake per frame. No new rig is written.

---

## Named mutants

Each must turn a stated criterion red.

| # | mutation | kills |
|---|---|---|
| M1 | delete the **old-position** direction of invalidation | a moved entity leaves a ghost — criterion 5 |
| M2 | delete the **new-position** direction | a moved entity's destination tile never updates — criterion 5 |
| M3 | `doAntiAlias: true` on the tile clip | seam — criterion 2, **subject to G1** |
| M4 | drop `scaleGeneration` from the key | stroke widths and dash phase from the wrong scale — criterion 8 |
| M5 | a definition edit does not drop the generation | stale instances — criterion 6 |
| M6 | ignore the LRU cap | unbounded memory — criterion 12 |
| M7 | clip each tile to the viewport instead of to its own rect | every tile draws everything; the correctness criteria stay green and the frame collapses — criteria 10 and 11 |
| M8 | do not read the tables revision | a layer colour change leaves stale pixels — criterion 7 |
| M9 | bake the whole visible set in one frame | the settle hiccup returns — criterion 11 |
| M10 | blit without snapping | the settled frame resamples and stops being 1:1 — criterion 1 |

M7 is the one worth stating twice: it is the mutation that passes every
correctness gate and destroys the plan's entire reason for existing. A suite that
cannot kill it is not gating this plan.

---

## Anti-degenerate rule

Binding on every test this plan writes.

- **No fixture may fit inside a single tile.** D7's injectable tile size makes
  this cheap to guarantee and expensive to violate by accident.
- **No ink comparison may run at the initial `fit` camera.**
  `ViewportTransform.fit` applies a 0.95 margin (`viewport_transform.dart:32`)
  and deriving an expected on-screen quantity through it cost Plan 3f two tasks.
  Build the camera by hand.
- **No test may use a single-tile viewport**, which would make the grid, the
  seam, and every invalidation criterion vacuous at once.
- **No invalidation test may touch a handle at the document root only.** The
  definition-owned path is D11, and a root-only fixture never reaches it.

---

## Accepted gaps

### G1 — The instrument cannot settle the seam on device

D8's mechanism is a hard clip on the pixel grid, which is exact in principle. The
ink comparison runs in `flutter test`, and
`drawvertices_antialiasing_test.dart` pins that **`flutter_test`'s software Skia
does not antialias `drawVertices` at all** — that file's own words are "a fact
about `flutter_test`'s software Skia, not about this codebase."

So the instrument **cannot produce an antialiased seam**, and a zero result from
criterion 2 is partly a property of the instrument. This is precisely the
situation `drawvertices_antialiasing_test.dart` was written to expose for Plan
3e's mode-2 seam, repeating on new ground.

**What criterion 2 does prove:** geometric completeness — no pixel missing, none
drawn twice, no clipping arithmetic error. That is most of the risk and it is
worth gating.

**What it does not prove:** that Impeller honours a non-antialiased clip exactly
on the device pixel grid. A device-side check is **owed and not delivered by this
plan**, and the results note must say so in those words rather than publishing a
green criterion 2 as a settled seam.

### G2 — In-place table record mutation

D12 covers table `add` and `remove`. If a record can be mutated in place, that
path stays invisible to the revision counter. Task 1 establishes which it is; if
in-place mutation exists, the gap is recorded, not fixed.

### G3 — Zoom stays where it is

Under a continuous zoom gesture this plan shows stale pixels cheaply; it does not
make a correct zoom frame faster. 500,000 entities under zoom remains a 32–40 ms
frame. That is Plan 3h's subject and this plan does not pretend otherwise.

### G4 — The web whole-drawing abort

`STATUS.md` records that Plan 3g is owed a back-to-back same-session re-run of
the web whole-drawing abort. It was out of scope for the spike and it is out of
scope here. **Still owed.**

---

## Global constraints for the implementation plan

- **The frame path allocates nothing per entity in steady state, and O(1) per
  flush.** Per-tile allocation is viewport-bounded and compliant; see
  Architecture.
- **Draw order is ascending handle value**, stable across undo, save, load and
  purge. Within a tile this is unchanged; tiles partition the screen, so no
  pixel's content is split across two tiles and cross-tile order cannot alter a
  pixel.
- **Geometric decisions use `Tolerance`; stored value comparisons are exact
  `==`.**
- **Never commit `analysis_options.yaml`** — `flutter pub get` rewrites three of
  them in this workspace.
- **Never synthesize test output.**
- **Never `git checkout` a file to revert a mutation.** Copy it aside, mutate,
  restore from the copy. Sanctioned exception:
  `apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj`, which
  `flutter drive` rewrites on every run.
- **Prefix every test command with `CI=true`.**
- `unused_import` is an **error** in `packages/jet_cad_2d_flutter`.
- **This plan may not amend `CLAUDE.md`.** A gate passable by editing the rule it
  is measured against is not a gate.
- Code, comments and commit messages in English.
- **Every task ends green** on both packages: test, analyze, format.

---

## What Plan 3h inherits

- **A measured zoom problem with a number on it**: 32.06 ms at 500,000 entities
  with tiles on, against a 16.67 ms budget, and the knowledge that no caching
  scheme touches it because the triangles are genuinely being drawn.
- **A tile cache that can hold a simplified bake.** Level-of-detail geometry has
  somewhere to live the moment it exists: it is a property of the generation,
  which is already keyed by scale.
- **G1's device seam check**, which 3h will need anyway if it changes what a tile
  contains.
- **The vertex-buffer consequence**, which this plan measures: baking per tile
  rewinds the buffer between tiles, so the 96.00 MiB high-water mark
  `STATUS.md:1005` records at 500,000 entities should fall to the largest single
  tile's geometry. If it does, the tile budget replaces that memory rather than
  adding to it, and 3h's budget starts from the new number.
