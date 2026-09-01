# Task 9 report: the buffer measurement, the results note, and what the window showed (OWED)

Branch `plan-d/fills`. Per Ruling D-9a, Steps 3 and 4 of the brief (the
device run and the human window check) are explicitly **not** performed in
this session — no `flutter run -d macos` was invoked, no device output is
reported, no window check is claimed. Everything else in the brief is done
in full.

## Files touched

- `apps/dev_harness_2d/lib/main.dart` — new `kSpikeFills` define (a
  `String`-keyed switch, same shape as `kFillsEnabled`, throws on an
  unrecognised value rather than reading a typo as off). `spikeDocument()`
  gained optional `entityCount`/`fillsEnabled` parameters, defaulting to the
  existing top-level defines (`kEntities`, `kSpikeFills`) so an ordinary
  `flutter run`/`flutter drive` invocation is unaffected, and calls
  `_addFillRegions` when fills are enabled. At `SPIKE_FILLS`'s default
  (`false`) the corpus `spikeDocument()` builds is byte-for-byte what it was
  before this task.
- `apps/dev_harness_2d/lib/gpu_arm.dart` — the header comment and the
  `GSPIKE note` line corrected: they used to describe `fillPolygon`,
  `fillCircle` and `text` as all falling through to `skippedOps` — false
  since this plan's earlier tasks landed both fill ops in the collector.
  Now: only `text` is described as skipped, and a new paragraph explains
  `SPIKE_FILLS` as the corpus-side switch (a separate question from whether
  the collector *can* draw fills, which it already could before this task).
- `apps/dev_harness_2d/test/fill_buffer_budget_test.dart` — new. The buffer
  measurement (below).
- `docs/superpowers/notes/2026-09-01-plan-d-results.md` — new. The full
  results note: criterion table, mutation summary, what the plan's own
  premises measured false, the buffer measurement, and the device-run /
  window-check sections marked OWED with the corrected command.
- `STATUS.md` — head rewritten (Plan D's state, exit gate 8/9, the
  fourteen-check debt) and the `## Resume here` section updated to name all
  three plans, their checks, and the corrected device-run command. Plan C's
  section was demoted to its own `## Plan C — dashes in the shader (merged,
  ...)` subsection immediately below the new head, content otherwise
  unchanged.

## How the buffer measurement was obtained

**Not a device run.** `GeometryCollector` builds the buffer a device upload
would receive entirely on the CPU; `ResidentGeometry.create` (the actual
GPU upload) is the only step not exercised, and it does not change the
buffer's byte length. `fill_buffer_budget_test.dart` calls
`spikeDocument(entityCount: 10000, fillsEnabled: true)` — the same corpus
builder `GpuSpikeState._buildResidentGeometry` in `gpu_arm.dart` uses for a
real device run — then makes the same three calls that method does, up to
and not including `ResidentGeometry.create`: `SpatialIndex`,
`ViewportTransform.fit`, `DraftPainter.paint` into a `GeometryCollector`,
then reads `collector.data` and walks it in 16-float strides to tally kind
tags (0 stroke / 1 join / 2 point / 3 fill — mirrored locally in the test
file as documented constants, since `instance_record.dart` is deliberately
unexported from `jet_cad_2d_flutter`'s public barrel).

Two reproductions, both re-run for this report:

```
$ cd apps/dev_harness_2d && flutter test test/fill_buffer_budget_test.dart
PLAN-D buffer: entities=10280 (requested 10000) instances=114717 (strokes=65469 joins=49088 points=0 fills=160) skippedOps=0 bytes=7341888 (7.00 MB) budget=8.00 MB margin=1046720 bytes
00:00 +1: All tests passed!
```

```
$ flutter test test/fill_buffer_budget_test.dart \
    --dart-define=SPIKE_INSTANCES=150 --dart-define=SPIKE_DEFS=20 --dart-define=DASHED=0.35
PLAN-D buffer: entities=10280 (requested 10000) instances=106636 (strokes=60798 joins=45678 points=0 fills=160) skippedOps=0 bytes=6824704 (6.51 MB) budget=8.00 MB margin=1563904 bytes
00:00 +1: All tests passed!
```

The second run matches Plan C's own device-run parameters
(`SPIKE_DEFS=20 SPIKE_INSTANCES=150 DASHED=0.35`, entities requested 10,000),
so its 6.51 MB / 106,636 instances is the number directly comparable to
Plan C's own recorded 6.41 MB / 105,076 instances (fills off). **Both
numbers PASS against the 8 MB budget** — margins of 1.49 MB and 1.00 MB
respectively. `fills=160` is identical across both runs (deterministic,
seeded generation): 80 filled rooms x 2 triangles each. `entities=10280` is
also identical: the base 10,000 plus 280 the fill-region generator adds (200
rooms in `kFillFraction=0.4` proportion — 80 filled pairs, 120 boundary-only
singles: 80x2 + 120 = 280).

Full derivation and the delta-against-Plan-C accounting is in the results
note's "Criterion 6" section.

## Verbatim output of all nine gate commands

### `packages/jet_cad_2d_flutter`

```
$ flutter test
...
00:08 +565 ~1: All tests passed!
```

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.1s)
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 92 files (0 changed) in 0.15 seconds.
```

### `packages/jet_cad_2d`

```
$ dart test
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
Formatted 113 files (0 changed) in 0.17 seconds.
```

### `apps/dev_harness_2d`

```
$ flutter test --concurrency=1
...
00:15 +73: All tests passed!
```

```
$ flutter analyze
Analyzing dev_harness_2d...
No issues found! (ran in 1.0s)
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 18 files (0 changed) in 0.09 seconds.
```

`+73` is `+72` (the count at Plan C's merge, from `STATUS.md`) plus this
task's one new test file.

`git status --short` immediately before staging showed exactly the five
files this task touches, no `analysis_options.yaml`.

## Additional evidence gathered for the results note, and how it was obtained

Several exit-gate rows (criteria 1–5) were already established by Tasks
6–8's own work on this branch. Rather than only citing their reports, I
re-ran the specific gating test files for this task and captured fresh
output:

```
$ flutter test test/gpu/fill_order_test.dart test/gpu/resident_pixel_differential_test.dart test/gpu/collector_differential_test.dart
...
00:00 +14: All tests passed!
```

(individual test names for these files are in the results note's
criterion-by-criterion section)

```
$ flutter test test/gpu/geometry_collector_test.dart
...
00:00 +52: All tests passed!
```

One number — the fill corpus's `ResidentColorAgreement` at
`kFillFixtureDevicePixelRatio` — was not previously captured verbatim in any
prior task's report (only its passing assertion, `>= 0.995`, was). I added a
temporary `print` to `test/gpu/resident_pixel_differential_test.dart`
immediately before that assertion, ran the single test, captured:

```
PLAN-D9 fill corpus per-channel: ResidentColorAgreement(union: 393051, withinTwo: 393051 (100.000%), overEight: 0, referenceInk: 393051)
```

then reverted the file with `git checkout --
packages/jet_cad_2d_flutter/test/gpu/resident_pixel_differential_test.dart`
(confirmed by `git diff --stat` reading empty afterward, before this task's
own commit was made). This mirrors Task 7's own documented practice
("captured via temporary print calls, then reverted").

## What the plan did not anticipate

1. **The brief's own Step 3 device-run command is missing
   `--dart-define=SPIKE_FILLS=true`.** It is byte-for-byte Plan C's command
   (`ENTITIES=10000 SPIKE_DEFS=20 SPIKE_INSTANCES=150 SPIKE_FRAMES=30
   SPIKE_REPEATS=3`), which predates this task's `SPIKE_FILLS` knob. Run
   exactly as written, the corpus would carry zero fills and none of Plan
   D's five window checks would have anything to look at. Both the results
   note and `STATUS.md`'s `Resume here` section carry the corrected command
   rather than repeating the brief's incomplete one uncorrected.
2. **`instance_record.dart`'s wire-format constants are deliberately
   unexported** from `jet_cad_2d_flutter`'s public barrel ("`GeometryCollector`'s
   own wire format, not something a caller writes" — the barrel's own
   comment). The buffer-measurement test cannot import them, so it carries a
   small, explicitly-documented local copy of `kFloatsPerInstance` and the
   four kind tags rather than reaching into `lib/src/`.
3. **`spikeDocument()` had no parameter seam for a fixed corpus.** It read
   every knob from top-level `dart-define`-backed finals, which a `flutter
   test` run cannot flip at runtime. Added `entityCount`/`fillsEnabled`
   optional parameters (defaulting to the existing finals) rather than
   introducing a second corpus builder, so the measurement test exercises
   the *same* function a real device run does, not a parallel copy that
   could drift from it.
4. **`Float32List.bytesPerElement`, not `bytesPerElementSize`** — a first
   draft of the measurement test used the wrong static member name; caught
   by the IDE diagnostic on write, fixed before the first test run.
5. Both buffer-measurement runs are **fully deterministic** (fixed seeds in
   `generateDocument` and `_addFillRegions`) — re-running either command
   multiple times reproduced identical `fills=160`, `entities=10280` and
   byte counts every time, which is what makes the two commands in the
   results note actual reproduction instructions rather than one-off
   readings.

## Commit

```
git add STATUS.md apps/dev_harness_2d/lib/gpu_arm.dart apps/dev_harness_2d/lib/main.dart \
        apps/dev_harness_2d/test/fill_buffer_budget_test.dart \
        docs/superpowers/notes/2026-09-01-plan-d-results.md
git commit -m "docs: Plan D's results, and what the window showed"
```

Result: `8338fd5`, 5 files changed, 743 insertions(+), 65 deletions(-).

## What is still owed, and by whom

Steps 3 and 4 of the brief — the macOS profile device run and the human
window check — are **not this session's to perform**, per Ruling D-9a, and
are recorded as OWED in both the results note and `STATUS.md`, each naming
the exact corrected command and the fourteen checks (Plan B's four, Plan
C's five, Plan D's five) one run would discharge. Plan D's own exit gate
therefore reads **8 of 9**, with row 8 OWED rather than failed — no
criterion in this task was scored a MISS, and none of the thresholds this
task measured against (8 MB, 0.995, 200 pixels, `> 5000`) were moved.

---

## Fix round 1/5

Independent review of `8338fd5` found one Important: `fill_buffer_budget_test.dart`
was never measured against this repo's testing bar (CLAUDE.md — "a new test
is only worth landing if a named mutation makes it go red"). Neither the
results note nor this report said which mutation kills it, or said plainly
it kills nothing.

**Closed by firing, not by reasoning**, per the reviewer's instruction:

1. `cp apps/dev_harness_2d/lib/main.dart /tmp/main.dart.bak9`.
2. Mutated `spikeDocument`'s fill-region call so `_addFillRegions` never
   runs regardless of `fillsEnabled`/`SPIKE_FILLS`:
   ```diff
   -  if (fillsEnabled ?? kSpikeFills) _addFillRegions(doc, count);
   +  // MUTATION (task-9 fix round 1): _addFillRegions never runs.
   +  if (false && (fillsEnabled ?? kSpikeFills)) _addFillRegions(doc, count);
   ```
3. `flutter test test/fill_buffer_budget_test.dart` — verbatim failure:
   ```
   00:00 +0 -1: the resident buffer at 10,000 entities with fills, measured on the CPU [E]
     Expected: a value greater than <0>
       Actual: <0>
        Which: is not a value greater than <0>
     fillsEnabled: true must actually reach the collector as fill instances, or this measurement is vacuous for the one thing Task 9 adds

     package:matcher                                     expect
     package:flutter_test/src/widget_tester.dart 473:18  expect
     test/fill_buffer_budget_test.dart 106:5             main.<fn>
   ```
   `expect(fills, greaterThan(0))` is the assertion killed.
4. Restored: `cp /tmp/main.dart.bak9 apps/dev_harness_2d/lib/main.dart`,
   confirmed byte-identical (`diff` empty) and `git status --short` clean —
   **never `git checkout --`**, per the reviewer's instruction.

**The companion assertion, `expect(other, 0)`** (every instance must carry a
known kind tag, 0–3), was **not independently fired this round**. Killing it
for real needs a mutation inside `GeometryCollector`/`instance_record.dart`
(writing an out-of-range kind), not inside the harness — a real mutation to
attempt, but not one this round attempted. The results note states this as
untested, not as either killed or unkillable, per the reviewer's instruction
not to drop it silently.

One sentence (plus the honest caveat on the second assertion) added to
`docs/superpowers/notes/2026-09-01-plan-d-results.md`'s "Criterion 6"
section, immediately after the method paragraph.

### Gate, re-run after the fix, before committing

All three packages green (verbatim tails):

```
$ cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
00:06 +565 ~1: All tests passed!
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.3s)
Formatted 92 files (0 changed) in 0.14 seconds.
```

```
$ cd ../jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
00:02 +798: All tests passed!
Analyzing jet_cad_2d...
No issues found!
Formatted 113 files (0 changed) in 0.14 seconds.
```

```
$ cd ../../apps/dev_harness_2d && flutter test --concurrency=1 && flutter analyze && dart format --output=none --set-exit-if-changed .
00:13 +73: All tests passed!
Analyzing dev_harness_2d...
No issues found! (ran in 1.2s)
Formatted 18 files (0 changed) in 0.08 seconds.
```

`git status --short` before staging: only
`docs/superpowers/notes/2026-09-01-plan-d-results.md`, no
`analysis_options.yaml`.

### Commit

```
git add docs/superpowers/notes/2026-09-01-plan-d-results.md
git commit -m "docs(plan-d): fire fill_buffer_budget_test's killability, per review round 1"
```

Result: `d6d5c58`, 1 file changed, 16 insertions(+).
