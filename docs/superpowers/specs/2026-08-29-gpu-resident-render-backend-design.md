# A GPU-resident render backend — design

**Date:** 2026-08-29. **Status:** design, **revision 3**, not yet a plan.
**Target scale: 10,000 entities**, set by the human on 2026-08-29.
**Evidence base:** [2026-08-29-flutter-gpu-backend-spike.md](../notes/2026-08-29-flutter-gpu-backend-spike.md),
plus a 10,000-entity measurement taken for this revision and recorded below.

**Revision 3 is much smaller than revision 2, and the scale is the whole
reason.** Revision 2 was sized for 500,000 entities and spent most of its length
on incremental editing: occurrence identity, a dirty closure, an
occurrence-scoped walk, a depth buffer, a rank-allocation algorithm and a byte
ledger. At 10,000 entities a **full rebuild costs 15.7 ms — one frame — and
every one of those mechanisms becomes unnecessary.** They are removed, not
deferred. Three independent reviews of revision 2 found four structural
defects; three of them lived in machinery this revision deletes, and the fourth
is fixed below.

---

## The scale, and what it does to the case for this work

`roadmap/00-README.md` puts a floor plan at 500 to 5,000 entities and calls the
render layer *"done, and over-built for this target"*. The target here is
**10,000** — that roadmap's ceiling, doubled, as headroom.

**Measured at 10,000 entities**, macOS profile, 1400x900, 59,875 segments,
three interleaved repeats, zoom phase, p50 build / raster in ms:

| arm | zoom p50 | zoom p95 build | what it is |
|---|---|---|---|
| **A painter (untiled)** | 8.71/4.25 · 7.44/3.73 · 7.54/3.64 → **~11.3 ms** | 10.27 · 10.55 · **12.35** | today's default |
| **B tiles (blit)** | 0.30/0.77 → **~1.1 ms** | 0.51 | today's gesture path, **blurry while moving** |
| **C flutter_gpu** | 0.63/0.63 · 0.61/0.65 · 0.32/0.26 → **~0.9 ms** | 0.99 | this design |

**The case for the work, stated honestly, is two-sided.**

*For it:* the untiled painter sits at 68% of the 16.67 ms budget at p50 and
**exceeds it at p95** — build p95 reaches 12.35 ms and raster adds ~4 — on a
fast desktop in profile mode. A weaker device has no headroom at all, and every
millisecond the frame spends walking the document is a millisecond the unwritten
interaction and tool layers cannot have.

*Against it:* **arm B already costs what arm C costs at this scale** — 1.1 ms
against 0.9 ms. The tile cache is shipping today and it solves the *cost*
problem at 10,000 entities.

**What it does not solve is the settle, and that is this design's primary
motivation.** The human, using the running product, reports **a visible flicker
after every pan and zoom**. That is not a new discovery so much as the
remainder of a defect this repository has already fought twice: Plan 3i's
ledger records that *"`paintFrame` blits the composite first and underneath"*,
and `a79903b` — *"the frame a zoom stops on still carried the composite"* — is
the fix for one arm of it. The instruments were, in that ledger's own words,
blind to it.

**The reason a resident backend removes it is structural, not incremental.**
The tile path has two representations of the same drawing — a magnified
composite during the gesture and freshly baked tiles after it — and a flicker
is the frame on which one is exchanged for the other. **A resident backend has
one representation.** Every frame, moving or still, draws the same geometry
through the same pipeline; there is no bake, no composite, and therefore no
frame at which the picture changes kind. The defect cannot recur because the
thing that causes it does not exist.

Three further differences follow the same way:

1. **The gesture stays sharp.** B blits a magnified bitmap; the drawing goes
   soft for the length of every pan and zoom.
2. **No composite to hold.** B's composite is ~20 MB; C's resident geometry at
   this scale is **2.06 MB**.
3. **No bake spikes.** The spike's web arm measured B at a **46-47 ms max
   build** on a zoom, in both repeats, against C's 4.40.

**The flicker is a reported observation, not yet a measurement**, and the plan
owes it one: reproduce it on the tiled arm, then show its absence on the
resident arm. Criterion 14 is that test. A design motivated by a defect nobody
has captured is a design resting on an anecdote.

---

## The question this answers

`DraftPainter.paint(sink, camera, viewport)` folds the camera into the residual
chain, so every vertex a sink receives is in screen space and **the whole
document is re-walked the moment the camera moves**.

> Make a pan or a zoom cost a **uniform write** instead of a **document walk**,
> without giving the picture up to a bitmap.

At this scale the answer's shape is simple: **move the walk from every frame to
every edit.** The walk costs 14.7 ms and happens on change; the frame costs
0.9 ms and happens sixty times a second. Camera movement is constant; editing
is not.

## Non-goals

- **Replacing `VerticesDrawSink`.** It stays the default and the fallback.
- **Changing the document model.** `packages/jet_cad_2d` is untouched.
- **Incremental geometry update.** Explicitly out of scope at this scale — see
  the rebuild decision below. If the target grows past ~50,000 entities this
  spec is wrong and revision 2's machinery is what replaces it.
- **A scene graph, or culling, or a tile cache of our own.**

---

## The two decisions everything else follows from

### 1. Any change is a full rebuild

**Measured: the collection walk is 14.7 ms and the upload is 1.0 ms at 10,000
entities.** That is one frame. So the backend does not track what changed.

| signal | response |
|---|---|
| `CommandApplied` / `Undone` / `Redone`, any `touched` | rebuild |
| `DocumentLoaded`, `DocumentPurged` | rebuild |
| **table revision counter** (`tables.dart`) | rebuild |
| watermark exit (below) | rebuild |

**The table row is not padding, and revision 2 got this wrong before a reviewer
caught it.** `tables.dart:559` states it plainly: *"Table mutations reach the
command system not at all. `DocChange` is emitted only by `undo.dart`."*
`DraftCanvas` merges a separate table listenable for exactly this reason —
without it a layer colour change produces no signal of any kind. A
`DocChange`-only backend draws stale after every layer edit.

An unconditional rebuild also makes the empty-`touched` case correct for free.
`doc_change.dart:12` defines an empty set as "the whole document changed", and a
design that reads `touched` at all has to remember that; one that ignores it
cannot get it wrong.

**What this deletes from revision 2:** occurrence identity, the `bySource`
dirty closure, the occurrence-scoped walk (which the reviews correctly sized as
a new public painter API or a refactor of its private methods), and the
whole-document-versus-handle reasoning. None of it is needed to rebuild
everything.

**The cost, stated:** an edit costs one frame. During a live drag-edit that is
~15 ms per frame — which is **no worse than today**, because the untiled
painter already walks the document every frame at 11.3 ms and the tiled path
rebakes. It is a real ceiling and it is the reason the non-goal above names
50,000 entities.

### 2. No depth buffer, because submission order is emission order

Revision 2's keystone was a depth code per occurrence, so that buffer order
could stop meaning anything. **That entire apparatus existed to make
incremental edits safe.** With a full rebuild, the buffer is written in walk
order and submitted in walk order, so **draw order is ascending handle value
because the walk emits it that way** — exactly as the spike ran, and the spike's
drawing was verified correct by screenshot on both platforms.

**What this deletes:** the depth attachment, `d24UnormS8Uint` and the
uniform-versus-float reasoning, integer depth codes, the order-maintenance
rank allocator, the rank-occupancy limit, and the relabel-rate criterion.

It also deletes a risk the reviews were right to raise: **the spike ran with no
depth attachment on any platform**, so revision 2's keystone rested on an
unmeasured feature reached through a pre-1.0 shim. Revision 3 does not need it.

**And it dissolves the antialiasing contradiction.** Revision 2 specified both
"blend off" and a fragment-shader coverage fade, which are mutually exclusive,
and had to reach for MSAA to reconcile them. With no depth test there is
nothing to keep order-independent: **blending in submission order is what
`VerticesDrawSink` already does**, and matching the reference is both simpler
and exactly what the pixel-parity criterion asks for.

---

## Architecture

### Collection is a `DrawSink` that stops running per frame

`RecordingDrawSink` equality is the project's primary correctness mechanism and
the spike showed a collector implementing `DrawSink` produces correct geometry
with the residual applied. Collection is that collector, driven by the existing
`DraftPainter.paint`, called on rebuild.

**No new painter API is required.** This is the largest practical difference
from revision 2, and it follows directly from rebuilding rather than patching.

### Where the quad is built: the shader, always

The stroke half-width is a **device-pixel** quantity
(`vertices_draw_sink.dart:66`) and the lineweight is paper-space 1/100 mm,
explicitly *"not a world quantity"* (`resolved_style.dart:18`). It is invariant
under zoom, so **any quad expanded at collection time thickens with the
camera.**

The instance record therefore carries a **centerline and a device half-width,
and all expansion happens in the vertex shader.** This is what the spike did;
revision 1 failed to say so and revision 2's reviewers caught it.

The consequence, which revision 2 also got wrong: **joins and caps cannot be
collector-emitted geometry either**, because a miter is a function of the device
half-width and would distort the same way.

- **Caps**: a per-instance flag; the shader extends the quad along the
  centerline by the half-width.
- **Joins**: their own instance kind and pipeline — the shared vertex plus two
  unit directions, with the wedge built at the live width. Mirrors
  `VerticesDrawSink._emitJoin` including the **seam join**, whose absence that
  file records as putting a notch on every circle.

### Dashes are shaded, not collected

`draft_painter.dart:630` dashes at `_dashScale(style, toScreen)` — the
segmentation depends on the live screen scale, so collected spans stretch with
the drawing and collapse to solid at small scale without recovering.

The instance carries the pattern's **period and phase in paper-space units**;
the fragment shader computes arc length along the segment, converts with the
camera-scale uniform, and discards gaps. `collapsedDashCount`'s
collapse-to-solid rule becomes a shader branch on the same threshold.

This is chosen over rebuilding on scale change for two reasons: it is exact at
every scale, and **it removes the span-per-dash geometry blowup**. The repo's
own measurement found the dash fraction moved the frame 6x at fixed drawn
geometry; a shaded dash emits one instance per polyline segment regardless of
pattern.

### Everything else scale-dependent is served by one watermark

**Every screen-space decision the painter makes is frozen at the camera the
collection ran under.** Revision 1 saw only arcs and treated it as a special
case. The complete list, after dashes move to the shader:

| decision | where | frozen consequence |
|---|---|---|
| arc and circle chord count | sagitta bound, `DrawSink.fillCircle` doc | chords visible on zoom-in |
| level of detail | painter drops sub-pixel geometry | **dropped geometry never reappears on zoom-in** |
| text culling | `draft_painter.dart:906` | culled text never reappears |
| float32 coordinate resolution | buffer holds collection-camera screen space | quantization visible past deep zoom |

One mechanism serves all four: the backend records its collection scale, and
when the live scale leaves the band `[s/4, s*4]` it schedules a **rebuild** —
the same operation as any other change, at the same measured 15.7 ms.

The float32 row is not a separate constraint: coordinates stored in
collection-camera screen space give roughly 1e-4 px over a 1e3 px extent, so the
supported zoom range and the watermark band are **the same bound**, and a
rebuild re-establishes precision at the new scale.

**The 4x band is pre-committed and the plan must measure it**, not inherit it.
A rebuild never runs on the frame path: if the camera leaves the band mid-
gesture, the frame draws with the stale collection and the rebuild lands after
settle. **That staleness is visible and it is this design's accepted cost**;
criterion 9 measures it.

### Fills

`DrawSink.fillPolygon` arrives **pre-triangulated** — computed once, off the
frame path, precisely so a batching sink can use it. Fills get their own
instance buffer and a trivial pipeline, and cost no new geometry work.
`fillCircle` is fanned at collection time under the watermark.

### Text is a resident list, not the walk

Revision 2 said text would be drawn by "a second Canvas pass driven by the
existing path", and **the existing path is the document walk** — calling it per
frame reinstates the O(document) term the design exists to remove.

Collection produces a **resident text-occurrence list**: composed transform,
string and style handle for every text op that survived. The per-frame Canvas
pass walks that list. Its cost is O(visible text).

Text culling reads the live scale, so it is on the watermark's list above.

---

## The platform seam

**Bare `flutter_gpu` cannot compile for the web** — it imports `dart:ffi` and
`dart:nativewrappers` at library level. `flutter_scene` ships a conditional
export selecting a verbatim re-export on native and a WebGL2 implementation on
web, and the spike measured that layer working with this project's own shader
bundle and instanced draw, on CanvasKit.

**The backend talks to exactly one file of ours, and that file decides where the
GPU API comes from:**

```
lib/src/gpu/gpu_facade.dart     ← the only file that imports a GPU package
```

Version one has the facade re-export `flutter_scene`'s shim — an off-contract
`lib/src/` import of a pre-1.0 package, confined to one file for that reason.
The alternative is our own conditional export over our own WebGL2 backend,
which is smaller for this project than `flutter_scene`'s 130 KB because they
need a general GLSL transpiler for arbitrary user shaders and this project has
a handful of hand-written ones.

**Pre-committed trigger for taking it in-house:** the first time a
`flutter_scene` minor release breaks the facade, or the first time the backend
needs an API the shim does not expose. **Revision 3 needs no depth attachment
and no MSAA, so the API surface it needs is the surface the spike already
exercised on both platforms** — which is the main thing that makes this seam
low-risk now and did not in revision 2.

Enablement belongs in the plan: `FLTEnableFlutterGPU` in `Info.plist` on
iOS/macOS, `io.flutter.embedding.android.EnableFlutterGPU` in
`AndroidManifest.xml` on Android, nothing on web, and **`flutter run` exposes no
CLI flag**. A platform where enablement fails falls back to `VerticesDrawSink`
and says so once.

Two API traps the spike hit: `createImageSurface`'s optional format argument is
mandatory in fact — its default resolves to `PixelFormat.unknown` on macOS
Metal — and the web backend has no `createImageSurface`, so the render target
is a `Texture`. `ShaderLibrary.fromAsset` throws on web;
`loadShaderLibraryAsync` exists on both.

---

## Budgets

All at **10,000 entities / 59,875 segments**, the measured corpus.

| quantity | measured | budget | note |
|---|---|---|---|
| resident geometry | **2.06 MB** (spike record) | **≤ 8 MB** with joins, caps and fills | four times the measured stroke buffer; joins run roughly one per segment and the shaded-dash change reduces segment count |
| rebuild, platform thread | **15.7 ms** (14.7 walk + 1.0 upload) | **≤ 20 ms** | one frame. No isolate, and revision 2's `FlutterTextMeasurer` isolate collision therefore does not arise |
| gesture frame p50 | 0.32-0.63 build / 0.26-0.65 raster | **≤ 1.0 ms build, ≤ 2.0 ms raster** | derived from the measurement above, with headroom for joins, caps, dashes, fills and the text pass |
| gesture frame p95 | 0.87-0.99 build / 1.03-1.20 raster | **≤ 3.0 ms raster** | see below |

**On the p95 that revision 2 called its likeliest failure:** at 500,000 entities
the spike recorded arm C's raster p95 as unstable and undiagnosed, 10-13 ms.
**At 10,000 entities the same arm reads 1.03-1.20 ms across three repeats**,
tight and stable. The instability is a large-scale phenomenon and this target
does not reach it. It stays an open question rather than a gate, and the plan
should not spend a task on it.

The memory and load budgets that dominated revision 2 are, at this scale,
**2.06 MB and 15.7 ms**. They are recorded so a later reader can see how much of
that document was scale and not substance.

---

## Invariants this must not break

1. **The frame path allocates nothing per entity in steady state, O(1) per
   flush.** The steady-state frame writes one uniform block, submits, and walks
   the resident text list. `paint_allocation_test.dart` is extended to cover it,
   and the text list walk must be shown O(visible text) with no per-entity
   allocation.
2. **Draw order is ascending handle value**, stable across undo, save, load and
   purge. Here it holds because the buffer is written and submitted in walk
   order — so the test is that a rebuild after each of those five operations
   produces an identical rendering.
3. **Geometric decisions use `Tolerance`; stored-value comparisons are exact
   `==`.** Unchanged; the collector inherits the painter's decisions.
4. **`packages/jet_cad_2d` is untouched.** `DraftPainter` and `DrawSink` already
   live in `jet_cad_2d_flutter` and `paint` takes `dart:ui`'s `Size`, so
   everything here is Flutter-side. Revision 3 adds no painter API at all.

---

## Testing

Per `CLAUDE.md`, defects surface through **mutation and differential testing**,
and the dominant failure mode is the degenerate fixture. Every fixture is
non-identity, off-origin and non-uniformly scaled, and the corpus includes **a
leaf inside a block definition placed at two instances** — not because this
revision keys anything by occurrence, but because that fixture is what catches a
collector that flattens the instance path.

**Differential, against `VerticesDrawSink`:** rendered-pixel comparison on a
corpus with a mirrored instance, a non-uniform scale, a dashed leaf at four zoom
levels, a translucent fill, an arc at four zoom levels, and text near the
culling threshold.

**Mutations that must go red** (pre-committed; the plan owns the full log):

- expand the stroke quad at collection scale → strokes thicken under zoom
- emit joins as collector geometry at the collection width → miters distort
- skip the seam join → the circle-notch test fails
- bake dash spans instead of shading them → the four-zoom dashed test fails
- ignore the table revision counter → a layer colour change draws stale
- rebuild only when `touched` is non-empty → the whole-document arm fails
- widen the watermark band to infinity → the four-zoom arc, LOD and text tests
  fail
- collect under an identity camera → level-of-detail test fails
- submit slabs out of walk order → draw-order test fails **(this is the test
  that stands in for revision 2's depth buffer: order is now a property of the
  submission, so it must be asserted directly)**

**Web is measured with a stated instrument.** The rig's `FrameTimingLog` refuses
to report on web because ordinal alignment does not hold there, and the spike
relaxed it to a distribution over the phase window. A comparative gate may not
rest on the relaxed instrument. One nuance carries: the spike recorded arm C at
**excess 0 in every web phase** while arms A and B slipped, so the relaxation
did not touch arm C's own figures.

---

## Exit gate

Pre-committed. Thresholds are not moved to make a criterion pass; a miss is
recorded as a miss with its number.

1. Pixel differential against `VerticesDrawSink`: **per-channel difference ≤ 2
   on ≥ 99.5% of pixels and ≤ 8 on the rest**, on premultiplied RGBA, with
   **separate baselines for native and web** because the rasterizers differ.
2. Draw order survives undo, redo, save, load and purge — a rebuild after each
   renders identically.
3. Submitting slabs out of walk order changes the rendering, and the test
   asserts it does. (The inverse of criterion 2, and the reason this design can
   drop the depth buffer.)
4. Steady-state frame allocates nothing per entity, O(1) per flush, including
   the text pass.
5. Resident geometry ≤ 8 MB at 10,000 entities with joins, caps and fills.
6. Rebuild ≤ 20 ms on the platform thread at 10,000 entities, on every one of
   the four rebuild triggers.
7. Gesture p50 ≤ 1.0 ms build and ≤ 2.0 ms raster on the full pipeline.
8. Gesture p95 ≤ 3.0 ms raster.
9. Crossing the watermark band during a gesture drops no frame; the rebuild
   lands after settle, and the stale interval is measured and reported.
10. A platform without Flutter GPU falls back to `VerticesDrawSink` exactly
    once, without throwing. **Tested through an injectable facade factory that
    fails on demand**, with a one-shot observable diagnostic — hardware or
    plist failure is not a deterministic fixture.
11. Web renders the differential corpus correctly under CanvasKit **and**
    Skwasm.
12. The text pass costs ≤ 0.5 ms p50 on a text-bearing corpus, or the corpus
    used for criteria 7 and 8 states that it excludes text.
13. Every mutation above goes red.
14. **The settle flicker is reproduced on the tiled arm and absent on the
    resident arm.** A pixel differential across the frames spanning the end of
    a gesture: the tiled arm shows a frame whose pixels differ from its
    predecessor by more than the pixel-parity threshold with no camera change
    between them, and the resident arm shows none. This criterion carries the
    design's stated motivation, so a miss on the *first* half — failing to
    reproduce the flicker under measurement — invalidates the motivation and
    is reported as such, not quietly dropped.

---

## Open questions

1. ~~**Is sharpness during a gesture worth this work, given that arm B already
   costs what arm C costs at this scale?**~~ **Answered by the human on
   2026-08-29:** the tiled path flickers visibly after every pan and zoom, and
   that settle transition is the motivation. See the top. What remains is not a
   judgement but a test — criterion 14.
2. **The web timing instrument.** No comparative web criterion may rest on the
   relaxed unaligned instrument.
3. **Skwasm.** Criterion 11 names it and nothing has been run there.
4. **Arm B's 46-47 ms max build on a web zoom**, found by the spike's web arm.
   A defect in the *shipping* tile cache, not in this design, and it needs its
   own investigation rather than being absorbed here.

Revision 2's open questions about the depth attachment, MSAA, and the isolate
collision are **closed by deletion** — this revision needs none of the three.
