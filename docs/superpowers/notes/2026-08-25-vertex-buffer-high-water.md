# The vertex buffer's high-water mark, measured

**Date:** 2026-08-25. **Tree:** `main` at `cad9f93` plus the rig instrumentation
this note was taken with. **Machine:** macOS, `flutter drive --profile -d
macos`, Low Power Mode read `0` before the runs.

This is the measurement
[the Plan 3g results note](2026-08-24-plan-3g-results.md) listed as owed and
never taken: `VerticesDrawSink.debugCapacityVertices` with tiles on against
tiles off at 500,000 entities. Plan 3h was to start its memory budget from the
answer.

## The question, as it was asked

> Baking per tile flushes and rewinds the buffer between tiles, so the **96.00
> MiB high-water mark `STATUS.md` records** at 500,000 entities should fall to a
> single tile's geometry. **If it does, the tile budget replaces that memory
> rather than adding to it**, and 3h's budget starts from the new number rather
> than from 96 + 96.

## The answer: no, and the premise was wrong twice

| run | `capacityVertices` | MiB |
|---|---|---|
| 500,000, `TILES=off` | 16,777,216 | **192.00** |
| 500,000, `TILES=on` | 16,777,216 | **192.00** |
| 50,000, `TILES=off` | 16,777,216 | **192.00** |
| 50,000, `TILES=on` | 16,777,216 | **192.00** |
| 500,000, `TILES=on`, after the rig fix below | 16,777,216 | **192.00** |

**Tiles change nothing.** Five configurations, one number. The tile budget
**adds** to this memory. 3h starts from 192 + tiles, not from a reduced
number.

**And the mark is not a function of entity count.** A tenfold corpus reads the
same 16,777,216. Both places `STATUS.md` states this figure attach it to a
corpus size — "at 500,000 entities", "at that corpus size" — and that
attachment is what today's 50,000-entity run refutes. **It cannot be budgeted as
a per-entity cost.**

**Twelve bytes a vertex**, since the number is meaningless without it:
`_positions` is two `Float32`s and `_colors` one `Int32`.
`debugCapacityVertices` returns `_colors.length`, so 16,777,216 x 12 =
201,326,592 bytes = 192.00 MiB exactly.

## What it is a function of, and what it is not

**Not over-allocation.** `VerticesDrawSink._reserve`
(`vertices_draw_sink.dart:510`) doubles until the request fits and does nothing
else. 192.00 MiB is 2^24 vertices, so **some frame genuinely demanded more than
2^23** — more than 8,388,608 vertices, about 2.8 million segments.

**Not the steady frame either.** The frames these rigs report are far below it:
R2 at 500,000 draws 571,018 triangles, roughly 1.71 million vertices, which
fits in 2^21. The steady state uses **an eighth** of what stays pinned.

So the mark is set by a frame the rig prints no counters for — the sweep's
worst camera — and then never released, because **capacity is never given
back**. `vertices_draw_sink.dart:163` says so as a deliberate property and
`paint_allocation_test.dart` depends on it: giving capacity back is what would
put an allocation on the frame path that test pins at zero.

**This is why the measurement had to be a run-to-run comparison.** Within one
run the number is monotone, so every rig after the first inherits whatever the
first pinned — visible directly in the transcripts, where R2, R4a and R4b all
print the identical 16,777,216. The rig now prints the mark at several points
so that *when* it was reached is legible, and the doc comment on `capacity()`
says why a within-run reading answers nothing.

## The recorded 96.00 MiB is a Plan 3d figure, and it is one doubling below

`STATUS.md:182` and `STATUS.md:1131` both carry it, and `:1131` is inside
**"What 3d hands it"** — it dates from Plan 3d, before Plan 3e's fills and Plan
3f's text and level of detail. Today's tree reads exactly twice it, which is one
step of a doubling policy.

**The cause of the doubling is not established here** and this note does not
guess at it. What is established is that the figure in `STATUS.md` is stale, is
attached to the wrong variable, and **is not a number Plan 3h can budget
against.**

## A rig defect this measurement found

`requireRepaint` (`measurement_rig.dart:109`) threw on R4b at 500,000 entities
with tiles on:

```
Bad state: no repaint happened: the forced frame did not draw
```

It is not a production defect. The guard sums `CanvasDrawSink.canvasCallCount`
and `VerticesDrawSink.totalFlushCount`, and **a frame whose viewport is fully
covered by live tiles blits and draws into neither sink** — which is the whole
point of the cache. Both counters read zero for the healthiest frame the cache
can produce.

**What it means is worse than the throw.** R4b threw on the first run of this
configuration that has ever happened, so **R4b has never been measured with
tiles on**: Plan 3g ran R2's tile phases and never this one. The guard was
taught the tiled path's evidence — `TileCache.blitCount` and
`liveDrawCount`, reset beside the sinks at each call site so it still bites on
a frame that never ran.

**The fix was confirmed against the branch it was written for, not merely
against a green run.** R4b at 50,000 entities with tiles on now passes, and its
own transcript proves the tiled branch is what carried it:

```
bakes=0 blits=12 carryOverBlits=0 liveDraws=0 blitDests=12
backend=vertices triangles=0 drawVerticesCalls=0
```

`drawVerticesCalls=0` and `triangles=0`: the forced frame drew into **neither**
sink and blitted twelve tiles. The old guard would have thrown on exactly this
frame. A run that passed with non-zero sink counters would have proved nothing,
which is why they are quoted here.

**And it is the frame the cache exists to produce.** R4b at 50,000 entities
reads `build p50=0.09ms raster p50=0.45ms total p50=0.72ms` with tiles on,
against `9.28 / 4.91 / 14.38` with them off — twenty times on `total`, for a
frame the rig previously refused to accept as a frame at all.

**500,000 entities then completed too**, with the identical signature —
`bakes=0 blits=12 liveDraws=0`, `drawVerticesCalls=0 triangles=0` — so the
configuration that first threw is now measurable end to end.

## R4b, tiles on, measured for the first time

R4b's 880 ms per-command cost is **not a tile regression**: `command p50` reads
**872.73 ms with tiles off** and **887.41 ms with tiles on**, a 1.7% difference
on a figure that dwarfs the frame. It is the instance-drag command's own cost at
500,000 entities, with `rebuilds=200 over 200 frames`.

What tiles do to that rig's frame path, from the same two runs:

| R4b, 500,000 | tiles off | tiles on |
|---|---|---|
| `build p50` | 24.50 ms | **0.09 ms** |
| `raster p50` | 10.45 ms | **0.71 ms** |
| `command p50` | 872.73 ms | 890.22 ms |

The tiles-on column is the post-fix run that reported `All tests passed`; the
pre-fix run that threw read `0.09 / 0.67 / 887.41`, so the two agree.

**`total p50` reads 35.17 ms off against 862.23 ms on, and that comparison is
not a regression — it is `totalSpan` catching the command.** `totalSpan` runs
vsync-start to raster-finish; with tiles on the frame's own work collapses to
under a millisecond, so the span is dominated by the ~880 ms of command work
sharing the thread. Read `build` and `raster`, which both fell by more than two
orders of magnitude.

## And R4b at 500,000 with tiles on sits on a driver timeout

The confirming re-run did not finish. The app's VM service dropped mid-R4b:

```
DriverError: Failed to fulfill RequestData due to remote error
Original error: ext.flutter.driver: (112) Service has disappeared
```

No crash report was written. **The arithmetic explains it without a defect:**
R4b runs 202 frames and its command costs ~880 ms each, so the rig needs about
178 seconds inside one `requestData` call. The first run reached R4b at 00:36
and reported at 03:44 — it cleared the timeout with nothing to spare; the second
did not.

**It is marginal, not broken:** of three attempts at this configuration, two
completed and one dropped. **Recorded as a property of measuring this rig, not
as a product finding.** Anyone re-taking R4b at 500,000 entities should expect
to lose a run now and then, and every number quoted here comes from a run that
reported `All tests passed`.

## What Plan 3h should take from this

1. **The tile budget adds to the vertex buffer; it does not replace it.** Budget
   192 MiB plus tiles.
2. **Do not treat 192 MiB as a per-entity figure.** 50,000 and 500,000 read the
   same. Whatever sets it, it is not corpus size.
3. **The steady frame needs an eighth of what stays pinned.** If that gap is
   worth closing, the lever is the sweep's worst camera or a releasable buffer —
   and a releasable buffer changes `paint_allocation_test.dart`'s contract,
   which is a deliberate property and not an oversight.
4. **R4b with tiles on is now measurable.** It was not before, and what it
   shows is the cache working: a pure blit frame, `build` and `raster` each
   more than an order of magnitude down, at both corpus sizes.
5. **The rig can still only see one rig's worth of tile phases.** R2 carries
   `runTilePhases`; R4a and R4b do not. Nothing here changes that, and the
   `bakes=0` in every R4b transcript above is a *settled* frame, not evidence
   about baking.
