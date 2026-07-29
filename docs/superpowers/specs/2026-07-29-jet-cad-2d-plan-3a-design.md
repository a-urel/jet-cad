# jet_cad_2d Plan 3a — Render Path Foundation and Measurement

**Status:** approved 2026-07-29, revised after review
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
descends the instance tree, a minimal `DraftCanvas` widget, and five measurement
rigs. Its deliverable is working code plus a numbers note.

**Plan 3b — designed later, from 3a's numbers — adds the caches** and the two
model gaps 3a cannot paper over: the definition picture cache, the tile cache,
the two invalidation channels, the text content model and its rendering, the
fill entity and its rendering, dashes, the paragraph layout cache, and the
frame-time gate.

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
invalidation channels, dashes, hatch and fill, the fill entity, **text content
and text rendering**, the paragraph layout cache, `InteractionTool`,
`SelectionController`, `DraftPermissions`, `overlayBuilder`, tool presets. Those
are Plans 3b and 4.

The 16.6 ms frame-time gate is **not** in 3a. That gate is meaningful only with
the caches active; asserting it against an uncached painter would either fail
uninformatively or pass on a document too small to mean anything.

## What Plan 2 shipped, and what it constrains

Eight facts from the merged code shape everything below. Each was read from the
source, and three of them contradicted this spec's first draft.

1. **`forEachInRect` visits root-level leaves only, ascending handle.** It does
   not descend into instances, deliberately
   ([`spatial_index.dart:256-263`](../../../packages/jet_cad_2d/lib/src/index/spatial_index.dart#L256-L263)).
   `forEachInstanceInRect` visits root-level instances, ascending handle.
2. **Neither rect query is reentrant, and they share scratch buffers.** Calling
   either from inside the other's `visit`, or mutating the document there,
   throws `QueryReentrancyError`. `_beginQuery` is called by `SpatialIndex`
   methods only, so `ContainerIndex` queries from inside a `visit` are legal —
   which is what makes painter recursion possible at all.
3. **"Root-level leaf" does not mean "coordinates in root space".** Group nodes
   are flattened into the enclosing container and each folded leaf's composed
   transform is stored in `_leafTransforms`, reachable through
   `ContainerIndex.transformOfLeaf(slot)`
   ([`container_index.dart:106`](../../../packages/jet_cad_2d/lib/src/index/container_index.dart#L106)).
   Identity is not stored, so the accessor returns null for the common leaf.
4. **`ContainerIndex.searchLeaves` is neither ordered nor deduplicated.** It
   visits the packed tree and then the dirty overlay, and a slot present in both
   is visited twice by design
   ([`container_index.dart:492-518`](../../../packages/jet_cad_2d/lib/src/index/container_index.dart#L492-L518)).
   `SpatialIndex.forEachInRect` sorts and the tree's dead marks deduplicate;
   a caller of `ContainerIndex` gets neither for free.
5. **There is no fill or hatch entity, and no text content.** `EntityKind` is
   `point, line, polyline, circle, arc, text, attrib`, but `EntityRecord` has no
   string, no per-entity text-style handle, no rotation and no alignment, and
   both `entityBounds` call sites pass `text: ''` with
   `ReservedHandles.standardTextStyle` hardcoded. A text entity today is an
   insertion point plus a height scalar. The `patterns` table exists with
   nothing to carry it.
6. **`TextMeasurer` is an injected seam with nothing to measure.** The interface
   and `InsertionPointMeasurer` exist and `DraftDocument` takes one, but with no
   stored string a real measurer returns exactly what the placeholder returns.
7. **`DocChange` carries no change kind** — only a label and a `touched` set —
   and `SpatialIndex` answers that by re-deriving and comparing rather than by
   being told
   ([`spatial_index.dart:2139-2161`](../../../packages/jet_cad_2d/lib/src/index/spatial_index.dart#L2139-L2161)).
   Any touched handle that resolves to a node or a definition is structural and
   triggers `rebuildAll()`.
8. **No command edits geometry in place.** The set is `AddEntityCommand`,
   `RemoveEntityCommand`, `AddNodeCommand`, `RemoveNodeCommand`,
   `TransformNodeCommand`, `SetComponentCommand`. Plan 2's own drag test spells
   a drag as remove-then-add per pointer sample, burning a handle and a slot
   each step
   ([`invalidation_test.dart:866-870`](../../../packages/jet_cad_2d/test/index/invalidation_test.dart#L866-L870)).

Facts 5 and 6 are why text leaves 3a. Fact 7 governs how the painter maintains
its owner map. Facts 7 and 8 together determine what the edit-simulation rigs
can actually measure.

## Package layout

New package `packages/jet_cad_2d_flutter`, depending on `jet_cad_2d`:

```
CameraController, ViewportTransform      camera and Float64 rebasing
DrawSink, CanvasDrawSink,                the paint seam
  RecordingDrawSink, NullDrawSink
DraftPainter                             the uncached walk
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
generate the same documents, or their numbers cannot be compared.
`benchmark/query_throughput.dart` is updated to import from the new location,
and re-running it with unchanged numbers is part of the move's acceptance.

Root `pubspec.yaml`'s `workspace:` list gains `packages/jet_cad_2d_flutter` and
`apps/dev_harness_2d`.

Harness app: `apps/dev_harness_2d`, targeting macOS and web. The existing
`dev_harness` depends on the 3D `jet_cad` package and is left alone.

## Camera and coordinate rebasing

`ViewportTransform` is a `Float64` affine carrying pan, zoom and optional
rotation, with `worldToScreen` / `screenToWorld` performed in `Float64`.
`CameraController` is a `ValueNotifier<ViewportTransform>`, so a camera change
repaints inside a `RepaintBoundary` without rebuilding the widget tree.

Every draw ends in exactly one residual matrix, composed in `Float64`:

- **Instances:** `camera ∘ ancestors ∘ instance ∘ rebase`. An instance transform
  is never pushed as an independent `canvas.transform` stacked on the camera: an
  instance placed near 4.5e6 carries that magnitude in its own `e`/`f`, and
  pushing it separately feeds the absolute coordinate back into the float32
  matrix, undoing the rebase.
- **Root-level leaves:** `camera ∘ leafTransform ∘ rebase`, where `leafTransform`
  is `ContainerIndex.transformOfLeaf(slot)` — the identity for a leaf owned
  directly by the container, and the folded group transform otherwise (fact 3).
  A painter that reads coordinates straight from `GeometryStore` and skips this
  draws every group-owned leaf in the wrong place.
- **The rebase origin** is one per frame: the camera's world centre snapped to a
  power-of-two world grid. The painter subtracts it in `Float64` before any
  coordinate reaches `Canvas`.

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

The delta is only meaningful on a corpus with more than one resolution path,
which is one of the generator extensions below.

## Render path

### The `DrawSink` seam

```dart
abstract class DrawSink {
  /// Pushes one composed residual. Every coordinate passed between this call
  /// and [endResidual] is expressed in that residual's local space — never in
  /// world coordinates, and never rebased twice.
  void beginResidual(Matrix4 residual);
  void endResidual();

  void point(double x, double y, ResolvedStyle style);
  void polyline(Float64List points, int count, ResolvedStyle style, {required bool closed});
  void circle(double cx, double cy, double r, ResolvedStyle style);
  void arc(double cx, double cy, double r, double start, double sweep, ResolvedStyle style);
}
```

Coordinates are residual-local, stated on the interface because
`RecordingDrawSink` equality is the primary correctness mechanism and an
ambiguous space makes two correct implementations disagree. `point` exists
because `EntityKind.point` does. There is no text operation in 3a.

Three implementations:

- `CanvasDrawSink` — production, writes to `ui.Canvas`.
- `RecordingDrawSink` — records ordered operations with their matrices and
  points. In 3b it is the surface the cached and uncached paths are compared
  on, without pixels.
- `NullDrawSink` — counts and discards, isolating query cost from paint cost.

The seam is deliberately thin. `ui.Canvas` is already an interface; the value
here is not abstraction but a deterministic, diffable record of what was drawn
in what order under what transform.

### Frame walk and draw order

Draw order is ascending handle, globally — a decision carried from Plan 2 and
not reopened. Two ordered streams must therefore be merged, and Plan 2's
non-reentrancy makes the naive interleaving illegal.

The painter:

1. Runs `forEachInstanceInRect`, copying handle values into its own
   preallocated `Uint32List`. The query completes before anything else runs.
2. Runs `forEachInRect` as a stream. Before drawing each leaf, it flushes every
   buffered instance whose handle is lower than that leaf's.
3. Flushes the remaining instances after the leaf stream ends.

`Uint32List`, not `Int32List`: handle values run to `kMaxHandle == 0xFFFFFFFF`.
Plan 2's `QueryScratch` backs handle values with an `Int32List`
([`query_scratch.dart:22`](../../../packages/jet_cad_2d/lib/src/index/query_scratch.dart#L22),
storing `node.value` at
[`spatial_index.dart:310`](../../../packages/jet_cad_2d/lib/src/index/spatial_index.dart#L310)),
which truncates above 2³¹. That is a pre-existing latent defect, not 3a's, and
is listed as a pre-task below rather than copied.

In 3a nothing is filled, so this ordering has no visible effect. It is
implemented now because 3b's fills make it visible, and because retrofitting
order into a painter means rewriting the painter.

### Recursion into instances

An instance is drawn by recursing into its definition's `ContainerIndex`. Four
mechanics follow from facts 2 and 4 and are requirements, not implementation
detail:

- **Only `ContainerIndex` calls are legal inside a `visit`.** Any
  `SpatialIndex`-level query from there throws `QueryReentrancyError`. The whole
  merge design above exists to stay on the legal side of this.
- **Sort and deduplicate per container.** `searchLeaves` visits tree order then
  the dirty overlay and may report a slot twice. The painter owns that, since
  `forEachInRect` does not do it at this level.
- **One scratch buffer per depth**, in the shape `SpatialIndex._scratchForDepth`
  already uses. A single shared buffer is wrong under recursion, so "the buffer
  grows once" becomes "each depth's buffer grows once".
- **Walk instances by index**, through `instanceHandleAt(i)` /
  `instanceTransformAt(i)`. `transformOfInstance(handle)` is
  `_instanceHandles.indexOf(node)`
  ([`container_index.dart:565-566`](../../../packages/jet_cad_2d/lib/src/index/container_index.dart#L565-L566)) —
  linear, and quadratic when called once per visible instance per frame.

### The owner map, and how it is maintained

The painter needs each definition's leaf slots. `DraftDocument.leavesByOwner()`
is a full live-slot scan that builds a fresh map (fact 7's neighbour at
[`draft_document.dart:198-206`](../../../packages/jet_cad_2d/lib/src/document/draft_document.dart#L198-L206)),
so it is a startup call, never a frame call, and rebuilding it on every
`DocChange` would make the edit rigs a measurement of that scan.

Maintenance follows `SpatialIndex._onChange`'s doctrine exactly, because
`DocChange` carries no change kind and cannot be asked:

- `DocumentLoaded` / `DocumentPurged` → full rebuild. Slots were renumbered.
- `CommandApplied` / `CommandUndone` / `CommandRedone` → for each touched
  handle, look up `entities.slotOf(handle)` and re-derive that slot's bucket
  membership from its current owner; a handle that resolves to neither an
  entity nor a node falls back to a full rebuild, matching `_reconcileEntity`'s
  conservatism.

A `TransformNodeCommand` touches a node handle, changes no leaf's owner, and
therefore costs the painter nothing. A drag spelled as remove-then-add (fact 8)
touches one entity handle per sample and costs one bucket update.

### Lineweight, pinned now because it changes the sink's contract

`Paint.strokeWidth` is in the current canvas's units, and the residual carries
camera zoom and instance scale. A paper-space width written straight into a
`Paint` under that transform grows with zoom and goes anisotropic under a
non-uniform instance — which the fixture rule below makes universal, not rare.

3a adopts the parent spec's rule one plan early, rather than inventing a
temporary one:

- Representative scale is `sqrt(|det residual|)`, and stroke width is the
  paper-space width divided by it.
- While the ratio of the residual's singular values stays within a declared
  threshold, that is the width used.
- **Beyond the threshold the instance takes the bypass path:** its points are
  transformed in `Float64` in Dart, the residual pushed is translation-only, and
  the width is exact. The parent spec already specifies this bypass for cached
  pictures; 3a is where it first has to exist.

The threshold's value is chosen in implementation and recorded in the results
note with the fraction of the corpus that takes the bypass.

### Two declared optimisms

3a's numbers are optimistic in two known ways, both quantified rather than
hidden:

- **No dashes.** Path splitting is a real, sized task and belongs with the
  caches that make it affordable. The results note records the fraction of the
  corpus carrying a non-continuous linetype — which requires the generator
  extension below, or the metric is zero by construction and measures nothing.
- **No text.** Text entities in the corpus are counted and skipped, and the
  count is recorded. Text is the product's payload, so 3b's re-measurement after
  the text model lands is not optional.

## Damage model

Repaint on events, never per vsync. 3a's triggers are `DocChange` and camera
change, wired as
`CustomPainter(repaint: Listenable.merge([camera, docChanges]))` inside a
`RepaintBoundary`. Selection, tool state, `documentRevision` and
`overrideChanges` are added by Plans 3b and 4.

## Corpus

The generator today is degenerate for three of the things 3a measures: every
instance is root-parented with a translation, or a translation composed with a
rotation at p = 0.15; nothing is mirrored or non-uniformly scaled; and every
entity is `layerZero` + `ByLayerColor` + `kByLayer` + `byLayerLinetype`, so
style resolution has exactly one path.

3a extends it. **Every extension arrives as a new parameter defaulting to off**,
so Plan 2's numbers are reproducible from the same file — re-running
`query_throughput.dart` with defaults and getting the recorded numbers back is
the acceptance test for the move and the extension together.

| Parameter | Why 3a needs it |
|---|---|
| nested instances (depth ≥ 2) | ancestor accumulation in the rebasing chain |
| mirrored and non-uniformly scaled instances | the anisotropy bypass, and the composition-order defect class |
| group nodes owning leaves | `transformOfLeaf` on the root-leaf path |
| multiple layers, and a mix of `ByLayer` / `ByBlock` / explicit color | more than one style-resolution path, without which the memo delta is meaningless |
| a non-continuous linetype fraction | the declared-optimism metric for dashes |

## Measurement

Five rigs, one shared harness library, each runnable by a single documented
command.

| Rig | What it measures | Where it runs |
|---|---|---|
| **R1 — paint microbench** | `PictureRecorder` + painter over N frames; p50/p95. **Debug JIT, and records without rasterising** — a relative regression signal only, never comparable to R2 and blind to the raster cost that justifies lineweight | `flutter test` |
| **R2 — frame timing** | Scripted camera timeline (pan, and zoom across scale bands) with `SchedulerBinding.addTimingsCallback`, reporting build and raster durations separately | `integration_test`, macOS, profile mode |
| **R3 — query-only** | The identical walk with `NullDrawSink`, separating index cost from paint cost | alongside R1 |
| **R4a — leaf edit** | A per-frame leaf move, spelled as `RemoveEntityCommand` + `AddEntityCommand` (fact 8), concurrent with pan. Records the frame timeline, `rebuildCount`, dirty-overlay length, and handle/slot consumption | alongside R2 |
| **R4b — instance drag** | A per-frame `TransformNodeCommand` on one instance, concurrent with pan | alongside R2 |

Documents: the shared generator at 50k and 500k entities, positioned near
4.5e6, with the nesting, mirroring and style extensions enabled.

R3 is not redundant with Plan 2's gate. That gate measured queries with an empty
`visit` callback; a painter does work inside the callback, and the painter's
`Paint` and style accesses evict exactly the cache lines the query walk warmed.
R3 shares R1's callback structure and changes only the sink, which makes it the
only measurement that can isolate that effect — subtracting two
separately-written benchmarks does not.

**Web smoke:** R1 and R2 run once on Chrome/CanvasKit. Informational, recorded,
not gating. CanvasKit is the most memory-constrained target and the one most
likely to constrain 3b's cache design; learning that before the cache is written
is cheap, and after is not.

**Allocation** is asserted structurally, following Plan 2: the painter's
per-depth buffers must not grow after warm-up, exposed through capacity getters
in the same shape as `entityScratchCapacity`. A GC heap delta is recorded
alongside as informational. The structural claim is platform-independent and
assertable in a test; the heap delta is neither.

### Why R4 is two rigs

The parent gate results left the dirty overlay's scaling open: `rebuildThreshold`
is `max(64, leafCount * 0.05)`, a fraction of document size, so the overlay's
per-query linear scan grows with the document and partly cancels the logarithmic
index in front of it. Four options were recorded (A: bound the threshold
absolutely; B: index the overlay; C: incremental rebuild; D: true incremental
insertion), and choosing between A and C needs to know whether a rebuild stall
is worse than the scan.

A single rig cannot produce that, because the two edit shapes take completely
different paths through `_reconcile` (fact 7):

- **R4a's leaf edit** touches an entity handle, dirties one slot, and fills the
  overlay. It produces the A-vs-C input: the cost of one 500k STR repack, how
  often an editing session crosses the threshold, and the overlay scan's share
  of frame time.
- **R4b's instance drag** touches a node handle, which `_reconcile` classifies
  as structural and answers with `rebuildAll()` — every frame, for the whole
  gesture. The overlay never fills, so this rig says nothing about A-vs-C. It
  measures something else that is currently unmeasured and product-central:
  moving a table is the application's defining gesture, and today it rebuilds
  the entire index per pointer sample.

Had R4 stayed one rig using `TransformNodeCommand`, it would have produced a
number that looked like an answer and was not.

The results note states the chosen overlay option and its justification. If the
data is genuinely ambiguous, the note names the single additional measurement
that resolves it — a named next step, not a deferral. R4b's number is recorded
whatever it says, and if it is bad enough to constrain Plan 4's move tool, that
is stated in the note rather than left for Plan 4 to discover.

## Testing

Plan 2's evidence governs: defects surfaced through differential and mutation
testing, not through reading, and the dominant defect class was a fixture that
could not tell right from wrong. The identity transform hid one composition-order
bug four times.

### The differential oracle

A reference walk sits beside the painter: it traverses the document tree
directly, uses no spatial index, performs no culling, and filters to the visible
rectangle afterwards. It writes to the same `RecordingDrawSink`.

The two recordings are compared as **painter ⊇ reference**, not as equality. The
painter culls against index boxes in container space, which carry slack; the
reference culls against entity bounds in root space. Requiring equality would
report a spurious failure for every rotated instance whose box is looser than
its geometry. The assertions are therefore:

1. every operation the reference produced appears in the painter's recording,
2. with identical geometry to within tolerance and identical residual-local
   coordinates,
3. in the same relative order,
4. and every extra operation in the painter's recording lies outside the view
   rectangle — conservative culling, never a wrong drawing.

That covers wrong culling, wrong merge order and wrong transform composition in
one comparison, because the reference accumulates transforms by a different
route than the painter does.

### Fixture rule

No fixture may contain an identity transform. Every instance carries a distinct
non-uniform scale, a rotation and a translation; at least one is mirrored
(negative scale); at least one is nested two levels deep; at least one leaf is
owned by a group node, so `transformOfLeaf` is exercised on the root-leaf path.
The rebasing chain has the same shape as the composition bug Plan 2 kept hiding,
and a fixture that cannot distinguish orderings will hide it again.

### Large coordinates

A fixture near 4.5e6 containing a nested instance placed there. Two assertions:
the residual matrix reaching `Canvas` has small magnitudes, and the recorded
points, transformed back by that residual, reproduce the world coordinates
within tolerance. A fixture near the origin cannot catch this class.

This also answers Plan 2's Phase 0 question about float32 jitter: an additional
recording taken with rebasing disabled documents what the failure looks like, so
the assertion has something real behind it.

### Mutation testing

Applied to the camera and rebasing arithmetic, the merge ordering, the
per-container sort and deduplication, and style resolution.

### Goldens, deliberately few

A small number of pixel goldens, macOS-tagged, covering stroke width and the
anisotropy bypass — the two places where the operation record cannot show
whether the result is visually right. Correctness otherwise rests on the
operation record, which does not depend on platform rasterisation.

## Pre-task

`QueryScratch` stores handle values in an `Int32List` while `kMaxHandle` is
`0xFFFFFFFF`, so a document whose handles pass 2³¹ sorts them as negative
numbers and then throws `HandleRangeError` when `forEachInstanceInRect`
reconstructs the `Handle`. No shipped test reaches that range, so it is latent
rather than observed. It is a one-line fix plus a regression test, it is in the
code path 3a's painter consumes directly, and 3a is where someone is looking at
it. Fixed as a standalone commit before the package work starts.

## Exit criteria

Two rows can fail:

| Criterion | Verdict if missed |
|---|---|
| The differential oracle's four assertions hold on the large-coordinate, nested, mirrored, group-owning corpus | **fail** — the rebasing or ordering design is wrong and 3b cannot start |
| Per-depth painter buffers do not grow after warm-up | **fail** — the frame path allocates, breaching the budget Plan 2 established |

Frame timings in 3a are **baselines, not thresholds**. The 16.6 ms gate belongs
to 3b.

Delivery also requires: the package merged with the full suite green, analyzer
and formatter clean; `query_throughput.dart` re-run after the generator move and
reporting its recorded numbers; all five rigs runnable by a documented single
command; and a results note at
`docs/superpowers/notes/<completion-date>-plan-3a-results.md` containing the
numbers table, the anisotropy-bypass fraction, the skipped-text count, the
non-continuous-linetype fraction, the web smoke figures, R4b's per-frame rebuild
cost, and the chosen dirty-overlay option with its justification.

## Carried to Plan 3b

- Definition picture cache keyed by `(definition, StyleContext, scaleBand, documentRevision)`, the tile cache, and the per-definition entry bounds that go with them.
- `documentRevision` and `overrideChanges` as separate invalidation channels, plus the runtime-override isolation test that can finally observe them.
- **The text content model**, as an engine task sequenced before the rendering that consumes it: stored string, per-entity text-style handle, rotation, DXF 72/73 alignment, codec support, commands, and the `TextMeasurer` signature those imply — after which `FlutterTextMeasurer`, text rendering, the paragraph layout cache, mirrored-text fidelity and the measurer-dependence test all become writable. Today a real measurer and `InsertionPointMeasurer` return the same answer, so none of them can be written.
- **The fill entity**, on the same footing: a new `EntityKind`, its geometry payload, the boundary↔fill association, codec support, commands and inverses, index bounds and `HitKind.fill` — then hatch and pattern rendering. The parent spec assigns "fills/patterns" to Plan 3 without noting that the model has nowhere to put one.
- Dashes and the linetype-scale chain.
- The end-of-Plan-3 frame-time gate, unchanged from the parent spec.

## Carried to Plan 4

An in-place geometry edit command. Today a drag is remove-then-add per pointer
sample, consuming a handle and leaving a dead slot each step, which is what
R4a has to simulate. Whether that is acceptable for a real move tool is Plan 4's
decision, informed by R4a's and R4b's numbers.

## Risks

| Risk | Where it is addressed |
|---|---|
| The uncached painter is so far from budget that caches plausibly cannot close the gap | 3a's R1/R2 numbers; if so, the render design reopens before 3b is written, which is the point of the split |
| 3a's numbers read as representative when text and dashes are both absent | Both declared as optimisms with a recorded magnitude; 3b re-measures the same rows |
| `DrawSink` grows into a second `Canvas` as dashes, hatches and paragraphs arrive | The seam stays minimal in 3a; 3b re-evaluates it against the caches rather than extending it by default |
| Recording-based tests drift from what is actually rasterised | The few macOS goldens exist for exactly this, and R2 measures the real raster thread rather than the recorder |
| CanvasKit memory behaviour invalidates the cache design | Web smoke in 3a, before 3b commits to cache sizing |
| The generator extensions change Plan 2's measured numbers | Every extension is off by default; `query_throughput.dart` re-run with defaults is part of acceptance |
| R4b reveals that the product's central gesture is unaffordable at scale | Measured in 3a rather than discovered in Plan 4; the note states the constraint explicitly |
