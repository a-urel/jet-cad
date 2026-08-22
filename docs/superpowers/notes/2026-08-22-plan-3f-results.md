# Plan 3f results — text wiring, the split cache, and level of detail

**Exit gate: 11 of 13 pass, 2 miss, 0 unevaluable.** The two that miss are
rows 1 and 2 — zero new paragraph layouts and zero paragraph evictions on a
repeated, unchanged frame at the whole-drawing camera. They are recorded and
left missing, per the plan's own stop clause. Nothing in this plan was tuned
to make them pass.

Mutation log:
[plan-3f-mutation-log.md](plan-3f-mutation-log.md) — fifteen named mutants, 14
killed, 1 restatement, plus one mutation recorded as unmeasurable with its
reason.

## Conditions

**Low Power Mode: OFF**, read before this task's first timed run, per the
spec's rule that Plan 3c's whole contaminated session established:

```
$ pmset -g | grep lowpowermode
 lowpowermode         0
```

Every timing in this note carries that mark. **No timing here is a gate.**
Every failable row is a count.

```
$ flutter --version
Flutter 3.47.1 • channel stable • https://github.com/flutter/flutter.git
Framework • revision 6655482ec0 (3 days ago) • 2026-08-19 10:07:23 -0700
Engine • hash 11d79658c444477b06513d32b52c8c4ccb7276b0 (revision 5d53178869) (3 days ago) • 2026-08-18 23:36:01.000Z
Tools • Dart 3.13.1 • DevTools 2.60.0
```

Corpus: `textRigCorpus(50000)` and `textRigCorpus(500000)`
(`test/rig/rig_support.dart`), viewport `kRigViewport`. Rig command:

```sh
cd packages/jet_cad_2d_flutter
CI=true flutter test --tags rig --run-skipped test/rig/paint_microbench_test.dart
```

---

## The thirteen failable criteria

| # | row | threshold | measured | verdict |
|---|---|---|---|---|
| 1 | whole-drawing camera, repeat frame, new layouts | 0 (baseline 4,140) | **3,876** at 50k, **3,658** at 500k | **MISS** |
| 2 | whole-drawing camera, repeat frame, paragraph evictions | 0 (baseline 4,140) | **3,876** at 50k, **3,658** at 500k | **MISS** |
| 3 | working-set camera, layouts and paragraph evictions | 0 | 0 and 0, both corpus sizes | **PASS** |
| 4 | `culledTextCount`, whole-drawing camera | > 0 | **414** at 50k, **2,246** at 500k | **PASS** |
| 5 | `culledTextCount`, working-set camera | 0 | 0, both corpus sizes | **PASS** |
| 6 | `doc.extents` at `minTextCapPixels` 0 and 1000 | bit-identical | bit-identical on all four components | **PASS**, structurally — see below |
| 7 | picking a text entity, at both thresholds | same hit | same entity, kind and world point | **PASS** |
| 8 | `DraftCanvas` over a document with the default measurer | throws, naming the fix | `ArgumentError` carrying the two-line fix | **PASS** |
| 9 | differential oracle, LOD on, both cameras | passes | passes at both, plus an LOD-off arm | **PASS** |
| 10 | extents-sweep non-interference | layouts 0, paragraph evictions 0 | 0 and 0 at unit and corpus scale | **PASS**, with a caveat — see below |
| 11 | split view: dispose one canvas | the other's cache unchanged | sibling keeps its one live paragraph | **PASS** |
| 12 | `measurer.clear()` | every live paragraph `debugDisposed` | `debugDisposed` true, both maps empty | **PASS** |
| 13 | mutation log | every mutant killed, argued equivalent, or unmeasurable with its reason | 14 killed, 1 restated, 1 unmeasurable | **PASS** |

### Rows 1 and 2 — the miss, and what it means

At the shipped `kMinTextCapPixels = 3.0`, the whole-drawing camera over the
50,000-entity corpus needs **3,876 distinct `(text, styleHandle, argb)`
paragraph keys in a single frame** against a 512-entry cache. A repeated,
unchanged frame therefore produces 3,876 new layouts and 3,876 paragraph
evictions — **zero cache hits**. Verbatim, from the rig's `[text on]` block
with a measurer already warm from twenty prior paints:

```
    [text on]
      R1 paint          p50=550.335ms p95=592.156ms min=530.677ms (n=37)
      R3 query-only     p50=140.727ms p95=152.163ms min=138.560ms (n=120)
      textOps: 4514  culledText: 414  skippedText: 0
      newLayouts=3876 newParagraphEvictions=3876
      cache: layouts=224808 paragraphEvictions=224296 metricsEvictions=0 liveParagraphs=512 liveMetrics=4020
```

The baseline this plan set out to beat was 4,140. 3,876 is a 6.4% improvement
on a row whose threshold is zero. **Rows 1 and 2 miss.**

Three independent mechanisms read the same 3,876 and are recorded because one
number from one mechanism is not a measurement: the ladder's query-only
`TextKeySink` pass (`distinctKeys`, draws nothing and lays nothing out), the
warm-cache `newLayouts` delta above, and the rig's pre-existing
`DISTINCT CACHE KEYS: 3876   (limit 512) OVER` print.

**The plan pre-committed to what happens next, and it binds this task: record
the number and stop.** Two things were available and neither was taken.

1. **Raising `kMinTextCapPixels` is refused.** 6.0 makes both rows comply
   outright (`distinctKeys=94`, `paragraphEvictions=0` — see the ladder). 3.0
   was chosen from a readability argument: below roughly three pixels of cap
   height a glyph cannot resolve two strokes. 6.0 would be chosen because a
   gate row needs it. Those are different in kind, and tuning a threshold
   until a gate passes is the failure this clause exists to prevent.
2. **Spending Ruling 4's single permitted `kParagraphCacheLimit` raise is the
   human's decision, not this plan's.** It is now *available* for the first
   time — the ruling requires a measured distinct-visible-key count recorded
   beside any raise, and that count did not exist until Task 8 produced it.
   Written up below as an option, and left unspent.

### The option this plan leaves on the table, unspent

**Raise `kParagraphCacheLimit` from 512 to something above 3,876.**

- **What it buys.** Rows 1 and 2 at the whole-drawing camera, on this corpus,
  at the shipped readability threshold. `liveParagraphs` would settle at
  3,876 and the repeat frame would hit every key.
- **What it costs.** Holding **3,876 native `ui.Paragraph` objects live in one
  frame**. A `Paragraph` holds native glyph memory that outlives the Dart
  object until `dispose()` runs. Plan 3d's carry-forward note argued against
  exactly this shape of decision — a bound relaxed to fit one corpus's
  worst-case camera rather than to fit a memory budget — and that argument
  has not been answered by anything measured here. Nobody has measured what
  3,876 live paragraphs cost in resident memory on any of the three targets.
- **What it does not buy.** It is a fact about *this* corpus at *this*
  camera. The 500,000-entity corpus needs 3,658, but the key-pressure ladder
  in the same rig run shows the count keeps climbing as the camera zooms out;
  a bound set at 4,096 is a bound that a different drawing walks past.
- **The ruling's terms.** One raise, once, with the measured count recorded
  beside it. Spending it here forecloses spending it in 3g, where the picture
  cache may want it.

**This is written down so a human can decide it, and is deliberately not
decided here.**

### Row 6 — passes, and cannot fail

`doc.extents` is bit-identical after a painter at `minTextCapPixels: 0.0` and
after one at `1000.0`, with `invalidateDerived()` between the reads so the
second is a genuine recomputation. That invariant is true and worth stating.

It is also **structurally guaranteed rather than testable**, and the mutation
log records that as a restatement instead of a kill. Mutant 10 — a cull leaked
into `entityBounds` — was fired, twice, and row 6's test **passed both times**.
`entityBounds` is a pure function of stored document data with no channel to
any painter's threshold, so it recomputes identically on both reads and two
identical wrong answers compare equal. The mutation is caught, incidentally, by
four other tests: a collapsed bound drops the leaf out of the spatial index's
query window, so `culledTextCount` reads 0 where 1 was expected.

### Row 10 — passes at both scales; only one of them discriminates

Row 10's procedure (paint warm at the working-set camera; `invalidateDerived()`
then a full `doc.extents` read; repaint; read the repeat frame's new paragraph
layouts and evictions) had no in-tree form and now has one, inside the rig:

```
  -- row 10: extents-sweep non-interference --
    sweep (66522.34207401797 x 48478.932530765655 world units): layouts=0 paragraphEvictions=0 metricsEvictions=0
    repeat frame after the sweep: newLayouts=0 newParagraphEvictions=0 newMetricsEvictions=0 liveParagraphs=512 liveMetrics=4020
```

**Two premises in the design document turn out to be wrong, and the row is
weaker than it reads.**

- `doc.extents` is **not** the 4,020-key sweep the spec justified the row
  with. `_computeExtents` is `_boundsOfContainer` over the tree with a
  per-*definition* bounds cache, so a corpus of 20,000 instances over 200
  definitions measures **12** distinct strings, not 4,020. The 4,020 figure
  belongs to `ContainerIndex.build`, which is a genuinely per-entity sweep and
  runs once when the index is built.
- Consequently the corpus-scale row **passes under both mutations it was
  written to catch**. Under mutant 6 (one merged map) the sweep evicted 12
  paragraphs and the repeat frame still read `newLayouts=0`; under mutant 7
  (`metricsLimit` cut to the paragraph bound) the same. LRU drops the *oldest*
  entries, and this camera's 18 keys were the newest with 512 slots to sit in.

The discriminating evidence is the **unit-scale** row 10 in
`flutter_text_measurer_test.dart` — `paragraphLimit: 4` against a 200-key
sweep leaves the drawn set no such margin, and mutants 6 and 12 both redden it
(200 paragraph evictions where the split cache has none). The corpus-scale
block stays because it is the plan's stated procedure and because its
`liveMetrics` field *is* the one that moves under both mutations; its comment
says plainly that it does not discriminate on this corpus.

---

## The threshold ladder

Reproduced from the committed tree at `1dc76d4` for this note, byte-for-byte
against Task 8's table:

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test --tags rig --run-skipped \
  test/rig/paint_microbench_test.dart --name 'text paint at 50000$' \
  --dart-define=LADDER=0.0,1.0,2.0,3.0,4.0,6.0,10.0
```

| threshold | camera | distinctKeys | layouts | paragraphEvictions | metricsEvictions | culledText | liveParagraphs | liveMetrics |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| 0.0 | whole drawing | 4140 | 4140 | 3628 | 0 | 0 | 512 | 4020 |
| 0.0 | working set | 18 | 18 | 0 | 0 | 0 | 18 | 4020 |
| 1.0 | whole drawing | 4140 | 4140 | 3628 | 0 | 0 | 512 | 4020 |
| 1.0 | working set | 18 | 18 | 0 | 0 | 0 | 18 | 4020 |
| 2.0 | whole drawing | 4140 | 4140 | 3628 | 0 | 0 | 512 | 4020 |
| 2.0 | working set | 18 | 18 | 0 | 0 | 0 | 18 | 4020 |
| **3.0** | **whole drawing** | **3876** | **3876** | **3364** | 0 | **414** | 512 | 4020 |
| **3.0** | **working set** | **18** | **18** | **0** | 0 | **0** | 18 | 4020 |
| 4.0 | whole drawing | 1123 | 1123 | 611 | 0 | 3368 | 512 | 4020 |
| 4.0 | working set | 18 | 18 | 0 | 0 | 0 | 18 | 4020 |
| 6.0 | whole drawing | 94 | 94 | **0** | 0 | 4751 | **94** | 4020 |
| 6.0 | working set | 18 | 18 | 0 | 0 | 0 | 18 | 4020 |
| 10.0 | whole drawing | 0 | 0 | 0 | 0 | 4928 | 0 | 4020 |
| 10.0 | working set | 18 | 18 | 0 | 0 | 0 | 18 | 4020 |

### What the ladder says, plainly

**Level of detail is decisive at the working-set camera — and by not firing at
all.** Every threshold from 0.0 to 10.0 gives identical numbers: 18 distinct
keys, 18 layouts, 0 culled, 0 evicted. The smallest surviving cap height at
that camera is **53.67 px**, about five times the widest threshold tried and
17.9× the shipped one. This is the camera a frame budget is actually about,
and it is nowhere near the cliff. There is nothing for LOD to do there, and
rows 3 and 5 pass because of it.

**Level of detail is insufficient at the whole-drawing camera, at a
readability-justified threshold.** 3.0 culls 414 of 4,928 candidates and
leaves 3,876 keys chasing 512 slots.

**The step is a band from 3.0 to 6.0, not a point.** `generate_document.dart`'s
fixed-height-80.0 attributes are about 4,000 of the ~4,928 candidates, and at a
small enough camera scale their pixel cap heights cluster tightly. But the
corpus's `mirroredFraction` and `nonUniformFraction` placement transforms give
per-instance `scaleMagnitude` real spread **even at one fixed logical text
height**, so the mass crosses over a roughly 3-unit-wide band rather than at
one exact threshold value: 414 culled at 3.0, 3,368 at 4.0, 4,751 at 6.0, the
full 4,928 at 10.0. Reported as a band rather than smoothed into a cliff.

`liveMetrics` reads **4,020 at every threshold and both cameras** — level of
detail does not touch the metrics map at all, because `entityBounds` fills it
for every text entity while the index is built, before any camera exists, and
the painter's LOD check only ever touches keys already there. That is the
measured count now written into `kMetricsCacheLimit`'s doc comment.

---

## Per-site LOD margin (from Task 6)

Every `DraftPainter` construction site in the package that draws text, with the
smallest **drawn** cap height it produces and its margin over the 3.0
threshold. Taken by temporarily instrumenting `_drawText` to print, per frame,
the smallest cap height among drawn text; the instrumentation was removed
before the commit.

| site | camera | drawn / culled | smallest drawn cap height | margin | decision |
|---|---|---|---|---|---|
| `text_paint_test.dart` — hand-built label tests | `doc.extents` fit | 1 / 0 each | 57.90 / 76.44 / 83.41 / 111.84 px | 19×–37× | default |
| `text_paint_test.dart` — `_textCorpus(2000)`, whole drawing | `fit(doc.extents)` | 25 / 116 | **3.0591 px** | **1.02×** | thin → new explicit `0.0` arm added |
| `text_paint_test.dart` — `_textCorpus(2000)`, cropped | `cameraOverDocumentCentre` | 15 / 0 | **3.2289 px** | **1.08×** | thin → covered by the same `0.0` arm |
| `text_paint_test.dart` — `'the text corpus is not vacuous'` | `fit(doc.extents)` | 25 ops vs `greaterThan(20)` | **3.0591 px** | **1.02×** | `0.0` explicitly |
| `text_paint_test.dart` — `'drawText: false …'` | `fit(doc.extents)` | 25 / 116 | **3.0591 px** | **1.02×** | `0.0` on both painters |
| `rig/paint_microbench_test.dart` — whole drawing, 50k | `wholeDrawingCamera` | 4,514 / 414 | **3.0006 px** | **1.0002×** | default kept on purpose, plus a degeneracy guard |
| `rig/paint_microbench_test.dart` — working set, 50k | `workingSetCamera` | 19 / 0 | **53.67 px** | 17.9× | default |
| `support/sink_comparison.dart` | its own | 1 / 0 | **28.98 px** | 9.7× | default |
| `draft_painter_root_test.dart` — blank-text counting, 30k | `fit(doc.extents)` | 114 / 454 | **3.0080 px** | **1.003×** | `minTextCapPixels: 0.0` |
| `draft_canvas_test.dart` — `'drawText reaches the painter…'` | its own | 1 / 0 | **106.40 px** | 35.5× | default |
| `golden/text_ladder_golden_test.dart` | `kGoldenViewport` | — | **22 px** | 7.3× | default; goldens unchanged |

**The five thin sites are the finding.** Four tests sat within 8% of the
threshold and one within 0.02%: a later `kMinTextCapPixels` of 3.3 would have
left them comparing text-free drawings and still green. They were given
explicit `0.0` arms rather than a moved threshold. The rig's whole-drawing row
keeps the shipped default deliberately — a rig that measured a frame nobody
paints is not a frame budget — and prints its own margin every run
(`LOD MARGIN: smallest drawn cap height 3.0005 px  (threshold 3.0 px, 1.0002x)  culled: 414`)
so a human reading a transcript sees how close it is on the run in front of
them.

A note on a visible discrepancy left unreconciled: the pinned figure at
`paint_microbench_test.dart:313` reads **3.0006 px** and three separate runs
of the rig this session all measured **3.0005 px**. The difference is in the
fifth significant digit, inside the bisection's declared 1e-4 relative
tolerance, and both round to the same reported margin. Left visible rather
than silently edited.

---

## Timings, recorded and not gated

50,000 entities, `[text on]` / `[text off]`, Low Power Mode off:

| camera | arm | R1 paint p50 | R3 query-only p50 |
|---|---|---|---|
| whole drawing | text on | 550.3 ms | 140.7 ms |
| whole drawing | text off | 499.0 ms | 139.6 ms |
| working set | text on | 19.3 ms | 1.44 ms |
| working set | text off | 19.3 ms | 1.43 ms |

500,000 entities:

| camera | arm | R1 paint p50 | R3 query-only p50 |
|---|---|---|---|
| whole drawing | text on | 927.2 ms | 284.4 ms |
| whole drawing | text off | 866.2 ms | 282.3 ms |
| working set | text on | 44.5 ms | 3.46 ms |
| working set | text off | 44.5 ms | 3.45 ms |

Text costs about 50–60 ms of a whole-drawing paint at either corpus size and
is **not measurable** at the working-set camera. This is the widget-level rig
(JIT, `PictureRecorder`), a relative signal only, per the file's own header.

The device arms (`flutter drive --profile -d macos`) are in Task 8's report.
Both arms complete cleanly, `minTextCapPixels=3.0` and `0.0` visibly differ on
the transcript, and `culledText=0` in both — that camera stays well above both
thresholds, consistent with the ladder's working-set row.

---

## Suites, on the merged result

Every count below was produced by running the suite, not by reading a report.

| suite | result |
|---|---|
| `packages/jet_cad_2d` — `CI=true dart test` | **777 pass**, analyze and format clean |
| `packages/jet_cad_2d_flutter` — `CI=true flutter test` | **299 pass, 1 skipped**, analyze and format clean |
| `CI=true flutter test --tags golden` | **35 pass**, 40 PNGs |
| `apps/dev_harness_2d` | analyze and format clean |
| `benchmark/query_throughput.dart` | **GATE: PASS** — every gated row under its threshold |

The one skip is `test/rig/paint_microbench_test.dart`, gated at suite level by
the `rig` tag — by design.

`snap at dirty threshold`, the carried failure from Plan 2, **passes** on this
run (p50 0.552 ms, p95 0.680 ms against a 1.0 ms threshold). It is a timing
row on a shared machine and has failed before; recorded as passing today
rather than declared fixed.

Six new PNGs (`text_lod_ladder`, three rungs × two backends) took the golden
count from 34 to 40. **No pre-existing PNG was regenerated.** The three
`vertices/text_lod_ladder_*.png` are byte-identical to each other, which is
understood and documented: text reaches the canvas through
`VerticesDrawSink.text` → `_fallback.text` → `CanvasDrawSink.text` →
`canvas.drawParagraph` and never reaches the triangle buffer the rasterizer
observes, so the threshold has nothing to act on in that backend. The
information about the threshold lives entirely in the three canvas PNGs.

---

## What this plan did **not** close

**1. Permitted divergence 5 — overlapping translucent strokes on a triangle
soup.** Still live, still unexercised by any fixture. Plan 3e's Task 15
measured a different and narrower question (a translucent fill's own internal
triangulation seam). Nothing in 3f touched it. Carried forward unchanged.

**2. The metrics map's lookup allocation is unmeasurable on this side.**
`AllocationMeter` lives in the engine suite because `jet_cad_2d_flutter` has no
`vm_service` dependency — Plan 3c carry-forward item 3. The split cache is
Flutter-side, so no VM allocation profile can watch it. `a repeat request lays
out nothing and allocates no metrics` asserts `identical(a, b)` on two
`measure()` calls, which proves the returned **value** is cached and says
nothing about whether the lookup allocated a key on the way to it. The
corresponding mutation is recorded in the mutation log as unmeasurable with its
reason rather than listed with a killer that cannot kill it. Closing it means
moving `AllocationMeter` into `packages/jet_cad_2d/lib/src/testing/`.

**3. The corpus's text pressure is a step function, and the step is in the
wrong place for rows 1 and 2.** The pressure does not fall off smoothly with
the threshold — it sits flat at 4,140 keys through 2.0, then collapses across
a 3.0→6.0 band to 94. There is no threshold value that is both readability-
justified and cache-feasible on this corpus at this camera. Level of detail as
built is the right mechanism for the camera that matters and is not, by
itself, an answer for the whole-drawing camera. That is the shape of the
problem Plan 3g inherits.

**4. Row 10 at corpus scale does not discriminate** (see above). The claim is
held by the unit-scale fixture.

**5. Criterion 6 is unfalsifiable by construction** (see above). The invariant
is true; no fixture can distinguish it from a uniformly wrong `entityBounds`.

**6. Mutant 7's survival exposed a shape, not just a constant, and the shape
*was* audited.** A test file that always constructs its subject with every
bound passed explicitly cannot see a wrong default. One test was added for
`metricsLimit`. The final fix wave audited how widely that pattern occurs and
found three known instances:

- `FlutterTextMeasurer.metricsLimit`'s default — mutant 7, the one that
  survived the suite it shipped with.
- `FlutterTextMeasurer.paragraphLimit`'s default — audited during Task 9's
  review. Mutating it reddens only a restatement test
  (`the same string in two colours is two entries, not one`, which merely
  checks `layoutCount`/`liveParagraphCount` against literal `2`s regardless of
  what the default is), so the default is still behaviourally unexercised.
- `reference_walk.dart:36`'s `minTextCapPixels` default. Setting it to `0.0`
  leaves the whole suite green, because every caller that cares supplies its
  own threshold explicitly, and that caller's default shadows the parameter's.

**7. The rig's prints are not assertions, and the fix should be turning them
into some.** Rows 1–5 and corpus-scale row 10 in
`test/rig/paint_microbench_test.dart` print rather than assert. This is not
hypothetical: mutant 7 (above) survived its own suite while the rig printed
`liveMetrics=512 metricsEvictions=608634` for a run that should have read
`liveMetrics=4020 metricsEvictions=0`, and the run still passed — a glaring
regression that a human has to notice by reading a transcript rather than one
the suite would fail on. Turning the rig's degeneracy guard into real
assertions is a candidate follow-up for Plan 3g and was out of scope here.

---

## What Plan 3g inherits

- **A working text LOD**, `kMinTextCapPixels = 3.0`, disableable with `0.0`,
  wired from `DraftPainter` through `DraftCanvas` to the harness's `LOD`
  define, counted by `culledTextCount` and pinned by a three-rung golden
  ladder.
- **The threshold ladder**, regenerable from the tree behind a `LADDER`
  dart-define, and the finding that the step is a band.
- **The measured distinct-visible-key count: 3,876** at the whole-drawing
  camera on the 50,000-entity corpus at the shipped threshold — the figure
  Ruling 4's single permitted `kParagraphCacheLimit` raise requires beside it.
  **The raise is available and unspent.**
- **A split text cache** — colour-free metrics, coloured paragraphs — bounded
  separately, so a full `extents` sweep cannot evict what the paint path had
  warm.
- **The document owns the measurer and `DraftCanvas` borrows it**, refusing a
  document whose measurer cannot lay out paragraphs and naming the fix.
- **One unresolved question, and it is 3g's first design decision: whether a
  cached picture may contain text at all.** A picture is baked per scale band;
  level of detail is a function of continuous scale. A picture baked at one
  scale and replayed at another either shows glyphs the current camera would
  cull or hides glyphs it would draw. The three candidate answers — never bake
  text, bake per LOD band as a fourth cache axis, or draw text outside the
  cached picture entirely — have not been priced.
