# The dash/leaf separation — the frame's cost is per canvas call

Every render measurement this project has taken reported two numbers that move
together. From 10,000 entities to 50,000, on the same working-set camera,
`screenSpaceLeafCount` went ×1.304 and `dashSpans` went ×1.293. Raster time
went ×1.495. Nothing in that data can tell **cost per drawn leaf** from **cost
per dash span** apart, because in this corpus the two are collinear.

Plan 3a inferred "about 26 µs a leaf". Plan 3b's batch spike was designed
against that inference and its four modes all lost. Plan 3c's results note
carried the same per-leaf framing forward. **The per-leaf unit was never
measured — it was assumed, three times.**

This note holds the geometry still and moves only the linetype.

## Why the control is sound

`generateDocument`'s `dashedFraction` does not reach the corpus's random
stream. `_Styling.linetypeFor` is a quota counter:

```dart
_dashedDue += dashedFraction;
if (_dashedDue < 1.0) return ReservedHandles.byLayerLinetype;
_dashedDue -= 1.0;
return handle;
```

It never calls `random`. Changing the fraction therefore cannot perturb a
single coordinate, which means extents, camera and the set of drawn leaves are
identical across the arms. The entities are the same entities; some of them
stop being dashed.

The fraction does change one other thing. `generateDocument` seeds the dashed
`LinetypeRecord` only when the fraction is positive, so at zero every later
handle shifts down by one. Relative draw order — ascending handle value — is
unaffected, and so is what gets drawn.

**That the control held is measured, not argued.** All three arms report
`screenSpaceLeafCount=1664`. Had the geometry moved, that number would have
moved with it, and the experiment would have been void.

The define is `DASHED`, inert at its default of `0.35`, which is the value
every earlier run used.

## Machine and build

Apple M3 Pro, macOS 26.5.1, **Flutter 3.47.0**, Dart 3.13.0, engine revision
`5f77625673`. Impeller/Metal with SDF (`MetalSDF`). Low Power Mode **off**,
verified with `pmset -g` after the runs.

Plan 3b's numbers were taken on Flutter 3.44.9. Absolute times are not
comparable across that gap; the ratios within this note are all same-session.

```sh
cd apps/dev_harness_2d && flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart --profile -d macos \
  --dart-define=TEXT=true --dart-define=ENTITIES=10000 \
  --dart-define=RIG=pan --dart-define=DASHED=<0|0.175|0.35>
```

## The three arms

| `DASHED` | dashSpans | canvasCalls | leaves | build p50 | raster p50 | frame |
|---|---|---|---|---|---|---|
| 0.35 | 37,376 | 39,631 | **1664** | 12.52 ms | 44.63 ms | 57.2 ms |
| 0.175 | 18,976 | 21,655 | **1664** | 7.61 ms | 23.46 ms | 31.1 ms |
| 0 | 0 | 3,097 | **1664** | 2.46 ms | 7.06 ms | **9.5 ms** |

The leaf count is held; the frame moves 6.0×. Dashing is **84%** of raster and
**80%** of build.

The 0.35 arm reproduces the reading taken earlier the same day to within 0.3%
(44.63 against 44.75 ms), so the spread between arms is three orders of
magnitude above the run-to-run noise.

## The prediction, and where it missed

The 0.175 arm was run **after** a model was fitted to the other two and a
prediction written down. Fitting on `canvasCalls`:

| | predicted | measured | error |
|---|---|---|---|
| canvasCalls | 21,785 | 21,655 | −0.6% |
| **build p50** | 7.57 ms | **7.61 ms** | **+0.5%** |
| raster p50 | 26.14 ms | 23.46 ms | −10.3% |

**Build is linear in canvas calls to the limit of the measurement.** The
three-point least-squares fit:

```
build = 1.620 ms + 0.275 µs × canvasCalls      residuals [−0.01, +0.03, −0.01] ms
```

Across a 12.8× range of call counts the worst residual is 30 µs. There is no
per-leaf term and no per-pixel term left over — the CPU side of the frame is
call count and nothing else.

**Raster is not linear, and the 10% miss is the finding.** Marginal cost rises
with call count:

| interval | marginal raster cost |
|---|---|
| 3,097 → 21,655 | 0.884 µs/call |
| 21,655 → 39,631 | **1.178 µs/call** (+33%) |

This is the same "slightly super-linear" residual Plan 3b reported (+16% over
leaf count) and Plan 3c reproduced twice (+14.6%, +16.9%) — now attributed. It
was never about leaves. Every `DrawLine` becomes one Impeller `Entity` carrying
its own depth value; as entities per render pass grow, the opportunities to
merge them fall, so the cost of the marginal call rises.

**The super-linearity makes batching worth more, not less.** Removing calls
buys back more than a proportional share.

## What Impeller does with a dash span

Read from the engine source of the exact revision that produced these numbers
(`/opt/homebrew/Caskroom/flutter/<...>/flutter` is 3.47.0 despite the stale
cask directory name; `bin/internal/engine.version` matches `flutter --version`).

A dash span leaves `DraftPainter` as `polyline(_span, 2, style)` and reaches
the canvas as `drawPath` on a two-point path. Impeller then:

```
impeller/display_list/dl_dispatcher.cc:622   if (path.IsLine(&start, &end)) { canvas.DrawLine(...); return; }
impeller/display_list/canvas.cc:901          if (AttemptDrawLineSDF(p0, p1, paint, ...)) return;
impeller/display_list/canvas.cc:818          // Draw the line as a filled rectangle
```

**We are already on Impeller's cheapest line path.** The 930-line
`StrokePathGeometry` tessellator never runs; the span becomes an SDF-filled
rectangle. There is no tessellation cost to remove, which is why every attempt
so far to make the *geometry* cheaper has failed. The cost is the per-`Entity`
setup, ~1 µs of it, 37,376 times.

This also explains Plan 3b's batch spike. Collapsing spans into one large
`Path` did not batch them — it **left the `IsLine` fast path** and dropped the
whole drawing into `StrokePathGeometry`. `bucketMapBakedCurves` was 172.9%
slower for that reason. Batching was never refuted; one particular batching
was, and it was the one that gives up the fast path.

## What is available, and what is not

| Route | Verdict |
|---|---|
| `Canvas.drawVertices` | **Open.** One `Entity`, N triangles (`impeller/display_list/canvas.cc:1473`). The real batching primitive. |
| `Canvas.drawRawPoints(PointMode.lines)` | **Closed, verified.** `dl_dispatcher.cc:662` loops and calls `DrawLine` per segment. Same N entities; the only gain is `reuse_depth`. |
| `Canvas::DrawDashedLine` | **Exists in the engine** (`canvas.cc:915`, `StrokeDashedLineGeometry`) and would collapse 37,376 spans to 1,664 calls with the dashing done on the GPU — but it is declared only at `display_list/dl_canvas.h:108` and **is not exposed through `dart:ui`**. Unreachable. |
| `flutter_gpu` | Ships in the SDK (`bin/cache/pkg/flutter_gpu`), with `bindPipeline` and `draw(vertexCount, instanceCount:)`. Instanced rendering from Dart. The fallback if `drawVertices` is not enough. |

## What this settles

- **The unit of render cost is the canvas call, not the drawn leaf.** Every
  per-leaf figure in Plans 3a, 3b and 3c is an artefact of a corpus in which
  dash spans and leaves happen to be collinear. Per-leaf numbers should not be
  carried forward.
- **The engine, the walk, the index and the text path are not the problem.**
  At `DASHED=0` a 10,000-entity frame is 9.5 ms — inside the 16.67 ms budget,
  about 105 fps, with everything else unchanged.
- **A rewrite in another language addresses nothing here.** Build is 0.275 µs
  per call of Dart, against 1.0–1.2 µs per call of GPU entity setup. Even a
  free CPU side leaves 44.63 → 44.63 ms.

## What this does not settle

- **Build's 0.275 µs/call is two costs in one.** It covers the `Dasher`'s span
  generation *and* the `Path` construction and `drawPath` recording.
  `drawVertices` removes the second and keeps the first, so build will land
  somewhere between 2.46 and 12.52 ms, not at 2.46. This experiment cannot
  split them; an arm that generates spans and discards them would.
- **`dashedFraction: 0.35` is this corpus's choice.** Real drawings vary, and
  the *magnitude* of the win varies with them. The finding that cost tracks
  call count does not.
- **The super-linear term is attributed but not modelled.** Pass merging is the
  hypothesis; nothing here measures it directly.

## The next experiment

A `VerticesDrawSink` behind the existing `DrawSink` seam: accumulate a
`Float32List` per resolved style, flush on style change or at frame end. The
differential oracle compares op streams rather than pixels, so it survives the
swap; the 14 golden PNGs do not. Predicted raster at 10,000 entities: ~7–10 ms,
against 44.63 today.
