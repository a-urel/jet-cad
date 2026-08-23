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

Baked by running `DraftPainter` into a `PictureRecorder` through the configured
sink, then `Picture.toImageSync`.

**The painter does change, in one way, and the reason is subtle enough to state
in full.** `DraftPainter.paint` derives its rebase origin from *that call's*
visible world: `rebaseOriginFor` snaps the view centre to a power-of-two grid
whose step comes from the view span (`camera_controller.dart:18-33`). That is
frame-global **by construction** — the snap exists precisely so a pan does not
re-quantise every coordinate.

Bake a tile through a per-tile camera and each tile gets its own span, its own
exponent, its own step and its own origin. The residuals then differ from the
live frame's in `float32`, and criterion 1 allows **zero** differing pixels.

So `DraftPainter` gains an **injectable rebase origin**, and every tile in a
generation bakes with the frame-global origin the live path would have used.
The existing `debugDisableRebasing` is not that escape hatch: it forces the
origin to zero and destroys the precision rebasing exists for at 4.5e6.

**The general shape of this risk is worth naming once**: tiling subdivides the
frame, so *anything frame-global* — the rebase origin, the quantisation step,
the screen clip, the level-of-detail threshold — silently becomes a per-tile
quantity unless it is explicitly pinned. The seam is only its most visible
instance. Task 1 audits `DraftPainter.paint` for every such quantity and the
results note lists what it found.

### D2 — The key is `(scaleGeneration, x, y)`

A tile is `kTileDevicePixels` square. At scale `S` and device pixel ratio `dpr`
it therefore covers `kTileDevicePixels / (S · dpr)` world units, so **the world
extent of a tile is a function of the scale**. A scale change bumps the
generation and drops every tile.

This is not an extra mechanism; it is the same rule as D3, expressed in the key.

**It closes two carried traps at no cost:**

- **Trap 3** (`STATUS.md:1089`, a baked picture is not scale-invariant now that
  dashes exist) needed a new invalidation axis. It does not: scale is already
  in the key, so dash phase, stroke width and the text level-of-detail decision
  all bake at the one scale they are correct for.
- **Plan 3f's unanswered question** — may a cached picture contain text at all —
  falls out of the same fact. Text was a problem for a *definition* picture
  because that picture is shared across scale bands. A tile shares nothing:
  each generation has exactly one scale. **Text goes in the tile.**

### D3 — During a zoom gesture, blit a single carry-over composite, scaled; rebake on settle

Pixels are wrong during the gesture: stroke widths grow with the zoom
(a lineweight is a paper quantity and must not), text softens, and text the new
scale would newly reveal is absent. All of it is transient and self-correcting.

This is the standard map/CAD behaviour and it is the only option that makes zoom
*cheaper*; rebaking per frame was measured at 11–26%, which is not a win, and
drawing live leaves zoom exactly where it is today.

**What is blitted is one image, not the outgoing generation's tiles.** When a
generation is retired, its visible tiles are collapsed once into a **single
viewport-sized carry-over image** and the tiles themselves are dropped.

Two things force this and neither is optional:

- **Independently snapped neighbours gap or overlap.** D9's snapping is exact
  only when tile destinations differ by whole multiples of the tile size, which
  holds at the generation's own scale and fails under an arbitrary zoom factor.
  Snapped independently, adjacent scaled tiles leave a background gap or
  double-composite translucent ink along every shared edge. One composite has no
  internal edges.
- **Two live generations do not fit.** A spread settle (D13) would otherwise
  hold the outgoing generation *and* the incoming one, and LRU would fight the
  frame path from both ends, since the outgoing tiles are read every frame and
  therefore never look stale to a recency policy. The composite is 29.3 MiB
  flat, whatever the tile size.

**Snapping is therefore conditional**, and D9 says so: it applies when the
generation's scale equals the current scale, and not on the carry-over path.

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

| tile | tiles | memory | blits per frame |
|---|---|---|---|
| 128 px | 26 × 20 = 520 | 32.5 MiB | 520 |
| **256 px** | 14 × 11 = 154 | **38.5 MiB** | 154 |
| 512 px | 8 × 6 = 48 | 48.0 MiB | 48 |
| 1024 px | 5 × 4 = 20 | 80.0 MiB | 20 |
| *viewport area* | — | *29.3 MiB* | — |

**Every memory figure in this spec is MiB**, binary, so the cap in criterion 12
can be checked against these rows without conversion.

Larger tiles cost **more** memory, not less: the partial-coverage waste grows
with the square. 1024 px spends 2.5× what 128 px does — and D6 shows the bake
cost running the other way, which is why neither number picks the size alone.

### D6 — `kTileDevicePixels` starts at 256 and the plan measures it

Probe D measured **one** viewport-sized blit at 0.97 ms of raster. Whether 154
blits of 1/154 the area cost the same total, or whether per-call overhead
dominates, is **not measured**. Probe A's break at 2,507 calls was
`drawVertices`; `drawImageRect` is a different call.

A task sweeps the tile size and reports **three** columns, because the costs
pull in opposite directions and a sweep that reads only one of them picks the
wrong size confidently.

`kScreenClipInflate` is 32.0 **logical** pixels (`draft_painter.dart:50`) and it
inflates whatever rect the painter is culling against. Per frame that is a rounding
error on a 1600×1200 view. Per *tile* it is not:

| tile | tiles | memory | bake overdraw | blits per frame |
|---|---|---|---|---|
| 128 px | 520 | **32.5 MiB** | **4.00×** | 520 |
| 256 px | 154 | 38.5 MiB | 2.25× | 154 |
| 512 px | 48 | 48.0 MiB | **1.56×** | 48 |
| 1024 px | 20 | 80.0 MiB | 1.28× | 20 |

**Memory wants small tiles and bake cost wants large ones.** A 128 px tile at
`dpr` 2 is 64 logical pixels; inflated by 32 on every side it culls against a
128×128 logical rect, so the settle walks **four times** the live frame's
geometry. At D7's 64 px test tiles the factor is **9×**, which is why the test
grid is a correctness instrument and never a timing one.

So the sweep reports **blit cost per frame, bake cost per tile, and the measured
overdraw factor**, and criterion 11 — the one threshold no measurement backs
yet — is dominated by the second and third, not the first.

**1024 px is excluded before the sweep starts**: 80.0 MiB of visible set against
criterion 12's 96 MiB cap leaves no room for the 29.3 MiB carry-over. The sweep
runs {128, 256, 512}.

**This subsumes the spike's open upload-bound-versus-fill-bound question**, which
existed only because it decides tile size. The sweep answers the decision
directly instead of the mechanism behind it.

**A second constant falls out**: whether a tile bake should inflate by
`kScreenClipInflate` at all. It cannot inflate by zero — a stroke centred outside
the tile still bleeds in by half its width — but 32 logical pixels is a
frame-scale number. The sweep reports what the overdraw costs; if a
tile-specific `kTileClipInflate` is warranted, the results note names it with
the measurement that justified it. **This plan does not guess it in advance.**

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

### D9 — The frame's screen translation is quantised to whole device pixels, on **both** paths

A world-anchored tile lands at a fractional device offset after an arbitrary
pan. **Settling does not make that offset zero**: the key excludes translation
by design (D2), and criterion 8 requires a pan to drop nothing, so there is no
moment at which the camera returns to the one the grid was anchored at.
Snapping each tile independently against a fractional camera would therefore
leave the tiled frame up to half a pixel from the live frame — permanently, not
transiently — and criterion 1 allows zero differing pixels. An earlier draft of
this spec claimed the offset was zero at settle. It is not.

**The rule instead: the camera's screen-space translation is quantised to whole
device pixels, and the quantised camera drives the live path too.**

Then every tile destination is integral by construction, at every camera, and
the blit is a 1:1 texel-to-pixel copy. The drawing sits up to half a device
pixel from the mathematically exact camera — invisible, uniform across the whole
frame, and **identical in the tiled and live paths**, which is the property the
gate needs.

That is what earns the strongest correctness claim available: the tiled frame is
required to match the live frame with **zero stray and zero uncovered pixels**,
not a tolerance — and it is required at *any* camera, not at a privileged one.

**Snapping is conditional on the generation's scale matching the current scale.**
On D3's carry-over path the scale differs, tile spacing is fractional, and
independently snapped neighbours would gap or overlap; that path blits one
composite image and does not snap.

### D10 — Invalidation by document edit is two-directional and per tile

`DocChange` carries `Set<Handle> touched` and no previous geometry
(`doc_change.dart:11-12`). Both directions are needed, for the reason
`_letBoundRecede` exists:

- **Old position.** Each tile records the handles it baked as an ascending
  `Uint32List` — free, because the queries already return in that order — and a
  change binary-searches it.
- **New position.** Tiles intersecting the touched handles' new boxes.

**Leaf handles alone are not enough, and the gap is not exotic.**
`TransformNodeCommand` moves an `InstanceNode` and reports
`touched: {handle}` — the node's handle and nothing else
(`commands.dart:304`). The leaves it moved keep their own handles and appear in
no part of that set. A tile that recorded only baked *leaf* handles cannot find
the old pixels of a dragged instance, and the instance leaves a ghost.

So a tile records **two** ascending lists: the leaf handles it baked, and the
**node handles whose subtrees contributed to it** — every instance and
definition on the path down to those leaves. A touched handle matching either
list invalidates the tile.

`DocChange.touched` is documented as "empty when the whole document changed"
(`doc_change.dart:11-12`), which is already the whole-document signal: an empty
set drops the generation.

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

### D12 — Five change arms, and a table signal that does not exist yet

Trap 1 (`STATUS.md:1081`) says `documentRevision` does not exist and nothing says
what bumps it. Verified against the tree, two things are worse than that.

**First, `DocChange` has five subclasses and five emitters, not two.**
`undo.dart` emits `CommandApplied` (`:112`), `CommandUndone` (`:140`),
`CommandRedone` (`:161`), `DocumentLoaded` (`:169`) and `DocumentPurged`
(`:178`). An earlier draft of this spec surveyed only the first two. The cache
switches on all five, exhaustively, the way `spatial_index.dart:2256-2270`
already does:

| change | tile cache |
|---|---|
| `CommandApplied` / `CommandUndone` / `CommandRedone` | D10's two-directional per-tile invalidation |
| `DocumentLoaded` | drop everything, generation and carry-over |
| `DocumentPurged` | drop everything — a purge rewrites the store's slots wholesale |

**Redo is not a footnote.** A cache that handles apply and undo and forgets redo
shows stale pixels after every redo while passing an undo-only gate. Criterion 9
and M12 both name it.

**Second, table mutations emit nothing at all, and reading a counter would not
be enough.** `TableSection` has three mutators — `add`, `remove` and **`clear`**
(`tables.dart:51-68`) — none of which notifies anything, and `DraftCanvas`
repaints only for `Listenable.merge([camera, _changes])` where `_changes` is the
command-backed `DocChangeNotifier` (`draft_canvas.dart:184-185`). A revision
integer checked inside `paint` would invalidate correctly **and never be
reached**, because a layer edit causes no paint. The stale pixels would sit there
until an unrelated camera move.

So `documentRevision` is defined here as: **a counter on `DocumentTables`,
bumped by `add`, `remove` and `clear`, exposed as a `Listenable` and merged into
`DraftCanvas._repaint` beside the camera and the command notifier.**

`TableSection`'s six instances are bare field initializers on `DocumentTables`
with no back-reference (`tables.dart:471-478`), so the counter cannot live on
`TableSection` alone: `DocumentTables` constructs each section with a mutation
callback and owns the counter and the `Listenable`. **This is the only change
this plan makes to `packages/jet_cad_2d`.**

And the direction trap 1 actually cared about becomes criterion 5: **a geometry
edit inside one tile must invalidate no other tile.**

### D13 — The settle rebake is spread across frames

When a zoom settles, the whole visible set is stale. Baking it in one frame is a
60 ms hiccup at 500,000 entities — the cost this plan exists to remove, moved
rather than removed.

`kTilesBakedPerFrame` bounds how many tiles bake per frame; the rest continue to
show **D3's carry-over composite**, scaled, until replaced. The outgoing
generation's tiles are already gone by then, which is what keeps the budget in
D14's arithmetic instead of holding two generations at once. **It starts at 8**, which at
256 px covers a 154-tile visible set in twenty frames — a third of a second at
60 fps, against the ~60 ms single-frame stall it replaces. D6's sweep may move
it, and the results note reports the value it settled on with the frame times
that justify it. The gesture already showed
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
     if a carry-over composite exists:
        blit it once, scaled, beneath everything      // D3, not snapped

     for each visible tile key, in a fixed order:
        image = cache[key]
          ?? (baked now, if this frame's bake budget is not spent)
        if image != null → blit at the snapped destination
        else if no carry-over covers this tile's rect → remember it as uncovered

     if any tile was uncovered:
        draw live, once, clipped to the union of the uncovered rects
```

**The uncovered path is not a startup special case, and calling it one was a
defect in an earlier draft.** A tile can be missing whenever no image covers its
rect, and three ordinary situations produce that:

- the very first frame, when no generation and no carry-over exist yet;
- a pan that travels farther than the retained ring, so the carry-over — anchored
  where the generation was retired — no longer reaches;
- **after eviction**, once criterion 12's cap has reclaimed tiles the camera then
  comes back to.

The last is the one that would have shipped as an intermittent blank strip:
nothing in a settled-frame criterion can see it.

**It draws live once for the union, not once per tile.** Up to 154 painter
invocations in a single frame would be slower than the live path this plan
replaces; one walk against the union rect is exactly today's cost, which is the
correct worst case for a frame that has no cache to use.

A **long-pan fixture that exceeds the retained ring** and an **eviction fixture
that returns to reclaimed tiles** are both required by the anti-degenerate rule
below.

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
9. **Undo and redo** both travel the same path as the edit they reverse, and
   `DocumentLoaded` and `DocumentPurged` each drop everything. All five arms of
   `DocChange`, none omitted.

### Budget and performance

10. The 500,000-entity settled frame, read from **`totalSpan`**: **≤ 4.00 ms**.
    Probe D measured 1.61 ms for a single viewport blit; the allowance covers
    the tile grid's extra `drawImageRect` calls, whose cost D6 has not measured
    yet. Against a live frame's 40.27 ms this is still a 10× claim.
11. A pan frame that is baking a newly exposed strip, same column: **≤ 16.67
    ms** at 500,000 entities — the frame budget itself, since a pan frame that
    misses it is a dropped frame and the whole plan is about pan.
12. Peak live cache bytes stay under **`kTileCacheBytes = 96 MiB`**, counting
    the carry-over composite and every generation's tiles together. At 256 px
    the visible set is 38.5 MiB and the carry-over is 29.3 MiB, leaving 28.2 MiB
    of ring — enough that eviction is real rather than theoretical, and little
    enough that the eviction fixture actually reclaims.

    **The cap is 96 MiB and not 64 because D3's carry-over is a second live
    image**, and because 96 MiB is the figure this cache may *replace*: the
    vertex buffer's high-water mark at 500,000 entities (`STATUS.md:1066`).
13. Frame-path allocation: nothing per entity, viewport-bounded per frame.

**Criterion 13 needs an instrument it does not have, and trap 5 says why.**
`STATUS.md` records that there is no working Flutter-side allocation meter and
that "3g's trap 5 needs a **command-time assertion** … not a frame-path
allocation gate in `jet_cad_2d_flutter`". `paint_allocation_test.dart` reads one
field — `VerticesDrawSink.debugCapacityVertices` — which can see neither a
`Paint` nor a `Rect`.

So criterion 13 is measured by field reads rather than by a heap profile:
`TileCache` exposes **the identity of the single blit `Paint`** and a
**per-frame count of blit destinations**, pinned across frames and against the
visible tile count.

**Corrected 2026-08-24, during Task 4.** An earlier revision said that exposing
the `Paint`'s identity "is what makes M13 killable". **It does not.** A getter
returning the cache's own field reports the same object whatever the blit
actually passes to `drawImageRect`, so a mutant that builds a fresh `Paint` at
the call site leaves the test green — the assertion is a tautology. This is the
same gap `paint_allocation_test.dart` already exists to close for
`VerticesDrawSink.debugPaint`, and this spec walked into it again one section
after citing trap 5.

**M13's real instrument is a canvas spy.** The repository already carries one
(`test/support/spy_canvas.dart`); the test reads the `Paint` actually handed to
`drawImageRect` and compares *that* to the cache's field. The identity getter
stays — it is a useful cheap check — but it is not the gate.

**Criterion 11's threshold is the one number here that is not backed by a
measurement**, and the plan must not quietly relax it. D6's sweep runs before
criterion 11 is evaluated, and it must report **bake cost per tile and the
overdraw factor**, not blit cost alone: a pan frame's cost is dominated by the
strip it bakes, and bake cost moves *opposite* to blit cost as the tile size
changes. A sweep that reads only blit cost would recommend the smallest tile and
lose the criterion.

If the sweep shows 16.67 ms is unreachable at every size in {128, 256, 512}, the
response is a smaller `kTilesBakedPerFrame`, or a `kTileClipInflate` justified by
the overdraw column, **not a larger threshold**. A gate moved to fit its result
is not a gate.

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
| M3 | `doAntiAlias: true` on the tile clip | **deferred, unkillable in this instrument** — see G1 |
| M4 | drop `scaleGeneration` from the key | stroke widths and dash phase from the wrong scale — criterion 8 |
| M5 | a definition edit does not drop the generation | stale instances — criterion 6 |
| M6 | ignore the LRU cap | unbounded memory — criterion 12 |
| M7 | clip each tile to the viewport instead of to its own rect | every tile draws everything; the correctness criteria stay green and the frame collapses — criteria 10 and 11 |
| M8 | leave the table `Listenable` out of `DraftCanvas._repaint`, keeping the counter | invalidation is correct and never asked to run: a layer colour change leaves stale pixels until an unrelated camera move — criterion 7 |
| M9 | bake the whole visible set in one frame | the settle hiccup returns — criterion 11 |
| M10 | blit without snapping | the settled frame resamples and stops being 1:1 — criterion 1 |
| M11 | blit with `BlendMode.src` instead of `srcOver` | a tile's transparent regions overwrite the canvas beneath and translucent pixels stop compositing — criterion 4 |
| M12 | handle `CommandApplied` and `CommandUndone` but drop the `CommandRedone` arm | a redo shows the pixels the undo left — the omission an undo-only gate would never see — criterion 9 |
| M13 | build the blit `Paint` per tile at the `drawImageRect` call site instead of once | per-frame allocation grows with the tile count — criterion 13. **Fired through a canvas spy, not through the identity getter**, which cannot see what the call site passed |
| M14 | skip text when baking a tile | a tiled frame silently loses its labels — criterion 3 |
| M15 | offset a tile's bake camera by one device pixel | a row of missing and duplicated pixels along every seam — criterion 2, **and this one the instrument can fire** |
| M16 | record only leaf handles per tile, dropping the node list | a dragged instance leaves a ghost in the tile it left — criterion 5 |
| M17 | bake tiles with a per-tile rebase origin instead of the frame-global one | **not criterion 1** — see the note below. Fired by a wiring test that reads the coordinate `_bake` hands the sink |

**Seventeen mutants against thirteen criteria. Sixteen can be fired in this
plan's instrument; M3 cannot, and it is listed as deferred rather than counted.**

**Corrected 2026-08-24, during Task 5. M17 is not fireable through the pixel
criteria on the vertices backend, and the reason is algebraic rather than a
matter of fixture magnitude.** The painter pushes the rebase origin as the
residual itself — `Transform2.translation(_screenOrigin.x, _screenOrigin.y)`
(`draft_painter.dart:605,742`) — and `VerticesDrawSink` applies that residual in
Dart `Float64` (`vertices_draw_sink.dart:322-323`) before storing into its
`Float32List`. So `(screen - origin) + origin = screen` **exactly**, whatever
the origin, and the final pixel does not depend on it. Task 5 proved this both
algebraically and with a magnitude sweep from 4.5e6 to 1e15.

D1's injected origin is still required — it is what keeps the *stored* value
small on the `CanvasDrawSink` path, where the residual becomes a canvas
transform Skia evaluates in `float32`, and text takes that path on every frame
— but its gate is a **wiring** test that reads the coordinate `_bake` hands the
sink, not a pixel comparison. The mutation log records it that way.

That distinction is the whole point of stating the property. Plan 3f.1's final
review found a criterion with no possible mutant only after the plan had shipped,
with the sentence claiming full coverage sitting in its spec the whole time — and
an earlier draft of *this* spec repeated it, counting M3 toward a coverage claim
that G1 had already conceded was unfirable two sections later. **Criterion 2 is
gated by M15**, which moves pixels the software rasteriser can see; M3 waits on
G1's device check.

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
- **The invalidation matrix must include an instance transform and its undo.**
  `TransformNodeCommand` reports only the node handle, so a fixture that moves a
  leaf exercises none of D10's node-handle list and M16 survives it.
- **A long-pan fixture must travel farther than the retained ring**, and an
  **eviction fixture must return to tiles the cap has reclaimed.** Both reach the
  uncovered path in Architecture, which no settled-frame criterion can see.

Every clause here exists because a plausible fixture that violates it would leave
a named mutant alive.

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
drawn twice, no clipping arithmetic error. That is most of the risk, it is worth
gating, and **M15 fires it**: a bake camera offset by one device pixel moves
pixels that software Skia renders and compares perfectly well.

**M3 is the mutant that cannot fire here**, and it is listed in the table as
deferred rather than counted toward coverage.

**What it does not prove:** that Impeller honours a non-antialiased clip exactly
on the device pixel grid. A device-side check is **owed and not delivered by this
plan**, and the results note must say so in those words rather than publishing a
green criterion 2 as a settled seam.

### G2 — In-place table record mutation, now nearly closed

Every table record is `@immutable` with all-final fields (`tables.dart:73-95`),
and `TableSection.add` throws `DuplicateHandleError` on a handle it already
holds — so changing a layer's colour is necessarily a `remove` followed by an
`add`, and both are covered.

**The gap shrinks to a rule rather than a risk: no table record may gain a
setter.** If one ever does, the mutation is invisible to D12's counter. The plan
records this where the counter lives, so the next person to add a setter reads
the reason first.

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
  contains — and with it the standing lesson that this repository's software
  rasteriser cannot produce an antialiasing artefact, so no green result from it
  settles one.
- **The vertex-buffer consequence**, which this plan measures: baking per tile
  rewinds the buffer between tiles, so the 96.00 MiB high-water mark
  `STATUS.md:1066` records at 500,000 entities should fall to the largest single
  tile's geometry. If it does, the tile budget replaces that memory rather than
  adding to it, and 3h's budget starts from the new number.
