# jet_cad_2d Plan 3 — Rendering

**Status:** approved 2026-08-17
**Parent:** [2026-07-27-jet-cad-2d-architecture-design.md](2026-07-27-jet-cad-2d-architecture-design.md)
**Predecessors:** Plan 1 (core document model) and Plan 2 (spatial index, queries,
validation) — both merged, 599 tests, 0 skipped
**Gate results carried in:** [2026-07-28-plan-2-gate-results.md](../notes/2026-07-28-plan-2-gate-results.md)

## Summary

Plan 3 makes the engine draw. Nothing in the repository renders today: there is
no `Canvas` call, no widget, no Flutter dependency anywhere in
`packages/jet_cad_2d`.

The work is delivered as **three plans, one spec**:

| Plan | Scope | Gate |
|---|---|---|
| **Spike** | `apps/frame_bench` plus a throwaway painter — four variants, three scenarios, two dirty-overlay configurations | none; it produces a decision table |
| **3a** | camera and rebasing, `StyleResolver`, definition and tile caches, damage model, `DraftCanvas`, geometry, dashes, lineweight, text (model columns, Flutter measurer, layout cache) | **binding** 50k frame-time gate |
| **3b** | fill/hatch entity (model, codec, command) and pattern geometry generation | its own gate row |

This spec defines the spike **completely** and 3a **conditionally**: every row of
the spike's decision table names, in advance, which 3a task it switches on or
off. 3b is a sketch, because its plan is written after 3a's gate has run.

The split exists because the parent spec's `Plan 3 owns all of the above`
sentence, read literally, makes Plan 3 extend Plan 1's document model — new
columns, a new entity kind, a JSON schema change, new commands. That is not
render work, and putting it in front of the frame-time gate delays the one
measurement that can still send the architecture back.

## Non-goals

`InteractionTool`, `SelectionController`, `DraftPermissions` enforcement,
`ViewportTransform` and `overlayBuilder` as a public surface, the geometric tool
set, and the `DraftViewer`/`DraftDesigner` presets are Plan 4. `DraftCanvas`
here paints and hosts a camera; it does not host tools.

Polyline offset and polygon boolean stay deferred. `ImageFill` rendering is
declared out of scope in 3b, with a defined degradation.

Format work (DXF, IFC) is untouched.

## What Plans 1 and 2 actually shipped, and what it constrains

Seven facts, each read out of the delivered code. They are stated here because
three of them contradict what a reader would assume from the parent spec, and
two of them change this design.

**1. Text content is not stored anywhere.** `EntityRecord`'s fields are
`handle, owner, kind, layer, linetype, linetypeScale, geomIndex, color,
lineweight, transparency, flags` (`entity_store.dart:53-65`). There is no string
column, no per-entity `textStyle` handle, and no rotation, alignment, width
factor or oblique angle. `DraftDocument._boundsOfContainer` calls `entityBounds`
without a `text` argument — so the default `''` — and with a hard-coded
`ReservedHandles.standardTextStyle` (`draft_document.dart:226-231`). The parent
spec's list of text attributes was never written. **3a adds it.**

**2. `InstanceNode` carries only two of `StyleContext`'s six fields.** It has
`definition, layer, color, transform, visible` (`node.dart:153-173`). `linetype`,
`linetypeScale`, `lineweight` and `transparency` do not exist on it. Since
`StyleContext` is the picture-cache key, adding fields to it later would change
the key, its `hashCode`, and every test keyed on it. **3a adds the four
fields.**

**3. There is no fill or hatch entity.** `EntityKind` is
`point, line, polyline, circle, arc, text, attrib` (`entity_store.dart:9`).
`PatternRecord` and `PatternLine` exist and round-trip through the codec
(`tables.dart:285-375`, `tables.dart:475`), but no entity references them.
**3b adds the entity; 3a does not touch fills.**

**4. Dashes and lineweight need no model work.** `linetype`, `linetypeScale` and
`lineweight` are already `EntityRecord` columns, and `LinetypeRecord.pattern` is
a `DashPattern` in paper units with a `totalLength` (`tables.dart:142-209`).
Dash and lineweight are pure render work. This asymmetry with fills is what sets
the 3a/3b seam.

**5. ATTRIB entities are already indexed, and correctly.**
`ContainerIndex.build` visits `leavesByOwner[child]` when it reaches an instance
node and adds those leaves to the **root** leaf tree under the instance's
`composed` transform (`container_index.dart:208-210`), keeping the transform in
`_leafTransforms` and exposing it as `transformOfLeaf(slot)`
(`container_index.dart:590`). So `forEachInRect` already returns attrib slots, at
the right place, with their transform available. The renderer must **never** call
`ConvenienceQueries.attributesOf`, which is a full entity-store scan and says so
(`convenience_queries.dart:106-113`).

**6. `onAfterMutate` is single-owner and `SpatialIndex` holds it.** It is a
field, not a list, assigned in `SpatialIndex`'s constructor
(`spatial_index.dart:138`). The renderer therefore subscribes to
`document.changes`, the async broadcast stream. That is correct rather than
merely tolerable: the renderer sees a change one microtask later, by which time
the index is already up to date, and damage is per-event anyway.

**7. `forEachInRect` is root-level only and the rect queries are not
reentrant.** It walks `rootIndex` (`spatial_index.dart:270-292`), so definition
contents are reached through `indexFor(definition)`, not through it. Both rect
queries share the index's scratch buffers and throw `QueryReentrancyError` on
nested use (`spatial_index.dart:298-320`).

Two further facts, recorded because they are traps rather than constraints:

**`GeometryPayload.transformedBy` copies `scalars` verbatim** and takes no
`EntityKind` (`geometry_store.dart:32-42`); a test pins the behaviour as "moves
points and leaves scalars alone" (`geometry_store_test.dart:45`). A scaled circle
keeps its radius; a rotated text keeps its rotation. No call site in `lib`
applies it to a payload today, so this is latent, not broken. See
[Text rotation](#text-rotation-stays-in-scalars).

**`FilterEvaluator.invalidate` has no caller**, because no command can currently
change a layer's or a node's visibility or lock state (`query_filter.dart`, the
class doc comment). Any Plan 3 code that mutates a layer record must call it.

## Decisions carried in, not to be relitigated

- **Draw order is ascending handle value**, stable across undo, save, load and
  purge. Every query returns in that order.
- **The frame path allocates nothing.** `forEachInRect`,
  `forEachInstanceInRect`, `pickInto` and `snapInto` are allocation-free in
  steady state and a harness measures it. The renderer may not spend that budget
  back.
- **Leaf containment is `EntityRecord.owner`, only that.**
- Geometric *decisions* use `Tolerance`; *stored value* comparisons are exact
  `==`.
- The package split is `jet_cad_2d` (pure Dart) / `jet_cad_2d_flutter`
  (`Canvas`, widgets).

## Phase S — the rendering spike

Plan 2 defined this spike and never started it, because it needs a human to run
an application. It is the first work of Plan 3.

### Where it lives

A new `apps/frame_bench`, a workspace member, `publish_to: none`, depending on
`flutter` and `jet_cad_2d` (path). It does **not** depend on `jet_cad`, the 3D
package: that would pull in an OCCT native build and blur the pure-Dart
boundary. `apps/dev_harness` is left alone.

### What is throwaway and what is not

- **Durable** — this is what runs 3a's gate: `FrameRecorder`
  (`addTimingsCallback`, build and raster histograms kept **separately**), the
  fixture loader, the scenario drivers, the table writer (markdown to stdout),
  and the CLI flags.
- **Throwaway**: `SpikePainter`, a crude `CustomPainter` behind variant flags.

In 3a the painter is deleted and the real renderer is attached to the same
`FrameRecorder`. Spike numbers and gate numbers are therefore produced by the
same measurement code and are comparable.

### Fixtures

`benchmark/generate_document.dart` is reused unchanged: `generateDocument(50000)`
and `generateDocument(500000)`, `originX = 4.5e6`, same seeds as the Plan 2 gate.
No new fixture is written.

### Variants

Cumulative flags over one sweep:

| Variant | Adds | Measures |
|---|---|---|
| V1 | `forEachInRect` plus direct `Canvas` calls, one `Paint` | the baseline and the worst case |
| V2 | a definition picture cache (one `StyleContext`, one `scaleBand`) | what caching buys |
| V3 | a `Paragraph` per text entity, no cache, synthetic strings | the upper bound on paragraph layout |
| V4 | hand-written dash path splitting | what dashes cost per frame |

V3 needs no model change: text entities already exist in the fixture with an
insertion point and a height scalar, and the spike synthesises a string per
entity from its handle. What is being measured — how many layouts per frame and
how long they take — depends on the count and length distribution, not on the
content.

### Scenarios

All three are frame-index driven and seeded, never wall-clock driven, so two
runs follow the same path:

1. `pan` — constant-speed straight pan through populated regions.
2. `zoom` — centred zoom in and out, crossing scale bands.
3. `edit` — a drag at pointer-move rate plus interleaved inserts and deletes,
   long enough to trip the rebuild threshold several times.

### Overlay configurations

`pct` — today's `math.max(64, (leafCount * 0.05).floor())`
(`container_index.dart:489`). `capped` —
`math.min(math.max(64, (leafCount * 0.05).floor()), 2000)`.

The threshold becomes a **permanent knob on `ContainerIndex`**, defaulting to
today's formula, rather than a spike-only patch. Plan 3 will change this value
whichever option it picks, and measuring one expression while shipping another
separates the measurement from the thing measured.

### Measured rows

For each (fixture x scenario x variant x overlay):

- build p50 / p95 / **max** and raster p50 / p95 / **max**, kept apart
- number of frames over budget
- `rebuildCount` delta
- entities drawn per frame, and `Paragraph` layouts per frame

That last row is the counterpart of the Plan 2 gate's "a sample visited 3,832
entities" check: it is the evidence that the sweep is not measuring empty space.
Without it, a renderer that draws nothing passes every threshold.

One row carries no timing: **a screenshot with rebasing on and off at
`4.5e6`.** The parent spec claims float32 spacing of roughly 0.5 units there.
This confirms or refutes that claim for free.

### How it is run

`flutter run --profile -d macos` with flags. Debug mode is forbidden — it
produces noise, not numbers.

### Decision table — written before the spike runs

`p95 frame` below is the 95th percentile of **per-frame total time** — build plus
raster for that same frame, which is `FrameTiming.totalSpan` — not the sum of two
separately computed percentiles, which would not be a percentile of anything.
Build and raster percentiles are also reported individually, because the
path-batching row depends on comparing them. `frame budget` is 16.6 ms.

| Measurement | Consequence |
|---|---|
| V1 at 50k, `pan` and `zoom`, p95 < budget | the tile cache **leaves** 3a, with the reason recorded; only the definition cache remains |
| V2 at 50k p95 >= budget | 3a is **not planned**; the render design reopens |
| raster p95 substantially above build p95 at either size | a path-batching task enters 3a; cache scope is **not** widened, because replaying a `Picture` does not reduce rasterisation |
| (V3 p95 - V2 p95) > 25% of budget | the paragraph layout cache is a **required** 3a task, and text LOD (skipping glyphs below N device px) enters the design |
| (V3 p95 - V2 p95) <= 25% of budget | the layout cache alone is enough; no LOD |
| (V4 p95 - V2 p95) > 25% of budget | dashes are baked into definition pictures; per-frame splitting is rejected |
| `edit` at 50k, `pct`: no frames over budget | the overlay is **left alone**; the 500k row is recorded as informational |
| `edit` at 500k, `capped`: max frame < budget | overlay **option A** (absolute cap) is taken |
| `edit` at 500k, `capped`: max frame over budget | overlay **option C** (incremental repack) enters 3a as a task |

The spike's output is a note under `docs/superpowers/notes/`, in the shape of the
Plan 2 gate results: the machine, the Flutter and Dart versions, the run mode,
the fixture and seeds, every measured row, and the decision each row triggered.
A spike whose numbers are not written down has to be run again.

Options A and C are the gate note's own options
([2026-07-28-plan-2-gate-results.md](../notes/2026-07-28-plan-2-gate-results.md),
"Options for Plan 3"). B and D are not reachable from this table: B (indexing the
overlay) is rejected there on its own merits, and D (a splitting R-tree) gives up
STR's query quality and is a Plan 2 redesign, not a Plan 3 task.

**Why `max`, not `p95`, decides the overlay rows.** A rebuild stall is a single
very long frame. Over a sweep of a few hundred frames, p95 hides it completely.
Plan 2's gate made the mirror-image mistake in the other direction: it measured
only a freshly built index, so it structurally could not see the post-drag
regression. Both are the same error — a measurement that excludes the state the
fault occurs in.

## 3a — architecture

### Package layout

`packages/jet_cad_2d_flutter`, depending on `flutter` and `jet_cad_2d`. One
responsibility per file:

```
lib/src/camera/camera_controller.dart      Float64 world->screen affine, ValueNotifier
lib/src/camera/rebase.dart                 Float64 composition -> float32 residual Matrix4
lib/src/style/style_context.dart           value type, cache key (== and hashCode)
lib/src/style/document_style_resolver.dart StyleResolver over the document tables
lib/src/style/resolved_style.dart          concrete draw parameters
lib/src/style/paint_intern.dart            ResolvedStyle -> Paint, interned
lib/src/style/scale_band.dart              band quantisation and anisotropy policy
lib/src/paint/stroke_policy.dart           lineweight (1/100 mm) -> device px
lib/src/paint/dash.dart                    path splitting
lib/src/text/flutter_text_measurer.dart    TextMeasurer over dart:ui
lib/src/text/paragraph_cache.dart          (string, style, height band) -> Paragraph
lib/src/render/scene_walk.dart             traversal and decisions, over SceneSink
lib/src/render/scene_sink.dart             the narrow interface the walk writes to
lib/src/render/canvas_sink.dart            SceneSink implemented against Canvas
lib/src/render/definition_cache.dart       (def, StyleContext, band, docRevision) -> Picture
lib/src/render/tile_cache.dart             world-space tiles, each with its own rebase
lib/src/damage/damage_source.dart          repaint triggers and subscriptions
lib/src/widgets/draft_canvas.dart          StatefulWidget: camera, damage, RepaintBoundary
```

The `scene_walk` / `scene_sink` / `canvas_sink` split is required by testing, not
by taste; see [Testing](#testing).

### The frame-path contract

Plan 2's zero-allocation budget survives only under these four rules.

1. **`visit` closures are held as fields**, never written per frame. The
   per-frame `Canvas` goes into a field, not into the closure — a closure literal
   captures `this`, the canvas and the filter, which is one allocation per call
   on a path whose whole point is to have none.
2. **The tile pass and the instance pass are sequential, never nested.** The
   reentrancy guard already forbids nesting; the design conforms to it rather
   than working around it.
3. **No picture is recorded inside a query callback.** Slots that need recording
   are collected into the renderer's own scratch, the query ends, then recording
   happens.
4. **Recording is not the frame path.** Allocation there is ordinary. The budget
   is on the replay path.

### Camera and rebasing

`CameraController` is a `ValueNotifier` holding pan, zoom and optional rotation
as a `Float64` world->screen affine. The parent spec's rule is kept exactly:
`camera ∘ ancestors ∘ instance ∘ rebase` is multiplied out in `Float64` and a
single residual matrix reaches `Canvas`. Instance transforms are never pushed as
separate `canvas.transform` calls.

One thing enforces this in code rather than in prose: **`rebase.dart` is the only
file that constructs a `Matrix4`.** `scene_walk` and the caches see
`Transform2` and never see a `Matrix4`.

### Style resolution, bands and declared constants

`StyleContext`, `StyleResolver`, the two invalidation channels
(`documentRevision` global and rare; `overrideChanges` per-instance and
highest-priority) and the cache key
`(definition, StyleContext, scaleBand, documentRevision)` are taken from the
parent spec unchanged.

Every constant below is declared, and every one is a knob:

| Constant | Value | Reason |
|---|---|---|
| band factor `f` | `sqrt(2)` | with the representative scale as the geometric mean, stroke width error is at most +/-19%. `f = 2` gives +/-41%, which is visible on hairlines. About 20 bands across a 1000x zoom range. |
| anisotropy threshold | singular-value ratio 1.1 | above it the instance **bypasses** the definition cache and draws with exact per-axis handling. A pure mirror (ratio 1, negative determinant) stays on the cached path. |
| entries per definition | 16 | beyond it those instances bypass the cache. This is the parent spec's "declared degeneration", given a number. |
| tile size | 1024 device px divided by the band representative | tiles are per-band, so a band change invalidates them, as the parent spec requires |
| live tile budget | 64, LRU | bounded memory while panning |

### The two-level cache, and tile invalidation without an old box

The definition cache and the tile cache are as the parent spec describes:
instances sharing a key replay one picture under their own composed transform;
static root-level geometry is recorded into world-space tiles, each around its
own rebase origin; instances in `overriddenInstances` and all ATTRIB text are
excluded from tiles.

`DocChange` carries `Set<Handle> touched` and nothing else — no old geometry. A
moved wall's **previous** box no longer exists by the time the renderer hears
about it, so invalidating tiles that intersect the new box leaves stale pixels
behind at the old position.

The fix reuses the draw-order invariant for free. When a tile is recorded, the
handles baked into it are written to a `Uint32List` in **ascending order** —
which costs nothing, because the query already returns in that order. On a
change:

- for each touched handle, binary-search each tile's list (the **old**
  position), and
- invalidate every tile intersecting the touched handles' **new** boxes.

Both directions are needed, for the same reason Plan 2's `_letBoundRecede`
exists: growth-only invalidation is not conservative, it is wrong in one
direction. Cost is tiles x log(entities per tile), which for tens of tiles is
nothing.

`DocumentLoaded` and `DocumentPurged` invalidate everything: a purge renumbers
slots, so every structure keyed by a slot is dead.

### Damage

Repaint on events, never per vsync. Sources: `document.changes` (a stream),
`CameraController` (a `Listenable`), `documentRevision` on the resolver, and
`overrideChanges` (which repaints the per-instance pass only). `DraftCanvas`
paints inside a `RepaintBoundary`, so a camera change repaints without rebuilding
the widget tree.

### Draw order

Per the parent spec:

```
tile / geometry cache        static, rebased, excludes overridden instances
definition pictures          per (StyleContext, scaleBand, documentRevision)
per-instance pass            ATTRIB text, runtime-overridden instances
entity under active edit     live, outside the cache          (reserved for Plan 4)
selection highlight, handles screen space                     (Plan 4)
snap indicators              screen space                     (Plan 4)
```

3a paints the first three rows. The last three are named so the ordering is
fixed before Plan 4 builds on it.

## 3a — model additions

Exactly this, and no more:

| Addition | Where | Note |
|---|---|---|
| text content | `EntityStore`, a slot-parallel `List<String>`, `''` for non-text | no interning: the paragraph cache is keyed by string *value* already. Slot-lifetime rule: reset to `''` on free. |
| ATTRIB tag | a second string column | required for DXF round-trip; empty means TEXT |
| `textStyle` handle | a `Uint32List` column | defaults to `ReservedHandles.standardTextStyle`, which is hard-coded at every call site today |
| alignment (DXF 72/73) | one `Uint32List` column, two 4-bit fields | |
| height, rotation, width factor, oblique angle | `GeometryPayload.scalars[0..3]` | height is already `scalars[0]` |
| `InstanceNode`: `linetype`, `linetypeScale`, `lineweight`, `transparency` | `node.dart`, the codec, `copyWith` | symmetric with `EntityRecord`; see constraint 2 above |

All of it goes through the existing rules: slot lifetime, JSON key order,
`save(load(save(d))) == save(d)`, unknown-preservation, and one command per
mutation with an inverse.

### Text rotation stays in `scalars`

Rotation lives in `scalars[1]`, and 3a pays down the trap rather than moving it:

- `GeometryPayload`'s doc comment gets a table of what `scalars` means per
  `EntityKind`.
- `transformedBy` gets an explicit warning: coords only; transforming `scalars`
  is the caller's responsibility and depends on the kind.
- A test makes the trap visible — a scaled circle and a rotated text — pinning
  today's behaviour and stating why it is wrong for a command to rely on.

The two rejected alternatives, recorded: storing rotation as a second point in
`coords` would make `transformedBy` correct for free, but forces the codec to
convert DXF's angle both ways and makes the bounds path kind-aware about which
points count. Making `transformedBy` kind-aware belongs to Plan 4's command
semantics, and cannot be finished anyway — under anisotropic scale a circle's
correct answer is an ellipse, and there is no ellipse entity kind.

## 3a — text

- `FlutterTextMeasurer implements TextMeasurer`, over `ParagraphBuilder`:
  `width: infinity` for TEXT, wrapping for MTEXT.
- **One cache, two consumers.** `(string, textStyle, height band)` maps to a
  laid-out `Paragraph` plus its `Aabb2`. The engine's `TextMeasurer` calls and
  the renderer's draw calls read the same entry; two caches would mean two
  truths. The height band uses the same factor `f` as the scale band.
- The engine also ships `MetricModelMeasurer`: a deterministic advance-ratio
  model, no font stack, producing real rectangles. Pure-Dart pick, snap, extents
  and differential tests run against it. `InsertionPointMeasurer` stays as the
  declared lower bound (`extents.dart:29-39`).
- **The measurer is fixed for a document's lifetime.** Index leaf boxes are built
  with `doc.textMeasurer` (`container_index.dart:93-98`), so changing it means
  rebuilding the index. `DraftDocument` takes it at construction, which gives the
  rule for free — but the rule has to be written down.
- An unavailable `TextStyleRecord.fontFamily` falls back and emits a
  `Diagnostic`. SHX maps to TTF, declared lossy, as the parent spec says.
- **Mirrored blocks render text faithfully mirrored** in v1, with no
  counter-transform. A golden test pins it.
- Text LOD — skip glyphs when the text's on-screen height falls below a
  threshold, proposed at **4 device px**, where a glyph is unreadable anyway — is
  conditional on the spike's V3 row. If it is taken, the threshold is a declared
  constant like the others, and the differential tests must run with it disabled,
  since a renderer that legitimately omits glyphs cannot be compared against one
  that draws them.

### The ATTRIB pass

One `forEachInRect`, results split by `kindAt(slot)`: non-attrib leaves go to the
tile cache, attrib leaves to the per-instance pass with their transform from
`transformOfLeaf(slot)`. `attributesOf` is never called on the frame path.

This satisfies the parent spec's "attribute text can never live inside a shared
definition picture" at zero additional query cost.

## 3a — dashes and lineweight

**Dashes.** The pattern is `DashPattern` (paper units) x the header's `$LTSCALE`
x the entity's `linetypeScale`. It is converted to world units using the band
representative and **baked into the definition picture**, unless the spike's V4
row says otherwise, in which case splitting happens per frame. Splitting walks
polyline segments linearly and arcs by arc length; geometric decisions use
`Tolerance`. `(linetype, band, linetypeScale)` maps to a `Float64List` of dash
lengths, computed once per pattern.

**Lineweight** is a fixed device-pixel width. The parent spec offered two
policies; this is the choice:

```
px = (lineweight_hundredthsMm / 100) * kPixelsPerMm * devicePixelRatio
kPixelsPerMm = 96 / 25.4  ~= 3.78   (declared constant)
clamped to [1 device px, 20 device px]
lineweight 0, kLineweightDefault, ByLayer and ByBlock resolve through StyleContext
```

Treating it as a world unit is forbidden: walls would swell on zoom.

`ResolvedStyle` maps to an interned `Paint`, never mutated after construction, so
the frame path allocates no `Paint`.

## Testing

Plan 2's lesson stands: its defects were found by differential testing against a
brute-force reference and by mutation, not by reading. The dominant failure was a
degenerate fixture — a test that could not tell right from wrong. The identity
transform hid a composition-order bug four times.

### The differential oracle is a reference painter

Two painters, one scene, two images, compared pixel by pixel.

- `ReferencePainter`: no caches, no bands, style resolved from scratch per
  entity, drawn directly. Slow, obviously correct, short.
- The production path: definition cache, tile cache, bands, baked strokes and
  dashes.

Both render to a `Picture`, then to an `Image`, and the images are compared. This
is the render counterpart of `reference_query.dart`: it measures whether caching
changes the picture, and every definition-cache, tile-cache, `scaleBand` and
rebase defect is exactly that question. It runs over a corpus of random cameras
and random documents.

### Translation invariance

The same document at `4.5e6` and translated to the origin, with the camera
translated to match, must produce **identical** images. This covers the whole
rebase chain in one test and breaks the moment `camera ∘ ancestors ∘ instance ∘
rebase` stops being multiplied out in `Float64`. The corpus must contain nested
instances at large coordinates; the parent spec says a fixture near the origin
proves nothing, and it is right.

### An independent `StyleResolver` reference

A naive resolver with no memoisation, walking the chain every time, compared
against the production resolver for every (entity, context) pair in the corpus.
The correctness of the two-channel split falls out of this.

### The boundary that testing dictates

Scene traversal — which slot, in what order, under what transform, with what
style — is separated from `Canvas` calls by the narrow `SceneSink` interface.
The reason is measurement: the traversal half is tested in **pure Dart**, where
Plan 2's `vm_allocation_meter.dart` harness works unchanged, so "the frame path
allocates nothing" stays measurable for the renderer too. The `Canvas` half is
covered by the differential and golden tests. Without this seam the allocation
budget becomes unmeasurable.

### Mutants that must be killed, and the fixture each one needs

The right-hand column is the property the corpus **must** contain for the mutant
to be observable. This column is the degenerate-fixture defence.

| Mutant | Required fixture property |
|---|---|
| drop `scaleBand` from the cache key | one definition instanced at 0.1x and at 10x |
| merge `documentRevision` and `overrideChanges` into one channel | overridden and non-overridden instances together |
| push the instance transform as a separate `canvas.transform` | nested instances at `4.5e6` |
| reverse draw order | **overlapping** geometry in different colours; non-overlapping geometry makes order invisible |
| remove the anisotropy bypass | an instance with singular-value ratio > 1.1, and a pure mirror (ratio 1, negative determinant) |
| drop the old-position (sorted handle list) half of tile invalidation | an entity that **leaves** a tile |
| reset dash phase per segment | a multi-segment polyline whose dash length is comparable to its segment length |
| drop the height band from the paragraph cache key | the same string at two heights |
| treat lineweight as a world unit | the same wall at two zoom levels |
| bake stroke width without pre-dividing by the band representative | the 0.1x / 10x pair above, compared for equal on-screen width |

### Goldens, and their limits

A golden is a weak oracle: it pins whatever was rendered, bugs included. Goldens
here cover **appearance intent** — dashes actually look dashed, mirrored text is
actually mirrored, a hatch angle is right. Cache correctness is not their job;
that is the differential tests above. Goldens live in the widget package only.

## Validation gate — end of 3a

Binding unless a row says otherwise. Run from `apps/frame_bench` in profile mode,
on the same fixtures as Plan 2's gate.

| Row | Threshold | Verdict if missed |
|---|---|---|
| 50k at `4.5e6`, pan and zoom, **full workload** (text and dashes on) | p95 frame < 16.6 ms sustained | **fail** — blocks Plan 4; the render design reopens |
| 500k, same | p95 < 33 ms | informational; recorded in the README as the documented supported scale |
| one runtime override toggled per frame, 50k | zero tile invalidations, zero picture rebuilds | **fail** — the two-channel split is not working |
| the `edit` scenario at 50k, under the overlay configuration the spike selected | no frames over budget | **fail** |
| frame-path allocation (pure Dart, against a fake `SceneSink`) | zero in steady state | **fail** — Plan 2's budget has been spent back |
| cache bounds | <= 16 entries per definition, and <= 64 live tiles if the tile cache survived the spike's V1 row | **fail** |
| honesty rows | entities drawn per frame > 0 and paragraph layouts per frame > 0, both recorded | the measurement is void |

The last row exists so the gate cannot fool itself: an empty screen passes every
threshold above it.

The gate may not be deferred into Plan 4, and the full-workload qualifier on the
first row is not decoration. Measuring it with text or dashes switched off would
skip the two rows of the parent spec's risk table that this plan exists to
retire.

## 3b — sketch

3b's plan is written after 3a's gate runs. Two decisions are made now, because
both touch the model.

### A fill stores its own boundary geometry

`entityBounds(kind, payload, measurer, textStyle)` sees only the entity's own
payload and cannot read another entity. Deriving a fill's box from its boundary
would break that signature and start entity-to-entity reads inside index builds.
So, as DXF does:

- the fill entity holds the boundary path in its **own** payload — `coords` for
  all loop points, `scalars` for loop offsets and fill parameters;
- the **association** to source entities lives in a component
  (`FillAssociationComponent`);
- regenerating the stored path when the boundary changes is a **command**, not a
  read-time derivation.

Index and extents stay local, the frame path performs no cross-entity reads, and
DXF round-trip is natural. This is documented as "stored, regenerated by command,
never derived at read time", which does not violate the derived-versus-stored
decision.

### The draw-order convention for a boundary/fill pair

Draw order is globally ascending handle, so a region's fill must satisfy
`fill.handle < boundary.handle` or the fill paints over its own outline. 3b
declares the convention; Plan 4's region tool honours it. Left undeclared, the
symptom is unexplainable, because its cause is handle ordering.

### Rendering

Pattern line families are generated over the boundary's bounding box and clipped
with `canvas.clipPath(boundary)` — clipping rather than analytic trimming,
because it is correct and cheap. `(pattern, band, boundary)` maps to a cached
picture. Multi-loop boundaries use `PathFillType.evenOdd`. Gradients use
`Paint.shader` (`dart:ui`'s `Gradient.linear` / `Gradient.radial`). Solid fills
are trivial.

**Declared degeneration:** a segment cap per fill (proposed: 20,000). Beyond it
the fill degrades to solid in its dominant colour and emits a `Diagnostic`. The
parent spec's "shader fast path held in reserve" stays in reserve; 3b does not
use it.

**`ImageFill` rendering is out of scope** — it needs asset and image lifecycle
management, which is not this plan's subject. It degrades to solid plus a
`Diagnostic`; the export side is already recorded as lossy.

### 3b gate row

A hatch-heavy fixture filling the viewport at 50k: p95 < 16.6 ms. Mutation row:
`evenOdd` mutated to `nonZero`, whose required fixture property is a **nested
loop (a donut)** — without one, both fill types produce the same image.

## Risks

| Risk | Where it is addressed |
|---|---|
| Flutter `Canvas` insufficient at scale | the spike's V1/V2 rows, then 3a's gate |
| The bottleneck is raster, not build, so picture caching does not help | the spike's build/raster split and its path-batching decision row |
| Paragraph layout dominates on text-heavy plans | the spike's V3 row; the layout cache and conditional text LOD |
| Style contexts fail to collapse, so definition caching degenerates | the 16-entry bound with a declared bypass, and a corpus that includes per-instance colours |
| Dashes cost too much per frame | the spike's V4 row; baking into pictures |
| The dirty overlay's linear scan defeats the index at scale | the spike's `edit` scenario over two configurations; options A and C |
| Text model additions widen 3a beyond a render plan | the additions are enumerated exactly, and fills are pushed to 3b |
| Hatch pattern generation cost | 3b's picture cache and segment cap |

## Open items

- The parent spec's `Plan 3 owns all of the above` line should be read as
  superseded by this spec's three-plan split. The parent is not edited here;
  this note is the reconciliation.
- Whether mirrored text should follow AutoCAD's own convention instead of the
  file's transform stays deferred until the real-file corpus exists, per the
  parent spec.
- `FilterEvaluator.invalidate` has no caller today. If 3a or 3b introduces a
  command that changes layer visibility or lock state, that command must call
  it; nothing detects the omission.
