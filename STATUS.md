# jet-cad — project status

**Last updated:** 2026-08-30
**Verified against:** `main` at `cd5bc98` — the merge commit for **Plan A of the
GPU-resident render backend**, the first of that spec's seven plans. Plan A ran
on `plan-a/gpu-seam-and-strokes`, cut from `spike/flutter-gpu-backend`, nine
tasks at `81529f0..cdf2a23`, merged `--no-ff` and the branch deleted. **Its last
*code* commit is `d5c85f4`**; everything after it is documentation and citation
repair. Before it, Plan 3i ran directly on `main` at
`468e310..dbc31e8` and is DONE. The tree is clean apart from the files the traps
below say never to commit, plus untracked `.DS_Store` files a device run left
behind — the repo has no `.gitignore` entry for them. Every suite count below
was produced by running that suite on the merged tree on 2026-08-30, not by
reading a report — with the one exception the table marks as not re-run.

**Plan B (joins and hairlines), the second of the GPU-resident render
backend's seven plans, is DONE — eleven tasks on
`plan-b/joins-and-hairlines` (cut from `main` at `5c94e11`, one commit after
Plan A's merge), code range `5c94e11..72b938a`, not merged.** Exit gate:
**10 of 11 — criterion 11 is UNMET**, in those words: the device run
happened but no human looked at the running window, and Plan 3h's session
already proved that instrument catches what the other two (mutation
testing, differential testing) do not. The device run also measured one
real MISS (rebuild, 79.6 ms against 16.67 ms, cause a hypothesis, not
confirmed) inside that otherwise-passing gate, while the buffer figure
PASSES at 4.99 MB against 8 MB. See
[Plan B](#plan-b--joins-and-hairlines) and
[Resume here](#resume-here). `packages/jet_cad` is untouched, as every task
in this plan was.

---

## TL;DR — where you left off

**Plan A of the GPU-resident render backend is DONE and merged, nine tasks,
`81529f0..cdf2a23`, merge `cd5bc98`.** A third `RenderBackend.residentGpu` draws
a document's **stroked polylines** from GPU-resident geometry in **one instanced
draw call**, camera as a uniform, falling back to `VerticesDrawSink` where
Flutter GPU is absent. The document is walked **once per rebuild**, not per
frame, into one `Float32List` uploaded once; draw order survives because the
buffer is in walk order and there is exactly one call. Every GPU import is
confined to `lib/src/gpu/gpu_facade.dart`, which re-exports `flutter_scene`'s
conditional shim — so the package still compiles for web even though
`flutter_gpu` cannot.

**Plan A ships strokes only.** Joins, caps, `point()` and `_coveredArgb` are
Plan B; dashes C; fills D; the text split E; rebuild triggers and the watermark
F; web G. The collector **counts** every op it does not draw (`skippedOps`)
rather than dropping it silently, so a corpus needing a later plan shows as a
number, not a missing picture.

**A device run happened** (macOS profile, three interleaved repeats, 27 phase
reports) and settled three things code review could not: the **80-byte** uniform
block against a reflection reporting 128, the **device-pixel-ratio fold**, and
the **device half-width**. The last two were real bugs found *after* the spike's
entire measurement campaign missed them — because that campaign measured
timings and never looked at the picture.

**The plan's own sample code carried four real defects**, each found by running
it rather than reading it: a `List<double>` grown by assigning `.length` (throws
for a non-nullable element type), a shader attribute declared but never read
(fails `impellerc` reflection), a library asset path missing its
`packages/<name>/` prefix, and a frame matrix missing its `dpr` factor. Written
by the same author as the plan, caught by nine independent reviews.

Ledger, nine task reports and all twenty-six rulings:
[docs/superpowers/ledgers/2026-08-29-gpu-backend-plan-a-seam-and-strokes/](docs/superpowers/ledgers/2026-08-29-gpu-backend-plan-a-seam-and-strokes/).
Spec: [2026-08-29-gpu-resident-render-backend-design.md](docs/superpowers/specs/2026-08-29-gpu-resident-render-backend-design.md)
(revision 4). Plan: [2026-08-29-gpu-backend-plan-a-seam-and-strokes.md](docs/superpowers/plans/2026-08-29-gpu-backend-plan-a-seam-and-strokes.md).

---

## Plan B — joins and hairlines

**Plan B taught the GPU-resident backend joins, seam joins, `point()` as its
own kind, circle/arc flattening and the `_coveredArgb` hairline alpha fade —
the second of the design spec's seven plans, on `plan-b/joins-and-hairlines`
(cut from `main` at `5c94e11`), eleven tasks, code at `5c94e11..72b938a`, not
merged.** Spec:
[2026-08-29-gpu-resident-render-backend-design.md](docs/superpowers/specs/2026-08-29-gpu-resident-render-backend-design.md)
(the same revision-4 spec Plan A used). Plan:
[2026-08-30-gpu-backend-plan-b-joins-and-hairlines.md](docs/superpowers/plans/2026-08-30-gpu-backend-plan-b-joins-and-hairlines.md).
Results:
[2026-08-30-plan-b-results.md](docs/superpowers/notes/2026-08-30-plan-b-results.md).
Mutation log:
[plan-b-mutation-log.md](docs/superpowers/notes/plan-b-mutation-log.md) —
fifteen named mutants, eighteen firings, sixteen dead, one proven equivalent
(M-B3's guard-only arm), one declared structural survivor (M-B1', the pixel
instrument cannot see a colour-only fade).

**Exit gate: 10 of 11. Criterion 11 is UNMET, in those words**: the device
run happened (macOS profile, three interleaved repeats, 27 phase reports,
Low Power Mode confirmed OFF) but no human looked at the running window —
corners filled, circle not notched at its start angle, dot square, nothing
thickening under zoom. Plan 3h's session made looking at the window this
project's third instrument, alongside mutation and differential testing, and
it was the only one of the three that caught any of that session's four
defects; a passing gate on the other ten criteria is not evidence for this
one. Criteria 1 through 10 all pass — pixel differential, emission order
(open run, closed run, flattened circle), the seam join's load-bearing test,
half-width invariance, the three-way hairline fade, `point()`'s square shape,
`skippedOps`'s exact accounting, the 8 MB buffer budget, the shader bundle's
decoded OpenGL ES 100 stage, and all ten pre-committed mutants (exceeded —
fifteen total fired).

**Two results outside the eleven-criterion gate, reported as they measured,
not smoothed toward either verdict.** The buffer **PASSES at 4.99 MB against
≤ 8 MB** (109,068 instances, 12 floats each, up from Plan A's 2.06 MB at
59,875 strokes-only segments — joins roughly doubled the instance count and
circles/arcs/points are now collected where Plan A skipped them). The
**rebuild MISSES**: `walk 5.7 ms, total 79.6 ms` against the spec's
≤ 16.67 ms budget. The likely cause is cold pipeline-creation cost — Plan
A's own design note records native rebuild at 82.3 ms first run, 6.5 ms
warm, and 79.6 ms sits almost exactly on that first-run shape — **but only
one rebuild happened in this session, so no warm figure exists, and the
cause is recorded as a hypothesis, scored as a miss, not excused.** The walk
itself also reads 5.7 ms against Plan A's 14.7 ms on a nominally same-size
corpus while emitting *more* instances — a 2.6x divergence in the wrong
direction, recorded as unexplained. Arm C's gesture timings pass with
margin despite joins landing as predicted (zoom build median 0.51 ms
against ≤ 1.2, zoom raster median 0.62 ms against ≤ 2.0, zoom raster p95s
all under 3.0) — antialiasing has not landed (Ruling B3), which the spec's
own budget discussion named as the other consumer of that margin.

**Ruling B2's and B3's consequences, stated rather than smoothed over.**
Caps are butt caps and Plan B emits no cap geometry — the spec's criterion 8
corpus requirement naming "caps" is satisfied **vacuously**. The resident
arm is **hard-edged**; the spec's own budget discussion assumed antialiasing
would be consuming raster headroom by now, and it is not, which is part of
why the gesture-timing margin held.

**What was not measured, at minimum**: no warm rebuild, no web run, no
text, no fills, no dashes, no per-channel colour comparison in the pixel
differential (that instrument is coverage-only; colour is gated separately
at the record level), and the pixel instrument's own structural blind spot
— it cannot see geometry added inside a footprint already inked by
something else, proven by M-B7 and M-B15 (a wrong-side join wedge and no
join at all) producing the *identical* differential reading. Full account:
[2026-08-30-plan-b-results.md](docs/superpowers/notes/2026-08-30-plan-b-results.md).

**A harness defect this device run itself exposed, fixed in the same
task**: the GSPIKE note printed by `apps/dev_harness_2d/lib/gpu_arm.dart`
still claimed arm C "draws only strokes... No joins, no caps, no
antialiasing" — false after Plan B, which shipped joins, points, circles and
arcs. A transcript that misdescribes what it measured is exactly this
repo's own standing failure mode; corrected at `72b938a`, keeping what
stayed true (butt caps only, no antialiasing, dash spans baked at the
collection camera).

---

**Plan 3i (the zoom frame) is DONE, fourteen tasks, worked directly on `main`
at `468e310..dbc31e8`, nothing in flight. Its exit gate is 9 of 11 — criteria
8 and 9 MISS, and neither threshold was moved.** Criterion 8 reads a median
ratio of **2.328 against a gate of 2.4** at n=9 interleaved, which is the
answer to Plan 3h's open question: 2.35 was real, not noise — and the gate
sits *inside* the measurement's own noise, so no sample size settles it.
Criterion 9 **regresses**: `tile pan` p95 reads 20.90 / 21.75 / 23.70 ms
against 3h's 19.86 / 15.99 / 13.43, non-overlapping sets, 1.35x on means, with
every tile counter byte-identical to 3h's. It is measured and **not
diagnosed**. **The spec declined level-of-detail geometry** — see
[Plan 3i](#plan-3i--done-14-of-14-exit-gate-9-of-11). Thirty-nine mutants
fired, thirty-seven dead, two survivors (M8 declared, M24 provable).

Results note:
[docs/superpowers/notes/2026-08-26-plan-3i-results.md](docs/superpowers/notes/2026-08-26-plan-3i-results.md).
Mutation log:
[docs/superpowers/notes/plan-3i-mutation-log.md](docs/superpowers/notes/plan-3i-mutation-log.md) —
it opens with a summary table naming every mutant, its verdict and its gate.

**Plan 3h (the fallback walk and its instrument) is done, worked directly on
`main`, nothing in flight — and its headline criterion MISSES.** Criterion 3,
the `tile pan` p95 ratio (M4 arm over narrowed, same session), reads **2.35x
against a gate of ≥ 2.4x**. Criterion 6 also **MISSES** (`tile hold` p95,
2.77 ms against 2.5 ms on one of three runs). Neither is adjusted or re-run to
chase its threshold. At n=3 per arm the measurement **cannot settle** whether
2.35 is real or noise — nine pairwise ratios span 1.82 to 2.84, straddling 2.4
in the middle — and the **2.4 gate was itself mis-derived** from a
cross-session numerator, the exact comparison a ratio measured in one session
exists to prevent. The **mean**, offered as evidence rather than a gate, shows
a real, large, non-overlapping effect (≈16.6 ms saved per fallback frame).
Six mutants, all re-fired 2026-08-26 against a widened fixture: four killed
in the widget suite (M1, M3, M4 and M5 — M5 found by a reviewer, not
planned), M2 survives the **pixel sweep** as the plan's pre-committed gap
(→ H5) while dying at suite level on the pad's value, and M6 — clip the
padded strip rather than the uncovered union, found by the whole-branch
review — survives outright (→ H6). **M4, which the plan itself said "has no
unit witness," dies doubly**, in the widget suite and on the device ratio;
that correction is this task's most important line. The widening itself was a
finding: `canvas.translate(strip.left, strip.top)` had **no witness** until
it landed, and the two swept offsets that exercise that line were both
vacuous. See
[Plan 3h](#plan-3h--the-fallback-walk-and-its-instrument) and
[Resume here](#resume-here).

**Plan 3g (the rasterised tile cache) is done and pushed, sixteen tasks, worked
directly on `main` at `477d4c5..2367a20`, nothing in flight.** **Its exit gate
is 11 of 13.** Criterion 10 passes at **1.58 ms against 4.00** — 26× the same
runs' untiled 41.09 ms. **Criterion 11 misses by 2.1× and the threshold was not
moved**; its cause is isolated to the live fallback drawing the uncovered strip,
and it is Plan 3h's design question. **Gap G7 closed on 2026-08-24**, one commit
past the ledger archive. See [Plan 3g](#plan-3g--the-definitiontile-picture-cache)
and [Resume here](#resume-here).

**Plan 3f.1 (hardening before the picture cache) is done, eight tasks, worked
directly on `main` at `c078677..b1e9ec1`, nothing in flight.** **Its exit gate
is 16 of 17 — the one miss is the allocation-meter probe's own pre-committed
stop clause firing, recorded as the plan working, not failing.** See
[Plan 3f.1](#plan-3f1--hardening-before-the-picture-cache) and
[Resume here](#resume-here).

Results note:
[docs/superpowers/notes/2026-08-23-plan-3f1-results.md](docs/superpowers/notes/2026-08-23-plan-3f1-results.md).
Mutation log:
[docs/superpowers/notes/plan-3f1-mutation-log.md](docs/superpowers/notes/plan-3f1-mutation-log.md) —
seventeen named mutants, all seventeen killed, no survivors.

**Plan 3f (text wiring and level of detail) is done, nine tasks, worked
directly on `main`, nothing in flight.** **Its exit gate is 11 of 13 — and the
two that miss are recorded as missing, not tuned away.** See
[Plan 3f](#plan-3f--text-wiring-and-level-of-detail) and
[Resume here](#resume-here).

Results note:
[docs/superpowers/notes/2026-08-22-plan-3f-results.md](docs/superpowers/notes/2026-08-22-plan-3f-results.md).
Mutation log:
[docs/superpowers/notes/plan-3f-mutation-log.md](docs/superpowers/notes/plan-3f-mutation-log.md) —
fifteen named mutants, 14 killed, 1 restatement, 1 mutation recorded as
unmeasurable with its reason.

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

Nothing is in flight. Plan 3f had no worktree either — the human gave explicit
consent to work `main` directly, as for 3e — so **its ledger must be archived
onto `main` before the `.superpowers/sdd/` directory is cleared**, the same
ordering 3e's archive records as the lesson. The `spike/vertices-sink` branch
and its worktree are gone; the ledger is archived at
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

| Suite | State (on `main` at `dbc31e8`, run 2026-08-29, not read off a report) |
|---|---|
| `packages/jet_cad_2d` — engine | **797 tests, all pass**, analyze/format clean |
| `packages/jet_cad_2d_flutter` — widgets | **413 tests pass, 1 skipped**, analyze/format clean |
| `flutter test --tags golden` | **35 pass** as of `122b6e3`; **NOT re-run on 2026-08-29** |
| `apps/dev_harness_2d` | **72 tests, all pass** (`flutter test --concurrency=1`), analyze/format clean |
| `benchmark/query_throughput.dart` | **NOT RE-RUN on 2026-08-25.** Last read 2026-08-23: **GATE: PASS**, every gated row under its threshold, `snap at dirty threshold` included (p50 0.552 ms against 1.0 ms). That row is Plan 2's carried failure and it is a **timing on a shared machine**: recorded as passing that day, not declared fixed |

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
render cost is the canvas call, not the drawn leaf — on the canvas backend.**
**That qualification is not decoration.** The 2026-08-23 spike below moves a
vertices frame from 20 to 633 `drawVertices` calls at a fixed triangle count
and raster does not respond. Both findings hold: a `drawPath` call carries a
tessellation into its `Entity`, a `drawVertices` call carries triangles that
are already built, and the cost per call is a function of what the call
contains. Every per-leaf µs figure
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
vertex buffer pinned for the widget's life at 500,000 entities (**a Plan 3d
figure; the tree read 192.00 MiB on 2026-08-25, and not as a function of entity
count** — see
[the high-water note](docs/superpowers/notes/2026-08-25-vertex-buffer-high-water.md)); the web rows are
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
| `/Users/ahmeturel/Projects/oss/jet-cad` | `plan-b/joins-and-hairlines` | clean apart from the untracked/traps this file already names; DONE, exit gate 10 of 11, **not merged** — criterion 11's human window check is still owed |

**No separate worktree — the primary checkout itself is on
`plan-b/joins-and-hairlines`, at `72b938a`.** `main` is one branch back, at
`5c94e11`, and carries Plans 1/2/3a/3b/**3c**/**3d**/**3e**/3f/3g/3h/3i and
**GPU Plan A** merged, plus Plan B's own spec and plan documents (written
directly onto `main` before the branch was cut, the pattern this file's
other spec-writing commits also use). **Nothing is task-in-flight** — every
one of Plan B's eleven tasks is finished and reviewed — but the branch
itself is unmerged pending the human window check criterion 11 names.

`plan-a/gpu-seam-and-strokes` was merged with `--no-ff` and deleted. **Three
spike branches survive and are now all contained in `main`:**
`spike/flutter-gpu-backend` (Plan A's parent — its throwaway arm was deleted by
Plan A's own Task 9), `spike/picture-cache-price` and `spike/widget-per-entity`.
They were left rather than deleted because deleting someone else's spike branch
is not a merge's business; delete them when you no longer want the label.

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

**A human must still look at the window.** That is the top of this list on
purpose: Plan B's exit gate is 10 of 11 and the one UNMET criterion is
exactly this — the device run happened (macOS profile, three interleaved
repeats, Low Power Mode confirmed OFF) but nobody has looked at what it
actually drew. Look for: filled corners, a circle **not** notched at its
start angle, a square dot, and nothing thickening as you zoom in. Plan 3h's
session proved this is not a formality — it was the only one of this
project's three instruments (mutation testing, differential testing,
looking at the window) that caught any of that session's four defects.
Command:

```
cd apps/dev_harness_2d
flutter run -d macos --profile --dart-define=RUN_GPU_SPIKE=true \
  --dart-define=ENTITIES=10000 --dart-define=SPIKE_DEFS=20 \
  --dart-define=SPIKE_INSTANCES=150 --dart-define=SPIKE_FRAMES=30 \
  --dart-define=SPIKE_REPEATS=3
```

**Plan B (joins and hairlines) is done, eleven tasks, on
`plan-b/joins-and-hairlines` at `5c94e11..72b938a`, not merged; nothing is
task-in-flight.** Full account:
[Plan B](#plan-b--joins-and-hairlines) and
[2026-08-30-plan-b-results.md](docs/superpowers/notes/2026-08-30-plan-b-results.md).
Once a human has looked at the window and the merge decision is made, the
next unit of work is **Plan C — dashes**, per the roadmap line Plan A and
Plan B both cite: *"Plan A ships strokes only. Joins, caps, `point()` and
`_coveredArgb` are Plan B; dashes C; fills D; the text split E; rebuild
triggers and the watermark F; web G."*

**One thing Plan A left for whoever writes Plan C, carried forward because
Plan B did not touch it:** `DraftCanvas` still renders `residentGpu` as
`vertices` — the widget paint path is deliberately not wired, since it
needs the rebuild triggers Plan F builds. The enum value's own doc says so.
The dev harness arm remains the only runtime consumer of the resident
backend. **The GPU-arm-inlined-in-`main.dart` item Plan A also left is now
closed**: Plan B's first commit (`0615eb0`) moved it into
`apps/dev_harness_2d/lib/gpu_arm.dart`, a standalone file beside the widget
spike's own sibling files, exactly as the final Plan A review asked.

Fifteen findings were graded Minor during Plan A and triaged by the final
whole-branch review: twelve left, three upgraded to Important and fixed. The
survivors are listed in the ledger's deferred lines.

---

**Plan 3h (the fallback walk and its instrument) is done, worked directly on
`main` at `f642202..122b6e3`, eight tasks (the eighth split into 8a and 8b),
nothing in flight — and its headline criterion MISSES.** Criterion 3's ratio
reads **2.35x against a gate of ≥ 2.4x**; criterion 6 misses too. Both are
recorded as misses, not adjusted or re-run to chase their thresholds. At n=3
per arm the measurement cannot settle whether 2.35 is real or noise, the 2.4
gate was itself mis-derived across sessions, and the mean shows the effect is
real and large but is offered as evidence, not a gate. Read the full account,
including where each of the six mutants died and gaps H1–H7, at
[Plan 3h](#plan-3h--the-fallback-walk-and-its-instrument).

~~**A resumer's ledger chore:** Plan 3h's `.superpowers/sdd/` material is not
yet archived.~~ **Done**, at
[docs/superpowers/ledgers/2026-08-25-jet-cad-2d-plan-3h-pan-frame/](docs/superpowers/ledgers/2026-08-25-jet-cad-2d-plan-3h-pan-frame/),
with 3g's and 3f.1's beside it. The git-ignored workspace is gone. **No ledger
chore is outstanding.** The ordering is still the lesson every archive note in
this file records: archive onto the branch before the workspace is deleted,
never after.

**Since Plan 3h, four findings came out of running the harness by hand** —
two fixed (`fc05076`, `967fa3b`), two measured and deliberately left for 3i.
Read them before writing 3i's spec:
[After Plan 3h](#after-plan-3h--what-the-window-showed-2026-08-26).

**Plan 3i is DONE on `main`, all fourteen tasks, exit gate 9 of 11.** See
[Plan 3i](#plan-3i--done-14-of-14-exit-gate-9-of-11) immediately below. **Read
that before touching the tile cache**: the spec **declined** level-of-detail
geometry, so the numbered paragraph further down, written before 3i's spec
existed, does not describe what 3i did — the correction is at the head of the
3i section and G3 is on the open-gap list with the condition that reopens it.

**A resumer's ledger chore: none outstanding.** Plan 3i's `.superpowers/sdd/`
material is archived at
[docs/superpowers/ledgers/2026-08-26-jet-cad-2d-plan-3i-zoom-frame/](docs/superpowers/ledgers/2026-08-26-jet-cad-2d-plan-3i-zoom-frame/),
with the raw `KEEP_*.log` measurement logs behind every published figure
beside it — including `KEEP_c8_DEGENERATE_run.log`, the run that was taken,
read and discarded. **The ordering is the lesson: archive onto the branch
before the workspace is deleted, never after.**

**Next is Plan 3j** — the 192 MiB vertex buffer, below. Plan 3h did not choose
an order between 3i and 3j and each is independent of the other; **the human
chose 3i on 2026-08-26**, after the zoom measurements below landed in its
scope. **3i leaves two things a later plan should pick up**: criterion 9's
regression, measured and not diagnosed, and the spec's §5 memory pricing,
untested because the reference viewport is unreachable on this machine
(Ruling 20).

---

## Plan 3i — done, 14 of 14, exit gate 9 of 11

**Spec:** [2026-08-26-jet-cad-2d-plan-3i-zoom-frame-design.md](docs/superpowers/specs/2026-08-26-jet-cad-2d-plan-3i-zoom-frame-design.md),
written 2026-08-26 and revised twice against five external reviews.
**Plan:** [2026-08-26-jet-cad-2d-plan-3i-zoom-frame.md](docs/superpowers/plans/2026-08-26-jet-cad-2d-plan-3i-zoom-frame.md).
**Results:** [2026-08-26-plan-3i-results.md](docs/superpowers/notes/2026-08-26-plan-3i-results.md).
**Mutation log:** [plan-3i-mutation-log.md](docs/superpowers/notes/plan-3i-mutation-log.md).
**Ledger:** [2026-08-26-jet-cad-2d-plan-3i-zoom-frame/](docs/superpowers/ledgers/2026-08-26-jet-cad-2d-plan-3i-zoom-frame/), **21 numbered rulings**.
**Range:** `468e310..dbc31e8`, directly on `main`, no
worktree, on the human's standing consent — the arrangement of 3e through 3h.
Executed with subagent-driven development: a fresh implementer per task, an
independent reviewer after each, and the controller running the full gate
itself after every task.

**The exit gate is 9 of 11, and the two misses stand.**

- **Criterion 8 MISSES**: the median ratio is **2.328 against a gate of 2.4**,
  at n=9 interleaved, 500,000 entities, 800x600. Mean 2.407, range 1.693 to
  3.088, four of nine pairs at or above 2.4. **This answers Plan 3h's open
  question**: 2.35 was real, not noise — n=9 puts the median in essentially
  the same place — but the distribution straddles the gate, so **no sample
  size settles "2.35 or 2.4"; the gate sits inside the measurement's own
  noise.** The `tile hold` control drifted +9.1% toward arm B, an order of
  magnitude below the effect; 3h's blocked ordering had produced an
  order-of-magnitude drift on the same inert phase.
- **Criterion 9 MISSES**: `tile pan` p95 reads 20.90 / 21.75 / 23.70 ms
  against 3h's 19.86 / 15.99 / 13.43. **The sets do not overlap**; 1.35x on
  means. `tile hold` did not regress, and every counter (`bakes=14 blits=1582
  liveDraws=10 liveTiles=26 tileBytes=27262976`) matches 3h's exactly — **the
  same work, at a higher cost per expensive frame.** Two candidates are named
  and not chosen between: the rest-gate bookkeeping every frame now performs,
  and the `_lastChangeWasPan` frame the fix wave added, which converts the
  frame a pan stops on from a composite blit into a live walk. **Measured, not
  diagnosed.**

**Criterion 3 passes as `settleFrames == 2`, not `== 1`** — Ruling 15 below;
that is a spec contradiction resolved, not a threshold moved.

**G3 was NOT this plan's subject, and the spec says why. The spec DECLINED
level-of-detail geometry.** The human chose a map-application target — *the
gesture stays smooth even if what it shows is stale, and the drawing snaps to
full resolution when the gesture ends* — and under that target a correct frame
during a pinch is never drawn, so the 32.06 ms it costs stops blocking.
**G3 stays open, and it becomes necessary the day the target changes to
correct geometry while the fingers are still moving.** Any older text in this
file describing 3i as *delivering* level-of-detail geometry predates 3i's spec
and is wrong.

**What landed.** A tiled frame now has two regimes. A **moving** frame — one
whose quantised camera changed, or that has not yet seen two unchanged frames
— draws the carry-over composite and nothing else: no bake, and no live walk.
A **resting** frame walks the visible region **one tile row at a time** into a
band image and cuts tiles out of it, one walk per band instead of one per
tile. Bands rather than one image because the union of visible keys has the
tile set's own area — `visibleKeys` yields a full rectangle — so a single
source plus the tiles sliced from it peaks at exactly `kTileCacheBytes` with
no headroom.

**Suites at `dbc31e8`,** each run rather than read from a report: **797**
engine, **413** widget with 1 pre-existing skip, **72** harness
(`flutter test --concurrency=1`). Analyze and format clean in all three.

**Thirty-nine mutants fired, thirty-seven dead, two survivors.** The mutation
log opens with a summary table naming every one, its verdict and its gate. Of
the spec's own eleven, **ten died and M8 is the declared survivor** — the exit
gate's mutation clause met exactly; the other twenty-eight came from
reviewers, fix waves and the whole-branch review. **M24 survived and provably
must** --
the ceiling property it targets is held by the rest bake's up-front pricing,
not by the recency stamp it deletes, so the gating arm cannot be built; the
derivation is in the log, with the note that relaxing the pricing to count only
the *missing* tiles would make the stamp load-bearing and the arm buildable. **Mutant numbering is per-plan:
`M4` and `M5` name different mutations in Plan 3h's log and Plan 3i's, so any
citation must name the plan.** **M8 survived as declared** — with integral source
rectangles a bilinear and a nearest sample read the same texels, and it was
written down as a survivor before it was fired, the way Plan 3h recorded its
own M6. **M11 turned out to be unreachable by pixels**: the rebase origin
cancels in `float64` before anything reaches `float32`, about 1e-13 device
pixels, so its gate of record is Task 6's direct origin-argument test rather
than a differential arm.

**Two defects were found in this plan's own instruments, both of the
vacuous-gate class this repository exists to catch, and both found by firing a
mutant and noticing it did not die.**

1. **`captureLive` was returning the tiled image byte for byte.**
   `shouldRepaint` is unconditionally false, so the "live" capture was the
   tiled one. Six mutants read zero differing pixels until a distinct
   `ValueKey` forced a separate element. A differential instrument was
   comparing a frame with itself.
2. **`pumpTiled`'s canvas was never the viewport it claimed.** A `SizedBox`
   under `pumpWidget`'s tight constraints is inert, so every test built on that
   helper since Task 2 ran at 800x600 logical rather than 400x300 — 475 tiles,
   not 130 — and the fixture left 38% of each frame blank. No assertion value
   moved when it was fixed; several comments became true.

**The whole-branch review ran before the device runs, and that ordering is
the single most valuable thing about this plan's record.** Two independent
lenses — production correctness, and instrument honesty — surfaced **two
production defects, one Blocking measurement defect that then recurred one
frame away after its own fix, and four instruments that could not fail.** Every
one of them would have become a retraction had the numbers been taken first.

1. **A pan straight after a zoom drew only the stale composite, for the whole
   pan.** `panBy` copies the matrix's `a,b,c,d` bit-identically, so
   `matchesScale` held, `_gridFor` never retired, and the composite minted by
   the zoom survived the pan while `_restGateSteps` sat at 0 — composite
   blitted, early return, no tile blit, no live walk. Pre-3i the same frame
   paid a full-viewport live walk: expensive, but correct pixels. A regression
   against D8, reachable directly from a macOS trackpad.
2. **One missing tile made the rest bake walk *every* band and discard all but
   the ones it needed** — a whole-viewport walk on the ordinary edit path,
   every frame of a drag.
3. **The settle timing named the wrong frame, twice.** `FrameTiming` is
   delivered after a frame rasterises; `pumpFrame` returns before it. First the
   callback was re-registered per idle frame, so frame *i*'s bucket held frame
   *i-1*'s timing. That was fixed — and the same defect returned one frame away,
   because the *caller* pumped a camera-reset frame before the log was armed.
   The published "frame that covered the viewport" was the in-between composite
   blit that draws nothing. **The function's own comment had the mechanism
   right; the defect moved to its caller.**
4. **Four instruments could not fail**: criterion 7's headline ceiling assertion
   ran with 43x headroom; `a` and `d` in `sameQuantisedCamera` were each
   individually deletable (every fixture tied `d` to `-a`); the skipped-band
   guard ran at a cap that never evicted; and `ZOOM_ARMS` printed N identical
   arms under labels that read exactly like the interleaved measurement, with
   the flag never flipped and every ratio at 1.00.

**Five of the ledger's twenty-one rulings a later reader must not mistake for
drift.** The other sixteen are in the archived ledger's `progress.md`.

- **Ruling 14 — the plan pinned two interleaved measurements and built no way
  to run either.** Criterion 4 alternates a rest-bake arm with a "rest bake
  disabled" arm; criterion 8 alternates a narrow arm with Plan **3h**'s M4
  mutation. Both arrangements are *same session, interleaved*, and two
  binaries cannot interleave — so both arms need a runtime switch, and neither
  existed. `TileCache.debugRestBakeDisabled` and
  `TileCache.debugFullViewportQuery` were added for exactly this, default
  `false`, no `lib/` writer, each proved to actually change an observable
  counter by its own mutant (M13, M14) and the second one's narrow clip — what
  makes it 3h's M4 rather than its M5 — pinned by `debugLastClip` and M16.
  **The second switch ships a known defect behind a flag**, which is stated at
  the field. Without both switches, both arms of each ratio run identical code
  and every reading is 1.00 — the degenerate fixture, landed in a document of
  record.
- **Ruling 15 — criterion 3 is scored as `settleFrames == 2`, not `== 1`, and
  this is a spec contradiction rather than a moved threshold.** The criteria
  table says the settle completes in **one** frame; `kRestGateFrames = 2` is
  pinned separately in the same spec, for its own reason (a pan straight after
  a zoom finds an empty generation and would otherwise arm the gate mid-pan).
  The last gesture frame changes the camera, so idle frame 1 can only reach
  `_restGateSteps == 1` and takes the moving-frame early return; idle frame 2
  is the first that can bake. **On correct code `settleFrames` is always 2**,
  so criterion 3 as literally written is a gate only broken code could pass.
  The correction is derived from a pinned constant and was recorded **before
  any device run**, so there is no result it could have been fitted to; the
  results note must carry the reading and the arithmetic so a reader can
  disagree without re-deriving it.
- **Ruling 17 — the controller's brief was wrong and the implementer's
  pushback was right**, recorded because a brief that would have broken a spec
  decision is worth more as a record than as a silent correction. Fix wave A's
  brief said to gate the moving-frame fall-through on `!carryOverCovers`; that
  would have made **every zoom-out frame pay the full-viewport live walk D3
  names, prices at 31.5–41.6 ms and rejects in as many words.** The shipped
  condition is `scaleChanged = !identical(incoming, _gridFor(...))`, which is
  exactly spec D1's definition of *moving*, and the reviewer checked it is not
  narrower than the defect on the three sequences the controller named.
- **Ruling 20 — the spec's pinned 1600x1200 reference viewport is
  UNREACHABLE on this machine, and criteria 2 and 4 were measured at 1400x900
  by the human's decision.** The logical desktop is 1496x967 and the panel
  3456x2234, so at dpr 2 the widest scaling gives 1728x1117 and the height
  never reaches 1200 in any mode. The smoke run also found that **nothing in
  the harness had ever set the window**: every figure it has ever produced was
  taken at the nib default of 800x600 while `main.dart` fitted its camera to
  `Size(1600, 1200)` — **the code had always assumed a window it never
  created.** Three options were put to the human with the trade stated before
  they chose. **Consequence, not buried: spec §5's memory pricing — 48 MiB of
  tiles, 8 MiB bands, a 56 MiB peak, all priced against the 3200x2400 device
  rectangle — remains untested**, and criterion 7's ceiling holding at the
  sizes tested is the weaker statement that was actually earned.
- **Ruling 21 — criterion 8's first n=9 run was DEGENERATE and its numbers
  were not published.** The arms were wired around the **zoom** phase, where
  `debugFullViewportQuery`'s only effect — the live fallback's query extent —
  never runs, because a moving frame blits the composite and returns:
  `gestureLiveDraws=0` in all eighteen arms and the two arms were
  indistinguishable. **This is the 1.00 that Ruling 14 exists to prevent,
  arriving through a different door**: not "the flag was never flipped" but
  "the flag was flipped on code that never runs". Root cause was the
  controller's brief — Plan 3h's criterion 3 measured the **pan** phase. **The
  irony is exact: the zoom phase has no live walk because this plan removed
  it, and criterion 1 scored that as a PASS in the same session.** The
  discarded log is kept as `KEEP_c8_DEGENERATE_run.log` beside the archived
  ledger and is named in the results note as a measurement taken, read and
  discarded.

**Gaps this plan accepted, and the new ones this plan produced.**

Accepted by the spec, each ungated on purpose:

- **G3 — level-of-detail geometry, still open.** After this plan it blocks
  nothing: a correct frame during a gesture is still 32–40 ms at 500,000
  entities, and this plan does not make that frame faster, it stops drawing
  it during a gesture. **G3 becomes necessary the day the target changes to
  correct geometry while the fingers are still moving.**
- **The zoom-out background ring.** D3 leaves it, by the human's decision.
  What it looks like at speed is a judgement for a human with the window open,
  and no criterion here measures it.
- **An edit landing mid-gesture.** `applyChange` drops the carry-over, so a
  moving frame then has no composite and under D3 draws nothing at all until
  the gesture ends. Rare, recorded, ungated.
- **The resting frame's duration is not gated.** D5's *peak* is gated; its
  length is not. A slower machine shows a longer hitch and this plan will not
  have measured how much longer.

New, from this plan's own session:

- **Criterion 9's regression is measured and not diagnosed.** 1.35x on means
  with byte-identical counters. Two candidates are named above; neither is
  ruled in or out. The counters are where an investigation starts.
- **The spec's §5 memory pricing at 3200x2400 device pixels is untested**,
  because the window cannot be made that large on this display (Ruling 20).
  Recoverable by a re-run on an external display.
- **The naked-eye seam check (gap G1) is still owed by a human.** The
  instrument exists — `.vscode/launch.json` carries `2d: seam check -- tiles
  ON` and its tiles-off control — and nobody has stood at the window and
  compared them.

**Two findings for the record that are not this plan's to fix.**

- **`DraftPainter` queries the index unslacked** (`draft_painter.dart:338`
  sets `_worldRect` from `camera.visibleWorld(viewport)`) while a bake pads by
  `kTileSlack`, so an untiled reference drops strokes centred just outside a
  viewport edge — **measured 1,767 stray pixels**. Fixing it is a production
  change that could move goldens, so Task 9 left it and routed its arms' ink
  away from the blind window instead, saying so at the assertion.
- **`bakeCount` now mixes units**: once per band on the rest path, once per
  tile on the budgeted path. A reader comparing against Plan 3g and 3h
  transcripts, where it meant tiles, will be misled unless the phase's own
  label is read.

---

1. ~~**Plan 3i — zoom, G3, and level-of-detail geometry**~~ — **DONE, and the
   answer was not level-of-detail geometry.** This paragraph was written on
   2026-08-25, before 3i had a spec, and it is kept struck through rather than
   deleted because a later reader will otherwise re-derive the wrong premise
   from Plan 3g's assignment. **3i's spec declined LOD** and took a map
   application's target instead — a moving frame draws the carry-over
   composite and nothing else — so **G3's 32.06 ms at 500,000 entities is
   still there and still uncaught, and it now blocks nothing.** G3 stays on
   the open-gap list, above, with the condition that reopens it: **the day the
   target changes to correct geometry while the fingers are still moving.**
   The two things this item said 3i must *carry* were both discharged:
   criterion 3's re-measurement happened at n=9 interleaved (3i's criterion 8,
   which **misses** at 2.328 and settles the question differently than
   expected — the gate sits inside the noise), and the zoom gesture path is
   what 3i rebuilt.
2. **Plan 3j — the 192 MiB vertex buffer.** `debugCapacityVertices` reads
   **16,777,216 vertices, 192.00 MiB, in all five configurations measured**:
   50,000 and 500,000 entities, tiles on and off. **Tiles change nothing, so
   the tile budget adds to that memory rather than replacing it** — that
   addition is Plan 3j's starting point, and **the figure sits on a doubling
   boundary with no headroom.** The mark is not a function of entity count: a
   tenfold corpus reads the same number. The steady frame uses an eighth of
   what stays pinned; the mark is set by the sweep's worst camera and never
   released, because capacity is deliberately never given back. Full
   measurement:
   [docs/superpowers/notes/2026-08-25-vertex-buffer-high-water.md](docs/superpowers/notes/2026-08-25-vertex-buffer-high-water.md).

---

## After Plan 3h — what the window showed (2026-08-26)

**Not a plan. Four findings from running the harness by hand and looking at
it**, at the human's request, before deciding what 3i should be. Two were
fixed on the spot; two are 3i's input and are deliberately **not** fixed here.

Every defect below was alive under a green suite. `CLAUDE.md` already says
defects here surface through mutation and differential testing rather than
reading; this session adds a third instrument — **looking at the running
window** — which is exactly what gap G1 predicted would be needed and the only
one that found any of these.

### Fixed

1. **A macOS trackpad never sends the event zoom listened for** — `fc05076`.
   The harness bound zoom to `Listener.onPointerSignal`, which only a real
   mouse wheel reaches. Instrumenting every pointer callback and driving the
   trackpad logged **709 `PointerPanZoomUpdateEvent`s and zero pointer
   signals**. Two-finger scroll additionally reports its motion as `pan` with
   `scale` at exactly 1.0, so handling `scale` alone would have fixed pinch
   and left scrolling dead. Eight tests, three mutants killed.

2. **The settle needed frames nothing was asking for** — `967fa3b`. A defect,
   not a limitation, and **it was not on any gap list**. `paintFrame` bakes at
   most `budgetedTilesPerFrame` tiles — exactly one at the production defaults
   — so a viewport fills over many frames; Flutter produces a frame only when
   something asks, and only the camera, the document and the layer tables were
   asking. A gesture that ended ended the settle with it, leaving the
   magnified carry-over on screen until an unrelated edit happened to cause a
   frame. The measurement rig never saw it because `_pumpFrame` drives frames
   itself. `TileCache._viewportCovered` already held the answer and was only
   read internally; it becomes `viewportCovered`, and `DraftCanvas` asks for
   one more frame while it is false. **This is `_TableListenableAdapter`'s
   defect from the other side** — there the cache was never told, here it was
   told and could do nothing.

### Measured, and left for Plan 3i

> **Both are now answered, and the answer to the first was the *first* of the
> two rival options below, not the second.** Plan 3i skips baking on a frame
> whose scale changed and declines level-of-detail geometry; the resting
> camera does spend more than a moving one, via the band bake. Read the two
> items as the question 3i was handed, not as its conclusion.

3. **A zoom step retires the whole generation, and a gesture is all waste.**
   `_gridFor` calls `_retireGeneration` whenever `matchesScale` fails, so
   every scale change drops every baked tile. Measured at 800x600, dpr 2,
   512-pixel tiles against `fillingGrid`:

   | | |
   |---|---|
   | cold settle | 11 frames, 12 tiles |
   | **one zoom step** | 12 tiles → **1**, generation 1 → 2 |
   | settle after that step | 12 frames |
   | a 20-step gesture | generation 2 → **22**, tile count never above 1 |

   The gesture bakes twenty tiles and discards twenty. Against Task 11's
   measured **12.56 ms to bake one 512-pixel tile**, that is ~12.56 ms of
   per-frame work thrown away for one frame's worth of one tile in twelve.

   **Two rival answers, and choosing between them is 3i's job, not a
   follow-up commit's.** Either skip baking on a frame whose scale changed
   (the tile dies next frame anyway), or bake something *cheaper* at that
   scale — which is level-of-detail geometry, G3, and the reason 3i exists.
   Landing the first ad hoc would pre-decide the second. **Nothing here was
   fixed for that reason**, and the settle fix above is not the same call: "no
   frames at all" is a defect, "what to bake during a zoom" is a policy.

4. **The settle is bounded at one tile per frame, and that bound is
   measured, not arbitrary.** `kBakeBudgetDevicePixels = 262144` is exactly
   one 512-pixel tile because one bake (12.56 ms) plus the hold-frame blit
   (1.52 ms) is 14.08 ms against a 16.67 ms budget, and two bakes are 25.12 ms
   outright. So a ~40-tile viewport needs ~40 frames — about 0.7 s of stale
   pixels after every zoom. **Raising the budget is not free and the number
   that forbids it is already recorded**; whether a *resting* camera may spend
   more than a moving one is a question 3i should answer with the rest of the
   zoom path, since a still screen cannot show a dropped frame.

### Also established, and not a defect

**`drawVertices` ignores `isAntiAlias`, and `defaultRenderBackend()` is
`RenderBackend.vertices`.** There is no `isAntiAlias` anywhere in
`vertices_draw_sink.dart`, `canvas_draw_sink.dart` or `tile_cache.dart`,
because that path cannot honour it — edge quality is the surface's MSAA and
nothing else. Gap G1 said software Skia does not antialias `drawVertices`;
what the window adds is that **the default production backend does not get
per-primitive antialiasing on a GPU either**. `BACKEND=canvas` is the A/B, and
Skia's `Paint.isAntiAlias` defaults to true there. Whether that matters to a
CAD drawing at plot lineweights is a question for a human with the two windows
side by side, not for a test.

**The instrument now exists.** `--dart-define=CORPUS=simple` builds
`seamCorpus()` — about sixty entities at the measurement corpus's own far
origin, a hairline grid whose pitch is deliberately not a divisor of the tile
pitch, a fan weighted toward shallow angles, and two lineweight regimes in one
frame. `.vscode/launch.json` carries `2d: seam check -- tiles ON` and its
tiles-off control. Gap **G1 is now reachable by anyone who presses F5**, which
is the whole of what it asked for.

---

**Plan 3f.1 (hardening before the picture cache) is done, worked directly on
`main` at `c078677..b1e9ec1`. Its exit gate is 16 of 17, the one miss being its
own pre-committed stop clause firing on the allocation-meter probe.**
Everything below about 3f is still true and still worth reading.

**Nothing here is waiting on a human.** `StyleContext` is now correctly keyed
(trap 4, closed), `linetypeScale` reaches the drawing, and 3g knows before it
starts that its central risk (trap 5) needs a command-time assertion rather
than a frame-path allocation gate, because the latter does not work under
`flutter test`. See
[Plan 3f.1](#plan-3f1--hardening-before-the-picture-cache) above and
[the results note](docs/superpowers/notes/2026-08-23-plan-3f1-results.md) for
every number, including the plan's own recurring failure mode (a stated cause
stronger than its evidence, three times, each caught by running something
rather than reading it) and the three plan premises corrected mid-flight.

~~**A resumer's ledger chore:** 3f.1's `.superpowers/sdd/` material is not yet
archived.~~ **Done.** Archived at
[docs/superpowers/ledgers/2026-08-23-jet-cad-2d-plan-3f1-hardening/](docs/superpowers/ledgers/2026-08-23-jet-cad-2d-plan-3f1-hardening/),
and 3g's beside it. The ordering is still the lesson 3e's and 3f's archives
both record: **archive onto the branch before the workspace is deleted.**

**Plan 3f (text wiring and level of detail) is done, worked directly on
`main`, nothing in flight. Its exit gate is 11 of 13.** Everything below about
3e is still true and still worth reading; this is what changed on top of it.

**One thing is waiting on a human and nothing else in 3f is.** Rows 1 and 2 of
3f's gate miss: at the shipped `kMinTextCapPixels = 3.0` the whole-drawing
camera needs **3,876 distinct paragraph keys in one frame** against a
512-entry cache, so a repeated identical frame relays out all 3,876 and evicts
3,876. **Ruling 4's single permitted `kParagraphCacheLimit` raise is now
available** — the ruling wanted a measured distinct-visible-key count recorded
beside any raise, and 3,876 is it. **The plan deliberately did not spend it**,
because it can only be spent once and 3g may want it, and because holding
3,876 live native `ui.Paragraph` objects in a frame is a memory cost nobody
has measured. Raising the *threshold* instead makes both rows comply and was
refused on principle: 3.0 is a readability number, 6.0 would be a
gate-passing number. **The decision is written up as an option in
[the 3f results note](docs/superpowers/notes/2026-08-22-plan-3f-results.md)
and is yours to make.**

**A resumer's ledger chore:** 3f had no worktree, so its
`.superpowers/sdd/2026-08-22-jet-cad-2d-plan-3f-text/` material is **not yet
archived** to `docs/superpowers/ledgers/`. Do that before clearing it — the
ordering is the lesson 3e's archive records.

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
is the named successor and what 3d, 3e and 3f owe it is written out at the end
of [the 3d results note](docs/superpowers/notes/2026-08-21-plan-3d-results.md),
[the 3e results note](docs/superpowers/notes/2026-08-22-plan-3e-results.md) and
[the 3f results note](docs/superpowers/notes/2026-08-22-plan-3f-results.md)
respectively. 3g's **first design decision** is 3f's unanswered question:
whether a cached picture may contain text at all, given that a picture is baked
per scale band while level of detail is a function of continuous scale.
**Permitted divergence 5** (overlapping translucent strokes on a triangle soup)
is now live and still has no fixture — 3f did not touch it either — a candidate
for a short follow-up before or alongside 3g.

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
4. **Whole-drawing thrash → text LOD (Plan 3f). Attempted, measured, and
   *not* closed.** The premise was 4,140 layouts and 4,140 evictions per
   frame, bounded by string variety rather than entity count, and that "not
   drawing text too small to read removes the cost." Plan 3f built the LOD
   and measured what it removes: at the readability-justified 3.0 px
   threshold, **3,876** — a 6.4% improvement on a row whose bar is zero. The
   cost is *not* removed at the whole-drawing camera; it is removed
   completely at the working-set camera, which never needed it (smallest
   surviving cap height 53.67 px, 17.9× the threshold). **This item stays
   open**, and the two ways to close it are named in
   [the 3f results note](docs/superpowers/notes/2026-08-22-plan-3f-results.md):
   Ruling 4's one unspent `kParagraphCacheLimit` raise, now that 3,876 is
   measured, or a threshold in the 3.0–6.0 band chosen on grounds other than
   a gate row.
5. `snap at dirty threshold` p95 1.08 ms against < 1.0 ms — carried from Plan 2.
6. `DocumentTree._link` is quadratic in a parent's child count, which is why
   the rigs cap `instanceCount` at 20,000 — recorded in Plan 3b.

---

## Rulings that still bind future work

Plan 3c's ledger carries 56 numbered rulings, archived in full at
[docs/superpowers/ledgers/](docs/superpowers/ledgers/). These are the ones that
constrain work not yet done:

**Ruling 4 — the cache limit is not a tuning knob.** `kParagraphCacheLimit` is
owned by Plan 3c Task 9 and may be raised **once**, and only with the
measured distinct-visible-key count recorded beside it. Lowering
`attributedInstanceFraction` is equally acceptable. **Relaxing the
zero-new-layouts gate row is not.** Otherwise the gate passes because the corpus
was thinned rather than because the cache works.

> **Status as of 2026-08-23: the raise is now *available* and is still
> unspent.** Plan 3f Task 8 produced the count the ruling asks for —
> **3,876** distinct `(text, styleHandle, argb)` keys at the whole-drawing
> camera on the 50,000-entity corpus at `kMinTextCapPixels = 3.0`, read by
> three independent mechanisms. Plan 3f declined to spend it: the raise can
> only happen once, Plan 3g may want it, and holding 3,876 live native
> `ui.Paragraph` objects in one frame is a memory cost nobody has measured on
> any target. **A human decides whether to spend it.** Plan 3f also refused
> the other route — raising `kMinTextCapPixels` from 3.0 to 6.0 makes the
> gate rows comply and would be a threshold chosen because a gate needed it,
> which is the same failure this ruling names one level up.

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

**Done.** Nine tasks, worked directly on `main` at `5d4ef7a..d113d2d`, no
worktree, on the human's explicit consent. Spec:
[docs/superpowers/specs/2026-08-22-jet-cad-2d-plan-3f-text-design.md](docs/superpowers/specs/2026-08-22-jet-cad-2d-plan-3f-text-design.md).
Plan:
[docs/superpowers/plans/2026-08-22-jet-cad-2d-plan-3f-text.md](docs/superpowers/plans/2026-08-22-jet-cad-2d-plan-3f-text.md).
Results:
[docs/superpowers/notes/2026-08-22-plan-3f-results.md](docs/superpowers/notes/2026-08-22-plan-3f-results.md).
Mutation log:
[docs/superpowers/notes/plan-3f-mutation-log.md](docs/superpowers/notes/plan-3f-mutation-log.md).

Two defects fixed and one mechanism built. A document assembled the ordinary
way carried `InsertionPointMeasurer` and drew no text while reporting nothing —
the document now owns a `FlutterTextMeasurer`, `DraftCanvas` borrows it, and a
document whose measurer cannot lay out paragraphs is refused with the fix
spelled out. The painter and the sink read different measurers — they now read
the same one, whose cache is **split**: colour-free metrics keyed
`(text, styleHandle)`, coloured paragraphs keyed `(text, styleHandle, argb)`,
bounded separately, so a full `extents` sweep cannot evict what the paint path
had warm. And text level of detail: `kMinTextCapPixels = 3.0`, checked
**before** `measure()` so a cull saves the layout, `0.0` to disable, counted by
`culledTextCount`, pinned by a three-rung golden ladder.

**Exit gate: 11 of 13 pass, 2 miss, 0 unevaluable.**

**Rows 1 and 2 miss and are left missing.** At the shipped 3.0 threshold the
whole-drawing camera needs **3,876 distinct paragraph keys in one frame**
against a 512-entry cache, so a repeated, unchanged frame produces 3,876 new
layouts and 3,876 paragraph evictions — zero cache hits, against a baseline of
4,140. Three independent mechanisms read the same 3,876.

**Neither available remedy was taken, and the second is a decision waiting for
the human.**

1. **Raising `kMinTextCapPixels` to 6.0 makes both rows comply outright**
   (`distinctKeys=94`, `paragraphEvictions=0`) and is **refused**. 3.0 comes
   from a readability argument — under about three pixels of cap height a
   glyph cannot resolve two strokes. 6.0 would come from a gate row needing
   it. Those are different in kind.
2. **Ruling 4's single permitted `kParagraphCacheLimit` raise is now
   available and is deliberately unspent.** The ruling requires a measured
   distinct-visible-key count recorded beside any raise; that count did not
   exist until Task 8 produced it, and now does. Cost: **3,876 live native
   `ui.Paragraph` objects in one frame**, which Plan 3d's carry-forward note
   argued against and which nobody has measured in resident memory on any
   target. It also forecloses spending the raise in 3g. **The human decides
   this, not a plan.** Written up in full in the results note.

**The honest shape of the outcome.** Level of detail is **decisive at the
working-set camera — by not firing at all**: flat at every threshold from 0.0
to 10.0 (18 keys, 18 layouts, 0 culled), smallest surviving cap height
**53.67 px**, about five times the widest threshold tried. That is the camera a
frame budget is about and it is nowhere near the cliff. It is **insufficient at
the whole-drawing camera at a readability-justified threshold**. And the step
is a **band from 3.0 to 6.0, not a point** — the corpus's mirrored and
non-uniform placement transforms spread per-instance `scaleMagnitude` even at
one fixed logical text height, so the mass crosses over about three units
rather than at one value.

**Two rows pass without being able to fail, and both are recorded as such.**
Criterion 6 (`doc.extents` bit-identical at either threshold) is **structurally
guaranteed**: `entityBounds` has no channel to a painter's `minTextCapPixels`,
so it recomputes identically on both reads and two identical wrong answers
compare equal. Mutant 10 was fired twice and row 6's test passed both times;
recorded as a restatement, never as a kill. Criterion 10 at **corpus** scale is
non-discriminating — `doc.extents` is not the 4,020-key sweep the spec assumed
(`_computeExtents` caches bounds per definition, so 12 distinct strings get
measured, not 4,020), and it passes under both mutations it exists to catch.
The discriminating form is the unit-scale test.

**Mutant 7 survived its own suite** — `metricsLimit` defaulted to
`kParagraphCacheLimit` passed all 297 tests, because every test in
`flutter_text_measurer_test.dart` constructed the measurer with both bounds
given explicitly. Recorded as a survivor, then killed by a test written for it
(`645b027`). The shape of that hole **was audited** in the final fix wave.
Three known instances: `metricsLimit`'s default (mutant 7, above);
`paragraphLimit`'s default, audited during Task 9's review — mutating it
reddens only a restatement test, so the default is still behaviourally
unexercised; and `reference_walk.dart:36`'s `minTextCapPixels` default, where
setting it to `0.0` leaves the whole suite green because a caller's own
default shadows it.

### Plan 3f.1 — hardening before the picture cache

**Done.** Eight tasks, worked directly on `main` at `c078677..b1e9ec1`, no
worktree, on the human's explicit consent. Task 7 (the allocation-meter
probe) produced no commit — its stop clause fired and the change was fully
reverted. Spec:
[docs/superpowers/specs/2026-08-23-jet-cad-2d-plan-3f1-hardening-design.md](docs/superpowers/specs/2026-08-23-jet-cad-2d-plan-3f1-hardening-design.md).
Plan:
[docs/superpowers/plans/2026-08-23-jet-cad-2d-plan-3f1-hardening.md](docs/superpowers/plans/2026-08-23-jet-cad-2d-plan-3f1-hardening.md).
Results:
[docs/superpowers/notes/2026-08-23-plan-3f1-results.md](docs/superpowers/notes/2026-08-23-plan-3f1-results.md).
Mutation log:
[docs/superpowers/notes/plan-3f1-mutation-log.md](docs/superpowers/notes/plan-3f1-mutation-log.md).

Two defects closed and one instrument tested to a verdict. `InstanceNode`
gained the four style fields `StyleContext` needs (`lineweight`,
`transparency`, `linetype`, `linetypeScale`; schema 5 → 6); `contextFor`
resolves all three sentinel-carrying fields exactly as it already resolved
`color`, including the `kLineweightDefault` (`-3`) guard and the layer-0
substitution; and `linetypeScale` now composes multiplicatively — entity ×
every enclosing INSERT × the header's global scale — where before it was
constructed, copied, compared and hashed and read by nothing. Two structural
invariant files moved Plan 3f's printed-but-unasserted rig numbers into
always-on tests. And `AllocationMeter` was moved to `lib/src/testing/` and
probed from `jet_cad_2d_flutter`: it does not work under `flutter test`
(`flutter_tester` launches with `--disable-vm-service`), the move was reverted
in full, and the finding is recorded rather than a workaround forced.

**Exit gate: 16 of 17 criteria PASS, 1 MISS, 0 UNEVALUABLE.** The miss is
criterion 17, the allocation-meter probe, and it is recorded as the plan's own
pre-committed stop clause working as designed, not as a defect. All
seventeen named mutants fired and were killed — no survivors, unlike Plan 3f's
own log.

**The Flutter package does not have a working allocation meter.** The
mechanism `AllocationMeter` relies on — starting the VM service at runtime
from inside the isolate under test, with no launch flag — cannot work under
`flutter test`, because `flutter_tester` is launched with
`--disable-vm-service` before any in-isolate code runs. A flag-based
alternative (`flutter test --start-paused` or similar) is plausible and was
never tried, but could not serve an always-on gate regardless, since the flag
is supplied by `flutter test` itself and not by anything this repository
controls per test run. **3g's trap 5 (the allocation gate cannot see a
lazily-populated cache) therefore needs a command-time assertion, the same
shape that proved fills eager in Plan 3e, not a frame-path allocation gate in
`jet_cad_2d_flutter`.**

**The plan's own recurring failure mode is named in the results note, in its
own section, because it produced three findings across this plan alone: a
stated cause written down more strongly than the evidence behind it, caught
each time by running something rather than by reading it** — the spec's own
defect 4 (a false present-tense claim about `flutter_text_measurer_test.dart`
that reached a committed comment before the Task 5 review caught it), the
ledger's "no retry would help" about the Task 7 probe, and the Task 7 report's
first causal claim. See the results note for the full account.

**Three plan premises were corrected mid-flight**, all recorded in the ledger
with their rulings: layer 0 already has a seeded record
(`tables.dart:509`, Task 2's fixture assumed otherwise); Task 1's "the
pre-existing suite will not move" (three tests pin the schema version by
literal or by FNV fingerprint, both re-baselined with evidence that the cause
was the serialisation shape and not an RNG-order regression); and Task 2's
"eight tests, all FAIL" (six failed, two were pre-existing regression guards
for a capability that did not yet exist).

**What this plan did not close:** permitted divergence 5 (overlapping
translucent strokes on a triangle soup) — untouched, still unexercised;
Ruling 4's single permitted `kParagraphCacheLimit` raise — still unspent, its
measured 3,876 still beside it; and the malformed-layer asymmetry — mirrored
onto instance resolution rather than fixed, an accepted gap from the spec.

### Plan 3g — the definition/tile picture cache

> **Plan 3g is executed and pushed. Exit gate: 11 of 13, and gap G7 closed
> after it.** Thirteen planned tasks became sixteen — 6a, 9a and 11a were
> inserted mid-flight — across `477d4c5..2367a20` on `main`, worked directly,
> nothing in flight. Pushed 2026-08-24, `6c6dc42..2367a20`, 45 commits.
>
> Results:
> [docs/superpowers/notes/2026-08-24-plan-3g-results.md](docs/superpowers/notes/2026-08-24-plan-3g-results.md).
> Mutation log:
> [docs/superpowers/notes/plan-3g-mutation-log.md](docs/superpowers/notes/plan-3g-mutation-log.md)
> — **41 mutants named, 40 fired, 39 killing something.** The plan counted
> seventeen; execution more than doubled it because repeatedly the mutant a task
> was handed could not fire and a working one had to be built.
> Spec:
> [docs/superpowers/specs/2026-08-23-jet-cad-2d-plan-3g-tile-cache-design.md](docs/superpowers/specs/2026-08-23-jet-cad-2d-plan-3g-tile-cache-design.md).
>
> **What works.** A rasterised tile cache behind `DraftCanvas(tiles: true)`,
> default off. `kTileDevicePixels = 512`, `kBakeBudgetDevicePixels = 262144`,
> `kTileCacheBytes = 96 MiB`. **Criterion 10 PASSES: a settled 500,000-entity
> frame reads a `totalSpan` median of 1.58 ms against a 4.00 ms threshold — 26x
> the same runs' untiled 41.09 ms.** A tiled frame is byte-identical to a live
> one at any camera, gated at zero stray, zero uncovered and zero differing
> pixels.
>
> **What misses, and it is recorded rather than tuned away.**
> **Criterion 11 MISSES by 2.1x**: a baking pan frame reads 35.67 ms against
> 16.67. The threshold was not moved. **The cause is not the bake** — a bake
> walk is 5.7-6.4 ms per tile, and the frame's ~32 ms of excess is the **live
> fallback drawing the still-uncovered strip**. The spec's own prescribed remedy
> is spent: it said the answer was a smaller bake budget, and the budget is
> already one tile. **Plan 3h inherits a design question, not a tuning one.**
>
> **And the gap that read worst turned out to be a gap in what had been run.**
> Plan 3g closed recording **G7 — nothing gates per-tile clipping**. M7 (clip
> each tile to the viewport instead of its own rect) was fired **on device** and
> collapsed nothing: criterion 10 is *structurally blind* to it
> (`bakeFrames=0/60`) and criterion 11 was already red, so neither timing could
> show a green-to-red transition. Both of those readings stand. What did not
> stand is the conclusion drawn from them — that **no** transition existed
> anywhere. The widget suite was never executed under M7; the line covering it
> read "criteria 1–9, 12 and 13 pass under M7 **by construction**", and "by
> construction" was the tell.
>
> **Run on 2026-08-24, M7 reddens five widget tests.** Four already existed:
> the **criterion 5** rows in `tile_invalidation_test.dart`, which assert that
> an edit invalidates its own tiles **and no others** — under M7 every tile
> records every visited handle, so every edit invalidates every tile. The
> containment claim was reachable from the invalidation side and was already
> gated there.
>
> **G7 is closed.** The bake-time assertion the spec asked for was landed anyway
> at `1b7ea04` —
> [`test/invariants/tile_containment_test.dart`](packages/jet_cad_2d_flutter/test/invariants/tile_containment_test.dart)
> — because the four state that *invalidation is precise* while it states that
> *a bake is bounded*, and Plan 3h may loosen the first in good faith. Nine
> short segments 90 world units apart; a bake queries its own tile grown by
> `kTileSlack`, 68.57 world units across at that rig, while two segments span
> 96. Clean reads one segment per tile, M7 reads nine on tile (0,0). No new
> production API and no fourth knob.
>
> **Read the results note's last section before starting 3h.** The dominant
> finding of this execution was not any single defect: **twelve times a gate
> turned out unable to see what it claimed to measure**, each in a different
> disguise, and the note carries the taxonomy and the seven questions that find
> them. The twelfth reaches the instruments themselves — the rig's `overdraw`
> column reads identically under M7 because `_probeBake` **reimplements** the
> bake geometry instead of calling `_bake`, which means the overdraw figures in
> the spec describe a reimplementation and not the shipped code. They
> corroborated the 512 decision; the pan p95 and the live-walk fallback counts
> decided it.
>
> **And a thirteenth, which is the inverse and was found after the plan
> closed:** a gate that *could* see what it claimed to measure, recorded as
> blind because a different instrument was the only one fired. Its question
> joins the seven — *did I run this, or did I reason that it passes?* See the
> G7 correction above.
>
> Traps 1, 2, 3 and 4 are closed, and so are F1 (a whole stroke column vanished
> at 6 of 41 zoom factors), G6 and — since 2026-08-24 — **G7**. Gaps G1, G2,
> G3, G4 and G5 are open and each names what it owes.

**What 3f hands it, and one question it must answer first.**

- **A working text LOD** — `kMinTextCapPixels = 3.0`, `0.0` disables it, wired
  from `DraftPainter` through `DraftCanvas` to the harness's `LOD` define,
  counted by `culledTextCount`, pinned by a golden ladder.
- **The threshold ladder**, regenerable from the committed tree behind a
  `LADDER` dart-define, and the finding that the step is a **band** (3.0→6.0),
  not a point.
- **The measured distinct-visible-key count: 3,876** — and with it, **Ruling
  4's one permitted `kParagraphCacheLimit` raise, now available and
  unspent.** Spending it in 3g is a live option; so is spending it on 3f's
  missed rows. It can only be spent once.
- **A split text cache** and **document-owned measurer** (see 3f above).
- **The unresolved question, and it is 3g's first design decision: may a
  cached picture contain text at all?** A picture is baked per scale band;
  level of detail is a function of continuous scale. A picture baked at one
  scale and replayed at another either shows glyphs the current camera would
  cull or hides glyphs it would draw. Three candidate answers — never bake
  text, bake per LOD band as a fourth cache axis, or draw text outside the
  cached picture entirely — and **none of them has been priced**.

**What 3f.1 hands it.**

- **A correctly-keyed `StyleContext`.** All six fields now carry what they
  claim, so the picture cache key is right the first time and does not need
  rekeying after the fact. See trap 4's closure note, below, for the
  cardinality cost this creates.
- **`linetypeScale` connected end to end** — entity × every enclosing INSERT ×
  global — which bears directly on trap 3: a baked picture is not
  scale-invariant now that dashes exist, and dash phase is a function of this
  product.
- **Structural invariants that run on every `flutter test`**
  (`text_cache_invariants_test.dart`, `frame_accounting_test.dart`), so 3g's
  own counters can land on a suite that fails rather than one that prints.
- **No working Flutter-side allocation meter, and a recorded reason why.**
  `AllocationMeter` does not connect under `flutter test`
  (`--disable-vm-service` at the process launch, not a code defect). 3g's
  trap 5 needs a **command-time assertion** — the shape that actually proved
  fills eager in Plan 3e — not a frame-path allocation gate in
  `jet_cad_2d_flutter`.
- **Ruling 4 still unspent**, its measured 3,876 still beside it.

**What 3d hands it.** A picture cache that records into a `Picture` interacts
with a sink that batches across residuals: 3g must decide whether a cached
picture flushes the vertex buffer at its boundary. There is **no crossover
number** to work against — the vertices backend's raster margin is still
widening at 500,000 entities — and there is **96.00 MiB of vertex buffer pinned
for the widget's life** at that corpus size, which is the arithmetic a tiling
scheme changes. **Both halves of that last clause were measured false on
2026-08-25:** the figure is 192.00 MiB on today's tree, it is the same at
50,000 entities so it is not "at that corpus size" at all, and **tiling does not
change it** — see
[the high-water note](docs/superpowers/notes/2026-08-25-vertex-buffer-high-water.md). Read the margin against **canvas calls**, not entity count: a
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
4. ~~**`InstanceNode` carries only 2 of `StyleContext`'s 6 fields.**~~
   **Closed by Plan 3f.1, 2026-08-23.** `linetype`, `linetypeScale`,
   `lineweight`, `transparency` were missing; `InstanceNode` now carries all
   four (schema 6) and `contextFor` resolves them exactly as it already
   resolved `color`, including the layer-0 substitution and the
   `kLineweightDefault` guard. **And closing it creates a cache-key
   cardinality cost 3g should not meet as a surprise:** `StyleContext`
   compares `linetypeScale` with `==` and feeds it to `Object.hash`
   (`style_context.dart:67,73`). Now that the four fields carry real values,
   instances that used to share one definition picture no longer do — and
   because the scale is a **product** accumulated down the tree, two chains
   whose scales are mathematically equal but reached by different factors
   (say, `2.0 × 4.0` and `1.0 × 8.0`) are different doubles and therefore
   different keys. That is correct behaviour with a real hit-rate
   consequence, and it is a reason 3g may want its key to carry a **quantised
   scale band** rather than the raw double.
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

### Plan 3h — the fallback walk and its instrument

**Done, worked directly on `main`, `f642202..122b6e3`, eight tasks (the eighth
split into 8a and 8b), nothing in flight** — no worktree, the same standing
consent as Plans 3e, 3f, 3f.1 and 3g. Spec:
[docs/superpowers/specs/2026-08-25-jet-cad-2d-plan-3h-pan-frame-design.md](docs/superpowers/specs/2026-08-25-jet-cad-2d-plan-3h-pan-frame-design.md).
Plan:
[docs/superpowers/plans/2026-08-25-jet-cad-2d-plan-3h-pan-frame.md](docs/superpowers/plans/2026-08-25-jet-cad-2d-plan-3h-pan-frame.md).
Results:
[docs/superpowers/notes/2026-08-25-plan-3h-results.md](docs/superpowers/notes/2026-08-25-plan-3h-results.md).
Mutation log:
[docs/superpowers/notes/plan-3h-mutation-log.md](docs/superpowers/notes/plan-3h-mutation-log.md).

**Read this before anything below that sounds like a clean close: the
headline criterion MISSES, and a second criterion misses beside it.**
Criterion 3 — `tile pan` p95 ratio, the M4 arm (pre-narrowing behaviour) over
the narrowed arm, same session, three runs each — reads **2.35x against a
gate of ≥ 2.4x**. Criterion 6 (`tile hold` p50 ≤ 2.0 ms, p95 ≤ 2.5 ms, scored
per run, not by median) also **MISSES**: run 1's p95 is 2.77 ms. Per
instruction, neither number is adjusted or re-run to chase its threshold.

**The measurement cannot settle criterion 3 either way, at n=3 per arm.**
Narrowed `tile pan` p95: {13.43, 15.99, 19.86} ms, mean 16.43, CV 19.7%. M4
arm p95: {36.14, 37.59, 38.14} ms, mean 37.29, CV 2.8%. Pairing every M4 run
against every narrowed run gives nine ratios, sorted: 1.82, 1.89, 1.92, 2.26,
2.35, 2.39, 2.69, 2.80, 2.84 — a span that **straddles 2.4 in the middle, not
near either edge**. Re-running this exact arrangement and hoping the median
lands ≥ 2.4 would be close to a coin flip, not a confirmation of either
result. The M4 arm also ran last, in a visibly noisier session (`tile hold`
max, a phase M4 cannot touch at all, reads an order of magnitude higher on
the M4 arm than the narrowed arm), which biases the ratio's numerator
**upward — against the miss, not for it.**

**The 2.4 gate itself was mis-derived, in exactly the way a ratio measured in
one session exists to prevent.** It comes from the spike's 2.59x, whose
numerator (43.13 ms) was measured in a *different* machine session from its
own 16.66 ms denominator. Against this task's M4 figure (37.59 ms) that
numerator reads −12.8%; against this task's narrowed median (15.99 ms) the
spike's own denominator reads only −4%. The gap between sessions sits almost
entirely in the numerator — a cross-session comparison is the exact weakness
criterion 3's own design argument gives for making it a ratio in the first
place.

**The mean is evidence, not a gate, and it shows the effect is real and
large.** Narrowed `tile pan` means: {3.71, 3.89, 3.27} ms, CV 8.8%. M4 means:
{5.02, 5.17, 5.09} ms, CV 1.5%. The two sets do not overlap at all — narrowed's
highest (3.89) sits below M4's lowest (5.02) — and `bakes=14 liveDraws=10` in
the same 120-frame phase on both arms, so the delta concentrates onto the
same roughly-ten fallback frames either way: **≈16.6 ms saved per fallback
frame**, non-overlapping, low-noise. This is not a substitute score for
criterion 3, which is defined on p95 and stays a **MISS**.

**Criterion 3b, the absolute figure, is a near-miss and is not smoothed.**
Narrowed `tile pan` p95: 19.86, 15.99, 13.43 ms, against the spec's own
ungated 16.67 ms budget. The **median** (15.99 ms) lands under budget, but
**one of three runs (19.86 ms) misses it outright, by 3.19 ms** — a larger
overshoot than the spike's own worst sample (17.40 ms, 0.73 ms over).
Recorded plainly, per spec, ungated: "median under budget, one run clearly
over, more variance tonight than the spike showed."

**Six mutants, and where each died — all re-fired 2026-08-26 against the
widened `fillingGrid` (fix round 2; see the mutation log for every
transcript).**
- **M1 — drop the clamp.** Unit, killed, and **more fully than before**: the
  three `stripFor` cases it always reddened, **plus** `criterion 2 and 2c` on
  the triangle ratio (`liveTri: 62, tiledTri: 66`), which the predecessor
  fixture could not see. Whole suite `+368 ~1 -4`.
- **M2 — drop the pad (`kTileSlack → 0`).** **Survives the pixel sweep;
  dies at the suite level on the pad's value.** The narrow claim — the
  `fillingGrid` sweep cannot see `pad = 0` — is what criterion 1b and gap H5
  rest on and it holds, now non-vacuously (every one of the eight bands
  carries 2224–9696 device pixels of live ink and the sweep still reads
  `stray: 0, uncovered: 0, differing: 0`). But `tile_cache_test.dart`'s
  `stripFor` group asserts the pad's *value* and reddens on three cases:
  whole suite `+369 ~1 -3`. The earlier bare "survives" here conflated the
  two claims and scored those same three cases for M3 while dropping them for
  M2; that is corrected. D2's pad rests on `_bake`'s argument and Plan 3g's
  F1 history, not on a gate this plan built.
- **M3 — shrink the query 20px.** Unit, killed — and **fuller than the plan's
  own text claimed**: under the whole widget suite, criterion 2b also reddens
  (`differing: 417` against a bound of 60), not only criteria 2 and 2c, plus
  three `stripFor` cases and a `tile_budget_test.dart` row. Whole suite
  `+365 ~1 -7`, the same seven tests as before the fixture change.
- **M4 — narrow the clip, not the query.** **The plan's own claim that it
  "has no unit witness" is FALSE — the most important correction in this
  close-out.** A reviewer's M5 (below) prompted a triangle-count-ratio gate
  that, as a side effect neither mutant's author anticipated, also kills M4:
  it dies **doubly**, in the widget suite (`liveTri: 62, tiledTri: 80` against
  a bound of 60.14, whole-package run `+371 ~1 -1`, exactly one failure, on a
  sample carrying `stripInk: 7032`) and on the device ratio (2.35x — short of
  the 2.4 gate, but nowhere near the 1.0x a true non-regression would read,
  and an absolute 16.67 ms gate could not have told the two apart at all,
  since the narrowed arm's own p95 already straddles it). The device figures
  are unchanged and were not re-run: a fixture cannot move a timing.
- **M5 — grow the walk to the viewport, found by a reviewer, not planned.**
  Unit. First fired **green** against the entire widget package: the pixel
  sweep cannot see a query that *grows*, only one that *shrinks*, because the
  unchanged clip absorbs the excess. Killed by the triangle-count-ratio gate
  (`kTriangleBudgetRatio`, re-bracketed to **0.97** on the new fixture:
  correct code's worst ratio is 0.9375 and the mutant's lowest visible ratio
  is 1.0000, both measured). **This is the plan's own evidence that the
  review loop caught something the design did not.**
- **M6 — clip the padded strip instead of the uncovered union, found by the
  whole-branch review, not planned.** Unit, **survives** the entire widget
  package (`+372 ~1`, identical to baseline). `tile_cache.dart:825-830`
  predicts it in so many words. The difference is pure overdraw of pixels that
  already carry the same ink, so no pixel oracle can see it, and it does not
  change what is queried, so the triangle count cannot either. Recorded as
  **gap H6**.

**Gaps H1–H7** — H1–H5 carried from the spec's own accepted-gap list, H3 and
H5 restated and H6 added by the whole-branch review's fix round (2026-08-26),
H7 added by the final record re-review (2026-08-26).
- **H1.** Criteria 4 and 5 (`PAN_STEP=30/60`) are recorded, not gated, per
  design. Recorded: `perFrame` rises 0.117 → 0.500 → 0.967 as `PAN_STEP` goes
  7.6 → 30 → 60 px/frame, `liveDraws` rises 10 → 47 → 115, and at 60 px/frame
  `tileBytes` reaches exactly 96.00 MiB — the cap, not merely approached.
- **H2.** The three `PAN_STEP` arms are still not distance-matched (120 frames
  at 7.6/30/60 px/frame cover three different total distances). Open,
  unaddressed by this task, inherited by whoever gates that band next.
- **H3.** G5, the fallback strip's `Float32`/`Float64` asymmetry from its
  `canvas.translate`. **Restated 2026-08-26; the previous wording claimed a
  bound the near-axis arm cannot produce.** Measured per offset, every
  `nearAxisDiagonals` offset that carries any ink in the entering band —
  `(37,0)`, `(53,0)`, `(71,0)`, band ink 1654 each — has
  `strip.topLeft == (0, 0)`, where `canvas.translate` is a no-op; the other
  five bands are empty (that fixture spans world 20..220 by 30..150). **The
  near-axis arm therefore never exercises the translate at all**, and
  "bounded on the near-axis arm" was not a statement about G5. What the tree
  now has instead: the widened `fillingGrid` carries ink in the band at all
  eight offsets, including the two whose strips start at (343, 0) and
  (0, 247), and criterion 2 gates those at **exactly zero** differing pixels
  — a stronger claim than a bound, but only for **axis-aligned** geometry.
  The combination this gap is actually about — a near-axis slope walked
  through a translated strip — is **untested**, by either arm. Open, and
  narrower than it was recorded as being.
- **H4.** The spec's own text, "M4 has no unit witness," is **now known
  false** — see M4 above. Recorded here as corrected rather than left standing.
- **H5.** M2 survives the **pixel sweep** exactly as the plan pre-committed —
  and no longer vacuously. Measured zeros (`stray: 0, uncovered: 0,
  differing: 0` at all eight swept offsets) now sit on bands carrying
  2224–9696 device pixels of live ink apiece, so the sweep had something to
  lose at every offset. It is not a suite-level survivor: `stripFor`'s three
  pad-value cases redden (see M2 above). D2's pad is retained on `_bake`'s
  argument and F1's history, not on a gate of this plan's own.
- **H6.** M6 — clipping the padded strip rather than the uncovered union —
  survives the whole widget suite, and `tile_cache.dart`'s own comment
  predicts exactly that. Closing it needs an oracle this plan does not have:
  a fill-rate counter (nothing here counts pixels written) or a device timing
  sensitive to a `kTileSlack`-sized overdraw, which criterion 3 at n=3 is
  demonstrably not. Open. **The tally is six fired, four killed, two
  survivors**, over a chosen six — not a claim about every mutant that could
  be written.
- **H7.** The anti-vacuity clause added alongside `fillingGrid`'s widening
  (`InkReport.liveStripInk`) measures ink inside `TileCache.debugLastStrip`
  — `uncovered` padded outward by `kTileSlack` — not inside `uncovered`
  itself, the band the fallback actually owes. The pad reaches back into
  area the frame already blitted, so the clause is weaker than its own
  comment claimed: a re-review showed that on the predecessor, too-narrow
  `fillingGrid` extent, with this clause live at a floor of 200, deleting
  `TileCache.paintFrame`'s `canvas.translate` still left the whole widget
  suite green. Measuring ink inside `uncovered` rather than the padded strip
  would need a debug accessor on `TileCache` that does not exist. Until
  then, the sweep's protection against a vacuous band rests on
  `fillingGrid` clearing the largest swept pan offset, not on this clause.
  Added 2026-08-26 by the final record re-review; not a gate this plan
  built.

**One deferred minor, and one closed.** Still open: the triangle-budget gate
has **2** triangles of headroom at its tightest swept offset (60 of 62
allowed, out of 64 live, at `Offset(0, 53)`) — deterministic, not a flake, but
brittle to any future edit of `fillingGrid` or the swept offsets, and tighter
than the 4 it had before the fixture widened. Closed 2026-08-26:
`checkTriangleBudget` now defaults to **`true`**, joined by a new
`minimumStripInk` gate that also defaults on, so a future caller of
`sweepFallbackAgreement` gets both unless it opts out in writing;
`criterion 2b` is the one caller that does, and says why at the call site.

**Exit gate.** Of the criteria table's 12 rows, 3 (3b, 4, 5) are recorded
only, per spec, not gates. **Of the 9 that are gates: 6 PASS, 2 MISS, and
criterion 1b resolves to accepted gap H5 rather than to either outcome** —
per its own pre-commitment, it is not a binary pass or fail: M2 survives, so
1b lands on the plan's pre-declared third path, not on "pass" or "fail."
The 2 MISS are criteria 3 and 6, both above. The 6 PASS are criteria 1, 2,
2b and 2c on the shipped tree (confirmed by the mutation log above),
criterion 7 (peak `tileBytes` 27262976 bytes = 26.00 MiB against ≤ 96 MiB),
and criterion 8 (`capacityMiB` exactly 192.00 in every configuration, no
increase to explain).

**Plan 3i inherited three things, named here so no future session has to
reconstruct them — and 3i is now done, so each carries its outcome:**
1. **G3 — zoom and level-of-detail geometry** — renumbered onto 3i by Task 8a.
   **3i's spec DECLINED it**; G3 is still open and now blocks nothing. See
   [Plan 3i](#plan-3i--done-14-of-14-exit-gate-9-of-11).
2. **Settling criterion 3**, by re-measuring at **n=7–9, interleaved
   (narrow, M4, narrow, M4, …), not blocked (three-then-three)** — the only
   arrangement that removes the thermal/session-drift ordering bias this
   task's own numbers show biased the ratio *against* the miss, not for it.
   **Done as 3i's criterion 8, at n=9: median 2.328, mean 2.407, range 1.693
   to 3.088. It MISSES, and the finding is that the gate sits inside the
   measurement's own noise, so no sample size settles it.**
3. **Plan 3j** owns the **192 MiB vertex buffer**, whose figure sits on a
   doubling boundary with no headroom. **Still open — 3i did not touch it.**

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
