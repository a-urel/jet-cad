# A GPU-resident geometry buffer — a throwaway spike, and its positive result

**Date:** 2026-08-29. **Branch:** `spike/flutter-gpu-backend`, cut from
`6367e13` (the widget spike's tip). Its code is throwaway; this note is what
the spike produced.

**Status: answered, positive, and it reverses a result from this morning.
Extended the same day with a measured web arm** -- see the web section.
The vector-replay spike rejected sharp gesture frames on per-frame cost. Moving
the geometry to the GPU removes that cost. The question the human asked was
whether a 2D CAD drawing layer could be built on `flutter_scene`; the answer
splits into a package recommendation and a measurement, and the measurement is
the part worth keeping.

---

## The question, and the correction it needed first

The human asked whether the CAD widget — or its drawing layer — could be built
on **`flutter_scene`** (pub.dev). Two corrections, in order of how much they
change the answer.

**`flutter_scene` is a 3D scene graph, and its top half is the wrong
abstraction.** It carries `Node` hierarchies, physically-based materials, glTF
import and skinned animation. A 2D CAD drawing wants none of that. What it
does carry that is genuinely useful is its *bottom* half: `flutter_gpu`
plumbing, a shader-bundle build hook, and — see the web section — a WebGL2
backend.

**The interesting question is one layer down.** `render_backend.dart` already
foresees it in the enum's own doc comment: *"a third backend is foreseeable —
`flutter_gpu` ships in the SDK"*. And `DraftPainter.paint(sink, camera,
viewport)` folds the camera into the residual chain, so today **every vertex
handed to a sink is in screen space and is recomputed the moment the camera
moves**. That is the cost the whole spike is about:

> Can a pan or a zoom cost a **uniform write** instead of a **document walk**,
> and still draw sharp?

## Why the answer mattered before it was taken

Two spikes landed on 2026-08-29 before this one, and this question sits exactly
between them.

- `2026-08-29-vector-gesture-replay-spike.md` asked for sharp gesture frames
  and got **22.9x the blit's cost at 500,000 entities** — because a replay is
  *O(visible geometry) per frame*, and `clipRect` discards fragments, not
  vertex work.
- `2026-08-29-widget-per-entity-spike.md` found that widget-per-entity zeroes
  the build and **triples the raster**, because the unit of render cost is the
  canvas call, and it rejected the approach on five architectural grounds.

A GPU-resident buffer is the third answer: one draw call (so the widget
spike's objection does not apply), and the per-frame transform in a vertex
shader (so the replay spike's does not either).

## What was built

Three arms, interleaved, over a hold, a pan and a zoom.

| | |
|---|---|
| **A — painter (untiled)** | today's untiled path: the whole document walked per frame into one `drawVertices` |
| **B — tiles (blit)** | today's *gesture* path: Plan 3i's tile cache, blitting the previous generation's composite, magnified. **Cheap and blurry** |
| **C — flutter_gpu (resident)** | the geometry uploaded once as **instance data**, the camera a uniform. **Real geometry every frame** — see what "sharp" claims, below |

Arm C's shape, since it is the whole claim:

- **One instanced draw call.** A four-vertex unit quad steps per vertex; a
  nine-float segment record (`p0`, `p1`, half width, RGBA) steps per instance.
  `VertexStepMode.instance` is what makes the memory tolerable — without it
  every segment would carry four or six copies of its own endpoints.
- **The lineweight is applied after projection, in the vertex shader.** That
  is what lets a stroke hold its device-pixel width under zoom with no CPU
  work. It is also precisely the thing the widget spike's arm B got *wrong*
  and its arm C paid 2.5 ms of build for.
- **The buffer's space is the fit camera's screen space, not world space.**
  Collecting under an identity camera would give world coordinates and the
  wrong level of detail, because the painter's LOD decisions read the camera's
  scale. The uniform matrix maps out of it:
  `mvp = ndcFromScreen(now) ∘ worldToScreen(now) ∘ screenToWorld(fit)`.

**"Sharp" in this note means one thing and not another, and the difference is
load-bearing.** It means the frame draws **real geometry under the current
transform** instead of replaying magnified pixels — which is exactly the axis
the tile cache trades away and the vector-replay spike could not afford. It
does **not** mean visual parity with the painter: arm C draws no joins, no caps
and no antialiasing, so its picture is *geometrically* correct and *visually*
incomplete. No claim of full visual equivalence is made anywhere in this note,
and none was measured.

**Every cheat runs in arm C's favour and is stated so the numbers are read
honestly:** no joins, no caps, no antialiasing, no fills, no text, and dash
spans baked at the collection camera. One thing runs *against* it: **arm C does
no culling at all** — it draws all 2.38 M segments every frame while arm B's
tile cache is O(viewport). C's figures are pessimistic by that amount.

## What the smoke runs found before any number was taken

Two defects, both caught by instruments rather than by reading.

1. **`createImageSurface`'s optional format argument is mandatory in fact.**
   Called without a format it falls back to `GpuContext.defaultColorFormat`,
   which on this macOS Metal context returns **`PixelFormat.unknown`** — the
   value the enum itself documents as *"an invalid or unspecified format …
   never the format of a real texture"* — and the surface then throws
   `Unsupported GpuSurface pixel format`. `PixelFormat.r8g8b8a8UNormInt` works.
   Nothing in the signature says the default is unusable.
2. **The first `painted=0` guard was too strict, and being too strict is also
   a defect.** Arm C renders only when the camera changes, so a *hold*
   legitimately submits zero GPU frames — the arm working, not failing. The
   guard belongs at the arm switch, where "this arm is not in the paint path
   at all" is the thing that can actually be wrong. Recorded because the
   widget spike's lesson was the opposite error, and the correction is not
   symmetric: the check has to move, not go away.

**Arm C was verified visually before its numbers were read.** A screenshot at
19,504 segments shows real geometry — lines, polylines, circles and arcs, the
ACI palette, correctly transformed. Not a blank surface, which is what a
`painted=0` failure looks like from the timing side.

## The numbers

macOS profile mode, 1400x900, interleaved arms, three repeats at the two
larger scales. Milliseconds, **p50, build / raster**, one figure per repeat.

### 19,504 segments (1,500 entities, 0.67 MB) — smoke, n=1

| arm | hold | pan | zoom |
|---|---|---|---|
| A painter | 0.06 / 1.61 | 2.45 / 1.30 | 3.99 / 1.91 |
| B tiles | 0.24 / 1.02 | 0.41 / 1.04 | 0.11 / 0.31 |
| C gpu | 0.09 / 0.31 | 0.27 / 1.01 | 0.52 / 0.63 |

### 84,299 segments (15,000 entities, 2.89 MB), n=3

| arm | phase | build p50 | raster p50 |
|---|---|---|---|
| A painter | pan | 10.67 / 10.42 / 10.28 | 4.95 / 4.99 / 4.87 |
| A painter | zoom | 9.93 / 10.55 / 9.46 | 4.74 / 4.98 / 4.66 |
| B tiles | zoom | 0.21 / 0.09 / 0.11 | 0.49 / 0.25 / 0.30 |
| C gpu | zoom | 0.67 / 0.56 / 0.11 | 2.56 / 1.66 / 0.46 |

### 2,380,424 segments (500,000 entities, 81.73 MB), n=3

| arm | phase | build p50 | raster p50 |
|---|---|---|---|
| A painter | pan | 338.15 / 336.91 / 337.41 | 132.34 / 121.41 / 123.25 |
| A painter | zoom | **401.73 / 383.09 / 347.67** | 164.13 / 137.47 / 130.88 |
| B tiles | zoom | 0.22 / 0.11 / 0.27 | 0.68 / 0.32 / 0.78 |
| C gpu | zoom | **0.26 / 0.22 / 0.17** | 1.00 / 3.14 / 3.46 |

One-time collection and upload: **19.5 ms** walk at 84 K segments,
**1,040 ms** walk plus 73 ms upload at 2.38 M.

### What the numbers say

- **Arm C's build does not grow with the drawing.** 0.52 ms at 19.5 K
  segments, 0.11–0.67 at 84 K, **0.17–0.26 at 2.38 M**. The per-frame CPU term
  is gone, which is the entire claim and it holds across two orders of
  magnitude. Arm A's build over the same span goes 3.99 → 10 → **383 ms**.
- **Drawing real geometry now costs roughly what blitting pixels costs.** At 500,000 entities the zoom
  frame totals about **0.9 ms** for the blit and **1.3–3.6 ms** for real
  vector geometry — call it 1.5x to 4x. The replay spike measured **22.9x**
  for the same sharpness on the CPU. That is a difference in kind, not in
  degree, and it is what reopens the question the replay spike closed.
- **The growing term moved to the raster thread, and it is small.** C's zoom
  raster goes 0.63 → ~1.7 → ~3.5 ms; that is 9.5 M vertices per frame at the
  top scale, with **no culling whatsoever**. Its p95 is unstable (12.96 and
  10.64 ms observed) and that is not diagnosed.
- **C's zoom raster drifts across repeats at 84 K (2.56 → 1.66 → 0.46) while
  A and B do not.** Interleaving was supposed to make session drift land on
  every arm equally, so a drift specific to one arm is C's own. The image
  surface's backing-texture pool reaching steady state is the obvious
  candidate. **Not measured, and it is the first thing to check if this is
  taken further.**
- **Memory is the real bill: 81.73 MB of resident vertex data at 500,000
  entities**, against the replay spike's 23.01 MB picture and the tile cache's
  20.16 MB composite — about **4x**. The instanced layout already saved a
  factor of four or six over an expanded one.
- **Loading is the second bill: a 1.04-second document walk on the UI
  thread.** At floor-plan scale it is 19.5 ms and invisible; at 500,000
  entities it is a one-second jank unless it moves off the platform thread.

## The web arm: measured, and the line survives

**This section was added after the first result.** The spike above concluded
"no web without `flutter_scene`'s WebGL2 layer" from reading. The human's
direction was that web *will* be supported, so the layer was measured rather
than assumed.

### How the technique actually works

`flutter_scene` carries the shim internally, at
`packages/flutter_scene/lib/src/gpu/gpu.dart`:

```dart
export 'stub/_gpu.dart'
    if (dart.library.io) 'impeller/_gpu.dart'
    if (dart.library.js_interop) 'web/_gpu.dart';
```

Native re-exports `package:flutter_gpu` verbatim -- the shim is free there, and
this arm's native figures confirm it: zoom p50 went 0.52 / 0.63 through
`flutter_gpu` directly to 0.18 / 0.49 through the shim, the same numbers within
this rig's noise. Web is a parallel implementation, thirteen files and roughly
130 KB of Dart, including a GLSL transpiler and a flatbuffer reader for the
shader bundle.

**The public `package:flutter_scene/gpu.dart` is a curated subset** -- shader,
texture and vertex-format types for the `ShaderMaterial` workflow -- and it
does **not** carry `DeviceBuffer`, `RenderPass`, `RenderPipeline` or a surface.
This arm therefore imports `lib/src/`, which is off contract, and does so as a
measuring instrument rather than as an architecture.

**Driving `flutter_scene` properly instead was considered and rejected on its
source.** Its instancing is *node-transform* instancing: `scene_encoder.dart`
packs per-node transforms and binds them at `geometry.vertexStreamCount`. This
arm's instance record is a segment -- two endpoints, a width and a colour --
which is not a transform, so the scene-graph path would have to be fought
rather than used.

### Three things the port had to change, and one it did not

1. **`createImageSurface` does not exist on the web backend.** The arm moved to
   `createTexture` plus a render target, which exists on both.
2. **`ShaderLibrary.fromAsset` throws on web** -- it is synchronous, web asset
   loading is not. `loadShaderLibraryAsync` is on both backends.
3. **The bundle must carry the OpenGL ES stage.** The web loader reads
   `entry.openglEs` and runs `transpileGlslEs100To300` over it. The bundle
   this spike compiles carries `#version 100` GLSL with `attribute`/`varying`,
   which is exactly that input. **The shaders themselves did not change.**
4. **What did not change: the frame stayed one-phase.** The web shim also
   carries an *asynchronous* bridge (`Surface.snapshot`,
   `presentTextureAsImage`, built on `ui_web.createImageFromTextureSource`),
   and a two-phase render would have split the submit and the composite across
   two frames and made the accounting unreadable. But web `Texture.asImage`
   states it "matches flutter_gpu's synchronous `asImage`", and it does.

### The instrument had to change, and refusing was the right default

**The rig's own backlog latch fires on the web, on arm A** -- the plain
painter, with no GPU code anywhere near it:

> `GSPIKE A painter (untiled)/pan: the timing stream ran a backlog after the
> baseline, so every ordinal is off by an unknown amount.`

That is the instrument working. It is not reporting a defect in what is being
measured; it is reporting that **ordinal alignment, which `FrameTimingLog` was
built to guarantee on native, does not hold on the web.** The refusal stands on
native and is relaxed on web only, through
`FrameTimingLog.debugTimingsUnaligned`, and every web figure below is a
**distribution over the phase window rather than a statement about the i-th
pumped frame**. The worst excess is printed beside each row.

**Wall-clock timing was considered first and rejected.** `pumpFrame` waits for
vsync, so every frame cheaper than the refresh interval reads as the refresh
interval -- and the entire question here is the difference between half a
millisecond and three.

**Two further web-only obstacles, recorded because they cost real time.**
`print` on a dart2js profile build goes to the browser console, which
`flutter run` does not forward to its stdout, so a web run posts its numbers
where no terminal can read them; the rig now renders its report into the
widget tree *after* the last phase, and a screenshot is the artefact. And an
unhandled async error surfaces as a bare minified `Error` with no message, so
the spike gate now catches and prints it.

### The web numbers

Chrome 151 profile, CanvasKit, 1400x900, 19,504 segments (1,500 entities),
30 frames per phase, one repeat. **Unaligned**; worst excess in the last
column. Milliseconds.

| arm | phase | build p50 / p95 | raster p50 / p95 | excess |
|---|---|---|---|---|
| A painter | hold | 0.60 / 1.40 | 1.00 / 1.80 | 2 |
| A painter | pan | 3.10 / 7.80 | 0.50 / 0.90 | 0 |
| A painter | zoom | 2.40 / 3.50 | 0.50 / 1.80 | 2 |
| B tiles | hold | 0.80 / 1.10 | 0.50 / 1.10 | 1 |
| B tiles | pan | 1.10 / 7.70 | 0.50 / 1.10 | 1 |
| B tiles | zoom | 0.50 / **52.30** | 0.30 / 1.40 | 2 |
| C gpu | hold | 1.00 / 1.60 | 0.60 / 0.90 | 0 |
| C gpu | pan | 0.80 / 2.00 | 0.30 / 1.00 | 0 |
| C gpu | zoom | **0.50 / 0.70** | **0.20 / 0.40** | 0 |

Arm C submitted 30 of 30 GPU frames on both pan and zoom, and 0 of 30 on the
hold -- the same shape as native, and the same reason.

And at the larger scale: **84,299 segments (15,000 entities, 2.89 MB)**, same
browser and viewport, 30 frames per phase, two repeats. Collection and upload
took a 13.0 ms walk and 64.5 ms in total.

| arm | phase | build p50 / p95 | raster p50 / p95 | max build |
|---|---|---|---|---|
| A painter | pan | 8.70 / 21.90 · 9.00 / 12.20 | 1.20 / 2.70 · 1.30 / 1.80 | 33.10 |
| A painter | zoom | 7.40 / 14.60 · 7.70 / 14.50 | 1.10 / 3.30 · 1.20 / 2.00 | 27.90 |
| B tiles | zoom | 0.50 / 1.50 · 0.40 / 1.20 | 0.20 / 0.90 | **47.20 · 46.00** |
| C gpu | pan | 0.50 / 1.10 | 0.30 / 0.80 | 1.80 |
| C gpu | zoom | **0.50 / 1.20** | **0.20 / 0.60** | 4.40 |

- **Arm C is flat on the web too.** Its zoom build p50 is 0.50 ms at 19,504
  segments and 0.50 ms at 84,299 -- a 4.3x larger drawing for the same
  per-frame cost, which is the same result the native arm gave across two
  orders of magnitude. Arm A over the same step goes 2.40 → 7.40.
- **Arm B's worst frame is the story on web.** Its zoom build p50 is excellent
  (0.40-0.50 ms) and its *max* is **46-47 ms** in both repeats, against arm
  C's 4.40. Whatever the tile cache does on a bake costs three frames' budget
  when it happens, and it happens on web where it did not on native. Not
  diagnosed here, and it is the strongest single argument in the resident
  buffer's favour on this platform.

**Read within the platform, not across it.** Plan 3d Task 13's rule applies
unchanged: the desktop and web tables are two separate confirmations, not one
table doubled.

- **Arm C works on the web and is the cheapest arm on a zoom**, at 0.7 ms of
  build plus raster against arm A's 2.9 ms.
- **Arm C's p95 is the tightest of the three** (0.70 / 0.40). Arm B's zoom
  build p95 is **52.30 ms** -- the tile cache spikes on web where it does not
  on native, and that is not diagnosed here.
- **Arm C's excess is 0 in every phase**, while A and B shift by up to two
  frames. The relaxation that made this table possible did not touch arm C's
  own numbers: they were aligned already.

### What this settles about the package question

The recommendation below was written before this section and said a GPU
backend would have to run "through `flutter_scene`'s compatibility layer, not
around it". That still holds, and it is now measured rather than read: **the
same shader bundle, the same instanced draw and the same one-phase frame run
under CanvasKit through that layer.**

What it does *not* settle is which of two ways to use it -- depending on
`flutter_scene` and importing `lib/src/`, off contract and pre-1.0, or
reimplementing the technique behind our own conditional export. The second is
smaller for us than the 130 KB it costs them, because they need a general GLSL
transpiler for arbitrary user shaders and this project has two hand-written
ones whose ES 300 forms could simply be authored. That decision is deliberately
left open; it needed these numbers first, and now it has them.

## The web finding that started it — superseded, and kept for its chronology

**Superseded by "The web arm: measured" above, which was added later the same
day. The paragraph this section originally ended with said the WebGL2 layer
was a documentation claim and should be measured before it is relied on. It
has since been measured; that sentence is struck below rather than deleted, so
the note reads as the record of a decision rather than as a thing that was
always known.** What survives unchanged is the constraint that made the web
question pressing in the first place.

**Bare `flutter_gpu` cannot compile for the web.** `bin/cache/pkg/flutter_gpu/lib/gpu.dart`
imports `dart:ffi` and `dart:nativewrappers` at library level. There is no
conditional import and no web implementation in the SDK package.

This matters more here than it would in most projects, because
`render_backend.dart`'s current default rests on **measured web numbers** —
Plan 3d Task 13, CanvasKit, a 17.3x–17.5x build ratio — and the vertices sink
is the default *because* of them.

`flutter_scene` states that it ships **its own WebGL2 backend, "a drop-in for
`flutter_gpu`"**, working under both CanvasKit and Skwasm, with no setup. So
the package question resolves the opposite way from where this spike started:

> If the web line must live, the way to a GPU backend runs **through
> `flutter_scene`'s compatibility layer**, not around it. Bare `flutter_gpu`
> is a native-only answer.

~~Nothing here measured that layer. It is a documentation claim and it should
be measured before it is relied on.~~ **It was measured the same day** — same
shader bundle, same instanced draw, same one-phase frame, under CanvasKit. See
"The web arm: measured" above for the numbers and for what the port had to
change.

## Setup cost, recorded because it is not zero

- `flutter_gpu` is an SDK dependency (`sdk: flutter`), needs Dart ≥ 3.11
  (3.13.1 here), and must be **enabled per platform**: `FLTEnableFlutterGPU`
  in `Info.plist` on iOS/macOS, an `io.flutter.embedding.android.EnableFlutterGPU`
  metadata key on Android. **`flutter run` exposes no CLI flag for it.**
- Shaders compile to a `.shaderbundle` with `impellerc`, which ships in the
  engine artifacts (`bin/cache/artifacts/engine/darwin-x64/impellerc`).
  `--runtime-stage-metal --runtime-stage-vulkan --runtime-stage-gles3
  --shader-bundle=<json> --sl=<out>` compiled both stages first try. A real
  backend would want this in a build hook rather than a shell command.
- `flutter pub get` rewrote three `analysis_options.yaml` files, as
  `CLAUDE.md` warns. They are not committed.

## What this does *not* settle

Everything arm C skipped is real work, and the list is the honest cost of a
backend:

1. **Joins and caps.** A constant factor on the instance count, plus the seam
   join `VerticesDrawSink._endRun` already documents as the thing whose absence
   notches every circle.
2. **Antialiasing.** A coverage varying and an edge fade. Matching Impeller's
   hairline quality is its own measurement.
3. **Text.** `flutter_scene` has none either. An overlay canvas pass or an SDF
   atlas; the project already has `FlutterTextMeasurer` and a `text()` sink op.
4. **Fills.** The sink's `fillPolygon` already arrives pre-triangulated, so
   this is the *easiest* of the five, not the hardest.
5. **Arcs re-fanned on zoom.** A circle's tessellation is scale-dependent —
   `DrawSink.fillCircle` says so — and a buffer uploaded once cannot re-fan it.
6. **Dirty tracking.** The spike uploads once and never edits. A real backend
   needs handle-keyed sub-buffer updates that keep **draw order ascending by
   handle**, which is a non-negotiable and is *not* free in a packed buffer.
7. **Culling.** Arm C has none. Adding it is what would let the 3.5 ms raster
   fall, and it needs the buffer partitioned spatially — the packed R-tree is
   already there to say how.

## Recommendation

**Not `flutter_scene` as a scene graph. Yes to the layer under it, and the
measurement says the question is now worth a spec rather than another spike.**

The one number that decides it: at 500,000 entities the per-frame CPU cost of
a gesture is **0.2 ms and flat**, against 383 ms for the walk. The tile cache
exists to hide exactly that walk, at the price of a blurry gesture; this
removes the walk instead of hiding it, and the gesture keeps drawing real
geometry for roughly what the blit costs — geometric sharpness, not the
finished picture; see what "sharp" claims above.

Against that: **82 MB resident**, a **one-second load** at that scale, a **web
line that exists only through `flutter_scene`'s WebGL2 layer** — measured and
working, but a dependency the project does not have today — and seven pieces
of unbuilt work above, of which **dirty tracking under the ascending-handle
draw-order invariant** is the one most likely to be harder than it looks.

**What this note asks for, stated once so it cannot be read as more:
approval to open a design spec, not approval to implement.** The 500,000-entity
figures are n=3 with a raster p95 this note itself records as unstable and
undiagnosed, and arm C is missing joins, caps, antialiasing, text, fills and
culling. That is enough to justify designing the thing. It is not enough to
justify building it, and no threshold here was ever proposed as a gate.

If it is taken further, the order that respects what is already known.
**Step 1 has since been done and its result is in the web section above** --
the layer works, and arm C is the cheapest and steadiest arm on a web zoom.

1. ~~Measure `flutter_scene`'s WebGL2 drop-in on the web.~~ **Done.** The
   remaining web question is not whether but *how*: depend on the shim through
   an off-contract `lib/src/` import, or reimplement the technique behind our
   own conditional export.
2. Diagnose arm C's raster p95 and the per-arm drift before trusting any
   gesture figure at 500,000 entities. Add to that **arm B's 46-47 ms max
   build on web**, which the web arm turned up and which is a defect in
   today's shipping gesture path, not in anything this spike proposes.
3. Design dirty tracking against the draw-order invariant **before** anything
   else is built, because it is the piece that can invalidate the approach.
4. Decide what the web measurement instrument should be. The relaxation this
   spike added is sound for a distribution and unsound for a per-frame claim,
   and anything that becomes a gate needs better than that.
