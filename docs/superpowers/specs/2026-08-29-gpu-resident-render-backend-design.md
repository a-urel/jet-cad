# A GPU-resident render backend — design

**Date:** 2026-08-29. **Status:** design, not yet a plan.
**Evidence base:** [2026-08-29-flutter-gpu-backend-spike.md](../notes/2026-08-29-flutter-gpu-backend-spike.md).

---

## Two things to check before reading further

**1. This spec is opened against the roadmap's own stated judgement, on the
human's explicit instruction.** `roadmap/00-README.md` says the render layer is
*"done, and over-built for this target"*, that a floor plan is 500 to 5,000
entities, and that *"the engine is not the risk; the risk is the three
unwritten layers"*. This spec's own evidence agrees: at 1,500 entities the
existing painter draws a zoom frame in about 6 ms against a 16.67 ms budget,
and the GPU arm's advantage does not open until roughly 15,000 entities. The
objection was raised and the human reaffirmed the work. It is recorded here
because a spec that hides its own strongest counter-argument is worth less
later.

**2. The scale this is designed for is an assumption, and it is the first
thing spec review must confirm or replace.** Everything below is sized for
**documents of 10,000 to 500,000 entities** — imported DXF drawings and
site-scale plans, not a single floor plate. If the real target is the
roadmap's 500-5,000, most of this design is unnecessary and the honest answer
is to close it. Every threshold in the exit gate is derived from that
assumption and must move with it.

---

## The question this answers

`DraftPainter.paint(sink, camera, viewport)` folds the camera into the
residual chain it hands a sink. Every vertex a sink receives is therefore in
screen space, and **the whole document is re-walked and re-transformed the
moment the camera moves**. Plan 3g's tile cache hides that walk during a
gesture by blitting a magnified bitmap; the drawing goes soft while the
gesture lasts. The vector-replay spike priced the sharp alternative on the CPU
at **22.9x the blit** and rejected it.

> Make a pan or a zoom cost a **uniform write** instead of a **document walk**,
> without giving up the picture.

The spike answered that it can be done. At 2,380,424 segments the per-frame
CPU cost of a gesture was **0.17-0.26 ms and flat**, against **383 ms** for the
walk, and it held on the web through `flutter_scene`'s WebGL2 layer. What the
spike did *not* build is everything that makes it a backend rather than an
arm. That is what this design is for.

## Non-goals

- **Replacing `VerticesDrawSink`.** It stays the default and the fallback. This
  is a third backend, chosen explicitly, and every platform and document that
  does not choose it is unaffected.
- **Changing the document model.** Nothing in `packages/jet_cad_2d` changes.
  The engine stays pure Dart with no `dart:ui` dependency.
- **A scene graph.** `flutter_scene`'s `Node`/`Mesh`/material stack is not
  used; see the spike note for why its instancing model does not fit.
- **Matching the painter pixel for pixel.** See the visual-parity gate below:
  parity is specified where it is cheap and explicitly bounded where it is not.

---

## Architecture

### The seam: collection stays a `DrawSink`, it just stops being per-frame

The backend does **not** add a fourth `DrawSink`. It reuses the existing one
and changes *when* it runs.

`DrawSink` is the project's primary correctness mechanism — `RecordingDrawSink`
equality is what makes two implementations comparable — and the spike showed a
collector implementing it produces correct geometry with the residual applied.
So collection is a `DrawSink` implementation driven by `DraftPainter.paint`,
called **on document change** rather than on every frame.

```
DraftPainter.paint(collector, collectionCamera, extentsViewport)
        │
        ▼
  ResidentGeometry            ← handle-keyed slabs, GPU-resident
        │
        ▼
  one instanced draw per pipeline, camera as a uniform
```

**What this preserves:** the walk, the residual rebasing, the level-of-detail
decisions, the fill triangulation, and every test that already covers them.
**What it changes:** how often the walk runs.

### Draw order becomes a depth value, and that is the keystone

**The rule is non-negotiable: draw order is ascending handle value, stable
across undo, save, load and purge** (`draft_document.dart:317`). In a packed
instance buffer the naive reading of that rule is "buffer order must equal
handle order", which makes every insert a re-pack and every size-changing edit
a memmove of everything after it.

Instead: **each emitted primitive carries a `depth` attribute equal to its rank
in the walk's emission order.** The opaque pass runs with depth write on and
`CompareFunction.greaterEqual`, so the fragment that survives is the one the
painter would have drawn last. Submission order stops mattering.

Three things fall out of this, and they are the reason the design works:

1. **Edits become local.** A changed entity's slab can be rewritten in place or
   appended at the end and the old one freed. Buffer order no longer needs to
   mean anything.
2. **Culling becomes free to add later** without reordering hazards.
3. **The invariant is testable as an invariant**, not as an accident of
   submission: a differential test can shuffle slab order and assert the
   rendered result is byte-identical.

**Emission order, not handle order, is what is ranked.** Within one entity the
walk emits joins before segments, and `VerticesDrawSink._runTo` documents why
that matters. Ranking the emission preserves it.

**Depth precision is a real limit and it gets a number.** The format is
`d24UnormS8Uint`: 2^24 values spaced **uniformly** over [0, 1], which is
exactly what a rank does — ranks are uniform, so a uniform encoding is the
right one. The design budget is therefore **16,777,216 emitted primitives per
document**, about seven times the spike's 2.38 M, and beyond it the backend
must refuse and fall back rather than draw a wrong picture.

`d32FloatS8UInt` is **not** used, and the reason is worth stating because the
intuition runs the other way: a 32-bit float has more bits but spends them
non-uniformly, dense near 0 and sparse near 1, so mapping uniform ranks onto it
wastes precision at one end and runs short at the other. More bits is not more
distinguishable ranks here.

The clear value is `0.0` — which is `DepthStencilAttachment`'s own default —
and the comparison is `CompareFunction.greaterEqual`, so rank ascends with
depth and the last-drawn fragment wins. Rank *r* of *N* maps to
`(r + 1) / (N + 1)`, keeping every real primitive strictly above the cleared
background.

### Transparency is a second pass, because depth cannot order blending

`ResolvedStyle.argb` carries alpha (`255 - transparency`), and Plan 3e already
found a translucent seam question. Depth testing gives the correct *opaque*
result in any order; blending does not commute, so:

- **Pass 1 — opaque** (`alpha == 255`): depth write on, depth test on, blend
  off, any submission order.
- **Pass 2 — translucent** (`alpha < 255`): depth **test** on against pass 1's
  buffer, depth **write off**, blend on, submitted in ascending emission rank.

Pass 2 must be ordered, so it keeps a sorted slab list. This is affordable
because translucency is rare in this corpus; **if a document's translucent
fraction exceeds 5%, pass 2's cost must be measured before the backend claims
the frame.** That threshold is a stop clause, not a target.

### Dirty tracking

`DocChange` is a sealed hierarchy of five and every command variant carries
`Set<Handle> touched` (`doc_change.dart:11`). The tile cache already consumes
exactly this through `DocChangeNotifier(onChange:)`, and the backend uses the
same plumbing.

| change | response |
|---|---|
| `CommandApplied` / `CommandUndone` / `CommandRedone` | re-walk **only** the touched handles; rewrite or reallocate their slabs |
| `DocumentLoaded` | drop everything, full rebuild |
| `DocumentPurged` | drop everything — slots are rewritten wholesale, so every slab key is invalid |

**A re-walk of one entity still needs the painter.** `DraftPainter` walks the
document, not an entity, so this design needs a **handle-scoped walk** — the
one piece of new engine-adjacent API here. It must produce, for a given handle
set, exactly the emissions a full walk would produce for those handles, in the
same relative order. That equivalence is a differential test, not an argument.

**Emission ranks are not renumbered on edit.** A rewritten slab keeps its rank
range; a slab that grows past its range borrows from a gap. Ranks are dense
only at build time. A **rank-exhaustion compaction** runs when free ranks fall
below a threshold, and it is a full rebuild — the same operation as
`DocumentLoaded`, which the design already has to support.

### Culling: none in version one, with the measurement that says so

The spike drew all 2,380,424 segments every frame, with no culling of any
kind, and the zoom frame's raster cost was **1.00-3.46 ms**. Culling is
therefore not required to meet the budget at the design's stated top scale, and
adding it now would be building against a number the project does not have.

**The threshold at which this is revisited is pre-committed: a p50 raster above
6 ms on the reference gesture.** Above it, the next move is spatial bucketing of
slabs, which the depth decision above already made safe.

### Text stays on the Canvas

`flutter_scene` has no text and neither does this backend. `DraftPainter`
already emits `text()` ops through the sink and the project already has
`FlutterTextMeasurer`. The GPU image is composited, then **a second Canvas pass
draws text above it**, driven by the existing path.

This is chosen over an SDF atlas because text counts are small next to segment
counts, the existing path is already tested, and an atlas is a
level-of-detail problem in its own right. The cost is one extra Canvas pass per
frame and it is measured, not assumed.

### Fills

`DrawSink.fillPolygon` already arrives **pre-triangulated** — the doc comment
says the triangulation is computed once, off the frame path, precisely so a
batching sink can use it. Fills therefore get their own instance buffer and a
trivially simple pipeline (position, colour, depth), and they cost no new
geometry work. `fillCircle` is fanned at collection time under the arc rule
below.

### Strokes: joins, caps, antialiasing

The spike drew bare quads with butt ends and no antialiasing, and said so. The
backend does not get to.

- **Joins and caps** are emitted as additional instances by the collector,
  mirroring `VerticesDrawSink._emitJoin` and `_endRun` — including the **seam
  join**, whose absence that file records as putting a notch on every circle.
  This is a constant factor on instance count, not a new per-frame term.
- **Antialiasing** is a coverage varying: the quad is expanded by half a device
  pixel and the fragment shader fades the outer edge. The reference is
  `VerticesDrawSink`'s own output, and the gate is a pixel test, below.

### Arcs and circles

A circle's tessellation is scale-dependent — `DrawSink.fillCircle` says so —
and a buffer uploaded once cannot re-fan it. The rule:

- Arcs are fanned at collection time for the **collection camera's** scale.
- A **zoom-scale watermark** is kept. When the live camera's scale exceeds the
  collection scale by more than **4x**, arcs whose device radius grew past the
  quarter-pixel sagitta bound are re-fanned and their slabs rewritten. This is
  a dirty-tracking event like any other and reuses that machinery.

An analytic arc shader was considered and deferred: it is a second pipeline
with its own antialiasing story, and re-fanning reuses machinery this design
already needs.

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
breaking changes, and **it is confined to one file for exactly that reason.**

The alternative — our own conditional export over our own WebGL2 backend — is
smaller for this project than `flutter_scene`'s 130 KB, because they need a
general GLSL transpiler for arbitrary user shaders and this project has two
hand-written ones whose GLSL ES 300 forms can simply be authored. It is not
version one's job, and the facade is what keeps that a later decision rather
than a rewrite.

**Pre-committed trigger for taking it in-house:** the first time a
`flutter_scene` minor release breaks the facade, or the first time the backend
needs an API the shim does not expose.

### What the platform seam must carry

Enablement is not free and belongs in the plan: `FLTEnableFlutterGPU` in
`Info.plist` on iOS/macOS, `io.flutter.embedding.android.EnableFlutterGPU` in
`AndroidManifest.xml` on Android, nothing on web. **`flutter run` exposes no
CLI flag.** A platform where enablement fails must fall back to
`VerticesDrawSink` and say so once, not throw per frame.

Two API traps the spike hit, recorded so the plan does not re-find them:
`createImageSurface`'s optional format argument is mandatory in fact — its
default resolves to `PixelFormat.unknown` on macOS Metal — and the web
backend has no `createImageSurface` at all, so the render target is a
`Texture`. `ShaderLibrary.fromAsset` throws on web; `loadShaderLibraryAsync`
exists on both.

---

## Budgets

Derived from the assumption in "Two things to check", at **500,000 entities /
2.38 M segments**, and each is a gate in the exit criteria.

| quantity | spike measured | budget | how |
|---|---|---|---|
| resident geometry | 81.73 MB | **≤ 64 MB** | pack colour as `uint32` and width as normalized `uint16` instead of four floats and one |
| initial load, main thread | 1,040 ms walk | **≤ 150 ms on the platform thread** | build the byte buffers in an isolate; the upload alone stays on the platform thread |
| gesture frame, p50 | 0.22 / 3.14 ms | **≤ 1.0 ms build, ≤ 6.0 ms raster** | — |
| gesture frame, p95 | **unstable, 10-13 ms observed** | **≤ 8.0 ms raster** | requires the diagnosis named below |

**The p95 row is the one that can fail this design.** The spike recorded arm
C's raster p95 as unstable and undiagnosed, and drifting across repeats in a
way arms A and B did not. The first task of any plan built from this spec is to
diagnose it — the image surface's backing-texture pool reaching steady state is
the standing hypothesis — because a gesture backend whose worst frame is
unexplained is not a backend.

---

## Invariants this must not break

These are `CLAUDE.md` non-negotiables and each gets a test, not a claim.

1. **The frame path allocates nothing per entity in steady state, and O(1) per
   flush.** The GPU path's steady-state frame writes one uniform block and
   submits; `paint_allocation_test.dart` is extended to cover it.
2. **Draw order is ascending handle value**, stable across undo, save, load and
   purge. Tested by shuffling slab order and asserting an identical rendering —
   which is only meaningful *because* of the depth decision.
3. **Geometric decisions use `Tolerance`; stored-value comparisons are exact
   `==`.** Unchanged; the collector inherits the painter's decisions.
4. **The engine stays pure Dart.** Nothing here touches `packages/jet_cad_2d`
   except the handle-scoped walk, which is `dart:ui`-free.

---

## Testing

Per `CLAUDE.md`: defects here surface through **mutation and differential
testing**, and the dominant failure mode is the degenerate fixture. Every
fixture below is non-identity, off-origin, and non-uniformly scaled.

**Differential, against `VerticesDrawSink`:**
- same document, same camera → same `RecordingDrawSink` op stream from the
  collector as from a full walk (this is what makes the handle-scoped walk
  trustworthy)
- rendered-pixel comparison at a stated tolerance, on a corpus that includes a
  mirrored instance, a non-uniform scale, a dashed leaf, a translucent fill and
  an arc at four zoom levels

**Mutations that must go red** (a non-exhaustive pre-commitment; the plan owns
the full log):
- drop the depth attribute → draw order test fails
- rank by handle instead of emission order → the join-before-segment ordering
  test fails
- write depth in pass 2 → translucent-over-translucent test fails
- skip the seam join → the circle-notch test fails
- keep a stale slab after `CommandUndone` → dirty-tracking test fails
- re-fan arcs at the live scale instead of the watermark → allocation test
  fails on the frame path
- collect under an identity camera instead of the fit camera → level-of-detail
  test fails

**Web is measured with a stated instrument.** The rig's `FrameTimingLog`
refuses to report on web because ordinal alignment does not hold there; the
spike relaxed it to a distribution over the phase window. **A gate may not rest
on the relaxed instrument.** Deciding what the web instrument should be is
listed as an open question and blocks any web exit criterion.

---

## Exit gate

Pre-committed. Thresholds are not moved to make a criterion pass; a miss is
recorded as a miss, with its number.

1. Differential op-stream equality between the handle-scoped walk and a full
   walk, on the mutation corpus.
2. Pixel differential against `VerticesDrawSink` within the stated tolerance,
   including joins, caps and antialiasing.
3. Draw order survives a shuffled slab order, byte-identical.
4. Draw order survives undo, redo, save, load and purge.
5. Steady-state frame allocates nothing per entity, O(1) per flush.
6. Resident geometry ≤ 64 MB at 500,000 entities.
7. Platform-thread load ≤ 150 ms at 500,000 entities.
8. Gesture frame p50 ≤ 1.0 ms build and ≤ 6.0 ms raster at 500,000 entities.
9. Gesture frame p95 ≤ 8.0 ms raster, **with the instability diagnosed**, not
   merely observed to be lower.
10. A platform without Flutter GPU falls back to `VerticesDrawSink`, once,
    without throwing.
11. Web renders the differential corpus correctly under CanvasKit and Skwasm.
12. Every mutation above goes red.

Criterion 9 is the one most likely to miss. It is stated as a gate anyway,
because the alternative is shipping a gesture path whose worst frame nobody can
explain.

---

## Open questions, to settle before a plan is written

1. **The scale assumption.** See the top. If the target is 500-5,000 entities,
   close this spec instead of planning it.
2. **The web timing instrument.** No web criterion can rest on the relaxed
   unaligned instrument. What replaces it is unsolved.
3. **Skwasm.** Criterion 11 names it and nothing has been run there. It may
   simply work; it has not been checked.
4. **Arm B's 46-47 ms max build on a web zoom**, found by the spike's web arm.
   That is a defect in the *shipping* tile cache, not in this design, and it
   needs its own investigation rather than being absorbed here.
5. **Whether the handle-scoped walk belongs in `jet_cad_2d` or beside the
   painter.** It is `dart:ui`-free either way; the question is whether the
   engine should carry an API whose only consumer is a Flutter-side backend.
