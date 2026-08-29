# One render object per entity — a throwaway spike, and what it settled

**Date:** 2026-08-29. **Branch:** `spike/widget-per-entity`, cut from `c22cd90`,
**deleted after this note was written.** Its two commits were `490d1f4` (the
three arms) and `6367e13` (the three instrument defects the smoke run found).
Recoverable from the reflog for as long as git keeps it.

**Status: answered, and the answer is not the one the timing suggests.** At
floor-plan scale the widget approach is fast enough. It is still the wrong
architecture, for reasons no measurement touches.

---

## The question, and the premise that had to be corrected first

The human asked why the CAD canvas does not use Flutter's widget render
infrastructure, given that it is fast and GPU-accelerated.

**It already does.** `DraftCanvas.build` returns
`RepaintBoundary(child: CustomPaint(painter: ..., size: Size.infinite))`
(`draft_canvas.dart:358`). Both are widgets. The `Canvas` a `CustomPainter`
receives is the same `Canvas`, the same layer tree, the same `Scene` and the
same Impeller as every other widget. There is no separate accelerated path
being missed.

The question that survives the correction is real and worth measuring:

> One render object drawing 5,000 things, or 5,000 render objects drawing one
> thing each?

## The three arms

| | |
|---|---|
| **A — painter** | today's path: one `CustomPainter`, the whole document walked per frame |
| **B — widget + transform** | one render object per entity, the whole set behind a `RepaintBoundary`, the camera a `Transform` **above** it. No child repaints when the camera moves. **Draws the wrong line widths** — `strokeWidth` is baked into the retained picture in recorded space and scales with zoom |
| **C — widget + correct lineweight** | the honest arm: screen-space lineweight recomputed per frame, so every child repaints when the scale changes |

B against C is the price of correctness. A against both is the price of the
architecture.

**The widget arms were steelmanned deliberately.** `Path` and `Vertices` built
once and cached, so no arm pays tessellation per frame. Layout a no-op —
children `sizedByParent` at the smallest constraints, so a camera change marks
paint and never layout. Children culled by their recorded bounds. Two further
cheats run in the widget arms' favour and were printed at the top of every run:
text ops are not drawn at all, and dash spans recorded at the fit camera are
never re-split.

**B's shape was corrected during design and the correction matters.** Described
first as "transform plus one widget per entity", it would have cost almost
exactly what C costs, because a parent's repaint re-executes its children's
`paint` unless they have their own layer. B's claim only holds with the
`RepaintBoundary` *inside* and the `Transform` *outside*. That is what shipped,
and it is what makes B a genuine ceiling.

## What the smoke run found before any number was taken

Three defects, none of which reading would have caught. This is the same
instrument Plan 3i's Ruling 19 records, one stage earlier.

1. **The residual transform was dropped.** `DraftPainter` rebases the origin so
   a drawing far from `(0,0)` does not lose float32 precision, and emits the
   remainder as a `BeginResidualOp`. Every geometry op between a begin and an
   end is in **residual-local** coordinates. Keeping the geometry and throwing
   the transform away put all 399,000 primitives outside the viewport, and the
   layer's cull rejected every one.
2. **The scale was two orders of magnitude wrong.** `harnessDocument` places
   20,000 instances, so `ENTITIES=2000` had the painter emitting **399,000**
   primitives. The scale that matters is the count of *drawn primitives* —
   what both a walk and a tree pay for. A probe under `flutter test`, no device
   needed, mapped corpus settings to counts: roughly **3.3 primitives per
   entity**.
3. **The widget arms were measuring a zero-sized viewport.** A `Stack` sizes
   itself to its *non-positioned* children, and the only one was the `Offstage`
   wrapping arm A — zero-sized exactly when a widget arm was live. The stack
   collapsed, `Positioned.fill` handed the layer tight zero constraints, and
   the cull rejected all 4,769 children against an empty rect. Arm A never saw
   it, because `DraftCanvas` paints at `size: Size.infinite` and gave the stack
   a size whenever it was the live arm. **This is `pumpTiled`'s defect from the
   other side.**

Each produced `painted=0` with the build time of a full cull walk and the
raster time of an empty screen — numbers that read as "the widget arms are
extraordinarily fast". The `painted=0` warning, written before the first run,
is what caught all three.

## The numbers

**Smoke quality and labelled as such: n=1 repeat, 15 frames per phase.** The
three-scale, three-repeat run that would have carried a gate **was never
taken** — see the last section. Milliseconds, p50.

4,769 primitives (1,500 entities / 20 definitions / 150 instances), 1400x900,
`tiles: false`, **macOS Low Power Mode on, on battery, by the human's
instruction to measure the worst realistic case.**

| arm | hold b/r | pan b/r | zoom b/r |
|---|---|---|---|
| A painter | 0.09 / 3.06 | 3.62 / 1.83 | 3.69 / 1.75 |
| B widget+transform | 0.09 / 6.21 | **0.09** / 6.08 | **0.11** / 6.23 |
| C widget+correct | 0.06 / 5.28 | 2.30 / 5.36 | 2.68 / 5.90 |

Arm switch, wall clock, first frame: A 1.2 ms, B 19.7 ms, C 21.2 ms — the
one-time cost of building 4,769 widgets, elements and render objects.

Fixture validity, printed by the run: viewport `[0,0 1400,900]`, primitive
union `[109.8,22.5 1290.2,867.5]`, **painted 4,769 of 4,769** in every phase
(4,236 in C's zoom, where the camera moved geometry off screen).

### What the numbers say

- **B's build is flat at ~0.09 ms across all three phases.** The
  `RepaintBoundary` works exactly as designed: not one child repaints on a pan
  or a zoom. The widget approach's ceiling is real.
- **B's raster is 3.4x A's** (6.21 against 1.83). This was not expected, and
  the repository's own finding explains it: *the unit of render cost is the
  canvas call*. Arm A's vertices sink submits the whole frame as **one**
  `drawVertices`; B's retained picture carries 4,769 separate draw calls. The
  widget path zeroes the build and triples the raster — a trade, not a win.
- **Correctness costs about 2.5 ms of build** at this scale: B's 0.09 to C's
  2.30 on a pan. That is the price of screen-space lineweight over 4,769
  children.
- **Every arm fits the frame budget.** Rough build+raster on a pan: A ~5.5 ms,
  B ~6.2 ms, C ~7.7 ms, against 16.67 ms, **in Low Power Mode on battery**.

**The pre-registered reading rule, recorded before the run and honoured here:**
Low Power Mode gives a one-sided conclusion. C **passing** the budget there
means the approach is definitively adequate on timing; C **failing** would have
meant only "not in the worst case". C passed. So on timing alone, at
floor-plan scale, **widget-per-entity is viable** — which is the opposite of
what this author predicted, and is why it was measured.

## The verdict: timing was never the deciding factor

The architectural objections are measurement-independent and all of them
survive a favourable number.

1. **The columnar store exists to avoid exactly these objects.**
   `EntityRecord`'s doc comment (`entity_store.dart:23`): *"One object per
   entity is precisely what the columnar decision exists to avoid."* A widget,
   an element and a render object per entity re-materialise what the storage
   design was built to prevent.
2. **The spatial index is needed regardless, so the tree becomes a second
   model.** Flutter's hit testing answers "what is under this point" by tree
   walk. CAD asks for rectangle queries, nearest endpoint within tolerance, nine
   snap kinds — the packed R-tree's work. Keeping a widget tree beside it is two
   sources of truth to hold in sync.
3. **The zero-allocation frame-path invariant dies by construction.**
   `CLAUDE.md` makes it a non-negotiable and `paint_allocation_test.dart`
   measures the residue at three objects per flush, nothing per entity.
4. **Draw order is ascending handle value**, stable across undo, save, load and
   purge. Widget paint order is child order; maintaining the invariant means
   keeping a sorted child list through every mutation.
5. **The engine is pure Dart with no Flutter dependency**, which is what lets
   797 tests run in milliseconds with no binding. Widget-per-entity puts
   `dart:ui` in the document model or demands a parallel one.

**Decision: the `CustomPainter` walk stays.** Not because widgets are slow —
they are not, at this scale — but because the widget tree would duplicate a
model the engine already keeps better, and would cost invariants three plans
were built to hold.

## The concession, and it is a real one

**Grips and overlay UI should be widgets.** A selection's grips number eight to
twenty, not five thousand, so the scale argument does not apply. As widgets
they get hit testing, hover, cursor changes (`MouseRegion`), focus, keyboard
and accessibility for free; in a `CustomPainter` every one of those is
hand-written.

The right architecture is **hybrid**: a painted canvas with a small number of
widget overlays above it. This is recorded as an open question in
`roadmap/03-grips-and-transform.md`.

## What was not measured, and why

- **The slope.** Three scales (~1,100 / ~4,800 / ~20,000 primitives) at three
  repeats were launched and produced nothing usable: the driving loop used
  `set -- $s` inside `for s in "350 10 35 small"`, and **zsh does not word-split
  an unquoted variable** the way bash does. All three runs took the whole string
  as `ENTITIES` and wrote to one file. Roughly fifteen minutes of device time,
  no usable number. The single-scale smoke figures above are all this spike
  produced, and the human stopped the spike rather than spend more on a slope
  that would not change the verdict.
- **Memory.** Object counts are known — three per primitive, so ~14,300 at this
  scale — but no heap figure was taken.
- **Anything on AC power.** Every figure here is Low Power Mode on battery,
  deliberately.

## For a later reader

If the decision is ever reopened, the thing to measure is the **slope of C
against A past 20,000 primitives**, and the thing to weigh is not that number
but the five objections above. A faster machine does not make a widget tree
stop being a second copy of the document.
