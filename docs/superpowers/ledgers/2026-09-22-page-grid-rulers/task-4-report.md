# Task 4 report: `page_geometry.dart` and `grid_scale.dart`

## What I implemented

Per the brief, verbatim:

- `packages/jet_cad_2d/lib/src/document/page_geometry.dart` — `sheetWorldRect`,
  `zoomOf`, `pageWorldOf`, `worldOfPage`.
- `packages/jet_cad_2d/lib/src/geometry/grid_scale.dart` — `kMajorMinPixels`,
  `kMinorMinPixels`, `GridScale` (`majorMm`, `minorMm`, `unit`, `divisor`),
  `GridScale.pick` (with `minorMinPixels` defaulting to `kMinorMinPixels`,
  per Ruling 04-7), `GridScale.ladderFor`, `formatLength`, `snapToGrid`.
- Two barrel exports added to `packages/jet_cad_2d/lib/jet_cad_2d.dart`:
  `src/document/page_geometry.dart` and `src/geometry/grid_scale.dart`.
- Test files written exactly as the brief specifies:
  `packages/jet_cad_2d/test/document/page_geometry_test.dart` (3 tests) and
  `packages/jet_cad_2d/test/geometry/grid_scale_test.dart` (11 tests: 7 in
  `pick`, 1 in `formatLength`, 3 in `snapToGrid`).

No deviation from the brief's Step 3 source. The two arithmetic notes in the
task description (the `_divisorFor` floor/exponent edge case, and
`formatLength(311.15, DisplayUnit.inches)` → `'12.25 in'` via `_trim`) held
with the brief's code as given — no fix to `_trim` was needed.

## TDD evidence

### RED — both test files fail to compile (source files did not exist yet)

Command:
```
cd packages/jet_cad_2d && CI=true dart test test/document/page_geometry_test.dart test/geometry/grid_scale_test.dart
```

Output (relevant excerpt, pasted as printed):
```
00:00 +0: loading test/document/page_geometry_test.dart
00:00 +0 -1: loading test/document/page_geometry_test.dart [E]
  Failed to load "test/document/page_geometry_test.dart":
  test/document/page_geometry_test.dart:11:18: Error: Method not found: 'sheetWorldRect'.
      final rect = sheetWorldRect(page);
                   ^^^^^^^^^^^^^^
  ...
00:00 +0 -2: loading test/geometry/grid_scale_test.dart [E]
  Failed to load "test/geometry/grid_scale_test.dart":
  test/geometry/grid_scale_test.dart:11:17: Error: Undefined name 'GridScale'.
        final s = GridScale.pick(DisplayUnit.meters, 0.137)!;
                  ^^^^^^^^^
  ...
00:00 +0 -2: Some tests failed.

Failing tests:
  test/document/page_geometry_test.dart: loading test/document/page_geometry_test.dart
  test/geometry/grid_scale_test.dart: loading test/geometry/grid_scale_test.dart
```
Exit code: 1.

### GREEN — after implementing both source files and the two exports

Command:
```
cd packages/jet_cad_2d && CI=true dart test test/document/page_geometry_test.dart test/geometry/grid_scale_test.dart
```

Output (printed counter lines, as printed):
```
00:00 +0: loading test/document/page_geometry_test.dart
00:00 +0: test/document/page_geometry_test.dart: the sheet rect is origin plus effective size times D
00:00 +1: test/geometry/grid_scale_test.dart: pick metric: the smallest ladder step at or above 64 px
00:00 +2: test/document/page_geometry_test.dart: 100 % is pixelsPerPaperMm / D
00:00 +3: test/document/page_geometry_test.dart: 100 % is pixelsPerPaperMm / D
00:00 +4: test/geometry/grid_scale_test.dart: pick minor is null under the minor threshold
00:00 +5: test/document/page_geometry_test.dart: page space is world minus origin, and back
00:00 +6: test/document/page_geometry_test.dart: page space is world minus origin, and back
00:00 +7: test/document/page_geometry_test.dart: page space is world minus origin, and back
00:00 +8: test/document/page_geometry_test.dart: page space is world minus origin, and back
00:00 +9: test/geometry/grid_scale_test.dart: pick the ladders are ascending and the metric one is 1-2-5
00:00 +10: test/geometry/grid_scale_test.dart: formatLength per unit
00:00 +11: test/geometry/grid_scale_test.dart: snapToGrid nearest, anchored at the sheet origin, negative side too
00:00 +12: test/geometry/grid_scale_test.dart: snapToGrid an adaptive step lands on the drawn lattice
00:00 +13: test/geometry/grid_scale_test.dart: snapToGrid refuses a non-positive step
00:00 +14: All tests passed!
```
Exit code: 0. (14 tests: 3 + 11, matching the brief's two files; `dart test`'s
concurrent runners interleave/collapse some printed names but the terminal
count of 14 with zero failures accounts for every test in both files.)

## Gate line (`packages/jet_cad_2d`)

### `CI=true dart test` (full suite)

Command: `cd packages/jet_cad_2d && CI=true dart test`

Tail of output (printed as printed):
```
00:02 +856: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +857: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:03 +858: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:03 +858: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +859: All tests passed!
```
Exit code: 0. (859 tests total, up from the branch point; no regression.)

### `dart analyze`

```
Analyzing jet_cad_2d...
No issues found!
```
Exit code: 0.

### `dart format --output=none --set-exit-if-changed .`

First run (before formatting the four new files) reported the new files as
unformatted:
```
Changed lib/src/document/page_geometry.dart
Changed lib/src/geometry/grid_scale.dart
Changed test/document/page_geometry_test.dart
Changed test/geometry/grid_scale_test.dart
Formatted 125 files (4 changed) in 0.24 seconds.
```
Exit code: 1 (this was the check run, not the writer — see constraint about
never running `dart format` without `--output=none --set-exit-if-changed` as
the gate; I then ran a plain `dart format <the 4 files>` to apply the
brief's own layout choices consistently, which only reformatted long
parameter/argument lists — no functional change). Re-running the gate
command afterward:
```
Formatted 125 files (0 changed) in 0.24 seconds.
```
Exit code: 0.

All three gate commands are green.

## Files changed

- Modified: `packages/jet_cad_2d/lib/jet_cad_2d.dart` (two new exports)
- Created: `packages/jet_cad_2d/lib/src/document/page_geometry.dart`
- Created: `packages/jet_cad_2d/lib/src/geometry/grid_scale.dart`
- Created: `packages/jet_cad_2d/test/document/page_geometry_test.dart`
- Created: `packages/jet_cad_2d/test/geometry/grid_scale_test.dart`

`git status --short` before committing showed no `analysis_options.yaml`
rewrite this run, so there was nothing to `git checkout --`.

## Self-review

- **Completeness:** all 3 tests in `page_geometry_test.dart` and all 11 in
  `grid_scale_test.dart` (7 `pick`, 1 `formatLength`, 3 `snapToGrid`) are
  present verbatim from the brief and pass. Both barrel exports added.
  `GridScale.pick` returns `GridScale?`. `divisor` getter present.
  `ladderFor` present with the `floorMm` branch. `minorMinPixels` parameter
  present on `pick`, defaulting to `kMinorMinPixels`, exercised by the
  "minor is null under the minor threshold" test per Ruling 04-7.
- **Quality:** implementation is the brief's Step 3 code unmodified beyond
  `dart format`'s own line-wrapping of long parameter/argument lists — no
  logic changes were needed. Doc comments carry the spec references
  (D1, D3–D7) as given.
- **Discipline:** no subagents dispatched; no mutation sweep beyond what the
  brief's tests already exercise; commit trailer verified via
  `git log -1 --format=%B | grep -c "Fable 5.1"` → `1`.
- **Pristine output:** full `jet_cad_2d` gate line (test, analyze, format)
  all exit 0; no other files touched; `apps/dev_harness_2d` and the
  untouched-widget list were not touched.

## Concerns

None. The two "arithmetic notes" flagged in the task description (the
`_divisorFor` floor-vs-exponent rounding for exact powers of ten, and
`_trim`'s handling of `formatLength(311.15, DisplayUnit.inches)`) both
resolved correctly with the brief's code as given, so no source deviation
was required.

---

## Fix round 1

Reviewer verdict: needs fixes. HEAD at the start of this round: `5f54569`.
All six findings addressed; nothing else touched.

### What changed, per finding

1. **(IMPORTANT, Ruling 04-11) Imperial ladder bit-mismatch.** In
   `lib/src/geometry/grid_scale.dart`, the imperial ladder's inch rungs were
   built as `inches * 25.4` (e.g. `6 * 25.4` = `152.39999999999997726`), which
   is a different double than `pick`'s minor for a foot-based major
   (`609.6 / 4` = `152.40000000000000568`). Rebuilt the inch rungs as
   fractions of a foot — `304.8 * f` for
   `f in [1/192, 1/96, 1/48, 1/24, 1/12, 1/6, 1/2]` (1/16", 1/8", 1/4", 1/2",
   1", 2", 6") — so a foot-based major divided by 4 is the same double as the
   corresponding rung, by construction (halving `304.8` is exact, as is
   doubling it, regardless of order). Added the doc comment on
   `_imperialLadder` explaining why. Added the test (in "imperial ladder in
   inches and feet"):
   ```dart
   expect(GridScale.ladderFor(DisplayUnit.feetInches).contains(s.minorMm),
       isTrue,
       reason: "the 2 ft major's minor is the 6 in rung, bit for bit");
   ```
   kept the existing `closeTo` assertions.

2. **(IMPORTANT, Ruling 04-12) Imperial divisor wrong with a floor.**
   `_divisorFor` guarded with
   `if (unit.isImperial && floorMm == null) return 4;`, so an imperial unit
   with a `floorMm` fell through to the metric mantissa rule. Changed the
   guard to `if (unit.isImperial) return 4;` — every imperial step divides by
   4, floor or not (spec D7). Added the test:
   ```dart
   test('imperial divisor is 4 even with a floor', () {
     final s = GridScale.pick(DisplayUnit.feetInches, 0.25, floorMm: 304.8)!;
     expect(s.majorMm, 304.8);
     expect(s.minorMm, 76.2);
     expect(s.divisor, 4);
   });
   ```

3. **(IMPORTANT) Ascending-ladder test only covered metric.** Added the same
   strictly-ascending loop over `GridScale.ladderFor(DisplayUnit.inches)`
   inside the existing "the ladders are ascending…" test, so a mutation of
   the 6" rung (or any imperial rung) going out of order is now caught.

4. **(minor) `formatLength(-0.5, feetInches)` printed `-0'-0"`.** In
   `_feetInches`, moved the sign decision to after rounding: `sign` is now
   `mm < 0 && sixteenths != 0 ? '-' : ''`, so a value that rounds to zero
   sixteenths prints without a minus. Added the assertion
   `expect(formatLength(-0.5, DisplayUnit.feetInches), '0\'-0"');`.

5. **(minor) `ladderFor` allocated per call.** Hoisted the metric and
   imperial ladders to `static final List<double> _metricLadder` /
   `_imperialLadder`, built once at class load. `ladderFor` now returns one
   of those two for the no-floor case and only builds a fresh list when
   `floorMm != null` (the floor ladder is comparatively rare — driven by an
   explicit `PageComponent.gridStepMm`, not called every frame the way the
   no-floor path is). Return type is unchanged (`List<double>`).

6. **(minor) Adaptive-snap test only checked x.** Captured the step in a
   local `step` variable and added
   `expect((p.y - page.originY) % step, 0);` alongside the existing x
   assertion.

### TDD evidence for this round

Test file edited first (all six findings' assertions added), then run
against the pre-fix source to confirm RED for findings 1, 2 and 4 (finding 3
and 6 are coverage additions with no bug to expose yet under the old code;
finding 5 has no observable test difference — it's a performance-only
change).

**RED** — `cd packages/jet_cad_2d && CI=true dart test test/geometry/grid_scale_test.dart` (against HEAD `5f54569`'s source, before applying the fixes):
```
00:00 +0: loading test/geometry/grid_scale_test.dart
00:00 +0: pick metric: the smallest ladder step at or above 64 px
00:00 +1: pick a mantissa-2 major divides by 4
00:00 +2: pick minor is null under the minor threshold
00:00 +3: pick imperial ladder in inches and feet
00:00 +3 -1: pick imperial ladder in inches and feet [E]
  Expected: true
    Actual: <false>
  the 2 ft major's minor is the 6 in rung, bit for bit
  ...
00:00 +3 -1: pick imperial divisor is 4 even with a floor
00:00 +3 -2: pick imperial divisor is 4 even with a floor [E]
  Expected: <76.2>
    Actual: <60.96>
  ...
00:00 +6 -2: formatLength per unit
00:00 +6 -3: formatLength per unit [E]
  Expected: '0\'-0"'
    Actual: '-0\'-0"'
     Which: is different.
            Expected: 0'-0"
              Actual: -0'-0"
                      ^
  ...
00:00 +9 -3: Some tests failed.

Failing tests:
  test/geometry/grid_scale_test.dart: formatLength per unit
  test/geometry/grid_scale_test.dart: pick imperial divisor is 4 even with a floor
  test/geometry/grid_scale_test.dart: pick imperial ladder in inches and feet
```
Exit code: 1.

**GREEN** — same command, after the source fixes:
```
00:00 +0: loading test/geometry/grid_scale_test.dart
00:00 +0: pick metric: the smallest ladder step at or above 64 px
00:00 +1: pick a mantissa-2 major divides by 4
00:00 +2: pick minor is null under the minor threshold
00:00 +3: pick imperial ladder in inches and feet
00:00 +4: pick imperial divisor is 4 even with a floor
00:00 +5: pick null past the top of the ladder, and for a bad scale
00:00 +6: pick a floor is exact when it fits and the ladder climbs from it
00:00 +7: pick the ladders are ascending and the metric one is 1-2-5
00:00 +8: formatLength per unit
00:00 +9: snapToGrid nearest, anchored at the sheet origin, negative side too
00:00 +10: snapToGrid an adaptive step lands on the drawn lattice
00:00 +11: snapToGrid refuses a non-positive step
00:00 +12: All tests passed!
```
Exit code: 0.

### Gate line (`packages/jet_cad_2d`), after the fixes

`CI=true dart test` (full suite), tail:
```
00:03 +857: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:03 +858: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:03 +859: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:03 +860: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +860: All tests passed!
```
Exit code: 0. (860 tests total — one more than round 0's 859, matching the
one net new test across findings 1–3's additions minus none removed... in
fact five new/changed assertions were added inside existing `test(...)`
blocks and one wholly new `test(...)` block was added for finding 2, so the
file's test count went from 11 to 12 — the package total moved from 859 to
860 accordingly.)

`dart analyze`:
```
Analyzing jet_cad_2d...
No issues found!
```
Exit code: 0.

`dart format --output=none --set-exit-if-changed .`: first run flagged the
edited test file as unformatted (`Changed test/geometry/grid_scale_test.dart`,
exit 1); ran `dart format test/geometry/grid_scale_test.dart` to apply
Dart's own line-wrapping (no logic change), then re-ran the gate command:
```
Formatted 125 files (0 changed) in 0.25 seconds.
```
Exit code: 0.

`git status --short` before committing showed only the two intended files
modified (`lib/src/geometry/grid_scale.dart`,
`test/geometry/grid_scale_test.dart`) — no `analysis_options.yaml` rewrite
this round, so nothing to restore.

### Files changed (fix round 1)

- Modified: `packages/jet_cad_2d/lib/src/geometry/grid_scale.dart`
- Modified: `packages/jet_cad_2d/test/geometry/grid_scale_test.dart`

Commit: `93e58ea` "fix(engine): imperial ladder as foot fractions, imperial
divisor with a floor, ladder tests". Trailer verified:
`git log -1 --format=%B | grep -c "Fable 5.1"` → `1`.

### Concerns

None. All six findings are addressed with a covering test that would have
failed against the pre-fix code (or, for findings 3, 5, 6, a test that
strengthens coverage against a named future mutation, per the coordinator's
own framing). Nothing outside `grid_scale.dart` and its test file was
touched.
