# Task 7 report: The startup document (spec D5), and the clamp constants checked against it (D4)

## What I implemented

Transcribed the brief's Step 1 test and Step 3 document verbatim into:

- `apps/floor_planner/lib/startup_plan.dart` — `startupPlan(FlutterTextMeasurer)`
  building the hand-written flat via the `_Pen` helper (`AddEntityCommand` /
  `EntityRecord` / `GeometryPayload`), plus the four Task-8 constants:
  `kMinScale = 0.001`, `kMaxScale = 100.0`, `kPlanOriginX = 12000.0`,
  `kPlanOriginY = 8000.0` (and the two supporting constants `kPlanWidth`,
  `kPlanHeight` the brief's own test references).
- `apps/floor_planner/test/startup_plan_test.dart` — the brief's four tests,
  unmodified.

No pitch change was needed (see entity count below), so Step 4's named-change
branch was not exercised.

## What I tested, and the results (pasted, not synthesized)

### RED — Step 2

Command: `cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart`
(run before `lib/startup_plan.dart` existed)

```
  test/startup_plan_test.dart:23:17: Error: Method not found: 'startupPlan'.
      final doc = startupPlan(measurer);
                  ^^^^^^^^^^^
  ... (further "Method not found: 'startupPlan'" / "Undefined name" errors
       for kPlanOriginX, kPlanOriginY, kPlanWidth, kPlanHeight, kMinScale,
       kMaxScale)
00:00 +0 -1: Some tests failed.

Failing tests:
  .../apps/floor_planner/test/startup_plan_test.dart: loading .../startup_plan_test.dart
```

Expected and matched: compile error because `startupPlan` and the four
constants did not exist yet.

### GREEN — Step 4

Command: `cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart`
(run after `lib/startup_plan.dart` was added)

```
00:00 +0: loading .../startup_plan_test.dart
00:00 +0: is at the target scale: between 500 and 1,000 entities
00:00 +1: is off-origin and not axis-symmetric
00:00 +2: the outer walls close: the extents are the outer rectangle
00:00 +3: the clamp constants bracket the fitted scale by decades
STARTUP fit scale 0.095 px/mm; min 0.001 (95.0x out), max 100.0 (1052.6315789473683x in)
00:00 +4: All tests passed!
```

The `STARTUP` line, verbatim, for Task 10 to quote:

```
STARTUP fit scale 0.095 px/mm; min 0.001 (95.0x out), max 100.0 (1052.6315789473683x in)
```

### Entity count

523 (measured with a temporary `print('ENTITY COUNT: ${doc.entities.liveCount}')`
inserted into a scratch copy of the test, run, then the test file was
restored byte-for-byte from a backup taken before the edit — the committed
test file is exactly the brief's Step 1 code, confirmed by diff against the
backup):

```
ENTITY COUNT: 523
00:00 +4: All tests passed!
```

523 is within 500–1,000, so no pitch change (Step 4's named-change branch)
was needed.

### Full app test suite

Command: `cd apps/floor_planner && CI=true flutter test`

```
00:00 +0: loading .../startup_plan_test.dart
00:00 +0: is at the target scale: between 500 and 1,000 entities
00:00 +1: is off-origin and not axis-symmetric
00:00 +2: the outer walls close: the extents are the outer rectangle
00:00 +3: the clamp constants bracket the fitted scale by decades
STARTUP fit scale 0.095 px/mm; min 0.001 (95.0x out), max 100.0 (1052.6315789473683x in)
00:00 +4: All tests passed!
```

(This is the app's only test file at this point in the plan — Task 6 left no
tests, Task 7 adds the first.)

### Analyze

Command: `cd apps/floor_planner && flutter analyze`

```
Analyzing floor_planner...

   info • Unnecessary braces in a string interpolation. Try removing the braces • test/startup_plan_test.dart:52:14 • unnecessary_brace_in_string_interps
   info • Unnecessary braces in a string interpolation. Try removing the braces • test/startup_plan_test.dart:53:14 • unnecessary_brace_in_string_interps

2 issues found. (ran in 0.9s)
```

Exit code 0 (`info`-level, not `warning`/`error`). Both are `${kMinScale}` /
`${kMaxScale}` interpolations in the brief's own Step 1 code (the `print`
line). I left them exactly as written — the brief says transcribe verbatim,
the print line is called out as intentional, and "clean" gates on the
analyzer's own definition of an issue, which this is not (exit 0, no
warnings or errors). Not touched.

### Format

Command: `cd apps/floor_planner && dart format --output=none --set-exit-if-changed .`

First run (before formatting `lib/startup_plan.dart`) reported one file
would change — `dart format` reflowed several of the brief's `p.door(...)`,
`p.rect(...)`, `p.circle(...)`, `p.parquet(...)` and `line(...)` calls that
exceeded the line-length limit onto multiple lines. This is whitespace-only
reformatting of the brief's code, explicitly permitted. I ran
`dart format lib/startup_plan.dart` to apply it (diff confirmed: line-wrap
only, no token changes), then re-ran the check:

```
Formatted 3 files (0 changed) in 0.02 seconds.
```

Exit code 0.

## Files changed

- `apps/floor_planner/lib/startup_plan.dart` (new)
- `apps/floor_planner/test/startup_plan_test.dart` (new)

`apps/floor_planner/analysis_options.yaml` was not touched or modified by
`pub get`/`flutter test` in this run (confirmed via `git status --short`
before commit — nothing but the two new files appeared).

## TDD evidence

Covered above under RED / GREEN.

## Self-review findings

- Completeness: both files match the brief's Step 1 and Step 3 code, modulo
  `dart format`'s whitespace reflow of a handful of over-length call
  expressions in `startup_plan.dart` (permitted).
- Quality: `_Pen` is the sole entry point for entities, matching the
  documented invariant that draw order (ascending handle) is command order
  (source order in `startupPlan`).
- Discipline: no files created beyond the two named in the brief; no other
  file touched; commit contains exactly those two files.
- Testing: all four tests assert real, checkable properties (entity-count
  band, off-origin/non-symmetric extents, exact outer-rectangle extents, and
  the clamp-constant decades against the fitted scale) — none are
  degenerate-fixture checks. The one `print` is the brief's intentional one,
  carrying the `// ignore: avoid_print` from the brief; not removed.

## Issues or concerns

None. The brief's code compiled and passed as written; the only deviation
from a literal byte-for-byte transcription is `dart format`'s permitted
line-wrapping of `lib/startup_plan.dart`, and the two analyzer infos in the
brief's own test file at lines 52–53, which are not analyzer failures (info,
exit 0) and were left untouched per "transcribe exactly."

## Fix report — round 1

**Finding:** `apps/floor_planner/test/startup_plan_test.dart:52-53` —
`flutter analyze` reported two `unnecessary_brace_in_string_interps` infos
for `${kMinScale}` and `${kMaxScale}` in the `STARTUP` print. Controller's
ruling: "analyze clean" in this repository means `No issues found!` at every
severity, and the brief's braces there are wrong.

**What changed:** in the `print` inside the "the clamp constants bracket the
fitted scale by decades" test, `${kMinScale}` → `$kMinScale` and
`${kMaxScale}` → `$kMaxScale`. The other four interpolations in the same
`print` (`${fit.scale}`, `${fit.scale / kMinScale}`, `${kMaxScale / fit.scale}`)
are expressions, not bare identifiers, so `dart format`/the analyzer do not
flag them and they were left as-is. Nothing else in the file, and no other
file, was touched.

**Covering test:** `startup_plan_test.dart`'s fourth test, "the clamp
constants bracket the fitted scale by decades" — it still prints and asserts
the same `STARTUP` line; only the source text of the print statement changed,
not its output.

**Commands and pasted output:**

`cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart`

```
00:00 +0: loading .../startup_plan_test.dart
00:00 +0: is at the target scale: between 500 and 1,000 entities
00:00 +1: is off-origin and not axis-symmetric
00:00 +2: the outer walls close: the extents are the outer rectangle
00:00 +3: the clamp constants bracket the fitted scale by decades
STARTUP fit scale 0.095 px/mm; min 0.001 (95.0x out), max 100.0 (1052.6315789473683x in)
00:00 +4: All tests passed!
```

`cd apps/floor_planner && flutter analyze`

```
Analyzing floor_planner...
No issues found! (ran in 1.2s)
```

`cd apps/floor_planner && dart format --output=none --set-exit-if-changed .`

```
Formatted 3 files (0 changed) in 0.02 seconds.
```

`git status --short` (checked for a rewritten `analysis_options.yaml`
before committing):

```
 M apps/floor_planner/test/startup_plan_test.dart
```

No `analysis_options.yaml` was rewritten; nothing to restore.

**Commit:** `5dadd17` — `test(floor_planner): drop the interpolation braces the analyzer flags`,
`apps/floor_planner/test/startup_plan_test.dart` only (1 file changed, 2
insertions, 2 deletions).
