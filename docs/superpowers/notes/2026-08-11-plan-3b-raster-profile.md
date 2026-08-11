# What the 179 ms actually is

The batch spike established the negative: raster time is not draw-call
dispatch — collapsing 7,009 calls to 10 made rasterising 2.7x *slower*. This
task asks the positive question the spike left open: does raster time scale
with the number of drawn leaves, or with the number of shaded pixels? Three
controlled experiments answer it before any profiler is touched, and a
profiler capture then attributes it on the GPU.

**Answer: the cost tracks leaf count, not pixel count — but softer than
"proportional."** A 2.09x leaf-count change produced a 2.42x time change, not
a 2.09x one: real, leaf-count-dominated, and slightly super-linear on top of
that, not a clean 1:1. Vertex-stage GPU work — not fragment/fill — is what a
real capture shows dominating, and that is consistent with everything below.
Plan 3e should read the magnitude as softer than a confident one-line headline
would suggest: enough to justify a leaf-reducing cache, not enough to promise
that halving leaves exactly halves raster time.

## Machine and build

Apple M3 Pro, macOS 26.5.1, Flutter 3.44.9, Dart SDK 3.12.2, Impeller (the
macOS default, unchanged from the batch spike). Same corpus generator, same
working-set camera as Plan 3a and the batch spike. `RIG=pan` throughout —
`R2`'s 120 pan frames + 120 zoom frames.

## Experiment A — vary leaf count, hold the camera

`ENTITIES=500000` and `ENTITIES=50000`, same working-set camera, two runs
each.

| Entities | Run | raster p50 | raster p95 | build p50 | screenSpaceLeafCount |
|---|---|---|---|---|---|
| 500,000 | 1 | 170.02 ms | 178.70 ms | 9.56 ms | 4,679 |
| 500,000 | 2 | 171.17 ms | 178.41 ms | 9.53 ms | 4,679 |
| 50,000 | 1 | 70.46 ms | 74.54 ms | 4.11 ms | 2,237 |
| 50,000 | 2 | 70.42 ms | 74.37 ms | 4.10 ms | 2,237 |

Within-condition spread is negligible (170.02 vs 171.17; 70.46 vs 70.42), so
medians stand without a third run: **170.60 ms** raster at 500k,
**70.44 ms** at 50k.

- Entity count scaled by **10.0x** (500,000 / 50,000).
- `screenSpaceLeafCount` scaled by **2.09x** (4,679 / 2,237) — the working-set
  camera shows roughly the same world-space window regardless of corpus
  density, so most of that 10x never reaches the screen.
- Raster p50 scaled by **2.42x** (170.60 / 70.44).

**Time scaled by 2.42x when the drawn leaf count scaled by 2.09x — far closer
to leaf-count-proportional than to entity-count-proportional (10x) or flat.**
It is not an exact 1:1 (2.42 against 2.09 is about 16% more time growth than
leaf growth), so the relationship is slightly super-linear in leaf count
rather than perfectly linear. Two things sit inside that residual 16%, and
the note should not collapse them into one vague "more points per leaf":

1. **A structural confound in the corpus, not just denser geometry.**
   `harnessDocument()` (and this task's direct calls to `generateDocument`)
   hold `definitionCount: 200` and `instanceCount: 20000` fixed while
   `entityCount` scales 10x from 50k to 500k. Entities-per-definition rises
   with corpus size, so A is not a clean "same drawing, more copies of the
   same shapes" scaling — it is "same number of definitions and instances,
   each definition carrying more geometry." Some of the extra 16% is
   plausibly the extra points-per-leaf that denser definitions carry (each
   `screenSpaceLeafCount` unit doing slightly more work), and some is
   plausibly this instancing-density shift changing how much of the walk and
   paint concentrate inside fewer, busier definitions. Neither was isolated
   here; both are consistent with leaf-count dominance, but the exact split
   is not known.
2. Given that confound, "halving the leaf count roughly halves the raster
   time" is the right shape of the finding but not a precise guarantee — **a
   cache that reduces leaves drawn per frame is addressing the right lever,
   sized to something a bit larger than 1:1 rather than exactly 1:1.**

Build p50 moved in step (9.545 ms → 4.105 ms, a 2.33x ratio), which makes
sense: build cost is the walk, and the walk visits roughly the same set of
things the paint step draws.

### Reconciling `screenSpaceLeafCount` against Plan 3a's leaf counts

Plan 3a's results note reports "about 3,670 and 7,010 leaves on the working
set" for the 50k/500k working-set cameras — 33–40% higher than this task's
2,237 and 4,679. Both numbers are correct; they count different things, and
that has to be on the record rather than left as a silent mismatch a later
plan could build on.

3a's figure is `opsPerFrame / 3` from R1, the debug-JIT `PictureRecorder` rig
using `NullDrawSink`. `NullDrawSink.opCount` increments once for
`beginResidual`, once for the geometry call, once for `endResidual` — three
ops per leaf, for **every** leaf kind `DraftPainter` draws: points, lines,
polylines, circles and arcs all go through that same
beginResidual/geometry/endResidual shape, whichever of the two paths
(screen-space or residual) they take. `screenSpaceLeafCount` is a different,
narrower counter, redefined in Task 1: it increments only inside
`_drawLeafComposed`'s `point`/`line`/`polyline` case — the screen-space path.
Circles and arcs always take the residual path and are structurally excluded
from it, by design, not by omission (see `DraftPainter.screenSpaceLeafCount`'s
own doc comment).

So 3a's number is "every leaf drawn" and this task's is "every leaf drawn via
the screen-space path" — a strict subset. The two ratios stay close (this
task's 2.09x against 3a's 7,010/3,670 = 1.91x) because the point/line/polyline
share of the corpus is proportionally similar at both sizes, not because the
two counters measure the same thing. A cache or any other Plan 3e mechanism
that reads "leaves drawn" from either note needs to know which of these two
definitions it is getting.

## Experiment B — vary stroke width, hold everything else

Added `--dart-define=LINEWEIGHT_SCALE` (see "Harness change" below), which
multiplies every stroke's device-pixel width at the sink and nowhere else.
Geometry, draw-call count and the walk are byte-identical across 1x, 2x and
4x — only each stroke's own shaded area changes. `ENTITIES=500000`,
`RIG=pan`, two runs per multiplier (1x reuses Experiment A's 500k runs,
since `LINEWEIGHT_SCALE=1.0` is the harness default and produces an
identical binary).

| Scale | Run | raster p50 | raster p95 | build p50 | screenSpaceLeafCount |
|---|---|---|---|---|---|
| 1x | 1 | 170.02 ms | 178.70 ms | 9.56 ms | 4,679 |
| 1x | 2 | 171.17 ms | 178.41 ms | 9.53 ms | 4,679 |
| 2x | 1 | 173.80 ms | 182.77 ms | 9.54 ms | 4,679 |
| 2x | 2 | 177.55 ms | 184.89 ms | 9.60 ms | 4,679 |
| 4x | 1 | 180.18 ms | 187.42 ms | 9.55 ms | 4,679 |
| 4x | 2 | 180.52 ms | 188.18 ms | 9.47 ms | 4,679 |

Medians: 1x = 170.60 ms, 2x = 175.68 ms (+3.0%), 4x = 180.35 ms (+5.7%).
`screenSpaceLeafCount` and build p50 are flat across all three, confirming
the multiplier touches nothing but how much of each stroke's own area is
shaded.

### B's denominator is overdraw, not coverage — and it scales exactly by construction

Fragment shading cost tracks **fragment invocations**: every stroke's own
area, counted separately, overlaps included. That is overdraw — total
`Σ (screen-space polyline length × stroke width)` — and it is a different
quantity from *coverage*, which is the union of what got touched at all and
saturates at 100% of the viewport. `LINEWEIGHT_SCALE` multiplies every
stroke's width and touches nothing else — not length, not draw-call count,
not the walk — so overdraw scales **exactly linearly by construction**: 2x
at `LINEWEIGHT_SCALE=2.0`, 4x at `4.0`. No measurement is needed to know
that, and none could disagree with it.

**Time grew 5.7% when fragment work (overdraw) grew 4x. Fill rate is a minor
contributor, not the dominant one.** That is B's conclusion, and it is the
one the experiment was designed to produce.

### A separate finding: the working-set scene is already ~99.5% covered

Before settling on overdraw as B's denominator, this task tried measuring
*coverage* instead — the union of touched pixels — using the technique the
deleted `batch_equivalence_test.dart` used for its own pixel-level proof:
`PictureRecorder` → `DraftPainter.paint` → `Picture.toImage` →
`toByteData(rawRgba)`, on the same working-set scene and camera as the rig,
at a plain `test()` (no widget, no window) so it needed no profile-mode run.
Written as a throwaway test, run once per `LINEWEIGHT_SCALE`, then deleted —
it is not part of the suite.

The first attempt counted pixels differing from a white background fill and
got a nonsensical result: coverage *fell* as width grew (0.87x at 2x, 0.77x
at 4x). The cause was the background choice, not the render: the corpus
draws some layers in white — `ByLayerColor` resolving through layer 0 to ACI
7, which the deleted test's own comments called out by name as "white on the
white background." A white stroke is invisible against a white background,
and worse, a *widened* white stroke visibly painted back over other, already
non-white ink, erasing it toward white and shrinking the naive count as the
scale grew. Fixed by drawing no background at all (`PictureRecorder`'s
canvas starts transparent) and counting pixels with alpha > 0 — coverage by
"was any ink drawn here," regardless of that ink's colour:

| LINEWEIGHT_SCALE | covered pixels | of 1,920,000 (1600x1200) |
|---|---|---|
| 1x | 1,911,000 | 99.531% |
| 2x | 1,919,800 | 99.990% |
| 4x | 1,920,000 | 100.000% |

**The working-set scene is already ~99.5% covered at 1x** — essentially
solid ink, with almost no white space left. That is a fact about this
corpus's density, not a measurement of fill-rate sensitivity, and it stands
on its own: it is what makes fill rate a reasonable suspect in the first
place (a nearly-solid viewport is exactly the situation where per-pixel
cost would be expected to matter), and it bounds what any leaf-culling
mechanism can achieve on this working set — the visible area is already
almost entirely touched by *something*, so culling reduces which leaves
contribute to a pixel, not how many pixels have contributions.

**Coverage was the wrong instrument for B, and it is worth saying plainly so
the mistake isn't repeated:** an already-saturated scene cannot report a
change in a quantity that is pinned at its ceiling. Coverage moving from
99.531% to 100.000% is not evidence that "not much changed" when width
quadruples — it is evidence that coverage was never the quantity fragment
shading cost depends on. Overdraw, which has no ceiling and scales exactly
with the multiplier by construction, is that quantity, and it is what B's
5.7%-against-4x conclusion above is stated against.

## Experiment C — vary the viewport (dropped)

Attempted by assigning `tester.view.physicalSize = tester.view.physicalSize *
2.0` inside `boot()` before the camera fit, at `ENTITIES=500000`. Two runs.

| Run | raster p50 | raster p95 | build p50 | screenSpaceLeafCount | reportedPhysicalSize |
|---|---|---|---|---|---|
| 1 | 0.00 ms | 0.00 ms | 10.60 ms | 4,861 | (unprintable — see below) |
| 2 | 0.00 ms | 0.00 ms | 10.44 ms | 4,861 | 3200.0 x 2400.0 |

`tester.view.physicalSize` **did** change what the widget tree believes: the
reported size doubled from the default 1600x1200 to 3200x2400 as instructed,
and `screenSpaceLeafCount` shifted (4,679 → 4,861) because `ViewportTransform
.fit` now maps the fixed world rect into a differently-proportioned screen.
(The first run's `reportedPhysicalSize` printed as `Instance of 'Size'`
rather than a value — profile-mode AOT compilation strips `Size.toString()`
in this build; the second run prints `.width`/`.height` directly instead,
which are plain `double`s and print correctly.)

But raster p50 and p95 both collapsed to **0.00 ms** for 241 of 242 frames in
both runs — only the first (cold-start) frame recorded a nonzero duration,
at a magnitude matching the *unscaled* baseline's own cold-start cost
(~2.2 s), not anything resembling a 4x-pixel-area steady-state cost. Build
time went up slightly instead of down, consistent with more layout work
producing no corresponding GPU-visible raster work.

**This means the real macOS window's backing surface was not actually
resized** — the widget tree's belief about its own size and what the engine
actually rasterises onto diverged, and the frame pipeline stopped doing (or
stopped reporting) real raster work once they disagreed. Per this task's
ambiguity resolution #2, **C is dropped**: it produces no reliable pixel-area
number on this rig. A and B together already separate per-leaf from
per-pixel work, which is why C was scoped as best-effort in the first place.

The `VIEWPORT_SCALE` code that produced this table was written directly in
`frame_timing_test.dart`, used for these two runs, and then **reverted** —
it does not appear in the committed harness diff, since it produces nothing
trustworthy and the brief's ambiguity resolution says to drop a C that
doesn't work rather than ship it.

## Step 2 — attributing it on the GPU

### Route 1: `flutter drive --profile --trace-to-file=<path>.binpb` — failed silently

Tried at `ENTITIES=500000` and (as a faster repeat) `ENTITIES=1000`, both
with `RIG=pan`. The flag is accepted by `flutter drive`'s argument parser
(confirmed via `--help -v`; the flag is `--trace-to-file=<path/to/trace.binpb>`,
Perfetto proto format, not literal Chrome JSON as the brief's phrasing
suggested — that's already a difference from what was expected). Every run
exited 0, printed no error, and **no trace file ever appeared at the
specified absolute path** — confirmed on disk and by `find`. A full run
under `-v` (verbose) produced no line anywhere containing "trace",
"timeline" or "binpb" connected to this flag (the only "trace" hits were
unrelated Clang/DTrace build environment variables). Conclusion: this flag
is silently inert for `flutter drive -d macos` in Flutter 3.44.9, at least
in this configuration — not implemented, or gated on something undiscovered
within budget.

### Route 2: Xcode Instruments (`xctrace`), Metal System Trace — succeeded

`xctrace` (Xcode 16.0) is scriptable from the command line with no GUI
interaction required (`xcrun xctrace record`), which matters in this
environment.

**`--launch` sub-mode failed.** `xctrace record --template "Metal System
Trace" --launch -- <path-to-binary> --no-prompt` starts the target process
itself. `ps aux` showed it sitting in **`T` (stopped)** state for the entire
20-second recording window — it never ran. The recording "succeeded" (exit
messages looked normal) but captured nothing of the app, because the app
never executed. This is consistent with a developer-tools/ptrace permission
gate that an interactive Xcode/Instruments session satisfies via a one-time
GUI prompt, which `--no-prompt` skips rather than grants, in this
non-interactive session.

**`--attach` sub-mode worked.** Built the harness's ordinary interactive
target — `flutter build macos --profile --dart-define=ENTITIES=500000`
(not the integration-test rig binary, which is a `flutter_driver`-controlled
process rather than a normal interactive app) — and launched it with `open`.
A real on-screen window exists at a fixed position (confirmed via
`osascript`/System Events) and responds to synthetic OS-level mouse events:
`cliclick`'s `dd:`/`dm:`/`du:` drag commands visibly panned the drawing
(screenshotted before/after — the empty margin on the canvas's edge visibly
grew). `xctrace record --template "Metal System Trace" --attach
dev_harness_2d --time-limit <N>s --no-prompt` was then run in the background
while several drag gestures were issued during its window.

The `metal-gpu-intervals` table (exported via `xctrace export --xpath`) has
one row per GPU work interval, tagged with a `gpu-channel-name` (`Vertex`,
`Fragment`, or `Compute`) and a `process`. Instruments' XML export interns
repeated values — a value is written once with an `id`, and every later
occurrence is `<tag ref="id"/>` — so a small Python script
(`parse_gpu2.py`, kept in the scratchpad, not committed) resolves refs
against a first-pass `id → fmt` map and sums duration by channel and
process.

Two independent captures, each covering several manual pan drags at
`ENTITIES=500000`:

| Capture | Window | Vertex (dev_harness_2d) | Fragment (dev_harness_2d) | Compute | Vertex:Fragment |
|---|---|---|---|---|---|
| 1 | 15.910 s | 13,035.2 ms (812 intervals, avg 16.05 ms) | 5,289.9 ms (817 intervals, avg 6.47 ms) | ~0 | **2.46x** |
| 2 | 12.921 s | 7,161.1 ms (584 intervals) | 3,240.2 ms (592 intervals) | ~0 | **2.21x** |

**The Vertex-stage total exceeds the Fragment-stage total by 2.2–2.5x,
reproduced across two independent captures.** (The fraction of wall clock
spent busy differs between the two captures — 82%/33% in capture 1 versus
55%/25% in capture 2 — because how much of each window was spent actively
dragging versus idle is an artifact of manual `cliclick` timing, not a
property of the render path; the ratio between the two channels is the
stable signal, not their absolute share of the window.) As a control,
`WindowServer`'s own compositing channels in capture 1 are roughly
1:1 (10,373 ms Vertex vs 10,487 ms Fragment) — the 2.2–2.5x skew is specific
to this app's rendering, not a general property of Metal work on this
machine.

**Answering the brief's question directly: the dominant GPU cost is vertex
work, not fragment/fill.** This is not the same claim as "CPU-side
tessellation" — this capture is GPU-side only. It does not distinguish
whether Impeller does its own CPU-side path flattening ahead of the GPU
vertex stage (which would show up in a `time-profile` CPU stack sample, not
captured here). What it does rule out is GPU fragment/fill and blit/composite
as the dominant cost, and it is fully consistent with A and B: work that
scales with per-leaf geometry (vertex/tessellation load) dominates; work
that scales with shaded-pixel area (fragment/fill) does not.

### Route 3: `--trace-skia` + DevTools timeline — not attempted

Route 2 already produced a reproducible, corroborated attribution, and the
task's ~40-minute Step 2 budget was consumed by Route 1 (which failed
cleanly but took real time to confirm) and Route 2 (including diagnosing
the `--launch` stuck-process failure before finding `--attach`). Impeller is
also expected to leave Skia's own trace tracks empty on this rendering
backend, per the brief's own framing — so Route 3 was deprioritized in favour
of the working route rather than attempted and found empty.

## The batch spike's 2.7x, revisited

The batch spike found that merging ~7,000 draw calls into one giant `Path`
(`bucketMapBakedCurves`) made rasterising 2.7x *slower* (490 ms against 179
ms), not faster. This note's finding — the bottleneck is per-leaf vertex
work, not dispatch — explains why merging *didn't help*: collapsing draw
calls doesn't reduce the total vertex/geometry work Impeller has to
tessellate, so there was never a mechanism by which it should have won.

**It does not explain why merging made things worse.** If per-leaf vertex
work dominates and the total vertex count is roughly the same whether it
arrives as one `Path` or seven thousand, something about the *merged* shape
specifically got more expensive, and this note has not measured what.
Leaving that unconnected would let a reader assume "vertex work dominates"
is the whole story behind both numbers, when only the first is established.

One candidate, named as a hypothesis and not a finding: path-fill and
-stroke tessellation generally has to resolve overlaps and winding across
everything sharing one `Path` object, so tessellating ten thousand unrelated
subpaths *as one path* may require a joint resolution step that ten thousand
independent, small, locally-resolved draw calls do not — each separate
`drawPath` call only has to resolve winding within its own few points, and
relies on cheap GPU blending (not joint tessellation) to composite the
results together on screen. This is consistent with the batch spike's own
record/raster split — `bucketMapBakedCurves` had the *cheapest* recording
time of the four modes (4.11 ms), which rules out expensive `Path`
construction (`Path.addPath(matrix4:)` itself) as the mechanism, since that
cost would show up at recording time and didn't. It points instead at
something that only happens at rasterisation, when Impeller actually
tessellates the accumulated path — consistent with, but not proof of, a
joint winding-resolution cost.

**This is unconfirmed. What would settle it:** repeat this note's Route 2
capture (`xctrace`, Metal System Trace, `metal-gpu-intervals`, attached while
panning) against the `bucketMapBakedCurves` build. That build no longer
exists on this branch — Task 4b removed the batching machinery after the
spike refuted it — so answering this needs checking out the parent commit
(`b5e6a21^`, the commit immediately before the removal) into a scratch
worktree rather than reverting anything here. Not attempted in this task:
optional per the brief, and the honest "unexplained, here is what would
settle it" costs nothing that a wrong guess wouldn't cost more. If the
capture shows Vertex-stage time disproportionately larger for the merged
build (more than the leaf/vertex count alone would predict), that supports
the joint-resolution hypothesis; if some other channel dominates instead —
GPU submission stalls from one giant command buffer being unable to
pipeline the way many small ones can, say — that would point somewhere
else entirely, and the hypothesis above should be discarded rather than
defended.

## What this means for Plan 3e

The dominant cost is **GPU vertex-stage work that scales with the number of
drawn leaves** (Experiment A), **not fragment/fill work that scales with
overdraw** (Experiment B: overdraw quadrupled by construction and raster time
grew only 5.7%), and a direct GPU capture (Step 2, Route 2) attributes the
app's own GPU time to the Vertex channel over Fragment by 2.2–2.5x,
reproduced twice.

This decides between Plan 3e's candidate mechanisms:

- **A definition/tile cache that reduces the number of leaves walked and
  re-tessellated per frame is on the table** — it directly addresses the
  identified cost. Experiment A's near-halving of raster time under a
  near-halving of leaf count is exactly the effect such a cache would be
  built to produce.
- **A mechanism aimed only at reducing fill area** (thinner default
  strokes, crisper AA, fewer overlapping fragments) **would not address the
  dominant cost** — Experiment B quadrupled overdraw by construction (the
  width multiplier applies to every stroke and nothing else) and raster time
  grew only 5.7%, so fill rate is not where the time is going. (The
  working-set scene is separately measured at ~99.5% *coverage* at 1x —
  worth knowing on its own, since it is what makes fill rate a reasonable
  suspect at all, but it is not the quantity this bullet's conclusion rests
  on: coverage is already pinned near its ceiling and cannot be B's
  denominator.)
- **A mechanism aimed only at reducing transform pushes / draw-call count is
  already refuted** by the batch spike: the most call-collapsed mode was
  2.7x slower, not faster, which is consistent with this note's finding that
  the bottleneck is downstream of dispatch, in per-leaf GPU geometry work.

**Open gap, honestly stated:** whether there is a *separate, significant*
CPU-side tessellation cost ahead of the GPU vertex stage (Impeller's own
path flattening, say) was not measured here — only the GPU-side channel
breakdown was captured, within the Step 2 time budget. If Plan 3e's design
needs to choose between caching raw (untessellated) geometry versus caching
GPU-ready (tessellated) geometry, that CPU/GPU split still matters and
remains open. A `time-profile` capture via the same `xctrace --attach`
recipe below (swap the template for "Time Profiler" or add it as an
`--instrument`) is the natural next step, not attempted here.

## Harness change: `LINEWEIGHT_SCALE`

Added for Experiment B, permanent, inert at its default:

- `packages/jet_cad_2d_flutter/lib/src/canvas_draw_sink.dart` —
  `CanvasDrawSink` gained a `lineweightScale` field (default `1.0`), applied
  in `_widthFor` as a multiplier on the computed device-pixel width, nowhere
  else. Not read by `DraftPainter` or `StyleResolver` — the point of the
  experiment is that only the sink's idea of width changes, leaving
  geometry, draw-call count and the walk untouched.
- `packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart` — `DraftCanvas`
  gained a matching `lineweightScale` constructor parameter (default `1.0`),
  forwarded to the sink and included in `didUpdateWidget`'s re-attach check.
- `apps/dev_harness_2d/lib/main.dart` — a `kLineweightScale` top-level value
  parses `--dart-define=LINEWEIGHT_SCALE`. There is no `double.fromEnvironment`
  in Dart, so (unlike `kEntities`) it is not `const`: it parses the string
  define with `double.tryParse` at startup instead, falling back to `1.0`.
  Passed straight through to `DraftCanvas`.
- `apps/dev_harness_2d/integration_test/frame_timing_test.dart` — `boot()`
  now also returns the `DraftPainter` (reached via
  `tester.state<DraftCanvasState>(find.byType(DraftCanvas)).painter`, which
  is public exactly so a rig can do this), and the R2 pan rig prints
  `screenSpaceLeafCount` and `lineweightScale` after its report.

## Capture recipe, for next time

```bash
# Experiment A: vary ENTITIES, same command otherwise.
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart --profile -d macos \
  --dart-define=ENTITIES=500000 --dart-define=RIG=pan

# Experiment B: vary LINEWEIGHT_SCALE, ENTITIES fixed.
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart --profile -d macos \
  --dart-define=ENTITIES=500000 --dart-define=RIG=pan \
  --dart-define=LINEWEIGHT_SCALE=4.0

# GPU attribution (Route 2): build the interactive app, not the test rig.
flutter build macos --profile --dart-define=ENTITIES=500000
open build/macos/Build/Products/Profile/dev_harness_2d.app

# Record while panning by hand, or drive the window with cliclick
# (brew install cliclick) — dd:/dm:/du: for drag-down/move/up. --launch
# leaves the target process stopped and captures nothing; --attach an
# already-running instance instead.
xcrun xctrace record --template "Metal System Trace" --time-limit 15s \
  --no-prompt --output metal-trace.trace --attach dev_harness_2d

xcrun xctrace export --input metal-trace.trace \
  --xpath '/trace-toc/run[@number="1"]/data/table[@schema="metal-gpu-intervals"]' \
  --output gpu-intervals.xml
# Then resolve id/ref and sum duration by gpu-channel-name and process —
# see parse_gpu2.py's approach in this task's report.
```

Every `flutter drive` run above must be foregrounded with a long explicit
timeout, per the operational note both this task and the batch spike
inherited: any move to the background stalls the process at 0% CPU,
recoverable only by `pkill -9 -f dev_harness_2d.app` and an identical retry.
