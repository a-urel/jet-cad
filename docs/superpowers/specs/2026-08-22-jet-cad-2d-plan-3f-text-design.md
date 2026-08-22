# Plan 3f — text wiring and level of detail

**Date:** 2026-08-22
**Status:** design, approved section by section, then revised against three
independent reviews on 2026-08-22
**Line:** `jet_cad_2d` / `jet_cad_2d_flutter` — the live pure-Dart 2D line
**Branch:** `main`, worked directly, no worktree

## Renumbering

The roadmap in `STATUS.md` gave `3f` to the definition/tile picture cache. This
plan takes the `3f` slot because it ships first, and the picture cache moves to
**`3g`**. All fourteen `3f` occurrences in `STATUS.md` mean the picture cache and
are swept to `3g` in this plan's first task.

The reorder is argued from a measurement, not a preference. Plan 3f's original
justification was Plan 3b's finding that the dominant render cost is
leaf-count-bound GPU vertex work — measured on the **canvas** backend, with one
`save`/`transform`/`restore` triple per leaf. Plan 3d retired that backend:
`defaultRenderBackend()` returns `RenderBackend.vertices` unconditionally, and
the vertices sink draws 10,000 entities in 5.71 ms build / 6.68 ms raster and
500,000 in 17.44 / 21.64. The speed argument for a picture cache is much weaker
than when it was written; the largest measured remaining loss in the text path
is not.

---

## The problem

Two defects, both live on `main` at `8fad846`, both in text.

### 1. A document built the ordinary way draws no text and reports no error

`DraftDocument.empty`'s `measurer` parameter defaults to
`const InsertionPointMeasurer()` (`src/document/draft_document.dart:90`), which
returns `TextMetrics.zero` for every string. `DraftPainter._drawText` takes its
metrics from `document.textMeasurer` (`draft_painter.dart:807`) and composes the
text transform from them.

**The mechanism is a guarded zero, not a division by zero.**
`TextLayout.composeTransform` reads

```dart
final scale = metrics.capHeight == 0 ? 0.0 : height / metrics.capHeight;
```

(`text_geometry.dart:242`), so a zero-metric measurer produces an explicit
`0.0` scale and a singular matrix. Plan 3c's results note and
`apps/dev_harness_2d/lib/main.dart`'s comment both describe the symptom
correctly and the mechanism loosely; this document is the correction.

`DraftCanvasState` does build a real measurer — `FlutterTextMeasurer()` at
`draft_canvas.dart:123` — but hands it only to `CanvasDrawSink`
(`draft_canvas.dart:138`). The painter never sees it.

So an application assembled the ordinary way — `DraftDocument.empty()`, then
`DraftCanvas(document: doc, ...)` — draws no text, throws nothing, and logs
nothing. Plan 3c recorded this as carry-forward item 1 and left it without an
owner. It is a shipping blocker for text.

The same zero metrics reach the query path: `entityBounds` is called with
`document.textMeasurer` from `DraftDocument.extents` and from
`reference_walk.dart:133`, so a text entity's box collapses to a point and
picking a text entity — which Plan 3c made a `HitKind.fill` against that box —
misses.

### 2. Two paragraph caches, and unifying them alone makes things worse

Because the painter and the sink read different measurers, a text leaf costs up
to two layouts. Plan 3c measured the query-only row at **+97 ms at 50,000
entities and +105 ms at 500,000**, into a `NullDrawSink`, and attributed it
precisely: "That is not the sink; it is `document.textMeasurer.measure(...)` in
`_drawText`, which runs whatever the sink is."

**That cost is killed by LOD, not by unification.** It is the paint walk's
measure call, and the LOD early return happens before it. Section 1 must not
claim it.

What unification alone would do is make the cache *worse*. Today the two caches
are separate, so metrics pressure cannot evict drawn paragraphs. Merge them
naively and a full `extents` recomputation — 4,020 distinct strings, no LOD
protection — walks straight through a 512-entry cache and throws away every
paragraph the paint path had warm.

The key is also at the wrong layer. `FlutterTextMeasurer`'s cache is keyed
`(text, styleHandle, argb)`. `measure()` substitutes `kMetricsProbeArgb`
(`0xFF000000`, `flutter_text_measurer.dart:21`); `paragraphFor()` passes the
entity's resolved ARGB. The class's own doc comment states the fact that makes
this wrong: colour cannot change metrics. Colour belongs to the `ui.Paragraph`,
not to the `TextMetrics`.

### 3. Whole-drawing cache thrash

Plan 3c measured, at the whole-drawing camera, **4,140 new paragraph layouts and
4,140 new evictions per frame** — the cache evicting entries the same frame asks
for again — at **both** 50,000 and 500,000 entities, because the count is bounded
by string variety rather than entity count. Over the 500,000 run: 349,740
layouts in the document's cache and 149,040 in the sink's.

Raising `kParagraphCacheLimit` is not the answer and Ruling 4 forbids using it as
one. A bigger cache holds one zoom level of one corpus. Text too small to read
does not need to be laid out at all.

---

## Decisions taken

Settled with the human on 2026-08-22, before and after review.

1. **This plan is text, not the picture cache.** The picture cache is four
   independent subsystems — the `InstanceNode`/`StyleContext` model completion,
   the definition picture cache, tiling, and text LOD — and does not fit one
   spec. Text LOD is the only one with no dependency on the other three, and it
   carries the largest measured loss.
2. **Below the threshold, draw nothing.** Not a greeked bar, not two tiers. Both
   alternatives are written into the code as comments with the reason each was
   not taken now.
3. **The document owns the measurer; the widget borrows it.** Approach A of
   three; the rejected two are under "Alternatives considered".
4. **The paragraph cache splits in two**, colour-free metrics and coloured
   paragraphs, with **separate bounds and separate counters**.
5. **The metrics probe paragraph is disposed, not kept.** Reversed on review —
   see Section 1.
6. **The application owns the measurer's disposal.** `DraftCanvas.dispose()`
   stops calling `clear()`.

---

## Non-goals

- MTEXT, DXF `72=3`/`72=5` layout, and any other text feature.
- The definition/tile picture cache — Plan 3g.
- The `InstanceNode`/`StyleContext` model completion and `documentRevision` —
  prerequisites for 3g, not for this plan.
- Permitted divergence 5 (overlapping translucent strokes on a triangle soup).
  Still open, still unexercised, still nobody's.
- Moving `AllocationMeter` into `jet_cad_2d/lib/src/testing/` so the Flutter
  suite can run a real allocation profile. An accepted gap, below.

---

## Section 1 — measurer ownership and the split cache

### Ownership

`DraftCanvasState._measurer` is deleted. `_attach()` resolves the sink's
measurer from `widget.document.textMeasurer`.

`DraftCanvas` refuses, at `_attach()` time, a document whose `textMeasurer` is
not a `FlutterTextMeasurer`. The refusal is **unconditional** — it does not
consult `drawText`. `drawText: false` is a measurement flag, not a licence to
carry a measurer that computes the wrong extents: a document whose boxes came
from `TextMetrics.zero` is wrong whether or not glyphs are drawn. A guard
conditioned on `drawText` would also force `CanvasDrawSink` to hold a throwaway
`FlutterTextMeasurer` for its typed field (`canvas_draw_sink.dart:41`), which is
the second cache coming back.

The refusal message names the fix in full, including the construction order:

```
DraftCanvas requires document.textMeasurer to be a FlutterTextMeasurer;
it is InsertionPointMeasurer. Build the measurer first and pass it to the
document:

    final measurer = FlutterTextMeasurer();
    final doc = DraftDocument.empty(measurer: measurer);
```

`DraftDocument.empty`'s and `generateDocument`'s `InsertionPointMeasurer`
defaults **stay**. They are legitimate, documented lower bounds for an
engine-only caller — `jet_cad_2d` has no Flutter dependency and cannot construct
a real measurer. The rule lives at the `DraftCanvas` boundary and nowhere else.

`DraftPainter` is unchanged in this respect: it already reads
`document.textMeasurer`. What changes is that the sink now reads the same object.

This makes Ruling 36 — "a golden document must carry a real measurer" —
structural rather than conventional.

### Disposal, which this change makes homeless

`DraftCanvasState.dispose()` currently calls `_measurer.clear()`
(`draft_canvas.dart:182`), which is correct while the widget owns the cache. It
becomes wrong the moment the document owns it: two canvases over one document —
a split view — share one measurer, and closing one would wipe the other's cache
and every `ui.Paragraph` it holds.

**Ruling: the application owns the measurer's lifetime.** It constructs the
`FlutterTextMeasurer`, hands it to the document, and calls `clear()` when it
retires the document. `DraftCanvas.dispose()` no longer calls `clear()`, and
carries a comment saying why. This is the ordinary Dart contract for a
native-resource holder — `ui.Image` works the same way — and it is the only
option that does not add a lifecycle to the engine package.

**Every construction site takes the obligation with the measurer.** A
one-line change that adds `FlutterTextMeasurer()` and stops there moves the leak
rather than fixing it. In tests that means `addTearDown(measurer.clear)` beside
the construction; in the harness it means `_HarnessState.dispose()`
(`main.dart:421-425`, which today releases `index` and `camera` and nothing else)
gains the call. `harnessDocument` currently builds the measurer inline inside the
`generateDocument` argument list (`main.dart:155`), so it must hoist it to a
field the state can reach.

Three tests pin it:

- **Split view.** Two `DraftCanvas`es over one document; dispose one; the other
  still serves paragraphs from a warm cache with `layoutCount` unchanged.
- **Application teardown.** `measurer.clear()` disposes every live paragraph —
  the existing `debugLastEvicted` / `Paragraph.debugDisposed` surface already
  supports this assertion.
- **Harness lifecycle.** Disposing the harness state disposes the measurer.
  The teardown row alone only proves `clear()` works when someone remembers to
  call it, which is not the failure mode this change introduces.

`_measurer`'s current doc comment (`draft_canvas.dart:120-122`) argues that the
cache should *survive* a document swap. The new ownership reverses that on
purpose — the cache belongs to the document, so swapping the document swaps the
cache. The comment is rewritten, not deleted.

### The split cache

`FlutterTextMeasurer` holds two `LinkedHashMap`s, both least-recently-touched
first, both evicting from the front.

| map | key | value | bound |
|---|---|---|---|
| metrics | `(text, styleHandle)` | `TextMetrics` | `kMetricsCacheLimit` |
| paragraphs | `(text, styleHandle, argb)` | `ui.Paragraph` | `kParagraphCacheLimit` = 512 |

**The bounds are different numbers for different reasons and must not be
shared.** A paragraph entry holds native glyph memory; 512 is Ruling 4's, and
Ruling 4's single permitted raise stays unspent. A metrics entry is four
doubles. The paragraph map is sized against what a *frame* draws; the metrics map
is sized against what a full `extents` sweep *touches*, which is every text
entity in the document because LOD deliberately does not apply there.

`kMetricsCacheLimit` must exceed the measured distinct-`(text, styleHandle)`
count of the rig corpus, and **the count ships written beside the constant**. The
expected value is about 4,020 — 4,000 unique `ATTRnnnnn` strings plus the twenty
distinct labels Ruling 17 pins — which is roughly 400 KB of `TextMetrics`. A
metrics map bounded at 512 against 4,020 keys would thrash on every sweep, and a
metrics miss *builds a paragraph*, so the thrash costs real layouts. This is
Ruling 4's reasoning applied to a different cache, not a raise of Ruling 4's own
constant.

`measure()` reads the metrics map. On a miss it builds a paragraph at
`kMetricsProbeArgb`, reads the metrics, stores them, and **disposes the probe
paragraph**.

**It does not consult the paragraph map, and that is a decision, not an
oversight.** An earlier draft had it probe the paragraph map for any entry with
the same `(text, styleHandle)` at any colour. Two reviews independently pointed
out that a `LinkedHashMap` keyed on the wide `(text, styleHandle, argb)` tuple
cannot be queried on the narrow one — the only implementations are a linear scan
of up to 512 entries per miss, or a third reverse-index map with its own
eviction maintenance.

Neither is needed, because **the probe can never pay**. `DraftPainter._drawText`
calls `measure()` before it calls `sink.text`, and `sink.text` is the only route
to `paragraphFor` (`canvas_draw_sink.dart:207`; the vertices sink delegates text
to the same fallback at `vertices_draw_sink.dart:721`). So at first sight of a
string the paragraph map has nothing to find. The probe could only pay when a
paragraph outlives its metrics entry — which requires a metrics eviction, and
`kMetricsCacheLimit` is sized above the corpus's whole distinct-key count
precisely so that does not happen. The bound that makes the split work is the
same bound that makes the probe dead code.

**Disposing the probe is a reversal, and the reason it was reversed is a fact
that was checked.** The first draft kept it, arguing ACI 7 is black so the probe
would usually be the one the sink asked for next. `resolved_style.dart:53` maps
ACI 7 to `0xFFFFFF` — **white** — pinned by `style_resolver_test.dart:365`. The
probe's black is therefore almost never the drawn colour, so keeping it would
hold two paragraph entries per distinct string and halve the effective capacity
of a 512-entry cache to 256 distinct strings. The alternative is a named mutant
so the threshold ladder measures it rather than taking this argument on trust.

`paragraphFor()` reads the paragraph map, building on a miss.

**Insert-over-existing stays unreachable, and is asserted rather than
handled.** `_buildEntry` ends `_cache[key] = entry`
(`flutter_text_measurer.dart:172`) with no disposal of a displaced paragraph.
An earlier draft called for a disposal branch, on the theory that the split made
that path reachable. It does not: `paragraphFor` inserts only after an exact
`(text, styleHandle, argb)` miss, and `measure()` — with the probe dropped —
never inserts into the paragraph map at all. A disposal branch there would be
dead code, and a mutant that deleted it would be equivalent. The invariant gets
an `assert(!_paragraphs.containsKey(key))` instead, which is the honest shape:
a claim the code makes about itself, not a handler for a case that cannot
arise.

Both maps must be probed without allocating. The paragraph map keeps the existing
mutable `_CacheKey`; the metrics map needs its own two-field equivalent, for the
reason `MetricModelMeasurer`'s doc comment records — building a record key per
lookup was measured at roughly 41 `_Record` allocations per pick and broke
`query_allocation_test`.

`measure()` must return the **identical** `TextMetrics` instance on a repeat call.

**The constructor takes two bounds, not one.** It is
`FlutterTextMeasurer({this.limit = kParagraphCacheLimit})` today
(`flutter_text_measurer.dart:41`), and `flutter_text_measurer_test.dart:33`
passes `limit: 2` to force eviction. Under two maps a single `limit` is
ambiguous, and both the eviction unit test and the threshold ladder need the
metrics bound settable per instance. Two named parameters,
`paragraphLimit` and `metricsLimit`, defaulting to the two constants.

### Counters, per map

`layoutCount` stays one number — a layout is a layout. Everything else splits:

- `paragraphEvictionCount` and `metricsEvictionCount`. A paragraph eviction costs
  native memory and a future re-layout; a metrics eviction is four doubles. Gate
  row 2 reads the paragraph one. Blending them is Ruling 54's exact mistake — the
  one this design refuses for `culledText` against `skippedText`.
- `liveParagraphCount` stays pinned to the paragraph map. Plan 3c's "peak live
  paragraphs at or below the declared limit" row depends on it meaning native
  paragraphs.
- `clear()` clears and disposes both.
- `resetCounters()` zeroes all three counts and touches neither map.

**`evictionCount` is a breaking rename and every reader must move with it.**
`layoutCount` and `liveParagraphCount` keep their names and meanings; only
`evictionCount` splits. The call sites, all of which the task must edit or the
first analyze run is red:

- `test/flutter_text_measurer_test.dart:37`, `:91` — the class's own unit test,
  which also constructs `FlutterTextMeasurer(limit: 2)` at `:33`
- `test/rig/paint_microbench_test.dart:286`, `:299`, `:301`, `:304`
- `apps/dev_harness_2d/integration_test/frame_timing_test.dart:265`, `:323`
- `apps/dev_harness_2d/lib/measurement_rig.dart:156`, `:158`, `:218` — `:218` is
  a second call site outside `printTextCounters`, and that function's own
  `evictionsBefore` parameter splits too

`measurement_rig.dart:155-157` prints `newLayouts=`, `newEvictions=` and `live=`
from these and gains the second eviction number.

**`paint_microbench_test.dart` is a special case: this plan falsifies its
premise.** Its fixture builds two measurers on purpose, and says why at
`:153-158` — "Two measurers, because production has two. `DraftCanvas` builds its
own `FlutterTextMeasurer` for the sink and never touches
`document.textMeasurer`". That is exactly the wiring this plan removes, and it is
the rig the +97/+105 ms figure came from. Left alone it measures a shape that no
longer exists and its comment becomes false in-tree. The task collapses it to one
measurer and rewrites the comment to say what the new wiring is.

### What this buys, stated honestly

**Unification is required for correctness.** One real measurer is what makes the
painter and the sink agree and what makes `extents` and picking see real boxes.

**The split is what stops unification from making the cache worse.** Merged
naively, an `extents` sweep over 4,020 strings evicts everything the paint path
had warm. Split, the sweep lands in the metrics map and the drawn paragraphs
survive. That is the whole payoff, and it is a regression *prevented*, not a
speed-up delivered.

**The +97 ms / +105 ms is killed by LOD**, in Section 2, because it is the paint
walk's own `measure` call and LOD returns before it.

**First sight of a string still costs up to two layouts** — a disposed probe for
the metrics, then the drawn paragraph. Steady state is zero, which is what every
gate row measures.

### Blast radius

Seven files construct a `DraftCanvas`. Only `text_ladder_golden_test.dart:59`
already passes a `FlutterTextMeasurer`. The guard trips the other six, nine
documents in total:

| file | documents | current measurer |
|---|---|---|
| `test/draft_canvas_test.dart` | 3 | two default (`:112`, `:180`), one `MetricModelMeasurer` (`:282`) |
| `test/render_backend_test.dart` | 2 | `generateDocument`'s default (`:9`, `:69`) |
| `test/frame_path_seam_test.dart` | 1 | default (`:39`) |
| `test/golden/dash_ladder_golden_test.dart` | 1 | default (`:22`) |
| `test/golden/fill_ladder_golden_test.dart` | 1 | default (`:46`) |
| `apps/dev_harness_2d/lib/main.dart` | 1 | conditional — below |

**The task re-scans every `DraftCanvas` call site rather than trusting this
table.** The table was wrong once already: the first draft of this document
asserted all three golden ladders were safe, and two of them are not.

Each is a one-line change: pass a `FlutterTextMeasurer`.
`draft_canvas_test.dart:282` swaps `MetricModelMeasurer` for
`FlutterTextMeasurer` and loses nothing — that test asserts `textOpCount == 1`,
which is about the `drawText` forward, not about the metric model — and it must
also pass `minTextCapPixels: 0` so LOD does not cull the entity it counts.

`main.dart` is the interesting one. It already works around this defect by hand:

```dart
measurer:
    kTextCorpus ? FlutterTextMeasurer() : const InsertionPointMeasurer(),
```

and its doc comment names the failure exactly — "every text transform to a
singular matrix. A text corpus built on it looks like a text corpus and draws
nothing measurable." The workaround was applied at one call site and the cause
left in place. Under the guard the ternary collapses to an unconditional
`FlutterTextMeasurer()`, and what turns text off becomes `labelFraction: 0` and
`attributedInstanceFraction: 0`, which is the correct axis. **A task that leaves
the ternary in place has not done the work.**

### Alternatives considered

**The widget owns it and attaches it to the document.** `textMeasurer` would stop
being `final` and a once-only `attachMeasurer()` would call
`invalidateDerived()`. Zero burden on the application, which is its real appeal.
Rejected because applications read `doc.extents` to place the initial camera
*before* the canvas mounts: that read would be served by zero metrics, and
invalidating the cache afterwards does not un-place a camera already built from
the wrong box. `DraftDocument.textMeasurer`'s own doc comment argues the same
class of hazard for making the field `final`.

**Keep two objects and make the default loud.** Drop the default from
`DraftDocument.empty` so a measurer must be named. Closes the silent failure,
leaves the double layout where it is. Cheapest and worth the least.

---

## Section 2 — level of detail

### The test, and where it goes

`DraftPainter._drawText` gains an early return. **The method is also reordered**:
today it calls `measure()` at `:807` and `TextLayout.resolve` at `:812`. The new
order is

1. `drawText` off → return
2. empty string → `_skippedText++`, return
3. `_textLayout.resolve(payload, textAttrs, record)`
4. **LOD** → `_culledText++`, return
5. `document.textMeasurer.measure(...)`
6. `composeTransform`, `beginResidual`, `sink.text`, `endResidual`

```dart
final screenCap = _textLayout.height * chain.scaleMagnitude;
if (screenCap < minTextCapPixels) {
  _culledText++;
  return;
}
```

`TextLayout.resolve` needs no metrics — it resolves height, rotation, width
factor, oblique angle and justification from the payload, the attribute bits and
the style record (`text_geometry.dart:172`). `TextLayout.height` is the effective
DXF text height, which **is** the cap height, in world units.
`Transform2.scaleMagnitude` is `sqrt(|det|)`, already in the codebase
(`transform2.dart:87`) and already documented as the representative scale the
renderer uses. `chain` carries camera, ancestors, instance, placement and rebase,
so the product is the on-screen cap height in pixels.

**No measurement is involved, and that is the whole point.** Placing this test
after step 5 would cull the draw and save no layout — it would look like it
worked and change nothing the gate measures. That placement is a named mutant.

### The threshold

`kMinTextCapPixels = 3.0`, in **logical** pixels.

Below three pixels of cap height a glyph cannot resolve two strokes, so nothing
readable is lost. Logical rather than device pixels is deliberate: on a 2×
display the same text is six device pixels tall, so the rule culls **less** than
a device-pixel rule would. That is the safe direction, the same one
`kScreenClipInflate` takes.

The plan measures a threshold ladder against the corpus and records the table
beside the constant. The ladder reports, per threshold and per camera:
layouts, paragraph evictions, metrics evictions, `culledTextCount`, **and the
distinct surviving key count in each map**. The last is the number that says
whether 3.0 is feasible or whether Ruling 4's single raise finally gets spent.

### Why rows 1 and 2 are reachable, and why that is fragile

`generate_document.dart:676` gives every attribute a fixed height of `80.0`;
labels get `100 + rand*200` (`:631`, `:650`). At a 96,000-unit-wide camera an
attribute is about one pixel of cap height. Attributes are 4,000 of the 4,020
distinct pairs and Ruling 54 measured them at a 0.0% hit rate. LOD culls the
entire pressure, leaving roughly 140 label keys — comfortably under 512 — which
is why rows 1 and 2 can read zero.

**That also makes the gate a step function rather than a gradient.** One fixed
attribute height means one threshold at which 4,000 keys vanish at once. A later
corpus change that varies attribute height would move the step and could take the
gate green-to-green while the mechanism degrades. This is the repo's named
degenerate-fixture class wearing a different hat, and it is written here so the
plan's threshold ladder is read as a step-locator, not as a curve.

### Disabling it

`DraftPainter` gains `minTextCapPixels`, forwarded from `DraftCanvas`, default
`kMinTextCapPixels`. **`0.0` disables LOD.** The exit gate compares LOD-on
against LOD-off on the same corpus at the same camera; without a control arm the
before/after numbers are two different documents.

Both fields are `final`, for the reason `drawText` is (`draft_canvas.dart:89`).

**`minTextCapPixels` must be added to `didUpdateWidget`'s comparison list**
(`draft_canvas.dart:161-169`). Without it a rebuild that changes the threshold
keeps the old painter, so the LOD-off control arm silently measures the LOD-on
build and looks like it worked. Named mutant, and the equivalent prop-update test
already exists for `drawText`.

The harness maps its `LOD` define to `true → kMinTextCapPixels`,
`false → 0.0`, and passes it to `DraftCanvas` (`main.dart:443-450` forwards
`drawText: kDrawText` today and nothing else).

### The second blast radius: LOD arrives by default value

The measurer guard's radius is a compile error at every call site, so it can be
tabled and re-scanned. **`minTextCapPixels` defaulting to `kMinTextCapPixels`
has no compiler-visible call site at all** — seventeen files construct a
`DraftPainter`, and every one of them silently gains culling. A default-valued
API change needs the same explicit sweep a signature change gets, and the first
draft of this document did not give it one.

Five of the seventeen carry text:

| suite | why it matters |
|---|---|
| `test/text_paint_test.dart` | the text draw path's own tests |
| `test/rig/paint_microbench_test.dart` | the gate's feasibility number |
| `test/support/sink_comparison.dart` | sink-against-sink ink comparison |
| `test/draft_painter_root_test.dart` | root-level text ordering |
| `test/draft_canvas_test.dart` | the `drawText` forward |

**The task enumerates all seventeen and records, for each text-bearing one, its
smallest text cap height in pixels against the threshold** — the way
`text_ladder`'s 7.3× is recorded below. A suite whose margin is thin gets
`minTextCapPixels: 0` explicitly rather than an implicit pass, so that a later
threshold change cannot silently empty it.

`paintToRecording` (`test/support/fixtures.dart:154`) builds a bare
`DraftPainter(document:, index:, resolver:)` and is the one spelling every
differential test uses. It gains `minTextCapPixels` alongside
`referenceToRecording`'s (`:167`) — **both sides**, or the matched on/off control
arms cannot be driven and mutant 5's near-threshold fixture cannot put the
painter and the oracle on the same number on purpose.

### Anisotropy

`scaleMagnitude` is the geometric mean of the axis scales, so text squashed in y
under an anisotropic placement reads taller than it renders and survives longer
than it should. This is the same approximation the painter already makes for
curve stroke widths past `kAnisotropyThreshold`, and it errs toward drawing.
Recorded here rather than hidden; not counted separately.

### The reference walk derives its own

`reference_walk.dart` is the differential oracle. It must apply the same LOD rule
and must **compute it itself** — from `resolveTextAttributes(...)`
(`text_geometry.dart:286`) `.height` and its own `chain.scaleMagnitude` — never
by asking the painter what it decided. Sharing the decision would have the oracle
share the assumption it exists to test. This is the correction Plan 3e made at
`24cfd23` for fill triangulation, applied here before it can go wrong.

The walk already skips the empty string independently
(`reference_walk.dart:161`), which is the same pattern.

**`referenceWalk` therefore needs the threshold as an input.** Its signature is
five positional parameters and carries no LOD knob
(`reference_walk.dart:29-42`); it gains `minTextCapPixels`, and so do its two
call sites, `test/support/fixtures.dart:169` and `differential_test.dart:63`.
Without it the plan cannot demonstrate matched on/off control arms, and cannot
build the near-threshold non-identity fixture mutant 5 requires.

### The counter

`DraftPainter.culledTextCount`, reset per frame in `paint()` beside the others.

Kept separate from `skippedTextCount`, which counts **the empty string only** —
`drawText: false` returns at `draft_painter.dart:796`, before the counter.
Blended, the gate cannot tell which mechanism fired; that is Ruling 54's mistake.

### Documented alternatives

Both rejected alternatives are written into `_drawText` as comments, each with
what it would cost:

- **Greeking** — draw a bar the width of the text instead of the glyphs, so a
  zoomed-out plan keeps its visual weight. In the vertices sink a bar is two
  batched triangles, effectively free. The obstacle is the width: it needs
  `advanceWidth`, so either the layout happens anyway and the saving is lost, or
  a font-free width model (`text.length × ratio`, the shape `MetricModelMeasurer`
  uses) is introduced as a new approximation.
- **Two tiers** — greek in a middle band, nothing beyond it. Closest to real CAD
  and the most control, at two constants, two counters, two golden ladders, and
  the same font-free width model.

### What LOD must not change

`doc.extents` and picking. A document bounding box that changes with zoom is
absurd, and text that cannot be picked because it is small is a different
decision from text that is not drawn. Both are gate rows.

---

## Section 3 — measurement, the exit gate, and mutation

### No failable criterion is a timing

Every row below is a count. Plan 3c's whole session ran under macOS Low Power
Mode and every timing in it is contaminated; Plan 3e's 10,000-entity row was
measured, cleared its bar by a wide margin, and still could not be scored for the
same reason. Counts are machine-independent.

Timings are still measured and written down. They are not gates.

The results note must state whether Low Power Mode was on, checked with
`pmset -g | grep lowpowermode` **before** the first run.

### Baseline, from Plan 3c

| camera | new layouts / frame | new evictions / frame |
|---|---|---|
| working set | 0 | 0 |
| whole drawing | **4,140** | **4,140** |

Both figures are identical at 50,000 and 500,000 entities.

### Failable criteria

| # | row | threshold |
|---|---|---|
| 1 | whole-drawing camera, repeat frame, new layouts | **0** (baseline 4,140) |
| 2 | whole-drawing camera, repeat frame, **paragraph** evictions | **0** (baseline 4,140) |
| 3 | working-set camera, layouts and paragraph evictions | **0** — no regression |
| 4 | `culledTextCount`, whole-drawing camera | **> 0** |
| 5 | `culledTextCount`, working-set camera | **0** |
| 6 | `doc.extents` at `minTextCapPixels` 0 and 1000 | **bit-identical** |
| 7 | picking a text entity, at both thresholds | same hit |
| 8 | `DraftCanvas` over a document with the default measurer | **throws, naming the fix** |
| 9 | differential oracle, LOD on, both cameras | passes |
| 10 | **extents-sweep non-interference** — see below | layouts **0**, paragraph evictions **0** |
| 11 | split view: dispose one canvas | the other's `layoutCount` unchanged |
| 12 | `measurer.clear()` | every live paragraph `debugDisposed` |
| 13 | mutation log | every mutant killed, argued equivalent, or recorded unmeasurable with its reason |

**Rows 4 and 5 are load-bearing as a pair.** Row 4 alone passes on a corpus with
no text; row 5 alone passes with LOD disabled. One proves the mechanism fires,
the other proves it does not fire where text is readable — the row a threshold
set too high fails.

**Row 10 is the row the split exists for**, and it replaces a weaker "warm pick
sweep" row that a narrow sweep could pass while the regression hid behind it:

1. paint one frame at the working-set camera, warm
2. `invalidateDerived()`, then a full `doc.extents` recomputation — every text
   entity in the document, roughly 4,020 distinct strings, no LOD
3. repaint at the same camera

New paragraph layouts **0** and paragraph evictions **0**. A merged cache fails
this by construction: step 2 walks 4,020 keys through 512 slots and evicts
everything step 3 needs. A metrics map bounded too low fails it too, in layouts.

### Named mutants

A test is worth landing here only if a named mutation makes it red.

| # | mutation | expected killer |
|---|---|---|
| 1 | move the LOD test after `measure()` | row 1 |
| 2 | `<` → `<=` at the threshold | boundary fixture, one entity exactly at `kMinTextCapPixels` |
| 3 | drop `chain.scaleMagnitude`, cull on world height alone | row 5 |
| 4 | drop `_culledText++` | row 4 |
| 5 | reference walk reads the painter's decision | near-threshold, non-identity placement fixture |
| 6 | merge the two maps back into one | row 10 |
| 7 | `metricsLimit` defaulted to `kParagraphCacheLimit` | row 10, in layouts |
| 8 | remove the `DraftCanvas` guard | row 8 |
| 9 | `measure()` does not store metrics | rows 1 and 10 |
| 10 | apply LOD inside `entityBounds` | row 6 |
| 11 | `culledTextCount` not reset per frame | two-frame fixture |
| 12 | keep the metrics probe paragraph instead of disposing it | the threshold ladder's distinct-key column |
| 13 | `DraftCanvas.dispose()` keeps calling `clear()` | row 11 |
| 14 | `minTextCapPixels` left out of `didUpdateWidget` | prop-update test, the shape `drawText`'s already has |
| 15 | `DraftPainter.minTextCapPixels` defaulted to `0.0` | a bare-`DraftPainter` text test that passes no knob — the rig passes one explicitly and would stay green |

**Two mutants from the previous draft are gone, both because the mechanisms they
attacked were removed.** "Skip the paragraph-map probe on a metrics miss" and
"insert over an existing paragraph key without disposing" both described paths
that the probe's removal makes unreachable; a mutation of unreachable code is
equivalent by construction, and listing it would have put a row in the log that
row 13 could never close.

**Mutant 6 replaced a bad one.** The first draft named "key the metrics map by
ARGB", expecting row 10 to kill it. `measure()` always passes
`kMetricsProbeArgb`, so re-keying by ARGB changes nothing observable — an
equivalent mutant dressed as a real one. Merging the maps is the mutation that
actually undoes the design.

**Mutant 5 needs a fixture designed on purpose.** The painter and the walk must
be capable of disagreeing, which means text near the threshold under a
non-identity placement. A fixture at the identity transform cannot tell them
apart — the repo's named dominant defect class. The two reach `chain` by
different routes (`draft_painter.dart:793`, `reference_walk.dart:145-148`), so a
genuine disagreement is constructible.

**Mutant 12 exists because a premise was wrong once.** The probe-disposal
decision rests on ACI 7 resolving to white; the ladder measures the alternative
rather than trusting the argument.

**Mutant 15 exists because the rig cannot see it.** The harness passes
`minTextCapPixels` explicitly, so a wrong default leaves every gate row green.
Only a construction site that relies on the default can catch it.

### Goldens

One new ladder, `text_lod_ladder`, three rungs × two backends = six PNGs. Both
backends are real: `RenderBackend.canvas` survives as an explicit choice even
though the default is `vertices`.

The fixture is one drawing carrying three text heights under a camera chosen so
the smallest is culled, the largest is not, and the middle sits near the
boundary. It pins the threshold visually and goes red if the constant moves.

Ahem is sufficient and the reason is stronger than "presence and absence":
`capHeight` is `kCapHeightRatio * kNominalTextPixels`, a constant, and the LOD
test reads no metrics at all, so the cull decision is **font-independent**. The
ladder is font-proof. It still carries a `FlutterTextMeasurer` per Ruling 36,
which the guard now enforces anyway.

**No pre-existing PNG may be regenerated**, and `text_ladder` in particular must
not move. Its `kWorld` is 200×150 (`text_ladder_golden_test.dart:38`) rendered
into `kGoldenViewport`, `Size(400, 300)` (`:32`) — 2.0 px per world unit — and
its smallest rung is height 11 (`:222`), giving 22 pixels of cap height against a
3.0 threshold: a **7.3× margin**. Note that `kGoldenViewport` is declared
separately in each golden file and is *not* `fixtures.dart`'s `kViewport`, which
is `Size(800, 600)`; reading the wrong one doubles the apparent margin. That
margin belongs in this document rather than in the implementer's head.

### The rig

`apps/dev_harness_2d` gains a `LOD` define. Per the trap,
`bool.fromEnvironment` reads `--dart-define=LOD=1` as **false**; the define is
therefore a `String.fromEnvironment` that throws on anything but `"true"` and
`"false"`, the pattern Plan 3e used for `FILLS`. It maps to
`minTextCapPixels: kMinTextCapPixels` or `0.0` and is forwarded to `DraftCanvas`.

`printTextCounters` (`measurement_rig.dart:145`, which is where `skippedText=`
is printed at `:154` — **not** `printInvariants` at `:102`) gains `culledText=`
and the second eviction count. Per the trap, any rig guard belongs before the
first print or nowhere: R4a and R4b printed three lines and threw, for months.

---

## Accepted gaps

**The metrics map's lookup allocation cannot be measured.**
`query_allocation_test.dart` lives in the engine suite because
`jet_cad_2d_flutter` has no `vm_service` dependency — Plan 3c carry-forward
item 3. The split cache is Flutter-side, so no VM allocation profile can watch
it. The `identical` assertion on a repeat `measure()` proves the **value** is
cached; it proves nothing about whether the lookup allocated a key.

Consequently the mutation "allocate the metrics probe key per call" is
**unmeasurable on this side and is recorded as such rather than listed as a
mutant with a killer that cannot kill it.** Row 13 admits that third category
explicitly, and Plan 3e's log has the precedent — two documented gaps beside
fifty-two kills. Moving `AllocationMeter` into `jet_cad_2d/lib/src/testing/`
would close it and is out of scope here.

**Anisotropic placements cull late.** Stated in Section 2, not counted.

**The gate's text pressure is a step function.** Stated in Section 2. The
threshold ladder locates a step; it does not trace a curve.

**The engine package is untouched.** `DraftDocument`, `TextMeasurer`,
`TextMetrics` and `text_geometry.dart` keep their current shape. A task that
finds it needs an engine change should raise it as a ruling, not take it.

---

## Files

**Modified**

- `packages/jet_cad_2d_flutter/lib/src/flutter_text_measurer.dart` — the split,
  the two bounds, two constructor parameters, per-map counters, probe disposal,
  and the insert-over-existing assertion
- `packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart` — measurer resolution,
  the guard, `minTextCapPixels` including in `didUpdateWidget`, `dispose()` no
  longer calling `clear()`
- `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart` — the reorder, the LOD
  test, `culledTextCount`, `kMinTextCapPixels`, `minTextCapPixels`
- `packages/jet_cad_2d_flutter/lib/src/reference_walk.dart` — an independently
  derived LOD, and `minTextCapPixels` on `referenceWalk`
- `packages/jet_cad_2d_flutter/test/support/fixtures.dart` — the new parameter on
  **both** `paintToRecording` (`:154`) and `referenceToRecording` (`:167`)
- `packages/jet_cad_2d_flutter/test/differential_test.dart` — the new parameter
- `packages/jet_cad_2d_flutter/test/flutter_text_measurer_test.dart` — the
  measurer's own unit test: the eviction rename, the two constructor bounds, the
  probe removal
- `packages/jet_cad_2d_flutter/test/canvas_draw_sink_test.dart` — reads
  `layoutCount` and `liveParagraphCount`, which keep their meaning; audited, not
  necessarily changed
- `packages/jet_cad_2d_flutter/test/rig/paint_microbench_test.dart` — collapsed
  to one measurer, its two-measurer comment rewritten, the eviction rename
- `packages/jet_cad_2d_flutter/test/support/sink_comparison.dart` — a
  text-bearing bare `DraftPainter`
- `packages/jet_cad_2d_flutter/test/text_paint_test.dart` — text-bearing
- `packages/jet_cad_2d_flutter/test/draft_painter_root_test.dart` — text-bearing
- `apps/dev_harness_2d/integration_test/frame_timing_test.dart` — the eviction
  rename at `:265` and `:323`
- `apps/dev_harness_2d/lib/main.dart` — the `LOD` define, the threshold
  forwarded, the measurer ternary collapsed, the measurer hoisted out of the
  `generateDocument` argument list to a field, and `dispose()` releasing it
- `apps/dev_harness_2d/lib/measurement_rig.dart` — `culledText=` and the second
  eviction count, in `printTextCounters`
- `packages/jet_cad_2d_flutter/test/draft_canvas_test.dart` — three documents
- `packages/jet_cad_2d_flutter/test/render_backend_test.dart` — two documents
- `packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart` — one document
- `packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart` — one
- `packages/jet_cad_2d_flutter/test/golden/fill_ladder_golden_test.dart` — one
- `STATUS.md` — the 3f/3g renumbering. **Not a mechanical sweep.** Fourteen
  occurrences, and three of them (`:622`, `:633`, `:635`) are prose *about the
  previous renumbering* — "fills is 3e and the picture cache is 3f", "every
  `3d`/`3e`/`3f` above was swept". Rewriting those blindly destroys the history
  that explains why the numbers moved. `:436` is a third case: "the picture
  cache's text LOD (Plan 3f)" is the item this plan takes and 3g keeps the rest,
  so it splits rather than renumbers. The task states which of the fourteen are
  prose before it edits any of them.

**Created**

- `packages/jet_cad_2d_flutter/test/text_lod_test.dart`
- `packages/jet_cad_2d_flutter/test/text_measurer_split_test.dart`
- `packages/jet_cad_2d_flutter/test/golden/text_lod_ladder_golden_test.dart`
  and six PNGs
- `docs/superpowers/notes/2026-08-22-plan-3f-results.md`
- `docs/superpowers/notes/plan-3f-mutation-log.md`

---

## Global constraints

Copied from `CLAUDE.md`; every task's requirements include them.

- The frame path allocates nothing per entity in steady state, and O(1) per flush.
- Draw order is ascending handle value, stable across undo, save, load and purge.
- Geometric *decisions* use `Tolerance`; *stored value* comparisons are exact `==`.
- Never commit `analysis_options.yaml`. Also never commit
  `apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj`, which
  `flutter drive` rewrites.
- Never synthesize test output.
- Never `git checkout` a file to revert a mutation — copy it aside and restore
  from the copy in a `finally`.
- Code, comments and commit messages in English.
- Every task ends green on all three packages: test, analyze, format.
- **This plan may not amend `CLAUDE.md`.** A gate passable by editing the rule it
  is measured against is not a gate.

---

## What this owes Plan 3g

- **A working text LOD**, one of the four subsystems 3g was carrying. 3g inherits
  three: the `InstanceNode`/`StyleContext` model completion, the definition
  picture cache, and tiling.
- **The threshold ladder table**, the first real measurement of how much of a
  zoomed-out frame is text, with the caveat that it locates a step.
- **A measured distinct-`(text, styleHandle)` count** for the rig corpus, which
  is the number any future text cache is sized against.
- **The unresolved question of whether a cached picture may contain text at
  all.** A baked picture is recorded per scale band; LOD is a function of
  continuous scale. A definition baked at one band and replayed across the band
  either draws text the current zoom would have culled or omits text it would
  have drawn. 3g must decide; this plan does not.
