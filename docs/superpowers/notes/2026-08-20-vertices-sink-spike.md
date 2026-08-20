# The vertices sink — batching the calls, and what it took

`2026-08-20-dash-leaf-separation.md` ended with a number and a lever. The
number: holding the drawn geometry fixed at `screenSpaceLeafCount=1664` and
moving only the dash fraction moved the frame 6.0x, so the unit of render cost
is the canvas call and not the drawn leaf. The lever: make fewer calls.

This note is the spike that pulled it.

**The frame went from 57.3 ms to 14.3 ms at 10,000 entities — from about 17 fps
to about 70, inside the 16.67 ms budget for the first time.** Getting there
cost two design mistakes, both caught by looking at the picture rather than at
the numbers, and both worth recording because the numbers looked fine while the
drawing was wrong.

## Why a cheaper geometry was never going to work

Read from the engine source of the revision that produced these numbers — the
Homebrew cask directory is named `3.27.3` but `bin/internal/engine.version`
matches `flutter --version` at 3.47.0, engine `5f77625673`.

A dash span leaves `DraftPainter` as `polyline(_span, 2, style)` and reaches
the canvas as `drawPath` on a two-point path. Impeller then:

```
impeller/display_list/dl_dispatcher.cc:622   if (path.IsLine(&start, &end)) { canvas.DrawLine(...); return; }
impeller/display_list/canvas.cc:901          if (AttemptDrawLineSDF(p0, p1, paint, ...)) return;
impeller/display_list/canvas.cc:818          // Draw the line as a filled rectangle
```

**We were already on Impeller's cheapest line path.** The 930-line
`StrokePathGeometry` tessellator never ran; each span became an SDF-filled
rectangle. There was no tessellation left to remove, which is why every earlier
attempt to make the *geometry* cheaper failed. What was left was one Impeller
`Entity` per call, about 1 µs of it, 37,376 times.

This also settles Plan 3b's batch spike, which collapsed spans into one large
`Path` and got slower. That did not batch them — it **left the `IsLine` fast
path** and dropped the drawing into `StrokePathGeometry`.
`bucketMapBakedCurves` was 172.9% slower for that reason. Batching was never
refuted; one particular batching was, and it was the one that gives up the fast
path.

## What is available, and what is not

| Route | Verdict |
|---|---|
| `Canvas.drawVertices` | **Open.** One `Entity`, N triangles (`canvas.cc:1473`). What this spike uses. |
| `Canvas.drawRawPoints(PointMode.lines)` | **Closed, verified.** `dl_dispatcher.cc:662` loops and calls `DrawLine` per segment. Same N entities. |
| `Canvas::DrawDashedLine` | **Exists** (`canvas.cc:915`, `StrokeDashedLineGeometry`) and would dash on the GPU, but is declared only at `display_list/dl_canvas.h:108` and is **not exposed through `dart:ui`**. |
| `flutter_gpu` | Ships in the SDK, with `bindPipeline` and `draw(vertexCount, instanceCount:)`. The fallback if `drawVertices` had not been enough. |

## The measurements

R2, 10,000 entities, working-set camera, `TEXT=true`, macOS Low Power Mode
**off** and verified with `pmset -g` after each run. Apple M3 Pro, macOS 26.5.1,
Flutter 3.47.0. `screenSpaceLeafCount` is 1664 in every row — same drawing.

| Sink | canvas calls | `drawVertices` | build p50 | raster p50 | frame |
|---|---|---|---|---|---|
| `CanvasDrawSink` | 39,631 | — | 12.41 ms | 44.86 ms | **57.3 ms** |
| one buffer per colour, curves on the fallback | 14,570 | 7 | 5.62 ms | 18.75 ms | 24.4 ms |
| one ordered buffer, curves on the fallback | 14,570 | 1 | 5.61 ms | 19.86 ms | 25.5 ms |
| **curves and points batched too** | **18** | **19** | **5.50 ms** | **8.77 ms** | **14.3 ms** |

The last row is the median of three consecutive runs, raster 8.73 / 8.77 /
8.87. The 18 remaining canvas calls are text paragraphs; the 19 flushes are one
per text op plus one at the end of the frame.

**The per-call model predicted this before it was measured.** From the
separation note, fitted on a completely different sink:

```
build  = 1.620 ms + 0.275 µs x calls   ->  at 14,570: predicted 5.63, measured 5.62
raster = 2.997 ms + 1.028 µs x calls   ->  at 14,570: predicted 17.98, measured 18.75
```

The sharpest evidence is the last row rather than those two. Batching the
curves took the segment count **up** from 26,352 to 61,204 — 2.3x more
triangles and more shaded pixels — and the frame got 1.8x faster, because the
entity count collapsed. The GPU does not mind filling triangles. Impeller minds
setting up a render entity for each call.

## Two mistakes, both found by looking

### One buffer per colour reordered the drawing

The first cut kept a buffer per colour and flushed them at the end of the
frame. It was fast, and it was wrong: every segment of one colour then drew
after every segment of another, whatever order the walk emitted them in. A
screenshot of the harness showed it at once — the baseline's green/cyan/magenta
mix became magenta-dominated.

The class comment at the time said draw order was invisible "until fills land".
**That was wrong.** Strokes are opaque. A reordered stroke covers a different
neighbour, so draw order is a rule about strokes and not only about fills.

Carrying the colour on the vertices instead of on the `Paint` fixed both halves
at once: triangles inside a single `drawVertices` rasterise in submission order
with no depth test between them, so the buffer's order *is* the draw order, and
there is one call however many colours the frame uses.

Its measured cost is 1.1 ms — 19.86 against 18.75 — because a per-vertex colour
is an extra attribute and puts Impeller on `VerticesSimpleBlendContents`
instead of the colour-source path. Collapsing seven calls to one does not pay
that back, and should not be expected to: per-`Entity` cost only dominates in
the tens of thousands.

Text still could not be batched, so it flushes the buffer before deferring to
`CanvasDrawSink`. Without that, every stroke batched before a text op would
draw after it.

### The stroke-width floor was a guess

The sink floored the width at one *logical* pixel. Impeller's rules, both in
device space and neither reachable from Dart:

```
line_geometry.cc:24  max(width, kMinStrokeSize / max_basis), kMinStrokeSize = 1.0f
geometry.cc:148      thinner than that keeps its pixel and gives up alpha in
                     proportion: clamp(w * 2, 0, 1), with exactly zero taking
                     full alpha as the hairline case
```

Both are mirrored now, and `devicePixelRatio` comes in from the widget on every
build rather than being cached — the ratio changes when a window moves between
displays.

**The claim that the old floor drew lines "2x too thick", and that 8.63 ms was
therefore an upper bound, was wrong on both counts.** `kLogicalPixelsPerMm` is
3.7795, so the corpus's thinnest lineweight is 0.945 logical pixels and the old
floor rounded it to 1.0 — 5.8% thick on a quarter of the entities, not 2x.
Three runs after the fix read 8.73 to 8.87 against 8.47 to 8.68 before it: no
change outside the noise. It is a fidelity fix, not a performance one.

The alpha fade is inert on this corpus at any normal ratio — every lineweight
it generates is above the floor — so it is insurance for the lineweights a real
file carries, pinned by tests rather than by a measurement.

## Correctness

The golden suite is **not available to this sink**: `flutter_test`'s software
Skia backend did not finish a `drawVertices` of 1,007 segments in 7 minutes 28
seconds, where Impeller draws it instantly. That left the differential oracle
as the only mechanism, and `expectPainterSupersetOfReference` could not reach a
sink that emits no ops.

`test/support/vertices_differential.dart` moves the comparison down a level:
the reference walk says where ink belongs, the sink says where its triangles
are, point-in-triangle joins them. The samples run along the *true* primitive —
the real arc, not its chords — and are transformed by the residual, where the
sink builds chord quads from a flattening it chose itself, so the two sides
stay independent.

- `expectInkCovers` — every point a primitive passes through is inside a
  triangle of its own colour.
- `expectNoStrayInk` — every triangle sits on a primitive of its colour. Run
  against the *painter's* ops, not the reference's: the painter is a superset
  of the reference by design and so cannot be bounded by it.

Nine mutants against these two tests alone, with the unit tests out of the
picture: eight killed. The ninth is not applicable rather than surviving —
`closed:` is `false` at all four of the painter's call sites, so no closed
polyline reaches a sink from the frame path.

Three things the oracle cannot see, all recorded in its header: a stroke too
thin **on a straight line** (the centreline is inside the quad at any positive
width — the halved-width mutant dies only through the sag of a curve); alpha
(the sink's own coverage arithmetic); and order (two overlapping triangles are
both found whichever came first).

Totals for the sink as it stands: **33 mutants, 32 killed, 1 not applicable**,
across 28 new tests. A further 7 were run against the per-colour design before
it was discarded.

## What this is not

- **No joins and no caps.** Every segment is an independent quad, so a
  polyline's corners have a notch on the outside. Dash spans are two points
  each and have none, which is where the measurement was aimed — but a
  continuous polyline at a visible lineweight will show it.
- **Anti-aliasing is MSAA, not a coverage shader.** The SDF path this replaces
  anti-aliases analytically. Not measured; not visible at the screenshot scale
  used here.
- **Text is still `CanvasDrawSink`'s.** A paragraph is not triangles.
- **Measured at one corpus and one entity count.** 50,000 and 500,000 are
  unmeasured, and the per-call model says the win should widen with them.

## Where it stands

Branch `spike/vertices-sink`, four commits, nothing merged and nothing pushed.
`DraftCanvas.useVertices` and the harness's `VERTICES` define are both inert at
their defaults, so `main`'s frame is byte-identical to what it was.

Engine suite 720/720, widget suite 180/180, analyze and format clean in both
packages.

The open question is not whether to batch — that is settled — but whether this
sink becomes the sink, which needs joins, caps, a decision about the golden
suite, and the two larger corpora measured.
