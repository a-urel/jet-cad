# jet-cad — project status

**Last updated:** 2026-08-21
**Verified against:** branch `spike/vertices-sink`, worktree
`.claude/worktrees/vertices-spike`, at `4a16b41`, working tree clean — all
three packages re-run there on 2026-08-21. Every count below was produced by
running the suite, not by reading a report.

---

## TL;DR — where you left off

**Plan 3d (the vertices sink) is finished and in flight on
`spike/vertices-sink`** — fifteen tasks, executed, reviewed and committed, not
merged and not pushed. **Its exit gate is 7 of 8 with one criterion open for
the human**, and that one criterion is the whole handoff. See
[Plan 3d](#plan-3d--the-vertices-sink-is-the-default-everywhere) and
[Resume here](#resume-here).

Plan 3c (**text**) is **merged into `main`** at `52c7a7b`, exit gate passing.
The `plan-3c` branch and its worktree are gone; the ledger is archived at
[docs/superpowers/ledgers/](docs/superpowers/ledgers/).

| Suite | State (on `spike/vertices-sink` at `4a16b41`) |
|---|---|
| `packages/jet_cad_2d` — engine | **720 tests, all pass**, analyze/format clean |
| `packages/jet_cad_2d_flutter` — widgets | **238 tests pass, 1 skipped**, analyze/format clean |
| `flutter test --tags golden` | **23 pass**, 28 PNGs (14 fixtures × 2 backends); no pre-existing PNG regenerated |
| `apps/dev_harness_2d` | analyze/format clean; **R2/R4a/R4b run on macOS in profile mode, and R2 on Chrome/CanvasKit** |

The widget suite's one skip is `test/rig/paint_microbench_test.dart`, skipped at
suite level by the `rig` tag in `dart_test.yaml` — pre-existing and by design.

**Plan 3c's exit gate: PASS.** All eight of its failable criteria were met —
zero new paragraph layouts and zero evictions in the steady-state frame at both
entity counts and on real hardware, `skippedTextCount` 0, peak live paragraphs
exactly at the declared limit, and 53 mutants accounted for. The one benchmark
failure is Plan 2's carried `snap at dirty threshold`.

Results note:
[docs/superpowers/notes/2026-08-20-plan-3c-results.md](docs/superpowers/notes/2026-08-20-plan-3c-results.md).
**macOS Low Power Mode was on for the whole 3c session** — every timing in it is
contaminated; no failable criterion is a timing. Re-measured with it off, the
contamination is a uniform **~24%** on both raster and build, not the 4–12×
that note guesses, and Plan 3b's claim that CPU-only paths are unaffected is
**wrong**: they run 23–40% faster with it off. Plan 3d read Low Power Mode as
`0` before and after its desktop sweep.

### The per-leaf cost model is dead

[docs/superpowers/notes/2026-08-20-dash-leaf-separation.md](docs/superpowers/notes/2026-08-20-dash-leaf-separation.md)
holds the drawn geometry fixed (`screenSpaceLeafCount=1664` in all three arms)
and moves only `dashedFraction`. The frame moves **6.0×**, so **the unit of
render cost is the canvas call, not the drawn leaf**. Every per-leaf µs figure
in Plans 3a, 3b and 3c is an artefact of a corpus where dash spans and leaves
are collinear — do not carry them forward. `build` is linear in call count to
±30 µs; raster is super-linear because each call is one Impeller `Entity`. At
`DASHED=0` a 10,000-entity frame is **9.5 ms**, inside the 60 fps budget.

### Plan 3d — the vertices sink is the default everywhere

The 2026-08-20 spike
([note](docs/superpowers/notes/2026-08-20-vertices-sink-spike.md)) became Plan
3d, and Plan 3d is **finished on `spike/vertices-sink`** — **24 commits**,
`548fa8e..HEAD`, on top of 8 spike-and-spec commits, so **32 off `main`**.
**Not merged, not pushed.** `VerticesDrawSink` builds each
stroked segment's triangles itself and submits the frame's strokes as one
ordered `drawVertices`. What the spike lacked, 3d added: **miter and bevel
joins** (a miter is two triangles), **seam joins on closed runs**, `Vertices`
disposal at submission, a **coverage-only triangle rasterizer** so the golden
suite is available to it, goldens **on both backends**, and a **sink-against-sink
ink comparison**.

Results note:
[docs/superpowers/notes/2026-08-21-plan-3d-results.md](docs/superpowers/notes/2026-08-21-plan-3d-results.md).
Mutation log:
[docs/superpowers/notes/plan-3d-mutation-log.md](docs/superpowers/notes/plan-3d-mutation-log.md).

**Exit gate: 7 of 8 pass. Criterion 7 is measured and cannot be closed by the
plan.** Desktop, median of three (build p50 / raster p50): 10,000 — canvas
12.35 / 44.32 ms, vertices **5.71 / 6.68 ms**; 50,000 — canvas 15.36 / 66.94,
vertices **7.07 / 8.53**; 500,000 — canvas 44.29 / 508.00, vertices **17.44 /
21.64**. Criterion 5 (10k under 16.67 ms) and criterion 6 (raster better by
more than the spread at 50k and 500k) both pass, with disjoint `[min, max]`
intervals and no crossover anywhere.

**`defaultRenderBackend()` now returns `RenderBackend.vertices`
unconditionally, web included.** CanvasKit's `drawVertices` beats its
`drawPath` decisively — web 10,000: canvas 117.80 / 79.30 ms, vertices 6.80 /
1.40 ms. **The number that justifies the flip is the 17.3×–17.5× within-platform
`build` ratio, not the 56–60× raster figure**: `build` is the same Dart code on
both arms, while CanvasKit's `rasterDuration` almost certainly ends at command
submission. The desktop and web tables are **two separate confirmations, not one
table doubled** — they did not draw the same drawing. `CanvasDrawSink` is not
dead: it is the fallback and takes text on every frame (`canvasCalls=19` at 10k).

**What is open, and it is the handoff:** `CLAUDE.md`'s "the frame path allocates
nothing in steady state" is **not literally true of this backend**. Measured
residue is **three objects per flush** (a `Vertices` and two `sublistView`
wrappers), **nothing per entity**, so `3 × (textOps + 1)` per frame. The design
forbids the plan from amending the rule it is measured against, so `CLAUDE.md` is
untouched and **the human decides**. Proposed wording, and both outcomes, are in
the results note. Approved → criterion 7 passes and the gate is 8/8. Refused →
criterion 7 **fails** and that is the plan's result.

**Costs and gaps the note records rather than smooths over:** 96.00 MiB of
vertex buffer pinned for the widget's life at 500,000 entities; the web rows are
**not reproducible from what was committed** (raw artifacts committed at
`docs/superpowers/notes/2026-08-21-plan-3d-web-raw/`); the seam join and the
point-shape fix have **no coverage through any frame path**; the permitted
sub-pixel divergence is exercised by one unit test and no golden; a **2π-sweep
`ARC`** would draw an unjoined seam and is characterised, not fixed (no DXF
reader exists, and the corpus cannot produce one); and the R4a/R4b pairs'
control is plausible but **not demonstrated**.

---

## What this project is

A CAD workspace holding **two independent product lines that share a name and
nothing else**.

### `jet_cad_2d` — the live line (pure Dart 2D CAD)

A pure-Dart 2D CAD engine and document model. **No OCCT, no FFI, no native
build, no Flutter dependency** — it runs anywhere Dart runs. Rendering and
widgets live in the separate `jet_cad_2d_flutter` package so the engine stays
free of `dart:ui`. This is where all current work happens.

### `jet_cad` — the dormant line (OCCT 3D)

A Flutter CAD package backed by Open CASCADE Technology over FFI, with a macOS
viewport. Plans 1 and 2 for it shipped; **Plan 3 (the interactive OCCT viewport)
was written as a kickoff but never executed** — the project pivoted to the
pure-Dart 2D line instead. Last commit touching it: `139a677`, 2026-07-13.
Nothing here is being worked on. Do not assume its docs describe current
direction.

---

## Repo layout

```
packages/
  jet_cad/              # DORMANT — OCCT 3D over FFI, macOS viewport
  jet_cad_2d/           # ACTIVE — pure-Dart 2D engine (45 lib files)
  jet_cad_2d_flutter/   # ACTIVE — Flutter render layer (8 lib files)
apps/
  dev_harness/          # DORMANT — manual harness for the jet_cad viewport
  dev_harness_2d/       # ACTIVE — measurement harness; exists so R2/R4a/R4b
                        #   run on a real device in profile mode
docs/superpowers/
  specs/                # design specs — BINDING AUTHORITY
  plans/                # implementation plans — what the implementer follows
  notes/                # measurement + mutation results of record
  ledgers/              # raw per-task record, archived when a plan merges
.superpowers/sdd/       # git-ignored per-task ledger for the plan IN FLIGHT
```

`jet_cad_2d` is Dart-only (`meta`, `vector_math`; dev: `test`, `vm_service`).
`jet_cad_2d_flutter` depends on Flutter + `jet_cad_2d` by path. Both are
`resolution: workspace` members of the root pubspec.

---

## Branch and worktree map

| Location | Branch | State |
|---|---|---|
| `/Users/ahmeturel/Projects/oss/jet-cad` | `main` | clean, **`bb67137`**, Plans 1/2/3a/3b/**3c** merged |
| `.claude/worktrees/vertices-spike` | `spike/vertices-sink` | clean, **Plan 3d complete**, **32 commits off `main`** (8 spike/spec + 24 plan), not merged, not pushed |

`main` is a strict ancestor of the branch, so the branch is a fast-forward.
**As of this worktree's refs `origin/main` is also at `bb67137`** —
`git rev-list --count origin/main..main` is `0`, not the 29 this file used to
claim. That ref is local and may be stale; re-check with `git fetch` before
acting on it. Do not push unless explicitly asked.

The Plan 3d per-task ledger lives in the worktree at
`.superpowers/sdd/2026-08-20-jet-cad-2d-plan-3d-vertices-sink/` and is
git-ignored; **archive it to `docs/superpowers/ledgers/` when the branch
merges**, or it is lost with the worktree.

---

## Completed work

### Plan 1 — the 2D core (merged)

Identity and handles, the scene tree, columnar geometry and entity stores,
components, commands with undo, style tables and resolution, the packed R-tree
spatial index with a dirty overlay, snapping, and a deterministic versioned JSON
document format.

### Plan 2 — the backlog (merged)

Query performance and the zero-allocation invariant on the pick and snap paths.
Its `query_allocation_test.dart` harness is now a standing gate that every later
plan must not break.

> **Known carried failure:** `dart run benchmark/query_throughput.dart` has one
> failing row, `snap at dirty threshold`, carried forward from Plan 2. It is
> expected. Do not treat it as a new regression.

### Plan 3a — the render foundation (merged)

The first working render path: camera, coordinate rebasing, the `DrawSink`
paint seam, `DraftPainter`, the reference walk, and the differential oracle that
checks the painter against an independent implementation.

### Plan 3b — batching and dashes (merged)

**Batching was measured and refuted, not shipped.** The spike found the most
call-collapsed mode was **2.7× slower to rasterise** than one
`save`/`transform`/`restore` triple per leaf, and the plan's own pre-declared
stop clause fired. What shipped instead:

- The cull floor and the style memo were **deleted** — both were measured losses.
- Every line-like leaf is carried into screen space unconditionally, replacing
  the old anisotropy-gated bypass.
- An engine-side **dasher**: screen space for polylines, arc-window-aware for
  circles and arcs, with a human-reviewed collapse floor (`kDashCollapsePx`).

The profiling task also answered the standing question about an unexplained
179 ms: it is **leaf-count-bound GPU vertex work**, not fragment fill and not
draw-call dispatch. That finding is what makes a picture cache (**Plan 3f**,
called 3e before the vertices sink took the 3d slot) worth building.

> **Every `flutter drive` number in the 3b results note is contaminated:**
> macOS Low Power Mode was on system-wide for the whole session and could not be
> turned off. CPU-only paths are unaffected; build and raster columns at 500k
> entities are elevated 4–12×. **Any future `flutter drive` note must state
> whether Low Power Mode was on.**

---

## In flight: Plan 3c — text

- **Spec (binding):** [docs/superpowers/specs/2026-08-17-jet-cad-2d-plan-3c-design.md](docs/superpowers/specs/2026-08-17-jet-cad-2d-plan-3c-design.md)
- **Plan:** [docs/superpowers/plans/2026-08-17-jet-cad-2d-plan-3c-text.md](docs/superpowers/plans/2026-08-17-jet-cad-2d-plan-3c-text.md)
- **Ledger (the only progress record — read it):** `.claude/worktrees/plan-3c/.superpowers/sdd/2026-08-17-jet-cad-2d-plan-3c-text/progress.md`

**Goal:** store, measure, hit-test and draw single-line text so the product's
real payload — table numbers and room labels — renders, and measure what it
costs.

**The central design idea:** every paragraph is laid out **once at a nominal em
size** (`kNominalTextPixels = 100.0`) and every text attribute — height,
rotation, width factor, oblique angle, justification — becomes a **transform**.
So the paragraph cache key carries no height, angle or width factor. It is
`(string, textStyle handle, ResolvedStyle.argb)` — argb is in the key because
`ui.Paragraph` bakes its colour and `drawParagraph` takes no `Paint`.

`kCapHeightRatio = 0.7`: DXF height is cap height, so the matrix scale is
`effectiveHeight / metrics.capHeight`.

**Out of scope for 3c:** MTEXT, DXF 72=3/72=5 layout, text LOD, fills, picture cache.

### Task board

| # | Task | State |
|---|---|---|
| 0 | Text columns on the store and the record | ✅ complete, review clean |
| 1 | Codec, schema 3 → 4, defensive scalar read | ✅ complete, review clean |
| 2 | `TextMetrics`, measurer seam, metric model | ✅ complete (Ruling 8 carried to T6, paid) |
| 3 | `text_geometry.dart` — one resolution point | ✅ complete, fix round 1/5 |
| 4 | `entityBounds` and all four call sites | ✅ complete, fix round 1/5 |
| 5 | `SetEntityTextCommand` | ✅ complete (landed with T4 per Ruling 11) |
| 6 | Text picks as `HitKind.fill` | ✅ complete, approved |
| 7 | The corpus grows two text sources | ✅ complete, fix round 1/5 |
| 8 | The sink learns one text op | ✅ complete, approved |
| 9 | `FlutterTextMeasurer` + paragraph cache | ✅ complete (Rulings 21–23; one real defect found) |
| 10 | The painter draws text | ⬜ **NEXT** |
| 11 | Goldens — attribute ladder and mirror | ⬜ not started |
| 12 | Rigs, counters, the number the gate depends on | ⬜ not started |
| 13 | Mutation testing | ⬜ not started |
| 14 | Exit gate and the results note | ⬜ not started |

Test count grew 667 → 716 engine and 123 → 133 widget across Tasks 0–9.

---

## Resume here

**Plan 3d is complete on `spike/vertices-sink` and waiting on one human
decision.** Everything is green there and the tree is clean; nothing else is in
flight.

**The one thing to answer first — the `CLAUDE.md` allocation amendment.** The
current non-negotiable says the frame path allocates *nothing* in steady state.
The vertices sink allocates **three objects per flush and nothing per entity**.
The plan measured this and stopped, because a gate that can be passed by editing
the rule it is measured against is not a gate. The proposed replacement:

> **The frame path allocates nothing per entity in steady state, and O(1) per
> flush.** `packages/jet_cad_2d/test/invariants/query_allocation_test.dart` and
> `packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart`
> measure it.

**Approve it** → exit criterion 7 passes, the gate is 8/8, and the branch is
ready for `superpowers:finishing-a-development-branch`. **Refuse it** →
criterion 7 fails, and that is Plan 3d's recorded result rather than a delay;
the branch does not merge on the strength of its note until the residue is
removed or the rule is settled another way.

**Then**: finish the branch (the merge menu is the human's to answer), archive
`.superpowers/sdd/2026-08-20-jet-cad-2d-plan-3d-vertices-sink/` into
`docs/superpowers/ledgers/`, and pick the next plan from the roadmap below —
3e (fills) and 3f (caches and tiles) are the named successors, and what 3d owes
each is written out at the end of
[the 3d results note](docs/superpowers/notes/2026-08-21-plan-3d-results.md).

### What Plan 3d leaves open

1. **The `CLAUDE.md` amendment**, above.
2. **A frame-path fixture for the seam and the point shape.** Both are pinned
   against the `DrawSink` interface only. `DraftPainter` routes point, line and
   polyline through `_emitScreenSpace`, whose residual is a bare translation, so
   a rotated point never reaches the sink through the painter at all.
3. **The 2π-sweep `ARC` seam**, characterised and unfixed — safe only because
   there is no DXF reader in the repository and the corpus cannot produce one.
4. **The R4a/R4b control**, plausible but not demonstrated: a grep pattern
   dropped the invariant fields from those two rows' transcripts.
5. **Permitted divergence 5 (overlapping translucent strokes) goes live the
   moment 3e adds fills.** It is inert today only because the corpus is opaque.

### What the next plan inherits from 3c

Six items, listed in full in the [results
note](docs/superpowers/notes/2026-08-20-plan-3c-results.md). The first blocks
shipping text to an application and has no owner:

1. **Nothing outside the tests wires a real measurer into a document.**
   `DraftDocument.empty` defaults to `InsertionPointMeasurer`, the zero
   metrics, so `composeTransform`'s `height / capHeight` divides into zero —
   singular text transform — and `entityBounds` collapses every glyph box to a
   point. An application built the ordinary way draws no text **and reports no
   error**. Out of 3c's scope: the plan specifies the seam, not who plugs it in.
2. **Two paragraph caches, not one.** The painter takes metrics from
   `document.textMeasurer`, the sink lays out through `DraftCanvas`'s own. A
   text leaf costs up to two layouts, and the query path pays for text even
   into a `NullDrawSink` — **+97 ms** at 50k, **+105 ms** at 500k, whole
   drawing.
3. **The allocation gate measures the engine helpers, not the painter.**
   `text_paint_allocation_test.dart` is in the engine suite because
   `jet_cad_2d_flutter` has no `vm_service`. Closing it means moving
   `AllocationMeter` into `jet_cad_2d/lib/src/testing/`.
4. **Whole-drawing thrash → the picture cache's text LOD (Plan 3f).** 4,140
   layouts and 4,140 evictions
   per frame, and it is 4,140 at *both* 50k and 500k because it is bounded by
   string variety rather than entity count. A bigger cache holds one zoom
   level of one corpus; not drawing text too small to read removes the cost.
5. `snap at dirty threshold` p95 1.08 ms against < 1.0 ms — carried from Plan 2.
6. `DocumentTree._link` is quadratic in a parent's child count, which is why
   the rigs cap `instanceCount` at 20,000 — recorded in Plan 3b.

---

## Rulings that still bind future work

Plan 3c's ledger carries 56 numbered rulings, archived in full at
[docs/superpowers/ledgers/](docs/superpowers/ledgers/). These are the ones that
constrain work not yet done:

**Ruling 4 — the cache limit is not a tuning knob.** `kParagraphCacheLimit` is
owned by Task 9 and may be raised **once**, in Task 12, and only with the
measured distinct-visible-key count recorded beside it. Lowering
`attributedInstanceFraction` is equally acceptable. **Relaxing the
zero-new-layouts gate row is not.** Otherwise the gate passes because the corpus
was thinned rather than because the cache works.

**Ruling 20 — discharged in Task 10, with numbers.** The residual-path norm is
**1.00** allocations per leaf (one `Transform2`). A text leaf through
`resolveTextAttributes` + `textLocalTransform` was **9.00**; through one
long-lived `TextLayout` it is **0.87–1.00**, at or below the norm. The spec's
second `Float64List(16)` was not the fix — under the plan's shape the sink
composes nothing — the reusable layout was, and `TextLayout` lost `@internal`
for it. Gate:
`packages/jet_cad_2d/test/invariants/text_paint_allocation_test.dart`. Every
assertion there is a **ratio**, because the profiler was observed once to read
0.07 where two other runs read 1.00.

**Ruling 10 — `boxOfLeaf` returns null after an edit, correctly.** Dirtying a
leaf removes it from the packed R-tree and parks it in the overlay. Any test
reading a box after an edit must use the codebase idiom:
`index.boxOfLeaf(slot) ?? index.dirty.boxOf(slot)`.

**Ruling 12 — never `tables.textStyles[...]!`.** `JsonCodec._loadTables` clears
the seeded defaults and `TableSection.remove` is public, so a document missing
handle 5 crashes on plain `doc.extents`. Use
`DraftDocument.textStyleOf(Handle)`, which falls back to a `const
TextStyleRecord`.

**Ruling 22 — pin the layout em size exactly, not positively.** The measurer's
one unforgivable failure is laying a paragraph out at anything other than
`kNominalTextPixels`, and `expect(ascent, greaterThan(0))` is satisfied by every
positive em size. `flutter_test`'s font is exactly 0.75em ascent / 0.25em
descent / 1em per character, so the assertions are exact: `WC` at nominal is
ascent 75.0, descent 25.0, advance 200.0. A Flutter upgrade that moves the test
font fails loudly, which this plan prefers to a silent pass.

**Ruling 23 — the two measurers must agree, and one guard is still owed.**
`Paragraph.longestLine` is `-FLT_MAX` for a paragraph with no lines, and
`-FLT_MAX` is **finite**, so no `isFinite` guard catches it.
`FlutterTextMeasurer` now shares `ascent`/`descent`'s `lines.isEmpty` guard for
`advanceWidth` so it returns `0.0`, matching `MetricModelMeasurer`. The seam's
premise — and the differential oracle's validity — is that the two are
interchangeable. The draw-path `isEmpty` guard landed in Task 10, in the
painter *and* in the reference walk, and both halves are pinned by mutation.

**Ruling 28 — the paragraph flip lives in the sink, not the painter.**
`Canvas.drawParagraph` draws y-down from the top of the line; the residual maps
glyph space, y-up from the baseline. `CanvasDrawSink.text` reconciles them with
`translate(0, alphabeticBaseline)` then `scale(1, -1)`. It must **not** move
into the painter: it is a `dart:ui` fact, and `reference_walk` composes the
same residual independently — sharing it would have the oracle share the
assumption it exists to test.

**Ruling 33 — the fixture set, not any one task, is the recurring hole.** Three
Task 10 mutations survived a green suite, all degenerate fixtures: no blank
text entity anywhere (the corpus *replaces* blanks with labels rather than
adding them), and **no text entity on a non-STANDARD style anywhere**, which is
Ruling 13's exact hole reopening one plan later in two new call sites. Both are
now covered by hand-built fixtures. Any new text call site must be checked
against both before it is called done.

**Ruling 53 — a gate that fails on correct code is worse than no gate.**
`text_paint_allocation_test` failed one full-suite run in eleven while the code
was right: the subject read 1.00, the *control* read 0.60, and because every
assertion was a ratio a low control **tightened** the bound. Ruling 31's ratios
answer the artefact only when all loops read low together. The repair is a
plausibility guard on the controls — whose answers are fixed by construction, so
retrying cannot mask a subject regression — and a failure message that names the
meter rather than the subject. Any measurement gate here needs the same
distinction between *a bad result* and *a bad read*.

**Ruling 54 — report a cache hit rate split by source or not at all.** Blended,
this corpus reads as a mediocre cache. Split, 9,928 label draws are served by
140 entries (98.6%) while all 4,000 attributes miss every time. One number hid
which half was the problem.

**Ruling 49/50 — a named killer is not a killer until it has fired.** Four of
the twenty spec mutants Task 13 ran survived the very suite the spec names for
them, and three of the four failed the same way: the test named the right
property against a fixture that could not tell right from wrong. *Rotation is
not symmetric about its sign* survives negating both sides. Every text case in
`extents_test` passes `entityBounds` an explicit measurer, so none of them
tests the document's field. `query_allocation_test` watched
`{Vector2, _Record}` and a per-candidate `TextMetrics` was not on the list —
**55.533 allocations per pick against a budget of 0.5**, invisible. Any spec
row that says "killed by X" is a hypothesis until X has been seen to go red.

**Ruling 51 — two spec mutants have no site, and that is the design working.**
*Lay the paragraph out at the effective em size* cannot be written:
`_buildEntry` is handed no size and `fontSize` is a constant. *Swap the
measurer mid-life* cannot be written either: `DraftDocument.textMeasurer` is
`final` for exactly that reason and its doc comment says so. Both were run in
their nearest reachable form and both restatements are recorded beside their
rows in the log — never silently.

**Ruling 39/40 — the cache limit is settled, with a measured margin.** 18 keys
at the working-set camera against 512; the limit does not move and Ruling 4's
one permitted raise is unspent. The margin is the key-pressure ladder, not a
feeling: binding starts around 12000–24000 world units wide.

**Ruling 44 — measurement machinery fails by printing a plausible number.**
Three of Task 12's mutants survived a green suite, and none of the three would
have errored: a dropped `DraftCanvas.drawText` forward prints a text-off row
identical to text-on; a `resetCounters` that also cleared the cache prints one
new layout per visible string and makes a working cache read as a failing gate;
a `TextKeySink` without the colour axis under-reports the gate's own number.
Any new counter, flag or rig sink needs a test that a *wrong reading* would
fail, not just one that a crash would.

**Ruling 34 — Plan 3c Task 11 Step 2's rung-4 criterion is backwards, and the
engine wins.** The step says to check that the crossed cells are "wider at the
same slope rather than more slanted". `composeTransform` shears *before* the
width-factor x-scale — `w * (x + k*y)`, which `textLocalTransform`'s doc names
as the DXF reading and `text_geometry_test.dart` pins as
`c = widthFactor * tan(oblique) * scale`. The stem slope is therefore
`widthFactor * tan(oblique)` and the wide cell **is** more slanted; the plan's
sentence describes the swapped order, which is the drawing rung 4 exists to
reject. If any later task quotes that sentence, it is quoting the mutant.

**Ruling 37 — a colour golden needs a repeated string, not a palette.** See
[Resume here](#resume-here); it constrains Task 13's "visibly by a colour
golden" requirement to a property of the fixture.

**Ruling 36 — a golden document must carry a real measurer.** The painter
takes its scale from `document.textMeasurer` while the sink lays the paragraph
out through its own; the glyphs sit inside the box the document believes they
occupy only while the two agree. A golden on `MetricModelMeasurer` pins a
drawing no production wiring produces — the degenerate fixture in its most
expensive form, a *reviewed* one.

**Ruling 17 — the corpus must hold exactly 20 distinct labels.**
`expect(labels.length, 20)`, not `lessThanOrEqualTo(20)`. The distribution is
the exact property Task 12's distinct-key measurement is taken against; a
degenerate assertion collapsing it to one label would silently void the gate.

---

## Plan 3c exit gate (Task 14)

### Checks

| Check | Command |
|---|---|
| engine suite | `cd packages/jet_cad_2d && dart test` |
| engine analyze/format | `dart analyze && dart format --output=none --set-exit-if-changed .` |
| widget suite | `cd packages/jet_cad_2d_flutter && flutter test` |
| goldens | `flutter test --tags golden` — all pass, **no existing PNG regenerated** |
| widget analyze/format | `flutter analyze && dart format --output=none --set-exit-if-changed .` |
| harness analyze | `cd apps/dev_harness_2d && flutter analyze` |
| allocation harness | `dart test test/invariants/query_allocation_test.dart` — zero allocation **with text in the corpus** |
| query throughput | `dart run benchmark/query_throughput.dart` — `snap at dirty threshold` is the known carried failure |
| rigs | `flutter test --tags rig --run-skipped`, then `flutter drive --profile -d macos` |

### Failable criteria

| Criterion | Threshold |
|---|---|
| repeat frame at the working-set camera | **zero** new paragraph layouts |
| evictions per repeat frame, working-set camera | **zero** |
| peak live paragraphs | ≤ the declared limit |
| `skippedTextCount` on `textRigCorpus` | **0** |
| differential and non-vacuity, text on | pass |
| reference-query differential, text picking | pass |
| overlay-equals-rebuild for an edited text | pass |
| mutation log | every mutant killed or argued equivalent |

**If a failable row misses: record it and stop.** Plan 3b's Task 4 stop clause
is the precedent — a row that fires is a result. Write the number, say what it
implies for fills and the picture cache (**3e and 3f** under the current
numbering; 3c's own plan text called them 3d and 3e), and stop rather than
tuning until it complies.

The results note must state **whether macOS Low Power Mode was on**.

---

## Roadmap after 3d

**Renumbered.** The vertices sink took the `3d` slot, so the two plans below
moved up one: **fills is 3e** and **the picture cache is 3f**. That is the
numbering the Plan 3d design document uses in "What 3d owes the plans after it",
and it is the numbering the rest of this file uses — every `3d`/`3e`/`3f` above
was swept and corrected, including the picture-cache pointer in the 3b section
and the text-LOD item in 3c's carry-forward list. **Notes and plan documents
written before 2026-08-20 still call fills "3d" and the cache "3e"; read those
by name, not by number.**

### Plan 3e — fills

**It inherits no mechanism from 3b.** The 3b design's "flush contract" — a fill
flushing open draw buckets — has nothing to attach to, because batching was
reverted — but 3d's vertices sink supersedes that concern entirely: **3e
inherits a triangle buffer already appended to in draw order, and a flush that
already happens before anything unbatchable.** `_flushBeforeUnbatchable` is the
shape any fill-flush contract extends.

**The open problem:** draw order is ascending handle value, so a region's fill
must carry a **lower** handle than its boundary or it paints over its own
outline. But handles are monotonic by creation and the natural authoring order
is *draw the boundary, then hatch it* — which produces exactly the failing case.
3e must choose and state one of:

- give the fill an explicit draw-order key the painter honours ahead of handle order, or
- require the region command to create boundary and fill in one transaction with the ordering reserved.

**One thing 3e must not inherit silently.** Permitted divergence 5 —
overlapping translucent strokes — is **inert today only because the corpus is
opaque** (`argb`'s alpha is `255 - transparency`). A stroked path unions its
coverage; a triangle soup does not, so two quads that overlap double-blend. The
moment 3e draws anything with alpha < 255 that divergence is live and needs a
test. See the [3d results
note](docs/superpowers/notes/2026-08-21-plan-3d-results.md).

### Plan 3f — the definition/tile picture cache

**What 3d hands it.** A picture cache that records into a `Picture` interacts
with a sink that batches across residuals: 3f must decide whether a cached
picture flushes the vertex buffer at its boundary. There is **no crossover
number** to work against — the vertices backend's raster margin is still
widening at 500,000 entities — and there is **96.00 MiB of vertex buffer pinned
for the widget's life** at that corpus size, which is the arithmetic a tiling
scheme changes. Read the margin against **canvas calls**, not entity count: a
10× entity rise moves `screenSpaceLeafCount` only 2.13× and `dashSpans` 3.03×.

The prize is real: the dominant cost is leaf-count-bound GPU vertex work, and
dashing makes that story **stronger** — one dashed polyline becomes dozens of
drawn spans per leaf without moving the painter's op count.

Four traps recorded in
[docs/superpowers/notes/2026-08-17-carry-forward-additions.md](docs/superpowers/notes/2026-08-17-carry-forward-additions.md):

1. **`documentRevision` does not exist yet** and nothing says what bumps it. If
   an ordinary entity edit bumps it, every definition picture is discarded every
   command — the exact pathology the two-channel split exists to avoid, and the
   planned gate row would not catch it.
2. **Tile invalidation has a hole for edits inside a definition.** A touched
   handle owned by a definition appears in no tile's handle list and its new box
   is in definition-local space. Tiles must record which definitions they baked
   and map touched handles through placements.
3. **A cached picture is no longer scale-invariant now that dashes exist.** Dash
   phase and the collapse floor are both functions of screen-space scale, so
   zoom far enough and baked-dashed entities need to render solid. That is a new
   invalidation axis with no name yet.
4. **`InstanceNode` carries only 2 of `StyleContext`'s 6 fields.**
   `linetype`, `linetypeScale`, `lineweight`, `transparency` are missing, and
   DXF's INSERT carries all four. `StyleContext` is the picture cache key, so
   this model decision belongs **before** the cache, not after.

**Do not design 3f against a fixed op-count ceiling.** The web whole-drawing
abort is reproducible but its trigger is unknown — a memory- or
session-dependent CanvasKit failure explains it with no code at fault. What 3f
is owed first is a back-to-back, same-session re-run.

---

## Commands

```sh
# engine (pure Dart)
cd packages/jet_cad_2d
dart test
dart test test/invariants/query_allocation_test.dart
dart run benchmark/query_throughput.dart
dart analyze && dart format --output=none --set-exit-if-changed .

# render layer (Flutter)
cd packages/jet_cad_2d_flutter
flutter test
flutter test --tags golden
flutter test --exclude-tags golden          # any platform but the one they were made on
flutter test --tags rig --run-skipped   # R1/R3, and R4's text counters
flutter test --tags rig --run-skipped test/rig/paint_microbench_test.dart \
  --plain-name "text paint at 50000"    # the gate's feasibility number
flutter analyze && dart format --output=none --set-exit-if-changed .

# real-device frame timings  (TEXT/DRAW_TEXT must be "true"/"false", not 1/0)
cd apps/dev_harness_2d
flutter drive --profile -d macos --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart \
  --dart-define=TEXT=true --dart-define=DRAW_TEXT=false
```

---

## Traps

- **`flutter pub get` rewrites three `analysis_options.yaml` files** in this
  workspace. They must **never** be committed. Check `git status` after any pub
  operation.
- **The degenerate fixture is the dominant defect class here.** Plan 3c alone
  shipped it three times: fixtures all at the identity transform, all at the
  origin, all with default attributes, all one distinct string. Every one was
  caught by mutation testing, none by reading. A test that cannot be made red by
  a named mutation is not evidence.
- **`query_allocation_test` is a standing gate, not a Plan 2 artifact.** A
  `measure()` that allocates on a cache *hit* breaks it. This already bit once:
  Task 2's record-tuple memo allocated 41.5 objects per pick-path call, found in
  Task 6.
- **Reviewers verify claims independently.** Synthesized test output invalidates
  a task.
- **Never `git checkout` a file to revert a mutation.** It restores HEAD, so it
  silently wipes every uncommitted change in that file — Task 10 lost a full
  task's painter work that way. Copy the file aside first and restore from the
  copy in a `finally` block.
- **`flutter_test` renders Ahem, not a real font,** unless one is loaded. Any
  golden asserting something about glyph *shape* — that a mirrored label reads
  backwards, most of all — needs `test/golden/fonts/Roboto-Regular.ttf` loaded
  through a `FontLoader`, or it asserts nothing while looking like it does.
- **`bool.fromEnvironment` accepts only `"true"` and `"false"`.**
  `--dart-define=TEXT=1` reads as **false**. One device rig run measured the
  wrong document and printed numbers that looked entirely correct; only the
  `corpus=on/off` line it now prints gave it away.
- **`flutter drive` rewrites
  `apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj`.** CocoaPods
  bumps `MACOSX_DEPLOYMENT_TARGET` 10.15 → 12.0 in all three configurations.
  Same class as the `analysis_options.yaml` trap: revert it, do not commit it.
- **The `plan-3c` ledger is the only progress record** for that plan — TodoWrite
  was unavailable in the session that ran it. Keep appending to it.

---

## Housekeeping done 2026-08-20

Removed as dead weight:

- `.superpowers/sdd/` scratch for **finished** plans — Plan 1-core, Plan 3b, and
  the loose Plan 2 reports and `review-*.diff` files (~2.7 MB, git-ignored,
  **not recoverable**). Their conclusions live in `docs/superpowers/notes/`.
  The **`plan-3c` ledger was deliberately kept** — it is live state.
- Speckit scaffolding: `.specify/` and the nine `.claude/skills/speckit-*/`
  skills. Unreferenced anywhere in the project; the repo uses the superpowers
  SDD workflow instead. Tracked by git, so recoverable via
  `git checkout a7008a6 -- .specify .claude/skills`.
- `.superpowers/plan-3-kickoff-prompt.md` — the kickoff for the abandoned OCCT
  Plan 3 viewport, superseded by the 2D line.
- `CLAUDE.md` rewritten from its speckit stub into real project instructions.

**Known cost:** six links in three tracked docs
(`2026-08-11-plan-3b-results.md`, `2026-08-10-plan-3a-ledger.md`,
`2026-07-12-03-interactive-viewport.md`) point into the deleted
`.superpowers/sdd/` reports and are now dead. The notes' own prose is
self-contained; only the citations broke.
