# jet_cad_2d Plan 3b — Draw-Call Batching and Dashes

**Status:** draft 2026-08-10
**Parent:** [2026-07-27-jet-cad-2d-architecture-design.md](2026-07-27-jet-cad-2d-architecture-design.md)
**Predecessor:** Plan 3a (render path foundation and measurement) — tasks 0–9 merged at `f9a7d8e`, tasks 10–18 committed to `main` directly, exit gate run at `cdeb4cc` and recorded at `bfe9df4`. 759 tests: 639 engine, 120 Flutter
**Carried in:** [2026-08-10-plan-3a-results.md](../notes/2026-08-10-plan-3a-results.md), [2026-08-10-plan-3a-ledger.md](../notes/2026-08-10-plan-3a-ledger.md)

## Summary

Plan 3a built the render path without a cache and measured it. Two of its
numbers decide what comes next:

> **The path is raster-bound, not walk-bound.** At 500,000 entities on a
> working-set camera, raster is 182.73 ms and build is 10.69 ms — a factor of
> 17. Every leaf carries its own `save` / `transform` / `restore` around one
> `drawPath`, and that is what 21,031 ops per frame cost.
>
> **Every number in that note was measured on a corpus that is 0.06% text and
> 35.0% dashed, with neither drawn.** They are a floor, not a baseline.

What 3a carried forward as "Plan 3b" is five independent subsystems — the
measured corrections, dashes, the text content model and its rendering, the fill
entity and hatching, and the two picture caches with their invalidation
channels. That is roughly fifty tasks against 3a's twenty-one. It is split, for
the same reason Plan 3 was split into 3a and 3b: a plan that must be rewritten
halfway through is two plans wearing one name.

| Plan | Content | Gate |
|---|---|---|
| **3b — this spec** | draw-call batching, the three measured corrections, dashes | relative, failable |
| 3c | text: engine content model, rendering, paragraph layout cache | relative |
| 3d | the fill entity, hatch and pattern rendering | relative |
| 3e | definition picture cache, tile cache, the two invalidation channels | **16.6 ms** |

**This moves the 16.6 ms gate.** The 3a results note says it "belongs to 3b",
and 3a's own spec placed it at the end of Plan 3. Splitting the remainder four
ways moves it with the caches, because 3a's argument for not gating an uncached
painter applies unchanged to a painter that is batched but still uncached: the
gate would either fail uninformatively or pass on a document too small to mean
anything. The reversal is deliberate, and it is stated here rather than left for
a reader of the note to find as a contradiction.

**Content before caches.** The cache key's dimensions are discovered by writing
the content, not guessed at: a mirrored instance cannot reuse a
non-mirrored definition's text picture, a dashed line's on-screen period depends
on the composed scale, and a hatch's op count depends on its density. Designing
the cache against a corpus that is 0.06% text is the risk 3a's own risk table
names. It is also the ordering that just paid: 3a measured the unmemoised style
resolver *first*, and the memo turned out to cost 19–39%.

3b's job is to make the draw calls cheap enough that 3c and 3d can be measured
honestly on top of them, and to do it before the caches exist so that 3e is
designed against a path that is already as thin as an uncached path can be.

## Non-goals

Definition picture cache, tile cache, `documentRevision` / `overrideChanges`
invalidation channels, text content and text rendering, the paragraph layout
cache, the fill entity, hatch and pattern rendering, `InteractionTool`,
`SelectionController`, `DraftPermissions`, `overlayBuilder`, tool presets.

The 16.6 ms frame-time gate is not in 3b. It belongs to 3e, where the caches are.

The dirty overlay's option C — incremental rebuild — is **not** in 3b either. It
is index work, and the thing that wants it is the move tool: R4b's 957.98 ms
per-pointer-sample `rebuildAll()`. That and the structural-invalidation decision
touch the same mechanism and are designed together in Plan 4.

## What 3a measured, and what it decides here

Six findings shape this plan. Each is a number, not a judgement.

1. **Raster is 14–17x build.** 78.29 / 5.48 ms at 50k, 182.73 / 10.69 ms at
   500k, both on the working set. The target is draw calls.
2. **The style memo costs 19–39%.** It is a measured pessimisation. It is
   deleted here rather than left in `lib/` to be rediscovered.
3. **The cull floor loses 10–20% on the frame that matters** and wins 5–13% on
   the frame nobody renders. `kCullFloor`, `LeafOwnerMap` and its change-feeding
   path are deleted.
4. **35.0% of the corpus is dashed and none of it is drawn dashed.** Dashes
   multiply segment count for a third of the drawing, and they are what makes
   3b's gate a real question rather than a formality.
5. **A single picture of about 3.4 million ops aborts CanvasKit.** The
   500,000-entity whole-drawing frame does not render on web at all. Fewer,
   larger draw calls is the same fix as (1).
6. **A fifth of drawn curves carry an approximate stroke width**, because an
   anisotropic transform turns a circle into an ellipse and one
   `Paint.strokeWidth` cannot be right on both axes. 3b's variant A′ removes
   that approximation as a side effect; see "The spike" below.

## The batch

### The mechanism already exists

`DraftPainter` already has a path that carries points into screen space in
Float64 and pushes a residual that is a pure translation: the anisotropy bypass,
[`_emitBypassed`](../../packages/jet_cad_2d_flutter/lib/src/draft_painter.dart).
Its own comment states the property that matters here — "the residual left for
`Canvas` is a pure translation, so its scale is 1 and the stroke width the sink
computes is the exact paper width in device pixels".

Two consequences were not used in 3a:

- That residual is `Transform2.translation(screenOrigin.x, screenOrigin.y)`, and
  `screenOrigin` comes from the frame's rebase origin. **Every bypassed leaf in
  a frame pushes the same residual.** Same residual means same `Canvas` state,
  which means the geometry can go into one path.
- The property is not specific to anisotropic transforms. It holds for conformal
  ones too. The bypass was the exception only because nothing needed it to be
  the rule.

3b makes it the rule. This is not a new mechanism; it is an existing one with
its precondition removed.

### What changes in the painter

`_bypassable` disappears. Points, lines and polylines are **always** carried into
screen space in Float64, and the shared translation residual is pushed once.

Curves are untouched here: the painter still pushes the full chain as a residual
and calls `circle` or `arc` in local space, exactly as today. What a sink does
with that residual is a sink decision, and it is where the variants differ.

`kAnisotropyThreshold` stops gating anything. It no longer applies to line-like
geometry — there is no residual scale left for a stroke width to be wrong about
— and for curves it was only ever a counter's condition. It survives as
`anisotropicCurveCount`'s predicate and nothing else, which the spec says out
loud so nobody later reads it as a live threshold.

The cost is Dart-side arithmetic: four multiplies and two adds per point, per
frame, instead of letting Skia's matrix do it. That is build time traded for
raster time, at a ratio of 10.69 ms against 182.73 ms. The trade is in the right
direction by construction; how far it pays is measured.

**This is the whole painter change, and every variant in the spike shares it.**
The variants differ in `CanvasDrawSink` alone. That is deliberate: it keeps the
spike's diff small, and it means the differential oracle — which reads
`RecordingDrawSink`, not `CanvasDrawSink` — is affected by this one change and
by no variant choice at all.

### What changes in `CanvasDrawSink`

The batching lives in the sink, not the painter. `CanvasDrawSink` accumulates
geometry into `ui.Path`s and flushes each with one `canvas.drawPath`.

**Two bucket lifecycles are possible, and they are different designs, not
different tunings.** The spike measures both, because the choice decides how much
batching is available, what draw order survives, and what 3b owes 3d.

| | **Single open bucket** | **Persistent bucket map** |
|---|---|---|
| State | one `Path`, one paint key | `Map<paintKey, Path>`, insertion-ordered |
| A primitive whose key differs | flushes the open bucket, opens a new one | appends to that key's path; nothing flushes |
| Batching available | run-length in walk order — a corpus that alternates styles per handle gets none | every primitive of a key merges across the whole frame |
| Draw order | **fully preserved** | preserved within a key, lost across keys |
| Flush at end of frame | the one open bucket | every bucket, in insertion order |

Neither is obviously right. The single open bucket gives up nothing and may buy
nothing: the corpus assigns eight layers round-robin, so adjacent handles rarely
share a paint, and it could degenerate to today's call count with extra Dart
arithmetic on top. The persistent map is the design that can actually collapse
21,031 ops into tens of calls, and it is the one that costs draw order.

This is the decision that keeps the seam intact, under either lifecycle:

| | |
|---|---|
| `DrawSink` interface | **unchanged** — 3a's recorded risk that the seam grows into a second `Canvas` does not materialise |
| `RecordingDrawSink` | unchanged in shape; it still records one op per primitive |
| the differential oracle | unchanged in shape; only the coordinate space its ops are in moves |
| `NullDrawSink.opCount` | unchanged in meaning, so 3a's R1/R3 rows stay comparable |

`CanvasDrawSink` gains a separate counter for real `Canvas` calls. The difference
between the two counters is the number this plan exists to move.

**The bucket key is the paint, not the style:** `(argb, lineweightHundredths)`.
`ResolvedStyle` also carries `linetype` and `linetypeScale`, and both are wrong
to key on — they decide what geometry a dashed entity produces, and that
geometry is already baked into the path by the time the sink sees it. Keying on
the whole style would open a bucket per linetype for lines that share a colour
and a width, which is a bucket per nothing.

### Draw order, and what a flush means

Under the persistent map, draw order is lost between primitives with different
paint keys. That is the one thing given up, and it needs a contract rather than
a shrug. Under the single open bucket nothing is given up and the contract below
is vacuous — which is itself a reason to prefer it at equal speed.

**The contract: a batch is flushed by anything that can occlude what is already
in it.** In 3b nothing can — every primitive is a thin stroke, and two strokes
that cross do not hide each other; which of two crossing opaque strokes wins the
overlapping pixels is the only difference, and it is a difference between two
equally arbitrary answers. When 3d adds fills, a fill flushes the open buckets
before drawing and opens new ones after, so a hatch drawn later still covers the
lines drawn earlier. The rule is one condition in one place, and it degrades
correctly as content arrives.

Order **within** a bucket is preserved, because a path preserves the order its
subpaths were added in.

**The differential oracle cannot see any of this.** It reads
`RecordingDrawSink`, which is unbatched by construction, and its in-order
superset assertion is on the painter's op stream — the batching happens
downstream of it. The only witness to a draw-order change is a golden, which is
why the golden work below is the batch's correctness proof and not a formality.

### Transparency

Two overlapping strokes in one path are unioned; drawn separately they are
blended twice. With opaque paint the result is identical. Below full alpha it is
not.

`ResolvedStyle` has no transparency field — an entity's transparency is folded
into `argb` at resolution time, where "alpha is `255 - transparency`". So the
test is `(argb >>> 24) != 0xFF`, and it is not hypothetical: it is invisible
today only because the corpus is entirely opaque, and it would appear the first
time a user sets a transparent layer.

**A style with alpha < 255 is never batched.** It flushes the open bucket and
draws on its own. Today that costs nothing at all, and it is what makes the
correctness test below possible: batched and unbatched rendering can be required
to be byte-identical, which would be unachievable if transparent strokes were
merged.

## The spike, and the decision rule

The reason raster is 26 µs per leaf is an inference — "the per-leaf transform
push defeats batching" is plausible and unproven. If it is wrong, this plan's
headline is wrong, and that is better learned in task 1 than in task 15.

**Task 1 measures four variants on the same scenes.** All four share the single
painter change above and differ only inside `CanvasDrawSink`:

| Variant | Buckets | Curves | Flushes on | Order lost |
|---|---|---|---|---|
| **0** | none — today's sink | per-leaf `save`/`transform`/`restore` | n/a | nothing |
| **B** | one open bucket | `canvas.transform`, which flushes the open bucket | paint-key change, alpha, end of frame | **nothing** |
| **A** | persistent map | `canvas.transform`, which flushes **every** bucket first so the curve lands in order | curve, alpha, end of frame | between two consecutive curves, across paint keys |
| **A′** | persistent map | residual matrix baked into the bucket's path via `Path.addPath(matrix4:)`, from one `reset()` scratch path so the frame path still does not allocate | alpha, end of frame | across the whole frame, across paint keys |

**Even variant B is not trivially zero.** Today every leaf pays
`save` + `transform` + `restore` around one `drawPath` — three of the 21,031 ops
are one leaf. With line-like geometry carried to screen space the residual is the
same for every one of them, so the transform is issued once per frame instead of
once per leaf. B keeps all of that even if it merges nothing at all.

**A′ carries a stroke-width rule the other variants do not**, and it is a
correctness change rather than a tuning one. With the matrix baked into the path,
the stroke is applied in screen space, so an anisotropically placed circle is
drawn as an exact ellipse with a **uniform** paper-space width and nothing
divided out of it. That is what `ResolvedStyle.lineweightHundredths` says a
lineweight is — "paper-space width in 1/100 mm, **not** a world quantity" — so
A′ does not approximate less than the current path, it is correct where the
current path is wrong. It retires finding (6) entirely.

Its cost is the widest ordering contract in the table: nothing but a transparent
style or the end of the frame ever flushes, so order is lost between every pair
of opaque primitives with different paint keys anywhere in the frame.

**The decision rule, stated before the numbers exist:**

1. Three runs of each variant; compare 500k working-set raster p50 from R2, the
   only rig that sees real raster. Differences under 5% are noise.
2. The fastest variant ships.
3. **Ties break toward the narrower ordering contract**: B over A, A over A′.
4. If no variant beats variant 0 by more than noise, **the plan stops and the
   design reopens.** The batch hypothesis is then false, dashes are the only
   remaining content of 3b, and 3e's job is larger than 3a's note assumed. That
   outcome is recorded, not worked around.

Variant A′ also has to pass the anisotropy golden from 3a, which it will
**change** — the stretched stroke becomes uniform. The golden is regenerated
deliberately, with the change named in the commit, rather than silently.

## Dashes

### Where the code lives

`jet_cad_2d`, pure Dart. A dasher takes a point list or an arc, a `DashPattern`,
a scale and a clip rectangle, and emits spans. `Aabb2` and `DashPattern` are
already engine types, so it is testable from the plain `dart test` suite with no
Flutter binding, and a DXF exporter or a print path reuses it rather than
writing it a second time.

The painter calls it. The painter does not implement it.

### The period is computed in screen space

`pattern × ResolvedStyle.linetypeScale × globalLinetypeScale × composed scale`,
giving a period in device pixels, where the composed scale is `sqrt(|det|)` of
the full world-to-screen chain for that leaf — the same representative scale the
stroke width already uses. The batch design carries every point into screen
space anyway, so this costs nothing extra.

The reason is not aesthetic. **A pixel-denominated period bounds segment count
by the viewport, not by the document.** World-space generation on a
60,000-unit line produces tens of thousands of segments regardless of zoom, and
the CanvasKit ceiling at 3.4 million ops is measured, not theoretical.

### Clip before dashing, and carry the phase

The period alone is not enough. At working-set zoom a 60,000-unit line is about
32,000 px long; at a 3 px period that is roughly 10,000 segments, of which about
200 are on screen.

So the geometry is clipped to the viewport — inflated by half the maximum stroke
width so a stroke whose centreline is outside still draws its visible edge —
**before** spans are generated. Clipping moves the start point, so the pattern
phase at the clip entry is computed from arc length along the original geometry.
Skipping that gives a picture that is correct at rest and slides as the camera
moves, which is exactly the kind of defect that survives a screenshot.

### The collapse floor

When the on-screen period falls below `kDashCollapsePx`, the entity is drawn
solid. Zoomed far enough out a dashed line is visually solid anyway; below the
floor the only thing dash generation buys is segments.

The constant is **measured, then reviewed** — not chosen. R1 and R2 are run
across a sweep of candidate values, and each run records segment count, collapse
count and raster p50. A dash-ladder golden — one fixture, the same dashed
geometry at several zoom levels — is rendered at each candidate.

The value that ships is picked by a **recorded human review** of those goldens,
against the numbers beside them. That is a judgement, and writing it down as one
is the point: "no visible difference" is not a threshold a test can hold, and
pretending otherwise would bury the trade-off inside a constant. The sweep, the
numbers and the chosen value all go in the results note.

Collapsed entities are counted per frame, the way `bypassCount` and
`skippedTextCount` are counted, so the note can state how often it happens.

### Phase, curves, anisotropy

| Question | Decision | Why |
|---|---|---|
| Phase across a polyline's vertices | restarts at each vertex | DXF's default without LWPOLYLINE flag 128. The continuous-pattern flag is a DXF-plan field, not a decision made here |
| Circles and arcs | dashed by angle, arc length from the screen-space radius, same floor | the bound has to hold for curves too or it does not hold |
| Anisotropic placements | dashed with the representative scale | one scalar period cannot be right on both axes; counted, like the curve-width approximation it resembles |

### Global linetype scale

`DocumentHeader` gains `globalLinetypeScale`, defaulting to 1.0, with codec
support and no command — matching `units` and `scale`, which are plain mutable
header fields today.

Without it the chain stops at `ResolvedStyle.linetypeScale`, DXF's `$LTSCALE`
has nowhere to land when the import plan arrives, and adjusting a whole
drawing's dash density means editing every entity.

## Removals

Deleted, with their tests:

- `kCullFloor`, `LeafOwnerMap`, the `DraftPainter.ownerMap` parameter, and the
  change-feeding path in `DraftCanvas`. The map's only consumer is the shortcut.
- `MemoisedStyleResolver`.

Both are measured losses. The numbers survive in the 3a results note, which is
where evidence belongs; a measured pessimisation left in `lib/` is a measured
pessimisation waiting to be adopted by someone who did not read the note.

`DraftCanvas` gets simpler as a result: `DocChangeNotifier` keeps notifying
listeners, but there is no derived state left to update before it does.

## Measurement

Every rig from 3a is re-run, unchanged in shape so its rows compare:

| Rig | What it answers here |
|---|---|
| R1 paint microbench | relative regression signal; batching's effect on the walk plus record |
| R3 query-only | unchanged; confirms the walk did not get slower |
| R2 pan and zoom (profile) | **the gate's number** |
| R4a leaf edit | dash generation on the edit path — the rig's added line takes a **dashed** linetype, or it exercises none of this |
| R4b instance drag | unchanged; recorded so Plan 4's constraint stays current |
| web smoke | whether the 500k whole-drawing frame now completes |

New counters, all per frame:

- real `Canvas` calls, beside the existing painter op count
- batch flushes, and what caused each (style, alpha, residual, end of frame)
- dash segments emitted
- entities whose dashes collapsed to solid

The results note is
`docs/superpowers/notes/<completion-date>-plan-3b-results.md` and states: the
four spike variants with their numbers and which shipped, the before-and-after
of every 3a row, the dash-segment and collapse counts, the measured
`kDashCollapsePx` with the sweep behind it, the real-call-versus-op-count ratio,
and the web result.

## Testing

### The differential oracle survives

**`referenceWalk` does not change at all.** Not one edit, let alone two.

`flatten` in `test/support/differential.dart` already applies each residual
before comparing, and its comment says exactly why: "the painter's bypass hands
the sink screen-space points under a translation-only residual where the
reference hands it local points under a full one. Both draw the same line."
Extending the bypass from an exception to the rule makes that the common case.
It does not create a new one.

This is the strongest available outcome for the oracle's independence. The
reference deliberately shares nothing with the painter — "no packed tree, no
dirty overlay, no container index, no scratch buffers, no cull floor, no
anisotropy bypass … that independence is the whole value" — and 3b keeps it
untouched rather than making the same edit twice in two files that must never be
merged into one.

The oracle's assertions are unchanged. `expectPainterSupersetOfReference`
makes two: every reference item is matched by the painter **in the same relative
order**, and every unmatched painter item lies outside the viewport. Both
differential tests keep running — the default fixture, and
`differentialFixture(originX: 4.5e6)` viewed through `cameraOverNestedInstance`
— alongside the four-expect non-vacuity test that proves the reference draws a
polyline, a circle, an arc and a point on the default fixture.

The oracle answers "does the index-driven walk visit what a brute-force walk
visits". Batching does not touch that question, which is why the sink is where
the batching goes — and, as noted above, why the oracle is blind to it.

### Batched equals unbatched

The proof is pixel-level rather than op-list, because batching is a `Canvas`
behaviour that an op list cannot see. It is **not** a golden comparison. Both
modes are rendered in one test through `PictureRecorder` → `Picture.toImage` and
their pixels are compared directly.

Three reasons, and the first two are measured rather than anticipated:

- **The widget route does not re-render.** `_DraftCustomPainter.shouldRepaint`
  returns `false` by design — repaint is driven by the camera and document
  listenables, not by rebuilds — and `RenderCustomPaint` skips
  `markNeedsPaint` when the new painter has the same `runtimeType` and says not
  to repaint. Two `pumpWidget` calls in one test therefore produce **one**
  render, and the second `expectLater` silently re-checks the first image. Both
  fixtures passed vacuously under mutation before this was found.
- **Byte-identity is false for opaque geometry**, and the batched image is the
  correct one. Merging overlapping strokes into one path makes Skia compute
  coverage once over the unioned outline — `1 − union(a, b)` — where separate
  draws composite one antialiased stroke over another — `(1−a)(1−b)`. At half
  coverage that is 0.5 against 0.25. The seam that disappears under batching is
  an artifact of drawing touching strokes separately, and a CAD drawing is made
  of touching strokes. Measured at 1.09% of pixels, magnitudes peaking at 1 and
  trailing to 37, inside the crossing region; a control of unbatched against
  itself differs by nothing.
- Golden files add a platform, a comparator with no tolerance, and a set of PNG
  bytes to maintain, for a comparison that is between two in-process renders.

**The invariant, in three parts:**

1. **Translucent geometry renders identically**, pixel for pixel, because a
   style below full alpha is never batched. Zero differing pixels — no
   tolerance, and therefore no margin to argue about.
2. **Opaque geometry may differ only in partial coverage.** Every pixel fully
   covered in the unbatched render is fully covered in the batched one;
   differing pixels stay under a small fraction of the image; no pixel changes
   hue. A dropped, moved or recoloured primitive fails all three.
3. **Cross-key overlap** is byte-identical under variant B and under B alone.
   Under the mapped variants the difference is the ordering contract made
   visible, and it is a *hue* change at the overlap — which is what separates it
   from part 2's coverage noise.

Part 1 is the discriminator. Deleting the alpha exclusion turns fixture 2's zero
into a difference immediately, with no tolerance standing between the mutant and
the failure. Parts 2 and 3 characterise what batching is allowed to change.

### Mutation testing

The method that found Plan 2's and 3a's real defects, applied to the constructs
this plan adds. At minimum: the clip-then-phase computation (drop the phase
carry — the picture must slide), the collapse-floor comparison (flip the
inequality), the alpha exclusion (delete it — fixture 2 must differ), the bucket
key (drop a field from it — two styles must merge visibly), the flush at end of
frame (drop it — the last bucket must vanish), and, if variant A ships, the
flush-all-buckets-before-a-curve (drop it — a curve must then draw beneath
geometry it belongs above, which is what fixture 3 is shaped to catch).

The log lives at `docs/superpowers/notes/plan-3b-mutation-log.md`, in the shape
3a's log established: every mutant, killed or survived, and for a survivor
either the test that was missing or the argument that it is equivalent.

### Fixture rule

Unchanged from 3a: fixtures allocate handles from `doc.handleSeed.next()` and
never write handle literals. Two 3a fixtures were silently building malformed
documents because they did, and the cross-store handle invariant is what exposed
them.

## Exit criteria

| Criterion | Threshold |
|---|---|
| 500k working-set raster p50, **with dashes on** | **≤ 182.73 ms** — 3a's dash-free number. Failable |
| batched vs unbatched goldens, fixtures 1 and 2 | byte-identical |
| batched vs unbatched goldens, fixture 3 | byte-identical under B; a reviewed, deliberately regenerated golden under A or A′ |
| the differential oracle | both differential tests and the non-vacuity test pass, with `reference_walk.dart` unmodified |
| the spike's four variants | measured, recorded, and the shipped one chosen by the stated rule |
| `kDashCollapsePx` | swept with its numbers recorded, and chosen by a recorded human review of the dash-ladder goldens |
| engine and Flutter suites, analyzer, formatter | green and clean |
| mutation log | every mutant killed or argued equivalent |

The gate asks the only question worth asking of this plan: **does the batching
win exceed the dash cost?** A pass means 3c and 3d start from a path that has
absorbed a third of the drawing becoming dashed. A failure means the batch win
is smaller than the dash cost, 3e's job is larger than 3a's note assumed, and
that is recorded as a number rather than discovered in 3e.

Web's 500k whole-drawing frame is **re-measured and not gated**. Batching is the
direct remedy for the 3.4-million-op abort and it would be satisfying to require
the fix, but a hard limit inside CanvasKit is not this plan's to guarantee.

## Carried to Plan 3c

The text content model as an engine task sequenced before any rendering that
consumes it: stored string, per-entity text-style handle, rotation, DXF 72/73
alignment, codec support, commands, and the `TextMeasurer` signature they imply.
Then `FlutterTextMeasurer`, text rendering, the paragraph layout cache,
mirrored-text fidelity, and the measurer-dependence test.

None of those can be written today. `InsertionPointMeasurer` is the only
`TextMeasurer` in the tree — there is no real measurer to disagree with it, so a
test that a document's extents depend on which measurer it was given has nothing
to compare.

`DraftPainter.skippedTextCount` is the count that stops being useful when 3c
lands, and the row it feeds in the results note is where text's real cost first
appears.

## Carried to Plan 3d

The fill entity: a new `EntityKind`, its geometry payload, the boundary-to-fill
association, codec support, commands and inverses, and index bounds. Then hatch
and pattern rendering.

**Not `HitKind.fill`** — 3a's carried list named it, but it already exists and
`SpatialIndex` already produces it for closed-polyline and circle interiors.
What 3d adds is an entity the hit kind can point at.

3b owes 3d one thing specifically: **the flush contract**. A fill flushes the
open buckets before it draws and opens new ones after. 3b writes the condition
with nothing to put in it, so 3d adds a caller rather than a mechanism.

## Carried to Plan 3e

The definition picture cache, the tile cache, the per-definition entry bounds,
`documentRevision` and `overrideChanges` as separate invalidation channels, the
runtime-override isolation test those finally make observable, and the 16.6 ms
gate.

3b changes what the cache is caching. A definition drawn into a picture is now a
handful of batched paths rather than hundreds of transform-wrapped draws, so the
cache's value, its memory footprint and its scale-band key all have to be
computed from 3b's numbers, not 3a's.

## Carried to Plan 4

Unchanged from 3a, plus one:

1. **Node transforms invalidate structurally.** `SpatialIndex._reconcile` sees a
   node handle and answers `rebuildAll()` — 957.98 ms per pointer sample at
   500,000 entities.
2. **There is no in-place geometry command.** A drag is remove-then-add, burning
   a handle and a slot per pointer sample.
3. **`AddNodeCommand` is quadratic in sibling count.** `DocumentTree._link`
   scans and copies the parent's children on every add. Loading a file is not
   affected; paste of a large selection is.
4. **The dirty overlay's option C, incremental rebuild.** Chosen in 3a on
   measured grounds — a repack costs 865 ms against the 0.089 ms per-query scan
   penalty it buys back — and deferred to here because the gesture that needs it
   and the structural-invalidation decision in (1) touch the same mechanism.

## Risks

| Risk | Where it is addressed |
|---|---|
| The batch hypothesis is wrong and raster is bound by something else | Task 1's spike, with a stated stop-and-reopen rule, before the plan's other work exists |
| Batching changes the picture | Byte-identical goldens both ways, with a transparent fixture that fails if the alpha exclusion is deleted |
| Dashes cost more than batching saves | That is the gate, phrased as a question rather than assumed away |
| The ordering contract is wrong once fills exist | The flush condition is written in 3b with 3d's caller named; the tie-break in the spike's decision rule prefers the narrower contract at equal speed |
| The collapse floor hides real dashes | Swept, and the value that ships is the largest with no visible golden difference; collapses counted per frame |
| Clipping breaks dash phase under a moving camera | The phase carry is an explicit mutation target — dropping it must make the picture slide |
| Pre-transforming points in Dart costs more build time than it saves raster time | Measured directly: the spike reports build and raster separately, as 3a's rigs already do |
| A′ ships and its wider ordering contract bites in 3d | The tie-break prefers A and B; A′ ships only if it wins by more than noise, and the contract is written down here rather than inferred later |
| The bucket lifecycle is left implicit and two readers build two sinks | Named as the axis the spike measures, with both lifecycles tabulated, an ordering-loss column per variant, and golden fixture 3 whose expected result differs between them |
| The oracle is "helpfully" updated alongside the painter | `reference_walk.dart` is untouched by this plan, and the diff being empty is an exit criterion. `flatten` already normalises both routes to screen space |
| The web ceiling persists | Re-measured, not gated, and named as CanvasKit's limit rather than this plan's |
