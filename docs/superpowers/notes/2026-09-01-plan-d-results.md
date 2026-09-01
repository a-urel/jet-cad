# Plan D — fills: results

**Plan:** [2026-09-01-gpu-backend-plan-d-fills.md](../plans/2026-09-01-gpu-backend-plan-d-fills.md).
**Spec:** [2026-08-29-gpu-resident-render-backend-design.md](../specs/2026-08-29-gpu-resident-render-backend-design.md)
(revision 4), the "Fills" section.
**Mutation log:** [plan-d-mutation-log.md](plan-d-mutation-log.md).
**Branch:** `plan-d/fills`, cut from `main` at `bde9196`.
**Ledger (per-task briefs, reports and review diffs):**
[.superpowers/sdd/2026-09-01-gpu-backend-plan-d-fills/](../../.superpowers/sdd/2026-09-01-gpu-backend-plan-d-fills/)
(git-ignored; archive it onto the branch before the workspace is deleted, per
every earlier plan's own recorded lesson).

**What Plan D shipped**: the fill kind (`kKindFill = 3`) and its writer
(`writeFill`), `fillPolygon` (pre-triangulated) and `fillCircle` (fanned at
its own outline's step count) in `GeometryCollector`, the shader's fill
branch and its Dart transcription (`test/support/instance_expander.dart`),
the `_coveredArgb` exclusion (a fill never fades on a hairline layer), the
order gate that proves walk order is load-bearing for a fill drawn under a
later stroke, and (this task) fills in the dev harness corpus and the
resident buffer's size measured with fills present.

---

## What this plan's own premises measured false

Three places, none of them silently absorbed:

1. **Task 4's brief specified `lineweightHundredths: 60` for the two
   strokes the record-level overlap guard needs to cross a fill.** That
   gave only **172 device pixels** of overlap, under the 200-pixel floor
   the guard checks. The implementer raised both strokes to `120` and
   re-measured **337 device pixels** — the plan's own literal was wrong,
   and the guard is what caught it before it shipped as a vacuous check.
2. **Task 5's brief predicted the compiled shader bundle would show the
   string `attribute ` exactly 8 times.** The real count is **16
   occurrences of 8 unique attribute names** — this repo's bundle embeds
   the shader source twice. The reviewer verified this independently by
   extracting and enumerating both copies (`kind_half, p0, p1, corner, p2,
   join_weight, color, dash`). The check itself stands; its expected number
   was corrected from 8 to 16 (Ruling D-5a).
3. **Task 7's brief supplied a sample test loop with a lock-in bug.** It
   tracked `lastFill` correctly but latched `strokeAfterFill` onto the
   *first* stroke seen after *any* fill rather than the last stroke in the
   corpus, because `AddRegionCommand.apply` draws a region's boundary as
   its own independently-visible entity immediately after the fill —
   "fill, then its own outline" is not "fill, then nothing else, then the
   next primitive." Run verbatim it failed (`Expected: a value greater
   than <58> / Actual: <3>`) against a real, correctly-ordered corpus. The
   implementer fixed the loop to scan for the *last* stroke and documented
   why in place — the underlying property (`strokeInkInsideFill`'s 337-pixel
   overlap, above) was independently already true; only the sample loop's
   ability to see it was wrong.

None of these three needed a threshold moved. Each is a correction to a
number or a loop the plan itself supplied, found by running it rather than
reading it — the failure mode this project's mutation-and-differential
testing bar exists to catch, this time catching the plan's own prose before
it reached a gate.

---

## What was measured in `flutter test`

All of the following were re-run for this task's report, from the fully
merged Plan D tree on `plan-d/fills` — not read off an earlier task's
report — except where a number is explicitly attributed to an earlier
task's own measurement.

### Criterion 1 — record-level differential, fill corpus (exact)

`collector_differential_test.dart`: "the fill fixture -- every instance's
kind, argb and three points match the reference's triangle stream, in
order" — **PASS**, part of the file's 4/4 green run:

```
$ flutter test test/gpu/collector_differential_test.dart
00:00 +0: emits every polyline segment the painter walks, in the same order, with the residual applied and half-width scaled by dpr
00:00 +1: fades a hairline stroke exactly as the reference sink does, not just strokes above the floor
00:00 +2: fades a hairline stroke by lineweightScale as well as by dpr, not just the identity default every other gate in this file exercises
00:00 +3: the fill fixture -- every instance's kind, argb and three points match the reference's triangle stream, in order
00:00 +4: All tests passed!
```

### Criterion 2 — pixel differential, colour (fill corpus and stroke corpus both)

`resident_pixel_differential_test.dart` gates both corpora at
`withinTwoFraction >= 0.995` and `overEight == 0`. Both pass; the exact
figures, from Task 6's own measurement (stroke corpus) and a fresh
temporary-`print` capture for this task (fill corpus, reverted before
commit — `git diff` empty afterward):

| corpus | union | withinTwo | overEight | referenceInk |
|---|---|---|---|---|
| stroke (Task 6) | 8,183 | 8,183 (**100.000%**) | 0 | 8,183 |
| fill (this task, re-measured) | 393,051 | 393,051 (**100.000%**) | 0 | 393,051 |

```
$ flutter test test/gpu/resident_pixel_differential_test.dart
00:00 +0: the resident arm draws the reference drawing
00:00 +1: the seam join is load-bearing on the circle
00:00 +2: the two arms agree per channel, not merely on coverage
00:00 +3: the colour measurement can actually fail
00:00 +4: the fill corpus agrees per channel
00:00 +5: All tests passed!
```

### Criterion 3 — anti-vacuity

`referenceInk` reads 8,183 (stroke corpus) and 393,051 (fill corpus), both
`> 5000`. The instrument's own control arm, `debugTintResident`, reads
`withinTwoFraction = 0.000%` (Task 6's measurement) — well below the 0.995
gate, so a broken instrument that always passed would be caught.

### Criterion 4 — spec criterion 4: kind-sorted vs. walk-ordered

From Task 7's own measurement (`fill_order_test.dart`), re-confirmed green
in this task's full suite run:

```
submitting the buffer out of walk order changes the rendering: differing = 9297 (gate: > 200)
unpermuted (walk order):        ResidentColorAgreement(union: 393051, withinTwo: 393051 (100.000%), overEight: 0, referenceInk: 393051)
permuted (sortByKind):          ResidentColorAgreement(union: 393051, withinTwo: 383754 (97.635%), overEight: 9297, referenceInk: 393051)
```

**PASS**: the resident arm matches the reference exactly in walk order
(100.000%, gate `>= 0.995`) and **fails to** match under the kind-sorted
permutation (97.635% `< 0.995`) — proving draw order, not merely draw
content, is what the buffer's walk order protects.

### Criterion 5 — `skippedOps` counts text alone, on the fill corpus

`geometry_collector_test.dart`: "counts the ops it does not draw instead of
dropping them silently" asserts `c.skippedOps == 1, reason: 'only text is
skipped now'`; "a fill polygon is one instance per triangle, in
triangulation order" asserts `c.skippedOps == 0, reason: 'a fill is drawn
now, not counted'` on a fill-only corpus. Both pass, part of the file's 52/52
green run (`+52: All tests passed!`). This task's own buffer measurement
(below) confirms the same on a full 10,000-entity, fills-on corpus:
`skippedOps=0` — no text is present in the harness spike corpus at all
(`labelFraction: 0`), so there is nothing for `skippedOps` to count.

---

## Criterion 6 — the resident buffer, measured on the CPU

**This is not a device run.** `GeometryCollector` builds the buffer that
would be uploaded to the GPU entirely on the CPU; `ResidentGeometry.create`
(the upload) is the only step not taken, and it does not change the
buffer's byte length, only where the bytes live. The number below is
exactly what `--dart-define=RUN_GPU_SPIKE` would report on a device,
obtained without a device.

**Method**: `apps/dev_harness_2d/test/fill_buffer_budget_test.dart` (new,
this task). It calls `spikeDocument(entityCount: 10000, fillsEnabled: true)`
— the same corpus builder `GpuSpikeState._buildResidentGeometry` uses in
`gpu_arm.dart` — then makes the same three calls that method does, up to
and not including `ResidentGeometry.create`: builds a `SpatialIndex`, fits
`ViewportTransform` to the document's extents, walks it through
`DraftPainter` into a `GeometryCollector`, and reads `collector.data`.

**This test is measured against the testing bar, not merely asserted.** Its
`expect(fills, greaterThan(0))` guard was fired: `main.dart`'s
`spikeDocument` was mutated so `_addFillRegions` never runs
(`if (false && (fillsEnabled ?? kSpikeFills)) _addFillRegions(doc, count);`),
`flutter test test/fill_buffer_budget_test.dart` then failed with
`Expected: a value greater than <0> / Actual: <0>` on that exact assertion,
and the file was restored from a `/tmp` backup (`git status --short` clean
afterward) — this is the guard against `SPIKE_FILLS` (or the fill path
behind it) silently going dark and the buffer measurement staying vacuous
about the one thing this task adds. The companion guard,
`expect(other, 0)` (every instance must carry a known kind tag), was not
independently fired this round — it would need a mutation inside
`GeometryCollector`/`instance_record.dart` rather than in the harness, which
is a real mutation to try but wasn't; it is reported here as untested rather
than as either killed or unkillable.

Reproducible two ways:

```sh
cd apps/dev_harness_2d
# Default knobs (SPIKE_DEFS=20, SPIKE_INSTANCES=200 -- spikeDocument()'s own defaults):
flutter test test/fill_buffer_budget_test.dart

# Matched to Plan C's own device-run parameters, for a direct comparison:
flutter test test/fill_buffer_budget_test.dart \
  --dart-define=SPIKE_INSTANCES=150 --dart-define=SPIKE_DEFS=20 --dart-define=DASHED=0.35
```

Verbatim output, both runs:

```
PLAN-D buffer: entities=10280 (requested 10000) instances=114717 (strokes=65469 joins=49088 points=0 fills=160) skippedOps=0 bytes=7341888 (7.00 MB) budget=8.00 MB margin=1046720 bytes
```

```
PLAN-D buffer: entities=10280 (requested 10000) instances=106636 (strokes=60798 joins=45678 points=0 fills=160) skippedOps=0 bytes=6824704 (6.51 MB) budget=8.00 MB margin=1563904 bytes
```

`entities=10280` on both runs: `spikeDocument` builds the base 10,000 and
`_addFillRegions` adds 200 rooms in `kFillFraction`'s (0.4) proportion — 80
filled (each an `AddRegionCommand` pair: a 4-edge boundary plus a
2-triangle fill, 160 fill instances total, matching `fills=160` on both
runs exactly) and 120 boundary-only, 280 entities in all.

### Against the budget, and against Plan C

| run | instances | bytes | MB | vs. 8 MB budget |
|---|---|---|---|---|
| default spike knobs | 114,717 | 7,341,888 | **7.00** | **PASS** — 1.00 MB margin |
| matched to Plan C's device params (`SPIKE_INSTANCES=150`) | 106,636 | 6,824,704 | **6.51** | **PASS** — 1.49 MB margin |
| Plan C, no fills, same matched params | 105,076 | 6,724,864 | 6.41 | PASS — 1.59 MB margin (recorded) |

**PASS. Fills add roughly 1,560 instances and 0.10 MB to Plan C's own
matched-parameter figure** (106,636 − 105,076 = 1,560; 6.51 − 6.41 = 0.10
MB) — 160 of those instances are the fills themselves (2 triangles per
filled room, 80 filled rooms), the remaining ~1,400 are the 120 unfilled
rooms' own boundary strokes and joins, which exist in this corpus only
because `_addFillRegions` adds them alongside the filled ones to exercise
both the fillable-and-filled and the fillable-but-not path. **The delta this
plan's fills add to Plan C's own measured buffer is small relative to the
6.41 MB baseline** and stays comfortably inside the budget at either set of
spike knobs measured here.

**This corpus is 160 fill instances out of 114,717 — 0.14% — and the PASS
above is a measurement of *that* mix, not of fills in general.** Ruling D7
records that a fill instance wastes ten of its sixteen floats — 40 of the
record's 64 bytes — and names Task 9, this measurement, as the way that
waste gets priced. At 0.14% of the buffer, the wasted floats cost about 6.25
KB here (160 × 40 bytes); a corpus with a materially higher fill fraction
would pay the same per-instance waste at a proportionally larger share of
the 8 MB budget, and this PASS says nothing about where that corpus would
land. Read the 6.51 MB and 7.00 MB figures as "fills at this corpus's fill
fraction fit," not as "fills fit."

`SPIKE_FILLS`'s own default (`false`) leaves `spikeDocument()` calling
`generateDocument` exactly as it did before this task, with no call to
`_addFillRegions` — every number any earlier plan took through this harness
stays reproducible unchanged.

---

## Criterion 7 — mutation testing

**12 of 12 pre-committed mutations fired; 11 killed on the first shot, 1
(M-D4) survived its first shot and was killed after a missing assertion was
added.** Full transcripts, diffs and verbatim `flutter test` output for
every mutation: [plan-d-mutation-log.md](plan-d-mutation-log.md).

| id | what it mutates | verdict |
|---|---|---|
| M-D1 | `fillPolygon` routes through `_coveredArgb` | KILLED |
| M-D2 | `fillCircle` routes through `_coveredArgb` | KILLED |
| M-D3 | shader fill branch adds `halfWidth` | KILLED |
| M-D4 | fill fold lands on `p2` instead of `p1` | **SURVIVED, then KILLED** (real coverage gap — see below) |
| M-D5 | fill/point shader branches swapped | KILLED (4 assertions) |
| M-D6 | `fillCircle` fans at `steps + 1` | KILLED |
| M-D7 | `fillPolygon` walks its triangulation backwards | KILLED |
| M-D8 | `fillPolygon` drops zero-area triangles | KILLED |
| M-D9 | the collector sorts its buffer by kind before returning | KILLED (3 assertions) |
| M-D10 | `writeFill` leaves `dashPeriod` unwritten | KILLED |
| M-D11 | `writeFill` writes `halfWidth: 1` | KILLED |
| M-D12 | `fillCircle`'s fan starts off-angle | KILLED |

**M-D4, in full.** The corner table (`ResidentGeometry.kCornerVertices`)
gives the fill fold triangle exactly one vertex wired to the `wm` weight,
added onto whichever of `wa`/`wb` also participates — so folding onto
*either* p1 (correct) or p2 (M-D4) makes two of that triangle's three
vertices literally coincide, and a triangle with two coincident vertices has
exactly zero signed area under both assignments, by the same algebraic
identity either way. The one test that existed, `'a fill expands to its
three corners and one degenerate triangle'`, checked only that area — a
genuine coverage gap, not an equivalent mutant: the value actually written
at the M vertex really does change (`a1` vs `a2`), the test just never read
it. Fixed by pinning the M-weighted vertex's raw position directly
(`positions[8]`, `positions[9]`) to `p1`'s known value — verified against
the *correct* code first (19/19 passed), then M-D4 re-applied and killed
this new assertion specifically (`Expected: ... 40 / Actual: 25.0`).

---

## What was NOT measured

- **No human has looked at the running window.** See below — Ruling D-9a of
  this task's own brief forbids simulating that step.
- **Text** (Plan E), **web** (Plan G), and **the `DraftCanvas` widget path**
  are all out of scope, per the plan's own self-review: `DraftCanvas` still
  renders `residentGpu` as `vertices` and needs Plan F's rebuild triggers
  before it can be wired to the real backend. The dev harness's GPU arm
  remains the only runtime consumer of fills through this backend.
- **The instrument's standing structural blind spot**, carried unchanged
  from Plan B: geometry added inside a footprint already inked by something
  else moves no pixel in a coverage-only comparison. The per-channel colour
  instrument (Task 6/7's `measureResidentColor`) narrows this for colour,
  but a same-colour overdraw is still invisible to any of this project's
  pixel instruments — not newly true of fills, but not newly false either.
- **No warm rebuild, no gesture-timing numbers for this plan.** Fills are
  static geometry with no per-frame branch of their own (a fill is never
  dashed, `kKindFill`'s own doc says so), so this plan did not re-run the
  gesture-phase measurement Plans B and C both took; nothing here suggests
  it would move, but that is a statement about what was not measured, not a
  result.

---

## The device run — OWED

**Not run in this session, and this session could not have run it.** This
task's controller ruling (D-9a) is explicit: the device run and the window
check are a human's work, not an implementer's, and this repository's
hardest rule is never writing down output that was not actually observed.
What follows names exactly what must happen and what to look for — a real
hole in this document, not a filled-in guess.

**The command in this task's own brief is incomplete for what this task
added, and this note says so rather than repeating it uncorrected.** The
brief's Step 3 command is byte-for-byte Plan C's own device-run command — it
does not pass `SPIKE_FILLS=true`, so run exactly as written it would draw
*no* fills at all and none of Plan D's five checks below would have
anything to look at. The corrected command:

```sh
cd apps/dev_harness_2d
flutter run -d macos --profile --dart-define=RUN_GPU_SPIKE=true \
  --dart-define=ENTITIES=10000 --dart-define=SPIKE_DEFS=20 \
  --dart-define=SPIKE_INSTANCES=150 --dart-define=SPIKE_FRAMES=30 \
  --dart-define=SPIKE_REPEATS=3 --dart-define=SPIKE_FILLS=true
```

**Confirm Low Power Mode is off before the run** (`pmset -g | grep
lowpowermode`) **and say so in whatever note records the run.** Plan C's
device run was contaminated by it and every timing in that note carries the
caveat; Plan D has not yet had a clean, uncontaminated device run of its
own.

---

## The window checks — OWED, fourteen across three plans

**One harness run, with the corrected command above, discharges all
fourteen.** None has been discharged as of this note.

### Plan D's five (this plan's own, all OWED)

1. A filled region is **filled**, not outlined and hollow.
2. The higher-handle stroke crossing it is **visible over** the fill, not
   hidden under it.
3. A filled circle's fill reaches exactly to its own boundary stroke at
   every zoom — no rim of background between them, no fill spilling past.
4. A fill on a hairline layer is **not faded**.
5. A translucent fill shows what is under it.

### Plan C's five, still owed since `18330a9`

1. Zoom in two stops: the dashes must get **longer**, and there must be the
   same number of them.
2. Zoom out until the dashes disappear into solid, at the same zoom on arm
   C as on arm A.
3. A dashed corner must be **notched**, not filled.
4. A dashed circle must be **notched** at its start angle.
5. Pan slowly along a long dashed line: the dashes must move **with** the
   line, not slide along it.

### Plan B's four, still owed since `72b162d`

1. Corners **filled** (a miter join, not a gap).
2. A circle **not** notched at its start angle (unlike a dashed one).
3. A `point()` draws a **square** dot.
4. **Nothing thickens** as you zoom in — no antialiasing has landed.

---

## Exit gate — 8 of 9

Pre-committed in the plan. A miss would be recorded as a miss with its
number; there is no miss to record — the one unmet row is OWED, not failed,
and stays that way until a human runs the harness.

**Criteria 1 through 4 are measured through the Dart transcription
(`test/support/instance_expander.dart`) plus `TriangleRasterizer`, not on a
GPU** — the same qualifier Criterion 6's buffer measurement carries above,
restated here because the table is read on its own.

| # | criterion | verdict |
|---|---|---|
| 1 | record-level differential, fill corpus, exact | **PASS** — `collector_differential_test.dart`, all instances match on `kind`, `argb`, three points |
| 2 | pixel differential, colour, fill corpus and stroke corpus both | **PASS** — both 100.000% within 2, `overEight = 0` |
| 3 | anti-vacuity | **PASS** — `referenceInk` 8,183 / 393,051, both `> 5000`; control arm 0.000% |
| 4 | spec criterion 4: kind-sorted vs. walk order | **PASS** — 100.000% in walk order, 97.635% under permutation (`< 0.995`), differing = 9,297 (gate `> 200`) |
| 5 | `skippedOps` counts text alone, fill corpus | **PASS** — `skippedOps = 1` on a corpus with text, `= 0` on a fills-only one, `= 0` on this task's own 10,000-entity fills-on corpus |
| 6 | resident geometry `<= 8 MB`, 10,000 entities with fills, measured | **PASS** — **6.51 MB** at 106,636 instances (matched to Plan C's own parameters), **7.00 MB** at 114,717 instances (default knobs); both against 8.00 MB |
| 7 | 12 of 12 mutations fire, survivors declared with a reason | **PASS** — 12/12 fired, 11 killed first shot, M-D4 survived its first shot for a real, declared reason and was killed after the fix |
| 8 | a human looks at the window | **OWED** — Plan D's five, plus Plan B's four and Plan C's five, fourteen checks total, none discharged |
| 9 | every gate green in all three packages | **PASS** — see below |

### The nine gate commands, verbatim

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:06 +565 ~1: All tests passed!
```

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.3s)
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 92 files (0 changed) in 0.14 seconds.
```

```
$ cd ../jet_cad_2d && dart test
...
00:02 +798: All tests passed!
```

```
$ dart analyze
Analyzing jet_cad_2d...
No issues found!
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.15 seconds.
```

```
$ cd ../../apps/dev_harness_2d && flutter test --concurrency=1
...
00:13 +73: All tests passed!
```

```
$ flutter analyze
Analyzing dev_harness_2d...
No issues found! (ran in 1.0s)
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 18 files (0 changed) in 0.08 seconds.
```

`+73` in `dev_harness_2d` is `+72` (the count at Plan C's merge) plus this
task's one new test, `fill_buffer_budget_test.dart`.

---

## Files this task touched

- `apps/dev_harness_2d/lib/main.dart` — `kSpikeFills` (a `String`-keyed
  define, same shape as `kFillsEnabled` and for the same reason: an
  unrecognised value throws rather than silently reading as off);
  `spikeDocument()` takes optional `entityCount`/`fillsEnabled` overrides so
  a test can fix the corpus directly rather than through a define, and calls
  `_addFillRegions` when fills are enabled.
- `apps/dev_harness_2d/lib/gpu_arm.dart` — the header comment and the
  `GSPIKE note` line corrected: fills are no longer described as unsupported
  by arm C (they were landed by this plan's earlier tasks); text is now the
  only op left in `skippedOps`.
- `apps/dev_harness_2d/test/fill_buffer_budget_test.dart` — new. The buffer
  measurement above.
- `docs/superpowers/notes/2026-09-01-plan-d-results.md` — this file.
- `STATUS.md` — head rewritten; see the commit for this task.
