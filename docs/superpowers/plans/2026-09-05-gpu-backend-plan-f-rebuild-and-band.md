# GPU backend, Plan F — the rebuild triggers, the band, and `DraftCanvas`'s `residentGpu` path

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `DraftCanvas(backend: RenderBackend.residentGpu)` draws through the
resident backend for real — collected once over the **whole document's
extents** at the live camera's scale, rebuilt on exactly the spec's five
triggers and never on a pan, with the watermark band measured rather than
assumed — so that the widget path Plan A left rendering as `vertices` finally
calls the `GpuDrawBackend.paint` Plans B–E built, and criteria 2, 5, 7, 9, 10
and 12 of the spec's exit gate get their first numbers.

**Architecture:** A GPU-free **`ResidentCollection`** is the product of one
rebuild: the collector's buffer, the text list, the classified patches, the
camera it was collected under, the `devicePixelRatio` and the table revision
it was collected at. It is walked under a **collection frame** — the live
camera's scale and rotation with a translation that puts the document's
extents at the viewport's origin, and a viewport exactly the extents' screen
size — so nothing is culled and a pan needs no rebuild. A **`ResidentRebuilder`**
owns the schedule: `markDirty(trigger)` coalesces into one post-frame walk,
the upload is awaited off the frame path, the frame draws whatever backend is
current, and a trigger that lands mid-flight queues exactly one more rebuild.
The widget reads three of the five triggers **on the frame** — the table
revision counter, the `devicePixelRatio`, and the live-over-collection scale
ratio against the band — and the other two arrive as `DocChange`s. **No new
shader, no new attribute, no new record float.** The classification gets a
uniform grid so the rebuild has a chance against its budget; the compositor
rejects off-viewport labels; the two frame-path reuses Ruling RF-1 named are
taken because this plan finally builds the instrument that can see them: a
VM-service allocation probe in the harness, on the real frame path, on the
real GPU.

**Tech Stack:** Dart, Flutter 3.47.1, `flutter_scene` 0.23.0 (for its
internal `flutter_gpu` shim only), `flutter_test`, `dart:ui` `PictureRecorder`
/ `Picture.toImage` for the composited differential, `vm_service` ^15.2.0 in
the **harness only** for the allocation probe.

**Spec:** [docs/superpowers/specs/2026-08-29-gpu-resident-render-backend-design.md](../specs/2026-08-29-gpu-resident-render-backend-design.md)
(**revision 5**, commit `d2095e7`, plus Plan E's Ruling E9 word at `8dde4fb..`),
sections **"The two decisions everything else follows from"** (the trigger
table), **"Collection covers the whole document, at a reference scale"**,
**"The watermark, with the list corrected"**, **"The platform seam"** (the
fallback sentence), **"Budgets"**, **"Invariants"** (invariant 1's "new
mechanism"), the corpus and mutation list under **"Testing"**, and criteria
2, 5, 7, 9, 10, 12 under **"Exit gate"**, and **open question 3**. Read all
of them before Task 1. This plan argues from them and departs from them
nowhere; it *answers* open question 3 (Ruling F1) and records the answer in
the spec's open-questions list the way question 1 was struck.

**Predecessors:** [Plan A](2026-08-29-gpu-backend-plan-a-seam-and-strokes.md)
(`cd5bc98`), [Plan B](2026-08-30-gpu-backend-plan-b-joins-and-hairlines.md)
(`72b162d`), [Plan C](2026-08-31-gpu-backend-plan-c-shaded-dashes.md)
(`3a61b45`), [Plan D](2026-09-01-gpu-backend-plan-d-fills.md) (`de962bd`),
[Plan E](2026-09-04-gpu-backend-plan-e-text-patches.md) (`4921619`). Ledgers
at [docs/superpowers/ledgers/](../ledgers/). **Read Plan E's Ruling RF-1 in
its ledger's `progress.md` before Task 6** — it names the two reuses this
plan takes and the one (R6-2) it leaves parked.

**Reference implementation — two files, both unchanged:**
`packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart` and
`packages/jet_cad_2d_flutter/lib/src/canvas_draw_sink.dart`. The reference
for the widget path is `DraftCanvas` itself drawing through `VerticesDrawSink`
— the branch every `residentGpu` canvas took before this plan and still takes
before its first rebuild lands. **Neither sink file is edited by this plan.**

---

## Where Plan F sits

| plan | delivers | state |
|---|---|---|
| A | the facade, the collector and buffer for **stroked polylines**, one draw call, the ordering and differential gates, the fallback | **merged** `cd5bc98` |
| B | joins, `point()`, `circle()`/`arc()`, the `_coveredArgb` hairline alpha | **merged** `72b162d` |
| C | dashes evaluated in the shader, at the live scale | **merged** `3a61b45` |
| D | fills, and the order gate they make testable | **merged** `de962bd` |
| E | text, and the patch that keeps a covered label under what covers it | **merged** `4921619` |
| **F (this one)** | **the rebuild triggers, the collection frame, the band, `DraftCanvas`'s `residentGpu` path, the allocation instrument** | this plan |
| G | web: CanvasKit and Skwasm | |

**Plan F closes five of the spec's pre-committed mutations** — *"ignore the
table revision counter"*, *"ignore the `devicePixelRatio` trigger"*, *"cull
collection to the live viewport"*, *"read the watermark band against the
reference scale instead of the live scale"*, and *"leave the resident text list
stale across a rebuild"* — and records the sixth, *"rebuild only when `touched`
is non-empty"*, as the equivalent mutation the spec already declares it to be.
It makes criteria **2, 5, 7, 9, 10 and 12** measurable for the first time and
takes criterion 8's number **on the widget path** rather than on a hand-wired
harness painter.

---

## What is missing today, stated as a measurement rather than as a worry

`DraftCanvas._attach` says it in a comment:

```dart
    // **`residentGpu` paints through `vertices` here too, until Plan F.**
```

and `RenderBackend.residentGpu`'s doc says *"Wiring a GPU-resident sink into
`DraftCanvas` is Plan F's work."* Three facts follow, each with a number:

- **The only runtime consumer of `GpuDrawBackend` is `apps/dev_harness_2d/lib/gpu_arm.dart`**,
  which collects **once, at the fit camera, and never again**
  (`_buildResidentGeometry`'s own doc: *"and never walks it again"*). Every
  number Plans A–E recorded is a number for a drawing that cannot be edited.
- **The collection is culled to the viewport it was collected under.**
  `DraftPainter.paint` computes `camera.visibleWorld(viewport)` and both
  index queries take it. The harness never saw this because the fit camera
  has the whole document in view — the degenerate fixture the spec names.
  A `DraftCanvas` at a working zoom, collected at its own viewport, would
  draw into empty buffer **33 logical pixels** into the first pan.
- **The band is two provisional constants**, `kBandLowerScale = 0.5` and
  `kBandUpperScale = 2.0` (Plan E's Ruling E3), and nothing reads them
  against a live camera. Criterion 2 says the band is *an output of criterion
  1*; nothing has measured it.

And the rebuild itself, as Plan E left it: **`classify` alone is 27.4 ms**
against the **16.67 ms** budget on the 10,000-entity corpus (164% of the
whole budget before the walk or the upload). A plan that gates criterion 7
and leaves that number alone is recording a miss it could have moved.

---

## Fourteen scope rulings, made here rather than left to an implementer

### Ruling F1 — the reference scale is the live camera's scale at the moment of the rebuild

Spec open question 3 asks which reference scale collection runs at, and the
collection section says *"the plan chooses the reference scale by
measurement"*. **This plan chooses: there is no reference-scale constant.** A
rebuild collects at the live camera's scale, whatever it is, so the band is
always centred on where the user actually is. The spec's own worry — that a
fit-scale collection freezes every scale decision at a uselessly coarse value
— is answered by the band trigger: a fitted canvas the user zooms 3× into
leaves the band and rebuilds at the working scale on the next frame. Any
fixed parameter puts some working zoom permanently outside its band; the
live scale never does. **Cost if wrong:** a user who oscillates across a band
edge rebuilds on every crossing. Criterion 9's stale-interval number and the
harness's band-exit phase measure exactly that.

### Ruling F2 — collection covers the extents through a shifted camera, not a painter API

Invariant 4 says *"this design adds no painter API at all"*. The collection
frame therefore does not ask `DraftPainter.paint` for a different query
rectangle; it hands the painter a **camera whose translation puts the extents'
screen box at the origin and a viewport exactly that box's size (plus
`kScreenClipInflate` on every side)**, so `visibleWorld(viewport)` *is* the
extents and nothing is culled. The collection camera differs from the live
camera by a pure translation, so `composeTransforms(live, collectionInverse)`
is a translation and the frame mapping is exact. **What this costs:** the
buffer holds absolute collection-frame coordinates in `Float32`, bounded by
the extents' size at the live scale — on the harness floor (60,000 units)
that is 1,350 px at fit, 135,000 px at 100× (ulp 0.0078 px), 1.35 M px at
1000× (ulp 0.125 px). The band sweep (Task 7) runs at a zoomed-in collection
as well as at fit, so precision at a working scale is measured, not assumed.

### Ruling F3 — a rebuild is a post-frame callback, the upload is awaited, the frame draws whatever is current

`markDirty` records the trigger and schedules **one** `addPostFrameCallback`;
a second `markDirty` before it runs changes nothing. The callback walks and
classifies synchronously (on the UI thread, after the frame's paint has
finished — *"a rebuild never runs on the frame path"*), then awaits
`ResidentGeometry.create`. A trigger that arrives during the await sets the
pending reason and, when the upload lands, exactly one more rebuild is
scheduled. **The first reason wins the name**; later ones coalesce into it.
The frame path never waits: it paints the backend it has, and the rebuilder's
`notifyListeners()` on landing is what asks for the frame that shows the new
one.

### Ruling F4 — the tables trigger reads the revision counter on the frame; the listenable only causes the frame

The spec's row names *"table revision counter (`tables.dart:559`)"*, and the
tile cache's precedent (`tablesRevision:` pulled per frame in
`_DraftCustomPainter.paint`) is the shape. `DraftCanvas` already merges the
table listenable into `_repaint`, so a layer edit causes a frame; that
frame's `noteFrame` compares `document.tables.mutationRevision` with the
revision the collection was taken at and marks `tables` dirty on a
difference. An implementer who deletes the comparison keeps the frame and
loses the rebuild — which is the spec's mutation *"ignore the table revision
counter → a layer colour change draws stale"*, and Task 2's test.

### Ruling F5 — before the first landing and after a failed upload, `residentGpu` paints through `VerticesDrawSink`, and the failed case says so once per process

The spec: *"A platform where enablement fails falls back to `VerticesDrawSink`
and says so once"*, and criterion 10: *"exactly once, without throwing …
with a one-shot observable diagnostic"*. Two fallbacks exist and both take
the same path: `resolveBackend` returning `vertices` because `gpuAvailable()`
is false (no `ResidentRebuilder` is built at all), and
`ResidentGeometry.create` returning `null` (the rebuilder marks
`uploadFailed`, installs no backend, and ignores every later `markDirty`).
Both report through **one** `FlutterError.reportError`, guarded by a
process-wide latch on `DraftCanvas` with a debug counter and a reset for
tests. **Before the first rebuild lands** the same `vertices` branch paints —
the pre-Plan-F path — so a `residentGpu` canvas never shows a blank frame.

### Ruling F6 — the band constants follow the measurement, inward only

Criterion 2: *"the reported band is the widest scale ratio at which criterion
1 still holds, measured. A band narrower than 2x is a design failure and is
reported as one."* Task 7 sweeps live-over-collection ratios
`0.25, 0.35, 0.5, 0.7, 1.0, 1.4, 2.0, 2.8, 4.0` on two corpora — solid
curves (`differentialFixture`) and text with level of detail on
(`textOverlapFixture`) — and prints every row. The **reported band** is the
widest contiguous run of passing ratios containing 1.0, intersected across
the two corpora. The **constants** move only if the measured run is narrower
than `[0.5, 2.0]`: they shrink to the measured edges (each edge rounded
toward 1.0 to the sweep's grid), the change is ledgered with the row that
forced it, and the suite's edge assertions (Task 7 Step 3) go green again.
They do **not** widen on a wider run: a wider band is paid in patch-target
memory (`patchTargetSizeFor` scales with the ceiling squared) and in reach
(the floor), and that price is not taken blind. A measured run narrower than
2× is recorded as the design failure the spec names, in the results note's
criterion table, and the constants still shrink to it.

### Ruling F7 — the classification gets a uniform grid; the brute force stays as the oracle

`classifyTextPatches` keeps its signature and becomes a grid: every
instance's reach-expanded box is binned into cells sized by the largest
label box, an instance spanning more than `kClassifyOverflowCells` cells goes
to an overflow list tested against every label, and a label tests only the
instances in the cells its box touches (deduplicated by a stamp array,
filtered by `i >= instanceIndex`, **sorted ascending** so the sub-buffer stays
a subsequence of the main buffer in the main buffer's order). The old loop
is renamed `classifyTextPatchesBruteForce`, `@visibleForTesting`, and Task 5's
differential asserts the two return byte-identical patch lists on two
corpora. Sorting *hit indices* is not sorting the buffer.

### Ruling F8 — the frame-path allocation instrument is a VM-service probe in the harness

Invariant 1's *"new mechanism"* and criterion 5. STATUS records why it
cannot live in `flutter test`: `flutter_tester` launches with
`--disable-vm-service`. A `flutter run --profile` process serves the VM
service, so the harness gains `vm_service` and an `AllocationProbe` that
connects to its own isolate, resets the allocation profile, pumps a pan phase
on arm D, and reads `instancesAccumulated` per class for
`package:jet_cad_2d_flutter/`, `dart:ui` and `dart:typed_data`. **The gate:**
per-frame allocations `≤ kAllocFixed + kAllocPerPatch × P`, with `P` the
frame's `patchesRendered` — a per-instance allocation on a 100,000-instance
buffer exceeds that by four orders of magnitude, which is the property. If
the service refuses (`Service.getInfo()` returns no URI, or the RPC fails),
criterion 5 is recorded **UNEVALUABLE with the error text**, never faked.
`vm_service` is a **harness** dependency only; `jet_cad_2d_flutter` gains no
dependency.

### Ruling F9 — arm D is added; arm C stays as the control

The GPU spike's arm C (`GpuArmView`, hand-wired, collected once at fit) is
the arm every recorded number belongs to. Replacing it would leave a
widget-path regression indistinguishable from a harness change. Arm D is
`DraftCanvas(backend: RenderBackend.residentGpu)` and inherits every phase;
the trigger, band-exit and allocation phases run on D alone because only D
has triggers. The rig prints 4 × 3 × repeats phase reports plus D's own.

### Ruling F10 — R6-2 stays parked; RF-1's two reuses are taken

Plan E parked per-frame `ui.Image` handle disposal (R6-2) as a race it would
not open blind, and named a mutable `PatchRegion` and a reused uniform
`ByteData` as *"Plan F's frame-path work"* (RF-1). This plan takes the two
reuses (Task 6) because Task 8's probe measures them; R6-2 stays parked for
the reason given — the probe *reports* the handle count beside the gate, and
if the number says it matters, that is the evidence a later plan acts on.

### Ruling F11 — `DocumentLoaded` is fired through `CommandDispatcher.notifyLoaded()`

The trigger table's second row. The codec builds a *new* document on load, so
"load" as a widget event is `didUpdateWidget` with a new `document` — a full
re-attach with a fresh rebuilder, tested in Task 3. The `DocChange` itself is
public on the dispatcher (`notifyLoaded()`, `notifyPurged()` beside it) and
both the tests and the harness fire it directly, so the switch arm is
exercised, not assumed reachable.

### Ruling F12 — the `devicePixelRatio` trigger is tested by flipping `MediaQuery`

`DraftCanvas.build` reads `MediaQuery.devicePixelRatioOf(context)` per build.
Tests pump the canvas under `MediaQuery(data: MediaQueryData(devicePixelRatio:
1.0))` and then `2.0`; the harness wraps arm D in a `MediaQuery` whose ratio a
`ValueNotifier` overrides for one rebuild and restores. A window moving
between displays is not a fixture a suite can arrange; a `MediaQuery` change
is the same signal by the same path.

### Ruling F13 — criterion 12's resident arm is Plan E's composited instrument with the band policy applied in-rig

The spec: *"the instrument is the rig path, not the widget boundary"* and
*"compares against a live reference at the same camera, never against a
predecessor frame"*. The tiled arm is `TileRig` through `measureTiledAgreement`
(the probe's own arrangement, `tileDevicePixels: 64, tilesBakedPerFrame: 64`).
The resident arm is `measureCompositedAgreement` — Skia rasterising the
vertex shader's Dart transcription — with a `ResidentZoomRig` that collects
under `collectionFrameFor` at the gesture's start and re-collects whenever a
frame's ratio leaves the band, exactly as the rebuilder would. `CompositedAgreement`
gains an `uncovered` count (reference ink the resident arm left blank). The
gate is *zero uncovered at every frame* on the resident arm and *nonzero
somewhere in the gesture* on the tiled arm — the reproduction is asserted so
the resident zero is not vacuous.

### Ruling F14 — `debugSetGpuAvailable` is the test seam that lets a widget test take the resident path without a GPU

`gpuAvailable()` caches one answer and `debugSetGpuFactory` can only make it
`false` (a factory that throws) — no test can construct a `gpu.GpuContext`.
`gpu_facade.dart` gains `debugSetGpuAvailable(bool?)`, which sets the cached
answer directly (`null` clears it). With it and an injected
`ResidentUploader` returning a recording `ResidentFramePainter`, every trigger,
the coalescing, the fallback and the frame-path branch are tested GPU-free in
`flutter test`. `GpuDrawBackend` itself is still constructed only on a
device (Task 8, Task 10).

---

## Global Constraints

Copied verbatim from `CLAUDE.md`, the spec, and Plans A–E, with this plan's
additions marked.

- **The frame path allocates nothing per entity in steady state, and O(1) per
  flush.** Revision 5's stated exception: **a patch costs the engine one
  `saveLayer` and one `ui.Image` handle per frame**, per label later geometry
  reaches, plus the per-patch Dart objects the spec's exception sentence
  enumerates (`PatchImage`, three `Rect`s, `Transform2`, one layer, one image
  handle — `PatchRegion` and the uniform `ByteData` leave that list in Task 6).
  **This plan adds:** `ResidentRebuilder.noteFrame` is O(1) — three
  comparisons and a stored reference — and **never walks**; `markDirty`
  allocates one closure per *scheduled* rebuild, never per frame. The
  compositor's viewport test writes into a `Float64List(4)` field.
- **Draw order is emission order** — *not* "ascending handle value". **Never
  sort the buffer.** The grid classifier sorts *hit indices* so a patch's
  sub-buffer stays a subsequence of the main buffer in the main buffer's
  order; the brute-force oracle proves it byte for byte.
- **Geometric decisions use `Tolerance`; stored value comparisons are exact
  `==`.** The band test is a geometric decision made with plain `<`/`>` on a
  ratio of two `scaleMagnitude`s, conservative by construction. The
  `devicePixelRatio` and `mutationRevision` comparisons are stored-value
  comparisons: exact `==`.
- **Never commit `analysis_options.yaml`** — `flutter pub get` rewrites three
  of them in this workspace. Check `git status` before every commit and
  `git checkout --` them.
- **Never synthesize test output.** Run the command, paste what it printed,
  **including the exit code**. `dart format --set-exit-if-changed` printing
  `(1 changed)` **is** a failure even though the line looks informational.
- **Before firing a mutation, back the file up with `cp`, and restore from
  that copy.** Never `git checkout --` a file to revert a mutation.
- Code, comments and commit messages in English.
- **`packages/jet_cad_2d` is untouched by this plan.** `DocChange`,
  `CommandDispatcher.notifyLoaded`/`notifyPurged`, `Tables.mutationRevision`,
  `LayerRecord`, `Aabb2.transformedBy` are **read**, never edited.
- **`vertices_draw_sink.dart` and `canvas_draw_sink.dart` are untouched by
  this plan.** They are the oracle; editing either makes the composited
  differential circular.
- **`DraftPainter` gains no API** (spec invariant 4). The collection frame is
  a camera and a viewport handed to the existing `paint`.
- **No shader change.** `shaders/cad_stroke.vert`, `cad_stroke.frag` and
  `assets/shaders/cad.shaderbundle` are not touched. If an implementer finds
  a reason to touch the shader, that is a plan defect to ledger, not a change
  to make.
- **`ResolvedStyle` takes four required named arguments** — `argb`,
  `lineweightHundredths`, `linetype`, `linetypeScale`.
- **`TextStyleRecord` in tests is spelled the way `canvas_draw_sink_test.dart:17`
  spells it:** `const TextStyleRecord(handle: Handle(11), name: 'Standard',
  fontFamily: 'Roboto')`.
- **Fonts in `flutter test` are not the device's fonts.** No text pixel
  assertion hard-codes a glyph position.
- **`vm_service` is a dependency of `apps/dev_harness_2d` only.** Neither
  package gains it.
- **Timing gates use the aggregation rule:** median of three interleaved
  per-repeat p50s, per stage. Every rebuild figure is the median over the
  repeats of the per-trigger wall clock, **warm** (the first rebuild of a
  process is reported beside it as cold and is not the gated number).
- Every task ends green:
  ```sh
  cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
  ```
  Tasks 8, 9 and 10 additionally run:
  ```sh
  cd packages/jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
  cd apps/dev_harness_2d && flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
  ```

## File structure

| file | responsibility |
|---|---|
| `lib/src/gpu/collection_frame.dart` | **create** — `CollectionFrame`, `collectionFrameFor` |
| `lib/src/gpu/resident_collection.dart` | **create** — `ResidentCollection`, `ResidentCollection.collect` |
| `lib/src/gpu/resident_rebuilder.dart` | **create** — `RebuildTrigger`, `ResidentFramePainter`, `ResidentUploader`, `uploadResidentCollection`, `ResidentRebuilder` |
| `lib/src/gpu/gpu_facade.dart` | **modify** — `debugSetGpuAvailable` |
| `lib/src/gpu/gpu_draw_backend.dart` | **modify** — `implements ResidentFramePainter`; `buildFrameInfo(out:)`; the `PatchRegion` pool; parallel pending lists |
| `lib/src/gpu/text_patches.dart` | **modify** — grid `classifyTextPatches`, `classifyTextPatchesBruteForce`, `ClassifyStats`, `kClassifyOverflowCells`, mutable `PatchRegion` + `patchRegionFor(out:)` |
| `lib/src/gpu/text_compositor.dart` | **modify** — viewport rejection, `labelsSkipped` |
| `lib/src/render_backend.dart` | **modify** — `residentGpu`'s doc no longer says "until Plan F" |
| `lib/src/draft_canvas.dart` | **modify** — the resident path, `resident`, `residentUploader`, the fallback latch |
| `lib/jet_cad_2d_flutter.dart` | **modify** — export the three new files |
| `test/support/gpu_comparison.dart` | **modify** — `CompositedAgreement.uncovered`, `collectionViewport:` |
| `test/support/recording_frame_painter.dart` | **create** — `RecordingFramePainter`, `FakeUploader`, `zoomedAbout` |
| `test/support/resident_zoom_rig.dart` | **create** — `ResidentZoomRig` |
| `test/gpu/collection_frame_test.dart` | **create** |
| `test/gpu/resident_collection_test.dart` | **create** |
| `test/gpu/resident_rebuilder_test.dart` | **create** |
| `test/gpu/draft_canvas_resident_test.dart` | **create** — the five triggers and the two non-triggers |
| `test/gpu/draft_canvas_fallback_test.dart` | **create** — criterion 10, both fallbacks |
| `test/gpu/classify_grid_test.dart` | **create** |
| `test/gpu/text_compositor_viewport_test.dart` | **create** — viewport rejection |
| `test/gpu/text_patches_test.dart` | **modify** — `PatchRegion` is no longer `const`; `out` |
| `test/gpu/frame_info_test.dart` | **modify** — `out` |
| `test/gpu/band_sweep_test.dart` | **create** — criterion 2 |
| `test/gpu/zoom_defect_test.dart` | **create** — criterion 12 |
| `apps/dev_harness_2d/pubspec.yaml` | **modify** — `vm_service` |
| `apps/dev_harness_2d/lib/allocation_probe.dart` | **create** |
| `apps/dev_harness_2d/lib/gpu_arm.dart` | **modify** — arm D, `fireRebuildTrigger`, the trigger / band-exit / alloc phases |
| `apps/dev_harness_2d/lib/main.dart` | **modify** — `parseBackend`, `residentGpu` |
| `apps/dev_harness_2d/test/gpu_widget_arm_test.dart` | **create** |
| `.vscode/launch.json` | **modify** — Plan F's two entries |
| `docs/superpowers/notes/plan-f-mutation-log.md` | **create** |
| `docs/superpowers/notes/2026-09-05-plan-f-results.md` | **create** |
| `docs/superpowers/specs/2026-08-29-gpu-resident-render-backend-design.md` | **modify** — open question 3 struck with a pointer |
| `STATUS.md` | **modify** |

All paths under `lib/` and `test/` are relative to `packages/jet_cad_2d_flutter/`.

---

## The rebuilder's contract, restated so no task restates it from memory

```dart
enum RebuildTrigger { initial, document, tables, devicePixelRatio, band }

abstract interface class ResidentFramePainter {
  void paint(Canvas canvas, ViewportTransform camera, Size viewport, double dpr);
  void dispose();
}

typedef ResidentUploader = Future<ResidentFramePainter?> Function(
    ResidentCollection collection, Size viewport);

class ResidentRebuilder extends ChangeNotifier {
  ResidentFramePainter? get backend;      // null before the first landing, and forever after a failed upload
  ResidentCollection? get collection;     // what `backend` was built from
  RebuildTrigger? get pending;            // the reason the next rebuild will carry, or null
  bool get inFlight;                      // a walk has started and its upload has not landed
  bool get uploadFailed;                  // an upload returned null; no further rebuild is attempted
  int rebuilds, landed, bandStaleFrames;  // walks started; rebuilds installed; frames drawn out of band
  int lastWalkMicros, lastClassifyMicros, lastUploadMicros, lastTotalMicros;
  RebuildTrigger? lastTrigger;
  void noteFrame(ViewportTransform camera, Size viewport, double dpr, int tablesRevision);
  void markDirty(RebuildTrigger trigger);
  bool inBand(ViewportTransform camera);
  Future<void> rebuildNow(ViewportTransform camera, Size viewport, double dpr, RebuildTrigger trigger);
}
```

`noteFrame` is called by `_DraftCustomPainter.paint` **every frame, before it
draws**. It stores the frame's camera, viewport and dpr for the next rebuild,
increments `bandStaleFrames` when the camera is out of band, and marks dirty
in this order: no collection yet → `initial`; `tablesRevision !=
collection.tablesRevision` → `tables`; `dpr != collection.devicePixelRatio`
→ `devicePixelRatio`; `!inBand(camera)` → `band`. `document` is marked by
`DraftCanvas`'s `DocChangeNotifier.onChange` for **every** `DocChange`
subclass, `touched` unread.

---
### Task 1: The collection frame, and the GPU-free product of a rebuild

**Files:**
- Create: `lib/src/gpu/collection_frame.dart`
- Create: `lib/src/gpu/resident_collection.dart`
- Modify: `lib/jet_cad_2d_flutter.dart` (two exports)
- Test: `test/gpu/collection_frame_test.dart`, `test/gpu/resident_collection_test.dart`

**Interfaces:**
- Consumes: `DraftPainter.paint(DrawSink, ViewportTransform, Size)`,
  `GeometryCollector` (Plan E's constructor with `measurer`/`textStyleOf`),
  `classifyTextPatches`, `ResidentGeometry.byteLengthFor`,
  `Aabb2.transformedBy`, `kScreenClipInflate` (`draft_painter.dart:50`),
  `composeTransforms` (`gpu_draw_backend.dart`).
- Produces: `CollectionFrame(camera, viewport)`, `collectionFrameFor(live,
  extents, {margin})`, `ResidentCollection` with the fields below and
  `ResidentCollection.collect({...})`. Task 2's rebuilder calls `collect`;
  Task 7's zoom rig calls `collectionFrameFor`.

- [ ] **Step 1: Write the failing tests for the frame**

`test/gpu/collection_frame_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

/// A drawing well away from the origin, and a live camera zoomed onto a
/// point far outside it: at [kLiveViewport] this camera sees NONE of the
/// extents, so a collection culled to the live viewport would be empty --
/// which is the mutation this file exists to kill.
const Aabb2 kExtents = Aabb2.raw(1000, 2000, 7000, 5000);
const Size kLiveViewport = Size(800, 600);
final ViewportTransform kLive = ViewportTransform(
    worldToScreenMatrix:
        const Transform2(3.2, 0, 0, -3.2, -20000.0, 30000.0));

void main() {
  test('the live camera at its own viewport sees none of the drawing', () {
    // Anti-vacuity for every test below.
    expect(kLive.visibleWorld(kLiveViewport).intersects(kExtents), isFalse);
  });

  test("the frame's visible world covers the extents", () {
    final f = collectionFrameFor(kLive, kExtents);
    final world = f.camera.visibleWorld(f.viewport);
    expect(world.minX, lessThanOrEqualTo(kExtents.minX));
    expect(world.minY, lessThanOrEqualTo(kExtents.minY));
    expect(world.maxX, greaterThanOrEqualTo(kExtents.maxX));
    expect(world.maxY, greaterThanOrEqualTo(kExtents.maxY));
  });

  test("scale and rotation are the live camera's; only the translation moves",
      () {
    final f = collectionFrameFor(kLive, kExtents);
    final c = f.camera.worldToScreenMatrix;
    final l = kLive.worldToScreenMatrix;
    expect(c.a, l.a);
    expect(c.b, l.b);
    expect(c.c, l.c);
    expect(c.d, l.d);
    final toLive = composeTransforms(l, c.invert());
    expect(toLive.a, closeTo(1, 1e-12));
    expect(toLive.b, closeTo(0, 1e-12));
    expect(toLive.c, closeTo(0, 1e-12));
    expect(toLive.d, closeTo(1, 1e-12));
    expect(toLive.e.abs() + toLive.f.abs(), greaterThan(1000),
        reason: 'the two cameras must actually differ, or the translation '
            'claim is vacuous');
  });

  test("the viewport is the extents' screen size plus the margin, all round",
      () {
    final f = collectionFrameFor(kLive, kExtents, margin: 10);
    expect(f.viewport.width, closeTo(6000 * 3.2 + 20, 1e-9));
    expect(f.viewport.height, closeTo(3000 * 3.2 + 20, 1e-9));
    // y is flipped, so the world's MAX y is the screen's min.
    final corner = f.camera.worldToScreen(Vector2(1000, 5000));
    expect(corner.x, closeTo(10, 1e-9));
    expect(corner.y, closeTo(10, 1e-9));
  });

  test('a rotated live camera keeps its rotation and still covers the extents',
      () {
    final rotated = ViewportTransform(
        worldToScreenMatrix: Transform2.translation(-9000, 400)
            .multiply(Transform2.rotation(0.4))
            .multiply(Transform2.scale(2.0, -2.0)));
    final f = collectionFrameFor(rotated, kExtents);
    expect(f.camera.worldToScreenMatrix.b, rotated.worldToScreenMatrix.b);
    expect(f.camera.worldToScreenMatrix.c, rotated.worldToScreenMatrix.c);
    final world = f.camera.visibleWorld(f.viewport);
    expect(world.minX, lessThanOrEqualTo(kExtents.minX));
    expect(world.maxY, greaterThanOrEqualTo(kExtents.maxY));
  });

  test('empty extents give the live camera back and a 1x1 viewport', () {
    final f = collectionFrameFor(kLive, Aabb2.empty());
    expect(identical(f.camera, kLive), isTrue);
    expect(f.viewport, const Size(1, 1));
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `cd packages/jet_cad_2d_flutter && flutter test test/gpu/collection_frame_test.dart`
Expected: FAIL — `collectionFrameFor` undefined.

- [ ] **Step 3: The frame**

`lib/src/gpu/collection_frame.dart`:

```dart
import 'dart:ui' show Size;

import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../draft_painter.dart' show kScreenClipInflate;
import '../viewport_transform.dart';

/// The camera and viewport one rebuild walks under (Ruling F2).
///
/// [camera] has the live camera's scale and rotation and a translation that
/// puts the document's extents at the viewport's origin; [viewport] is the
/// extents' screen size plus a margin on every side. `DraftPainter.paint`
/// culls to `camera.visibleWorld(viewport)`, so under this pair nothing is
/// culled: a pan needs no rebuild, and neither does a viewport resize.
///
/// The two cameras differ by a pure translation, so
/// `composeTransforms(live, camera.invert())` is a translation and the
/// frame mapping `GpuDrawBackend.render` builds every frame is exact.
class CollectionFrame {
  const CollectionFrame(this.camera, this.viewport);
  final ViewportTransform camera;
  final Size viewport;
}

/// The frame a rebuild at [live] walks under, covering [extents].
///
/// [margin] defaults to the painter's own clip inflate so an entity on the
/// extents' edge, with its stroke width, is inside the frame; the painter
/// inflates its *clip* by the same amount but queries the index on the
/// un-inflated world rect, which is why the margin lives here.
///
/// **Float32 is the cost.** The buffer holds absolute frame coordinates,
/// bounded by the extents' size at the live scale: 1,350 px on the harness
/// floor at fit, 135,000 px at 100x (ulp 0.0078 px), 1.35 M px at 1000x
/// (ulp 0.125 px). Task 7's band sweep runs at a zoomed-in collection as
/// well as at fit, so the precision at a working scale is measured.
///
/// Empty extents -- an empty document -- give [live] back unchanged and a
/// 1x1 viewport: nothing to cover, nothing to shift, and a `Size.zero`
/// viewport would make `visibleWorld` degenerate.
CollectionFrame collectionFrameFor(ViewportTransform live, Aabb2 extents,
    {double margin = kScreenClipInflate}) {
  if (extents.isEmpty) return CollectionFrame(live, const Size(1, 1));
  final m = live.worldToScreenMatrix;
  final box = extents.transformedBy(Transform2(m.a, m.b, m.c, m.d, 0, 0));
  final camera = ViewportTransform(
      worldToScreenMatrix:
          Transform2(m.a, m.b, m.c, m.d, margin - box.minX, margin - box.minY));
  return CollectionFrame(
      camera,
      Size(box.maxX - box.minX + 2 * margin,
          box.maxY - box.minY + 2 * margin));
}
```

Add to `lib/jet_cad_2d_flutter.dart`, beside the other `src/gpu/` exports:

```dart
export 'src/gpu/collection_frame.dart';
export 'src/gpu/resident_collection.dart';
```

- [ ] **Step 4: Run the frame tests; expect PASS**

Run: `flutter test test/gpu/collection_frame_test.dart`

- [ ] **Step 5: Write the failing tests for the collection**

`test/gpu/resident_collection_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart';

import '../support/fixtures.dart';

void main() {
  late FlutterTextMeasurer measurer;
  late DraftDocument doc;
  late SpatialIndex index;
  late DraftPainter painter;

  setUp(() {
    measurer = FlutterTextMeasurer();
    doc = textOverlapFixture(measurer);
    index = SpatialIndex(doc);
    // Level of detail OFF: this fixture's TINY label sits at the culling
    // threshold on purpose, and a scale-dependent cull would make two
    // collections at two scales differ for a reason that is not culling to
    // the viewport. Ruling F6 measures that divergence in its own test.
    painter = DraftPainter(
        document: doc,
        index: index,
        resolver: DocumentStyleResolver(doc),
        minTextCapPixels: 0);
  });
  tearDown(() {
    index.dispose();
    measurer.clear();
  });

  ResidentCollection collect(ViewportTransform live, {double dpr = 1.0}) =>
      ResidentCollection.collect(
          document: doc,
          painter: painter,
          live: live,
          devicePixelRatio: dpr,
          pixelsPerPaperMm: kLogicalPixelsPerMm,
          lineweightScale: 1.0,
          measurer: measurer,
          textStyleOf: doc.textStyleOf);

  ViewportTransform fit() => ViewportTransform.fit(doc.extents, kViewport);

  /// 8x the fit scale, with the drawing's top-left corner near the screen's
  /// origin: the live viewport sees roughly a sixty-fourth of the drawing.
  ViewportTransform corner() {
    final s = fit().scale * 8;
    final e = doc.extents;
    return ViewportTransform(
        worldToScreenMatrix:
            Transform2(s, 0, 0, -s, -s * e.minX + 5, s * e.maxY + 5));
  }

  test('the corner camera sees only part of the drawing', () {
    // Anti-vacuity for the test below.
    final vis = corner().visibleWorld(kViewport);
    expect(vis.intersects(doc.extents), isTrue);
    expect(vis.maxX < doc.extents.maxX || vis.minY > doc.extents.minY, isTrue,
        reason: 'the live viewport must see only part of the drawing, or '
            'culling to it would be invisible here');
  });

  test('a collection at the corner zoom holds everything the fit one holds',
      () {
    final a = collect(fit());
    final b = collect(corner());
    // MUTATION: collect under `live` and `kViewport` instead of the frame
    // -> b.instanceCount is a fraction of a.instanceCount, b.texts shorter.
    expect(b.instanceCount, a.instanceCount,
        reason: 'this fixture has no curve, so the instance count is scale-'
            'free; a difference is culling');
    expect(b.texts.map((t) => t.text), a.texts.map((t) => t.text));
    expect(a.instanceCount, greaterThan(5));
    expect(a.texts.length, 4, reason: 'COVERED, UNDER, GRAZED, TINY');
    expect(a.skippedOps, 0);
  });

  test('the collection camera differs from the live camera by a translation',
      () {
    final live = corner();
    final c = collect(live);
    final toLive = composeTransforms(
        live.worldToScreenMatrix, c.collectionCamera.worldToScreenMatrix.invert());
    expect(toLive.a, closeTo(1, 1e-12));
    expect(toLive.d, closeTo(1, 1e-12));
    expect(c.collectionCamera.scale, closeTo(live.scale, 1e-12));
    expect(c.collectionViewport.width, greaterThan(kViewport.width),
        reason: 'at 8x the extents are wider than the live viewport');
  });

  test('the table revision and the ratio are the ones the walk ran at', () {
    final before = doc.tables.mutationRevision;
    final zero = doc.tables.layers[ReservedHandles.layerZero]!;
    doc.tables.layers.remove(zero.handle);
    doc.tables.layers.add(LayerRecord(
        handle: zero.handle,
        name: zero.name,
        color: const IndexedColor(1),
        linetype: zero.linetype,
        lineweight: zero.lineweight,
        transparency: zero.transparency,
        visible: zero.visible,
        locked: zero.locked));
    expect(doc.tables.mutationRevision, greaterThan(before));
    final c = collect(fit(), dpr: 2.0);
    expect(c.tablesRevision, doc.tables.mutationRevision);
    expect(c.devicePixelRatio, 2.0);
  });

  test('half-widths follow the device pixel ratio', () {
    double widest(ResidentCollection c) {
      var w = 0.0;
      for (var i = 0; i < c.instanceCount; i++) {
        final o = i * kFloatsPerInstance;
        if (c.data[o + InstanceFieldOffset.kind] != kKindStroke) continue;
        final h = c.data[o + InstanceFieldOffset.halfWidth];
        if (h > w) w = h;
      }
      return w;
    }
    final one = widest(collect(fit()));
    final two = widest(collect(fit(), dpr: 2.0));
    expect(one, greaterThan(GeometryCollector.kMinStrokeDevicePixels),
        reason: 'the widest stroke must be above the floor, or the floor '
            'clamps both and the ratio below is vacuous');
    expect(two, closeTo(2 * one, 1e-3));
  });

  test('the timings are read and the byte length counts the patches', () {
    final c = collect(fit());
    expect(c.walkMicros, greaterThanOrEqualTo(0));
    expect(c.classifyMicros, greaterThanOrEqualTo(0));
    expect(c.patches.length, 2, reason: 'COVERED and GRAZED (Plan E)');
    expect(c.byteLength,
        ResidentGeometry.byteLengthFor(c.instanceCount,
            patchInstances: c.patchInstanceCount));
    expect(c.patchInstanceCount, greaterThan(0));
  });
}
```

- [ ] **Step 6: Run them to verify they fail**

Run: `flutter test test/gpu/resident_collection_test.dart`
Expected: FAIL — `ResidentCollection` undefined.

- [ ] **Step 7: The collection**

`lib/src/gpu/resident_collection.dart`:

```dart
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../draft_painter.dart';
import '../viewport_transform.dart';
import 'collection_frame.dart';
import 'geometry_collector.dart';
import 'resident_geometry.dart';
import 'resident_text.dart';
import 'text_patches.dart';

/// One rebuild's GPU-free product: what `ResidentGeometry.create` uploads,
/// plus what the three frame-read triggers compare against.
///
/// **Allocated at rebuild, read on the frame.** [data] and [texts] are the
/// collector's own copies (`GeometryCollector.data` and `.texts` each copy
/// on access -- read once here, never per frame); [tablesRevision],
/// [devicePixelRatio] and [collectionCamera] are what `ResidentRebuilder.noteFrame`
/// reads to decide whether the picture on screen was collected under the
/// tables, the display and the scale the frame is drawn at.
class ResidentCollection {
  const ResidentCollection({
    required this.data,
    required this.instanceCount,
    required this.texts,
    required this.patches,
    required this.collectionCamera,
    required this.collectionViewport,
    required this.devicePixelRatio,
    required this.tablesRevision,
    required this.skippedOps,
    required this.walkMicros,
    required this.classifyMicros,
  });

  final Float32List data;
  final int instanceCount;
  final List<ResidentTextRecord> texts;
  final List<TextPatch> patches;

  /// The frame's camera (Ruling F2): the live camera's scale and rotation,
  /// translated so the extents sit at the origin. `GpuDrawBackend` maps out
  /// of this space every frame.
  final ViewportTransform collectionCamera;
  final Size collectionViewport;
  final double devicePixelRatio;

  /// `document.tables.mutationRevision`, read before the walk.
  final int tablesRevision;
  final int skippedOps;
  final int walkMicros;
  final int classifyMicros;

  int get patchInstanceCount =>
      patches.fold(0, (sum, p) => sum + p.instanceCount);

  /// The budget row's number, before upload: main buffer plus every patch
  /// sub-buffer, as `ResidentGeometry.byteLength` will report it.
  int get byteLength =>
      ResidentGeometry.byteLengthFor(instanceCount,
          patchInstances: patchInstanceCount);

  /// Walks [document] through [painter] under the frame [collectionFrameFor]
  /// gives for [live], then classifies. Synchronous; the caller (the
  /// rebuilder's post-frame callback) is what keeps it off the frame path.
  ///
  /// [painter] is the widget's own `DraftPainter` -- its `drawText` and
  /// `minTextCapPixels` are the walk's, so a `DRAW_TEXT=false` canvas
  /// collects no text and a canvas with level of detail on culls at the
  /// collection scale, exactly as the reference sink would at that scale.
  static ResidentCollection collect({
    required DraftDocument document,
    required DraftPainter painter,
    required ViewportTransform live,
    required double devicePixelRatio,
    required double pixelsPerPaperMm,
    required double lineweightScale,
    required TextMeasurer? measurer,
    required TextStyleRecord Function(Handle)? textStyleOf,
    double bandLowerScale = kBandLowerScale,
  }) {
    // Read before the walk: the revision the picture is *of*. A table edit
    // cannot land during the walk (one isolate), so before and after are
    // the same number; "before" is the one whose meaning does not depend on
    // that argument.
    final tablesRevision = document.tables.mutationRevision;
    final frame = collectionFrameFor(live, document.extents);
    final walk = Stopwatch()..start();
    final collector = GeometryCollector(
        pixelsPerPaperMm: pixelsPerPaperMm,
        devicePixelRatio: devicePixelRatio,
        lineweightScale: lineweightScale,
        measurer: measurer,
        textStyleOf: textStyleOf);
    painter.paint(collector, frame.camera, frame.viewport);
    // One copy each, at rebuild -- see the two getters' own doc comments.
    final data = collector.data;
    final texts = collector.texts;
    walk.stop();
    final classify = Stopwatch()..start();
    final patches = classifyTextPatches(data, collector.instanceCount, texts,
        devicePixelRatio: devicePixelRatio, bandLowerScale: bandLowerScale);
    classify.stop();
    return ResidentCollection(
      data: data,
      instanceCount: collector.instanceCount,
      texts: texts,
      patches: patches,
      collectionCamera: frame.camera,
      collectionViewport: frame.viewport,
      devicePixelRatio: devicePixelRatio,
      tablesRevision: tablesRevision,
      skippedOps: collector.skippedOps,
      walkMicros: walk.elapsedMicroseconds,
      classifyMicros: classify.elapsedMicroseconds,
    );
  }
}
```

- [ ] **Step 8: Run both files; expect PASS. Fire the mutation once, by hand**

Run: `flutter test test/gpu/collection_frame_test.dart test/gpu/resident_collection_test.dart`

Then, with `cp lib/src/gpu/resident_collection.dart /tmp/rc.bak`, replace the
two `frame.*` arguments of `painter.paint` with `live` and `const Size(800,
600)`; run `resident_collection_test.dart`; expect *"a collection at the
corner zoom holds everything the fit one holds"* red with `b.instanceCount`
smaller than `a.instanceCount`; restore with `cp /tmp/rc.bak
lib/src/gpu/resident_collection.dart`. Paste both outputs in the report.
This is the spec's *"cull collection to the live viewport"* mutation and Task
9 fires it again for the log.

- [ ] **Step 9: Gates, commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git status --short   # no analysis_options.yaml
git add lib/src/gpu/collection_frame.dart lib/src/gpu/resident_collection.dart lib/jet_cad_2d_flutter.dart test/gpu/collection_frame_test.dart test/gpu/resident_collection_test.dart
git commit -m "feat(gpu): the collection frame covers the extents, and a rebuild has a GPU-free product"
```

---

### Task 2: The rebuilder — one schedule, five triggers, and the frame that never waits

**Files:**
- Create: `lib/src/gpu/resident_rebuilder.dart`
- Modify: `lib/src/gpu/gpu_facade.dart` (`debugSetGpuAvailable`)
- Modify: `lib/src/gpu/gpu_draw_backend.dart` (`implements ResidentFramePainter`, one line plus the import)
- Modify: `lib/jet_cad_2d_flutter.dart` (export)
- Create: `test/support/recording_frame_painter.dart`
- Test: `test/gpu/resident_rebuilder_test.dart`, `test/gpu/gpu_facade_test.dart` (one added test)

**Interfaces:**
- Consumes: `ResidentCollection.collect` (Task 1), `ResidentGeometry.create`,
  `GpuDrawBackend(geometry, collectionCamera, {measurer, textStyleOf})`,
  `SchedulerBinding.instance.addPostFrameCallback` / `ensureVisualUpdate`.
- Produces: everything in *"The rebuilder's contract"* above, plus
  `uploadResidentCollection(collection, viewport, {measurer, textStyleOf})`
  — the production `ResidentUploader` Task 3 wires — and, for tests,
  `RecordingFramePainter`, `FakeUploader`, `zoomedAbout`.

- [ ] **Step 1: The test seam in the facade, and its test**

Append to `lib/src/gpu/gpu_facade.dart`, after `debugSetGpuFactory`:

```dart
/// **Test seam.** Pins [gpuAvailable]'s cached answer; `null` clears it so
/// the next call probes again.
///
/// [debugSetGpuFactory] can only make the answer `false` -- a factory that
/// throws -- because no test can construct a `gpu.GpuContext`. A widget test
/// that wants `DraftCanvas` to take the `residentGpu` path GPU-free (Ruling
/// F14) needs the answer `true`, and this is the only honest way to say it:
/// the path it enables still cannot upload, so such a test also injects a
/// `ResidentUploader` that never touches a GPU.
void debugSetGpuAvailable(bool? available) {
  _available = available;
}
```

Add to `test/gpu/gpu_facade_test.dart`:

```dart
  test('debugSetGpuAvailable pins the answer, and null clears it', () {
    addTearDown(() => debugSetGpuAvailable(null));
    debugSetGpuAvailable(true);
    expect(gpuAvailable(), isTrue);
    debugSetGpuAvailable(false);
    expect(gpuAvailable(), isFalse);
    debugSetGpuAvailable(null);
    debugSetGpuFactory(() => throw StateError('no gpu'));
    addTearDown(() => debugSetGpuFactory(null));
    expect(gpuAvailable(), isFalse, reason: 'cleared: the factory probes');
  });
```

Run: `flutter test test/gpu/gpu_facade_test.dart` — PASS.

- [ ] **Step 2: The test support**

`test/support/recording_frame_painter.dart`:

```dart
import 'dart:async';
import 'dart:ui';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

/// A `ResidentFramePainter` that draws nothing and remembers being asked.
/// Stands in for `GpuDrawBackend`, which cannot be constructed without a
/// live GPU (`resident_geometry.dart`'s own doc comment on `create`).
class RecordingFramePainter implements ResidentFramePainter {
  RecordingFramePainter(this.collection);
  final ResidentCollection collection;
  int paints = 0;
  bool disposed = false;
  ViewportTransform? lastCamera;
  Size? lastViewport;
  double? lastDpr;

  @override
  void paint(Canvas canvas, ViewportTransform camera, Size viewport, double dpr) {
    paints++;
    lastCamera = camera;
    lastViewport = viewport;
    lastDpr = dpr;
  }

  @override
  void dispose() => disposed = true;
}

/// An uploader the test controls: hands back a [RecordingFramePainter] over
/// the collection it was given, or `null` while [failing]; [gate], when set,
/// holds the upload in flight until the test completes it.
class FakeUploader {
  bool failing = false;
  Completer<void>? gate;
  final List<ResidentCollection> collections = <ResidentCollection>[];
  final List<RecordingFramePainter> painters = <RecordingFramePainter>[];

  Future<ResidentFramePainter?> call(
      ResidentCollection collection, Size viewport) async {
    collections.add(collection);
    final g = gate;
    if (g != null) await g.future;
    if (failing) return null;
    final p = RecordingFramePainter(collection);
    painters.add(p);
    return p;
  }
}

/// [base] scaled by [s] about [centre], in screen space -- the same
/// composition `text_order_test.dart`'s `_scaled` uses.
ViewportTransform zoomedAbout(ViewportTransform base, Offset centre, double s) {
  final m = Transform2.translation(centre.dx, centre.dy)
      .multiply(Transform2.scale(s, s))
      .multiply(Transform2.translation(-centre.dx, -centre.dy))
      .multiply(base.worldToScreenMatrix);
  return ViewportTransform(worldToScreenMatrix: m);
}
```

- [ ] **Step 3: Write the failing rebuilder tests**

`test/gpu/resident_rebuilder_test.dart`:

```dart
import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/fixtures.dart';
import '../support/recording_frame_painter.dart';

void main() {
  late FlutterTextMeasurer measurer;
  late DraftDocument doc;
  late SpatialIndex index;
  late DraftPainter painter;
  late FakeUploader uploader;
  late ResidentRebuilder r;
  const centre = Offset(400, 300);

  setUp(() {
    measurer = FlutterTextMeasurer();
    doc = textOverlapFixture(measurer);
    index = SpatialIndex(doc);
    painter = DraftPainter(
        document: doc,
        index: index,
        resolver: DocumentStyleResolver(doc),
        minTextCapPixels: 0);
    uploader = FakeUploader();
    r = ResidentRebuilder(
        document: doc,
        painter: painter,
        uploader: uploader.call,
        pixelsPerPaperMm: kLogicalPixelsPerMm,
        lineweightScale: 1.0,
        measurer: measurer,
        textStyleOf: doc.textStyleOf);
  });
  tearDown(() {
    r.dispose();
    index.dispose();
    measurer.clear();
  });

  ViewportTransform fit() => ViewportTransform.fit(doc.extents, kViewport);
  int rev() => doc.tables.mutationRevision;

  /// The post-frame callback fires at the end of the first pump; the fake
  /// upload completes in a microtask; the second pump is the frame the
  /// landing asked for.
  Future<void> land(WidgetTester t) async {
    await t.pump();
    await t.pump();
  }

  testWidgets('the first frame marks initial and does not walk; the post-frame '
      'callback does', (t) async {
    r.noteFrame(fit(), kViewport, 1.0, rev());
    expect(r.pending, RebuildTrigger.initial);
    // MUTATION (M-F7): walk inside noteFrame -> rebuilds is already 1 here.
    expect(r.rebuilds, 0, reason: 'noteFrame never walks (Ruling F3)');
    expect(r.backend, isNull);
    await land(t);
    expect(r.rebuilds, 1);
    expect(r.landed, 1);
    expect(r.backend, isA<RecordingFramePainter>());
    expect(r.collection!.texts.length, 4);
    expect(r.pending, isNull);
    expect(r.lastTrigger, RebuildTrigger.initial);
    expect(r.lastTotalMicros, greaterThan(0));
  });

  testWidgets('three marks before the frame ends are one rebuild, named for '
      'the first', (t) async {
    r.noteFrame(fit(), kViewport, 1.0, rev());
    await land(t);
    r.markDirty(RebuildTrigger.document);
    r.markDirty(RebuildTrigger.band);
    r.markDirty(RebuildTrigger.tables);
    expect(r.pending, RebuildTrigger.document);
    await land(t);
    // MUTATION (M-F6): schedule a callback per markDirty -> rebuilds is 4.
    expect(r.rebuilds, 2);
    expect(r.lastTrigger, RebuildTrigger.document);
  });

  testWidgets('a mark during an upload in flight queues exactly one more',
      (t) async {
    r.noteFrame(fit(), kViewport, 1.0, rev());
    await land(t);
    uploader.gate = Completer<void>();
    r.markDirty(RebuildTrigger.document);
    await t.pump();
    expect(r.inFlight, isTrue);
    expect(r.rebuilds, 2);
    r.markDirty(RebuildTrigger.tables);
    r.markDirty(RebuildTrigger.tables);
    expect(r.pending, RebuildTrigger.tables);
    uploader.gate!.complete();
    uploader.gate = null;
    await land(t);
    await land(t);
    // MUTATION (M-F13): drop the reschedule at the end of _run -> rebuilds 2.
    expect(r.rebuilds, 3);
    expect(r.landed, 3);
    expect(r.inFlight, isFalse);
    expect(r.pending, isNull);
    expect(uploader.painters[1].disposed, isTrue,
        reason: 'the superseded backend is disposed on the swap');
    expect(identical(r.backend, uploader.painters[2]), isTrue);
  });

  testWidgets('the band is read as live over collection', (t) async {
    final base = fit();
    r.noteFrame(base, kViewport, 1.0, rev());
    await land(t);
    for (final s in const [0.5, 0.8, 1.0, 1.6, 2.0]) {
      r.noteFrame(zoomedAbout(base, centre, s), kViewport, 1.0, rev());
      expect(r.pending, isNull, reason: 'ratio $s is inside [0.5, 2.0]');
    }
    expect(r.bandStaleFrames, 0);
    r.noteFrame(zoomedAbout(base, centre, 2.01), kViewport, 1.0, rev());
    // MUTATION (M-F3): ratio = collection.scale / collection.scale -> never.
    expect(r.pending, RebuildTrigger.band);
    await land(t);
    expect(r.rebuilds, 2);
    expect(r.lastTrigger, RebuildTrigger.band);
    // The new collection is at 2.01x. 1.1 / 2.01 = 0.547 is inside its band
    // (not 1.005: that is 0.5 exactly in real numbers and a coin toss in
    // doubles); 0.98 / 2.01 = 0.488 is outside.
    r.noteFrame(zoomedAbout(base, centre, 1.1), kViewport, 1.0, rev());
    expect(r.pending, isNull);
    r.noteFrame(zoomedAbout(base, centre, 0.98), kViewport, 1.0, rev());
    expect(r.pending, RebuildTrigger.band);
    expect(r.bandStaleFrames, 2, reason: 'the 2.01 frame and the 0.98 frame');
  });

  testWidgets('the table revision counter triggers a rebuild, and the new '
      'collection carries the new revision', (t) async {
    r.noteFrame(fit(), kViewport, 1.0, rev());
    await land(t);
    final before = rev();
    final zero = doc.tables.layers[ReservedHandles.layerZero]!;
    doc.tables.layers.remove(zero.handle);
    doc.tables.layers.add(LayerRecord(
        handle: zero.handle,
        name: zero.name,
        color: const IndexedColor(1),
        linetype: zero.linetype,
        lineweight: zero.lineweight,
        transparency: zero.transparency,
        visible: zero.visible,
        locked: zero.locked));
    expect(rev(), greaterThan(before));
    r.noteFrame(fit(), kViewport, 1.0, rev());
    // MUTATION (M-F1): drop the revision comparison -> pending stays null.
    expect(r.pending, RebuildTrigger.tables);
    await land(t);
    expect(r.collection!.tablesRevision, rev());
    r.noteFrame(fit(), kViewport, 1.0, rev());
    expect(r.pending, isNull, reason: 'settled: no second rebuild');
  });

  testWidgets('a device pixel ratio change triggers a rebuild whose half-widths '
      'follow it', (t) async {
    r.noteFrame(fit(), kViewport, 1.0, rev());
    await land(t);
    final one = r.collection!;
    r.noteFrame(fit(), kViewport, 2.0, rev());
    // MUTATION (M-F2): drop the dpr comparison -> pending stays null.
    expect(r.pending, RebuildTrigger.devicePixelRatio);
    await land(t);
    final two = r.collection!;
    expect(two.devicePixelRatio, 2.0);
    // Same instance count, wider strokes: the same test Task 1 makes, on the
    // rebuilder's own output.
    expect(two.instanceCount, one.instanceCount);
    var wOne = 0.0, wTwo = 0.0;
    for (var i = 0; i < one.instanceCount; i++) {
      final o = i * 16 + 1; // InstanceFieldOffset.halfWidth, kFloatsPerInstance
      if (one.data[o] > wOne) wOne = one.data[o];
      if (two.data[o] > wTwo) wTwo = two.data[o];
    }
    expect(wTwo, closeTo(2 * wOne, 1e-3));
  });

  testWidgets('an edited label draws the new string: the text list is not '
      'stale across a rebuild', (t) async {
    r.noteFrame(fit(), kViewport, 1.0, rev());
    await land(t);
    expect(r.collection!.texts.map((x) => x.text), contains('COVERED'));
    doc.commands.execute(SetEntityTextCommand(const Handle(901), 'EDITED', ''));
    r.markDirty(RebuildTrigger.document);
    await land(t);
    // MUTATION (M-F4): hand the previous collection's texts to the new one
    // -> 'COVERED' survives and 'EDITED' never appears.
    final texts = r.collection!.texts.map((x) => x.text).toList();
    expect(texts, contains('EDITED'));
    expect(texts, isNot(contains('COVERED')));
    expect(identical(r.backend, uploader.painters.last), isTrue);
    expect(uploader.painters.last.collection.texts.map((x) => x.text),
        contains('EDITED'),
        reason: 'the backend was built from the new collection');
  });

  testWidgets('a failed upload falls back for good: no backend, no retry',
      (t) async {
    uploader.failing = true;
    r.noteFrame(fit(), kViewport, 1.0, rev());
    await land(t);
    expect(r.landed, 1);
    expect(r.backend, isNull);
    expect(r.uploadFailed, isTrue);
    r.markDirty(RebuildTrigger.document);
    r.noteFrame(zoomedAbout(fit(), centre, 3.0), kViewport, 1.0, rev());
    await land(t);
    expect(r.rebuilds, 1, reason: 'criterion 10: fall back once, not per frame');
    expect(r.pending, isNull);
  });

  testWidgets('a painter that lands after dispose is disposed, not installed',
      (t) async {
    r.noteFrame(fit(), kViewport, 1.0, rev());
    uploader.gate = Completer<void>();
    await t.pump();
    expect(r.inFlight, isTrue);
    r.dispose();
    uploader.gate!.complete();
    uploader.gate = null;
    await t.pump();
    await t.pump();
    expect(uploader.painters.single.disposed, isTrue);
    expect(r.backend, isNull);
    expect(r.landed, 0);
    // tearDown disposes again; ChangeNotifier tolerates it only if we do not
    // notify after dispose -- which the assertion above already proves.
  });
}
```

`tearDown`'s second `r.dispose()` on an already-disposed notifier: guard
`dispose` with `if (_disposed) return;` (in the implementation below) so this
file's last test does not throw in teardown.

- [ ] **Step 4: Run to verify they fail**

Run: `flutter test test/gpu/resident_rebuilder_test.dart`
Expected: FAIL — `ResidentRebuilder`, `ResidentFramePainter` undefined.

- [ ] **Step 5: The rebuilder**

`lib/src/gpu/resident_rebuilder.dart`:

```dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Canvas, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../draft_painter.dart';
import '../flutter_text_measurer.dart';
import '../viewport_transform.dart';
import 'gpu_draw_backend.dart';
import 'resident_collection.dart';
import 'resident_geometry.dart';
import 'text_patches.dart';

/// Why a rebuild ran. The spec's five triggers, plus the first build.
///
/// [document] is every `DocChange` -- `CommandApplied`, `CommandUndone`,
/// `CommandRedone`, `DocumentLoaded`, `DocumentPurged` -- with `touched`
/// unread: the spec declares "rebuild only when `touched` is non-empty" an
/// equivalent mutation, and this enum does not distinguish the five.
enum RebuildTrigger { initial, document, tables, devicePixelRatio, band }

/// What the frame path paints through once a rebuild has landed.
///
/// `GpuDrawBackend` is the production implementation. Tests substitute a
/// recorder, because a `GpuDrawBackend` needs a `ResidentGeometry` and
/// `ResidentGeometry.create` needs a live GPU.
abstract interface class ResidentFramePainter {
  void paint(Canvas canvas, ViewportTransform camera, Size viewport, double dpr);
  void dispose();
}

/// Turns one collection into a frame painter, or `null` when it cannot.
typedef ResidentUploader = Future<ResidentFramePainter?> Function(
    ResidentCollection collection, Size viewport);

/// The production uploader: `ResidentGeometry.create`, then a
/// `GpuDrawBackend` over it. `null` when the platform has no GPU or the
/// upload failed -- `create` has already reported the failure through
/// `FlutterError.reportError` (its own doc comment), so nothing is reported
/// twice here.
///
/// [viewport] is the widget's logical size, the ceiling for the patch
/// targets; a `Size.zero` first layout still asks for a 1x1 ceiling rather
/// than a texture the driver refuses.
Future<ResidentFramePainter?> uploadResidentCollection(
  ResidentCollection collection,
  Size viewport, {
  required FlutterTextMeasurer measurer,
  required TextStyleRecord Function(Handle) textStyleOf,
}) async {
  final dpr = collection.devicePixelRatio;
  final geometry = await ResidentGeometry.create(
      collection.data, collection.instanceCount,
      texts: collection.texts,
      patches: collection.patches,
      devicePixelRatio: dpr,
      maxPatchWidth: math.max(1, (viewport.width * dpr).round()),
      maxPatchHeight: math.max(1, (viewport.height * dpr).round()));
  if (geometry == null) return null;
  return GpuDrawBackend(geometry, collection.collectionCamera,
      measurer: measurer, textStyleOf: textStyleOf);
}

/// Owns the resident backend's lifecycle for one `DraftCanvas` attachment:
/// when to rebuild, and what the frame paints through meanwhile.
///
/// **The frame never waits** (Ruling F3). [noteFrame] is O(1) and never
/// walks; [markDirty] records a reason and schedules ONE post-frame callback;
/// the callback walks and classifies (on the UI thread, after the frame's
/// paint has finished), awaits the upload, swaps [backend] in and notifies.
/// A trigger during the await queues exactly one more rebuild. The frame
/// that fires a trigger is drawn with the collection it has -- criterion 9's
/// stale interval, counted in [bandStaleFrames] for the band case.
///
/// **Once an upload returns `null` the rebuilder stops** ([uploadFailed]):
/// no backend, no retry, every later [markDirty] ignored. The widget paints
/// through `VerticesDrawSink` from then on and says so once (Ruling F5).
class ResidentRebuilder extends ChangeNotifier {
  ResidentRebuilder({
    required this.document,
    required this.painter,
    required this.uploader,
    required this.pixelsPerPaperMm,
    required this.lineweightScale,
    required this.measurer,
    required this.textStyleOf,
    this.bandLowerScale = kBandLowerScale,
    this.bandUpperScale = kBandUpperScale,
  });

  final DraftDocument document;

  /// The widget's own painter: its `drawText` and `minTextCapPixels` are the
  /// walk's. Reused across rebuilds, never rebuilt here.
  final DraftPainter painter;
  final ResidentUploader uploader;
  final double pixelsPerPaperMm;
  final double lineweightScale;
  final TextMeasurer? measurer;
  final TextStyleRecord Function(Handle)? textStyleOf;
  final double bandLowerScale;
  final double bandUpperScale;

  ResidentFramePainter? _backend;
  ResidentFramePainter? get backend => _backend;

  ResidentCollection? _collection;
  ResidentCollection? get collection => _collection;

  RebuildTrigger? _pending;
  RebuildTrigger? get pending => _pending;

  RebuildTrigger? _inFlightTrigger;
  bool get inFlight => _inFlightTrigger != null;

  bool _scheduled = false;
  bool _disposed = false;
  bool get disposed => _disposed;

  bool _uploadFailed = false;
  bool get uploadFailed => _uploadFailed;

  /// Walks started. Every walk lands ([landed]) unless [dispose] ran first.
  int rebuilds = 0;
  int landed = 0;

  /// Frames [noteFrame] saw with the camera outside the band -- drawn from
  /// a collection the band has already condemned. Criterion 9's number.
  int bandStaleFrames = 0;

  int lastWalkMicros = 0;
  int lastClassifyMicros = 0;
  int lastUploadMicros = 0;
  int lastTotalMicros = 0;
  RebuildTrigger? lastTrigger;

  ViewportTransform? _camera;
  Size? _viewport;
  double _dpr = 1.0;

  /// Every frame, before the draw. Stores the frame's camera, viewport and
  /// dpr for the next rebuild, then fires the three frame-read triggers in
  /// this order: no collection -> [RebuildTrigger.initial]; a table revision
  /// other than the collection's -> [RebuildTrigger.tables]; a dpr other
  /// than the collection's (exact `==`, a stored value) ->
  /// [RebuildTrigger.devicePixelRatio]; a camera outside the band ->
  /// [RebuildTrigger.band]. One reason per frame; they coalesce anyway.
  void noteFrame(
      ViewportTransform camera, Size viewport, double dpr, int tablesRevision) {
    _camera = camera;
    _viewport = viewport;
    _dpr = dpr;
    final c = _collection;
    if (c == null) {
      markDirty(RebuildTrigger.initial);
      return;
    }
    final banded = inBand(camera);
    if (!banded) bandStaleFrames++;
    if (tablesRevision != c.tablesRevision) {
      markDirty(RebuildTrigger.tables);
    } else if (dpr != c.devicePixelRatio) {
      markDirty(RebuildTrigger.devicePixelRatio);
    } else if (!banded) {
      markDirty(RebuildTrigger.band);
    }
  }

  /// Whether [camera]'s scale, over the collection's, is inside
  /// `[bandLowerScale, bandUpperScale]`. **Live over collection**, read
  /// every frame -- the spec's mutation is reading it against the reference
  /// scale, which makes every ratio 1. A geometric decision made with plain
  /// comparisons on a ratio; conservative by construction. False with no
  /// collection.
  bool inBand(ViewportTransform camera) {
    final c = _collection;
    if (c == null) return false;
    final ratio = camera.scale / c.collectionCamera.scale;
    return ratio >= bandLowerScale && ratio <= bandUpperScale;
  }

  /// Records [trigger] and schedules a rebuild after the current frame, if
  /// one is not already scheduled or in flight. The first reason wins the
  /// name. Ignored after [dispose] and after a failed upload.
  void markDirty(RebuildTrigger trigger) {
    if (_disposed || _uploadFailed) return;
    _pending ??= trigger;
    if (_inFlightTrigger != null || _scheduled) return;
    _schedule();
  }

  void _schedule() {
    _scheduled = true;
    final binding = SchedulerBinding.instance;
    binding.addPostFrameCallback((_) {
      _scheduled = false;
      unawaited(_run());
    });
    // A DocChange arrives between frames; a post-frame callback needs a
    // frame to be post to. From inside a frame's paint this is a no-op
    // (`ensureVisualUpdate` returns during `persistentCallbacks`), which is
    // exactly right: the frame is already running and its end is the
    // callback's cue.
    binding.ensureVisualUpdate();
  }

  Future<void> _run() async {
    final trigger = _pending;
    final camera = _camera;
    final viewport = _viewport;
    // No frame has told us the camera yet: keep the reason, and the first
    // noteFrame marks again with a camera in hand.
    if (_disposed || trigger == null || camera == null || viewport == null) {
      return;
    }
    _pending = null;
    _inFlightTrigger = trigger;
    try {
      await rebuildNow(camera, viewport, _dpr, trigger);
    } finally {
      _inFlightTrigger = null;
    }
    if (!_disposed && _pending != null && !_uploadFailed) _schedule();
  }

  /// The walk, the classification, the upload, the swap. Public for the
  /// harness's trigger phases and the tests; the schedule calls it too.
  ///
  /// The walk and the classification run synchronously here (this is the
  /// post-frame callback's body, not a frame's); the upload is awaited. A
  /// painter that arrives after [dispose] is disposed and never installed.
  Future<void> rebuildNow(ViewportTransform camera, Size viewport, double dpr,
      RebuildTrigger trigger) async {
    rebuilds++;
    final total = Stopwatch()..start();
    final next = ResidentCollection.collect(
        document: document,
        painter: painter,
        live: camera,
        devicePixelRatio: dpr,
        pixelsPerPaperMm: pixelsPerPaperMm,
        lineweightScale: lineweightScale,
        measurer: measurer,
        textStyleOf: textStyleOf,
        bandLowerScale: bandLowerScale);
    final upload = Stopwatch()..start();
    final nextBackend = await uploader(next, viewport);
    upload.stop();
    total.stop();
    if (_disposed) {
      nextBackend?.dispose();
      return;
    }
    lastWalkMicros = next.walkMicros;
    lastClassifyMicros = next.classifyMicros;
    lastUploadMicros = upload.elapsedMicroseconds;
    lastTotalMicros = total.elapsedMicroseconds;
    lastTrigger = trigger;
    _collection = next;
    final old = _backend;
    _backend = nextBackend;
    old?.dispose();
    if (nextBackend == null) {
      _uploadFailed = true;
      _pending = null;
    }
    landed++;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _pending = null;
    _backend?.dispose();
    _backend = null;
    super.dispose();
  }
}
```

In `lib/src/gpu/gpu_draw_backend.dart`: `import 'resident_rebuilder.dart'
show ResidentFramePainter;` and `class GpuDrawBackend implements
ResidentFramePainter {`. Its existing `paint` and `dispose` already have the
interface's signatures; add `@override` to both.

Export from `lib/jet_cad_2d_flutter.dart`: `export
'src/gpu/resident_rebuilder.dart';`.

- [ ] **Step 6: Run; expect PASS**

Run: `flutter test test/gpu/resident_rebuilder_test.dart test/gpu/gpu_facade_test.dart`

- [ ] **Step 7: Gates, commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git status --short
git add lib/src/gpu/resident_rebuilder.dart lib/src/gpu/gpu_facade.dart lib/src/gpu/gpu_draw_backend.dart lib/jet_cad_2d_flutter.dart test/support/recording_frame_painter.dart test/gpu/resident_rebuilder_test.dart test/gpu/gpu_facade_test.dart
git commit -m "feat(gpu): the resident rebuilder -- one schedule, five triggers, and a frame that never waits"
```

---
### Task 3: `DraftCanvas` takes the resident path — the five triggers, and the two that are not

**Files:**
- Modify: `lib/src/draft_canvas.dart`
- Modify: `lib/src/render_backend.dart` (doc comment only)
- Test: `test/gpu/draft_canvas_resident_test.dart`

**Interfaces:**
- Consumes: `ResidentRebuilder`, `uploadResidentCollection`, `RebuildTrigger`,
  `ResidentUploader` (Task 2); `debugSetGpuAvailable` (Task 2);
  `RecordingFramePainter`, `FakeUploader`, `zoomedAbout` (Task 2's support).
- Produces: `DraftCanvas.residentUploader` (test seam), `DraftCanvasState.resident`,
  the static latch `DraftCanvas.debugResidentFallbackReports` /
  `debugResetResidentFallbackReport()` (used by Task 4 and Task 8), and the
  behaviour Task 8's arm D measures.

- [ ] **Step 1: Write the failing tests**

`test/gpu/draft_canvas_resident_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/fixtures.dart';
import '../support/recording_frame_painter.dart';

const Size kCanvas = Size(400, 300);
const Offset kCentre = Offset(200, 150);

void main() {
  late FlutterTextMeasurer measurer;
  late DraftDocument doc;
  late SpatialIndex index;
  late CameraController camera;
  late FakeUploader uploader;
  var paints = 0;

  setUp(() {
    debugSetGpuAvailable(true);
    addTearDown(() => debugSetGpuAvailable(null));
    DraftCanvas.debugResetResidentFallbackReport();
    measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    doc = textOverlapFixture(measurer);
    index = SpatialIndex(doc);
    addTearDown(index.dispose);
    camera = CameraController(ViewportTransform.fit(doc.extents, kCanvas));
    addTearDown(camera.dispose);
    uploader = FakeUploader();
    paints = 0;
  });

  Widget wrap(Widget child, {double dpr = 1.0, Size size = kCanvas}) =>
      MediaQuery(
          data: MediaQueryData(devicePixelRatio: dpr),
          child: Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                  child: SizedBox(
                      width: size.width, height: size.height, child: child))));

  Widget canvas({double dpr = 1.0, Size size = kCanvas, bool tiles = false}) =>
      wrap(
          DraftCanvas(
              document: doc,
              index: index,
              camera: camera,
              backend: RenderBackend.residentGpu,
              minTextCapPixels: 0,
              tiles: tiles,
              residentUploader: uploader.call,
              onPaintForTest: () => paints++),
          dpr: dpr,
          size: size);

  DraftCanvasState state(WidgetTester t) =>
      t.state<DraftCanvasState>(find.byType(DraftCanvas));

  /// The post-frame callback fires at the end of the first pump, the fake
  /// upload completes in a microtask, the landing's notify is the second
  /// pump's frame.
  Future<void> land(WidgetTester t) async {
    await t.pump();
    await t.pump();
  }

  testWidgets('the first frame paints through vertices; the landed rebuild '
      'paints through the backend', (t) async {
    await t.pumpWidget(canvas());
    final s = state(t);
    expect(s.resolvedBackend, RenderBackend.residentGpu);
    expect(s.resident, isNotNull);
    expect(s.vertices, isNotNull,
        reason: 'the pre-Plan-F path is still built: it draws before the '
            'first landing (Ruling F5)');
    expect(s.tileCache, isNull);
    expect(paints, 1);
    expect(uploader.painters, isEmpty,
        reason: 'the first frame drew before any rebuild landed');
    expect(() => s.vertices!.canvas, returnsNormally,
        reason: 'the vertices sink is what drew the first frame');
    await land(t);
    final r = s.resident!;
    expect(r.landed, 1);
    expect(r.lastTrigger, RebuildTrigger.initial);
    final p = uploader.painters.single;
    expect(p.paints, greaterThanOrEqualTo(1),
        reason: 'the landing asked for a frame, and that frame went through '
            'the backend');
    expect(p.lastDpr, 1.0);
    expect(p.lastViewport, kCanvas);
    expect(uploader.collections.single.collectionCamera.scale,
        closeTo(camera.value.scale, 1e-12));
  });

  testWidgets('every DocChange is a rebuild; a pan and a resize are not',
      (t) async {
    await t.pumpWidget(canvas());
    await land(t);
    final r = state(t).resident!;
    expect(r.landed, 1);

    Future<void> expectRebuild(String what, void Function() fire) async {
      final before = r.landed;
      fire();
      await land(t);
      await t.pump();
      expect(r.landed, before + 1,
          reason: '$what must cause exactly one rebuild');
      expect(r.lastTrigger, RebuildTrigger.document);
    }

    Future<void> expectNoRebuild(
        String what, Future<void> Function() act) async {
      final before = r.landed;
      await act();
      await land(t);
      expect(r.landed, before, reason: '$what must not rebuild');
    }

    await expectRebuild('CommandApplied', () {
      addLine(doc, doc.rootHandle, doc.handleSeed.next(), 100, 100, 900, 700);
    });
    await expectRebuild('CommandUndone', doc.commands.undo);
    await expectRebuild('CommandRedone', doc.commands.redo);
    await expectRebuild('DocumentLoaded', doc.commands.notifyLoaded);
    await expectRebuild('DocumentPurged', doc.purge);
    await expectNoRebuild('a pan', () async {
      camera.panBy(const Offset(40, 0));
      await t.pump();
    });
    await expectNoRebuild('a resize', () async {
      await t.pumpWidget(canvas(size: const Size(500, 350)));
    });
    expect(uploader.painters.last.lastViewport, const Size(500, 350),
        reason: 'the resized frame still painted through the same backend');
    expect(paints, greaterThan(7));
  });

  testWidgets('a layer edit rebuilds, through the revision counter', (t) async {
    await t.pumpWidget(canvas());
    await land(t);
    final r = state(t).resident!;
    final zero = doc.tables.layers[ReservedHandles.layerZero]!;
    doc.tables.layers.remove(zero.handle);
    doc.tables.layers.add(LayerRecord(
        handle: zero.handle,
        name: zero.name,
        color: const IndexedColor(1),
        linetype: zero.linetype,
        lineweight: zero.lineweight,
        transparency: zero.transparency,
        visible: zero.visible,
        locked: zero.locked));
    // The table listenable causes the frame; the frame's noteFrame reads the
    // counter (Ruling F4). MUTATION (M-F1): drop the comparison -> landed 1.
    await land(t);
    await t.pump();
    expect(r.landed, 2);
    expect(r.lastTrigger, RebuildTrigger.tables);
    expect(r.collection!.tablesRevision, doc.tables.mutationRevision);
  });

  testWidgets('a device pixel ratio change rebuilds, with the new ratio',
      (t) async {
    await t.pumpWidget(canvas(dpr: 1.0));
    await land(t);
    final r = state(t).resident!;
    await t.pumpWidget(canvas(dpr: 2.0));
    await land(t);
    // MUTATION (M-F2): drop the comparison -> landed 1, dpr still 1.0.
    expect(r.landed, 2);
    expect(r.lastTrigger, RebuildTrigger.devicePixelRatio);
    expect(r.collection!.devicePixelRatio, 2.0);
    expect(uploader.painters.last.lastDpr, 2.0);
  });

  testWidgets('leaving the band rebuilds at the live scale; staying inside '
      'does not', (t) async {
    await t.pumpWidget(canvas());
    await land(t);
    final r = state(t).resident!;
    camera.zoomAt(kCentre, 1.9);
    await land(t);
    expect(r.landed, 1, reason: '1.9 is inside [0.5, 2.0]');
    expect(r.bandStaleFrames, 0);
    camera.zoomAt(kCentre, 1.2); // 2.28 overall
    await land(t);
    await t.pump();
    // MUTATION (M-F3): ratio against the collection's own scale -> landed 1.
    expect(r.landed, 2);
    expect(r.lastTrigger, RebuildTrigger.band);
    expect(r.collection!.collectionCamera.scale,
        closeTo(camera.value.scale, 1e-12),
        reason: 'Ruling F1: the new reference scale is the live scale');
    expect(r.bandStaleFrames, greaterThanOrEqualTo(1),
        reason: 'the frame that fired the trigger was drawn out of band');
  });

  testWidgets('a re-attach replaces the rebuilder and leaves one table '
      'listener; an unmount leaves none', (t) async {
    await t.pumpWidget(canvas());
    await land(t);
    final first = state(t).resident!;
    expect(doc.tables.debugListenerCount, 1);
    await t.pumpWidget(canvas(tiles: true));
    final s = state(t);
    expect(first.disposed, isTrue);
    expect(s.resident, isNot(same(first)));
    expect(s.tileCache, isNull,
        reason: 'the resident path owns gestures; no tile cache beside it');
    expect(doc.tables.debugListenerCount, 1);
    await land(t);
    expect(s.resident!.landed, 1);
    final second = s.resident!;
    await t.pumpWidget(wrap(const SizedBox()));
    expect(second.disposed, isTrue);
    expect(doc.tables.debugListenerCount, 0);
    expect(uploader.painters.every((p) => p.disposed), isTrue,
        reason: 'every backend the canvas ever installed is disposed with it');
  });
}
```

`addLine(doc, owner, handle, x0, y0, x1, y1)` is `test/support/fixtures.dart:160`.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/gpu/draft_canvas_resident_test.dart`
Expected: FAIL — `residentUploader` is not a named parameter; `resident`
undefined.

- [ ] **Step 3: The widget**

In `lib/src/draft_canvas.dart`:

**Imports:** add `import 'gpu/resident_rebuilder.dart';`.

**The widget** gains one parameter and two statics:

```dart
  /// **Test-only.** Replaces the production uploader
  /// (`uploadResidentCollection`) on the `residentGpu` path, so a widget test
  /// can take that path without a GPU (Ruling F14). Not compared in
  /// [DraftCanvasState.didUpdateWidget]: a test that re-pumps the same canvas
  /// passes a fresh tear-off each time, and a re-attach on that alone would
  /// make "a resize does not rebuild" untestable.
  final ResidentUploader? residentUploader;
```

(constructor: `this.residentUploader,` after `this.onPaintForTest`), and on
the `DraftCanvas` class body:

```dart
  static bool _residentFallbackReported = false;

  /// How many times [_reportResidentFallback] has reported. **Test-only.**
  /// Zero or one: criterion 10 says once per process.
  static int debugResidentFallbackReports = 0;

  /// **Test-only.** Rearms the one-shot so the next fallback reports again.
  static void debugResetResidentFallbackReport() {
    _residentFallbackReported = false;
    debugResidentFallbackReports = 0;
  }

  /// The spec's "falls back to `VerticesDrawSink` and says so once" (Ruling
  /// F5). One `FlutterError.reportError` per process, whichever of the two
  /// fallbacks fires first: no GPU on this platform, or an upload that
  /// returned null. Observable through `FlutterError.onError` and
  /// [debugResidentFallbackReports]; never thrown.
  static void _reportResidentFallback(String message) {
    if (_residentFallbackReported) return;
    _residentFallbackReported = true;
    debugResidentFallbackReports++;
    FlutterError.reportError(FlutterErrorDetails(
        exception: FlutterError(message),
        library: 'jet_cad_2d_flutter',
        context: ErrorDescription('choosing the render backend for DraftCanvas')));
  }
```

**The state** gains a field and a listener:

```dart
  /// Non-null exactly when [resolvedBackend] is [RenderBackend.residentGpu]:
  /// the rebuild schedule and the backend the frame paints through once one
  /// has landed. Public so a rig reads what actually rebuilt and when.
  ResidentRebuilder? resident;

  void _onResidentLanded() {
    final r = resident;
    if (r != null && r.uploadFailed) {
      DraftCanvas._reportResidentFallback(
          'DraftCanvas was asked for RenderBackend.residentGpu and the upload '
          'failed (ResidentGeometry.create returned null; its FlutterError, if '
          'any, is above this one). Drawing through VerticesDrawSink from now '
          'on. Reported once per process.');
    }
  }
```

**`_attach`** becomes:

```dart
  void _attach() {
    final measurer = _requireMeasurer();
    sink = CanvasDrawSink(
        pixelsPerPaperMm: widget.pixelsPerPaperMm,
        lineweightScale: widget.lineweightScale,
        measurer: measurer,
        textStyleOf: widget.document.textStyleOf);
    final requested = widget.backend ?? defaultRenderBackend();
    resolvedBackend = resolveBackend(requested);
    if (requested == RenderBackend.residentGpu &&
        resolvedBackend != RenderBackend.residentGpu) {
      DraftCanvas._reportResidentFallback(
          'DraftCanvas was asked for RenderBackend.residentGpu, but this '
          'platform has no Flutter GPU (gpuAvailable() is false). Drawing '
          'through VerticesDrawSink instead. Reported once per process.');
    }
    // **`residentGpu` still builds the vertices sink** -- it is what draws
    // before the first rebuild lands and after an upload fails (Ruling F5).
    // `canvas` stays the one-`drawPath`-per-primitive fallback an explicit
    // `backend:` can still choose.
    vertices = resolvedBackend == RenderBackend.vertices ||
            resolvedBackend == RenderBackend.residentGpu
        ? VerticesDrawSink(
            pixelsPerPaperMm: widget.pixelsPerPaperMm,
            lineweightScale: widget.lineweightScale,
            fallback: sink)
        : null;
    painter = DraftPainter(
      document: widget.document,
      index: widget.index,
      resolver: widget.resolver ?? DocumentStyleResolver(widget.document),
      drawText: widget.drawText,
      minTextCapPixels: widget.minTextCapPixels,
    );
    resident = resolvedBackend == RenderBackend.residentGpu
        ? ResidentRebuilder(
            document: widget.document,
            painter: painter,
            uploader: widget.residentUploader ??
                (collection, viewport) => uploadResidentCollection(
                    collection, viewport,
                    measurer: measurer,
                    textStyleOf: widget.document.textStyleOf),
            pixelsPerPaperMm: widget.pixelsPerPaperMm,
            lineweightScale: widget.lineweightScale,
            measurer: measurer,
            textStyleOf: widget.document.textStyleOf)
        : null;
    resident?.addListener(_onResidentLanded);
    _tables = _TableListenableAdapter(widget.document.tables.changes);
    // **No tile cache beside the resident backend.** Both are gesture paths
    // and they answer the same frame; the resident one holds the whole
    // drawing and needs no tiles. `tiles: true` on a `residentGpu` canvas is
    // honoured by the fallback path only if the resident one never lands --
    // and it is not, deliberately: the cache would be built, invalidated
    // and never painted. Ignored, and said so here.
    tileCache = widget.tiles && resident == null
        ? TileCache(tileDevicePixels: widget.tileDevicePixels)
        : null;
    // The cache's derived state is updated before listeners run, for the
    // reason `DocChangeNotifier` gives: a listener repaints, and a repaint that
    // read the cache before `applyChange` had run would blit a tile the edit
    // already invalidated. The rebuilder is marked here too: every DocChange
    // subclass, `touched` unread (the spec's declared-equivalent mutation).
    _changes = DocChangeNotifier(widget.document, onChange: (change) {
      tileCache?.applyChange(change, widget.document);
      resident?.markDirty(RebuildTrigger.document);
    });
    // **The table adapter is here and not a nicety.** Without it a layer edit
    // causes no frame at all, so neither the cache's invalidation nor the
    // rebuilder's revision check is ever reached.
    _repaint = Listenable.merge([
      widget.camera,
      _changes,
      _tables,
      _settle,
      if (resident != null) resident!,
    ]);
  }
```

**`_detach`** adds, before `tileCache?.dispose()`:

```dart
    resident?.removeListener(_onResidentLanded);
    resident?.dispose();
    resident = null;
```

**`build`** passes `resident: resident,` to `_DraftCustomPainter`, which
gains `required this.resident,` / `final ResidentRebuilder? resident;` and,
at the top of `paint`, right after `canvas.clipRect(Offset.zero & size);`:

```dart
    final resident = this.resident;
    if (resident != null) {
      // O(1), never walks: stores the frame's camera, viewport and dpr for
      // the next rebuild and fires the three frame-read triggers. The
      // table revision is pulled per frame for the reason the tiled branch
      // gives below -- a table mutation reaches no command and so no
      // `DocChange`.
      resident.noteFrame(camera.value, size, devicePixelRatio,
          document.tables.mutationRevision);
      final backend = resident.backend;
      if (backend != null) {
        backend.paint(canvas, camera.value, size, devicePixelRatio);
        return;
      }
      // Before the first landing, or after a failed upload: the vertices
      // path below, which is the drawing every `residentGpu` canvas made
      // before this plan (Ruling F5).
    }
```

**`didUpdateWidget`**: no change to the compared fields (`residentUploader`
is deliberately not compared — see its doc).

**`render_backend.dart`**: replace the paragraph beginning *"**Wiring a
GPU-resident sink into `DraftCanvas` is Plan F's work.**"* with:

```dart
  /// `DraftCanvas` builds a `ResidentRebuilder` for this value (Plan F):
  /// the document is collected over its whole extents at the live scale,
  /// rebuilt on the spec's five triggers and never on a pan, and painted
  /// through `GpuDrawBackend` once the first rebuild lands. Before that,
  /// and after an upload that fails, the canvas paints through
  /// `VerticesDrawSink` and says so once -- see
  /// `DraftCanvas.debugResidentFallbackReports`.
```

- [ ] **Step 4: Run; expect PASS. Run the whole suite: `draft_canvas_test.dart` must still pass unchanged**

Run: `flutter test test/gpu/draft_canvas_resident_test.dart test/draft_canvas_test.dart`

`draft_canvas_test.dart` never sets `debugSetGpuAvailable`, so its
`residentGpu` requests still resolve to `vertices` under `flutter test` and
its assertions hold as before.

- [ ] **Step 5: Gates, commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git status --short
git add lib/src/draft_canvas.dart lib/src/render_backend.dart test/gpu/draft_canvas_resident_test.dart
git commit -m "feat(gpu): DraftCanvas paints residentGpu through the rebuilder, on five triggers and no pan"
```

---

### Task 4: Criterion 10 — the fallback, exactly once, observably

**Files:**
- Test: `test/gpu/draft_canvas_fallback_test.dart`
- Modify: `lib/src/draft_canvas.dart` only if Step 2 finds a gap (Task 3
  already carries the latch)

**Interfaces:**
- Consumes: `DraftCanvas.debugResidentFallbackReports`,
  `debugResetResidentFallbackReport`, `debugSetGpuAvailable`, `FakeUploader`.

- [ ] **Step 1: Write the tests**

`test/gpu/draft_canvas_fallback_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/fixtures.dart';
import '../support/recording_frame_painter.dart';

const Size kCanvas = Size(400, 300);

void main() {
  late FlutterTextMeasurer measurer;
  late DraftDocument doc;
  late SpatialIndex index;
  late CameraController camera;
  late FakeUploader uploader;
  var paints = 0;

  // `FlutterError.reportError` under the test binding parks the report as the
  // test's pending exception; `tester.takeException()` returns and clears it,
  // and an un-taken one fails the test. That is the observation, and it needs
  // no swap of `FlutterError.onError` -- which the binding checks at the end
  // of every test anyway.
  setUp(() {
    addTearDown(() => debugSetGpuAvailable(null));
    DraftCanvas.debugResetResidentFallbackReport();
    measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    doc = textOverlapFixture(measurer);
    index = SpatialIndex(doc);
    addTearDown(index.dispose);
    camera = CameraController(ViewportTransform.fit(doc.extents, kCanvas));
    addTearDown(camera.dispose);
    uploader = FakeUploader();
    paints = 0;
  });

  Widget wrap(Widget child) => MediaQuery(
      data: const MediaQueryData(devicePixelRatio: 1.0),
      child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
              child: SizedBox(
                  width: kCanvas.width, height: kCanvas.height, child: child))));

  Widget canvas(RenderBackend backend) => wrap(DraftCanvas(
      document: doc,
      index: index,
      camera: camera,
      backend: backend,
      minTextCapPixels: 0,
      residentUploader: uploader.call,
      onPaintForTest: () => paints++));

  DraftCanvasState state(WidgetTester t) =>
      t.state<DraftCanvasState>(find.byType(DraftCanvas));

  testWidgets('no GPU: two canvases, vertices both, one report', (t) async {
    debugSetGpuAvailable(false);
    await t.pumpWidget(canvas(RenderBackend.residentGpu));
    final s = state(t);
    expect(s.resolvedBackend, RenderBackend.vertices);
    expect(s.resident, isNull);
    expect(s.vertices, isNotNull);
    expect(paints, 1, reason: 'nothing threw on the frame path');
    final first = t.takeException();
    expect(first, isA<FlutterError>());
    expect(first.toString(), contains('residentGpu'));
    expect(first.toString(), contains('gpuAvailable'));
    expect(DraftCanvas.debugResidentFallbackReports, 1);
    await t.pumpWidget(wrap(const SizedBox()));
    await t.pumpWidget(canvas(RenderBackend.residentGpu));
    // MUTATION (M-F8): drop the static latch -> a second pending exception.
    expect(t.takeException(), isNull, reason: 'once per process');
    expect(DraftCanvas.debugResidentFallbackReports, 1);
    // An explicit vertices request is not a fallback and reports nothing.
    await t.pumpWidget(canvas(RenderBackend.vertices));
    expect(t.takeException(), isNull);
  });

  testWidgets('a failed upload: vertices from then on, one report, no retry',
      (t) async {
    debugSetGpuAvailable(true);
    uploader.failing = true;
    await t.pumpWidget(canvas(RenderBackend.residentGpu));
    await t.pump();
    await t.pump();
    final s = state(t);
    final r = s.resident!;
    expect(r.landed, 1);
    expect(r.uploadFailed, isTrue);
    expect(r.backend, isNull);
    final report = t.takeException();
    expect(report, isA<FlutterError>());
    expect(report.toString(), contains('upload'));
    final paintsBefore = paints;
    camera.zoomAt(const Offset(200, 150), 3.0);
    await t.pump();
    await t.pump();
    await t.pump();
    expect(paints, greaterThan(paintsBefore),
        reason: 'the canvas kept drawing after the failure');
    expect(() => s.vertices!.canvas, returnsNormally,
        reason: 'and it drew through the vertices sink');
    expect(r.rebuilds, 1, reason: 'criterion 10: once, not per frame');
    expect(t.takeException(), isNull, reason: 'no second report');
    expect(DraftCanvas.debugResidentFallbackReports, 1);
  });

  testWidgets('a canvas whose upload succeeds reports nothing', (t) async {
    debugSetGpuAvailable(true);
    await t.pumpWidget(canvas(RenderBackend.residentGpu));
    await t.pump();
    await t.pump();
    expect(state(t).resident!.backend, isA<RecordingFramePainter>());
    expect(t.takeException(), isNull);
    expect(DraftCanvas.debugResidentFallbackReports, 0);
  });
}
```

- [ ] **Step 2: Run; expect PASS against Task 3's code**

Run: `flutter test test/gpu/draft_canvas_fallback_test.dart`

If any assertion fails, the gap is in Task 3's latch or listener wiring; fix
it in `draft_canvas.dart` and record the finding in the report — do not
loosen the test.

- [ ] **Step 3: Gates, commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git status --short
git add test/gpu/draft_canvas_fallback_test.dart lib/src/draft_canvas.dart
git commit -m "test(gpu): criterion 10 -- the resident fallback falls back once, without throwing, observably"
```

---

### Task 5: The classification gets a grid, and the brute force stays as the oracle

**Files:**
- Modify: `lib/src/gpu/text_patches.dart`
- Test: `test/gpu/classify_grid_test.dart`; `test/gpu/text_patches_test.dart` unchanged and still green

**Interfaces:**
- Consumes: `_reaches` (Plan E, unchanged), `TextPatch`, `ResidentTextRecord`,
  `InstanceFieldOffset`, `kFloatsPerInstance`, `generateDocument`
  (`package:jet_cad_2d/testing.dart`).
- Produces: `classifyTextPatches(data, count, texts, {devicePixelRatio,
  bandLowerScale, ClassifyStats? stats})` — same call shape, one optional
  parameter added — `classifyTextPatchesBruteForce(...)` (`@visibleForTesting`),
  `ClassifyStats`, `kClassifyOverflowCells`.

- [ ] **Step 1: Write the failing tests**

`test/gpu/classify_grid_test.dart`:

```dart
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart';

import '../support/fixtures.dart';

/// Collects [doc] at its fit camera over the whole extents, the way a
/// rebuild does, and returns the collector's buffer and text list.
(Float32List, int, List<ResidentTextRecord>) collect(
    DraftDocument doc, FlutterTextMeasurer measurer, Size viewport, double dpr) {
  final index = SpatialIndex(doc);
  addTearDown(index.dispose);
  final painter = DraftPainter(
      document: doc,
      index: index,
      resolver: DocumentStyleResolver(doc),
      minTextCapPixels: 0);
  final frame =
      collectionFrameFor(ViewportTransform.fit(doc.extents, viewport), doc.extents);
  final collector = GeometryCollector(
      pixelsPerPaperMm: kLogicalPixelsPerMm,
      devicePixelRatio: dpr,
      measurer: measurer,
      textStyleOf: doc.textStyleOf);
  painter.paint(collector, frame.camera, frame.viewport);
  return (collector.data, collector.instanceCount, collector.texts);
}

void expectSamePatches(List<TextPatch> a, List<TextPatch> b) {
  expect(a.length, b.length, reason: 'patch count');
  for (var i = 0; i < a.length; i++) {
    expect(a[i].textIndex, b[i].textIndex, reason: 'patch $i textIndex');
    expect(a[i].instanceCount, b[i].instanceCount,
        reason: 'patch $i instanceCount');
    final n = a[i].instanceCount * kFloatsPerInstance;
    expect(a[i].instances.sublist(0, n), b[i].instances.sublist(0, n),
        reason: 'patch $i sub-buffer, byte for byte, in main-buffer order');
  }
}

void main() {
  late FlutterTextMeasurer measurer;
  setUp(() {
    measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
  });

  test('grid and brute force agree byte for byte on the text-overlap fixture',
      () {
    final doc = textOverlapFixture(measurer);
    final (data, count, texts) = collect(doc, measurer, kViewport, 1.0);
    final stats = ClassifyStats();
    final grid = classifyTextPatches(data, count, texts,
        devicePixelRatio: 1.0, stats: stats);
    final brute =
        classifyTextPatchesBruteForce(data, count, texts, devicePixelRatio: 1.0);
    expectSamePatches(grid, brute);
    expect(grid.length, 2, reason: 'COVERED and GRAZED (Plan E)');
    expect(stats.candidatesTested, greaterThan(0));
  });

  test('... and on a generated corpus with hundreds of labels, overflow included',
      () {
    final doc = generateDocument(
      3000,
      definitionCount: 20,
      instanceCount: 150,
      nestingDepth: 1,
      mirroredFraction: 0.1,
      nonUniformFraction: 0.2,
      groupCount: 10,
      layerCount: 8,
      byBlockFraction: 0.3,
      dashedFraction: 0.35,
      labelFraction: 0.05,
      attributedInstanceFraction: 0.2,
      measurer: measurer,
    );
    // One line across the whole floor, at a handle above every label's: the
    // generated rooms are 30-120 units and a label box is hundreds, so no
    // room wall spans kClassifyOverflowCells cells on its own. This one
    // spans hundreds, reaches every label on the diagonal, and is what
    // makes `stats.overflow > 0` below a fact rather than a hope.
    final e = doc.extents;
    addLine(doc, doc.rootHandle, doc.handleSeed.next(), e.minX, e.minY, e.maxX,
        e.maxY);
    final (data, count, texts) =
        collect(doc, measurer, const Size(1400, 900), 2.0);
    expect(texts.length, greaterThan(50), reason: 'a real label population');
    final stats = ClassifyStats();
    final grid = classifyTextPatches(data, count, texts,
        devicePixelRatio: 2.0, stats: stats);
    final brute =
        classifyTextPatchesBruteForce(data, count, texts, devicePixelRatio: 2.0);
    // MUTATION (M-F9): skip the overflow list -> a long wall through a label
    // is missing from its patch. MUTATION (M-F10): `.floor()` -> `.round()`
    // on the cell range -> an instance in a cell's lower half is binned one
    // cell late and a label at that edge misses it.
    expectSamePatches(grid, brute);
    expect(grid.length, greaterThan(3));
    expect(grid.any((p) => p.instanceCount > 1), isTrue);
    expect(stats.overflow, greaterThan(0),
        reason: 'a long wall spans more than kClassifyOverflowCells cells, '
            'or the overflow branch is untested here');
    expect(stats.binned, greaterThan(1000));
    expect(stats.candidatesTested, lessThan(texts.length * count ~/ 2),
        reason: 'the grid must test a fraction of the pairs the brute force '
            'does, or it is not the lever criterion 7 needs');
    // Reported, not gated: the two costs side by side.
    final w1 = Stopwatch()..start();
    classifyTextPatches(data, count, texts, devicePixelRatio: 2.0);
    w1.stop();
    final w2 = Stopwatch()..start();
    classifyTextPatchesBruteForce(data, count, texts, devicePixelRatio: 2.0);
    w2.stop();
    // ignore: avoid_print
    print('CLASSIFY grid=${w1.elapsedMicroseconds / 1000} ms '
        'brute=${w2.elapsedMicroseconds / 1000} ms '
        'instances=$count labels=${texts.length} '
        'binned=${stats.binned} overflow=${stats.overflow} '
        'skipped=${stats.skipped} tested=${stats.candidatesTested} '
        'cells=${stats.cellsX}x${stats.cellsY}');
  });

  test('no labels: an empty list, no grid built', () {
    final doc = textOverlapFixture(measurer);
    final (data, count, _) = collect(doc, measurer, kViewport, 1.0);
    final stats = ClassifyStats();
    expect(classifyTextPatches(data, count, const [], devicePixelRatio: 1.0,
        stats: stats), isEmpty);
    expect(stats.cellsX, 0);
  });
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/gpu/classify_grid_test.dart`
Expected: FAIL — `ClassifyStats`, `classifyTextPatchesBruteForce` undefined.

- [ ] **Step 3: The grid**

In `lib/src/gpu/text_patches.dart`, add `import 'package:meta/meta.dart';`,
and beside `kBandLowerScale`/`kBandUpperScale`:

```dart
/// Cells an instance's reach-expanded box may span before it leaves the
/// grid for the overflow list, which every label tests. A long wall through
/// a floor plan would otherwise be appended to hundreds of buckets.
const int kClassifyOverflowCells = 16;

/// What one `classifyTextPatches` call did -- diagnostics, for the tests and
/// the harness. Zero everywhere when there are no labels.
class ClassifyStats {
  int cellsX = 0, cellsY = 0;

  /// Instances binned into cells; instances sent to the overflow list;
  /// instances whose expanded box misses every label's union (never tested).
  int binned = 0, overflow = 0, skipped = 0;

  /// `_reaches` calls made. The brute force makes `labels x later instances`.
  int candidatesTested = 0;
}
```

Rename the existing function to `classifyTextPatchesBruteForce`, mark it
`@visibleForTesting`, keep its body and doc comment word for word, and add
one line to the doc: *"**The oracle.** `classifyTextPatches` is the grid; this
is Plan E's loop, kept so `classify_grid_test.dart` can prove the two return
the same list byte for byte."*

Then the new `classifyTextPatches`, with the old function's doc comment
moved onto it and this paragraph added: *"**A uniform grid over the labels'
union** (Ruling F7). Cell size is the largest label box; an instance's
reach-expanded box is binned into every cell it touches, or into the overflow
list past [kClassifyOverflowCells]; a label tests only the instances in the
cells its box touches, deduplicated by a stamp array, plus the overflow list.
Hit indices are **sorted** so the sub-buffer stays a subsequence of the main
buffer in the main buffer's order -- indices, never the buffer."*

```dart
List<TextPatch> classifyTextPatches(
  Float32List data,
  int instanceCount,
  List<ResidentTextRecord> texts, {
  required double devicePixelRatio,
  double bandLowerScale = kBandLowerScale,
  ClassifyStats? stats,
}) {
  if (texts.isEmpty) return const <TextPatch>[];
  final unitsPerDevicePixel = 1.0 / (devicePixelRatio * bandLowerScale);

  // The labels' union, and the largest label box: the cell.
  var uMinX = double.infinity, uMinY = double.infinity;
  var uMaxX = double.negativeInfinity, uMaxY = double.negativeInfinity;
  var cell = 0.0;
  for (final t in texts) {
    if (t.boxMinX < uMinX) uMinX = t.boxMinX;
    if (t.boxMinY < uMinY) uMinY = t.boxMinY;
    if (t.boxMaxX > uMaxX) uMaxX = t.boxMaxX;
    if (t.boxMaxY > uMaxY) uMaxY = t.boxMaxY;
    final w = t.boxMaxX - t.boxMinX, h = t.boxMaxY - t.boxMinY;
    if (w > cell) cell = w;
    if (h > cell) cell = h;
  }
  if (!(cell > 0)) cell = 1.0;
  // No more than 256 cells a side: a huge union over tiny labels would
  // otherwise build a grid nobody can afford at rebuild.
  final cellW = math.max(cell, (uMaxX - uMinX) / 256);
  final cellH = math.max(cell, (uMaxY - uMinY) / 256);
  final nx = math.max(1, ((uMaxX - uMinX) / cellW).ceil());
  final ny = math.max(1, ((uMaxY - uMinY) / cellH).ceil());
  if (stats != null) {
    stats.cellsX = nx;
    stats.cellsY = ny;
  }
  int cellX(double x) => ((x - uMinX) / cellW).floor().clamp(0, nx - 1);
  int cellY(double y) => ((y - uMinY) / cellH).floor().clamp(0, ny - 1);

  final buckets = List<List<int>>.generate(nx * ny, (_) => <int>[]);
  final overflow = <int>[];
  final box = Float64List(4);
  for (var i = 0; i < instanceCount; i++) {
    _expandedBox(data, i, unitsPerDevicePixel, box);
    if (box[2] < uMinX || box[0] > uMaxX || box[3] < uMinY || box[1] > uMaxY) {
      if (stats != null) stats.skipped++;
      continue;
    }
    final cx0 = cellX(box[0]), cx1 = cellX(box[2]);
    final cy0 = cellY(box[1]), cy1 = cellY(box[3]);
    if ((cx1 - cx0 + 1) * (cy1 - cy0 + 1) > kClassifyOverflowCells) {
      overflow.add(i);
      if (stats != null) stats.overflow++;
      continue;
    }
    for (var cy = cy0; cy <= cy1; cy++) {
      for (var cx = cx0; cx <= cx1; cx++) {
        buckets[cy * nx + cx].add(i);
      }
    }
    if (stats != null) stats.binned++;
  }

  // Stamp: the 1-based index of the label that last saw instance i. Zero is
  // "never", so no fill is needed.
  final stamp = Int32List(instanceCount);
  final patches = <TextPatch>[];
  final hits = <int>[];
  for (var ti = 0; ti < texts.length; ti++) {
    final t = texts[ti];
    final mark = ti + 1;
    hits.clear();
    final cx0 = cellX(t.boxMinX), cx1 = cellX(t.boxMaxX);
    final cy0 = cellY(t.boxMinY), cy1 = cellY(t.boxMaxY);
    for (var cy = cy0; cy <= cy1; cy++) {
      for (var cx = cx0; cx <= cx1; cx++) {
        for (final i in buckets[cy * nx + cx]) {
          if (i < t.instanceIndex || stamp[i] == mark) continue;
          stamp[i] = mark;
          if (stats != null) stats.candidatesTested++;
          if (_reaches(data, i, t, unitsPerDevicePixel)) hits.add(i);
        }
      }
    }
    for (final i in overflow) {
      if (i < t.instanceIndex) continue;
      if (stats != null) stats.candidatesTested++;
      if (_reaches(data, i, t, unitsPerDevicePixel)) hits.add(i);
    }
    if (hits.isEmpty) continue;
    // Indices, not the buffer: main-buffer order is the draw order.
    hits.sort();
    final sub = Float32List(hits.length * kFloatsPerInstance);
    for (var k = 0; k < hits.length; k++) {
      sub.setRange(k * kFloatsPerInstance, (k + 1) * kFloatsPerInstance, data,
          hits[k] * kFloatsPerInstance);
    }
    patches.add(
        TextPatch(textIndex: ti, instances: sub, instanceCount: hits.length));
  }
  return patches;
}

/// Instance [i]'s reach-expanded box into [out] as `minX, minY, maxX, maxY`
/// -- the same points-per-kind and reach-per-kind as [_reaches] (Rulings
/// E4, E5), written out rather than shared so [_reaches] stays Plan E's
/// oracle word for word; `classify_grid_test.dart` proves they agree.
void _expandedBox(
    Float32List d, int i, double unitsPerDevicePixel, Float64List out) {
  final o = i * kFloatsPerInstance;
  final kind = d[o + InstanceFieldOffset.kind];
  final half = d[o + InstanceFieldOffset.halfWidth];
  final int points;
  final double reachDevice;
  if (kind < 0.5) {
    points = 2;
    reachDevice = half;
  } else if (kind < 1.5) {
    points = 3;
    reachDevice = half * kMiterLimit;
  } else if (kind < 2.5) {
    points = 1;
    reachDevice = half;
  } else {
    points = 3;
    reachDevice = 0;
  }
  final reach = reachDevice * unitsPerDevicePixel;
  var minX = double.infinity, minY = double.infinity;
  var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
  for (var p = 0; p < points; p++) {
    final x = d[o + InstanceFieldOffset.x0 + p * 2];
    final y = d[o + InstanceFieldOffset.y0 + p * 2];
    if (x < minX) minX = x;
    if (x > maxX) maxX = x;
    if (y < minY) minY = y;
    if (y > maxY) maxY = y;
  }
  out[0] = minX - reach;
  out[1] = minY - reach;
  out[2] = maxX + reach;
  out[3] = maxY + reach;
}
```

`import 'dart:math' as math;` at the top if the file does not already have it.

- [ ] **Step 4: Run the new file and Plan E's; expect PASS, and read the printed `CLASSIFY` line into the report**

Run: `flutter test test/gpu/classify_grid_test.dart test/gpu/text_patches_test.dart test/gpu/text_order_test.dart`

- [ ] **Step 5: Gates, commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git status --short
git add lib/src/gpu/text_patches.dart test/gpu/classify_grid_test.dart
git commit -m "perf(gpu): classifyTextPatches on a uniform grid, with Plan E's loop kept as the oracle"
```

---
### Task 6: The compositor rejects off-viewport labels, and the frame path's per-patch objects become fields

**Files:**
- Modify: `lib/src/gpu/text_compositor.dart`
- Modify: `lib/src/gpu/text_patches.dart` (`PatchRegion` mutable, `patchRegionFor(out:)`)
- Modify: `lib/src/gpu/gpu_draw_backend.dart` (`buildFrameInfo(out:)`, the region pool, parallel pending lists)
- Test: `test/gpu/text_compositor_viewport_test.dart` (create); `test/gpu/text_patches_test.dart`, `test/gpu/frame_info_test.dart` (modify)

**Interfaces:**
- Consumes: `boundTransformedBox`, `patchRegionFor`, `buildFrameInfo`, `SpyCanvas`.
- Produces: `TextCompositor.labelsSkipped`; `PatchRegion` with mutable `x, y,
  width, height`; `patchRegionFor(..., {PatchRegion? out})`;
  `buildFrameInfo(..., {ByteData? out})`. Task 8's probe measures the effect.

- [ ] **Step 1: Write the failing compositor test**

`test/gpu/text_compositor_viewport_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/spy_canvas.dart';

const TextStyleRecord _roboto =
    TextStyleRecord(handle: Handle(11), name: 'Standard', fontFamily: 'Roboto');

/// A label whose collection-space box is [minX, minY]..[maxX, maxY], upright,
/// baseline at its box's bottom. Text, style and colour are the same for all
/// three; only the box moves.
ResidentTextRecord label(double minX, double minY, double maxX, double maxY) =>
    ResidentTextRecord(
        text: 'LABEL',
        style: const Handle(11),
        argb: 0xFF000000,
        a: 1,
        b: 0,
        c: 0,
        d: -1,
        e: minX,
        f: maxY,
        boxMinX: minX,
        boxMinY: minY,
        boxMaxX: maxX,
        boxMaxY: maxY,
        instanceIndex: 0);

void main() {
  test('labels outside the viewport are skipped; inside and straddling are drawn',
      () {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final compositor =
        TextCompositor(measurer: measurer, textStyleOf: (_) => _roboto);
    const viewport = Size(400, 300);
    // The outer transform is a pan of (-1000, 0): a label at x 1020..1100 in
    // collection space lands at 20..100 on screen (inside), one at 400..480
    // lands at -600..-520 (outside, left), one at 970..1030 straddles x = 0,
    // one at 1000..1080 / y 900..950 is below the viewport (outside).
    final outer = Transform2.translation(-1000, 0);
    final texts = <ResidentTextRecord>[
      label(1020, 100, 1100, 130),
      label(400, 100, 480, 130),
      label(970, 200, 1030, 230),
      label(1000, 900, 1080, 950),
    ];
    final spy = SpyCanvas();
    compositor.paint(spy,
        main: null,
        viewport: viewport,
        collectionToLogical: outer,
        texts: texts,
        patches: const <PatchImage>[]);
    // MUTATION (M-F11): invert the rejection -> 2 paragraphs skipped, 2 drawn
    // -- the wrong two, and `text_order_test.dart`'s composited differential
    // goes red with it.
    expect(spy.named('drawParagraph').length, 2,
        reason: 'the inside label and the straddling one');
    expect(compositor.labelsSkipped, 2);
    // Anti-vacuity: with a pan that brings every label on screen, all four
    // draw and nothing is skipped.
    final all = SpyCanvas();
    compositor.paint(all,
        main: null,
        viewport: const Size(2000, 2000),
        collectionToLogical: Transform2.identity(),
        texts: texts,
        patches: const <PatchImage>[]);
    expect(all.named('drawParagraph').length, 4);
    expect(compositor.labelsSkipped, 0);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/gpu/text_compositor_viewport_test.dart`
Expected: FAIL — `labelsSkipped` undefined (and four paragraphs drawn).

- [ ] **Step 3: The rejection**

In `lib/src/gpu/text_compositor.dart`, add to the class:

```dart
  /// Reused per plain label by the viewport test: [boundTransformedBox]'s
  /// caller-owned scratch, so rejecting an off-screen label allocates
  /// nothing.
  final Float64List _bound = Float64List(4);

  /// Plain labels the last [paint] did not draw because their box, under the
  /// outer transform, missed the viewport entirely. Diagnostics; reset per
  /// call. A patched label whose patch was off screen is not in `patches`,
  /// takes the plain branch, and is counted here too.
  int labelsSkipped = 0;
```

and in `paint`, `labelsSkipped = 0;` beside `_patchesComposited = 0;`, then
the plain branch becomes:

```dart
      if (patch == null) {
        final t = texts[i];
        boundTransformedBox(
            t.boxMinX, t.boxMinY, t.boxMaxX, t.boxMaxY, collectionToLogical, _bound);
        // Wholly off screen: nothing to draw. A box touching the edge is
        // drawn -- the paragraph clips itself.
        if (_bound[2] < 0 ||
            _bound[0] > viewport.width ||
            _bound[3] < 0 ||
            _bound[1] > viewport.height) {
          labelsSkipped++;
          continue;
        }
        _drawLabel(canvas, t, collectionToLogical);
        continue;
      }
```

Import `boundTransformedBox` is already in the file's `show` clause.

- [ ] **Step 4: Run; expect PASS. Then the two reuses, tests first**

Add to `test/gpu/frame_info_test.dart`:

```dart
  test('buildFrameInfo writes into `out` when given one of the right size', () {
    final m = Transform2(2, 0.5, -0.5, 2, 30, -40);
    final fresh = buildFrameInfo(m, 800, 600, dashScale: 1.7);
    final out = ByteData(80);
    final written = buildFrameInfo(m, 800, 600, dashScale: 1.7, out: out);
    expect(identical(written, out), isTrue);
    for (var i = 0; i < 80; i++) {
      expect(out.getUint8(i), fresh.getUint8(i), reason: 'byte $i');
    }
    // The wrong size is not trusted: a fresh block, not a partial write.
    final wrong = ByteData(64);
    expect(identical(buildFrameInfo(m, 800, 600, dashScale: 1.7, out: wrong),
        wrong), isFalse);
  });
```

Add to `test/gpu/text_patches_test.dart`:

```dart
  test('patchRegionFor writes into `out` and leaves it alone when off screen',
      () {
    final t = ResidentTextRecord(
        text: 'X', style: const Handle(11), argb: 0xFF000000,
        a: 1, b: 0, c: 0, d: -1, e: 0, f: 0,
        boxMinX: 10, boxMinY: 20, boxMaxX: 50, boxMaxY: 40, instanceIndex: 0);
    final out = PatchRegion(7, 7, 7, 7);
    final onScreen = patchRegionFor(t, Transform2.scale(2, 2), 800, 600,
        maxWidth: 4096, maxHeight: 4096, out: out);
    expect(identical(onScreen, out), isTrue);
    expect((out.x, out.y, out.width, out.height), (20, 40, 80, 40));
    final offScreen = patchRegionFor(
        t, Transform2.translation(-1000, 0), 800, 600,
        maxWidth: 4096, maxHeight: 4096, out: out);
    expect(offScreen, isNull);
    expect((out.x, out.y, out.width, out.height), (20, 40, 80, 40),
        reason: 'an off-screen answer must not scribble on the pool entry');
  });
```

Every `const PatchRegion(` in the existing tests becomes `PatchRegion(`.

- [ ] **Step 5: The reuses**

`text_patches.dart` — `PatchRegion` becomes:

```dart
/// Where a patch draws on screen this frame: device pixels, on the viewport.
///
/// **Mutable, and pooled by `GpuDrawBackend`** (Ruling F10, Plan E's RF-1):
/// one instance per patch for the backend's life, written in place by
/// [patchRegionFor]'s `out` each frame. Rebuild-time callers and tests pass
/// no `out` and get a fresh one.
class PatchRegion {
  PatchRegion(this.x, this.y, this.width, this.height);
  int x, y, width, height;
}
```

and `patchRegionFor` gains `PatchRegion? out` and ends:

```dart
  if (x1 <= x0 || y1 <= y0) return null;
  final w = (x1 - x0).clamp(0, maxWidth);
  final h = (y1 - y0).clamp(0, maxHeight);
  if (out == null) return PatchRegion(x0, y0, w, h);
  out
    ..x = x0
    ..y = y0
    ..width = w
    ..height = h;
  return out;
```

`gpu_draw_backend.dart` — `buildFrameInfo` gains `ByteData? out` and opens
with:

```dart
  final data = out != null && out.lengthInBytes == 80 ? out : ByteData(80);
```

(every one of the twenty floats is written explicitly, `f(19, 0)` included,
so a reused block carries nothing over). Add a doc line: *"`out`, when given
and 80 bytes long, is written in place and returned -- the frame path's own
block; a fresh one otherwise."*

`GpuDrawBackend` replaces `_pendingRegions` and adds a pool:

```dart
  /// The frame's uniform block, written in place by `buildFrameInfo(out:)`
  /// once for the main pass and once per patch; `HostBuffer.emplace` copies
  /// the bytes, so one block serves every pass of a frame.
  final ByteData _frameInfo = ByteData(80);

  /// One `PatchRegion` per patch, for the backend's life -- grown to
  /// `geometry.patches.length` on the first frame that needs each slot and
  /// never past it, then written in place by `patchRegionFor(out:)`.
  final List<PatchRegion> _regionPool = <PatchRegion>[];

  /// Parallel lists, reused per frame: the patches this frame drew and the
  /// pool entry each drew into, drained into [_patchImages] after the last
  /// `submit()` (see [render]'s tail). Two lists rather than a list of
  /// records, so the drain allocates no record per patch.
  final List<ResidentPatch> _pendingPatches = <ResidentPatch>[];
  final List<PatchRegion> _pendingRegions = <PatchRegion>[];
```

In `render`: clear both pending lists at the top (where `_pendingRegions.clear()`
was); the two `emplace(buildFrameInfo(...))` calls pass `out: _frameInfo`; the
patch loop becomes indexed:

```dart
    for (var p = 0; p < geometry.patches.length; p++) {
      final patch = geometry.patches[p];
      final t = geometry.texts[patch.textIndex];
      while (_regionPool.length <= p) {
        _regionPool.add(PatchRegion(0, 0, 0, 0));
      }
      final region = patchRegionFor(t, collectionToDevice, widthPx, heightPx,
          maxWidth: patch.targetWidth,
          maxHeight: patch.targetHeight,
          scratch: _regionScratch,
          out: _regionPool[p]);
      if (region == null) {
        patchesOffscreen++;
        continue;
      }
      // ... unchanged through `patchesRendered++;` ...
      _pendingPatches.add(patch);
      _pendingRegions.add(region);
    }
```

and the drain iterates `for (var k = 0; k < _pendingPatches.length; k++)`
reading `_pendingPatches[k]` and `_pendingRegions[k]`. Update the class doc's
enumeration of per-patch allocations: `PatchRegion` and the uniform block
leave the list; `PatchImage`, three `Rect`s, the `asImage()` handle and the
layer stay (with `gpu.Viewport`, `vm.Vector4`, `gpu.BufferView`, the command
buffer and the render pass as the GPU shim's own per-pass objects, which Task
8's probe reports beside ours).

- [ ] **Step 6: Run all four files; expect PASS**

Run: `flutter test test/gpu/text_compositor_viewport_test.dart test/gpu/text_compositor_test.dart test/gpu/text_patches_test.dart test/gpu/frame_info_test.dart test/gpu/text_order_test.dart`

- [ ] **Step 7: Gates, commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git status --short
git add lib/src/gpu/text_compositor.dart lib/src/gpu/text_patches.dart lib/src/gpu/gpu_draw_backend.dart test/gpu/text_compositor_viewport_test.dart test/gpu/text_patches_test.dart test/gpu/frame_info_test.dart
git commit -m "perf(gpu): the compositor skips off-viewport labels; PatchRegion and the uniform block are reused fields"
```

---

### Task 7: The band is measured (criterion 2), and both zoom defects are reproduced on tiles and absent on the resident arm (criterion 12)

**Files:**
- Modify: `test/support/gpu_comparison.dart` (`CompositedAgreement.uncovered`, `collectionViewport:`)
- Create: `test/support/resident_zoom_rig.dart`
- Test: `test/gpu/band_sweep_test.dart`, `test/gpu/zoom_defect_test.dart`
- Possibly modify: `lib/src/gpu/text_patches.dart` (the two band constants, per Ruling F6 — only if Step 4's rows say so)

**Interfaces:**
- Consumes: `measureCompositedAgreement` (Plan E), `collectionFrameFor`
  (Task 1), `zoomedAbout` (Task 2), `TileRig`, `measureTiledAgreement`,
  `InkReport` (`tile_comparison.dart`), `crossingGrid`, `tileCamera`,
  `kTileViewport`, `kTileDpr` (`tile_fixture.dart`).
- Produces: `CompositedAgreement.uncovered`; `ResidentZoomRig`; the reported
  band; the band constants' final values.

- [ ] **Step 1: The instrument grows an `uncovered` count and a collection viewport**

In `test/support/gpu_comparison.dart`:

```dart
class CompositedAgreement {
  const CompositedAgreement(this.union, this.withinTwo, this.overEight,
      this.referenceInk, this.patchCount, this.uncovered);
  final int union, withinTwo, overEight, referenceInk, patchCount;

  /// Reference ink the resident arm left blank -- the zoom-out defect's own
  /// unit (`InkReport.uncoveredPixels` on the tiled arm).
  final int uncovered;
  double get agreement => union == 0 ? 1.0 : withinTwo / union;

  @override
  String toString() => 'CompositedAgreement(agreement=${agreement.toStringAsFixed(5)} '
      'withinTwo=$withinTwo union=$union overEight=$overEight '
      'uncovered=$uncovered referenceInk=$referenceInk patches=$patchCount)';
}
```

`measureCompositedAgreement` gains `Size? collectionViewport` (doc: *"the
viewport the collector walks under -- `collectionFrameFor(...).viewport` for
a rebuild's arrangement; defaults to `size`, Plan E's arrangement"*), and
uses it: `painter.paint(collector, collectionCamera, collectionViewport ??
size);`. In the pixel loop, after `final inkA = ..., inkB = ...;` add `var
uncovered = 0;` outside and `if (inkA && !inkB) uncovered++;` inside, and
pass it as the sixth argument.

- [ ] **Step 2: The resident rig**

`test/support/resident_zoom_rig.dart`:

```dart
import 'dart:ui';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'gpu_comparison.dart';
import 'tile_fixture.dart';

/// The resident arm as a rig (Ruling F13): the collection frame a rebuild
/// would take at the gesture's start, re-collected whenever a frame's ratio
/// leaves the band -- `ResidentRebuilder`'s policy applied in-rig -- and
/// every frame compared against a live reference at the same camera.
///
/// **A frame out of band is drawn from the collection the rig has**, counted
/// in [staleFrames], and the re-collection lands for the NEXT frame, exactly
/// as the rebuilder's post-frame callback would order it.
class ResidentZoomRig {
  ResidentZoomRig(this.doc, this.measurer, ViewportTransform start,
      {this.bandLowerScale = kBandLowerScale,
      this.bandUpperScale = kBandUpperScale,
      this.size = kTileViewport,
      this.dpr = kTileDpr}) {
    _collectAt(start);
  }

  final DraftDocument doc;
  final FlutterTextMeasurer measurer;
  final double bandLowerScale, bandUpperScale;
  final Size size;
  final double dpr;

  late CollectionFrame collectionFrame;
  int rebuilds = 0;
  int staleFrames = 0;

  void _collectAt(ViewportTransform live) {
    collectionFrame = collectionFrameFor(live, doc.extents);
  }

  bool inBand(ViewportTransform live) {
    final ratio = live.scale / collectionFrame.camera.scale;
    return ratio >= bandLowerScale && ratio <= bandUpperScale;
  }

  Future<CompositedAgreement> frame(ViewportTransform live) async {
    final m = await measureCompositedAgreement(doc,
        collectionCamera: collectionFrame.camera,
        collectionViewport: collectionFrame.viewport,
        liveCamera: live,
        size: size,
        devicePixelRatio: dpr,
        pixelsPerPaperMm: kLogicalPixelsPerMm,
        measurer: measurer);
    if (!inBand(live)) {
      staleFrames++;
      _collectAt(live);
      rebuilds++;
    }
    return m;
  }
}
```

- [ ] **Step 3: The band sweep**

`test/gpu/band_sweep_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/fixtures.dart';
import '../support/gpu_comparison.dart';
import '../support/recording_frame_painter.dart';

/// Live-over-collection ratios, the band's two provisional edges among them.
const List<double> kRatios = [0.25, 0.35, 0.5, 0.7, 1.0, 1.4, 2.0, 2.8, 4.0];
const Size _size = Size(800, 600);
const Offset _centre = Offset(400, 300);
const double _dpr = 1.0;

/// Criterion 1, literally: per-channel <= 2 on >= 99.5% of the union, <= 8
/// on the rest, and differing pixels below 1% of live ink.
bool criterionOne(CompositedAgreement m) =>
    m.union > 0 &&
    m.withinTwo / m.union >= 0.995 &&
    m.overEight == 0 &&
    (m.union - m.withinTwo) < 0.01 * m.referenceInk;

Future<Map<double, CompositedAgreement>> sweep(
  DraftDocument doc,
  FlutterTextMeasurer measurer, {
  required String name,
  required ViewportTransform collection,
  required double minTextCapPixels,
}) async {
  final frame = collectionFrameFor(collection, doc.extents);
  final rows = <double, CompositedAgreement>{};
  for (final r in kRatios) {
    final m = await measureCompositedAgreement(doc,
        collectionCamera: frame.camera,
        collectionViewport: frame.viewport,
        liveCamera: zoomedAbout(collection, _centre, r),
        size: _size,
        devicePixelRatio: _dpr,
        pixelsPerPaperMm: kLogicalPixelsPerMm,
        measurer: measurer,
        minTextCapPixels: minTextCapPixels);
    rows[r] = m;
    // ignore: avoid_print
    print('BAND $name ratio=$r ${criterionOne(m) ? "PASS" : "FAIL"} $m');
  }
  return rows;
}

/// The widest contiguous run of passing ratios containing 1.0.
(double, double) passingRun(Map<double, CompositedAgreement> rows) {
  var lo = 1.0, hi = 1.0;
  final i1 = kRatios.indexOf(1.0);
  for (var i = i1 - 1; i >= 0 && criterionOne(rows[kRatios[i]]!); i--) {
    lo = kRatios[i];
  }
  for (var i = i1 + 1; i < kRatios.length && criterionOne(rows[kRatios[i]]!); i++) {
    hi = kRatios[i];
  }
  return (lo, hi);
}

void main() {
  late FlutterTextMeasurer measurer;
  setUp(() {
    measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
  });

  test("solid curves: criterion 1 holds at the band's edges and at 1.0, and "
      'the divergence past the band is real', () async {
    final doc = differentialFixture(measurer: measurer);
    final fit = ViewportTransform.fit(doc.extents, _size);
    final rows = await sweep(doc, measurer,
        name: 'curves@fit', collection: fit, minTextCapPixels: 0);
    for (final r in [kBandLowerScale, 1.0, kBandUpperScale]) {
      expect(criterionOne(rows[r]!), isTrue, reason: 'ratio $r: ${rows[r]}');
    }
    expect(rows[1.0]!.referenceInk, greaterThan(5000));
    // Anti-vacuity: the frozen chord count is a real divergence at 4x, so
    // this instrument is not comparing the resident arm to itself.
    expect(rows[4.0]!.agreement, lessThan(rows[1.0]!.agreement));
    final (lo, hi) = passingRun(rows);
    // ignore: avoid_print
    print('BAND curves@fit run=[$lo, $hi] = ${(hi / lo).toStringAsFixed(2)}x');
  });

  test('solid curves at a working zoom: Float32 at 8x the fit scale holds '
      "criterion 1 at the band's edges", () async {
    final doc = differentialFixture(measurer: measurer);
    final working = zoomedAbout(ViewportTransform.fit(doc.extents, _size), _centre, 8.0);
    final rows = await sweep(doc, measurer,
        name: 'curves@8x', collection: working, minTextCapPixels: 0);
    for (final r in [kBandLowerScale, 1.0, kBandUpperScale]) {
      expect(criterionOne(rows[r]!), isTrue, reason: 'ratio $r: ${rows[r]}');
    }
    expect(rows[1.0]!.referenceInk, greaterThan(5000));
  });

  test("text with level of detail on: criterion 1 holds at the band's edges "
      'and at 1.0', () async {
    final doc = textOverlapFixture(measurer);
    final fit = ViewportTransform.fit(doc.extents, _size);
    final rows = await sweep(doc, measurer,
        name: 'text-lod@fit', collection: fit, minTextCapPixels: kMinTextCapPixels);
    for (final r in [kBandLowerScale, 1.0, kBandUpperScale]) {
      expect(criterionOne(rows[r]!), isTrue, reason: 'ratio $r: ${rows[r]}');
    }
    expect(rows[1.0]!.patchCount, greaterThanOrEqualTo(1));
    final (lo, hi) = passingRun(rows);
    // ignore: avoid_print
    print('BAND text-lod@fit run=[$lo, $hi] = ${(hi / lo).toStringAsFixed(2)}x');
  });
}
```

- [ ] **Step 4: Run it, read the rows, and apply Ruling F6**

Run: `flutter test test/gpu/band_sweep_test.dart`

Three outcomes, each with a fixed response:

1. **Every assertion green.** The constants stay `0.5` / `2.0`. Record the
   three printed runs and their intersection in the report as *the reported
   band*.
2. **An edge assertion is red** (a row at `0.5` or `2.0` fails criterion 1).
   Move that constant in `text_patches.dart` to the nearest passing grid
   ratio toward 1.0 (`0.5 → 0.7`, or `2.0 → 1.4`). Re-run this file, then
   `text_patches_test.dart`, `text_order_test.dart`, `resident_rebuilder_test.dart`
   and `draft_canvas_resident_test.dart` — Plan E's *"the band constants and
   the pad are what the spec says"* test and this plan's `2.01`/`1.9` band
   probes name the old values and must be updated to the new ones, and only
   to the new ones. Ledger the change with the failing row pasted.
3. **The intersection of the runs is narrower than 2×** (`hi / lo < 2`).
   Outcome 2 applies to the constants, and the results note records
   criterion 2 as **the design failure the spec names**, with the rows.

The `4.0 < 1.0` anti-vacuity assertion failing is a different thing: it says
the instrument cannot see the chord divergence at all, and that is a Task 7
defect to fix (check `collectionViewport` reached the collector), not a
band result.

- [ ] **Step 5: The zoom defects**

`test/gpu/zoom_defect_test.dart`:

```dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/recording_frame_painter.dart';
import '../support/resident_zoom_rig.dart';
import '../support/tile_comparison.dart';
import '../support/tile_fixture.dart';

/// The probe's own gestures (`2026-08-29-settle-flicker-probe.md`): twelve
/// steps, then six settle frames, about the viewport centre.
const int kSteps = 12;
const int kSettle = 6;
const double kZoomOut = 0.94;
const double kZoomIn = 1.02;
const Offset kCentre = Offset(200, 150);

Future<void> warm(TileRig rig) async {
  for (var i = 0; i < 40 && !rig.cache.viewportCovered; i++) {
    await measureTiledAgreement(rig);
  }
  expect(rig.cache.viewportCovered, isTrue, reason: 'the warm-up must cover');
}

void main() {
  group('zoom out, twelve steps of 0.94', () {
    test('the tiled arm leaves ink uncovered during the gesture and one frame '
        'after it', () async {
      final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 64);
      addTearDown(rig.dispose);
      await warm(rig);
      final gesture = <int>[];
      for (var i = 0; i < kSteps; i++) {
        rig.camera = zoomedAbout(rig.camera, kCentre, kZoomOut);
        gesture.add((await measureTiledAgreement(rig)).uncoveredPixels);
      }
      final settle = <int>[];
      for (var i = 0; i < kSettle; i++) {
        settle.add((await measureTiledAgreement(rig)).uncoveredPixels);
      }
      // ignore: avoid_print
      print('ZOOM-OUT tiled uncovered: gesture=$gesture settle=$settle');
      expect(gesture.reduce(math.max), greaterThan(0),
          reason: 'the reproduction: the probe read 5,730 at the worst frame');
      expect(settle.first, greaterThan(0),
          reason: 'still uncovered one frame after the gesture (4,893)');
      expect(settle.last, 0, reason: 'and settled');
    });

    test('the resident arm leaves nothing uncovered at any frame', () async {
      final measurer = FlutterTextMeasurer();
      addTearDown(measurer.clear);
      final doc = crossingGrid(measurer);
      final rig = ResidentZoomRig(doc, measurer, tileCamera());
      var camera = tileCamera();
      final uncovered = <int>[];
      final agreement = <double>[];
      Future<void> frame() async {
        final m = await rig.frame(camera);
        expect(m.referenceInk, greaterThan(1000), reason: 'anti-vacuity: $m');
        uncovered.add(m.uncovered);
        agreement.add(m.agreement);
      }
      for (var i = 0; i < kSteps; i++) {
        camera = zoomedAbout(camera, kCentre, kZoomOut);
        await frame();
      }
      for (var i = 0; i < kSettle; i++) {
        await frame();
      }
      // ignore: avoid_print
      print('ZOOM-OUT resident uncovered=$uncovered rebuilds=${rig.rebuilds} '
          'stale=${rig.staleFrames}');
      // MUTATION (M-F5): collect under the live camera and kTileViewport ->
      // the first zoom-out step reveals uncovered ink at the viewport's rim.
      expect(uncovered, everyElement(0));
      expect(agreement, everyElement(greaterThanOrEqualTo(0.995)));
      expect(rig.rebuilds, 1,
          reason: '0.94^12 = 0.476 leaves the band at the last step');
    });
  });

  group('zoom in, twelve steps of 1.02', () {
    test('the tiled arm shows the wrong resolution over the settle', () async {
      final rig = TileRig(tileDevicePixels: 64, tilesBakedPerFrame: 64);
      addTearDown(rig.dispose);
      await warm(rig);
      for (var i = 0; i < kSteps; i++) {
        rig.camera = zoomedAbout(rig.camera, kCentre, kZoomIn);
        await measureTiledAgreement(rig);
      }
      final settle = <int>[];
      for (var i = 0; i < kSettle; i++) {
        settle.add((await measureTiledAgreement(rig)).differingPixels);
      }
      // ignore: avoid_print
      print('ZOOM-IN tiled differing over the settle: $settle');
      expect(settle.first, greaterThan(0),
          reason: 'the reproduction: the probe read 25,275 / 16,681 / 0');
      expect(settle.last, 0);
    });

    test('the resident arm matches the reference at every frame, with no '
        'rebuild', () async {
      final measurer = FlutterTextMeasurer();
      addTearDown(measurer.clear);
      final doc = crossingGrid(measurer);
      final rig = ResidentZoomRig(doc, measurer, tileCamera());
      var camera = tileCamera();
      for (var i = 0; i < kSteps + kSettle; i++) {
        if (i < kSteps) camera = zoomedAbout(camera, kCentre, kZoomIn);
        final m = await rig.frame(camera);
        expect(m.referenceInk, greaterThan(1000));
        expect(m.uncovered, 0, reason: 'frame $i: $m');
        expect(m.agreement, greaterThanOrEqualTo(0.995), reason: 'frame $i: $m');
      }
      expect(rig.rebuilds, 0, reason: '1.02^12 = 1.27 stays inside the band');
    });
  });
}
```

`TileRig.dispose` is whatever `tile_fixture.dart` exposes for teardown; if
the rig has none, tear down its `measurer.clear()` and `index.dispose()`
directly, as `tile_cache_test.dart` does.

- [ ] **Step 6: Run; expect PASS. Record the printed rows**

Run: `flutter test test/gpu/zoom_defect_test.dart test/gpu/text_order_test.dart test/gpu/resident_pixel_differential_test.dart`

- [ ] **Step 7: Gates, commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git status --short
git add test/support/gpu_comparison.dart test/support/resident_zoom_rig.dart test/gpu/band_sweep_test.dart test/gpu/zoom_defect_test.dart lib/src/gpu/text_patches.dart
git commit -m "test(gpu): the band is measured, and both zoom defects reproduce on tiles and vanish on the resident arm"
```

---

### Task 8: The harness — arm D, the trigger phases, the band exit, and the allocation probe

**Files:**
- Modify: `apps/dev_harness_2d/pubspec.yaml`
- Create: `apps/dev_harness_2d/lib/allocation_probe.dart`
- Modify: `apps/dev_harness_2d/lib/gpu_arm.dart`
- Modify: `apps/dev_harness_2d/lib/main.dart`
- Modify: `.vscode/launch.json`
- Test: `apps/dev_harness_2d/test/gpu_widget_arm_test.dart`

**Interfaces:**
- Consumes: `DraftCanvas(backend: RenderBackend.residentGpu)`,
  `DraftCanvasState.resident`, `ResidentRebuilder`'s counters,
  `GpuDrawBackend.frames`/`patchesRendered`, `FrameTimingLog`, `pumpFrame`,
  `gpuReport`, `gpuStats`.
- Produces: `GpuSpikeArm.widget`, `parseBackend`, `fireDocumentTrigger`,
  `AllocationProbe`, `kAllocFixed`, `kAllocPerPatch`, the GSPIKE lines Task 10
  reads.

- [ ] **Step 1: `vm_service`, and `BACKEND=residentGpu`**

`apps/dev_harness_2d/pubspec.yaml`, under `dependencies:`:

```yaml
  vm_service: ^15.2.0
```

then `flutter pub get` **and `git checkout -- '**/analysis_options.yaml'`**
before anything is staged.

`main.dart`: replace the `kBackend` switch with

```dart
/// `BACKEND=canvas|vertices|residentGpu`, or unset for the platform default.
/// A function so a test can check the parse without a `--dart-define`.
RenderBackend? parseBackend(String value) => switch (value) {
      '' => null,
      'canvas' => RenderBackend.canvas,
      'vertices' => RenderBackend.vertices,
      'residentGpu' => RenderBackend.residentGpu,
      final other => throw StateError(
          'BACKEND must be canvas, vertices, residentGpu or unset; got "$other"'),
    };

final RenderBackend? kBackend =
    parseBackend(const String.fromEnvironment('BACKEND', defaultValue: ''));
```

keeping the doc comment above it.

- [ ] **Step 2: Write the failing harness tests**

`apps/dev_harness_2d/test/gpu_widget_arm_test.dart`:

```dart
import 'dart:async';

import 'package:dev_harness_2d/gpu_arm.dart';
import 'package:dev_harness_2d/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

void main() {
  test('BACKEND parses residentGpu, and still refuses a typo', () {
    expect(parseBackend('residentGpu'), RenderBackend.residentGpu);
    expect(parseBackend('vertices'), RenderBackend.vertices);
    expect(parseBackend(''), isNull);
    expect(() => parseBackend('gpu'), throwsStateError);
  });

  test('four arms, four distinct labels, and D names the widget', () {
    expect(GpuSpikeArm.values, hasLength(4));
    expect(GpuSpikeArm.values.map((a) => a.label).toSet(), hasLength(4));
    expect(GpuSpikeArm.widget.label, contains('DraftCanvas'));
    expect(GpuSpikeArm.gpu.label, isNot(contains('DraftCanvas')));
  });

  test('fireDocumentTrigger emits the DocChange its name says', () async {
    final doc = spikeDocument(entityCount: 500, text: false);
    final probe = doc.handleSeed.next();
    final seen = <DocChange>[];
    final sub = doc.changes.listen(seen.add);
    addTearDown(sub.cancel);
    Future<Type> fire(String name) async {
      seen.clear();
      fireDocumentTrigger(doc, name, probe: probe);
      await Future<void>.delayed(Duration.zero);
      expect(seen, hasLength(1), reason: name);
      return seen.single.runtimeType;
    }
    expect(await fire('CommandApplied'), CommandApplied);
    expect(await fire('CommandUndone'), CommandUndone);
    expect(await fire('CommandRedone'), CommandRedone);
    expect(await fire('DocumentLoaded'), DocumentLoaded);
    expect(await fire('DocumentPurged'), DocumentPurged);
    final before = doc.tables.mutationRevision;
    fireDocumentTrigger(doc, 'tables', probe: probe);
    await Future<void>.delayed(Duration.zero);
    expect(doc.tables.mutationRevision, greaterThan(before));
    expect(seen, isEmpty, reason: 'a table edit emits no DocChange (spec)');
    expect(() => fireDocumentTrigger(doc, 'nonsense', probe: probe),
        throwsArgumentError);
  });

  test('the allocation budget is the enumerated exception set, generously', () {
    // A per-instance allocation on the measured corpus (~110,000 instances)
    // exceeds any P the corpus can have by orders of magnitude; the two
    // constants only have to be above the per-patch and fixed sets Plan E's
    // results note and the GPU shim's own per-pass objects add up to.
    expect(kAllocPerPatch, inInclusiveRange(12, 32));
    expect(kAllocFixed, inInclusiveRange(16, 64));
  });
}
```

- [ ] **Step 3: Run to verify they fail**

Run: `cd apps/dev_harness_2d && flutter test --concurrency=1 test/gpu_widget_arm_test.dart`
Expected: FAIL — `GpuSpikeArm.widget`, `fireDocumentTrigger`, `kAllocPerPatch` undefined.

- [ ] **Step 4: The probe**

`apps/dev_harness_2d/lib/allocation_probe.dart`:

```dart
// The frame-path allocation instrument the spec's invariant 1 calls a "new
// mechanism" (Ruling F8). `flutter test` cannot host one --
// `flutter_tester` launches with `--disable-vm-service` (STATUS, Plan 3g) --
// but a `flutter run --profile` process serves the VM service for DevTools,
// and this connects to its own isolate the way
// `packages/jet_cad_2d/test/invariants/vm_allocation_meter.dart` does under
// `dart test`, with `Service.getInfo()` first because the server is already
// up here.
import 'dart:developer' as dev;
import 'dart:isolate' as iso;

import 'package:vm_service/vm_service.dart' as vms;
import 'package:vm_service/vm_service_io.dart' as vms_io;

/// Library URIs whose classes the report counts: this project's own frame
/// path, the two `dart:` libraries its per-frame objects live in, and the
/// GPU shim's per-pass objects, reported beside ours.
const List<String> kProbedLibraryPrefixes = <String>[
  'package:jet_cad_2d_flutter/',
  'dart:ui',
  'dart:typed_data',
  'package:flutter_gpu/',
  'package:flutter_scene/',
];

class AllocationProbe {
  AllocationProbe._(this._service, this._isolateId);
  final vms.VmService _service;
  final String _isolateId;

  /// Connects to this process's VM service. Throws with the reason when the
  /// service is not serving; the caller reports UNEVALUABLE, never a number.
  static Future<AllocationProbe> connect() async {
    var info = await dev.Service.getInfo();
    if (info.serverUri == null) {
      info = await dev.Service.controlWebServer(enable: true);
    }
    final http = info.serverUri;
    if (http == null) {
      throw StateError('the VM service is not serving (Service.getInfo and '
          'controlWebServer gave no URI) -- is this a --profile run?');
    }
    final ws = http.replace(
        scheme: 'ws', path: http.path.endsWith('/') ? '${http.path}ws' : '${http.path}/ws');
    final service = await vms_io.vmServiceConnectUri(ws.toString());
    final isolateId = dev.Service.getIsolateId(iso.Isolate.current);
    if (isolateId == null) {
      await service.dispose();
      throw StateError('Service.getIsolateId(Isolate.current) is null');
    }
    // The first RPC proves the connection; a refused one throws here, not
    // in the middle of a measurement.
    await service.getAllocationProfile(isolateId);
    return AllocationProbe._(service, isolateId);
  }

  /// Two RPCs, not one -- the meter's own finding: `gc: true` and `reset:
  /// true` on one call left the accumulators non-zero.
  Future<void> reset() async {
    await _service.getAllocationProfile(_isolateId, gc: true);
    await _service.getAllocationProfile(_isolateId, reset: true);
  }

  /// `instancesAccumulated` since [reset], per class, for the probed
  /// libraries. Keys are `<library uri> <class name>`.
  Future<Map<String, int>> read() async {
    final profile = await _service.getAllocationProfile(_isolateId);
    final out = <String, int>{};
    for (final m in profile.members ?? const <vms.ClassHeapStats>[]) {
      final cls = m.classRef;
      if (cls == null) continue;
      final lib = cls.library?.uri ?? '';
      if (!kProbedLibraryPrefixes.any(lib.startsWith)) continue;
      final n = m.instancesAccumulated ?? 0;
      if (n == 0) continue;
      out['$lib ${cls.name}'] = n;
    }
    return out;
  }

  Future<void> dispose() => _service.dispose();
}
```

- [ ] **Step 5: Arm D, the triggers, the band exit, the probe phase**

In `apps/dev_harness_2d/lib/gpu_arm.dart`:

**The enum** gains a fourth value after `gpu`:

```dart
  /// `DraftCanvas(backend: RenderBackend.residentGpu)`: the same backend as
  /// arm C, reached through the widget path Plan F wired -- collected over
  /// the extents at the live scale, rebuilt on the five triggers. Arm C
  /// stays as the control (Ruling F9); a widget-path regression shows as a
  /// C-to-D gap, not as a mystery.
  widget;
```

with `GpuSpikeArm.widget => 'D residentGpu (DraftCanvas)'` in `label`.

**The budget constants**, top level:

```dart
/// Criterion 5's gate (Ruling F8): per-frame allocations on arm D's pan
/// phase, `<= kAllocFixed + kAllocPerPatch * P`. The per-patch set the spec's
/// exception enumerates -- `PatchImage`, three `Rect`s, the `asImage()`
/// handle, plus the GPU shim's own `Viewport`, `Vector4`, two `BufferView`s,
/// a command buffer and a render pass -- is under twelve; the fixed set --
/// `composeTransforms` twice, the main image and its two `Rect`s, the main
/// pass's shim objects -- is under twenty. Both doubled: a per-INSTANCE
/// allocation is ~110,000 per frame on the measured corpus and no slack
/// here can hide it.
const int kAllocFixed = 40;
const int kAllocPerPatch = 24;
```

**`GpuSpikeState`** gains:

```dart
  /// Arm D's canvas, so the rig can read its rebuilder.
  final GlobalKey<DraftCanvasState> widgetKey = GlobalKey<DraftCanvasState>();

  /// Non-null while the rig is exercising the `devicePixelRatio` trigger:
  /// arm D's `MediaQuery` reports this ratio instead of the window's.
  final ValueNotifier<double?> dprOverride = ValueNotifier<double?>(null);

  ResidentRebuilder? get widgetRebuilder => widgetKey.currentState?.resident;

  /// The `GpuDrawBackend` an arm draws through, or null: arm C's is
  /// [backend]; arm D's is its rebuilder's, once landed; A and B have none.
  GpuDrawBackend? backendOf(GpuSpikeArm a) => switch (a) {
        GpuSpikeArm.gpu => backend,
        GpuSpikeArm.widget => widgetRebuilder?.backend as GpuDrawBackend?,
        _ => null,
      };
```

`dispose()` adds `dprOverride.dispose();`. The `Stack` gains, after arm C's
`Positioned.fill`:

```dart
                    Offstage(
                      offstage: a != GpuSpikeArm.widget,
                      child: ValueListenableBuilder<double?>(
                        valueListenable: dprOverride,
                        builder: (context, dpr, _) {
                          final data = MediaQuery.of(context);
                          return MediaQuery(
                            data: dpr == null
                                ? data
                                : data.copyWith(devicePixelRatio: dpr),
                            child: DraftCanvas(
                              key: widgetKey,
                              document: widget.document,
                              index: index,
                              camera: camera,
                              lineweightScale: widget.lineweightScale,
                              drawText: widget.drawText,
                              backend: RenderBackend.residentGpu,
                              tiles: false,
                            ),
                          );
                        },
                      ),
                    ),
```

An `Offstage` canvas is laid out and never painted, so arm D's first
`noteFrame` -- and its first rebuild -- happens when the rig switches to it.

**`fireDocumentTrigger`**, top level, GPU-free and tested:

```dart
/// Fires one of the document-side triggers by name. `probe` is the handle
/// the `CommandApplied` line is added under (and undone, and redone); the
/// caller allocates it once from `doc.handleSeed`.
void fireDocumentTrigger(DraftDocument doc, String name, {required Handle probe}) {
  switch (name) {
    case 'CommandApplied':
      final cx = kDefaultOriginX + kFloorWidth / 2;
      final cy = kOriginY + kFloorHeight / 2;
      doc.commands.execute(AddEntityCommand(
        record: EntityRecord(
          handle: probe,
          owner: doc.rootHandle,
          kind: EntityKind.line,
          layer: ReservedHandles.layerZero,
          linetype: ReservedHandles.byLayerLinetype,
          linetypeScale: 1.0,
          geomIndex: 0,
          color: const ByLayerColor(),
          lineweight: 100,
          transparency: 0,
          flags: 0,
        ),
        payload: GeometryPayload(
            coords: Float64List.fromList(
                [cx - 8000, cy - 5000, cx + 8000, cy + 5000]),
            scalars: Float64List(0)),
      ));
    case 'CommandUndone':
      doc.commands.undo();
    case 'CommandRedone':
      doc.commands.redo();
    case 'DocumentLoaded':
      doc.commands.notifyLoaded();
    case 'DocumentPurged':
      doc.purge();
    case 'tables':
      final zero = doc.tables.layers[ReservedHandles.layerZero]!;
      final next = zero.color is IndexedColor && (zero.color as IndexedColor).aci == 1 ? 2 : 1;
      doc.tables.layers.remove(zero.handle);
      doc.tables.layers.add(LayerRecord(
          handle: zero.handle,
          name: zero.name,
          color: IndexedColor(next),
          linetype: zero.linetype,
          lineweight: zero.lineweight,
          transparency: zero.transparency,
          visible: zero.visible,
          locked: zero.locked));
    default:
      throw ArgumentError.value(name, 'name', 'not a document trigger');
  }
}
```

(`kDefaultOriginX`, `kOriginY`, `kFloorWidth`, `kFloorHeight` are the
constants `_addPatchedLabels` in `main.dart` already reads; import
`main.dart` if `gpu_arm.dart` does not already, and `dart:typed_data`.)

**`runGpuSpike`** changes:

`setArm` gains, before its `painted=0` check:

```dart
    if (a == GpuSpikeArm.widget) {
      // Arm D rebuilds on its first painted frame; nothing it draws before
      // the landing is the resident backend. Wait for it, bounded, and refuse
      // to measure a canvas that fell back.
      var frames = 0;
      while ((state.widgetRebuilder?.landed ?? 0) == 0 && frames < 300) {
        await pumpFrame();
        frames++;
      }
      final r = state.widgetRebuilder;
      if (r == null || r.landed == 0) {
        throw StateError('GSPIKE ${a.label}: no rebuild landed in $frames '
            'frames -- the widget path is not wired, or the upload hangs.');
      }
      if (r.uploadFailed) {
        throw StateError('GSPIKE ${a.label}: the upload failed and the canvas '
            'fell back to vertices; every number it would post is arm A\'s.');
      }
      gpuReport('GSPIKE ${a.label}: first rebuild landed after $frames '
          'frame(s) -- walk ${(r.lastWalkMicros / 1000).toStringAsFixed(1)} '
          'classify ${(r.lastClassifyMicros / 1000).toStringAsFixed(1)} '
          'upload ${(r.lastUploadMicros / 1000).toStringAsFixed(1)} '
          'total ${(r.lastTotalMicros / 1000).toStringAsFixed(1)} ms (COLD: '
          'the first GPU call of the process pays pipeline creation)');
    }
```

and its `painted=0` check reads `state.backendOf(a)?.frames ?? 0` before and
after, for both `gpu` and `widget`. `phase()` reads `state.backendOf(a)` where
it read `state.backend`. The arms loop already iterates `GpuSpikeArm.values`,
so D's `hold`/`pan`/`zoom` come for free; the per-repeat report loop's `if
(rep.arm == GpuSpikeArm.gpu)` becomes `if (rep.arm == GpuSpikeArm.gpu ||
rep.arm == GpuSpikeArm.widget)`, and `GpuSpikeArm.values.length * 3` already
counts four arms.

**The trigger phase**, run once per repeat after the arms loop, on arm D:

```dart
  /// The trigger names, in the order the spec's table lists them, the dpr
  /// pair and the band pair last. `probe` is allocated once per run.
  const triggers = <String>[
    'CommandApplied', 'CommandUndone', 'CommandRedone',
    'DocumentLoaded', 'DocumentPurged', 'tables',
    'devicePixelRatio', 'devicePixelRatio back',
    'band out', 'band back',
  ];
  final probe = state.widget.document.handleSeed.next();
  final baseDpr = MediaQuery.devicePixelRatioOf(state.context);

  Future<void> rebuildPhase(int repeat) async {
    await setArm(GpuSpikeArm.widget);
    state.camera.value = baseCamera;
    await pumpFrame();
    final r = state.widgetRebuilder!;
    for (final name in triggers) {
      final before = r.landed;
      switch (name) {
        case 'devicePixelRatio':
          state.dprOverride.value = baseDpr + 1;
        case 'devicePixelRatio back':
          state.dprOverride.value = null;
        case 'band out':
          state.camera.zoomAt(centre, 2.5);
        case 'band back':
          state.camera.zoomAt(centre, 1 / 2.5);
        default:
          fireDocumentTrigger(state.widget.document, name, probe: probe);
      }
      var frames = 0;
      while (r.landed == before && frames < 300) {
        await pumpFrame();
        frames++;
      }
      if (r.landed == before) {
        throw StateError('GSPIKE D rebuild | $name | no rebuild landed in '
            '$frames frames');
      }
      final c = r.collection!;
      gpuReport('GSPIKE D rebuild | r${repeat + 1} | $name | '
          'trigger=${r.lastTrigger!.name} '
          'walk ${(r.lastWalkMicros / 1000).toStringAsFixed(2)} '
          'classify ${(r.lastClassifyMicros / 1000).toStringAsFixed(2)} '
          'upload ${(r.lastUploadMicros / 1000).toStringAsFixed(2)} '
          'total ${(r.lastTotalMicros / 1000).toStringAsFixed(2)} ms | '
          'landed after $frames frame(s) | instances=${c.instanceCount} '
          'patches=${c.patches.length} '
          'buffer=${(c.byteLength / (1024 * 1024)).toStringAsFixed(2)} MB');
    }
  }
```

called as `await rebuildPhase(r);` at the end of each repeat's loop body
(after the report lines). **`band out` at 2.5×** collects at 2.5× the fit
scale, so its `instances` and `buffer` line is the first measurement of
criterion 6 at a rebuilt scale; `band back` returns to the base camera and
the collection follows.

**The band-exit phase**, once, after the repeats:

```dart
  await setArm(GpuSpikeArm.widget);
  {
    final r = state.widgetRebuilder!;
    state.camera.value = baseCamera;
    await pumpFrame();
    await pumpFrame();
    r.bandStaleFrames = 0;
    final landedBefore = r.landed;
    // 40 steps of 1.02 leave [0.5, 2.0] at step 36 (1.02^36 = 2.04); the
    // frames from that step to the landing are criterion 9's stale interval.
    final rep = await phase(GpuSpikeArm.widget, 'bandexit',
        (i) => state.camera.zoomAt(centre, 1.02));
    gpuReport('GSPIKE D | bandexit | build  ${gpuStats(rep.build)}');
    gpuReport('GSPIKE D | bandexit | raster ${gpuStats(rep.raster)}');
    gpuReport('GSPIKE D | bandexit | rebuilds landed=${r.landed - landedBefore} '
        'staleFrames=${r.bandStaleFrames} lastTrigger=${r.lastTrigger?.name} '
        '(criterion 9: the stale interval after a mid-gesture band exit, '
        'reported without a threshold)');
  }
```

This needs `frames` to be at least 40 for the phase; `phase()` pumps the
run's `frames`, so the band-exit phase calls `phase` with a local override:
give `phase` an optional `int? frameCount` parameter used in place of
`frames` when non-null, and pass `frameCount: 40` here.

**The allocation phase**, once, last:

```dart
  await setArm(GpuSpikeArm.widget);
  {
    state.camera.value = baseCamera;
    await pumpFrame();
    AllocationProbe? probe;
    try {
      probe = await AllocationProbe.connect();
    } catch (error) {
      gpuReport('GSPIKE alloc: UNEVALUABLE -- the VM service refused: $error');
    }
    if (probe != null) {
      const allocFrames = 30;
      await probe.reset();
      for (var i = 0; i < allocFrames; i++) {
        state.camera.panBy(const Offset(4, 0));
        await pumpFrame();
      }
      final counts = await probe.read();
      final b = state.backendOf(GpuSpikeArm.widget)!;
      final patches = b.patchesRendered;
      var total = 0;
      for (final n in counts.values) {
        total += n;
      }
      final perFrame = total / allocFrames;
      final budget = kAllocFixed + kAllocPerPatch * patches;
      final top = counts.entries.toList()
        ..sort((x, y) => y.value.compareTo(x.value));
      for (final e in top.take(15)) {
        gpuReport('GSPIKE alloc | ${(e.value / allocFrames).toStringAsFixed(1)}'
            '/frame | ${e.key}');
      }
      gpuReport('GSPIKE alloc: perFrame=${perFrame.toStringAsFixed(1)} '
          'patches=$patches budget=$budget '
          '(kAllocFixed=$kAllocFixed + kAllocPerPatch=$kAllocPerPatch x P) '
          '-> ${perFrame <= budget ? "PASS" : "MISS"} | frames=$allocFrames '
          'classes=${counts.length} total=$total');
      await probe.dispose();
    }
  }
```

**Every `GSPIKE done` line stays last.**

- [ ] **Step 6: `launch.json`**

Two entries after the `DRAW_TEXT=false` one:

```jsonc
        {
            // Plan F: four arms (D is DraftCanvas on residentGpu), the ten
            // trigger rebuilds per repeat, the band-exit phase and the
            // allocation probe. The same corpus as the criterion-11 run.
            "name": "2d: GPU spike -- Plan F (arm D, triggers, band exit, probe)",
            "cwd": "apps/dev_harness_2d",
            "program": "lib/main.dart",
            "request": "launch",
            "type": "dart",
            "deviceId": "macos",
            "flutterMode": "profile",
            "toolArgs": [
                "--dart-define=RUN_GPU_SPIKE=true",
                "--dart-define=ENTITIES=10000",
                "--dart-define=SPIKE_DEFS=20",
                "--dart-define=SPIKE_INSTANCES=150",
                "--dart-define=SPIKE_FRAMES=30",
                "--dart-define=SPIKE_REPEATS=3",
                "--dart-define=SPIKE_FILLS=true",
                "--dart-define=SPIKE_TEXT=true"
            ]
        },
        {
            // The main view on the resident backend, for the eye: pan and
            // zoom by hand, watch the rebuild land past 2x, pan far off the
            // fitted view and look for an empty edge.
            "name": "2d: main view -- BACKEND=residentGpu",
            "cwd": "apps/dev_harness_2d",
            "program": "lib/main.dart",
            "request": "launch",
            "type": "dart",
            "deviceId": "macos",
            "flutterMode": "profile",
            "toolArgs": [
                "--dart-define=BACKEND=residentGpu",
                "--dart-define=ENTITIES=10000"
            ]
        },
```

- [ ] **Step 7: Run the harness tests; expect PASS. Then the three gates**

```sh
cd apps/dev_harness_2d && flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
cd ../../packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
cd ../jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
git status --short   # analysis_options.yaml must not appear; pubspec.lock changes ARE committed
```

- [ ] **Step 8: Commit**

```sh
git add apps/dev_harness_2d/pubspec.yaml pubspec.lock apps/dev_harness_2d/lib/allocation_probe.dart apps/dev_harness_2d/lib/gpu_arm.dart apps/dev_harness_2d/lib/main.dart apps/dev_harness_2d/test/gpu_widget_arm_test.dart .vscode/launch.json
git commit -m "feat(harness): arm D on DraftCanvas, the ten trigger rebuilds, the band exit, and a VM-service allocation probe"
```

(`pubspec.lock` at the workspace root is the one `flutter pub get` rewrites;
if it is git-ignored in this repository, skip it.)

---
### Task 9: Mutation testing

**Files:**
- Create: `docs/superpowers/notes/plan-f-mutation-log.md`

**Interfaces:**
- Consumes: every test file this plan created. No production code changes
  land in this task; a mutation that survives is a plan defect, ledgered
  and fixed in its own commit before the log records the kill.

- [ ] **Step 1: The procedure, for every row**

```sh
cp <file> /tmp/mut.bak            # never `git checkout --` to restore
# apply the edit below, by hand
cd packages/jet_cad_2d_flutter && flutter test <witness file> 2>&1 | tail -40
cp /tmp/mut.bak <file>
git status --short                # must be clean before the next row
```

Paste the red run's last lines (the failing `expect` and its `reason`) into
the log, verbatim, with the exit code.

- [ ] **Step 2: The rows**

| id | spec mutation / plan mutation | file, edit | witness | expected red line |
|---|---|---|---|---|
| M-F1 | *ignore the table revision counter* | `resident_rebuilder.dart`: delete the `tablesRevision != c.tablesRevision` branch | `resident_rebuilder_test.dart`, `draft_canvas_resident_test.dart` | `pending` null where `tables` expected; `landed` 1 where 2 |
| M-F2 | *ignore the `devicePixelRatio` trigger* | `resident_rebuilder.dart`: delete the `dpr != c.devicePixelRatio` branch | same two files | `pending` null; `collection.devicePixelRatio` 1.0 where 2.0 |
| M-F3 | *read the watermark band against the reference scale instead of the live scale* | `resident_rebuilder.dart`, `inBand`: `final ratio = c.collectionCamera.scale / c.collectionCamera.scale;` | `resident_rebuilder_test.dart` (band), `draft_canvas_resident_test.dart` (band) | `pending` null where `band` expected |
| M-F4 | *leave the resident text list stale across a rebuild* | `resident_rebuilder.dart`, `rebuildNow`: after `collect`, `final next = ResidentCollection(...)` copy with `texts: _collection?.texts ?? next.texts` (spell all eleven fields) | `resident_rebuilder_test.dart` (edited label) | `texts` still contains `'COVERED'`, lacks `'EDITED'` |
| M-F5 | *cull collection to the live viewport → panning reveals empty buffer* | `collection_frame.dart`: `return CollectionFrame(live, const Size(800, 600));` as the first line | `resident_collection_test.dart`, `zoom_defect_test.dart` (resident zoom-out), `band_sweep_test.dart` | `instanceCount` smaller at the corner; `uncovered` nonzero at a zoom-out step |
| M-F6 | plan: coalescing | `resident_rebuilder.dart`, `markDirty`: remove the `_inFlightTrigger != null \|\| _scheduled` early return | `resident_rebuilder_test.dart` (three marks) | `rebuilds` 4 where 2 |
| M-F7 | plan: the rebuild is off the frame path | `resident_rebuilder.dart`, `noteFrame`: replace `markDirty(RebuildTrigger.initial)` with a direct `unawaited(rebuildNow(camera, viewport, dpr, RebuildTrigger.initial))` | `resident_rebuilder_test.dart` (first frame) | `rebuilds` 1 where 0 before the pump |
| M-F8 | criterion 10: once | `draft_canvas.dart`, `_reportResidentFallback`: delete `if (_residentFallbackReported) return;` | `draft_canvas_fallback_test.dart` | `reports` length 2 where 1 |
| M-F9 | plan: the grid's overflow list | `text_patches.dart`, `classifyTextPatches`: delete the `for (final i in overflow)` loop | `classify_grid_test.dart` (generated corpus) | a patch's `instanceCount` differs from the brute force |
| M-F10 | plan: the grid's cell range | `text_patches.dart`, `cellX`/`cellY`: `.floor()` → `.round()` | `classify_grid_test.dart` (generated corpus) | a patch's sub-buffer differs from the brute force |
| M-F11 | plan: viewport rejection | `text_compositor.dart`: invert the four-way `\|\|` test (`!(...)`) | `text_compositor_viewport_test.dart`, `text_order_test.dart` | `drawParagraph` count 2 → wrong two; composited agreement below 0.995 |
| M-F12 | plan: the region pool is written | `text_patches.dart`, `patchRegionFor`: `if (out == null) return PatchRegion(...)` → always `return PatchRegion(x0, y0, w, h);` | `text_patches_test.dart` (`out`) | `identical(onScreen, out)` false |
| M-F13 | plan: a mark during flight | `resident_rebuilder.dart`, `_run`: delete the trailing `if (!_disposed && _pending != null && !_uploadFailed) _schedule();` | `resident_rebuilder_test.dart` (in flight) | `rebuilds` 2 where 3 |
| M-F14 | plan: the frame's uniform block | `gpu_draw_backend.dart`, `buildFrameInfo`: ignore `out` (`final data = ByteData(80);`) | `frame_info_test.dart` (`out`) | `identical(written, out)` false |
| E-F1 | *rebuild only when `touched` is non-empty* — **declared equivalent** | `draft_canvas.dart`, `onChange`: `if (change.touched.isNotEmpty \|\| change is DocumentLoaded \|\| change is DocumentPurged) resident?.markDirty(...)` | `draft_canvas_resident_test.dart` (every DocChange) | **stays green**, and the log says why: `spatial_index.dart:2283-2287` — an empty `touched` on a command is *"defensive, not currently reachable"*, and load and purge are routed on type |

Fire E-F1 too, and record the green run: an equivalent mutation is recorded,
not skipped (spec, *"Removed as equivalent, and recorded rather than
deleted"*).

- [ ] **Step 3: The log**

`docs/superpowers/notes/plan-f-mutation-log.md`, in `plan-e-mutation-log.md`'s
shape: one section per row with the edit as a diff hunk, the command, the
pasted tail, the restore, and a summary table (`fired / killed / survived /
equivalent`). A survivor is a plan defect: fix the test or the code in its
own commit, re-fire, and log both runs.

- [ ] **Step 4: Gates, commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
cd ../jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd ../../apps/dev_harness_2d && flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
git status --short
git add docs/superpowers/notes/plan-f-mutation-log.md
git commit -m "test(gpu): Plan F mutation log -- fourteen fired, one declared equivalent"
```

---

### Task 10: The device run, criteria 2, 5, 7, 8, 9, 12, the results note, the spec's third question, and the resume point

**Files:**
- Create: `docs/superpowers/notes/2026-09-05-plan-f-results.md`
- Create: `docs/superpowers/notes/2026-09-05-plan-f-raw/` (the run logs)
- Modify: `docs/superpowers/specs/2026-08-29-gpu-resident-render-backend-design.md` (open question 3)
- Modify: `STATUS.md`

- [ ] **Step 1: The run, macOS profile, Low Power Mode OFF, and say so**

```sh
cd apps/dev_harness_2d
flutter run -d macos --profile --dart-define=RUN_GPU_SPIKE=true \
  --dart-define=ENTITIES=10000 --dart-define=SPIKE_DEFS=20 \
  --dart-define=SPIKE_INSTANCES=150 --dart-define=SPIKE_FRAMES=30 \
  --dart-define=SPIKE_REPEATS=3 --dart-define=SPIKE_FILLS=true \
  --dart-define=SPIKE_TEXT=true 2>&1 | tee /tmp/plan-f-run.log
```

Copy the log to `docs/superpowers/notes/2026-09-05-plan-f-raw/gspike-run.log`.
Record from it:

- **Criterion 8, arm D** (the widget path): build and raster p50 per phase
  per repeat; the median of three per phase, against `≤ 1.2` build and
  `≤ 2.0` raster; arm C's beside it, and the C-to-D difference per phase.
  Criterion 9's p95 raster on D against `≤ 3.0`.
- **Criterion 7, per trigger**: the ten `GSPIKE D rebuild` lines per repeat;
  the median of three of `total` per trigger against **16.67 ms**, with
  `walk`, `classify`, `upload` beside it. The first `setArm(widget)` line is
  the **cold** figure, reported and not gated. `classify` against Plan E's
  27.4 ms.
- **Criterion 6 at a rebuilt scale**: the `band out` line's `instances` and
  `buffer` against 8 MB, beside the fit-scale figure.
- **Criterion 9's stale interval**: the `bandexit` line's `staleFrames` and
  `rebuilds landed`, without a threshold, with the phase's build/raster max.
- **Criterion 5**: the `GSPIKE alloc` verdict line and the fifteen class
  lines above it. `UNEVALUABLE` is recorded as such with the error text.
- `textsDropped`, if printed, is a defect.

If any arm throws its `StateError`, the run is not a run; fix and repeat.

- [ ] **Step 2: Criterion 2 and criterion 12 from the suite**

Run `flutter test test/gpu/band_sweep_test.dart test/gpu/zoom_defect_test.dart`
once more and copy the printed `BAND`, `ZOOM-OUT` and `ZOOM-IN` lines into
the raw folder as `band-and-zoom.log`. The reported band is the intersection
of the three `run=` lines; the constants' final values are whatever Task 7
left in `text_patches.dart`.

- [ ] **Step 3: Look at the window, and write down what you saw**

Run the `2d: main view -- BACKEND=residentGpu` launch entry and, separately,
the Plan F spike entry. Plan F's four checks:

1. **Arm D draws the same picture as arm C** — watch the switch between the
   two in the spike; nothing moves, nothing appears, nothing vanishes.
2. **The probe line** — during arm D's `CommandApplied` rebuild a heavy
   diagonal appears across the floor's centre; it is gone after
   `CommandUndone`, back after `CommandRedone`, and still there after
   `DocumentLoaded` and `DocumentPurged`.
3. **A band exit sharpens without a blank** — in the main view, zoom in
   past 2× in one gesture: the picture stays drawn on every frame, and
   within a few frames the arcs and dashes re-tessellate at the new scale.
   No white frame, no flicker.
4. **A pan reveals no empty edge** — in the main view, at a working zoom
   (4×–8×), pan the drawing off where it was fitted and keep going; the
   spec's *"33 logical pixels into the first pan"* defect would show as a
   hard edge past which nothing is drawn.

Record each as seen / not seen / could not judge, exactly as answered. Plan
E's fifth check (`DRAW_TEXT=false`) stays OWED unless it is looked at again
here; if it is, record it under Plan E's heading in the results note with a
pointer from Plan E's note, as the 2026-09-05 discharge did.

- [ ] **Step 4: The results note**

`docs/superpowers/notes/2026-09-05-plan-f-results.md`, following Plan E's:
what the plan's own premises measured false; the `flutter test` measurements
(the band rows, the zoom rows, the classify comparison); the device-run
conditions; the criterion-7 table per trigger; the criterion-8 C-versus-D
table; the allocation table; the window; the mutation summary; the exit
gate table with PASS / MISS / UNEVALUABLE / OWED and the number beside each.
**Open question 3's answer** (Ruling F1) gets its own short section.

- [ ] **Step 5: The spec's third question**

In the spec's **Open questions**, strike question 3 the way question 1 is
struck:

```markdown
3. ~~**The reference scale**, and the band that follows from it (criterion 2).~~
   **Answered by Plan F** (Ruling F1): the reference scale is the live
   camera's scale at the moment of the rebuild -- no constant -- and the
   band is the measured run recorded in
   [2026-09-05-plan-f-results.md](../notes/2026-09-05-plan-f-results.md).
```

- [ ] **Step 6: STATUS.md**

Plan F's state under a new `## Plan F` section in the shape of Plan E's; the
resume point rewritten: the exit gate's count, criteria 2, 5, 7, 8, 9, 12
with their numbers, the window checks in whatever state Step 3 left them,
Plan E's fifth check still OWED or discharged, and the sentence that **Plan G
(web) is next**, inheriting: the web rebuild cost (spec open question 4),
Skwasm (question 5), the web timing instrument (question 2), and whatever
criterion 7 or criterion 5 left as a MISS here.

- [ ] **Step 7: All gates, commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
cd ../jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd ../../apps/dev_harness_2d && flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
git status --short
git add docs/superpowers/notes/2026-09-05-plan-f-results.md docs/superpowers/notes/2026-09-05-plan-f-raw docs/superpowers/specs/2026-08-29-gpu-resident-render-backend-design.md STATUS.md
git commit -m "docs: Plan F's results -- the band measured, the triggers timed, and what the window showed"
```

---

## Exit gate

Pre-committed. Thresholds are not moved to make a criterion pass; a miss is
recorded as a miss with its number.

1. **Criterion 1 at the band's edges**, both corpora, both collection scales:
   `band_sweep_test.dart` green at `kBandLowerScale`, `1.0`,
   `kBandUpperScale` with `referenceInk > 5000`.
2. **Criterion 2:** the reported band (the intersection of the three printed
   runs) is in the note; `hi / lo ≥ 2` is PASS, below it is the design
   failure the spec names, recorded as one. The constants' final values are
   recorded with the row that set them, or "unchanged".
3. **The five triggers**, GPU-free: each of `CommandApplied`, `CommandUndone`,
   `CommandRedone`, `DocumentLoaded`, `DocumentPurged`, a table edit, a
   `devicePixelRatio` change and a band exit causes **exactly one** rebuild;
   a pan and a resize cause none (`draft_canvas_resident_test.dart`).
4. **Criterion 7:** median-of-three `total` ≤ **16.67 ms** for every one of
   the ten trigger rows on arm D, warm; the cold first rebuild reported
   beside. `classify` reported against 27.4 ms.
5. **Criterion 5:** the probe's `perFrame ≤ kAllocFixed + kAllocPerPatch × P`
   on arm D's pan phase, with the fifteen class lines; or UNEVALUABLE with
   the VM service's refusal quoted.
6. **Criterion 8 on the widget path:** arm D `≤ 1.2` build / `≤ 2.0` raster
   p50, median of three, on the criterion-8 corpus (fills and text); the
   C-to-D difference per phase reported.
7. **Criterion 9:** arm D p95 raster `≤ 3.0` on hold, pan, zoom; the
   band-exit `staleFrames` reported without a threshold.
8. **Criterion 10:** `draft_canvas_fallback_test.dart` green — both fallbacks,
   one report, no throw, no retry.
9. **Criterion 12:** `zoom_defect_test.dart` green — tiled `uncovered > 0`
   during the zoom-out gesture and one frame after, tiled `differing > 0` on
   the zoom-in settle's first frame, resident `uncovered == 0` and agreement
   `≥ 0.995` at every frame of both.
10. **Criterion 6 at a rebuilt scale:** `buffer` at the `band out` (2.5×)
    rebuild reported against 8 MB.
11. **All fourteen mutations fire**, each with pasted output; E-F1 recorded
    as equivalent with its green run.
12. **No shader or bundle change** (`git diff --stat main..HEAD --
    packages/jet_cad_2d_flutter/shaders packages/jet_cad_2d_flutter/assets`
    is empty).
13. **A human looks at the window** and reports Plan F's four checks — and
    Plan E's fifth, if looked at.
14. Every gate green in `packages/jet_cad_2d_flutter`, `packages/jet_cad_2d`
    and `apps/dev_harness_2d`.

---

## Self-review

**Spec coverage.** The trigger table: `DocChange` rows — Task 3 (`onChange`,
every subclass); the table revision — Tasks 2 and 3 (Ruling F4); the
`devicePixelRatio` — Tasks 2 and 3 (Ruling F12); the watermark exit — Tasks 2,
3, 7 (Ruling F1, F6). *"Collection covers the whole document"* — Task 1
(Ruling F2), with the pan-needs-no-trigger and resize-needs-no-trigger claims
as Task 3's two non-trigger assertions. *"A rebuild never runs on the frame
path … lands after settle"* — Ruling F3, Task 2's first test and M-F7;
*"that staleness is measured by criterion 9"* — `bandStaleFrames`, Task 8's
band-exit phase. The fallback sentence and criterion 10 — Ruling F5, Task 4.
Invariant 1's *"new mechanism"* and criterion 5 — Ruling F8, Task 8. Criterion
2 — Task 7 and Ruling F6. Criterion 7 — Task 8's trigger phase and Task 5's
grid. Criterion 12 — Task 7 and Ruling F13. Criterion 8 and 9 on the widget
path — Task 8's arm D. The five spec mutations — M-F1..M-F5; the declared
equivalent — E-F1. Open question 3 — Ruling F1, Task 10. **Not covered,
deliberately:** web (Plan G — criterion 13, open questions 2, 4, 5); R6-2
(parked, Ruling F10); the spec's "reference scale is a parameter" wording,
which Ruling F1 answers rather than implements.

**Placeholder scan.** No "TBD", no "handle edge cases", no "similar to Task
N". Two steps name a fallback for something the repository decides rather
than the plan: Task 7's `TileRig.dispose` (tear down the measurer and index
directly if the rig has none) and Task 8's `pubspec.lock` (skip it if
ignored). Task 7's Step 4 names all three outcomes of the band measurement
and what each changes.

**Type consistency.** `ResidentCollection.collect({document, painter, live,
devicePixelRatio, pixelsPerPaperMm, lineweightScale, measurer, textStyleOf,
bandLowerScale})` is called with that shape in Tasks 1, 2. `ResidentRebuilder({document,
painter, uploader, pixelsPerPaperMm, lineweightScale, measurer, textStyleOf,
bandLowerScale, bandUpperScale})` in Tasks 2, 3. `noteFrame(camera, viewport,
dpr, tablesRevision)` in Tasks 2, 3. `ResidentUploader = Future<ResidentFramePainter?>
Function(ResidentCollection, Size)` in Tasks 2, 3, 4 (`FakeUploader.call`
matches it). `RebuildTrigger.{initial, document, tables, devicePixelRatio,
band}` in Tasks 2, 3, 8. `collectionFrameFor(live, extents, {margin})` in
Tasks 1, 7. `classifyTextPatches(data, count, texts, {devicePixelRatio,
bandLowerScale, stats})` in Tasks 1 (without `stats`), 5. `patchRegionFor(t,
m, w, h, {maxWidth, maxHeight, scratch, out})` in Task 6 both sites.
`buildFrameInfo(m, w, h, {dashScale, out})` in Task 6 both sites.
`CompositedAgreement(union, withinTwo, overEight, referenceInk, patchCount,
uncovered)` in Task 7 both sites. `measureCompositedAgreement(doc,
{collectionCamera, collectionViewport, liveCamera, size, devicePixelRatio,
pixelsPerPaperMm, measurer, mutatePatches, minTextCapPixels})` in Task 7 both
sites. `fireDocumentTrigger(doc, name, {probe})` in Task 8 both sites.
`zoomedAbout(base, centre, s)` in Tasks 2, 3, 7. `DraftCanvas.debugResidentFallbackReports`
/ `debugResetResidentFallbackReport()` in Tasks 3, 4.
