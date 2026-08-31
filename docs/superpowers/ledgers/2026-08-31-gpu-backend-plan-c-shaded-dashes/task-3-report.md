# Task 3 report: `shadedDashFixture()`

Commit: `da56c05` on `plan-c/shaded-dashes` (parent `d615798`).

## The fixture

Added to `packages/jet_cad_2d_flutter/test/support/fixtures.dart`:
`_addShadedLinetype`, `_addShadedEntity` (private helpers — the shared
`addEntity` always resolves `ByLayer` linetype at scale 1.0 and cannot build
a dashed fixture), and `shadedDashFixture({double linetypeScale = 1.0})`.

Contents, and the reason for each element:

- **900 `DASHED` `[12, -6]`** (total 18), **901 `DASHDOT` `[12, -3, 0.5, -3]`**
  (total 18.5, two positive entries), **902 `ALLGAP` `[-4]`** (total 4, zero
  positive entries) — three linetypes with drawn-element counts 1, 2, 0.
  `totalLength` on each is computed as the sum of `|dashes|` so the fixture
  can never be the place a totalLength/dashes disagreement hides (confirmed
  by reading `dasher.dart`: it never reads `totalLength`).
- **910**, a five-point dashed polyline (`EntityKind.polyline`, linetype 900).
  Turn at P1 is 130° (interior 50°, sharp, under 90°); turn at P2 is 3°
  (interior 177°, nearly straight, under 5°); turn at P3 is 67° (an ordinary
  third corner). Total path length 360 local units. A dashed run emits no
  joins (Ruling C3), so this is the vertex that can tell a missing join from
  a collinear one.
- **911**, a dashed circle (linetype 900, r=65, circumference ≈408) — a
  closed run, so the seam join is in play.
- **912**, a dashed arc (linetype 900, r=85, sweep 3.3 rad, length ≈280.5) —
  several chords for the per-chord running phase to advance across.
- **913**, a `DASHDOT` line (linetype 901, length 250) — the D==2 witness.
  Its own `linetypeScale` field is the only thing the fixture's
  `linetypeScale` parameter touches.
- **914**, an `ALLGAP` line (linetype 902, length 150) — the D==0/collapse
  witness.
- **915**, a **solid** line (`ReservedHandles.continuousLinetype`) crossing
  910's P1–P2 segment at local (39.64, 60) — so dash gaps have something
  behind them.
- **916**, a hairline dashed line (linetype 900, lineweight 1, length 200) —
  below one device pixel at dpr 1, routes through `_coveredArgb`.
- `doc.header.globalLinetypeScale = 1.7` — a real multiplicand, not the
  identity.
- Everything lives in one definition (`Handle(990)`) placed by one instance
  (`Handle(991)`) with `translation(1000, -600) * rotation(0.62) *
  scale(1.8, 0.65)` — rotated and non-uniformly scaled (ratio 1.8/0.65, far
  from 1), so nothing sits at the identity, the origin, or a uniform scale.

## Step 4 — proving Ruling C5 (not asserting it)

Done **before** writing the real fixture, while `fixtures.dart` was still
pristine, per the brief.

**First attempt was degenerate and had to be redone.** I added a probe
linetype + dashed line to `differentialFixture` reusing entity 800's exact
coordinates (`[ox+1, oy+1, ox+9, oy+6]`, world length ≈9.43). `flutter test
test/differential_test.dart` came back with only **1 of 9** tests failing —
"the differential fixture is entirely continuous" (a purpose-built guard
already in that file) — and, critically, "the painter draws a superset of
the reference walk, in order" **passed**. Investigating why: the probe's
length (9.43) was shorter than the pattern's first "on" segment (12), so the
dasher's "on" phase never ended before the line did and it emitted exactly
one span identical to the whole solid line — the same degenerate-fixture
trap this task's own brief warns about, just landed on accidentally.

**Second attempt, corrected**: lengthened the probe to `[ox+1, oy+1, ox+181,
oy+121]` (length ≈216.5, several pattern periods). Rerun of
`flutter test test/differential_test.dart`:

```
00:00 +0: the painter draws a superset of the reference walk, in order
00:00 +0 -1: the painter draws a superset of the reference walk, in order [E]
  Expected: <12>
    Actual: <11>
  the painter missed 1 of 12 reference ops, first unmatched: polyline(20.00,529.50)(780.00,22.84)
  ...
00:00 +0 -2: the same holds at 4.5e6 with the view over one nested instance [E]
  Expected: <5>
    Actual: <4>
  the painter missed 1 of 5 reference ops, first unmatched: polyline(-1357.36,1035.06)(8902.64,-5804.94)
  ...
00:00 +1 -3: the differential fixture is entirely continuous [E]
  Expected: empty
    Actual: [12.0, -6.0]
  ...
00:00 +6 -4: the oracle catches a broken painter noise below the tolerance does not fail [E]
  Expected: <12>
    Actual: <11>
  ...
00:00 +6 -4: Some tests failed.

Failing tests:
  test/differential_test.dart: the differential fixture is entirely continuous
  test/differential_test.dart: the oracle catches a broken painter noise below the tolerance does not fail
  test/differential_test.dart: the painter draws a superset of the reference walk, in order
  test/differential_test.dart: the same holds at 4.5e6 with the view over one nested instance
```

Exit code 1. **4 of 9 tests failed**, including the exact one the brief
named — "the painter draws a superset of the reference walk, in order" — for
exactly the predicted reason (painter emits spans, reference emits one whole
polyline, `expectPainterSupersetOfReference`'s greedy point-for-point match
never finds it). **Verdict: the brief's premise holds**, but only with a
fixture long enough to actually be cut into multiple spans — a length short
enough to fit inside the first dash's "on" phase gives a false negative. This
sensitivity is worth carrying forward for anyone extending this fixture.

Reverted with `git checkout -- test/support/fixtures.dart` (file was
committed and clean at that point); confirmed via `git status --short` and
`git diff` showing nothing, both empty.

## Step 3 — guard test

`flutter test test/support/fixtures_test.dart`: 1 test, green, exit 0.
Measured repeat count for entity 910 (via a temporary `print`, removed
before the final run): **16.54** (`greaterThan(4.0)` — well clear; the
straight-line back-of-envelope estimate was ~11.8, the gap is the
anisotropic instance transform not scaling the polyline's screen length
uniformly with `patternToLocal`'s `scaleMagnitude`, which is an existing,
known approximation in `_dashScale`, not a fixture defect).

## Full gate

```
$ flutter test        → 514 tests, +514 ~1 (the one pre-existing skip), exit 0
$ flutter analyze      → No issues found!
$ dart format --output=none --set-exit-if-changed .  → 90 files, 0 changed, exit 0
```

`differentialFixture` byte-identical to its committed state (`git diff` on
`test/support/fixtures.dart` limited to the appended `shadedDashFixture` and
its two private helpers; `git status --short` before commit showed only the
modified `fixtures.dart` and the new `fixtures_test.dart`). `analysis_options.yaml`
untouched. `packages/jet_cad_2d` untouched.

## What the brief got wrong / worth flagging

- The brief's Step 4 instructions don't warn that a short dashed probe can
  give a false negative on the superset test specifically because the dash
  pattern's first "on" phase can outlast the whole entity. My first attempt
  hit exactly that trap; worth a one-line warning in the brief for future
  tasks that build similar probes.
- "Drawn-element count" (assertion 4) turned out to be a static property of
  the registered `DashPattern.dashes` list (count of positive entries) —
  no painting needed. The brief's phrasing ("three different drawn-element
  counts") is consistent with this reading but could be misread as requiring
  a paint-and-count; worth confirming with Task 5/11 whether their
  "drawn element" language means the same thing.

## Concerns for later tasks

None found in the fixture itself. Handles 990/991 (definition/instance) sit
outside the documented 900–916 table on purpose, to avoid clashing with it.
