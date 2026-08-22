# jet-cad — project status

**Last updated:** 2026-08-22
**Verified against:** `main` at `8fad846`, pushed, working tree clean apart from
the three files the traps below say never to commit.
Every suite count below was produced by running the suite on the **merged**
result, not by reading a report and not on the branch before it landed.

---

## TL;DR — where you left off

**Plan 3e (fills) is done, seventeen tasks, worked directly on `main`** — see
[Plan 3e](#plan-3e--fills) and [Resume here](#resume-here). Six of its nine
failable criteria pass outright; one is a device timing row measured under
macOS Low Power Mode and left explicitly unevaluable rather than scored; one
(the translucent seam) is settled only for the routing rule and left open on
Impeller/GPU, on the reviewer's own instruction not to write "no seam was
found." No criterion failed.

Results note:
[docs/superpowers/notes/2026-08-22-plan-3e-results.md](docs/superpowers/notes/2026-08-22-plan-3e-results.md).
Mutation log:
[docs/superpowers/notes/plan-3e-mutation-log.md](docs/superpowers/notes/plan-3e-mutation-log.md) —
56 mutants accounted for, 52 killed, 2 proven equivalent, 2 documented gaps.

**Plan 3d (the vertices sink) is merged into `main`** — fifteen tasks,
executed, reviewed and committed, then merged locally with `--no-ff`. **Its exit gate is 8 of 8** — criterion 7 stayed open until the human approved
the `CLAUDE.md` allocation amendment on 2026-08-21, which the plan was forbidden
from granting itself. See
[Plan 3d](#plan-3d--the-vertices-sink-is-the-default-everywhere).

Nothing is in flight. The `spike/vertices-sink` branch and its worktree are
gone; the ledger is archived at
[docs/superpowers/ledgers/](docs/superpowers/ledgers/), beside Plan 3c's.
Plan 3e's own ledger was archived the same way at `8fad846`, since that plan had
no worktree of its own: 64 files at
[docs/superpowers/ledgers/2026-08-21-jet-cad-2d-plan-3e-fills/](docs/superpowers/ledgers/2026-08-21-jet-cad-2d-plan-3e-fills/).
**The ordering is the lesson: archive the ledger onto the branch before the
workspace is deleted, never after.**

**Since Plan 3d's merge, on `main` at `70d824e..0eac1be`: two of Plan 3d's
three remaining open items are closed**, and one thing that note recorded
turned out to be wrong. See [What Plan 3d leaves open](#what-plan-3d-leaves-open)
— one item remains and cannot be closed here.

Plan 3c (**text**) is **merged into `main`** at `52c7a7b`, exit gate passing.

| Suite | State (on `main`, run against the merged result) |
|---|---|
| `packages/jet_cad_2d` — engine | **777 tests, all pass**, analyze/format clean |
| `packages/jet_cad_2d_flutter` — widgets | **277 tests pass, 1 skipped**, analyze/format clean |
| `flutter test --tags golden` | **29 pass**, 34 PNGs (17 fixtures × 2 backends, 3 of them fills); no pre-existing PNG regenerated |
| `apps/dev_harness_2d` | analyze/format clean |
| `benchmark/query_throughput.dart` | one gated row fails — `snap at dirty threshold`, **carried from Plan 2**, not a regression |

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
3d, and Plan 3d is **merged into `main`** — the spike and spec commits at
`bb67137..548fa8e`, the plan at `548fa8e..a4c31c1`, brought in by one `--no-ff`
merge, pushed on 2026-08-21.
`VerticesDrawSink` builds each stroked segment's triangles itself and submits
the frame's strokes as one ordered `drawVertices`. What the spike lacked, 3d added: **miter and bevel
joins** (a miter is two triangles), **seam joins on closed runs**, `Vertices`
disposal at submission, a **coverage-only triangle rasterizer** so the golden
suite is available to it, goldens **on both backends**, and a **sink-against-sink
ink comparison**.

Results note:
[docs/superpowers/notes/2026-08-21-plan-3d-results.md](docs/superpowers/notes/2026-08-21-plan-3d-results.md).
Mutation log:
[docs/superpowers/notes/plan-3d-mutation-log.md](docs/superpowers/notes/plan-3d-mutation-log.md).

**Exit gate: 8 of 8.** Seven passed on the plan's own measurements; criterion 7
was measured by the plan, left open because the design forbids it from amending
the rule it is measured against, and closed on 2026-08-21 when the human
approved the amendment. Desktop, median of three (build p50 / raster p50): 10,000 — canvas
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

**The allocation rule, settled.** `CLAUDE.md`'s "the frame path allocates nothing
in steady state" was **not literally true of this backend**. Measured residue is
**three objects per flush** (a `Vertices` and two `sublistView` wrappers),
**nothing per entity**, so `3 × (textOps + 1)` per frame. The design forbade the
plan from amending the rule it is measured against, so the plan measured and
stopped. **The human approved the amendment on 2026-08-21** and it landed in a
commit that changed nothing else; the non-negotiable now reads "allocates
nothing per entity in steady state, and O(1) per flush", measured by
`query_allocation_test.dart` on the query path and `paint_allocation_test.dart`
on the paint path.

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
| `/Users/ahmeturel/Projects/oss/jet-cad` | `main` | clean, Plans 1/2/3a/3b/**3c**/**3d**/**3e** merged |

**No worktrees.** `spike/vertices-sink` was merged with `--no-ff` and both the
branch and `.claude/worktrees/vertices-spike` were removed. Nothing is in
flight.

**This file states commit ranges and never a commit count, on purpose.** A
count is falsified by the next commit — including the commit that writes the
count, which is how the figure here was wrong twice in one task. A range with
named endpoints is true forever. If you want the number, ask git:

```sh
git rev-list --count 52c7a7b..HEAD          # everything Plan 3d brought in
git rev-list --count origin/main..main      # what is unpushed
```

Plan 3d was pushed on 2026-08-21; `origin/main` reached `c54552f` then. Plan 3e
and Plan 3d's follow-up items were pushed on 2026-08-22, taking `origin/main`
to `8fad846`. Anything committed after that may or may not be pushed by the
time you read this — run the second command rather than trusting this
sentence. Do not push unless explicitly asked.

The Plan 3d per-task ledger was archived out of the worktree before it was
removed, and is at
[docs/superpowers/ledgers/2026-08-20-jet-cad-2d-plan-3d-vertices-sink/](docs/superpowers/ledgers/2026-08-20-jet-cad-2d-plan-3d-vertices-sink/):
fifty-nine files, including `progress.md` with its fourteen rulings and the
twenty-six review packages.

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
draw-call dispatch. That finding is what makes a picture cache (**Plan 3g**,
called 3e before the vertices sink took the 3d slot) worth building.

> **Every `flutter drive` number in the 3b results note is contaminated:**
> macOS Low Power Mode was on system-wide for the whole session and could not be
> turned off. CPU-only paths are unaffected; build and raster columns at 500k
> entities are elevated 4–12×. **Any future `flutter drive` note must state
> whether Low Power Mode was on.**

---

## Merged: Plan 3c — text

- **Spec (binding):** [docs/superpowers/specs/2026-08-17-jet-cad-2d-plan-3c-design.md](docs/superpowers/specs/2026-08-17-jet-cad-2d-plan-3c-design.md)
- **Plan:** [docs/superpowers/plans/2026-08-17-jet-cad-2d-plan-3c-text.md](docs/superpowers/plans/2026-08-17-jet-cad-2d-plan-3c-text.md)
- **Ledger (the only progress record — read it):** [docs/superpowers/ledgers/2026-08-17-jet-cad-2d-plan-3c-text/progress.md](docs/superpowers/ledgers/2026-08-17-jet-cad-2d-plan-3c-text/progress.md) — archived on merge; the `plan-3c` worktree the older text points at is gone

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

**Plan 3e (fills) is done, worked directly on `main`, nothing in flight.**
Six of nine failable criteria PASS outright; one device timing row is
recorded as measured-but-unevaluable (macOS Low Power Mode was on for the
whole session); one (the translucent seam) is settled only for the routing
rule and left explicitly open on Impeller/GPU, per the reviewer's own
instruction not to write "no seam was found." No criterion failed. See
[Plan 3e](#plan-3e--fills) above and
[the results note](docs/superpowers/notes/2026-08-22-plan-3e-results.md) for
every number.

**Two things a resumer should do before trusting any 3e timing number:**
`pmset -g | grep lowpowermode` before taking a new one — it read `1` (on)
throughout this plan's own session and Plan 3d's already measured what that
is worth (~24% uniform on raster and build). And the translucent-seam
question needs a GPU-backed instrument (`flutter drive`'s real Impeller path,
not `flutter_test`) to close — `flutter_test`'s software Skia does not
antialias `drawVertices` at all, which this plan proved by direct probe and
pinned as a permanent regression test.

**Plan 3d is merged into `main` and its gate is 8 of 8.** The last open item
was the `CLAUDE.md` allocation amendment, and it is **settled**: the human
approved it on 2026-08-21 and the non-negotiable now reads

> **The frame path allocates nothing per entity in steady state, and O(1) per
> flush.** `packages/jet_cad_2d/test/invariants/query_allocation_test.dart` and
> `packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart`
> measure it.

The plan measured the residue and stopped there rather than editing the rule
itself, because a gate that can be passed by editing the rule it is measured
against is not a gate. **No plan since has needed the rule amended again** —
3e measured against it and it still describes the work.

Plan 3d's open items were worked next, on `main` at `70d824e..0eac1be`: two
closed, one shown to be unclosable until a DXF reader exists.

**Next**: pick a plan from the roadmap below. **Plan 3g (caches and tiles)**
is the named successor and what 3d and 3e owe it is written out at the end of
[the 3d results note](docs/superpowers/notes/2026-08-21-plan-3d-results.md)
and [the 3e results note](docs/superpowers/notes/2026-08-22-plan-3e-results.md)
respectively. **Permitted divergence 5** (overlapping translucent strokes on
a triangle soup) is now live and still has no fixture — a candidate for a
short follow-up before or alongside 3g.

### What Plan 3d leaves open

Three of the five are closed. The full account, with every number, is the
**Follow-up** section at the end of
[the 3d results note](docs/superpowers/notes/2026-08-21-plan-3d-results.md);
the nine new mutants are Part 4 of
[the mutation log](docs/superpowers/notes/plan-3d-mutation-log.md).

1. ~~**The `CLAUDE.md` amendment.**~~ Settled 2026-08-21, above.
2. ~~**A frame-path fixture for the seam and the point shape.**~~ **Closed
   2026-08-21.** The two halves were different in kind. The **seam** was a real
   gap and now has
   [frame_path_seam_test.dart](packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart):
   a solid circle — the only closed run the painter produces, and exactly what
   the dash ladder's dashed circle is not — walked along its centreline, plus a
   triangle-count invariant, plus a comparison against the open full-sweep arc.
   Eight of nine mutants killed. The **point shape** had no reachable state to
   cover at all: `_drawLeafComposed` returns before `_emit` for point, line and
   polyline, unconditionally, so those three cases were dead code carrying
   working bodies. The bodies are gone; the cases stay as documented breaks.
3. **The 2π-sweep `ARC` seam**, characterised and unfixed — safe only because
   there is no DXF reader in the repository and the corpus cannot produce one.
   **Still open and still unclosable**: a fix cannot be test-driven, because
   nothing here can produce a full-sweep `ARC` entity. The DXF plan owns it.
4. ~~**The R4a/R4b control.**~~ **Closed 2026-08-21** — the three
   backend-independent fields match exactly within each pair (R4a
   2,081 / 46,511 / 292; R4b 1,970 / 46,696 / 241). **And the recorded cause was
   wrong.** No grep pattern lost those fields: R4a and R4b kept the canvas-only
   repaint guard after Task 13 fixed R2's, and under the vertices backend
   `canvasCallCount` is 0 for a healthy frame, so **both vertices runs of record
   failed** after printing `build`/`raster`/`command` and before printing
   anything else. R4a and R4b never printed `screenSpaceLeafCount` at all. Fixed
   at `0eac1be` by giving all three rigs one shared `requireRepaint` and
   `printInvariants` — copies are how the drift happened.
5. **Permitted divergence 5 (overlapping translucent strokes) is now live**,
   since Plan 3e adds fills — but **still not exercised by any fixture**.
   Plan 3e's Task 15 measured the translucent-fill-triangulation seam
   question (its own boundary's internal triangle edges) and found the
   routing rule does not fire on the instrument available; it did not build a
   fixture with an opaque stroke overlapping a translucent fill, which is
   what this item names. Still open for whoever builds one.

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
4. **Whole-drawing thrash → text LOD (Plan 3f), split from the picture cache,
   now Plan 3g.** 4,140
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

**Renumbered again on 2026-08-22.** Text wiring and text LOD were split out of
the picture cache and took the `3f` slot, so **the picture cache is now 3g**.
The sentence above describes the *earlier* move and is left as written: it is
the record of why the numbers shifted the first time, not a statement about the
current numbering.

### Plan 3e — fills

**Done — seventeen tasks, executed and reviewed one at a time directly on
`main`** (no worktree; the brief scoped this plan to work in the main
checkout, with `.superpowers/sdd/2026-08-21-jet-cad-2d-plan-3e-fills/` as its
ledger, archived the same way a worktree plan's would be). Commit range:
design and plan at `0eac1be..3201cc5`, the seventeen tasks at
`3201cc5..f0ea51e` plus the results-note commit on top.

**The open problem the plan named — solved.** Draw order is ascending handle
value, so a region's fill must carry a lower handle than its boundary. The
chosen answer is **`AddRegionCommand`**: one atomic command that allocates
the fill's handle first, the boundary's second, refuses an inverted pair, and
returns one `CommandResult` — so no observer, including undo/redo, can ever
see a fill whose boundary does not yet exist. `FillIndex` (`fill_index.dart`)
holds the triangulation cache and the fill→boundary reverse map, **keyed by
`Handle`, never `geomIndex`**, because `purge()` renumbers every `geomIndex`
wholesale and a slot-keyed cache would not go stale, it would go *permuted*.

**Exit gate: 6 of 9 failable criteria PASS outright; 2 measured but not
scored (a contaminated timing row, and the seam question left explicitly open
on Impeller/GPU); 1 process criterion (the mutation log) PASS.** No criterion
failed. Full detail, criterion by criterion:
[docs/superpowers/notes/2026-08-22-plan-3e-results.md](docs/superpowers/notes/2026-08-22-plan-3e-results.md).
Mutation log (56 mutants, 52 killed, 2 proven equivalent, 2 documented gaps):
[docs/superpowers/notes/plan-3e-mutation-log.md](docs/superpowers/notes/plan-3e-mutation-log.md).

**Four facts worth carrying forward, because no single per-task report states
them together:**

1. **Measured on Flutter 3.47.1** (framework `6655482ec0`), not the 3.47.0 the
   plan's own header states — the upgrade landed mid-plan, between Tasks 2 and
   3, and broke nothing checkable.
2. **macOS Low Power Mode was on for the whole of Task 16's device session.**
   Every timing row in it carries that mark; per Plan 3d's own measurement,
   that is a uniform ~24% penalty on both raster and build, not a rounding
   error.
3. **The 10,000-entity-under-16.67ms criterion is therefore MEASURED, not
   PASS** — both numbers (build 9.12ms, raster 5.00ms) clear the bar by a wide
   margin, but a contaminated timing row is recorded rather than scored.
4. **The translucent seam's routing rule does not fire (fills batch,
   settled), but the mode-2 mechanism itself is open on Impeller/GPU** —
   `flutter_test`'s software Skia cannot antialias `drawVertices` at all
   (proven by probe, pinned as a permanent regression test), so the measured
   `0.000%` is a property of the instrument. Do not read it as "no seam was
   found."

**One thing 3e did not close.** Permitted divergence 5 — overlapping
translucent strokes double-blending on a triangle soup — is now **live**
(fills exist and can carry alpha < 255) but **still not exercised by any
fixture**. Task 15 measured a different, narrower question (a translucent
fill's own internal triangulation seam), not this one. Open for 3g or a
follow-up. See the [3d results
note](docs/superpowers/notes/2026-08-21-plan-3d-results.md) for where this
divergence was first named.

### Plan 3f — text wiring and level of detail

In flight. Spec:
[docs/superpowers/specs/2026-08-22-jet-cad-2d-plan-3f-text-design.md](docs/superpowers/specs/2026-08-22-jet-cad-2d-plan-3f-text-design.md).
Plan:
[docs/superpowers/plans/2026-08-22-jet-cad-2d-plan-3f-text.md](docs/superpowers/plans/2026-08-22-jet-cad-2d-plan-3f-text.md).

Two defects: a document built the ordinary way carries `InsertionPointMeasurer`
and draws no text without reporting anything, and the painter and the sink read
different measurers. Plus text LOD, which is the one of Plan 3g's four
subsystems that depends on none of the other three.

### Plan 3g — the definition/tile picture cache

**What 3d hands it.** A picture cache that records into a `Picture` interacts
with a sink that batches across residuals: 3g must decide whether a cached
picture flushes the vertex buffer at its boundary. There is **no crossover
number** to work against — the vertices backend's raster margin is still
widening at 500,000 entities — and there is **96.00 MiB of vertex buffer pinned
for the widget's life** at that corpus size, which is the arithmetic a tiling
scheme changes. Read the margin against **canvas calls**, not entity count: a
10× entity rise moves `screenSpaceLeafCount` only 2.13× and `dashSpans` 3.03×.

The prize is real: the dominant cost is leaf-count-bound GPU vertex work, and
dashing makes that story **stronger** — one dashed polyline becomes dozens of
drawn spans per leaf without moving the painter's op count.

Five traps. The first four are recorded in
[docs/superpowers/notes/2026-08-17-carry-forward-additions.md](docs/superpowers/notes/2026-08-17-carry-forward-additions.md);
the fifth is Plan 3e's own, added here because a reader who follows
`CLAUDE.md`'s "read `STATUS.md` first" and stops at this section would
otherwise never see it:

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
5. **The allocation gate cannot see a lazily-populated cache, and a picture
   cache is exactly that shape.** Plan 3e proved this directly: mutating
   `DraftPainter._drawFill` to compute and store a triangulation on a cache
   miss, instead of skipping it, left `paint_allocation_test.dart`'s own
   `debugCapacityVertices` before/after comparison green. The mechanism only
   reads `VerticesDrawSink`'s own vertex-buffer capacity; a triangulation (or
   a baked `Picture`) that lands on the general Dart heap without touching
   that buffer is invisible to it, and the warm-up frames a gate like this
   one always runs will have already sized the buffer before the subject
   frame is measured, hiding a first-draw allocation completely. **If 3g's
   picture cache populates lazily on first paint, this exact gate will stay
   green while the cache allocates a `Picture` per miss on the frame path.**
   What actually proved fills are populated eagerly and not lazily was a
   direct command-time assertion (`the triangulation is materialised by the
   command, not by a draw`), not the allocation gate — 3g needs the
   equivalent of that assertion, or a real VM allocation-profile mechanism
   ported to the Flutter-side suite, not another buffer-capacity read.

**Do not design 3g against a fixed op-count ceiling.** The web whole-drawing
abort is reproducible but its trigger is unknown — a memory- or
session-dependent CanvasKit failure explains it with no code at fault. What 3g
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
- **A rig transcript that stops early is a failed run, not a bad grep.** R4a
  and R4b printed `build`, `raster` and `command` and then threw, for months,
  because their repaint guard was the canvas-only copy. The numbers looked
  complete because the missing lines were the ones nobody expects to read. Any
  rig guard belongs *before* the first print or nowhere.
- **A transcript taken before 2026-08-21 has a different shape.**
  `screenSpaceLeafCount` moved out of R2's `lineweightScale` line into the
  shared `printInvariants` line. Old greps will miss it.
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
