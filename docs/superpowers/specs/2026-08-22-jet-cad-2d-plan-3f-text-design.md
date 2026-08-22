# Plan 3f — text wiring and level of detail

**Date:** 2026-08-22
**Status:** design, approved section by section on 2026-08-22
**Line:** `jet_cad_2d` / `jet_cad_2d_flutter` — the live pure-Dart 2D line
**Branch:** `main`, worked directly, no worktree

## Renumbering

The roadmap in `STATUS.md` gave `3f` to the definition/tile picture cache.
This plan takes the `3f` slot because it ships first, and the picture cache
moves to **`3g`**. Every `3f` in `STATUS.md` that means the picture cache is
swept to `3g` as part of this plan's first task.

The reason for the reorder is a measurement, not a preference. Plan 3f's
original justification was Plan 3b's finding that the dominant render cost is
leaf-count-bound GPU vertex work — measured on the **canvas** backend, with one
`save`/`transform`/`restore` triple per leaf. Plan 3d retired that backend:
`defaultRenderBackend()` returns `RenderBackend.vertices` unconditionally, and
the vertices sink draws 10,000 entities in 5.71 ms build / 6.68 ms raster and
500,000 in 17.44 / 21.64. The speed argument for a picture cache is much weaker
than it was when it was written; the largest *measured* remaining loss in the
text path is not.

---

## The problem

Two defects, both live on `main` at `8fad846`, both in text.

### 1. A document built the ordinary way draws no text and reports no error

`DraftDocument.empty`'s `measurer` parameter defaults to
`const InsertionPointMeasurer()` (`draft_document.dart:90`), which returns
`TextMetrics.zero` for every string. `DraftPainter._drawText` takes its metrics
from `document.textMeasurer` (`draft_painter.dart:807`) and composes the text
transform from them; with a zero `capHeight` the scale is `height / 0`, so the
transform is degenerate and nothing readable reaches the canvas.

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

### 2. Two paragraph caches, and even one would not be enough

Because the painter and the sink read different measurers, a text leaf costs up
to two layouts. Plan 3c measured the cost on the query path alone at **+97 ms at
50,000 entities and +105 ms at 500,000**, whole drawing, even into a
`NullDrawSink`.

Unifying the two objects does **not** by itself remove the second layout, and
this is the finding that shapes the design. `FlutterTextMeasurer`'s cache is
keyed `(text, styleHandle, argb)`. The painter reaches it through `measure()`,
which substitutes `kMetricsProbeArgb` (`0xFF000000`,
`flutter_text_measurer.dart:21`); the sink reaches it through `paragraphFor()`
with the entity's resolved ARGB. Different colour, different key, **two layouts
of the same string in the same cache**.

The class's own doc comment states the fact that makes this wrong: colour cannot
change metrics. The colour belongs to the `ui.Paragraph`, not to the
`TextMetrics`. The key is at the wrong layer.

### 3. Whole-drawing cache thrash

Plan 3c measured, at the whole-drawing camera, **4,140 new paragraph layouts and
4,140 new evictions per frame** — the cache evicting entries the same frame asks
for again — at **both** 50,000 and 500,000 entities, because the count is bounded
by string variety rather than entity count. In each of two caches: 349,740
layouts over the run.

Raising `kParagraphCacheLimit` is not the answer and Plan 3c's Ruling 4 forbids
using it as one. A bigger cache holds one zoom level of one corpus. Text that is
too small to read does not need to be laid out at all.

---

## Decisions taken

Four, settled with the human on 2026-08-22 before this document was written.

1. **This plan is text, not the picture cache.** The picture cache is four
   independent subsystems — the `InstanceNode`/`StyleContext` model completion,
   the definition picture cache, tiling, and text LOD — and does not fit one
   spec. Text LOD is the only one of the four with no dependency on the other
   three, and it carries the largest measured loss.
2. **Below the threshold, draw nothing.** Not a greeked bar, not two tiers. Both
   alternatives are to be written into the code as comments, with the reason
   each was not taken now.
3. **The document owns the measurer; the widget borrows it.** Approach A of
   three. The rejected alternatives are recorded under "Alternatives considered".
4. **The paragraph cache splits in two**, colour-free metrics and coloured
   paragraphs, because one cache with one key cannot serve both callers without
   laying every coloured string out twice.

---

## Non-goals

- MTEXT, DXF `72=3`/`72=5` layout, and any other text feature. Out of 3c's
  scope and out of this one's.
- The definition/tile picture cache. That is Plan 3g.
- The `InstanceNode`/`StyleContext` model completion and `documentRevision`.
  Prerequisites for 3g, not for this plan.
- Permitted divergence 5 (overlapping translucent strokes on a triangle soup).
  Still open, still unexercised, still nobody's.
- Moving `AllocationMeter` into `jet_cad_2d/lib/src/testing/` so the Flutter
  suite can run a real allocation profile. Named as an accepted gap below.

---

## Section 1 — measurer ownership and the split cache

### Ownership

`DraftCanvasState._measurer` is deleted. `_attach()` resolves the sink's
measurer from `widget.document.textMeasurer`.

`DraftCanvas` refuses, at `_attach()` time, a document whose `textMeasurer` is
not a `FlutterTextMeasurer`. The refusal is **unconditional** — it does not
consult `drawText`. `drawText: false` is a measurement flag, not a licence to
carry a measurer that computes the wrong extents: a document whose boxes were
computed from `TextMetrics.zero` is wrong whether or not glyphs are drawn. A
guard conditioned on `drawText` would also force `CanvasDrawSink` to hold a
throwaway `FlutterTextMeasurer` for its typed field
(`canvas_draw_sink.dart:41`), which is the second cache coming back.

The refusal message names the fix, in full, including the construction order:

```
DraftCanvas requires document.textMeasurer to be a FlutterTextMeasurer;
it is InsertionPointMeasurer. Build the measurer first and pass it to the
document:

    final measurer = FlutterTextMeasurer();
    final doc = DraftDocument.empty(measurer: measurer);
```

`DraftDocument.empty`'s `InsertionPointMeasurer` default **stays**. It is a
legitimate, documented lower bound for an engine-only caller — `jet_cad_2d` has
no Flutter dependency and cannot construct a real measurer. The rule belongs at
the widget boundary, which is the first point at which a real font stack is
known to exist.

`DraftPainter` is unchanged: it already reads `document.textMeasurer`. What
changes is that the sink now reads the same object.

This makes Plan 3c's **Ruling 36** — "a golden document must carry a real
measurer" — structural rather than conventional.

### The split cache

`FlutterTextMeasurer` holds two maps instead of one.

| map | key | value | bound | eviction |
|---|---|---|---|---|
| metrics | `(text, styleHandle)` | `TextMetrics` | `limit` | free — no native memory |
| paragraphs | `(text, styleHandle, argb)` | `ui.Paragraph` | `limit` | `Paragraph.dispose()` |

Both maps are `LinkedHashMap`s ordered least-recently-touched first, evicted the
same way, at the same `limit` — `kParagraphCacheLimit = 512`. Ruling 4's single
permitted raise stays unspent. The metrics map is bounded even though its entries
are four doubles apiece: an unbounded map grows to every string in the document,
which is the shape of a leak whatever it holds.

`measure()` reads the metrics map. On a miss it builds a paragraph at
`kMetricsProbeArgb`, derives the metrics, stores them, and **keeps** the
paragraph in the paragraph map. Keeping it is deliberate: ACI 7 resolves to
black in this renderer and black text is the common case, so the probe
paragraph is usually the one the sink asks for next. Disposing it would
guarantee a miss.

`paragraphFor()` reads the paragraph map, unchanged in behaviour.

Both maps must be probed without allocating. The paragraph map keeps the
existing mutable `_CacheKey` probe; the metrics map needs its own two-field
equivalent, for the reason recorded in `MetricModelMeasurer`'s doc comment —
building a record key per lookup was measured at roughly 41 `_Record`
allocations per pick and broke `query_allocation_test`.

`measure()` must return the **identical** `TextMetrics` instance on a repeat
call. That is the property `MetricModelMeasurer` already guarantees and the only
proxy available for "this lookup allocates nothing" on the Flutter side (see
Accepted gaps).

### What this buys, stated honestly

The first time a string in a non-black colour is seen it still costs two
layouts: the painter must measure before it can compose a transform, the sink
must lay out to draw, and two colours are genuinely two `ui.Paragraph` objects.
**Steady state is zero**, which is what every gate row measures.

The real win is the query path. `DraftDocument.extents`, `entityBounds` and
picking now hit the metrics map and build **no** `ui.Paragraph` at all once it
is warm. That is where the +97 ms / +105 ms came from.

### Blast radius

Seven files construct a `DraftCanvas`. The three golden ladders already carry a
`FlutterTextMeasurer` (Ruling 36) and are unaffected. The guard trips the other
four, seven documents in total:

| file | documents | current measurer |
|---|---|---|
| `draft_canvas_test.dart` | 3 | two default, one `MetricModelMeasurer` |
| `render_backend_test.dart` | 2 | `generateDocument`'s default |
| `frame_path_seam_test.dart` | 1 | default |
| `apps/dev_harness_2d/lib/main.dart` | 1 | conditional — see below |

Each is a one-line change: pass a `FlutterTextMeasurer`. `generateDocument`'s own
`measurer` default stays `InsertionPointMeasurer`, for the same reason
`DraftDocument.empty`'s does — an engine-only caller is legitimate. The rule is
at the `DraftCanvas` boundary and nowhere else.

`main.dart` is the interesting one. It already works around this defect by hand:

```dart
measurer:
    kTextCorpus ? FlutterTextMeasurer() : const InsertionPointMeasurer(),
```

and its doc comment names the failure exactly — "every text transform to a
singular matrix. A text corpus built on it looks like a text corpus and draws
nothing measurable." The workaround was applied at one call site and the cause
left in place. Under the guard the ternary collapses to an unconditional
`FlutterTextMeasurer()`, and the thing that turns text off becomes
`labelFraction: 0` and `attributedInstanceFraction: 0`, which is the correct
axis. **A task that leaves the ternary in place has not done the work.**

`measurement_rig.dart` reads `sink.measurer` (`:217`) and prints `newLayouts`
and `newEvictions` from it (`:155`). Under this change `sink.measurer` **is**
`document.textMeasurer`, so the rig keeps working through the same expression
and starts reporting the only cache there is.

### Alternatives considered

**The widget owns it and attaches it to the document.** `textMeasurer` would
stop being `final` and a once-only `attachMeasurer()` would call
`invalidateDerived()`. Zero burden on the application, which is its real appeal.
Rejected because applications read `doc.extents` to place the initial camera
*before* the canvas mounts: that read would be served by zero metrics, and
invalidating the cache afterwards does not un-place a camera already built from
the wrong box. `DraftDocument.textMeasurer`'s own doc comment argues the same
class of hazard for making the field `final`.

**Keep two objects and make the default loud.** Drop the default from
`DraftDocument.empty` so a measurer must be named. Closes the silent failure and
leaves the double layout exactly where it is, with the +97/+105 ms intact.
Cheapest and worth the least.

---

## Section 2 — level of detail

### The test, and where it goes

`DraftPainter._drawText` gains an early return. The order in the method becomes:

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
the style record (`text_geometry.dart:172`). `TextLayout.height` is the
effective DXF text height, which **is** the cap height, in world units.
`Transform2.scaleMagnitude` is `sqrt(|det|)`, already in the codebase
(`transform2.dart:87`) and already documented as the representative scale the
renderer uses. `chain` carries camera, ancestors, instance, placement and
rebase, so the product is the on-screen cap height in pixels.

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

The plan must measure a threshold ladder against the corpus — layouts, evictions
and `culledTextCount` at a range of thresholds and at both cameras — and record
the table beside the constant. The constant ships with a measurement, not with
an estimate.

### Disabling it

`DraftPainter` gains `minTextCapPixels`, forwarded from `DraftCanvas`, default
`kMinTextCapPixels`. **`0.0` disables LOD.** The exit gate compares LOD-on
against LOD-off on the same corpus at the same camera; without a control arm the
before/after numbers are two different documents.

Both fields are `final`, for the reason `drawText` is (`draft_canvas.dart:87`).

### Anisotropy

`scaleMagnitude` is the geometric mean of the axis scales, so text squashed in y
under an anisotropic placement reads taller than it renders and is culled later
than it should be. This is the same approximation the painter already makes for
curve stroke widths past `kAnisotropyThreshold`, and it errs toward drawing.
Recorded here rather than hidden; not counted separately.

### The reference walk derives its own

`reference_walk.dart` is the differential oracle. It must apply the same LOD
rule and must **compute it itself** — from `resolveTextAttributes(...).height`
(`text_geometry.dart:62`) and its own `chain.scaleMagnitude` — never by asking
the painter what it decided. Sharing the decision would have the oracle share
the assumption it exists to test. This is the correction Plan 3e made at
`24cfd23` for fill triangulation, applied here before it can go wrong.

The walk already skips the empty string independently
(`reference_walk.dart:161`), which is the same pattern.

### The counter

`DraftPainter.culledTextCount`, reset per frame in `paint()` beside the others.

Kept separate from `skippedTextCount`, which stays the empty-string and
`drawText: false` half. Blended, the gate cannot tell which mechanism fired —
the same mistake Ruling 54 records for the cache hit rate.

### Documented alternatives

Both rejected alternatives are written into `_drawText` as comments, each with
what it would cost:

- **Greeking** — draw a bar the width of the text instead of the glyphs, so a
  zoomed-out plan keeps its visual weight. In the vertices sink a bar is two
  batched triangles, effectively free. The obstacle is the width: it needs
  `advanceWidth`, so either the layout happens anyway and the saving is lost, or
  a font-free width model (`text.length × ratio`, the shape
  `MetricModelMeasurer` uses) is introduced as a new approximation.
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

Every row below is a count: layouts, evictions, culled entities, allocations.
Plan 3c's whole session ran under macOS Low Power Mode and every timing in it is
contaminated; Plan 3e's 10,000-entity row was measured, cleared its bar by a
wide margin, and still could not be scored for the same reason. Counts are
machine-independent.

Timings are still to be measured and written down. They are not gates.

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
| 2 | whole-drawing camera, repeat frame, evictions | **0** (baseline 4,140) |
| 3 | working-set camera, layouts and evictions | **0** — no regression |
| 4 | `culledTextCount`, whole-drawing camera | **> 0** |
| 5 | `culledTextCount`, working-set camera | **0** |
| 6 | `doc.extents` at `minTextCapPixels` 0 and 1000 | **bit-identical** |
| 7 | picking a text entity, at both thresholds | same hit |
| 8 | `DraftCanvas` over a document with the default measurer | **throws, naming the fix** |
| 9 | differential oracle, LOD on, both cameras | passes |
| 10 | `layoutCount` after a warm pick sweep | **0** |
| 11 | mutation log | every mutant killed or argued equivalent |

Rows 4 and 5 are load-bearing as a pair. Row 4 alone passes on a corpus with no
text; row 5 alone passes with LOD disabled. One proves the mechanism fires, the
other proves it does not fire where text is readable — which is the row a
threshold set too high fails.

Row 10 is Plan 3c carry-forward item 2 discharged: the query path must build no
`ui.Paragraph` once the metrics map is warm.

**If a failable row misses: record the number and stop.** Plan 3b's Task 4 stop
clause is the precedent. Do not tune the threshold until the row complies —
say what the number implies for Plan 3g's text LOD and stop.

### Named mutants

A test is worth landing here only if a named mutation makes it red.

| # | mutation | expected killer |
|---|---|---|
| 1 | move the LOD test after `measure()` | row 1 |
| 2 | `<` → `<=` at the threshold | boundary fixture, one entity exactly at `kMinTextCapPixels` |
| 3 | drop `chain.scaleMagnitude`, cull on world height alone | row 5 (culls at every zoom) |
| 4 | drop `_culledText++` | row 4 |
| 5 | reference walk reads the painter's decision | a fixture where the two would differ |
| 6 | key the metrics map by ARGB — undo the split | row 10 |
| 7 | allocate the metrics probe key per call | the `identical` assertion |
| 8 | remove the `DraftCanvas` guard | row 8 |
| 9 | `measure()` does not store metrics | rows 1 and 10 |
| 10 | apply LOD inside `entityBounds` | row 6 |
| 11 | `culledTextCount` not reset per frame | a two-frame fixture |

Mutant 5 needs a fixture the plan must design deliberately: the painter and the
walk must be capable of disagreeing, which means text near the threshold under a
non-identity placement. A fixture at the identity transform cannot tell them
apart — the repo's named dominant defect class.

### Goldens

One new ladder, `text_lod_ladder`, three rungs × two backends = six PNGs.

The fixture is one drawing carrying three text heights under a camera chosen so
that the smallest is culled, the largest is not, and the middle sits near the
boundary. It pins the threshold visually and goes red if the constant moves.

Per Ruling 36 the golden document carries a `FlutterTextMeasurer`, which the
guard now enforces anyway. Per the `flutter_test` trap, a golden asserting
anything about glyph shape needs `Roboto-Regular.ttf` through a `FontLoader`;
this one asserts presence and absence, so Ahem is sufficient — and the plan must
say so explicitly rather than leave it to the reader.

### The rig

`apps/dev_harness_2d` gains a `LOD` define. Per the trap,
`bool.fromEnvironment` reads `--dart-define=LOD=1` as **false**; the define is
therefore a `String.fromEnvironment` that throws on anything but `"true"` and
`"false"`, which is the pattern Plan 3e used for `FILLS`.

`printInvariants` (`measurement_rig.dart:154`) gains `culledText=` beside
`skippedText=`. Per the trap, any rig guard belongs before the first print or
nowhere — R4a and R4b printed three lines and threw, for months.

---

## Accepted gaps

**The metrics map's allocation behaviour cannot be profiled.**
`query_allocation_test.dart` lives in the engine suite because
`jet_cad_2d_flutter` has no `vm_service` dependency — Plan 3c carry-forward
item 3. The split cache is Flutter-side, so no VM allocation profile can watch
it. The proxy is the `identical` assertion on a repeat `measure()` call. That is
weaker than a profile and is to be written as weaker, not as proof. Moving
`AllocationMeter` into `jet_cad_2d/lib/src/testing/` would close it and is out
of scope here.

**Anisotropic placements cull late.** Stated in Section 2, not counted.

**The engine package is untouched.** `DraftDocument`, `TextMeasurer`,
`TextMetrics` and `text_geometry.dart` all keep their current shape. If a task
finds it needs an engine change, that is a signal the design is wrong, not a
licence — raise it as a ruling.

---

## Files

**Modified**

- `packages/jet_cad_2d_flutter/lib/src/flutter_text_measurer.dart` — the split
- `packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart` — measurer resolution,
  the guard, `minTextCapPixels`
- `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart` — the LOD test,
  `culledTextCount`, `kMinTextCapPixels`, `minTextCapPixels`
- `packages/jet_cad_2d_flutter/lib/src/reference_walk.dart` — an independently
  derived LOD
- `apps/dev_harness_2d/lib/main.dart` — the `LOD` define, and the
  `kTextCorpus ? ... : ...` measurer ternary collapsed to an unconditional
  `FlutterTextMeasurer()`
- `apps/dev_harness_2d/lib/measurement_rig.dart` — `culledText=`
- `packages/jet_cad_2d_flutter/test/draft_canvas_test.dart` — three documents
  adapted to the guard
- `packages/jet_cad_2d_flutter/test/render_backend_test.dart` — two documents
- `packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart` — one document
- `STATUS.md` — the 3f/3g renumbering

**Created**

- `packages/jet_cad_2d_flutter/test/text_lod_test.dart`
- `packages/jet_cad_2d_flutter/test/golden/text_lod_ladder_golden_test.dart`
  and six PNGs
- `docs/superpowers/notes/2026-08-22-plan-3f-results.md`
- `docs/superpowers/notes/plan-3f-mutation-log.md`

---

## Global constraints

Copied from `CLAUDE.md`; every task's requirements include them.

- The frame path allocates nothing per entity in steady state, and O(1) per
  flush.
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

- **A working text LOD**, which is one of the four subsystems 3g was carrying.
  3g inherits three: the `InstanceNode`/`StyleContext` model completion, the
  definition picture cache, and tiling.
- **The threshold ladder table**, which is the first real measurement of how
  much of a zoomed-out frame is text.
- **The unresolved question of whether a cached picture may contain text at
  all.** A baked picture is recorded per scale band; LOD is a function of
  continuous scale. A definition baked at one band and replayed across the band
  either draws text the current zoom would have culled or omits text it would
  have drawn. 3g must decide, and this plan does not.
