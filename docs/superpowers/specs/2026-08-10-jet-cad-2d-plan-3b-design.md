# jet_cad_2d Plan 3b — Draw-Call Batching and Dashes

**Status:** draft 2026-08-10
**Parent:** [2026-07-27-jet-cad-2d-architecture-design.md](2026-07-27-jet-cad-2d-architecture-design.md)
**Predecessor:** Plan 3a (render path foundation and measurement) — merged at `bfe9df4`, 759 tests
**Carried in:** [2026-08-10-plan-3a-results.md](../notes/2026-08-10-plan-3a-results.md)

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

The consequence for `kAnisotropyThreshold` is that it no longer applies to
line-like geometry at all: there is no residual scale left for a stroke width to
be wrong about. What remains of the threshold — if anything — is decided by the
spike, because variant A′ removes the curve case as well.

The cost is Dart-side arithmetic: four multiplies and two adds per point, per
frame, instead of letting Skia's matrix do it. That is build time traded for
raster time, at a ratio of 10.69 ms against 182.73 ms. The trade is in the right
direction by construction; how far it pays is measured.

### What changes in `CanvasDrawSink`

The batching lives in the sink, not the painter. `CanvasDrawSink` accumulates
into a `ui.Path` while the current bucket holds, and flushes with one
`canvas.drawPath` when it does not.

This is the decision that keeps the seam intact:

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

Batching by bucket loses draw order between primitives in different buckets.
That is the one thing given up, and it needs a contract rather than a shrug.

**The contract: a batch is flushed by anything that can occlude what is already
in it.** In 3b nothing can — every primitive is a thin stroke, and two strokes
that cross do not hide each other. When 3d adds fills, a fill flushes the open
buckets before drawing and opens new ones after, so a hatch drawn later still
covers the lines drawn earlier. The rule is one condition in one place, and it
degrades correctly as content arrives.

Order **within** a bucket is preserved, because a path preserves the order its
subpaths were added in.

### Transparency

Two overlapping strokes in one path are unioned; drawn separately they are
blended twice. With opaque paint the result is identical. With
`transparency > 0` it is not.

`ResolvedStyle.argb` carries alpha, so this is not hypothetical — it is
invisible today only because the corpus is entirely opaque, and it would appear
the first time a user sets a transparent layer.

**A style with alpha < 255 is never batched.** It flushes the open bucket and
draws on its own. Today that costs nothing at all, and it is what makes the
correctness test below possible: batched and unbatched rendering can be required
to be byte-identical, which would be unachievable if transparent strokes were
merged.

## The spike, and the decision rule

The reason raster is 26 µs per leaf is an inference — "the per-leaf transform
push defeats batching" is plausible and unproven. If it is wrong, this plan's
headline is wrong, and that is better learned in task 1 than in task 15.

**Task 1 measures four variants on the same scenes**, sharing most of their code:

| Variant | Lines, points, polylines | Curves | Flush on |
|---|---|---|---|
| **0** | today: per-leaf `save`/`transform`/`restore` | same | n/a |
| **A** | carried to screen, shared residual | keep a per-leaf `Canvas` transform | residual change, style change, alpha |
| **B** | carried to screen, shared residual | keep a per-leaf `Canvas` transform | **any** style change — order fully preserved |
| **A′** | carried to screen, shared residual | residual matrix baked into the path via `Path.addPath(matrix4:)`, from one reset scratch path so the frame path still does not allocate | style change, alpha only |

A′ is strictly the most batched and has a second effect worth naming: baking the
matrix into the path means the stroke is applied in screen space, so an
anisotropically placed circle is drawn as an exact ellipse with a **uniform**
paper-space width. That is what `ResolvedStyle.lineweightHundredths` says a
lineweight is — "paper-space width in 1/100 mm, **not** a world quantity" — so
A′ does not approximate less, it is correct where the current path is wrong. It
also retires finding (6) entirely.

A′'s cost is the widest ordering contract: with no residual flush, order is lost
between every pair of opaque strokes in different buckets across the whole
frame, not merely between those sharing a residual.

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

`referenceWalk` moves into screen space exactly as the painter does — they share
the emit path, so it is one change. The four assertions are unchanged, and they
still run on `differentialFixture(originX: 4.5e6)`.

The oracle answers "does the index-driven walk visit what a brute-force walk
visits". Batching does not touch that question, which is why the sink is where
the batching goes.

### Batched equals unbatched

`CanvasDrawSink` gains `debugDisableBatching`. A golden test renders the same
fixture both ways and asserts the two PNGs are **byte-identical**.

This is the batch's correctness proof, and it is a pixel-level one rather than
an op-list one, because batching is a `Canvas`-level behaviour that an op list
cannot see.

Two fixtures, and the second is the one that makes the first mean something:

1. Overlapping opaque strokes in several styles. Byte-identical, because opaque
   union and opaque double-blend agree.
2. Overlapping strokes with `transparency > 0`. Also byte-identical — but only
   because transparent styles are excluded from batching. Deleting that
   exclusion must make this fixture differ, which is what proves the exclusion
   is doing work rather than merely existing.

### Mutation testing

The method that found Plan 2's and 3a's real defects, applied to the constructs
this plan adds. At minimum: the clip-then-phase computation (drop the phase
carry — the picture must slide), the collapse-floor comparison (flip the
inequality), the alpha exclusion (delete it — fixture 2 must differ), the bucket
key (drop a field from it — two styles must merge visibly), and the flush on
end of frame (drop it — the last bucket must vanish).

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
| batched vs unbatched goldens, both fixtures | byte-identical |
| the differential oracle's four assertions | pass |
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
mirrored-text fidelity, and the measurer-dependence test. Today a real measurer
and `InsertionPointMeasurer` return the same answer, so none of those can be
written.

`DraftPainter.skippedTextCount` is the count that stops being useful when 3c
lands, and the row it feeds in the results note is where text's real cost first
appears.

## Carried to Plan 3d

The fill entity: a new `EntityKind`, its geometry payload, the boundary-to-fill
association, codec support, commands and inverses, index bounds, and
`HitKind.fill`. Then hatch and pattern rendering.

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
| The web ceiling persists | Re-measured, not gated, and named as CanvasKit's limit rather than this plan's |
