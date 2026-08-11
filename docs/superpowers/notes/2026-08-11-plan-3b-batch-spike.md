# Plan 3b's batch spike — the hypothesis, refuted

Plan 3a's headline was that the render path is raster-bound: 182.73 ms raster
against 10.69 ms build at 500,000 entities on a working-set camera. From that,
183 ms over roughly 7,010 drawn leaves gives about 26 µs a leaf, and the
inference was that each leaf's own `save` / `transform` / `restore` around one
`drawPath` is what defeats Skia's batching.

**That inference was wrong, and Plan 3b's first task was written to find out.**

The plan's decision rule was fixed before any number existed: three runs of each
mode, compare the median 500k working-set raster p50, differences under 5% are
noise, fastest ships, ties break toward the narrower ordering contract, and if
no mode beats the unbatched path by more than noise then the plan stops and the
design reopens. Clause four fired.

## Machine and build

Apple M3 Pro, macOS 26.5.1, Flutter 3.44.9, Dart SDK 3.12.2. **Impeller**, which
is the macOS default in 3.44 and which `apps/dev_harness_2d` does not opt out
of. Corpus and cameras exactly as Plan 3a's results note describes.

The four modes, all implemented in `CanvasDrawSink` and differing nowhere else:

| Mode | Buckets | Curves |
|---|---|---|
| `off` | none | per-leaf `save`/`transform`/`restore` |
| `openBucket` | one, flushed on any paint change | `canvas.transform`, flushes the bucket |
| `bucketMap` | one `Path` per paint key, held to end of frame | `canvas.transform`, flushes **every** bucket first |
| `bucketMapBakedCurves` | same | residual matrix baked in via `Path.addPath(matrix4:)` |

## The measurement

Three runs of each mode, 500,000 entities, working-set camera, `flutter drive`
in profile mode. Within-mode spread was about 1.5 ms; between-mode differences
are dozens to hundreds of milliseconds, so the ranking is nowhere near the
noise floor.

| Mode | raster p50, median of three | vs `off` | build p50 |
|---|---|---|---|
| `off` | **179.63 ms** | baseline | 9.44 ms |
| `bucketMap` | 187.19 ms | +4.2% — inside the noise band, a tie | 8.14 ms |
| `openBucket` | 229.37 ms | **+27.7% slower** | 8.47 ms |
| `bucketMapBakedCurves` | 490.19 ms | **+172.9% slower** | 7.53 ms |

**No mode beats the unbatched path. The most batched mode is the slowest by a
factor of 2.7.**

## The record/raster split, which is the actual finding

The recording side behaves exactly as the hypothesis predicted. R1 is a debug
JIT `PictureRecorder` run that records without rasterising:

| Mode | R1 paint p50 | real `Canvas` draw calls |
|---|---|---|
| `off` | 6.96 ms | 7,009 |
| `openBucket` | 5.77 ms | 6,642 |
| `bucketMap` | 5.46 ms | 4,542 |
| `bucketMapBakedCurves` | 4.11 ms | **10** |

Draw calls collapse by three orders of magnitude and recording gets 40% cheaper.
Then rasterising the result costs 2.7 times as much.

So the cost is not in dispatching draw calls. **A single path holding tens of
thousands of subpaths is cheap to record and expensive to rasterise**, and
whatever binds the 179 ms is something a smaller op count does not relieve.
Impeller tessellates a path as a unit, which is a plausible mechanism, but this
spike measured the effect and not the cause.

`openBucket` deserves its own line: it merges almost nothing (6,642 calls
against `off`'s 7,009), because the corpus assigns eight layers round-robin and
adjacent handles rarely share a paint — and it is still 27.7% slower than `off`.
Deferring `canvas.save()` out of `beginResidual` and rebuilding a path per run
costs more than the handful of merges buys.

## Two follow-ups, and what they settled

**Skia on macOS: no measurement is possible.** `--enable-impeller=false` is
rejected as a syntax error; `--no-enable-impeller` is accepted and then ignored
— Flutter's own help says "On other platforms, this flag will be ignored", and
a confirmatory `off` run under it landed at 181.95 ms, 1.3% from the Impeller
figure and inside that mode's own noise. **Whether the result is "batching does
not help" or "one giant path is bad for Impeller's tessellator" cannot be
settled on this machine.**

**The web op ceiling does not reproduce.** Plan 3a recorded a hard
`RuntimeError: Aborted()` inside `finishRecordingAsPicture` for the 500,000
entity whole-drawing frame on CanvasKit, at about 3.4 million ops, and called it
"a hard limit". Re-run against the current tree, on the same corpus, camera and
toolchain, **all four modes completed**:

| Mode | whole-drawing 500k on CanvasKit | draw calls |
|---|---|---|
| `off` | completed | 1,134,900 |
| `openBucket` | completed | 1,074,725 |
| `bucketMap` | completed | 733,805 |
| `bucketMapBakedCurves` | completed | 10 |

Nothing aborted, so this says nothing about whether batching lifts an op ceiling
— the ceiling was never reached. What it does say is that **Plan 3a's results
note, item 5, should not be treated as a live constraint without re-checking
it.** The leaf count is unchanged from 3a (1,134,900 draw calls against 3a's
3,405,300 painter ops, which was three ops per leaf over the same 1.135 million
leaves), so the difference is in what reaches the picture, not in what is drawn.
No explanation here is better than a guess, and none is offered.

## What this leaves

1. **Batching does not ship.** Not in any mode, on the evidence available.
2. **The 179 ms is unexplained.** It is not draw-call dispatch. Until something
   identifies what it is, a cache designed to reduce work per frame is being
   designed against an unknown, which is the position Plan 3a's whole method
   exists to avoid.
3. **The one platform where op count was proven to matter no longer
   demonstrates it.** That was the last argument for shipping a mode that loses
   on the measured platform, and it is gone.
4. Two things from Plan 3b's earlier tasks stand on their own and are unaffected:
   the cull floor and the style memo are still measured losses and stay deleted,
   and carrying every line-like leaf into screen space is speed-neutral
   (`off` at 179.63 ms against 3a's 182.73 ms) while removing a code path and a
   stroke-width approximation.

## Operational note

The macOS `flutter drive` stall Plan 3a documented fires on **any** move to the
background, including a tooling timeout that reparents the command — not only an
explicit background flag. It reproduced twice here. The process stays alive at
0.0% CPU with its `TIME` frozen and never recovers; killing it and re-running
the identical command works immediately.
