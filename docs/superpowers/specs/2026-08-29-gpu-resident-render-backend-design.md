# A GPU-resident render backend — design

**Date:** 2026-08-29. **Status:** design, **revision 2**, not yet a plan.
**Evidence base:** [2026-08-29-flutter-gpu-backend-spike.md](../notes/2026-08-29-flutter-gpu-backend-spike.md).

**Revision 2 was written from three independent reviews of revision 1.** Every
finding they raised was checked against the code and every one of them held.
Four were structural — occurrence identity, table-driven changes, where the
stroke quad is built, and antialiasing contradicting the opaque pass — and they
changed the design rather than the wording. What survived unchanged is the
spine: collection as a `DrawSink`, rank as depth, two-pass transparency, and
the one-file platform facade.

---

## Two things to check before reading further

**1. This spec is opened against the roadmap's own stated judgement, on the
human's explicit instruction.** `roadmap/00-README.md` says the render layer is
*"done, and over-built for this target"*, that a floor plan is 500 to 5,000
entities, and that *"the engine is not the risk; the risk is the three
unwritten layers"*. This spec's own evidence agrees: at 1,500 entities the
existing painter draws a zoom frame in about 6 ms against a 16.67 ms budget,
and the GPU arm's advantage does not open until roughly 15,000 entities. The
objection was raised and the human reaffirmed the work.

**2. The scale is an assumption and it gates everything below.** This is sized
for **10,000 to 500,000 entities** — imported DXF drawings and site-scale
plans. **If the real target is the roadmap's 500-5,000, the correct action is
to close this spec, not to plan it**, and most of revision 2's added
complexity exists only to serve the larger number. Every threshold below is
derived from that assumption and moves with it. Settle this before anything
else.

---

## The question this answers

`DraftPainter.paint(sink, camera, viewport)` folds the camera into the residual
chain it hands a sink, so every vertex a sink receives is in screen space and
**the whole document is re-walked the moment the camera moves**. Plan 3g's tile
cache hides that walk during a gesture by blitting a magnified bitmap; the
drawing goes soft while the gesture lasts. The vector-replay spike priced the
sharp alternative on the CPU at **22.9x the blit** and rejected it.

> Make a pan or a zoom cost a **uniform write** instead of a **document walk**,
> without giving up the picture.

At 2,380,424 segments the spike's per-frame CPU cost was **0.17-0.26 ms and
flat**, against **383 ms** for the walk, and it held on the web. What the spike
did not build is everything that makes it a backend rather than an arm.

## Non-goals

- **Replacing `VerticesDrawSink`.** It stays the default and the fallback.
- **Changing the document model.** `packages/jet_cad_2d` is untouched.
- **A scene graph.** See the spike note for why `flutter_scene`'s instancing
  model does not fit.
- **Pixel-for-pixel parity with the painter.** Bounded explicitly in the exit
  gate, not claimed generally.

---

## The governing principle revision 1 missed

**Every screen-space decision the painter makes is frozen at the camera the
collection ran under.** Revision 1 found one instance of this — arc
tessellation — built a watermark for it, and treated it as a special case. It
is not a special case. It is the design's central hazard, and the complete list
is:

| decision | where | frozen consequence |
|---|---|---|
| arc and circle chord count | `DrawSink.fillCircle` doc; sagitta bound | chords visible on zoom-in |
| dash segmentation | `draft_painter.dart:630`, `_dashScale(style, toScreen)` | pattern stretches with the drawing; collapses to solid at small scale and never recovers |
| level of detail | painter drops sub-pixel geometry at the collection scale | **dropped geometry never reappears on zoom-in** |
| text culling | `draft_painter.dart:906`, `layout.height * chain.scaleMagnitude < minTextCapPixels` | culled text never reappears |
| float32 coordinate resolution | buffer stores fit-camera screen space | quantization visible past deep zoom |

**One mechanism serves all of them: the collection watermark.** The backend
records the scale its collection ran under. When the live camera's scale leaves
the band `[collectionScale / 4, collectionScale * 4]`, a **re-collection** is
scheduled at the new scale — the same operation as a load, on the same
machinery, off the frame path. Within the band, the frame is a uniform write.

Two of the five are removed from the list instead of being served by it:

- **Dashes move into the shader.** The instance carries the centerline plus the
  pattern's period and phase in **paper-space** units; the fragment shader
  computes arc length along the segment, converts with the camera-scale
  uniform, and discards gaps. This is strictly better than re-collecting: it is
  exact at every scale and it removes the span-per-dash geometry blowup that
  makes dashed documents expensive today. `collapsedDashCount`'s
  collapse-to-solid rule becomes a shader branch on the same threshold.
- **Float32 resolution is bounded, not fixed.** Coordinates are stored relative
  to the collection camera's screen space, which gives roughly 1e-4 px over a
  1e3 px extent. **The supported zoom range is therefore ±4x from the
  collection scale**, which the watermark already enforces, and re-collection
  re-establishes precision at the new scale. The two constraints are the same
  constraint.

Arcs, level of detail and text culling are served by the watermark.

**The 4x band is a pre-committed number and the plan must measure it**, not
inherit it: too wide and the picture is wrong inside the band, too narrow and a
gesture triggers re-collection mid-flight. The re-collection must never run on
the frame path; if the camera leaves the band during a gesture, the frame draws
with the stale collection and the re-collection lands after the gesture
settles. **That staleness is visible and it is the design's accepted cost**,
and criterion 13 measures it.

---

## Architecture

### Collection stays a `DrawSink`, and stops being per-frame

The backend adds no fourth `DrawSink`. `RecordingDrawSink` equality is the
project's primary correctness mechanism, and the spike showed a collector
implementing `DrawSink` produces correct geometry with the residual applied. So
collection is a `DrawSink` driven by `DraftPainter.paint`, called **on document
change and on watermark exit**, not per frame.

### Identity is the occurrence, not the handle

**Revision 1 keyed slabs by `Handle` and that is wrong.** `DraftPainter` emits a
leaf through two different call sites — `draft_painter.dart:568` and `:712` —
each with a different accumulated `chain`, so a leaf inside a block definition
is emitted **once per instance path**, with a different transform and possibly a
different inherited style each time. A leaf handle names none of those
expansions.

**The unit of residency is the occurrence:**

```
OccurrenceKey = (instancePath, leafHandle)
```

where `instancePath` is the chain of instance handles from the root to the
leaf. The backend keeps two structures:

1. `slabs: Map<OccurrenceKey, Slab>` — the GPU-resident geometry.
2. `bySource: Map<Handle, Set<OccurrenceKey>>` — the **dirty closure**: for
   every handle that can appear in a change signal, the occurrences it affects.

`bySource` is what makes an edit to a definition leaf reach all of its placed
copies. Building and maintaining it is the piece the spike note predicted would
be "harder than it looks", and it is now named rather than implied.

### Draw order becomes a depth value, and the rank is per occurrence

**Draw order is ascending handle value, stable across undo, save, load and
purge** (`draft_document.dart:317`). Reading that as "buffer order equals handle
order" makes every size-changing edit a memmove of everything after it.

Instead, **each occurrence gets a depth code equal to its rank in the walk's
emission order**, and every primitive in that occurrence carries the same code.
Pass 1 runs depth write on, depth test on, `CompareFunction.greaterEqual`, so
the fragment that survives is the one the painter would have drawn last.
Submission order stops mattering.

**One code per occurrence, not per primitive, and the reason matters.** Within
one occurrence every primitive shares a single `ResolvedStyle`, so intra-
occurrence overlap — a join over its own segment — is same-colour and its
ordering is invisible. Ranking per primitive would buy nothing and would cost
the rank space a factor of three or more.

**Rank space, with a number.** `d24UnormS8Uint` gives 2^24 codes spaced
uniformly over [0, 1], and code 0 is the cleared background, so **16,777,215
codes are usable**. Ranks are uniform, so a uniform encoding is the right one;
`d32FloatS8UInt` has more bits but spends them non-uniformly, dense near 0 and
sparse near 1, and mapping uniform ranks onto it wastes precision at one end
and runs short at the other. Depth is written as an **integer code**, not a
float ratio, so adjacent ranks cannot quantize together.

### Rank allocation is order maintenance, and it gets an algorithm

Revision 1 said a growing slab "borrows from a gap". That is not an algorithm:
the gap must lie between that occurrence's immediate predecessor and successor,
and a global free count says nothing about that.

This is the **list-labeling / order-maintenance** problem, and it gets the
standard solution:

- At build time, occurrences are labelled with a **stride** — the usable code
  space divided by the occurrence count, floored to a power of two.
- An inserted occurrence takes the midpoint of its neighbours' codes.
- When neighbours are adjacent, **relabel a bounded window**: double the window
  around the insertion point until it contains enough slack, then redistribute
  evenly within it. Amortized O(log n) relabels per insert.
- Only when the window reaches the whole document does it become a full
  rebuild — the same operation as `DocumentLoaded`, which the design already
  supports.

**Occupancy is the constraint that decides whether this holds.** At the design's
top scale the occurrence count is roughly 700,000, giving a stride near 24. That
is workable. **At three million occurrences the stride falls to 5 and inserts
relabel constantly**, so the backend must refuse above a stated occupancy and
fall back rather than thrash. Criterion 14 measures the relabel rate under an
edit workload; the number is not assumed.

**A rebuild or a wide relabel must not fire on the frame path.** It is
scheduled like a re-collection, and a gesture in flight draws with the current
labels. Criteria 8 and 9 exclude frames in which a rebuild landed, and say so.

### Transparency is a second, ordered pass

`ResolvedStyle.argb` carries alpha (`255 - transparency`). Depth gives the
correct opaque result in any order; blending does not commute.

- **Pass 1 — opaque** (`alpha == 255`): depth write on, depth test on, **blend
  off**, any submission order.
- **Pass 2 — translucent** (`alpha < 255`): depth **test** on against pass 1,
  depth **write off**, blend on, submitted in ascending rank.

If a document's translucent fraction exceeds **5%**, pass 2's cost must be
measured before the backend claims the frame. A stop clause, not a target.

### Antialiasing is MSAA, because coverage-fade contradicts pass 1

**Revision 1 specified both "blend off" and "the fragment shader fades the outer
edge", and those are mutually exclusive.** An alpha fade *is* blending; with
blend off a faded edge writes solid colour and there is no antialiasing at all.
Turning blend on for pass 1 reintroduces the order dependence the depth
keystone exists to remove, at every soft edge where two strokes overlap.

**Decision: MSAA on the transient colour target, blend stays off.** Coverage
resolves in the resolve step rather than through the blend equation, so pass 1
keeps order independence and gets antialiased edges. It also removes the
second half of the problem: a segment quad and its join quad overlap, and two
independently blended coverage fades leave a visible seam down every joint,
whereas two MSAA-covered primitives at the same depth and colour resolve
cleanly.

**The sample count is 4 and it is a measured cost, not a free one.** It
multiplies colour and depth bandwidth on the largest target in the frame, and
the raster budget below is stated as provisional for exactly this reason.
Alpha-to-coverage is the fallback if 4x MSAA misses the budget; it is cheaper
and its quality on thin strokes is worse, and choosing between them is
criterion 2's job rather than this document's.

### Where the quad is built: the shader, always

**This was the largest unstated mechanism in revision 1.** The stroke half-width
is a **device-pixel** quantity — `vertices_draw_sink.dart:66`, and
`resolved_style.dart:18` says the lineweight is paper-space 1/100 mm and
explicitly "**not** a world quantity". It is therefore invariant under zoom. Any
quad expanded at collection time thickens with the camera.

So: **the instance record carries a centerline and a device half-width, and all
expansion happens in the vertex shader.** This is what the spike already did;
revision 1 simply failed to say so.

The consequence revision 1 got wrong: **joins and caps cannot be "emitted as
additional instances by the collector"**, because a miter's geometry is a
function of the device half-width and would distort exactly like a baked quad.

- **Caps** are a per-instance flag; the shader extends the quad along the
  centerline by the half-width.
- **Joins** are their own instance kind and their own pipeline: the record is
  the shared vertex plus the two unit directions, and the shader builds the
  wedge at the live device half-width. This mirrors
  `VerticesDrawSink._emitJoin`, including the **seam join**, whose absence that
  file records as putting a notch on every circle.

### Fills

`DrawSink.fillPolygon` arrives **pre-triangulated** — computed once, off the
frame path, precisely so a batching sink can use it. Fills get their own
instance buffer and a trivial pipeline (position, colour, depth code) and cost
no new geometry work. `fillCircle` is fanned at collection time under the
watermark.

### Text is a resident occurrence list, not "the existing path"

Revision 1 said text would be drawn by "a second Canvas pass driven by the
existing path". **The existing path is the document walk**, and calling it per
frame reinstates the O(document) term this design exists to remove.

Instead, collection produces a **resident text-occurrence list** — the composed
transform, the string and the style handle for every text op that survived
collection — and the per-frame Canvas pass walks that list, not the document.
Its cost is O(visible text), not O(document).

Text culling reads the live scale (`draft_painter.dart:906`), so it is on the
watermark's list: text culled at the collection scale reappears only after
re-collection. Criterion 15 bounds the text pass and the exit gate states
whether the 500,000-entity corpus contains text.

### Dirty tracking

Revision 1's table listed only `DocChange` and was **wrong**, not merely
incomplete. `tables.dart:559` states it plainly: *"Table mutations reach the
command system not at all. `DocChange` is emitted only by `undo.dart`."*
`DraftCanvas` merges a separate table listenable for exactly this reason, and
without it a layer colour change produces no signal of any kind.

The backend therefore consumes **three** signals:

| signal | response |
|---|---|
| `CommandApplied` / `Undone` / `Redone` with `touched` non-empty | re-collect the occurrence closure `bySource[h]` for every touched `h` |
| **any of those with `touched` empty** | **full rebuild** — `doc_change.dart:12` defines an empty set as "the whole document changed", and the tile cache has a shipping regression test for this arm |
| `DocumentLoaded`, `DocumentPurged` | full rebuild; a purge rewrites slots, so every key is invalid |
| **table revision counter** (`tables.dart`) | **v1: full rebuild.** A style-to-occurrence reverse index is an optimization, and it is not version one's job |

**A re-collection of one occurrence still needs the painter**, which walks the
document rather than an occurrence. This design therefore needs a
**occurrence-scoped walk** producing, for a given occurrence set, exactly the
emissions a full walk would produce for them, in the same relative order. That
equivalence is criterion 1, a differential test, not an argument.

`DraftPainter`'s per-entity machinery (`_drawInstance`, `_drawContainer`,
`_drawLeafComposed`) is entirely private today, so this is a new public entry
point or a refactor of those methods — not a small addition, and the plan
should size it as such.

### Culling: none in version one, with the measurement that says so

The spike drew all 2,380,424 segments every frame with no culling and a zoom
raster of **1.00-3.46 ms**. Culling is therefore not required to meet the
budget at the stated top scale. **Pre-committed threshold for revisiting: a p50
raster above 6 ms on the reference gesture.** The depth decision already made
it safe to add.

---

## The platform seam

**Bare `flutter_gpu` cannot compile for the web** — it imports `dart:ffi` and
`dart:nativewrappers` at library level. `flutter_scene` solves this with a
conditional export selecting a verbatim re-export on native and a WebGL2
implementation on web, and the spike measured that layer working with this
project's own shader bundle and instanced draw.

**Decision: the backend talks to exactly one file of ours, and that file
decides where the GPU API comes from.**

```
lib/src/gpu/gpu_facade.dart     ← the only file that imports a GPU package
lib/src/gpu/…                   ← everything else imports the facade
```

Version one has the facade re-export `flutter_scene`'s shim. That is an
off-contract `lib/src/` import of a pre-1.0 package whose minor releases carry
breaking changes, and it is confined to one file for exactly that reason. The
alternative — our own conditional export over our own WebGL2 backend — is
smaller for this project than `flutter_scene`'s 130 KB, because they need a
general GLSL transpiler for arbitrary user shaders and this project has two
hand-written ones whose GLSL ES 300 forms can simply be authored.

**Pre-committed trigger for taking it in-house:** the first time a
`flutter_scene` minor release breaks the facade, or the first time the backend
needs an API the shim does not expose. **Depth and MSAA are both such APIs and
neither has been run through the shim** — see open questions.

Enablement belongs in the plan: `FLTEnableFlutterGPU` in `Info.plist` on
iOS/macOS, `io.flutter.embedding.android.EnableFlutterGPU` in
`AndroidManifest.xml` on Android, nothing on web, and **`flutter run` exposes no
CLI flag**. A platform where enablement fails falls back to `VerticesDrawSink`
and says so once.

Two API traps the spike hit: `createImageSurface`'s optional format argument is
mandatory in fact — its default resolves to `PixelFormat.unknown` on macOS
Metal — and the web backend has no `createImageSurface` at all, so the render
target is a `Texture`. `ShaderLibrary.fromAsset` throws on web;
`loadShaderLibraryAsync` exists on both.

---

## Budgets

At **500,000 entities / 2,380,424 segments**. Revision 1's budgets were derived
from the spike's record and did not account for the attributes and instances
this design adds; revision 2 states a ledger instead.

### The byte ledger

| pipeline | record | bytes | count | total |
|---|---|---|---|---|
| strokes | 2 endpoints ×2×f32 (16), colour u32 (4), half-width u16 (2), dash period/phase u16×2 (4), depth code u32 (4), flags u16 (2) | **32** | 2.38 M | 76.2 MB |
| joins | shared vertex ×2×f32 (8), two unit dirs ×4×f32 (16), colour u32 (4), half-width u16 (2), depth u32 (4), pad (2) | **36** | ~2.38 M | 85.7 MB |
| fills | position ×2×f32 (8), colour u32 (4), depth u32 (4) | **16** | corpus-dependent | — |

**That is ~162 MB before fills, against revision 1's stated 64 MB budget, and
the reviews are right that the old number was unreachable.** Joins alone run
roughly one per segment. Three responses, in the order the plan should try
them:

1. **Joins are not always needed.** A join is invisible when the turn angle is
   below the threshold at which the notch is sub-pixel at the *live* scale.
   Emitting joins only above a stated angle removes most of them on
   polyline-heavy DXF imports, and the threshold is a watermark input.
2. **Strokes drop the dash fields when the style is solid**, via a second
   pipeline. Solid is the common case; 32 becomes 28.
3. **Culling, which version one declines**, converts a residency budget into a
   working-set budget.

**The honest budget is therefore stated as a measurement, not a target:
criterion 6 becomes "≤ 96 MB with joins, caps and fills included, or a recorded
miss with its number".** Setting a number the design cannot show it can hit
would be the kind of threshold-chasing the project's notes exist to prevent.

### Time

| quantity | spike measured | budget | note |
|---|---|---|---|
| gesture frame p50 build | 0.22 ms | **≤ 1.0 ms** | firm |
| gesture frame p50 raster | 1.00-3.46 ms | **≤ 6.0 ms, provisional** | the spike measured no depth, no MSAA, no joins, no second pass, no text pass; this must be re-derived on a representative pipeline before it is a gate |
| gesture frame p95 raster | **unstable, 10-13 ms** | **≤ 8.0 ms with the cause diagnosed** | see below |
| initial load, platform thread | 1,040 ms walk | **≤ 150 ms, contingent** | see below |

**The p95 row can fail this design.** The spike recorded arm C's raster p95 as
unstable, undiagnosed, and drifting across repeats in a way arms A and B did
not. Diagnosing it is task 1 of any plan.

**The load budget's isolate plan has a collision that must be resolved before
it is a budget.** `draft_painter.dart:910` calls
`document.textMeasurer.measure(...)` inside the walk, and `FlutterTextMeasurer`
imports `dart:ui` and builds `Paragraph`s — so the collection walk **cannot run
in a background isolate as written**. Substituting a metric-model measurer makes
it run but changes layout and the `minTextCapPixels` culling decision, which
breaks criterion 1 by construction. Open question 4.

---

## Invariants this must not break

1. **The frame path allocates nothing per entity in steady state, O(1) per
   flush.** The steady-state frame writes one uniform block, submits, and walks
   the resident text list. `paint_allocation_test.dart` is extended to cover it,
   and the text list walk must be shown to be O(visible text) with no per-entity
   allocation.
2. **Draw order is ascending handle value**, stable across undo, save, load and
   purge. Tested by shuffling slab submission order and asserting an identical
   rendering — meaningful only *because* of the depth decision.
3. **Geometric decisions use `Tolerance`; stored-value comparisons are exact
   `==`.** Unchanged; the collector inherits the painter's decisions.
4. **`packages/jet_cad_2d` is untouched.** `DraftPainter` and `DrawSink` already
   live in `jet_cad_2d_flutter` and `paint` takes `dart:ui`'s `Size`, so the
   occurrence-scoped walk goes beside the painter and the engine package does
   not change. Revision 1 hedged this; the file layout settles it.

---

## Testing

Per `CLAUDE.md`, defects surface through **mutation and differential testing**,
and the dominant failure mode is the degenerate fixture. Every fixture is
non-identity, off-origin and non-uniformly scaled, and the corpus includes **a
leaf inside a block definition placed at two instances**, without which the
occurrence-identity findings above cannot be caught.

**Differential, against `VerticesDrawSink`:** identical `RecordingDrawSink` op
streams between the occurrence-scoped walk and a full walk; rendered-pixel
comparison on a corpus with a mirrored instance, a non-uniform scale, a dashed
leaf at four zoom levels, a translucent fill, an arc at four zoom levels, and
text near the culling threshold.

**Mutations that must go red** (pre-committed; the plan owns the full log):

- drop the depth attribute → draw-order test fails
- rank per primitive instead of per occurrence → no test fails, and **that is
  the point**: this is a declared equivalent mutation, recorded so a later
  reader does not mistake it for a gap
- key slabs by handle instead of occurrence → the two-instance definition test
  fails
- omit the `bySource` closure → editing a definition leaf leaves instances stale
- treat empty `touched` as "nothing changed" → the whole-document arm fails
- ignore the table revision counter → a layer colour change draws stale
- write depth in pass 2 → translucent-over-translucent test fails
- skip the seam join → the circle-notch test fails
- expand the stroke quad at collection scale → strokes thicken under zoom
- bake dash spans instead of shading them → the four-zoom dashed test fails
- widen the watermark band to infinity → the four-zoom arc and LOD tests fail
- collect under an identity camera → level-of-detail test fails

**Web is measured with a stated instrument.** The rig's `FrameTimingLog` refuses
to report on web because ordinal alignment does not hold there, and the spike
relaxed it to a distribution over the phase window. **A gate may not rest on the
relaxed instrument.** One nuance worth carrying: the spike recorded arm C at
**excess 0 in every web phase** while arms A and B slipped, so the relaxation
did not touch arm C's own figures. That weakens the blocker for absolute
single-arm numbers without removing it for comparative ones.

---

## Exit gate

Pre-committed. Thresholds are not moved to make a criterion pass; a miss is
recorded as a miss with its number.

1. Op-stream equality between the occurrence-scoped walk and a full walk, on
   the mutation corpus including the two-instance definition.
2. Pixel differential against `VerticesDrawSink`: **per-channel difference ≤ 2
   on ≥ 99.5% of pixels and ≤ 8 on the rest**, computed on premultiplied RGBA,
   with **separate baselines for native and web** because the rasterizers
   differ. Antialiasing choice (4x MSAA or alpha-to-coverage) is whichever meets
   this and the raster budget.
3. Draw order survives a shuffled slab submission order, byte-identical.
4. Draw order survives undo, redo, save, load and purge.
5. Steady-state frame allocates nothing per entity, O(1) per flush, including
   the text pass.
6. Resident geometry **≤ 96 MB** at 500,000 entities with joins, caps and fills
   included, **or a recorded miss with its number and its ledger**.
7. Platform-thread load ≤ 150 ms at 500,000 entities, **contingent on open
   question 4**.
8. Gesture p50 ≤ 1.0 ms build and ≤ 6.0 ms raster, on the full pipeline,
   excluding frames in which a rebuild or wide relabel landed.
9. Gesture p95 ≤ 8.0 ms raster **with the instability diagnosed**, not merely
   observed to be lower.
10. A platform without Flutter GPU falls back to `VerticesDrawSink` exactly
    once, without throwing. **Tested through an injectable facade factory that
    fails on demand**, with a one-shot observable diagnostic — hardware or
    plist failure is not a deterministic fixture.
11. Web renders the differential corpus correctly under CanvasKit **and**
    Skwasm.
12. Every mutation above goes red, and the declared equivalent mutation is
    recorded as equivalent.
13. Crossing the watermark band during a gesture does not drop a frame; the
    re-collection lands after settle, and the stale interval is measured and
    reported.
14. Relabel rate under a stated edit workload stays below one wide relabel per
    100 edits at the top scale, or the occupancy limit is lowered until it does.
15. The text pass costs ≤ 0.5 ms p50 on a text-bearing corpus, or the corpus
    used for criteria 6 to 9 states that it excludes text.

Criteria 9 and 6 are the two most likely to miss, and both are stated as gates
anyway.

---

## Open questions, to settle before a plan is written

1. **The scale assumption.** See the top. At 500-5,000 entities, close this spec.
2. **Does the WebGL2 shim support a depth attachment, and MSAA?** The whole
   keystone rests on depth, and **the spike ran with no depth attachment, no
   depth test and no depth write, on any platform**. Both features are unproven
   here and unproven through a pre-1.0 shim. This is task 1 alongside the p95
   diagnosis, and a negative answer changes the design rather than the plan.
3. **The web timing instrument.** No web criterion may rest on the relaxed
   unaligned instrument. What replaces it is unsolved.
4. **Can the collection walk run in an isolate given `FlutterTextMeasurer`?**
   Criterion 7 is contingent on the answer. Splitting the walk — geometry in an
   isolate, text on the platform thread — is the obvious candidate and has not
   been designed.
5. **Skwasm.** Criterion 11 names it and nothing has been run there.
6. **Arm B's 46-47 ms max build on a web zoom**, found by the spike's web arm.
   A defect in the *shipping* tile cache, not in this design; it needs its own
   investigation rather than being absorbed here.
