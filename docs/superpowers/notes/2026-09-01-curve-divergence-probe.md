# The curve divergence, decomposed

**2026-09-01.** A spike, not a plan: the output is an answer and one test.
Everything measured here ran on `main` at `67d73b0`, through
`flutter test`, at `devicePixelRatio` 1 unless a row says otherwise.

## The question

Plan C recorded exit-gate criterion 1 as **SPLIT**: straight geometry
pixel-exact (`differing == 0`), curves missing at **16.5%** (circle) and
**17.0%** (arc) of their own ink. It named a cause — *the reference emits
every dash span as its own `arc()` op and re-chords each one independently,
so its chord vertices sit in different places from the resident arm's* — and
gated the result with a loose 25%-of-ink tripwire that says in its own
`reason` that it is a tripwire and not a criterion.

**The cause was asserted, never decomposed.** Four things could produce it:
the flattener, the residual (these curves sit under a non-uniform instance,
so they are ellipses), the dash phase arithmetic, or the re-chording. Nobody
had measured which.

## What was measured

### 1. The same geometry, dashed against solid

The decisive experiment, and it had never been run: the same circle and the
same arc, same placement, same residual, same flattener — solid instead of
dashed.

| probe | referenceInk | differing | |
|---|---|---|---|
| dashed circle 911 | 994 | 128 | 12.9% |
| **solid circle, same geometry** | 1488 | **0** | **0.0%** |
| dashed arc 912 | 566 | 81 | 14.3% |
| **solid arc, same geometry** | 844 | **0** | **0.0%** |

**The flattener, the residual, the ellipse path and the chord count are
exonerated outright.** Every one of them is exercised identically by the
solid twin, which agrees pixel for pixel. Whatever the divergence is, it
enters with dashing.

### 2. It does not scale with the number of dash edges

`header.globalLinetypeScale` multiplies every pattern, so halving it halves
the period and doubles the edge count on the same geometry at the same
camera.

| global linetype scale | differing |
|---|---|
| 2.0 | 136 |
| 1.0 | 132 |
| 0.5 | 132 |
| 0.25 | 238 |

**Four times the dash edges, the same disagreement.** (The 0.25 row is a
different phenomenon: the period there approaches `kDashCollapsePx` and the
two arms disagree about whether the pattern has collapsed at all.) So the
divergence is not "each dash end lands somewhere slightly different" — that
would track the edge count.

### 3. It does not accumulate along the sweep

Same radius, same period, arcs of growing sweep:

| sweep (rad) | referenceInk | differing | |
|---|---|---|---|
| 0.4 | 400 | 84 | 21.0% |
| 1.0 | 487 | 67 | 13.8% |
| 2.0 | 563 | 49 | 8.7% |
| 3.3 | 566 | 81 | 14.3% |
| 6.0 | 983 | 135 | 13.7% |

No trend. A phase error that drifted as the walk advanced would grow with
the sweep; this does not.

### 4. It falls as the stroke widens — and that is the signature

Identical geometry, only the lineweight changes:

| lineweight | referenceInk | differing | fraction |
|---|---|---|---|
| 10 | 566 | 81 | 14.3% |
| 25 | 566 | 81 | 14.3% |
| 100 | 2160 | 84 | 3.9% |
| 400 | 8679 | 165 | 1.9% |

**The differing count is nearly flat while the ink grows fifteenfold.** The
disagreement is a *boundary band* along the stroke, not a fraction of its
area. (Lineweights 10 and 25 read identically because both floor at
`kMinStrokeDevicePixels`, which is a free internal check that the harness is
measuring what it claims.)

### 5. The mechanism, confirmed from the other side

If the band is the lateral gap between two different chordings of the same
curve, it is bounded by the flattener's sagitta — so tightening the chord
tolerance in **both** arms must collapse it. `kFlattenTolerance` 0.25 → 0.02
(a temporary mutation of both `geometry_collector.dart` and
`vertices_draw_sink.dart`, restored from `cp` backups):

| probe | at 0.25 px | at 0.02 px |
|---|---|---|
| dashed arc 912 | 81 differing (14.3%) | **1** differing (0.2%) |
| dashed circle 911 | 93 differing (16.3%) | **4** differing (0.7%) |
| solid arc | 0 | 0 |

## The answer

**The divergence is the lateral offset between two chordings of one curve,
and its size is set by the flattener's sagitta.** The reference re-chords
every dash span independently; the resident arm chords the whole sweep once.
Two different chordings of the same arc sit up to a sagitta apart laterally,
and at a one-to-two device-pixel stroke width a sub-pixel lateral offset
repaints most of the edge pixels along the whole inked length. That is why
the disagreement is flat in dash period, flat in sweep, flat in absolute size
as the stroke widens — and why it is large as a *fraction* only because a
thin stroke is nearly all boundary.

Plan C's recorded cause was right. Its framing was not: the number was
reported as a percentage of ink, and that percentage moves by 7× on identical
geometry with no change to a single differing pixel's cause.

## What follows from it

**Closing criterion 1 on curves by tightening the tolerance costs
criterion 6, measured:** at `kFlattenTolerance = 0.02` the 10,000-entity
corpus goes from 106,636 instances / **6.51 MB** to 330,975 instances /
**20.20 MB**, against an 8 MB budget. A 2.5× budget overrun buys a 0.2%
divergence. **Not done, and recorded as the price rather than taken.**

Two changes landed here instead:

1. **The tripwire is now an absolute pixel count, not a fraction of ink** —
   900 for the circle, 550 for the arc, roughly 1.5× the 2026-09-01
   measurements of 607 and 365. A fraction-of-ink bound is not a bound: the
   same disagreement reads 14.3% or 1.9% depending only on how wide the
   stroke is.
2. **A solid twin of each curve is now gated at `differing == 0`.** This is
   the real gain: it converts the exonerating half of this probe into a
   standing test. The flattener, the residual and the chord count agreeing
   exactly is now something a regression breaks loudly, instead of being
   absorbed into a curve's permitted divergence. Mutation fired: the
   collector flattening one step finer than the oracle
   (`(ideal + 1).clamp(...)`) gives `Expected: <0> Actual: <762>`.

**Still open, and now open with a price attached:** whether the resident arm
should reproduce per-span chording at all. It cannot without choosing chord
counts from a span set that exists only at one camera — which is the baking
Plan C exists to undo. The honest resolution is probably a band statement
from Plan F's watermark rather than a fix here.
