# Plan B (joins and hairlines) — results of record

**Date:** 2026-08-30. **Branch:** `plan-b/joins-and-hairlines`, cut from
`main` at `5c94e11` — the commit that wrote Plan B's own plan document,
one commit after `cd5bc98`, Plan A's merge into `main`. **The exit gate is
10 of 11. Ten criteria pass. Criterion 11 is UNMET, in those words**: the device run
happened, but no human looked at the running window. Plan 3h's session
established looking at the window as this project's third instrument, and it
was the only one that found any of that session's four defects — a green
suite and passing numbers do not stand in for it. **Put "a human must still
look at the window" at the top of the gaps list.**

Two more things need saying before any number: **macOS Low Power Mode was
OFF** (`pmset -g | grep lowpowermode` → `lowpowermode 0`, read immediately
before the run below), and **the rebuild budget MISSES**, at 79.6 ms against
16.67 ms, for a reason that is a hypothesis, not a fact — see below.

---

## The device run

```
cd apps/dev_harness_2d
flutter run -d macos --profile --dart-define=RUN_GPU_SPIKE=true \
  --dart-define=ENTITIES=10000 --dart-define=SPIKE_DEFS=20 \
  --dart-define=SPIKE_INSTANCES=150 --dart-define=SPIKE_FRAMES=30 \
  --dart-define=SPIKE_REPEATS=3
```

Viewport 1400x900 logical (the harness's own default — no `JC_WINDOW`
override). Corpus: `spikeDocument()`, `DASHED` at its default 0.35,
`labelFraction: 0` (no text entities; text is Plan E's). Three interleaved
repeats, 30 frames per phase, 27 phase reports, `Application finished` in
44 s. Log kept at `/tmp/t11-gspike.log` and not reproduced verbatim in full
here; every number below is transcribed from it and independently
recomputed, not copied from a prior claim.

**This run was performed once, by the human running this task, and is not
re-run here** — two earlier attempts in this session stayed attached to
`flutter run` for 11.5 hours because the command never exits on its own.

---

## Headline result 1 — the buffer: PASSES, and it is the plan's number

```
GSPIKE collect+upload: walk 5.7 ms, total 79.6 ms, instances=109068,
buffer=4.99 MB, skippedOps=0
```

**4.99 MB against the spec's ≤ 8 MB budget (all kinds plus the resident text
list) — PASS**, with 3.01 MB of headroom.

**What grew, and the arithmetic.** Plan A measured **2.06 MB at 59,875
segments, strokes-only**. Three things changed:

1. **The record went 10 floats to 12** (`kFloatsPerInstance`). A join now
   carries a vertex and both its neighbours where a stroke carries two
   endpoints (`instance_record.dart`'s doc: *"Ten became twelve in Plan
   B"*). That alone is a 1.2x multiplier on any fixed instance count.
2. **Joins roughly doubled the instance count.** 59,875 → 109,068 instances
   is 1.821x. Plan B emits a join instance at every interior vertex (plus
   the seam join on a closed run), and this corpus's polylines are mostly
   short chains, so the join:segment ratio is close to 1:1 — consistent with
   "roughly doubled."
3. **Circles, arcs and points are now collected where Plan A skipped them.**
   Plan A's collector implemented only `polyline`; `circle`, `arc` and
   `point` all fell through to `skippedOps`. They do not on this corpus —
   `skippedOps=0` (see the caveat below) — so their flattened chords and
   join instances are inside the 109,068.

Combining (1) and (2) predicts a 1.2 × 1.821 = **2.19x** buffer growth from
Plan A's own formula. **The observed growth is 4.99 / 2.06 = 2.42x** —
higher than that product predicts. The reason is not fully attributable:
Plan A's own note (`2026-08-29-gpu-arm-10k-measurement.md`) records
`buffer=2.06 MB` at `segments=59875`, but that count times the old
`kFloatsPerInstance=10` times 4 bytes is 59,875 × 10 × 4 = 2,395,000 bytes =
**2.28 MiB, not 2.06 MB** — a ~10% discrepancy in Plan A's own record that
this note does not resolve, only carries forward rather than silently
papering over. **This run's own arithmetic checks out exactly**: 109,068 ×
12 × 4 = 5,235,264 bytes = 4.9926 MiB, which rounds to the 4.99 MB the
harness printed.

**`skippedOps=0` means the collector was not asked to skip anything on this
corpus — it does not mean fills and text are covered.** This corpus has
`labelFraction: 0` (no text) and no fill entities; `fillPolygon`,
`fillCircle` and `text` remain Plan D's and Plan E's jobs, entirely
unexercised by this run.

**Collinear degenerate joins (Ruling B4's stated cost): 0 on this corpus.**
The harness did not count them, so a diagnostic-only counter,
`GeometryCollector.debugCollinearJoins`, was added
(`packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart`,
committed at `72b938a`) — `debug`-prefixed, read by nothing else in the
class, and it mirrors the shader's own degenerate predicate (`cross_z ==
0.0 || in_len == 0.0 || out_len == 0.0`, transcribed at
`test/support/instance_expander.dart`) in collection-space `double`
arithmetic, purely as a count. **This count is a property of the corpus's
geometry, not a timing, so it was measured off-device**: a temporary,
never-committed test rebuilt the exact same corpus (`ENTITIES=10000
SPIKE_DEFS=20 SPIKE_INSTANCES=150`, the harness's default 1400x900
viewport, the same fit camera) through `GeometryCollector` and printed

```
PROBE entities=10000 viewport=Size(1400.0, 900.0) instanceCount=109068
skippedOps=0 debugCollinearJoins=0
```

`instanceCount=109068` and `skippedOps=0` match the device run's own printed
line exactly, which is the evidence this off-device reconstruction is
faithful rather than a different corpus that happens to look similar. Zero
collinear joins is unsurprising on this corpus: `generateDocument`'s
entities are rectangles and rotated/mirrored instances of them, and a
circle's or arc's flattened chords turn by a constant nonzero angle by
construction — there is no source of an exactly-straight three-point run in
this generator. **A corpus built to exercise this path (a polyline whose
interior vertex is deliberately collinear) would read nonzero**; two such
fixtures now exist as unit tests (`geometry_collector_test.dart`,
"debugCollinearJoins counts a straight-through vertex..." and "...an exact
reversal too") and pin the counter's own correctness independent of this
corpus reading zero.

---

## Headline result 2 — the rebuild: MISSES, and the cause is a hypothesis

```
walk 5.7 ms, total 79.6 ms
```

**79.6 ms total against the spec's ≤ 16.67 ms budget (one frame, on the
platform thread) — MISS, by 4.8x.**

**The most likely explanation, stated as a hypothesis and not scored as a
pass on its strength.** Plan A's own design note records: *"native shows the
same shape (82.3 ms first run, 6.5 ms warm)"*
(`docs/superpowers/specs/2026-08-29-gpu-resident-render-backend-design.md:411`,
in the context of shader-library load and pipeline creation being a large
one-time constant, not a per-byte cost). 79.6 ms sits almost exactly on
82.3 ms's shape. If this run's 79.6 ms is that same cold, one-time
pipeline-creation cost — paid once per process, not once per rebuild — then
a warm rebuild in this same session would likely read closer to single
digits.

**But only one rebuild happened in this run**, because `GpuSpikeState`
calls `_buildResidentGeometry` exactly once, in `initState`'s post-frame
callback, and the harness does not trigger a second document walk during
the run. **No warm figure exists. This is recorded as a MISS with its
number, not excused by Plan A's warm figure, which measured a different
build under different code.** "No warm rebuild was measured" is on the gaps
list below.

**A second, separate thing is also unexplained, and this note does not
invent an explanation for it.** The **walk** portion (the document traversal
and buffer fill, before `ResidentGeometry.create`'s upload) reads **5.7 ms
here**, against **Plan A's 14.7 ms** on what the corpus knobs describe as
nominally the same size (`ENTITIES=10000`, same `SPIKE_DEFS`/`SPIKE_INSTANCES`).
This run emits **more** instances (109,068 against 59,875) for **less** walk
time — a 2.6x divergence in the wrong direction for an "it got slower
because it does more work" story. Candidates that were not investigated
here include JIT/AOT or optimization differences between the two
measurement sessions, machine-state drift, and the possibility that Plan
A's 14.7 ms itself included work this run's 5.7 ms does not (the two
sessions are ten commits and one shader rewrite apart) — none of these is
confirmed. **Recorded as unexplained, not diagnosed.**

---

## Headline result 3 — arm C's gesture timings: PASS

**Aggregation rule, pre-committed and not moved: median of the three
per-repeat p50s, per stage, then summed** where a sum is reported; a bare
median where the spec's budget is itself a bare p50 or p95.

Recomputed independently from `/tmp/t11-gspike.log`, not taken on trust:

| phase | stage | repeat 1 | repeat 2 | repeat 3 | median | budget | verdict |
|---|---|---|---|---|---|---|---|
| zoom | build p50 | 0.21 | 0.51 | 0.62 | **0.51** | ≤ 1.2 ms | **PASS** |
| zoom | raster p50 | 0.20 | 0.62 | 0.67 | **0.62** | ≤ 2.0 ms | **PASS** |
| zoom | raster p95 | 0.31 | 0.75 | 0.94 | — | ≤ 3.0 ms (each) | **PASS**, all three |

(Budgets: `docs/superpowers/specs/2026-08-29-gpu-resident-render-backend-design.md:428-431`,
"gesture frame p50 ≤ 1.2 ms build, ≤ 2.0 ms raster" and "gesture frame p95
raster ≤ 3.0 ms".)

The same spec passage anticipated this exact risk and said in advance that
it might not survive: *"joins roughly double the instance count... The build
budget is 2x the measured figure and the raster budget 3.2x, and those
multiples are the whole margin — if joins and antialiasing consume them,
the criterion misses and is recorded as a miss."* Joins did land, roughly
doubling the instance count as predicted (buffer result above), and the
gesture-frame criteria **still pass**, with margin (0.51/1.2 = 2.35x
headroom on build, 0.62/2.0 = 3.2x on raster). Antialiasing has not landed
(Ruling B3, below), which is part of why the raster margin held.

For completeness, hold and pan (not gated by the exit criteria above, but
part of the same run):

| phase | stage | median build | median raster |
|---|---|---|---|
| hold | — | 0.15 | 0.57 |
| pan | — | 0.60 | 0.70 |

**`hold | gpu submits=0 of 30 frames`, in all three repeats.** This is the
arm working, not a defect: `GpuArmPainter` is built with `repaint: camera`
(a `Listenable`), and a hold phase does not move the camera, so Flutter
never calls `paint()` and `GpuDrawBackend.render` is never reached —
`GpuDrawBackend.frames` (the submit counter) never increments. Arm C's
steady-state idle cost is not "small," it is **zero draw calls**: the small
nonzero hold build/raster figures above (0.15/0.57 ms) are other widget-tree
and frame-pipeline overhead, not this arm's paint path. Contrast arms A and
B, whose hold raster stays nonzero throughout (≈4.8–5.0 ms and ≈1.06–1.29 ms
respectively) — arm A re-walks the whole document every frame regardless of
camera change, and arm B still pays a composite-blit cost every frame; only
arm C can go to true zero when nothing moved.

---

## The exit gate — scored, criterion by criterion

1. **The resident arm draws the reference drawing (pixel differential,
   coverage-only): PASS.** `resident_pixel_differential_test.dart`,
   `the resident arm draws the reference drawing` — asserts
   `referenceInk > 5000` and `residentInk > 5000` (the anti-vacuity floor),
   `differing < referenceInk / 100` (the spec's own 1%-of-ink criterion),
   **and** a tighter absolute bound, `differing < 4`, sized against the
   smallest named-mutation kill on record (M-B3' at 14). All three
   assertions pass in the current suite (`flutter test`, this task,
   477 passed / 1 pre-existing skip). At Task 9's own recording, this
   corpus reads `referenceInk: 8183, residentInk: 8183, differing: 0`.
   **Coverage-only, stated plainly**: `TriangleRasterizer.inked` is a
   boolean per pixel; the per-channel colour half of spec criterion 1 is
   **not** measured by this instrument (see "What was not measured" below).
2. **Emission order holds within an entity: PASS.** Join-before-segment and
   seam-last are each asserted on all three shapes named:
   `geometry_collector_test.dart` — `an open three-point run is
   join-before-segment, and nothing else` (open run), `a closed run emits
   the closing segment and then the seam join` (closed run), `a circle is a
   closed run: N chords, N joins, seam last` (flattened circle). All three
   pass in the current suite.
3. **The seam join is load-bearing: PASS.** `resident_pixel_differential_test.dart`
   — `the seam join is load-bearing on the circle` asserts, first, that the
   differential against the reference stays near zero on the closed draw
   (so a dropped or misplaced seam disagrees with the reference itself, not
   just with a self-consistency probe), and second, as a supplementary
   check, that the same circle inks more closed than as the equivalent open
   run of chords. Passes. M-B3 (skip the seam join) and M-B3' (the same,
   fired against the pixel differential) both die on this gate.
4. **Half-width is invariant under the transform: PASS.**
   `instance_expander_test.dart` — `half-width does not scale with the
   transform`: under a 5x scale, the centreline moves 5x (`closeTo(500,
   1e-3)`) while the quad stays exactly as wide as it was built (`closeTo(8,
   1e-3)` — the 4-half-width stroke's full width). **Correction to how this
   criterion was described going in**: no separate "3x arm" was added to
   the pixel differential in Task 10 Step 2. That step's own brief made
   adding one *conditional* on M-B10 (emit joins at collection width
   instead of device width) surviving at the comparison's existing
   transform; it did not survive — the suite's own `devicePixelRatio: 2.0`
   already gives `scaleMagnitude == 2.0`, not identity, and M-B10 died
   decisively (`differing: 95` and `differing: 552` against bounds of 81
   and 4) on the very first firing. A throwaway, never-committed probe at
   `devicePixelRatio: 1.0` independently confirmed the mutation is a
   genuine no-op at true identity (`differing: 0`), which is what makes the
   suite's dpr-2.0 default — chosen for other reasons — the thing that
   actually protects this path. No 3x arm exists in the committed suite;
   the record-level 5x test plus the dpr-2.0 pixel-level kill are the gate.
5. **Sub-pixel fade behaviour: PASS, all three states.**
   `geometry_collector_test.dart` — `a sub-pixel stroke keeps its pixel and
   gives up alpha`, `a stroke at or above one device pixel keeps full
   alpha`, `a zero lineweight is the hairline case and keeps full alpha`.
   All three pass.
6. **`point()` is its own kind, square at every scale: PASS.**
   `instance_expander_test.dart` — `a point expands to a square of the
   stroke width` (record level, identity transform: a 6x6 square around
   its centre for `halfWidth: 3`). Record-level kind is separately gated by
   `geometry_collector_test.dart`'s point tests and `collector_differential_test.dart`.
   At the pixel level, under the suite's non-identity `devicePixelRatio:
   2.0`, M-B8 (point drawn as a zero-length capped stroke instead of its
   own kind) is killed with `differing: 16`, and the mutation log's
   derivation shows the wrong-kind geometry is a **7.56×3.78** device-pixel
   rectangle where the correct arm draws a **3.78×3.78** square — direct
   pixel evidence the square shape, not just its area, is what is being
   checked, at a real (non-identity) scale.
7. **`skippedOps` counts exactly `fillPolygon`, `fillCircle` and `text`:
   PASS.** `geometry_collector_test.dart` — `after Plan B, only fills and
   text are skipped`: four Plan-B ops (`polyline`, `circle`, `arc`, `point`)
   leave `skippedOps` at 0; the three remaining ops each increment it by
   exactly one, ending at 3.
8. **Resident geometry ≤ 8 MB at 10,000 entities: PASS.** 4.99 MB — see
   Headline result 1 above.
9. **The bundle carries an OpenGL ES 100 stage, verified by decode: PASS.**
   Task 7 (commit `d7499db`) rebuilt `assets/shaders/cad.shaderbundle` after
   the shader learned the join/point branches and verified it with a
   byte-level check, not `strings`: a Python script counted literal
   `#version 100` / `#version 120` / `#version 300 es` byte sequences in
   the compiled bundle and found **two** `#version 100` occurrences (one
   per entry point) and both entry-point names (`CadStrokeVertex`,
   `CadStrokeFragment`) present. Verified again here:
   `shasum -a 256 packages/jet_cad_2d_flutter/assets/shaders/cad.shaderbundle`
   → `0a7b07b44cdf2cffacb789a5aa8912fbbf6d084b2c980cd3c5a6c08d666cadcf`,
   matching Task 7's committed hash exactly, and `git log` confirms the
   file has not been touched since that commit. **A caveat carried
   forward, not resolved here**: this is a targeted byte-pattern check
   (searching for the specific version-pragma bytes), stronger than a bare
   `strings | grep attribute` count (which Plan A's Task 4 found conflates
   the ES-100 and desktop-120 stages) but not a full structured
   flatbuffer/vtable decode. Plan A's Task 4 reviewer separately proved the
   schema mapping once, for the original bundle — `Shader` vtable slot 10
   is `openglEs` — by hand-decoding the flatbuffer against
   `flutter_scene-0.23.0`'s generated bindings. That proof was not repeated
   against this plan's rebuilt bundle; Task 7's byte-pattern evidence is
   what stands for it here.
10. **All ten pre-committed mutants accounted for: PASS, and exceeded.**
    `docs/superpowers/notes/plan-b-mutation-log.md`'s summary table:
    M-B1 through M-B10, the plan's own pre-committed list
    (`docs/superpowers/plans/2026-08-30-gpu-backend-plan-b-joins-and-hairlines.md:2604-2615`),
    are every one accounted for — all ten killed with a transcript. M-B3
    ("skip the seam join") was tried as two arms: deleting the whole
    `if (_runSegments >= 2) { _emitJoin(...); }` statement is the actual
    mutation and it dies (both closed-run instance-count tests go 6→5); a
    narrower reading — deleting only the guard and leaving the call
    unconditional — was also tried and found an **equivalent mutation, not
    a survivor**: the log proves, from `_runHasDirection`'s invariant and
    `sqrt`'s evenness, that no input can ever reach that guard with fewer
    than two accepted segments, so deleting it changes the output of no
    program on any input — not a coverage gap, a dead-code fact.
    **Beyond the ten**: five more mutants (M-B11–M-B15) were added during
    execution by implementers and reviewers and are all dead, and one
    (M-B1, re-fired against the pixel instrument as M-B1') is a **declared,
    structural survivor** — `TriangleRasterizer.inked` is coverage-only, and
    `_coveredArgb`'s effect is a colour fade the pixel instrument cannot
    see by construction, predicted before firing and gated instead at the
    record level. Fifteen named mutants total, eighteen firings, sixteen
    dead, one equivalent, one declared survivor with a structural reason —
    strictly more than criterion 10's literal "ten," not less.
11. **The device run happened AND the window was looked at: UNMET.** The
    device run happened — the log above is real, 27 phase reports, three
    repeats, `Application finished`. **No human looked at the window.**
    Nobody checked whether corners are filled, whether the circle is
    notched at its start angle, whether the dot is square, or whether
    anything thickens under zoom. Plan 3h's session established looking at
    the running window as this project's third instrument — mutation
    testing and differential testing are the other two — and it was the
    only one of the three that found any of that session's four defects.
    **A passing gate on the other ten criteria is not evidence for this
    one**, and this note does not score it as passed on that strength.

**Gate: 10 of 11. Criterion 11 UNMET.**

---

## Ruling B2's consequence, stated plainly

**Caps are butt caps. Plan B emits no cap geometry.** `ResolvedStyle`
carries no cap style at all, so no cap other than "nothing" is reachable
from the document model; Task 4's instance-count tests assert an open run
produces exactly *segments + interior joins* and nothing more, which would
go red the day cap geometry appears without a cap style to justify it.
**Consequence for the spec's exit gate**: its criterion 8 corpus
requirement — *"containing text, fills, joins, caps, dashes and
antialiasing"* — is satisfied **vacuously** on the caps term by this plan.
There is no cap to test because there is no cap style to draw.

## Ruling B3's consequence, stated plainly

**The resident arm is hard-edged. Antialiasing is not Plan B's.** Spec
criterion 1 compares against `VerticesDrawSink`, which submits
`Vertices.raw` through `drawVertices` with `BlendMode.dst` and per-vertex
colours — no antialiasing path exists in that file at all. At this corpus's
one-to-two device-pixel stroke widths, edge pixels are most of the ink, so
a fragment coverage fade would diverge from the hard-edged reference by up
to 255 per channel on most inked pixels and fail criterion 1 outright.
**The spec's own budget discussion assumed antialiasing would be consuming
headroom by now** (`"if joins and antialiasing consume them, the criterion
misses"`) — it is not, which is part of why Headline result 3's raster
margin held as well as it did. Antialiasing only becomes possible once
something other than the hard-edged reference sink is the oracle.

---

## What was NOT measured

- **No warm rebuild.** Exactly one document walk happened in this session;
  79.6 ms is either a genuine per-rebuild cost or a one-time
  pipeline-creation cost paid once per process — this run cannot
  distinguish the two, and the hypothesis above is not scored as settled.
- **No web run.** This plan's entire measurement is native macOS profile.
  The spec's web rebuild budget is explicitly unmeasured pending a plan
  that runs there.
- **No text.** `labelFraction: 0` on this corpus; `GeometryCollector.text`
  still only increments `skippedOps`.
- **No fills.** `fillPolygon` and `fillCircle` still only increment
  `skippedOps`; this corpus contains neither call.
- **No dashes drawn through this arm's dash-specific path.** Dashed
  *polylines* reach the collector as ordinary `polyline` spans and draw
  today, but they are baked at the collection camera and never re-split
  under zoom (a direct consequence of walking the document exactly once) —
  not measured or scored here, and dashed *arcs* remain Plan C's.
- **No per-channel colour comparison in the pixel differential.**
  `resident_pixel_differential_test.dart` uses `TriangleRasterizer`, whose
  `inked(x, y)` is a boolean coverage test with no partial coverage and no
  colour read at all (`gpu_comparison.dart`'s own module doc). Colour
  correctness — including `_coveredArgb`'s alpha fade, which the declared
  survivor M-B1' exists precisely because this instrument cannot see — is
  gated separately, at the **record** level, by
  `geometry_collector_test.dart`'s alpha assertions and by
  `collector_differential_test.dart`'s `_referenceCoveredArgb` comparison
  (a second, independent reproduction of `VerticesDrawSink._coveredArgb`,
  added in Task 9 specifically to give this half of criterion 1 a witness
  the pixel instrument cannot provide).
- **The pixel instrument's structural blind spot: it cannot see geometry
  added inside a footprint already inked by something else.**
  `plan-b-mutation-log.md`'s "The instrument's structural blind spot"
  section proves this via M-B7 (every join wedge built on the *wrong* side
  of its corner) against M-B15 (no join ever emitted, at all): both
  produced the **identical** reading on both the corpus and seam tests —
  `differing: 26` and `differing: 178` respectively — because both satisfy
  `differing == referenceInk - residentInk` exactly: the resident set is a
  pure subset of the reference's in both cases. A wrong-side wedge sits
  entirely inside ink the two adjacent segment quads already cover, so it
  contributes zero *new* ink and reads as indistinguishable from no wedge
  at all. **This instrument therefore cannot catch a join emitted on both
  sides of a corner, a duplicated instance sitting on an existing one, a
  segment quad that overshoots into its neighbour's, or a miter tip that
  over-reaches inward without crossing outside the existing outline.** None
  of Plan B's own mutations needed such a witness to be caught, but a later
  plan reusing this instrument for new geometry should not read a passing
  `ResidentAgreement` as proof no interior-overlap defect exists.
- **The unexplained walk divergence** (5.7 ms here against Plan A's 14.7 ms
  on a nominally same-size corpus, while emitting more instances) is
  recorded above and not diagnosed.
- **Ruling B4's collinear-join cost was measured at 0 on this corpus** by
  construction of the generator, not because collinear joins are rare in
  general — see Headline result 1.
- **A human has not looked at the window.** Repeated here because it is the
  gate's own UNMET criterion, not a footnote.

---

## The shader bundle

`packages/jet_cad_2d_flutter/assets/shaders/cad.shaderbundle`,
SHA-256 `0a7b07b44cdf2cffacb789a5aa8912fbbf6d084b2c980cd3c5a6c08d666cadcf`,
last written at commit `d7499db` (Task 7) and unchanged since — confirmed by
`git log -1 -- assets/shaders/cad.shaderbundle` returning that same commit
and a fresh `shasum -a 256` matching Task 7's recorded hash exactly.

---

## The final gate, all three packages

```
$ cd packages/jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
...
00:02 +797: All tests passed!
Analyzing jet_cad_2d...
No issues found!
Formatted 113 files (0 changed) in 0.16 seconds.
exit=0

$ cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
...
00:06 +477 ~1: All tests passed!
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.8s)
Formatted 89 files (0 changed) in 0.14 seconds.
exit=0

$ cd apps/dev_harness_2d && flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
...
00:12 +72: All tests passed!
Analyzing dev_harness_2d...
No issues found! (ran in 1.0s)
Formatted 17 files (0 changed) in 0.08 seconds.
exit=0
```

`jet_cad_2d_flutter`'s 477 passing / 1 skipped: the pre-existing `rig`-tagged
skip (`test/rig/paint_microbench_test.dart`), unrelated to this plan, present
before Plan B started.

`git status --short` was checked before every commit in this task; no
`analysis_options.yaml` appeared at any point.

---

## Commits

- `72b938a` — the harness note fix and the `debugCollinearJoins` counter
  (`apps/dev_harness_2d/lib/gpu_arm.dart`,
  `packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart`,
  `packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart`).
- This document and the `STATUS.md` update that follows it.

Plan B's range on this branch, `5c94e11..72b938a`, covers every task's
code and tests; this document and the `STATUS.md` update are the commits
after it, documentation only, per this project's own convention that a
range's endpoint is the last *code* commit. Not merged into `main`.
