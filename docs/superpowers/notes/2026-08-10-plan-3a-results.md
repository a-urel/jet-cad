# Plan 3a results — the render path, measured

Every number Plan 3b is designed from. Nothing here is a gate: Plan 3a builds
the render path without a cache and measures it, and the 16.6 ms frame gate
belongs to 3b.

Read the headline first, because two of these numbers change what 3b should be
about.

> **The path is raster-bound, not walk-bound.** At 500,000 entities on a
> working-set camera, raster is 183 ms and build is 10.7 ms — a factor of 17.
> Plan 3b's target is the draw calls, not the walk.
>
> **Moving a block costs a full index rebuild, per pointer sample.** 958 ms at
> 500,000 entities against 0.10 ms for the same gesture on a leaf. It appears
> in no frame timing, because a command runs before the frame it causes.

## Machine and builds

- Apple M3 Pro, macOS 26.5.1, Flutter 3.44.9, Dart SDK 3.12.2.
- **R1/R3**: `flutter test`, debug JIT, `PictureRecorder` — records without
  rasterising. **A relative regression signal only.** Not comparable to R2/R4.
- **R2/R4**: `flutter drive --profile -d macos`, release-mode AOT on a real
  window, real raster.
- **Web**: `flutter test --platform chrome`, dart2js dev compile with CanvasKit.

Two cameras throughout. **Whole drawing** fits the document extents — the worst
case, and a frame nobody renders. **Working set** is 3000 x 2250 world units of
a 60000 x 40000 plan: a room or two, which is what a frame budget is about.

## Corpus

```bash
generateDocument(N, definitionCount: 200, instanceCount: 20000,
    nestingDepth: 2, mirroredFraction: 0.1, nonUniformFraction: 0.2,
    groupCount: 50, layerCount: 8, byBlockFraction: 0.3, dashedFraction: 0.35)
```

500,000 entities, 496,800 index leaves, 20,184 nodes, 200 definitions.

**Not the plan's `definitionCount: entityCount ~/ 25`.** That asks for 20,000
definitions and 500,000 root instances, and the document never finishes
building: `DocumentTree._link` scans and copies the parent's `children` list on
every add, so filling one parent is quadratic in its child count. Measured at
50,000 entities — 6,250 instances 236 ms, 12,500 → 532 ms, 25,000 → 2,684 ms,
50,000 → 15,767 ms. Four times the instances, thirty times the time. Loading a
file does not go through it (`DraftDocumentCodec` uses `addNodeUnchecked`), so
it is the command path only. **A constraint later plans inherit.**

## 1 and 2. R1 paint and R3 query-only — debug JIT, relative

```bash
cd packages/jet_cad_2d_flutter && flutter test --tags rig --run-skipped
```

| Corpus | Camera | R1 paint p50 / p95 | R3 query p50 / p95 | paint − query |
|---|---|---|---|---|
| 50k | whole drawing | 614.8 / 628.1 ms | 133.5 / 135.9 ms | 481.3 ms |
| 50k | working set | 3.11 / 3.20 ms | 0.725 / 0.794 ms | 2.39 ms |
| 500k | whole drawing | 1090.7 / 1114.0 ms | 311.8 / 321.5 ms | 778.9 ms |
| 500k | working set | 6.34 / 6.76 ms | 1.619 / 1.859 ms | 4.72 ms |

The difference is the sink: building `Path`s and `Paint`s and pushing a
transform per leaf. It is **three quarters of R1's time** at every size. R1
cannot see raster at all, so even this three quarters understates what the
draw calls cost — R2 below is the honest version.

Ops per frame: 11,016 (50k working set), 21,031 (500k working set), 2,055,300
and 3,405,300 for the two whole-drawing frames. Three ops per leaf — push
residual, geometry, pop — so about 3,670 and 7,010 leaves on the working set.

## 3. R2 camera under a scripted pan and zoom — macOS profile

```bash
cd apps/dev_harness_2d && flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart --profile -d macos \
  [--dart-define=ENTITIES=500000]
```

240 frames: 120 of pan, then 120 of zoom across three scale bands.

| Corpus | build p50 / p95 / max | raster p50 / p95 / max |
|---|---|---|
| 50k | 5.48 / 5.90 / 294.93 ms | 78.29 / 88.41 / 902.60 ms |
| 500k | 10.69 / 11.52 / 1518.91 ms | 182.73 / 194.42 / 2264.51 ms |

The max in both columns is the first frame, which paints the whole drawing
before the rig zooms to the working set; it is the whole-drawing cost, not a
tail.

**Raster is 14x build at 50k and 17x at 500k.** Every leaf carries its own
`save` / `transform` / `restore` around one `drawPath`. That is the design the
rebase requires and it is what the 21,000 ops per frame cost.

## 4. R4a — a leaf edit per frame

200 steps, each a remove-then-add, with a pan between them.

| Corpus | build p50 | raster p50 | command p50 / p95 / max |
|---|---|---|---|
| 50k | 5.45 ms | 74.40 ms | 0.12 / 0.17 / 0.21 ms |
| 500k | 10.67 ms | 176.36 ms | 0.10 / 0.15 / 0.19 ms |

| Corpus | overlay reached | rebuild threshold | rebuilds | handles burned |
|---|---|---|---|---|
| 50k | 1 | 2,340 | 0 | 201 |
| 500k | 1 | 24,840 | 0 | 201 |

**The overlay reaching 1 is an artifact of the rig, not a property of editing.**
A drag is remove-then-add, and the add takes the slot the remove just freed, so
one slot is dirtied 200 times over. A real session touches distinct entities.
Section 10 measures that separately.

201 handles and 201 slots burned over 200 steps: there is no in-place geometry
command, so every pointer sample of a real drag leaks a handle and a slot.

## 5. R4b — an instance drag per frame

`TransformNodeCommand` touches a node handle, which the index classifies as
structural and answers with `rebuildAll()`.

| Corpus | steps | build p50 | raster p50 | command p50 / p95 | rebuilds |
|---|---|---|---|---|---|
| 50k | 200 | 5.35 ms | 79.47 ms | 115.84 / 120.88 ms | 200 / 200 |
| 500k | 60 | 13.08 ms | 176.47 ms | **957.98 / 999.80 ms** | 60 / 60 |

One isolated full 500k index build, measured on its own:

```bash
cd packages/jet_cad_2d && dart run benchmark/overlay_fill.dart
```

**865 ms.** That is what a `rebuildAll()` costs, and R4b pays it once per
pointer sample.

**None of it appears in a frame timing.** A command runs synchronously in the
gesture handler, before the frame it causes. Timed by frames alone, R4b reports
"200 rebuilds" beside a 5.4 ms build and reads as "a full rebuild is free". The
rigs time the command separately for exactly this reason.

## 6. The anisotropy bypass

`kAnisotropyThreshold = 2.0`, exclusive — the ratio of the larger singular
value to the smaller, so 1.0 is conformal and a mirror stays conformal.

| Corpus, working set | leaves drawn | bypassed | anisotropic curves |
|---|---|---|---|
| 50k | ~3,670 | 924 (25%) | 766 (21%) |
| 500k | ~7,010 | 1,007 (14%) | 794 (11%) |

The corpus places 20% of root instances past the threshold and the nesting adds
its own non-uniform scale, so the two effects compound. **A fifth of the drawn
curves are drawn with an approximate stroke width** — they cannot take the
bypass, because an anisotropic transform turns a circle into an ellipse and
`DrawSink.circle` carries one radius. `Canvas` draws the ellipse correctly; only
the width is wrong, by up to the anisotropy ratio. Counted rather than assumed
away.

## 7. The two declared optimisms, quantified

**Text is not drawn.** The model carries no text content yet, so `DraftPainter`
counts and skips it: 300 entities per whole-drawing frame at both sizes, 0 and
2 on the working set.

That is **0.06% of the corpus** — and that is the optimism, not the reassurance.
Text is the payload of a real drawing; a floor plan is room labels, dimensions
and schedules. Every number in this note is measured on a corpus that has
essentially none, and the render path has not been asked to lay out a single
glyph. Plan 3b adds text, and when it does these numbers are a floor, not a
baseline.

**Dashes are not applied.** 174,999 of 500,000 entities — **35.0%** — carry a
non-continuous linetype, and the painter draws every one of them solid. Dash
generation is Plan 3b's, and it multiplies the op count for a third of the
drawing.

## 8. Web smoke

```bash
cd packages/jet_cad_2d_flutter && flutter test --tags rig --run-skipped --platform chrome
cd apps/dev_harness_2d && flutter build web --release
```

**The first run did not produce a number; it produced a defect.**
`Unsupported operation: Uint64List not supported on the web`, thrown from
`PackedRTree`'s dead-item bitset during `ContainerIndex.build`. The spatial
index — and therefore the entire render path — did not run on web at all. It
was the only 64-bit typed list in the engine, and a 64-bit word would have been
wrong on web even if the type existed, since JavaScript's bitwise operators are
32-bit. Now `Uint32List` with 32-bit words; existing tests kill both halves of
the obvious off-by-one.

With that fixed:

| Corpus | Camera | R1 paint p50 | R3 query p50 | vs native debug JIT |
|---|---|---|---|---|
| 50k | whole drawing | 7,667.6 ms | 2,124.6 ms | 12.5x slower |
| 50k | working set | 42.4 ms | 11.4 ms | 13.6x slower |
| 500k | whole drawing | **aborts** | — | — |

The 500,000-entity whole-drawing frame **aborts CanvasKit**:
`RuntimeError: Aborted()` inside `finishRecordingAsPicture` with about 3.4
million ops in one picture. Not a slow number — a hard limit. The working-set
frames complete.

`flutter build web --release` succeeds; 40 MB of build output, mostly CanvasKit.

Informational, as the plan says, with one exception: the `Uint64List` defect was
not informational and is fixed.

## 9. The style memo

`MemoisedStyleResolver` wraps `DocumentStyleResolver`, keyed on the entity slot
and every field of the style context.

| Corpus | Camera | R3 plain | R3 memoised | delta | entries |
|---|---|---|---|---|---|
| 50k | whole drawing | 133.5 ms | 183.2 ms | **+37%** | 70,133 |
| 50k | working set | 0.725 ms | 0.922 ms | **+27%** | 2,443 |
| 500k | whole drawing | 311.8 ms | 433.9 ms | **+39%** | 520,133 |
| 500k | working set | 1.619 ms | 1.933 ms | **+19%** | 5,538 |

**The memo is a pessimisation. Plan 3b does not ship it.**

The cache is fully warm from the second frame onward, so these are hits. A
seven-field record hash costs more than `DocumentStyleResolver.styleFor`, which
is a few array reads and switches. Measuring the unmemoised cost *first* is
what stopped this from being assumed — and it would have come with an
invalidation hazard for the privilege.

Also measured, and it is not a pessimisation: the owner-map cull-floor
shortcut. See section 11.

## 10. The dirty overlay — the decision

The parent gate left `rebuildThreshold = max(64, leafCount * 0.05)` open: a
fraction of document size, so the overlay's per-query linear scan grows with the
document. Four options were recorded — **A** bound the threshold absolutely,
**B** index the overlay, **C** incremental rebuild, **D** true incremental
insertion.

R4a cannot decide it, for the reason in section 4: its overlay never grows past
one entry. So the input was measured directly, filling the overlay with edits to
**distinct** entities:

```bash
cd packages/jet_cad_2d && dart run benchmark/overlay_fill.dart
```

500,000 entities, `rebuildThreshold = 24,840`, one rect query over the working
set:

| Overlay length | rect query p50 |
|---|---|
| 0 | 0.392 ms |
| 2,838 | 0.395 ms |
| 12,153 | 0.353 ms |
| 24,473 (threshold − 367) | 0.481 ms |

A full overlay costs **+0.089 ms per query, +23%**. One full index build costs
**865 ms**.

### The decision: C, incremental rebuild

The two costs are not close. A repack is **9,700 times** the scan penalty it
buys back, and it lands as a single 865 ms stall — 52 dropped frames at 60 Hz.
The scan, meanwhile, is 0.089 ms against a frame whose raster alone is 183 ms:
**five hundredths of one percent of a frame.**

That decides three of the four:

- **A — bound the threshold absolutely.** Rejected. Bounding it *lower* than
  `leafCount * 0.05` makes repacks more frequent, which is the expensive
  direction. The measurement says the threshold should if anything go up.
- **B — index the overlay.** Rejected. It makes the scan cheaper, and the scan
  is already free. It solves a problem nobody has.
- **C — incremental rebuild.** **Chosen.** It targets the only cost that
  matters: spreading the 865 ms repack across frames so no single frame wears
  it. The scan can stay linear and the threshold can stay a fraction.
- **D — true incremental insertion.** Strictly better than C and much larger.
  Not needed while the scan is free; the reason to reach for it would be a
  measurement showing the scan mattering, and this one shows the opposite.

No additional measurement is needed to choose. The one that *would* change the
answer, named so it is not rediscovered: if a session's overlay routinely holds
a large fraction of the document while the camera is zoomed out — where the
query returns far more than 7,010 leaves — the scan's share could rise enough
to matter. R1's whole-drawing rows are where that would show.

## 11. The cull floor — revisit it

`kCullFloor = 32`'s own comment calls it "a measured guess, the number to
revisit from R1's numbers". These are those numbers.

| Corpus | Camera | R3 plain | R3 + owner map | delta | direct buckets |
|---|---|---|---|---|---|
| 50k | whole drawing | 133.5 ms | 116.7 ms | **−13%** | 39,900 |
| 50k | working set | 0.725 ms | 0.872 ms | **+20%** | 325 |
| 500k | whole drawing | 311.8 ms | 296.7 ms | **−5%** | 39,900 |
| 500k | working set | 1.619 ms | 1.779 ms | **+10%** | 342 |

**It helps the frame nobody renders and hurts the frame that matters.** The
shortcut trades a rect query for drawing every leaf a container owns. With the
whole drawing on screen that query was culling nothing, so skipping it is free.
Zoomed in it was culling most of the container, and skipping it draws leaves
that are off screen.

Plan 3b should either drop the shortcut or gate it on the container's on-screen
fraction rather than on its leaf count. It is opt-in today (`DraftCanvas` passes
an owner map, so it is on), which makes this a live cost, not a hypothetical.

## 12. What R4b means for Plan 4

**A per-frame `rebuildAll()` at 500,000 entities is unaffordable. Plan 4 cannot
ship a move tool on top of `TransformNodeCommand` as it stands.**

958 ms per pointer sample is roughly one frame per second while dragging. The
gesture is not incidental — moving a block is the application's defining
action, and it is the one the index currently handles worst. A leaf edit through
the same rig costs 0.10 ms.

Two constraints Plan 4 inherits, both recorded here rather than left to be
discovered:

1. **Node transforms invalidate structurally.** `SpatialIndex._reconcile` sees a
   node handle and answers `rebuildAll()`. A move tool needs either an
   incremental path for "a node's transform changed, its subtree's boxes move
   rigidly" or a deferral that rebuilds once on gesture end and draws the
   dragged subtree from a live overlay in between. Choosing between those is a
   design question, not a tuning one.
2. **There is no in-place geometry command.** A drag is remove-then-add, which
   burns a handle and a slot per pointer sample — 201 of each over 200 steps in
   R4a. Undo history grows by two entries per sample. The cost is not the frame
   time, which is fine; it is that the document accumulates garbage in
   proportion to how long a user holds the mouse down.

Also inherited, from section "Corpus": `AddNodeCommand` is quadratic in the
number of siblings under one parent, so bulk construction through commands —
paste of a large selection, an importer that does not use the codec — is
quadratic. Loading a file is not affected.

## What this says about Plan 3b

1. **Optimise the draw calls, not the walk.** Raster is 14–17x build. A picture
   cache, fewer transform pushes, or batching leaves that share a residual — in
   that order of likely value.
2. **Do not ship the style memo.** Measured, and it costs 19–39%.
3. **Revisit or gate the cull floor.** It is a 10–20% loss on the working set
   today.
4. **Take option C for the overlay.** Spread the repack; leave the scan alone.
5. **The 500k web ceiling is real.** A single picture of 3.4M ops aborts
   CanvasKit. Whatever 3b does about the whole-drawing frame has to keep a
   picture under that limit, which points at the same fix as (1).
6. **Every number here is measured without text and without dashes**, on a
   corpus that is 0.06% text and 35% dashed. They are a floor.
