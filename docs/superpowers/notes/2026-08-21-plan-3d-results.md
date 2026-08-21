# Plan 3d results and exit gate — the vertices sink

**Runs of record:** 2026-08-20 and 2026-08-21.
**Branch:** `spike/vertices-sink`, worktree `.claude/worktrees/vertices-spike`.
**Commit range:** `548fa8e..4a16b41` (Task 15's own commit lands on top).
**Spec:** [`docs/superpowers/specs/2026-08-20-jet-cad-2d-plan-3d-design.md`](../specs/2026-08-20-jet-cad-2d-plan-3d-design.md)
**Plan:** [`docs/superpowers/plans/2026-08-20-jet-cad-2d-plan-3d-vertices-sink.md`](../plans/2026-08-20-jet-cad-2d-plan-3d-vertices-sink.md)
**Mutation log:** [`plan-3d-mutation-log.md`](plan-3d-mutation-log.md)

---

## Verdict

**Seven of the eight criteria pass on measurements taken and pasted below.
Criterion 7 is measured and cannot be closed by this plan** — it requires a
`CLAUDE.md` amendment that the design forbids the plan from granting itself.
It is open for the human and it is the only thing standing between this plan
and a clean gate.

| # | Criterion | Verdict | The deciding number |
|---|---|---|---|
| 1 | Both suites green, analyze and format clean | **PASS** | engine 720/720, widgets 238 passing + 1 skipped, three packages clean |
| 2 | Every design-table mutant killed by a named test, recorded in the log | **PASS**, one qualification | 14/14 named mutants killed; `B1` killed by an equivalent mutation, not the tabled one |
| 3 | Sink-against-sink coverage on point/polyline/circle/arc/text at a justified tolerance | **PASS** | stray 0, uncovered 0, at a one-pixel dilation; canvas 22,398 ink px, vertices 23,241 |
| 4 | Goldens exist and pass on both backends for all 14 fixtures | **PASS** | 28 PNGs (14 canvas + 14 vertices), 23 golden tests pass |
| 5 | 10,000 entities: vertices frame under 16.67 ms, median of three | **PASS** | build p50 **5.71 ms** [5.67, 5.81], raster p50 **6.68 ms** [6.63, 6.75] |
| 6 | 50k and 500k: vertices raster p50 better than canvas by more than the spread | **PASS at both** | 50k gap **58.22 ms**, 500k gap **485.01 ms**; no interval overlap, no crossover |
| 7 | Allocation invariant covers the paint path, residue zero or bounded **and written into `CLAUDE.md`** | **MEASURED, NOT CLOSED** | residue is 3 objects per flush, `3 × (textOps + 1)` per frame, nothing per entity; `CLAUDE.md` unamended |
| 8 | Web rows measured and the platform default stated with the number that justifies it | **PASS** | default is `vertices` everywhere; the justifying number is the **17.3×–17.5× web build ratio**, not the raster figure |

### What failed, and what is merely unfinished

- **Criterion 7 is not passed.** Its text requires the residue "written into
  `CLAUDE.md`". It is not written, deliberately: the design says "the plan may
  not grant itself the `CLAUDE.md` amendment. Criterion 7 is not satisfied by
  editing the rule it is measured against." See
  [The allocation residue](#the-allocation-residue-and-the-claudemd-question)
  for the exact proposed wording and both outcomes.
- **Nothing else failed.** Criterion 6 did not tie at 500,000, so the design's
  crossover fallback does not fire and there is no crossover number to hand 3f.
- **Several things are true and unflattering** and are recorded below rather
  than left out: the web rows are not reproducible from what was committed; the
  R4a/R4b pairs' control is not demonstrated; the seam join and the point-shape
  fix have no coverage through any frame path; the permitted sub-pixel
  divergence is exercised in exactly one place and nowhere in production
  fixtures; a divergence *not* on the permitted list exists and is
  characterised rather than fixed; and the vertices backend pins 96.00 MiB of
  vertex buffer at 500,000 entities that the canvas backend does not.

---

## Machine, OS and versions

Every timing in this note was taken on one machine.

```
$ sw_vers
ProductName:        macOS
ProductVersion:      26.5.1
BuildVersion:        25F80
```

Hardware (`system_profiler SPHardwareDataType`): MacBook Pro, Model Identifier
`Mac15,7`, Apple M3 Pro, 12 cores (6 performance + 6 efficiency), 36 GB memory.

```
$ flutter --version
Flutter 3.47.0 • channel stable • https://github.com/flutter/flutter.git
Framework • revision 4cf2416426 (9 days ago) • 2026-08-11 11:53:49 -0700
Engine • hash 59d54a2b2896a6bbf356c94b7fac7b9e235bdacd (revision 5f77625673) (9 days ago) • 2026-08-11 16:38:36.000Z
Tools • Dart 3.13.0 • DevTools 2.60.0
```

```
$ /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --version
Google Chrome 151.0.7922.170
```

### Low Power Mode

Plan 3c's whole timing set was contaminated by macOS Low Power Mode, so this
plan reads it before and after.

```
$ pmset -g | grep lowpowermode
 lowpowermode         0
```

Task 12 read it **before** the desktop sweep and **again after** it, both `0`.
The desktop rows are not contaminated.

**The web sweep has no Low Power Mode reading of record.** Task 13 never took
one. It ran on the same machine within about two hours of Task 12's post-run
reading of `0` and nothing in the session turned it on, so contamination is
unlikely — but "unlikely" is not "read", and this note will not claim a reading
that was not taken.

### When the runs happened

Timestamps from the branch's own commits (local time, +0300):

- **Phase A** (Task 7, first device run of the vertices backend, 10,000
  entities): **2026-08-20**, before `3351232` at 22:12.
- **Phase C desktop** (Task 12, 30 `flutter drive` runs) and **Phase C web**
  (Task 13, 12 `flutter run -d chrome` runs): **2026-08-21**, in the window
  between `c678ec3` (06:08) and `25bed0d` (08:26).

---

## The exit gate, criterion by criterion

### Criterion 1 — both suites green, analyze and format clean

Run on this tree at `4a16b41`, working tree clean.

```
$ cd packages/jet_cad_2d && dart test
00:02 +720: All tests passed!

$ dart analyze
Analyzing jet_cad_2d...
No issues found!

$ dart format --output=none --set-exit-if-changed .
Formatted 105 files (0 changed) in 0.13 seconds.
exit=0
```

```
$ cd packages/jet_cad_2d_flutter && flutter test
00:02 +238 ~1: All tests passed!

$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.9s)

$ dart format --output=none --set-exit-if-changed .
Formatted 44 files (0 changed) in 0.06 seconds.
exit=0
```

The harness is in the gate from Task 7 onward (it does not compile in Tasks 1–6
by construction — Task 1 deletes the `useVertices` parameter it passed and Task
7 is the task that repairs it):

```
$ cd apps/dev_harness_2d && flutter analyze
Analyzing dev_harness_2d...
No issues found! (ran in 0.9s)

$ dart format --output=none --set-exit-if-changed lib integration_test
Formatted 3 files (0 changed) in 0.01 seconds.
exit=0
```

**PASS.** 720 engine tests, 238 widget tests passing with 1 skipped, three
packages analyze- and format-clean. The one skip is
`test/rig/paint_microbench_test.dart`, skipped at the suite level by the `rig`
tag in `dart_test.yaml` ("rigs measure; they do not assert") — pre-existing, by
design, and unrelated to this plan's deliverables.

### Criterion 2 — every mutant in the design's table killed by a named test

The log is [`docs/superpowers/notes/plan-3d-mutation-log.md`](plan-3d-mutation-log.md),
41 mutants accounted for: 34 killed, 1 deliberate control, 2 unreachable dead
code, 2 cited from the codebase's own confirmed record, 2 structurally not
reproducible. The design document's own table is the 14 rows `J1`–`J9`, `B1`,
`B2`, `A1`, `V1`, `P1`, and **all 14 are killed** — 13 outright, `A1` after
surviving and being closed with a new test in two rounds.

**PASS, with one qualification the log itself states and this note repeats
rather than smooths over.** `B1` ("resolve the backend per call site rather
than once") was killed by an *equivalent* mutation, not the tabled one. The
design's stated killer for `B1` is "a test that overrides the backend and reads
it back from both the widget and the rig" — **no such test exists**, and `B1`'s
literal mutation has no line to invert, because `defaultRenderBackend()` is
unconditional with exactly one `lib/` call site at `draft_canvas.dart:140`. The
substitute run was `didUpdateWidget`'s comparison dropping
`widget.backend != oldWidget.backend`, which died on
`'changing the backend prop rebuilds the sinks'` with
`Expected: not null / Actual: <null>`. Read `B1` as killed via an equivalent
mutation, not as the tabled mutation run literally.

Two survivors surfaced during the mutation run and both were closed with a new
test in the same task, which is the mutation log doing its job rather than
confirming a suite that was already adequate:

- **`A1`** — a `Paint` allocated per flush. It survived because
  `paint_allocation_test.dart` measured buffer capacity only and was blind to a
  `Paint` object. A first fix proved too narrow (a call-site-local
  `Paint()` that never touched the field still passed all 237 tests); the second
  pins object identity across two flushes.
- **`S2`** — colour grouping before the flush. It survived because the existing
  test read the *pre-flush* buffer, correct by construction, and could not see a
  reorder inside `flush()` itself — which is exactly where the sink's real
  historic bug lived.

### Criterion 3 — sink against sink, on a fixture carrying all five primitives

```
$ cd packages/jet_cad_2d_flutter && flutter test test/sink_comparison_test.dart
00:00 +0: the two backends draw the same drawing
00:00 +1: the two backends agree on the ops the painter cannot emit
00:00 +2: anisotropic stroke width diverges, and vertices is right
00:00 +3: a sub-pixel stroke is where the two backends stop agreeing
00:00 +4: a full-sweep ARC leaves an unjoined seam. This is a defect
00:00 +5: All tests passed!
```

**The fixture carries all five required primitives.** `comparisonFixture()` in
`test/support/sink_comparison.dart` emits a point marker, two polylines (one
oblique corner inside the miter limit, one 160° corner past it), an open arc, a
text entity that forces a mid-frame flush, and a circle under a rotated
(0.35 rad) and non-uniformly scaled (1.0 × 1.15) residual.
`assertNoIdentityTransforms(doc)` runs first, so the degenerate-fixture failure
mode this repository names is checked by the test rather than asserted by its
author.

**The measurement of record (2026-08-21, `devicePixelRatio` 3.0, 1200×900
device pixels):** canvas 22,398 ink pixels, vertices 23,241, **0 stray and 0
uncovered**, at two flushes. The direct-ops fixture (a closed run and a point
under a rotated residual, neither of which `DraftPainter` can emit): canvas
18,291, vertices 18,906, **0 stray and 0 uncovered**, one flush.

**The tolerance and why it is that value.** The comparison is not a per-pixel
colour difference — comparing a no-AA scan conversion against an anti-aliased
raster at a per-pixel tolerance bounds nothing at one-pixel strokes. It is
**ink-region membership in both directions**, with exactly two knobs:

- `kInkAlphaFloor = 0xC0` — canvas pixels below this alpha are anti-aliasing
  spill, which the coverage-only rasterizer has no way to produce and which is
  row 3 of the permitted-divergence table.
- `_nearInk` dilates by **exactly one pixel in each direction**, a 3×3
  neighbourhood. That covers the half-pixel each rasteriser may place an edge
  differently and does not cover a corner in the wrong place.

Neither was widened to make a number go to zero: **both zeros were measured at
the tolerance as designed.** The thresholding is also conservative in the
dangerous direction — canvas ink is the strict `alpha >= 0xC0` core while
vertices ink is all coverage, which makes `stray` harder to zero than to
inflate. The text mask hides 61,631 canvas ink pixels and **zero** vertices
pixels, which is what says it excludes glyphs and not geometry.

**PASS.**

### Criterion 4 — goldens on both backends for all 14 fixtures

```
$ cd packages/jet_cad_2d_flutter && flutter test --tags golden
00:01 +23: All tests passed!

$ ls test/golden/*.png | wc -l          # canvas
14
$ ls test/golden/vertices/*.png | wc -l # vertices
14
```

28 PNGs, 14 fixtures × 2 backends: `dash_ladder_1..5`, `text_ladder_1..5`,
`stroke_width_0_5x`, `stroke_width_1_0x`, `stroke_width_8_0x`,
`anisotropy_bypass`. 23 test cases cover them (the three stroke-width zooms
share one test and the anisotropy fixture carries a second, non-golden
assertion). All 14 pre-existing canvas PNGs are byte-identical to what they
were before this plan (md5-compared in Task 10 and re-confirmed after its fix
round).

**PASS**, and the goldens were checked as pictures rather than as a green tick.
A reviewer opened all 14: `dash_ladder_2`'s circle has **no notch at three
o'clock at 10× zoom** (Task 5's seam holds), the three `stroke_width` fixtures
show **no crack at any miter base** (Task 4's two-triangle miter holds), and
`anisotropy_bypass` shows uniform width on every edge including the 8:1 stretch.
Suppressing the bevel triangle in `_emitJoin` moved exactly 3 vertices goldens
and 0 canvas ones, which is the hairline crack the spec names.

**One thing the goldens nearly failed to test at all, recorded because the
cause was not the one first reported.** The two text ladders' vertices goldens
were blank. The cause was structural: `TriangleRasterizer` was built at logical
resolution and samples pixel centres at `k + 0.5`, while the sink's width math
is calibrated in *device* pixels. At `dpr` 3.0 the `_rule` lineweight gives
0.3402 logical px against a floor of 1/3 = 0.3333, so neither the clamp nor the
alpha fade fires and the correctly-emitted 2-triangle band spanning
x ∈ [199.8299, 200.1701] contained no sample point. Mutating `polyline` to
return immediately — no geometry at all — left `text_ladder_1` and `_2`
**green**. The fix rasterizes at device resolution, which is what Impeller does;
the negative control now turns **all 14** vertices goldens red.

**A rationale that is now void and must not be repeated.** Task 10 justified
keeping the 14 canvas goldens partly as "canvas is the web renderer, so they
stop testing code nothing draws through." That reason died with the web
default flip: **no platform defaults to canvas now.** The goldens still earn
their place, for a different and correct reason — `CanvasDrawSink` is not dead
code. `DraftCanvasState._attach` constructs
`VerticesDrawSink(..., fallback: sink)`, and the vertices runs show
`canvasCalls=19` (10k) and `canvasCalls=24` (50k) **on web** — the desktop
control table above shows the same thing at 18 and 23, the small difference
being the different viewport, not a different behaviour. Either way
`CanvasDrawSink` draws text and fallbacks on every frame.

### Criterion 5 — 10,000 entities under 16.67 ms

Desktop, macOS profile, R2 pan/zoom, 242 frames, vertices backend, three runs:

| run | build p50 | raster p50 |
|---|---|---|
| 1 | 5.81 ms | 6.63 ms |
| 2 | 5.67 ms | 6.68 ms |
| 3 | 5.71 ms | 6.75 ms |
| **median** | **5.71 ms** | **6.68 ms** |
| spread (`max − min`) | 0.14 ms | 0.12 ms |

**PASS.** Both stages' median p50 are under 16.67 ms, and so is every
individual run's p50 — the worst single reading is build 5.81 and raster 6.75.
The canvas backend at the same corpus is 12.35 / 44.32 ms, so this is the
criterion the plan existed to move.

**The honest caveat.** The criterion is written on the median of three p50s and
it passes on that. It is not a claim that every frame of the pan/zoom script
fits the budget: **vertices raster p95 is 22.10–22.36 ms** across the three
runs, so a minority of frames — the zoom extremes, where the working set is
largest — still exceed 16.67 ms. Canvas's raster p95 at the same corpus is
59.40–60.53 ms.

Web at 10,000 entities is also under budget on the vertices backend (build p50
6.80 ms, raster p50 1.40 ms), but see
[Why the two tables cannot be merged](#why-the-two-tables-cannot-be-merged)
before reading the raster figure as a GPU measurement.

### Criterion 6 — 50,000 and 500,000, raster p50 better by more than the spread

The criterion's own definition: spread is `max − min` of the three runs, and it
is met when the two backends' `[min, max]` intervals **do not overlap** and the
vertices one is lower.

**At 50,000 entities:**

| backend | raster p50, three runs | median | interval | spread |
|---|---|---|---|---|
| canvas | 66.95, 66.94, 66.85 | 66.94 ms | [66.85, 66.95] | 0.10 ms |
| vertices | 8.63, 8.53, 8.22 | 8.53 ms | [8.22, 8.63] | 0.41 ms |

Intervals disjoint, vertices lower. Gap between the intervals:
**66.85 − 8.63 = 58.22 ms**, against a combined spread of 0.51 ms — a margin
of about 114× the spread. **PASS.**

**At 500,000 entities:**

| backend | raster p50, three runs | median | interval | spread |
|---|---|---|---|---|
| canvas | 507.05, 508.90, 508.00 | 508.00 ms | [507.05, 508.90] | 1.85 ms |
| vertices | 22.04, 21.20, 21.64 | 21.64 ms | [21.20, 22.04] | 0.84 ms |

Intervals disjoint, vertices lower. Gap: **507.05 − 22.04 = 485.01 ms**,
against a combined spread of 2.69 ms. **PASS.**

**It did not tie at 500,000, so there is no crossover to record and nothing to
hand 3f under the design's fallback clause.** The margin widens rather than
narrowing: raster p50 ratio is 6.63× at 10k, 7.85× at 50k, 23.48× at 500k.
Nothing failed at 500,000 and there was no OOM.

**But do not read that widening as linear in entities** — see
[The ratio is not linear in entities](#the-ratio-is-not-linear-in-entities).

### Criterion 7 — the allocation invariant on the paint path

The invariant exists, covers the paint path, and passes:

```
$ cd packages/jet_cad_2d_flutter && flutter test test/invariants/
00:00 +0: a steady-state frame allocates O(1) per flush, not O(entities)
00:00 +1: flush hands drawVertices the same Paint object every time, not a call-site-local one
00:00 +2: All tests passed!
```

`packages/jet_cad_2d/test/invariants/query_allocation_test.dart` is green in the
engine run above (`720/720`).

**MEASURED, NOT CLOSED.** See the next section. This is the one criterion this
plan cannot decide.

### Criterion 8 — the web rows and the platform default

Measured (Task 13): see [the web table](#web-chrome-canvaskit). The default is
stated in code, in the one place the decision is made:

```dart
RenderBackend defaultRenderBackend() => RenderBackend.vertices;
```

**`defaultRenderBackend()` now returns `RenderBackend.vertices` unconditionally,
web included.** That flip was the design's own stated consequence of the
measurement, not an improvisation: the spec's risk list says "CanvasKit makes
the web rows bad enough to want a third path" is out of scope *because* the
fallback already exists, and the criterion asks for the default to be stated
with the number that justifies it.

**The number that justifies it is the 17.3×–17.5× within-platform build
ratio, not the headline raster figure.** The doc comment on
`defaultRenderBackend()` carries both tables and that caveat. See the next
section for why the raster number is the wrong one to lean on.

**PASS.**

---

## The allocation residue, and the `CLAUDE.md` question

**What a steady-state frame actually allocates.** Task 3 measured it:
**three objects per flush** — the `Vertices` itself plus two
`Float32List.sublistView` / `Int32List.sublistView` wrappers — and **nothing
per entity**. A frame flushes once at the end plus once before each unbatchable
op, so the frame total is `3 × (textOps + 1)`. The triangle buffer itself is a
doubling reserve that never shrinks, so in steady state it is not reallocated
at all; that is the property `paint_allocation_test.dart` pins deterministically
by capacity, not by a profiler ratio.

`CLAUDE.md`'s non-negotiable reads:

> **The frame path allocates nothing in steady state.**
> `packages/jet_cad_2d/test/invariants/query_allocation_test.dart` measures it.

**That is not literally true of this backend.** Three objects per flush is not
nothing. The proposed wording, unchanged since Task 3 measured it:

> **The frame path allocates nothing per entity in steady state, and O(1) per
> flush.** `packages/jet_cad_2d/test/invariants/query_allocation_test.dart` and
> `packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart`
> measure it.

**`CLAUDE.md` is untouched by this plan, on purpose.** The design says: "The
plan may not grant itself the `CLAUDE.md` amendment. Criterion 7 is not
satisfied by editing the rule it is measured against." An exit gate that can be
passed by editing the rule it is measured against is not a gate. The decision is
the human's and it has not been made.

**Both outcomes, stated in advance so the answer is a decision and not a
negotiation:**

- **If the amendment is approved** — criterion 7 passes. The residue is
  measured, bounded, `O(1)` per flush, zero per entity, and written into
  `CLAUDE.md` as the criterion requires. The gate is 8/8 and Plan 3d is done.
- **If the amendment is refused** — criterion 7 **fails**, and that is this
  plan's result rather than a delay. The design's own risk list says so: "The
  allocation residue turns out to be unavoidable and larger than expected.
  Then criterion 7 fails and the plan reports it. A non-negotiable amended with
  a measurement is a decision; one amended to make a plan pass is not." A
  refusal means the vertices backend does not meet this repository's standing
  allocation rule and the branch does not merge on the strength of this note.

---

## The measurements

### Convention: what "median of three" means in these tables

**The medians are taken independently down each column.** A cell's build p50 is
the median of the three runs' build p50s and its raster p50 is the median of the
three runs' raster p50s — so a published pair may come from two different runs
and no single run necessarily produced that exact pair. Desktop 10,000 canvas
is an example: `12.35 / 44.32` is run 3's build with run 3's raster here, but
web 10,000 canvas's `117.80 / 79.30` pairs run 3's build with run 2's raster.
This is Task 12's convention and Task 13 followed it; it is stated rather than
changed.

Spread is `max − min` of the three runs, per the design's definition, not a
standard deviation — three samples do not support one.

### Desktop (macOS, profile)

```sh
cd apps/dev_harness_2d
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart --profile -d macos \
  --dart-define=TEXT=true --dart-define=ENTITIES=$N \
  --dart-define=RIG=pan --dart-define=BACKEND=$B 2>&1 \
  | grep -E "R2 |build |raster |screenSpace|dashSpans|backend=|text:|debugCapacityVertices"
```

R2 (pan and zoom), 242 frames, `TEXT=true`, median of three. Build p50 /
raster p50, each with its `[min, max]` beside it.

| entities | backend | build p50 | build [min, max] | raster p50 | raster [min, max] |
|---|---|---|---|---|---|
| 10,000 | canvas | 12.35 ms | [12.34, 12.37] | 44.32 ms | [44.22, 44.96] |
| 10,000 | vertices | **5.71 ms** | [5.67, 5.81] | **6.68 ms** | [6.63, 6.75] |
| 50,000 | canvas | 15.36 ms | [15.35, 15.43] | 66.94 ms | [66.85, 66.95] |
| 50,000 | vertices | **7.07 ms** | [7.06, 7.38] | **8.53 ms** | [8.22, 8.63] |
| 500,000 | canvas | 44.29 ms | [44.12, 44.30] | 508.00 ms | [507.05, 508.90] |
| 500,000 | vertices | **17.44 ms** | [17.19, 17.73] | **21.64 ms** | [21.20, 22.04] |

R4a (a leaf edit per frame) and R4b (an instance edit per frame), both at
50,000 entities, same driver, `--dart-define=RIG=$RIG`:

| rig | backend | build p50 | build [min, max] | raster p50 | raster [min, max] | command p50 |
|---|---|---|---|---|---|---|
| R4a | canvas | 15.96 ms | [15.92, 15.98] | 67.11 ms | [67.08, 67.83] | 0.05 ms |
| R4a | vertices | **8.73 ms** | [8.70, 8.77] | **4.71 ms** | [4.71, 4.79] | 0.12 ms |
| R4b | canvas | 17.34 ms | [17.03, 17.40] | 64.89 ms | [64.84, 65.46] | 175.35 ms |
| R4b | vertices | **7.26 ms** | [7.23, 7.36] | **3.65 ms** | [3.57, 3.68] | 167.23 ms |

**Control — the R2 pairs are genuinely controlled.** The backend-independent
fields match exactly across the two backends at each corpus size, which is what
makes a pair a comparison of two renderers rather than of two drawings:

| entities | screenSpaceLeafCount | dashSpans | collapsed | canvasCalls (canvas) | canvasCalls (vertices) | triangles | drawVerticesCalls |
|---|---|---|---|---|---|---|---|
| 10,000 | 1,664 | 37,376 | 238 | 39,631 | 18 | 166,279 | 19 |
| 50,000 | 2,170 | 48,323 | 334 | 51,298 | 23 | 217,758 | 20 |
| 500,000 | 4,625 | 146,335 | 356 | 151,671 | 74 | 559,682 | 22 |

**The R4a/R4b pairs' control is NOT demonstrated.** Task 12's Step 3 grep
pattern (`-E "R4|build |raster |command |backend="`) dropped
`screenSpaceLeafCount` and `dashSpans` from those transcripts, so those two
rows' invariant fields were never captured. It is *plausible* — the corpus is
deterministic at a fixed `ENTITIES` and the R2 pairs establish control for the
same corpus — but plausible is not shown, and re-running would cost over half
an hour of device time to confirm what R2 already establishes. **The note
states the gap rather than claiming control.**

**One R4a oddity, recorded and unexplained.** R4a's `command` time is
backend-dependent — canvas ~0.05 ms, vertices ~0.12 ms, consistent across three
runs each — for a pure document mutation that should touch neither sink. Tens
of microseconds; plausibly a cache or allocator artefact of the much larger
vertices buffer, not established as a real backend cost.

### Web (Chrome, CanvasKit)

```sh
flutter run -d chrome --profile \
  --dart-define=RUN_R2=true --dart-define=TEXT=true \
  --dart-define=ENTITIES=<N> --dart-define=BACKEND=<canvas|vertices>
```

Chrome 151.0.7922.170, CanvasKit, window 1200×723 at `dpr` 2, median of three.
**500,000 was not run on web**; the Task 13 brief authorises skipping it, and
the 10k/50k rows already point decisively.

| entities | backend | build p50 | build [min, max] | raster p50 | raster [min, max] |
|---|---|---|---|---|---|
| 10,000 | canvas | 117.80 ms | [117.10, 122.20] | 79.30 ms | [79.20, 79.60] |
| 10,000 | vertices | **6.80 ms** | [6.80, 6.90] | **1.40 ms** | [1.30, 1.40] |
| 50,000 | canvas | 155.70 ms | [154.20, 156.50] | 107.90 ms | [107.90, 108.00] |
| 50,000 | vertices | **8.90 ms** | [8.80, 8.90] | **1.80 ms** | [1.80, 1.80] |

Web control fields, matching exactly within each pair:

| entities | screenSpaceLeafCount | dashSpans | collapsed | canvasCalls (canvas) | canvasCalls (vertices) | triangles | drawVerticesCalls |
|---|---|---|---|---|---|---|---|
| 10,000 | 2,111 | 50,120 | 182 | 52,897 | 19 | 223,733 | 20 |
| 50,000 | 2,709 | 66,627 | 257 | 70,193 | 24 | 294,536 | 21 |

**`frames` does not match within each web pair and must not be read as having
matched.** 10,000: vertices 238/240/241 against canvas 241/241/241. 50,000:
vertices 241/239/233 against canvas 241/241/241. This is `onReportTimings`
batching differently at the tail in app-run mode — a real running app has no
synthetic clock to force an exact frame count the way `tester.pump` does. It
does not move a p50, and every other invariant matches exactly, which is the
control that matters.

### Why the two tables cannot be merged

**They are two separate confirmations, not one table doubled.** Three reasons,
and the third is the one that matters most:

1. **They did not draw the same drawing.** Desktop 10,000 is 1,664 screen-space
   leaves and 37,376 dashSpans; web 10,000 is 2,111 and 50,120 — a different
   viewport (web fits 1200×723 @2; desktop is whatever the driven window was).
   There is no sound per-platform multiplier between them.
2. **`build` is commensurable; `raster` is not.** `build` is Dart-side
   widget-to-displaylist cost, the same Flutter framework code on both
   platforms. Web vertices build is **3.22 µs/leaf** against macOS's **3.43** —
   the same Dart-side work at the same cost, which is a sanity check that
   passes. Web *canvas* build is 2.23 µs/call against macOS's 0.31, the
   expected CanvasKit JS-interop penalty.
3. **The headline web raster ratio is not a credible GPU measurement.** Web
   vertices raster of **1.40 ms** against macOS's **6.68 ms**, on **34% more
   geometry**, is not physically plausible as end-to-end GPU time. The most
   likely explanation is that CanvasKit's `FrameTiming.rasterDuration` ends at
   command submission rather than at completion. So the **56.6× / 59.9×** web
   raster ratios point the same direction as everything else but are **not the
   number the platform default rests on.**

**The default rests on the within-platform build ratios: 117.80 / 6.80 =
17.3× at 10,000 and 155.70 / 8.90 = 17.5× at 50,000.** That is the same Dart
code on both arms of the comparison, measured on the same platform, and it is
what answers the open question the default was written against — whether
CanvasKit's `drawVertices` is worth using.

### The ratio is not linear in entities

The raster margin widens 6.63× → 7.85× → 23.48× across 10k → 50k → 500k
entities, but **`ENTITIES` is not the driver of drawn cost.** From 50,000 to
500,000 — a 10× rise in entities — the geometry that actually reaches the sink
grows far less:

| | 50,000 | 500,000 | factor |
|---|---|---|---|
| entities | 50,000 | 500,000 | 10.0× |
| `screenSpaceLeafCount` | 2,170 | 4,625 | 2.13× |
| `dashSpans` | 48,323 | 146,335 | 3.03× |
| `canvasCalls` (canvas) | 51,298 | 151,671 | 2.96× |

The working-set camera culls, so a 10× corpus is a ~3× frame. Read the widening
ratio against **canvas calls**, which is the unit of render cost this project
established in
[`2026-08-20-dash-leaf-separation.md`](2026-08-20-dash-leaf-separation.md) —
not against the entity count in the table's left column.

### The cost the canvas backend does not carry

Peak vertex-buffer capacity, read from `debugCapacityVertices` printed in the
R2 vertices transcripts (12 bytes per vertex: `Float32x2` position + `Int32`
colour):

| entities | peak `debugCapacityVertices` | bytes | |
|---|---|---|---|
| 10,000 | 262,144 | 3,145,728 | 3.00 MiB |
| 50,000 | 1,048,576 | 12,582,912 | 12.00 MiB |
| 500,000 | 8,388,608 | 100,663,296 | **96.00 MiB** |

**At 500,000 entities the vertices backend pins exactly 96.00 MiB for the life
of the widget.** The doubling reserve never shrinks — that is the same property
that makes the frame path allocation-free in steady state, and it is not free.
The canvas backend has no equivalent. Whoever budgets memory for a large
drawing needs this number and it is not visible from any timing row.

---

## The five permitted divergences, with their counts

The design names five divergences as permitted; anything else is a defect. Each
is exercised or explicitly not, with the sink-against-sink measurement beside
it, taken 2026-08-21.

| # | Divergence | Which is right | Where it is exercised | Measured |
|---|---|---|---|---|
| 1 | **Anisotropic stroke width** | vertices | `'anisotropic stroke width diverges, and vertices is right'`, `anisotropyDivergenceFixture(scaleY: 3.0)` | canvas 19,194 ink px, vertices 24,580, **3,513 stray and 897 uncovered** — in both directions, which is what makes it a width divergence and not a misplaced ellipse |
| 2 | **Point shape** | neither; 3d picks the axis-aligned square | Removed as a divergence: `CanvasDrawSink.point` was changed to match. Pinned by `point_shape_test.dart` and by `'the two backends agree on the ops the painter cannot emit'` | **0 stray, 0 uncovered** (canvas 18,291, vertices 18,906) |
| 3 | **Anti-aliasing** | canvas | Absorbed by `kInkAlphaFloor = 0xC0` and the one-pixel dilation in every comparison | **0 stray, 0 uncovered** on the agreement fixture (canvas 22,398, vertices 23,241) |
| 4 | **Sub-pixel strokes** | vertices, untestable by agreement | `'a sub-pixel stroke is where the two backends stop agreeing'`, lineweight 1 → 0.11 device px | canvas **0** ink px (every pixel below the alpha floor), vertices **1,140**, all 1,140 stray |
| 5 | **Overlapping translucent strokes** | canvas | **Not exercised.** Inert while the corpus is opaque (`argb`'s alpha is `255 - transparency`, `resolved_style.dart:15`); live the moment 3e adds fills | no measurement — recorded, not fixed |

**Row 4 is exercised in exactly one place, and nowhere in a production
fixture.** No golden fixture in this repository reaches the sub-pixel floor:
the two ladders sit at 0.3402 logical px against a 0.3333 floor, the dash
ladder at 1.134, and `stroke_width` at 4.0 with `dpr` 1.0. The permitted
sub-pixel divergence is pinned by that one unit test and by nothing else — the
spec predicted exactly this ("the sub-pixel rules are pinned by unit test and by
nothing else") and it is true. A reader must not assume the golden suite covers
it.

**Two device-pixel regimes coexist in the golden suite, documented in neither
file until now:** `stroke_width_golden_test.dart` pins `dpr` 1.0 while the two
ladders run at the binding's 3.0.

### A divergence that is NOT on the permitted list

**A DXF `ARC` carrying `sweep == 2π` draws a full circle with an unjoined notch
at its start angle, where `Canvas.drawArc` closes the loop.** `closed` is
decided structurally with no tolerance anywhere — `VerticesDrawSink.circle`
passes `true`, `arc` passes `false` — so the value reaches the sink untouched.

**It is characterised, not fixed**, and the reason is that nothing can produce
one today:

- The corpus cannot. `generate_document.dart:617` draws root arc sweeps from
  `[0.25π, 1.75π)` and `:540` draws definition arcs from `[0.5π, 1.5π)`, the
  only two arc producers, both strictly below `2π`.
- **There is no DXF reader in this repository at all.**
  `packages/jet_cad_2d/lib/src/codec/` holds `json_codec.dart` and
  `schema_version.dart` and nothing else.

**It is also nearly invisible.** The seam notch is about `half · √(2/R)` device
pixels wide at the flattening tolerance — at `half` ≈ 2 px and R ≈ 40 px that
is **0.45 px**, under the comparison's one-pixel dilation. A 2π arc through the
painter at a realistic size measured **0 stray and 0 uncovered**: the divergence
was there and the comparison could not see it. The characterisation fixture
therefore uses a 36-device-pixel radius stroked 25 device pixels wide, where it
can: **canvas 5,688 ink px, vertices 5,710, 0 stray and 6 uncovered** — one
radial notch at three o'clock, the start angle, and nothing anywhere else on the
ring.

**What would have to change for it to matter:** a DXF reader that maps an `ARC`
with equal start and end angles onto a `2π` sweep, or a corpus change that
widens the sweep range. When `closed` learns about a full sweep, that test goes
red and the right fix is to change its two expectations to zero, not to delete
the fixture.

---

## What has no coverage, and where the tests are narrower than they read

Recorded here because a results note that reports only what went well is not a
result.

**The seam join and the point-shape fix have no coverage through any frame
path.** Not the goldens, not `draft_painter_*`. They are pinned against the
`DrawSink` interface only.

- `draft_painter.dart:425-429` routes point, line and polyline unconditionally
  through `_emitScreenSpace`, whose residual is a bare `Transform2.translation`
  (`:498`). **A rotated residual therefore never reaches `point`** through the
  painter, and `_emit`'s `case EntityKind.point` (`:566`) is dead code.
- The seam is **unobservable through the painter, not unreachable** — the
  painter does reach `closed: true` via `sink.circle` (`:588`, `:619`). What is
  missing is a frame-path fixture that would *show* a broken seam, not a code
  path that can never run.

**Two `_emitJoin` branches are unreachable dead code, not layered guards.**
`cosHalf <= 0` and `mlen == 0` cannot fire given the `dot < kMinMiterCosine`
bail at ~151°; each was disabled alone with all 46 tests staying green. The
mutation log records them as unreachable rather than counting them as covered.
An unreachable branch does not want a test; it wants removal or a comment
saying why it stays. **Left in place, recorded, for whoever touches the join
next.**

**A recurring shape this plan hit four times: the assertion is narrower than
the mutant's name.** It is worth naming because it will recur.

- Task 2: `_lastFlushDisposed = true` written unconditionally beside the
  dispose call — deleting `vertices.dispose()` left all 26 tests green.
- Task 4: every join fixture turned left, so `s = cross > 0 ? -half : half`
  collapsed to `s = -half` with all 198 tests green.
- Task 9: reversing the `observe` loop left all 11 tests green — nothing pinned
  triangle order *within one buffer*, the one property the sink is built around.
- Task 11: the full-sweep-ARC characterisation bypassed `expectSinksAgree`'s
  ink floors, so making `VerticesDrawSink.arc` return early — the vertices side
  emitting **nothing at all** — left all five tests passing.

All four were found by mutation and all four are closed. They are listed
together because reading the tests would not have found any of them.

**`lib/src/draft_canvas.dart:192`'s `devicePixelRatio` plumbing is referenced by
no test file.** Nothing in this plan should be read as covering it.

---

## Reproducibility

### Desktop — reproducible from what is committed

The `flutter drive` invocations above run against the committed harness. The one
exception is the peak-buffer reading: `printBackend` does not print
`debugCapacityVertices`, so Task 12 added one temporary line to
`apps/dev_harness_2d/integration_test/frame_timing_test.dart` for the duration
of the sweep and reverted it. The `debugCapacityVertices=… bytes=…` lines in
Task 12's transcripts are real printed output, not arithmetic done afterwards.
Reproducing the memory table means re-adding that line.

### Web — NOT reproducible from what is committed

**Say this plainly: the twelve web readings cannot be re-taken from the
committed path on this machine.** They ran under:

- a `main.dart` carrying a temporary `runZoned` + `dart:html` localStorage
  capture that is **in neither commit** (a `ZoneSpecification.print` that both
  forwards to the real `print()` and appends to a `StringBuffer`, written once
  to `window.localStorage['r2Result']` after `runR2Rig` completed), and
- two `/tmp` scripts that were never committed.

Running the shipped `RUN_R2` mode exactly as its doc comment describes produces
**no output whatsoever** here, because `flutter run -d chrome --profile` never
links a debug service on this machine. That gap is the reason the workaround
existed. A published row nobody can re-take is a number nobody can check, so the
artifacts are committed beside this note:

`docs/superpowers/notes/2026-08-21-plan-3d-web-raw/`

| file | what it is |
|---|---|
| `web_rows.log` | **ten of the twelve run blocks**, as the app printed them and the poller retrieved them. The other two — 10,000-entity run 1 on each backend — are appended to the same file under `RECOVERED BLOCKS`, **reconstructed from the Task 13 report rather than captured**, with the three fields that could not be recovered marked `<not recovered>`. See the note below the table. |
| `run_web_r2.sh` | the driver: launches `flutter run -d chrome --profile`, waits for the CLI banner, finds Chrome's `--remote-debugging-port` from `ps aux`, calls the poller, cleans up |
| `cdp_poll_generic.py` | the retrieval: one `Runtime.evaluate("window.localStorage.getItem('r2Result')")` over a CDP websocket, polled every 2 s, `returnByValue`, no scraping and no fragment assembly |
| `main.dart.pre-diag` | the harness `main.dart` **as backed up with `cp` before the run-time edits** — it carries that session's diagnostic `print()` lines but **not** the `runZoned`/localStorage capture |

**Two of the twelve web runs were never captured to `web_rows.log`.** They are
10,000-entity run 1 on each backend, and they survive only in the Task 13
report, whose transcripts are reflowed rather than verbatim. They are now
appended to `web_rows.log` as clearly-labelled reconstructions so that no
published figure rests on a file that will be deleted with this worktree — but
a reconstruction is not a capture and the file says so at both ends. The one
published figure this affects is the **upper endpoint of the web 10,000 canvas
build interval, `[117.10, 122.20]`**: `122.20` is a reconstructed number. It
does not move the median (117.80); it does set the published spread of 5.10 ms.
Also note that the run ordinals in `web_rows.log`'s ten captured headers were
typed by the operator and **do not line up with the report's run numbering** —
the file's own header explains which is which, and nothing published depends on
the ordering, only on the set of three.

**The exact `main.dart` that ran is not among the artifacts either.**
`main.dart.pre-diag` is the restore point, not the run-time file. The
`runZoned` capture survives only as the code excerpt in the Task 13 report, which is archived with this plan's
ledger. Anyone reproducing these rows must re-write that wrapper from the
excerpt.

**Two further caveats on the absolute web figures.** Every measured run
executed inside that `runZoned` wrapper, which the shipped code does not have —
it only buffers `print()` output and forwards it unchanged, and it wrapped both
backends identically, so the ratios hold, but the absolute numbers were taken
under code that is not the committed code. And
`localStorage['r2Result']` was never cleared at startup, so a stale prior-run
read was possible in principle; it was not observed — every block's `backend=`
and `R2 (N)` matched its own run's defines.

**The transcripts in the Task 13 report are reflowed, not byte-verbatim.**
Blocks were condensed for the table format and the identical
`text:`/`paragraphs:` lines were dropped from the per-run sweep tables. The raw
captures in `web_rows.log` are the unreflowed record.

---

## What 3d owes 3e and 3f

**3e (fills)** inherits:

- A triangle buffer that is **already appended to in draw order**, and a flush
  that already happens before anything unbatchable. The
  `fill.handle < boundary.handle` question is unchanged and still 3e's to
  answer; 3d only makes the guarantee it relies on stronger.
- **Permitted divergence 5 goes live the moment 3e adds fills.** Overlapping
  translucent strokes double-blend on a triangle soup where a stroked path
  unions its coverage. It is inert today because the corpus is opaque. It has
  no test, and the moment alpha < 255 appears it needs one.

**3f (caches and tiles)** inherits:

- `_flushBeforeUnbatchable` as the shape the picture-cache decision extends. A
  picture cache that records into a `Picture` interacts with a sink that batches
  across residuals; 3f must decide whether a cached picture flushes the buffer
  at its boundary.
- **No crossover number**, because criterion 6 did not tie. The design's
  fallback anticipated handing 3f the entity count where the backends converge;
  there is none up to 500,000 and the margin is still widening at that size.
- **96.00 MiB of pinned vertex buffer at 500,000 entities.** A tile or cache
  scheme changes how much geometry is live at once, which is exactly the
  arithmetic that number comes from.
- **The ratio is driven by canvas calls, not entities** (2.13× leaves and 3.03×
  dashSpans for a 10× entity rise). Any cache that changes the call count
  changes the whole comparison.

**Whoever chooses round joins** inherits one branch, in one method, with a
golden on each backend to show the difference.

**Whoever writes the next plan** inherits four open items from this one:

1. **The `CLAUDE.md` allocation amendment**, undecided (criterion 7).
2. **A frame-path fixture for the seam and the point shape.** Both are pinned
   against the `DrawSink` interface only; `DraftPainter` cannot exercise a
   rotated point at all today.
3. **The 2π-sweep `ARC` seam**, characterised and unfixed, safe only because no
   DXF reader exists. It becomes a real defect the day one does.
4. **The R4a/R4b control**, plausible but not demonstrated — half an hour of
   device time with the invariant fields in the grep pattern would close it.
