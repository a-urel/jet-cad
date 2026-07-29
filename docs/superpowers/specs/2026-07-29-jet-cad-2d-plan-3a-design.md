# jet_cad_2d Plan 3a — Render Path Foundation and Measurement

**Status:** approved 2026-07-29
**Parent:** [2026-07-27-jet-cad-2d-architecture-design.md](2026-07-27-jet-cad-2d-architecture-design.md)
**Predecessor:** Plan 2 (spatial index, queries, hit-testing, snapping) — merged at `3ba8fcd`, 599 tests, 0 skipped
**Carried in:** [2026-07-28-plan-2-gate-results.md](../notes/2026-07-28-plan-2-gate-results.md)

## Summary

The parent spec's Plan 3 is one plan containing at least four different kinds of
work: a camera and coordinate system, a style-resolution contract, two picture
caches, text, fills and dashes, a damage model, a widget, and a frame-time gate.
It is split in two.

**Plan 3a — this spec — builds the render path without any cache, and measures
it.** It creates `packages/jet_cad_2d_flutter`, the camera and `Float64`
rebasing chain, style resolution in the pure engine, an uncached painter that
descends the instance tree and draws text, a minimal `DraftCanvas` widget, and
four measurement rigs. Its deliverable is working code plus a numbers note.

**Plan 3b — designed later, from 3a's numbers — adds the caches**: the
definition picture cache, the tile cache, the two invalidation channels, the
paragraph layout cache, dashes, lineweight policy refinement, the fill entity
and its rendering, and the frame-time gate.

Three reasons for the split, in order of weight:

1. The parent spec's Plan 3 contains two decisions that cannot be made without
   measurement — which dirty-overlay option to take, and whether the cache
   design survives contact with real frame timing. A plan that must be rewritten
   halfway through is two plans wearing one name.
2. An uncached painter is not scaffolding to be discarded. It is the
   **differential oracle** the cached painter is tested against, in the same
   role brute-force queries played in Plan 2.
3. Plan 2's Phase 0 spike never ran, because it required a human to run an app
   and read a DevTools overlay. 3a converts that requirement into a repeatable
   harness, which is why it is expected to actually happen.

3a supersedes Plan 2's Phase 0 spike and absorbs both of its questions.

## Non-goals

Definition picture cache, tile cache, `documentRevision` / `overrideChanges`
invalidation channels, paragraph layout cache, dashes, hatch and fill, the fill
entity itself, `InteractionTool`, `SelectionController`, `DraftPermissions`,
`overlayBuilder`, tool presets. Those are Plans 3b and 4.

The 16.6 ms frame-time gate is **not** in 3a. That gate is meaningful only with
the caches active; asserting it against an uncached painter would either fail
uninformatively or pass on a document too small to mean anything.

## What Plan 2 shipped, and what it constrains

Six facts from the merged code shape everything below.

1. **`forEachInRect` visits root-level leaves only, ascending handle.** It does
   not descend into instances, deliberately
   ([`spatial_index.dart:256-263`](../../../packages/jet_cad_2d/lib/src/index/spatial_index.dart#L256-L263)).
   `forEachInstanceInRect` visits root-level instances, ascending handle.
2. **Neither rect query is reentrant, and they share scratch buffers.** Calling
   either from inside the other's `visit`, or mutating the document there,
   throws `QueryReentrancyError`. A caller cannot hold one query's results
   across the other's execution.
3. **There is no fill or hatch entity.** `EntityKind` is
   `point, line, polyline, circle, arc, text, attrib`. The `patterns` table and
   `PatternLine` exist; nothing carries them.
4. **`TextMeasurer` is already an injected seam** on `DraftDocument`, with
   `InsertionPointMeasurer` as the engine's deliberate lower bound. The Flutter
   layer supplies the real implementation; the engine does not change.
5. **Leaf containment is `EntityRecord.owner`.** `DraftDocument.leavesByOwner()`
   is a full entity-store scan and is not a frame-path call.
6. **`FilterEvaluator` memoises layer visibility and its `invalidate()` has no
   caller today**, because no command changes layer or node visibility
   ([`query_filter.dart:44-53`](../../../packages/jet_cad_2d/lib/src/index/query_filter.dart#L44-L53)).
   That is a fact about today's command set, not a guarantee. Style resolution
   has exactly the same shape and must not create the same debt in 3a.

## Package layout

New package `packages/jet_cad_2d_flutter`, depending on `jet_cad_2d`:

```
CameraController, ViewportTransform      camera and Float64 rebasing
DrawSink, CanvasDrawSink,                the paint seam
  RecordingDrawSink, NullDrawSink
DraftPainter                             the uncached walk
FlutterTextMeasurer                      ui.ParagraphBuilder implementation of TextMeasurer
DraftCanvas                              minimal widget: camera + painting only, no tools;
                                         the same class Plan 4 extends, not a placeholder name
paintStyle(ResolvedStyle) -> ui.Paint    the only place appearance meets dart:ui
```

`StyleContext`, `ResolvedStyle` and `StyleResolver` go in the **pure**
`jet_cad_2d` package, not the Flutter one. They express DXF semantics — ACI
indices, `BYLAYER`/`BYBLOCK`, transparency 0–255, lineweight in 1/100 mm — and
need no `dart:ui`. Export and engine-side tests will need them without Flutter.
The Flutter package owns only the mapping from `ResolvedStyle` to `ui.Paint`.

The corpus generator moves from `packages/jet_cad_2d/benchmark/generate_document.dart`
to `packages/jet_cad_2d/lib/src/testing/generate_document.dart`, exported from a
separate `package:jet_cad_2d/testing.dart` entry point and **not** from the main
`jet_cad_2d.dart` surface. Plan 2's query benchmark and 3a's render rigs must
generate the same documents, or their numbers cannot be compared. The existing
`benchmark/query_throughput.dart` is updated to import it from the new location;
its measured numbers must not change.

Harness app: `apps/dev_harness_2d`, targeting macOS and web. The existing
`dev_harness` depends on the 3D `jet_cad` package and is left alone.

## Camera and coordinate rebasing

`ViewportTransform` is a `Float64` affine carrying pan, zoom and optional
rotation, with `worldToScreen` / `screenToWorld` performed in `Float64`.
`CameraController` is a `ValueNotifier<ViewportTransform>`, so a camera change
repaints inside a `RepaintBoundary` without rebuilding the widget tree.

Two rebasing paths, both ending in exactly one residual matrix per draw:

- **Instances.** `camera ∘ ancestors ∘ instance ∘ rebase` is multiplied out in
  `Float64` and the small-magnitude result is pushed. An instance transform is
  never pushed as an independent `canvas.transform` stacked on the camera: an
  instance placed near 4.5e6 carries that magnitude in its own `e`/`f`, and
  pushing it separately feeds the absolute coordinate back into the float32
  matrix, undoing the rebase.
- **Root-level leaves.** One rebase origin per frame: the camera's world centre
  snapped to a power-of-two world grid. The painter reads point coordinates from
  `GeometryStore` in `Float64`, subtracts the origin in Dart, and hands small
  numbers to `Canvas`.

The grid snap is load-bearing. An origin that moves continuously with the camera
changes the float32 residual differently on every frame, producing jitter during
pan that a static golden cannot observe.

The per-point subtraction is a real per-frame cost, and measuring it is a
purpose of 3a: in 3b the tile cache performs it once at record time, and the
size of that win is unknown until 3a reports the uncached number.

## Style resolution

`StyleContext` carries the parent spec's fields — resolved color, linetype,
linetype scale, lineweight, transparency, inherited layer — with value equality
and a stable `hashCode`. It is a cache key in 3b, so its contract is fixed now
even though nothing caches on it yet.

3a implements two members of `StyleResolver`:

```dart
StyleContext contextFor(Handle instance, StyleContext inherited);
ResolvedStyle styleFor(Handle entity, StyleContext ctx);
```

Resolution order: the entity's own value → if `ByBlock`, the `StyleContext` →
if `ByLayer`, the layer record → default. The layer-0 rule and two levels of
nesting are resolved and tested in 3a.

`documentRevision`, `overriddenInstances` and `overrideChanges` are **not** in
3a. Their correctness is a statement about what gets invalidated, and nothing
can observe invalidation until a cache exists. Adding them now would produce
code no test can hold to account.

Resolution is **not memoised initially**. The unmemoised cost is measured first,
then a memo is added and the difference recorded. Done in the other order, the
memo's value is never known and 3b inherits an assumption instead of a number.
This also keeps `FilterEvaluator`'s invalidation debt from being duplicated in
3a; 3b introduces layer-editing commands and pays it once, deliberately.

## Render path

### The `DrawSink` seam

```dart
abstract class DrawSink {
  void beginResidual(Matrix4 residual);
  void endResidual();
  void polyline(Float64List points, int count, ResolvedStyle style, {bool closed});
  void circle(double cx, double cy, double r, ResolvedStyle style);
  void arc(double cx, double cy, double r, double start, double sweep, ResolvedStyle style);
  void text(TextRun run, Matrix4 residual, ResolvedStyle style);
}
```

Three implementations:

- `CanvasDrawSink` — production, writes to `ui.Canvas`.
- `RecordingDrawSink` — records ordered operations with their matrices and
  points. The primary correctness mechanism, and in 3b the surface the cached
  and uncached paths are compared on, without pixels.
- `NullDrawSink` — counts and discards, isolating query cost from paint cost.

`TextRun` is the painter's resolved text payload — the string, its
`TextStyleRecord` handle, resolved height, width factor, oblique angle,
rotation and alignment — assembled once per text entity so the sink implementations
share one representation.

The seam is deliberately thin. `ui.Canvas` is already an interface; the value
here is not abstraction but a deterministic, diffable record of what was drawn
in what order under what transform.

### Frame walk and draw order

Draw order is ascending handle, globally — a decision carried from Plan 2 and
not reopened. Two ordered streams must therefore be merged, and Plan 2's
non-reentrancy makes the naive interleaving illegal.

The painter:

1. Runs `forEachInstanceInRect`, copying handles into its own preallocated
   `Uint32List`. The query completes before anything else runs.
2. Runs `forEachInRect` as a stream. Before drawing each leaf, it flushes every
   buffered instance whose handle is lower than that leaf's.
3. Flushes the remaining instances after the leaf stream ends.

The buffer is owned by the painter and grows once; steady state allocates
nothing.

In 3a nothing is filled, so this ordering has no visible effect. It is
implemented now because 3b's fills make it visible, and because retrofitting
order into a painter means rewriting the painter.

### Instance contents

The painter keeps a definition → leaf-slot map, built once from
`DraftDocument.leavesByOwner()` and rebuilt on `DocChange`. Nested instances are
reached by painter recursion. `SpatialIndex.indexFor(container)` provides
per-container culling when a definition is large enough to be worth culling
inside.

### Text

`FlutterTextMeasurer` implements the engine's `TextMeasurer` with
`ui.ParagraphBuilder`, so document extents and text hit-testing use real
metrics. The painter draws text with no layout cache: width factor as a
horizontal scale, oblique as a skew, DXF 72/73 alignment, and — per the parent
spec — mirrored blocks rendered faithfully mirrored.

The absence of a layout cache is intentional. 3b's cache can only be justified
against the uncached number.

### Lineweight, and one declared optimism

Lineweight is resolved to device pixels through an explicit paper-space policy;
it does not grow with zoom. It is in 3a because stroke width materially affects
raster cost.

Dashes are **not** in 3a. Path splitting is a real, sized task, and it belongs
with the caches that make it affordable. This makes 3a's numbers optimistic for
line-heavy drawings. The results note therefore records what fraction of the
corpus carries a non-continuous linetype, and 3b re-measures the same rows with
dashes on. The optimism is quantified rather than hidden.

## Damage model

Repaint on events, never per vsync. 3a's triggers are `DocChange` and camera
change, wired as
`CustomPainter(repaint: Listenable.merge([camera, docChanges]))` inside a
`RepaintBoundary`. Selection, tool state, `documentRevision` and
`overrideChanges` are added by Plans 3b and 4.

## Measurement

Four rigs, one shared harness library, each runnable by a single documented
command.

| Rig | What it measures | Where it runs |
|---|---|---|
| **R1 — paint microbench** | `PictureRecorder` + painter over N frames; p50/p95. Deterministic, CI-suitable, catches regressions | `flutter test` |
| **R2 — frame timing** | Scripted camera timeline (pan, and zoom across scale bands) with `SchedulerBinding.addTimingsCallback`, reporting build and raster durations separately | `integration_test`, macOS, profile mode |
| **R3 — query-only** | The identical walk with `NullDrawSink`, separating index cost from paint cost | alongside R1 |
| **R4 — edit simulation** | A command-level out-and-back drag issuing `TransformNodeCommand` per frame, concurrent with pan; records the frame timeline, `rebuildCount`, and dirty-overlay size | alongside R2 |

Documents: the shared generator at 50k and 500k entities, positioned near
4.5e6, including nested and mirrored instances.

R3 is not redundant with Plan 2's gate. That gate measured queries with an empty
`visit` callback; a painter does work inside the callback, and the painter's
`Paint`, style and paragraph accesses evict exactly the cache lines the query
walk warmed. R3 shares R1's callback structure and changes only the sink, which
makes it the only measurement that can isolate that effect — subtracting two
separately-written benchmarks does not.

**Web smoke:** R1 and R2 run once on Chrome/CanvasKit. Informational, recorded,
not gating. CanvasKit is the most memory-constrained target and the one most
likely to constrain 3b's cache design; learning that before the cache is written
is cheap, and after is not.

**Allocation** is asserted structurally, following Plan 2: the painter's buffers
must not grow after warm-up, exposed through capacity getters in the same shape
as `entityScratchCapacity`. A GC heap delta is recorded alongside as
informational. The structural claim is platform-independent and assertable in a
test; the heap delta is neither.

### What R4 exists to decide

The dirty overlay's `rebuildThreshold` is `max(64, leafCount * 0.05)` — a
fraction of document size, so the overlay's per-query linear scan grows with the
document and partly cancels the logarithmic index in front of it. Plan 2's gate
results accepted this deliberately and recorded four options (A: bound the
threshold absolutely; B: index the overlay; C: incremental rebuild; D: true
incremental insertion), noting that choosing between A and C requires knowing
whether a rebuild stall is worse than the scan.

R4 produces exactly those three numbers:

1. the cost in milliseconds of one 500k STR repack — the stall option A buys,
2. how often an editing session crosses the threshold,
3. the overlay scan's share of frame time.

The results note states the chosen option and its justification. If the data is
genuinely ambiguous, the note names the single additional measurement that
resolves it — a named next step, not a deferral.

## Testing

Plan 2's evidence governs: defects surfaced through differential and mutation
testing, not through reading, and the dominant defect class was a fixture that
could not tell right from wrong. The identity transform hid one composition-order
bug four times.

### The differential oracle

A reference walk sits beside the painter: it traverses the document tree
directly, uses no spatial index, performs no culling, and filters to the visible
rectangle afterwards. It writes to the same `RecordingDrawSink`. The two
recordings must be equal.

One comparison covers three defect classes at once — wrong culling, wrong merge
order, and wrong transform composition — because the reference accumulates
transforms by a different route than the painter does.

### Fixture rule

No fixture may contain an identity transform. Every instance carries a distinct
non-uniform scale, a rotation and a translation; at least one is mirrored
(negative scale); at least one is nested two levels deep. The rebasing chain has
the same shape as the composition bug Plan 2 kept hiding, and a fixture that
cannot distinguish orderings will hide it again.

### Large coordinates

A fixture near 4.5e6 containing a nested instance placed there. Two assertions:
the residual matrix reaching `Canvas` has small magnitudes, and the recorded
points, transformed back by that residual, reproduce the world coordinates
within tolerance. A fixture near the origin cannot catch this class.

This also answers Plan 2's Phase 0 question about float32 jitter: an
additional recording taken with rebasing disabled documents what the failure
looks like, so the assertion has something real behind it.

### Mutation testing

Applied to the camera and rebasing arithmetic, the merge ordering, and style
resolution.

### Goldens, deliberately few

A small number of pixel goldens, macOS-tagged, covering text rendering
plausibility only. Correctness rests on the operation record, which does not
depend on font stacks or platform rasterisation.

### Measurer dependence

The same document measured with `InsertionPointMeasurer` and
`FlutterTextMeasurer` produces different extents. This is the contract, not a
defect; a test states it explicitly so that no later reader treats extents as
measurer-independent.

## Exit criteria

Two rows can fail:

| Criterion | Verdict if missed |
|---|---|
| Differential oracle agrees with the painter on the large-coordinate, nested, mirrored corpus | **fail** — the rebasing or ordering design is wrong and 3b cannot start |
| Painter buffers do not grow after warm-up | **fail** — the frame path allocates, breaching the budget Plan 2 established |

Frame timings in 3a are **baselines, not thresholds**. The 16.6 ms gate belongs
to 3b.

Delivery also requires: the package merged with the full suite green, analyzer
and formatter clean; all four rigs runnable by a documented single command; and
a results note at `docs/superpowers/notes/<completion-date>-plan-3a-results.md`,
dated on the day it is written, containing the numbers table, the non-continuous-linetype fraction, the web
smoke figures, and the chosen dirty-overlay option with its justification.

## Carried to Plan 3b

- Definition picture cache keyed by `(definition, StyleContext, scaleBand, documentRevision)`, the tile cache, and the anisotropy and per-definition entry bounds that go with them.
- `documentRevision` and `overrideChanges` as separate invalidation channels, plus the runtime-override isolation test that can finally observe them.
- Paragraph layout cache; dashes; hatch and pattern rendering.
- **The fill entity itself**, as a distinct engine-model task inside 3b, sequenced before the rendering that consumes it: a new `EntityKind`, its geometry payload, the boundary↔fill association, codec support, commands and inverses, index bounds and `HitKind.fill`. The parent spec assigns "fills/patterns" to Plan 3 without noting that the model has nowhere to put one.
- The end-of-Plan-3 frame-time gate, unchanged from the parent spec.

## Risks

| Risk | Where it is addressed |
|---|---|
| The uncached painter is so far from budget that caches plausibly cannot close the gap | 3a's R1/R2 numbers; if so, the render design reopens before 3b is written, which is the point of the split |
| `DrawSink` grows into a second `Canvas` as dashes, hatches and paragraphs arrive | The seam stays minimal in 3a; 3b re-evaluates it against the caches rather than extending it by default |
| Recording-based tests drift from what is actually rasterised | The few macOS goldens exist for exactly this, and R2 measures the real raster thread rather than the recorder |
| CanvasKit memory behaviour invalidates the cache design | Web smoke in 3a, before 3b commits to cache sizing |
| The corpus generator move changes Plan 2's measured numbers | `query_throughput.dart` re-run after the move; unchanged numbers are part of the move's acceptance |
