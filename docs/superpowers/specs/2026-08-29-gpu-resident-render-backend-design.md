# A GPU-resident render backend — design

**Date:** 2026-08-29. **Status:** design, **revision 4**, not yet a plan.
**Target scale: 10,000 entities**, set by the human on 2026-08-29.
**Evidence of record:**
[the spike note](../notes/2026-08-29-flutter-gpu-backend-spike.md),
[the 10,000-entity measurement](../notes/2026-08-29-gpu-arm-10k-measurement.md),
and [the settle-flicker probe](../notes/2026-08-29-settle-flicker-probe.md).

**Revision 4 answers three independent reviews of revision 3.** They found
three blocking defects, and two of them were the same defect seen from
different angles: **the design partitioned the drawing into separate pipelines,
which destroys the ordering property the whole design rests on.** The third was
that collection is viewport-culled, so a pan draws into empty buffer. Both are
fixed below. Revision 3's headline numbers were also wrong in the spec's own
favour, twice; the corrected figures are in the measurement note and repeated
here.

---

## Two things to check before reading further

**1. This spec is opened against the roadmap's own judgement**, which calls the
render layer *"done, and over-built for this target"* at 500-5,000 entities.
The objection was raised and the human reaffirmed the work at 10,000.

**2. The case rests on the settle, not on cost.** At this scale the shipping
tile cache costs what this design costs. That is measured, and it is stated
plainly below rather than argued around.

---

## The case for the work

**Measured at 10,000 entities / 59,875 segments** — full tables, aggregation
rule and caveats in the measurement note. Median of three interleaved
per-repeat p50s, per stage, summed; zoom phase:

| arm | build | raster | frame |
|---|---|---|---|
| A painter (untiled) | 7.54 | 3.73 | **11.27 ms** |
| B tiles (blit) | 0.30 | 0.84 | **1.14 ms** |
| C flutter_gpu | 0.61 | 0.63 | **1.24 ms** |

**Arm B is marginally cheaper than arm C on a zoom, and at parity on a pan.**
Revision 3 read "1.1 against 0.9" and drew the opposite conclusion; 0.9 does not
follow from any aggregation of the three repeats. **Cost is not the argument.**

**The budget argument is real but it is not this run's.** Arm A sits at 68% of
16.67 ms here, not over it. The recorded miss is
`2026-08-21-plan-3d-results.md:333`, which measures the *same* backend at the
*same* 10,000 entities and states **"vertices raster p95 is 22.10-22.36 ms"** —
a minority of frames exceeding the budget, on the record, since August 21. That
note's p50 and this run's differ by ~1.8x under different camera and corpus
settings, and neither corrects the other.

### What the tile cache does not solve

The human, using the running product, reported **a visible flicker after every
pan and zoom**, and that report has since been measured — see
[the settle-flicker probe](../notes/2026-08-29-settle-flicker-probe.md). The
measurement narrows it:

| frame | differing pixels | of live ink |
|---|---|---|
| at rest | 0 | 0.0% |
| last zoom gesture frame | 25,275 | **141.7%** |
| settle frame 1 | 25,275 | **141.7%** |
| settle frame 2 | 16,681 | **93.6%** |
| settle frame 3 | 0 | 0.0% |
| **pan, every frame, at any distance tested** | **0** | **0.0%** |

**Three findings, and one of them narrows this spec's claim.**

1. **There is no stale-frame defect.** `a79903b`'s fix holds; both gestures
   reach zero and stay there.
2. **The zoom flicker is real and it is the resolution change** — a
   **three-frame** transition, two of them wrong by 141.7% and 93.6% of the
   frame's ink. At 60 Hz that is a ~50 ms two-step change.
3. **A pan does not flicker at all.** Structurally, not by luck: at constant
   scale the lattice is reusable, and only a zoom forces the composite to be
   magnified.

**So this spec claims the zoom case and not the pan case.** Whether the product
observation of a pan flicker is a different phenomenon this fixture does not
model — a combined pan-and-zoom, a different corpus, a dpr change mid-gesture —
or the zoom case misattributed, is unresolved and is open question 1.

**Why a resident backend removes it is structural.** The tile path holds two
representations of one drawing and the flicker is the frame that exchanges
them. A resident backend holds **one**: every frame, moving or still, draws the
same geometry through the same pipeline. There is no bake and no composite, so
there is no frame at which the picture changes kind.

Two further differences, both measured: no ~20 MB composite to hold against
**2.06 MB** of resident geometry, and no bake spikes — the spike's web arm
measured arm B at a **46-47 ms max build** on a zoom, at 15,000 entities,
against arm C's 4.40.

**If sharpness during a gesture is not worth those, turn tiles on and close this
spec.**

---

## The question this answers

`DraftPainter.paint(sink, camera, viewport)` folds the camera into the residual
chain, so every vertex a sink receives is in screen space and the whole document
is re-walked the moment the camera moves.

> Make a pan or a zoom cost a **uniform write** instead of a **document walk**,
> without giving the picture up to a bitmap.

**Move the walk from every frame to every edit.** The walk costs 14.7 ms and
happens on change; the frame costs 1.24 ms and happens sixty times a second.

## Non-goals

- **Replacing `VerticesDrawSink`.** It stays the default and the fallback.
- **Changing the document model.** `packages/jet_cad_2d` is untouched.
- **Incremental geometry update.** Out of scope at this scale. Past roughly
  50,000 entities this spec is wrong.
- **Culling, a scene graph, or a tile cache of our own.**

---

## The two decisions everything else follows from

### 1. Any change is a full rebuild

**Measured: the collection walk is 14.7 ms, the upload 1.0 ms.** The backend
does not track what changed.

| signal | response |
|---|---|
| `CommandApplied` / `Undone` / `Redone`, any `touched` | rebuild |
| `DocumentLoaded`, `DocumentPurged` | rebuild |
| **table revision counter** (`tables.dart:559`) | rebuild |
| **`devicePixelRatio` change** (`draft_canvas.dart:353-357`) | rebuild |
| watermark exit (below) | rebuild |

**The table row is not padding.** `tables.dart:559`: *"Table mutations reach the
command system not at all. `DocChange` is emitted only by `undo.dart`."*
`DraftCanvas` merges a separate table listenable for exactly this reason.

**The `devicePixelRatio` row was missed by revision 3 and two reviewers caught
it.** The collected record carries a device half-width, and both that width's
floor (`vertices_draw_sink.dart:545-552`) and the hairline coverage fade
(`:561-575`) are functions of dpr, which `DraftCanvas` rebinds per build
*"because it changes when the window moves between displays"*. Moving a window
between a retina and an external display emits no `DocChange`, bumps no table
revision and changes no camera scale.

**The cost, corrected.** Revision 3 said an edit is "no worse than today". It is
worse, and both reviewers who checked said so:

- Against the **untiled** arm: a 14.7 ms rebuild against a ~7.5 ms per-frame
  build — roughly **2x**, and the rebuild frame still has to raster.
- Against the **tiled** arm the gap is larger, because the tile cache does not
  rebake wholesale on an edit. `tile_cache.dart:1885-1946` drops only tiles
  whose baked handles intersect `touched`, and `kBakeBudgetDevicePixels`
  (`tile_cache.dart:153`) spreads even a generation drop across frames at one
  tile per frame, by construction never spending a full walk on one frame.

So a live drag-edit is a real regression against both arms, and it is the price
of removing the per-frame walk. It bounds the design to this scale.

### 2. No depth buffer, because submission order is emission order

With a full rebuild the buffer is written in walk order and submitted in walk
order, so ordering holds without a depth attachment — which also retires
revision 2's dependency on a depth feature **the spike never ran on any
platform**, and dissolves revision 2's antialiasing contradiction, since with no
depth test there is nothing to keep order-independent and blending in
submission order is what `VerticesDrawSink` already does.

**One reviewer verified the graphics-API half and it holds:** within one
instanced draw call and across draw calls in one render pass, primitive and
instance order is guaranteed on Vulkan, GLES3/WebGL2 and Metal. What is *not*
available is any way to make separate draw calls appear in an order other than
submission — which is why the next section exists.

**Say "emission order", not "ascending handle value".** A definition's contents
are emitted contiguously at the *instance's* handle position, in
definition-local handles (`draft_painter.dart:397-412`, `:449-467`). Global
emission order is **not** a sorted list of handle values, and telling an
implementer otherwise invites them to sort the buffer, which would be wrong.

---

## Architecture

### One buffer, one kind tag, one draw call

**This is revision 4's central correction, and it was the blocking finding of
two independent reviews.** Revision 3 gave strokes, joins and fills their own
pipelines. Three pipelines are three draw calls, which submit as *all strokes,
then all joins, then all fills* — not walk order.

That is not a hypothetical. It is a defect this repository already shipped and
reverted, recorded in `vertices_draw_sink.dart:41-57`: one buffer per **colour**
was fast *"but it reordered the drawing… strokes are opaque, so a reordered
stroke covers a different neighbour, and the picture's colour balance changed.
Draw order is ascending handle value, and that is a rule about strokes, not
only about fills."* A buffer per pipeline is the same partition with a different
key. The ordering is intra-entity too: `_runTo` emits the join **before** its
segment (`:346-349`) and the seam join **last**, after the closing segment
(`:381-397`).

**The design is therefore what `VerticesDrawSink` already is, moved to the GPU
with the transform in the shader:**

- **One instance buffer**, written in walk order.
- **One record format**, carrying a `kind` tag: stroke segment, join wedge,
  fill triangle, point.
- **One instanced draw call**, one pipeline, one vertex shader that branches on
  `kind`.
- The unit primitive is a **triangle**; a stroke quad is two instances, a join
  wedge one or two, a fill triangle one. This mirrors what `drawVertices`
  receives today.

The cost is a wider record than a kind-specific one would need and a vertex
shader with a branch. Both are paid once per instance and neither is per frame.

### Collection covers the whole document, at a reference scale

**Revision 3 never said which camera collection runs under, and both branches
fail** — the second blocking finding.

`DraftPainter.paint` culls to the camera's viewport: `draft_painter.dart:338`
computes `camera.visibleWorld(viewport)` and both queries take it (`:357`,
`:369`), inflated by `kScreenClipInflate = 32.0` logical pixels (`:50`). A
buffer collected at the live camera therefore contains what was on screen plus
32 px, and the trigger table has no row for a pan — so panning 33 px draws into
empty buffer. The spike did not hit this because it collected at the **fit**
camera with the whole document in view, which is the degenerate fixture
`CLAUDE.md` names.

**Decision: collection runs with a viewport that covers the document's whole
extents, at a stated reference scale.** Nothing is culled, so:

- **A pan needs no trigger and no rebuild.** The question this design answers is
  about pans; a design that rebuilt on them would answer nothing.
- **A viewport resize needs no trigger either**, for the same reason.
- The only frozen decisions left are the **scale-dependent** ones below.

The reference scale is a parameter, not the fit scale: fitting a floor plan into
a viewport gives a scale 50-100x coarser than the working scale, which would
freeze every tessellation and culling decision at a uselessly coarse value and
put the watermark's band edge inside the first zoom. **The plan chooses the
reference scale by measurement.**

Coordinates are stored in that reference space, rebased through the painter's
own `rebaseOriginFor` (`draft_painter.dart:341`) so float32 precision is a
document-extent question rather than a world-origin one — the same problem the
painter already solves, solved the same way.

### Text: the submission splits at text boundaries

**The third blocking finding.** Revision 3 drew text as one Canvas pass over a
resident list. The GPU geometry reaches the canvas as a single composited image,
so one text pass puts **all** text above or below **all** geometry. The
reference interleaves: `VerticesDrawSink.text` flushes the batch first
(`:719-722`), and `:627-632` says why — *"without this the unbatchable op would
reach the `Canvas` immediately while every stroke before it waited for the end
of the frame, which is the reordering the class comment's history describes."*

**Decision: the resident stream is split at every text op.** *N* text ops
produce *N+1* GPU draw calls interleaved with *N* Canvas text draws, in emission
order. Ordering is then exact, and it is exactly the discipline the reference
sink already applies.

The cost is one draw call per text op, and **the plan must bound it**: this is
affordable at floor-plan text counts and is not at arbitrary ones. Criterion 11
gates the text pass, and the corpus for the gesture criteria is required to
contain text — revision 3 let that be waived and a reviewer showed the waiver
made the budget unfalsifiable.

The resident text record carries the composed transform's six floats **flat**
(composing `Transform2.multiply` per op per frame would allocate —
`transform2.dart:62-69` — and invariant 1 forbids it), the string, the style
handle, and `resolved.argb`, which is part of the paragraph cache key
(`canvas_draw_sink.dart:204-207`).

### Where the quad is built: the shader, always

The stroke half-width is invariant under zoom — the lineweight is paper-space
1/100 mm and explicitly *"not a world quantity"* (`resolved_style.dart:18`), and
the perpendicular is taken after transforming the endpoints
(`vertices_draw_sink.dart:59-67`). **Any quad expanded at collection time
thickens with the camera.**

So the record carries a **centerline and a half-width**, and expansion happens
in the vertex shader. The consequence revisions 1 and 2 got wrong: joins and
caps cannot be collector-emitted geometry either, because a miter is a function
of the live half-width.

- **Joins** are a `kind`: shared vertex plus two unit directions; the shader
  builds the wedge. Everything `_emitJoin` needs is scale-invariant under a
  uniform camera (`vertices_draw_sink.dart:399-448`). The **seam join**
  (`:375-397`) is included; its absence notches every circle, and it is
  reachable only from `circle()`, since the painter passes `closed: false` at
  every polyline site.
- **Caps** are a per-instance flag on a stroke.
- **`point()` is its own `kind`, not a cap.** It is drawn as a hardcoded
  *horizontal* square of the stroke width (`vertices_draw_sink.dart:638-652`) —
  a zero-length run with no centerline direction to extend along.
- **`_coveredArgb` is collected** (`vertices_draw_sink.dart:554-575`): a stroke
  thinner than one device pixel keeps its pixel and gives up alpha in
  proportion. It is dpr-dependent, hence the trigger row above. **It must not
  reach fills** — the sink bypasses it there deliberately, because *"routing a
  fill through `_coveredArgb` would fade a filled room on a hairline layer"*
  (`:736-741`).
- **Degenerate primitives are dropped at collection**, matching the sink's exact
  `== 0` tests (`:350-355`, `:503-507`, `:407-410`), so the shader never sees a
  zero-length direction.

### Dashes are shaded, with the conversion the painter actually uses

`draft_painter.dart:630` dashes at `_dashScale(style, toScreen)`, which is
`style.linetypeScale × header.globalLinetypeScale × toScreen.scaleMagnitude`
(`:651-654`) — and `toScreen` is `camera ∘ placement` (`:527`), so **the
per-entity placement scale is part of the factor and the camera is only one term
of it.** Revision 3 said "paper-space units and the camera-scale uniform", which
is wrong.

- The collected per-instance quantity is the period in reference-space units,
  which folds in `linetypeScale`, `globalLinetypeScale` and the placement's
  `scaleMagnitude`. The uniform is the **live-to-reference scale ratio**.
- **Phase: polylines restart at every vertex** (`dasher.dart:94-96`), so each
  segment instance carries phase 0 — a shader accumulating arc length along the
  polyline would be a regression against the oracle. **Arcs are continuous
  along the sweep** (`dasher.dart:319-352`) and carry a running phase.
- The collapse-to-solid rule is `kDashCollapsePx = 3.0` on the period
  (`dasher.dart:21`, `:117-121`) and reduces to a shader branch on the same
  threshold.
- **Dashed arcs are a distinct case and revision 3 had neither design nor
  fixture for them.** Today each dash span on an arc is emitted as its own
  `arc()` op (`draft_painter.dart:311-314`) and independently re-chorded
  (`vertices_draw_sink.dart:674-716`), so a single-chorded shaded arc puts
  vertices elsewhere and measures chord length where the reference measures arc
  length. **The plan must either reproduce the per-span chording or record the
  divergence**, and the corpus gains a dashed arc.

Shading is chosen over rebuilding because it is exact at every scale and because
it removes the span-per-dash blowup: `2026-08-20-dash-leaf-separation.md:69`
measured the dash fraction moving the frame **6.0x** at fixed drawn geometry.

### The watermark, with the list corrected

Every **scale-dependent** decision is frozen at the reference scale. The
complete set, after a reviewer enumerated every camera read in the painter and
sink:

| decision | where | on the list |
|---|---|---|
| arc / circle / `fillCircle` chord count | `vertices_draw_sink.dart:679`, `:712-716`, `:762` | yes |
| text culling | `draft_painter.dart:906` | yes |
| dash screen clip | `draft_painter.dart:346-351`, `dasher.dart:139` | yes |
| dash period and collapse | `draft_painter.dart:651-654` | moved to the shader |
| viewport cull | `draft_painter.dart:338` | **removed** — collection covers the extents |
| rebase origin | `draft_painter.dart:341` | fixed at the reference collection |
| anisotropy ratio | `draft_painter.dart:540` | correctly excluded — diagnostic only |

**Revision 3's "level of detail" row was wrong.** The painter drops no sub-pixel
*geometry*; level of detail in this codebase **is** `minTextCapPixels`
(`draft_painter.dart:97-98`) — the same mechanism as the text-culling row. Two
rows, one mechanism, and the pre-committed mutation aimed at it collapsed into
the text test. Corrected in the mutation list below.

When the live scale leaves the band around the reference scale, a **rebuild** is
scheduled — the same operation as any other trigger. **The band is not
pre-committed as a number.** Revision 3 fixed it at 4x while also demanding
pixel parity, and a reviewer showed the two cannot both be pre-committed: the
band determines how far the picture may drift, so **the band is an output of the
pixel-parity threshold**, measured by the plan. See criterion 1.

A rebuild never runs on the frame path. If the camera leaves the band
mid-gesture the frame draws with the current collection and the rebuild lands
after settle; that staleness is measured by criterion 9.

### Fills

`fillPolygon` arrives **pre-triangulated** — read, never computed
(`draw_sink.dart:31-47`, `draft_painter.dart:723-744`) — so fills are one
`kind` in the same buffer at their own handle position, and cost no new
geometry work. `fillCircle` is fanned at collection time at the *same* step
count its own outline uses (`vertices_draw_sink.dart:706-716`), which is what
keeps a fill and its outline from disagreeing.

---

## The platform seam

**Bare `flutter_gpu` cannot compile for the web** — `dart:ffi` and
`dart:nativewrappers` at library level. `flutter_scene` ships a conditional
export selecting a verbatim native re-export and a WebGL2 backend on web, and
the spike measured that layer working with this project's shader bundle and
instanced draw under CanvasKit.

**The backend talks to one file of ours, which decides where the GPU API comes
from:** `lib/src/gpu/gpu_facade.dart`. Version one re-exports `flutter_scene`'s
shim — an off-contract `lib/src/` import of a pre-1.0 package, confined to one
file for that reason. **Trigger for taking it in-house:** the first break, or
the first API the shim does not expose. Revision 4 needs no depth attachment and
no MSAA, so the surface it needs is the surface the spike already exercised on
both platforms.

Enablement belongs in the plan: `FLTEnableFlutterGPU` in `Info.plist`,
`io.flutter.embedding.android.EnableFlutterGPU` on Android, nothing on web, and
**`flutter run` exposes no CLI flag**. A platform where enablement fails falls
back to `VerticesDrawSink` and says so once.

**The web rebuild cost is unmeasured, and Decision 1 does not yet hold there.**
A reviewer read the spike's web totals as ~51 ms of upload for 2.89 MB. The
attribution is wrong — the spike's own figures show a large constant, not a
per-byte cost: 19,504 segments cost 51.5 ms total against 84,299 at 64.5 ms, so
4.3x the bytes added 5.6 ms. That constant is shader-library load and pipeline
creation, and native shows the same shape (82.3 ms first run, 6.5 ms warm). But
the conclusion stands in the form that matters: **no measurement here separates
one-time setup from a warm rebuild on web**, so the rebuild budget is native-only
until the plan measures a second rebuild in one session.

---

## Budgets

At **10,000 entities / 59,875 segments**. **Aggregation rule for every timing
gate: median of three interleaved per-repeat p50s, per stage** — the rule the
measurement note states and Plan 3d used. `STATUS.md:21-27` records what
happens without one.

| quantity | measured | budget |
|---|---|---|
| resident geometry, all kinds plus the text list | 2.06 MB strokes-only | **≤ 8 MB**, defined as GPU buffers plus the resident text list, excluding the render target |
| rebuild, platform thread, native | 15.7 ms | **≤ 16.67 ms** — one frame, not 1.2 |
| rebuild, web | **unmeasured** | no budget until measured |
| gesture frame p50 | 0.61 build / 0.63 raster | **≤ 1.2 ms build, ≤ 2.0 ms raster** |
| gesture frame p95 raster | 1.03-1.20 | **≤ 3.0 ms** |

**The headroom is stated rather than implied, because the measured arm is
weaker than the design.** Arm C measured with no joins, no caps, no
antialiasing, no fills, no text and baked dashes, on a corpus with
`labelFraction: 0`. Against that, joins roughly double the instance count, and
the shaded-dash `discard` defeats early-Z. The build budget is 2x the measured
figure and the raster budget 3.2x, and **those multiples are the whole margin** —
if joins and antialiasing consume them, the criterion misses and is recorded as
a miss.

**On the p95 revision 2 called its likeliest failure:** at 2,380,424 segments
the spike recorded arm C's raster p95 as unstable and undiagnosed, 10-13 ms. At
59,875 it reads 1.03-1.20 across three repeats. The instability is a large-scale
phenomenon and this target does not reach it.

---

## Invariants

1. **The frame path allocates nothing per entity in steady state.** The frame
   writes one uniform block, submits *N+1* draw calls, and walks the resident
   text list.
   **The instrument does not exist and revision 3 understated this.**
   `paint_allocation_test.dart:190-216` measures `VerticesDrawSink`-specific
   fields — a growing vertex buffer and `Paint` identity — neither of which a
   resident backend has, and `text_paint_allocation_test.dart:4-12` records that
   `jet_cad_2d_flutter` has *"no `vm_service` dependency and no access to this
   directory's `AllocationMeter`"*. Criterion 4 therefore requires a **new
   mechanism**, and the plan must size it as its own task. The word "flush" is
   dropped: this design has none.
2. **Emission order is preserved.** Not "ascending handle value" — see
   Decision 2.
3. **Geometric decisions use `Tolerance`; stored-value comparisons are exact
   `==`.** Unchanged.
4. **`packages/jet_cad_2d` is untouched.** `DraftPainter` and `DrawSink` are
   already in `jet_cad_2d_flutter`; this design adds no painter API at all.

---

## Testing

Per `CLAUDE.md`, defects surface through **mutation and differential testing**,
and the dominant failure mode is the degenerate fixture. Every fixture is
non-identity, off-origin and non-uniformly scaled.

**The corpus** includes, each because a specific finding above needs it: a leaf
inside a block definition placed at two instances; a mirrored instance; a
non-uniform scale; a dashed polyline and **a dashed arc** at four scales inside
the band; an arc at four scales; **an opaque fill overlapping strokes of both
lower and higher handle**; a translucent fill; **text overlapped by a stroke of
higher handle**; text near the culling threshold; a hairline below one device
pixel; and a `point()`.

**Mutations that must go red:**

- give strokes, joins and fills separate draw calls → the fill-overlap test fails
- draw all text in one pass before or after the geometry → the text-overlap test fails
- expand the stroke quad at collection scale → strokes thicken under zoom
- emit joins as collector geometry at the collection width → miters distort
- skip the seam join → the circle-notch test fails
- route fills through `_coveredArgb` → a filled region on a hairline layer fades
- drop `_coveredArgb` from strokes → hairlines are too dark
- accumulate dash phase along a polyline instead of restarting per vertex → the dashed-polyline test fails
- drop the running phase on arcs → the dashed-arc test fails
- ignore the table revision counter → a layer colour change draws stale
- ignore the `devicePixelRatio` trigger → half-widths are wrong after a display change
- cull collection to the live viewport → panning reveals empty buffer
- read the watermark band against the reference scale instead of the live scale → the four-scale tests fail
- treat `point()` as a zero-length capped stroke → the point test fails
- leave the resident text list stale across a rebuild → an edited label draws the old string

**Removed as equivalent, and recorded rather than deleted:** revision 3's
*"rebuild only when `touched` is non-empty"*. `spatial_index.dart:2283-2287`
states that empty `touched` is *"defensive, not currently reachable"* from any
command, and load and purge are routed on type, so a faithful implementation
survives that mutation. It is declared equivalent here so a later reader does
not mistake its absence for an oversight.

**Web** is measured with a stated instrument. The rig's `FrameTimingLog` refuses
to report on web because ordinal alignment does not hold there. **No web timing
criterion is stated in this gate**, because no instrument for one exists — see
open question 2.

---

## Exit gate

Pre-committed. Thresholds are not moved to make a criterion pass; a miss is
recorded as a miss with its number. Every timing criterion uses the aggregation
rule stated under Budgets.

1. **Pixel differential against `VerticesDrawSink`**, at the reference scale:
   per-channel difference ≤ 2 on ≥ 99.5% of pixels, ≤ 8 on the rest, on
   premultiplied RGBA, **and** differing pixels below 1% of live ink — the
   anti-vacuity floor this repo's comparable gate uses
   (`tile_cache_test.dart:958-959`).
2. **The watermark band is the output of criterion 1, not an input**: the
   reported band is the widest scale ratio at which criterion 1 still holds,
   measured. A band narrower than 2x is a design failure and is reported as one.
3. Emission order survives undo, redo, save, load and purge: a rebuild after
   each renders identically to a rebuild before it.
4. Submitting the buffer out of walk order changes the rendering on the
   fill-overlap corpus, and the test asserts it does.
5. Steady-state frame allocates nothing per entity, through a **new**
   instrument built for the purpose.
6. Resident geometry ≤ 8 MB as defined in Budgets.
7. Rebuild ≤ 16.67 ms on the platform thread, on every one of the five triggers.
8. Gesture p50 ≤ 1.2 ms build and ≤ 2.0 ms raster, **on a corpus containing
   text, fills, joins, caps, dashes and antialiasing**. No waiver.
9. Gesture p95 raster ≤ 3.0 ms; the stale interval after a mid-gesture band exit
   is measured and reported without a threshold.
10. A platform without Flutter GPU falls back to `VerticesDrawSink` exactly
    once, without throwing, through an injectable facade factory that fails on
    demand, with a one-shot observable diagnostic.
11. The text pass costs ≤ 0.5 ms p50 on the criterion-8 corpus, and the *N+1*
    draw-call count is reported.
12. **The zoom settle transition is reproduced on the tiled arm and absent on
    the resident arm.** The target numbers exist: on the tiled arm, across the
    three frames after a twelve-step 1.02 zoom, **25,275 / 16,681 / 0**
    differing pixels against a live reference at the same camera. The resident
    arm must stay flat across the same gesture and settle.
    **The instrument is the rig path, not the widget boundary** — `toImage`
    asserts on `!debugNeedsPaint` and these are exactly the dirty states, which
    cost the probe its first attempt. And it compares against a live reference
    at the same camera, never against a predecessor frame: criterion 9 accepts
    a post-settle rebuild that changes pixels with no camera change, so a
    predecessor test would fire on both arms.
13. Web renders the criterion-1 corpus under CanvasKit and Skwasm within
    criterion 1's thresholds, measured on that platform against a reference
    rendered on that platform.
14. Every mutation above goes red; the declared equivalent mutation is recorded
    as equivalent.

---

## Open questions

1. ~~**Which settle defect is the human seeing?**~~ **Measured** — see the
   probe note. A zoom flickers over three frames; a pan does not flicker at
   all. **What remains open is narrower and it is the human's to answer:** the
   product report said "pan and zoom", and the pan half is not reproducible on
   this fixture. Does the observed pan flicker survive a deliberate
   pan-only gesture, or was it a combined pan-and-zoom? And does a 141.7%-of-ink
   three-frame transition read as a flicker or as a sharpen? The second question
   is perceptual and no measurement settles it.
2. **The web timing instrument.** No web timing criterion is in the gate because
   none can be stated. Criterion 13 is correctness-only.
3. **The reference scale**, and the band that follows from it (criterion 2).
4. **Warm rebuild cost on web**, which Decision 1 needs and no measurement
   separates from one-time setup.
5. **Skwasm.** Criterion 13 names it and nothing has been run there.
6. **Arm B's 46-47 ms max build on a web zoom.** A defect in the shipping tile
   cache, not in this design; it needs its own investigation.
