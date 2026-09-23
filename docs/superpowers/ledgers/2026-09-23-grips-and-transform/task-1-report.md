# Task 1 report — the branch point, and `grips.dart`

## What was implemented

- `packages/jet_cad_2d/lib/src/document/grips.dart` (new): `GripRole`,
  `Grip` (exact `==`/`hashCode`), `isClosedPolyline`, `leafGrips`,
  `reshapeLeaf`, and the private helpers `_distance`, `_wrapSweep`,
  `_degenerateSweep` — exactly as given in the brief's Step 4 code block,
  reformatted by `dart format` (line-wrap only, no logic change).
- `packages/jet_cad_2d/lib/jet_cad_2d.dart`: added
  `export 'src/document/grips.dart';` between `extents.dart` and
  `fill_index.dart`, as the brief specifies verbatim (this is not
  alphabetical — the rest of the barrel is — but it is the brief's explicit
  instruction, followed literally).
- `packages/jet_cad_2d/test/document/grips_test.dart` (new): the brief's
  test file verbatim (11 tests under `leafGrips` and `reshapeLeaf`,
  covering M-03y, M-03o, M-03r, M-03n and Ruling 03-1's witness).

No brief code needed changing to compile or pass — the implementation
compiled and passed on the first attempt after `dart format`.

## TDD evidence

**RED** — `cd packages/jet_cad_2d && CI=true dart test test/document/grips_test.dart`
(test file written, `lib/src/document/grips.dart` not yet created):

```
test/document/grips_test.dart:210:11: Error: Method not found: 'leafGrips'.
test/document/grips_test.dart:209:19: Error: Method not found: 'reshapeLeaf'.
... (leafGrips/reshapeLeaf/Grip/GripRole undefined throughout)
00:00 +0 -1: Some tests failed.
Failing tests:
  test/document/grips_test.dart: loading test/document/grips_test.dart
```

Expected: compile error naming `leafGrips`, `Grip`, `GripRole` as
undefined, per the brief's Step 3. Matches exactly.

**GREEN** — same command, after writing `grips.dart` and the barrel export:

```
cd packages/jet_cad_2d && CI=true dart test test/document/grips_test.dart
00:00 +0: loading test/document/grips_test.dart
00:00 +0: leafGrips the grip set per kind, in owner space (M-03y)
00:00 +1: leafGrips isClosedPolyline is an exact stored-value test
00:00 +2: reshapeLeaf a line stretch writes the grabbed pair and copies the rest
00:00 +3: reshapeLeaf a polyline middle-vertex stretch moves that vertex and nothing else (M-03o)
00:00 +4: reshapeLeaf a closed room corner moves as one: first and last pairs stay == (M-03r)
00:00 +5: reshapeLeaf a circle radius grip sets r = |target − centre|; degenerate is null
00:00 +6: reshapeLeaf an arc start stretch keeps the sweep direction and the end, both signs (Ruling 03-1)
00:00 +7: reshapeLeaf an arc end stretch on a negative sweep stays negative (M-03n)
00:00 +8: reshapeLeaf an arc radius grip copies the angles
00:00 +9: reshapeLeaf an arc stretch to a zero or a full sweep is null
00:00 +10: reshapeLeaf a move grip is not a reshape, and a kind without grips throws
00:00 +11: All tests passed!
```

## Step 1 — branch point (recorded in `progress.md`)

`git log --oneline -1` at start: `e376ced` (later than `c09b747`, as
required). `flutter pub get` at the worktree root rewrote one
`analysis_options.yaml` (`packages/jet_cad/analysis_options.yaml`),
restored with `git checkout --`. The four gate lines at the branch point:

- `packages/jet_cad_2d`: `CI=true dart test` → `+862: All tests passed!`;
  `dart analyze` → `No issues found!`; `dart format --output=none
  --set-exit-if-changed .` → `Formatted 125 files (0 changed)`.
- `packages/jet_cad_2d_flutter`: `CI=true flutter test` → `+797 ~1 -5: Some
  tests failed.`, all five failures in
  `test/golden/text_ladder_golden_test.dart` (rungs 1–5,
  `RenderBackend.canvas`) — the documented standing exception; `flutter
  analyze` → `No issues found!`; `dart format` → `Formatted 148 files (0
  changed)`.
- `apps/dev_harness_2d`: `CI=true flutter test --concurrency=1` →
  `+82: All tests passed!`; `flutter analyze` → `No issues found!`; `dart
  format` → `Formatted 22 files (0 changed)`.
- `apps/floor_planner`: `CI=true flutter test` → `+21: All tests passed!`;
  `flutter analyze` → `No issues found!`; `dart format` → `Formatted 7
  files (0 changed)`; `flutter build macos --release` → built
  `floor_planner.app` (51.0MB); `flutter build web --release` → `✓ Built
  build/web`.

These match the brief's Plan 04 merge counts (862 / 797 + 1 skip + five
goldens / 82 / 21 with both builds) exactly, so no discrepancy to record.

## Gate line for this task (`packages/jet_cad_2d`)

```
CI=true dart test
...
00:03 +873: All tests passed!

dart analyze
Analyzing jet_cad_2d...
No issues found!

dart format --output=none --set-exit-if-changed .
Formatted 127 files (0 changed) in 0.24 seconds.
```

873 = 862 (branch point) + 11 (new `grips_test.dart`). Exit codes: `dart
test` 0 (all passed), `dart analyze` 0 (no issues), `dart format
--set-exit-if-changed` 0 (0 changed).

## Files changed

- `packages/jet_cad_2d/lib/src/document/grips.dart` (new)
- `packages/jet_cad_2d/lib/jet_cad_2d.dart` (added one export line)
- `packages/jet_cad_2d/test/document/grips_test.dart` (new)

Commit `abd0d28`: `feat(engine): grips -- leafGrips, isClosedPolyline, reshapeLeaf`.
`git log -1 --format=%B | grep -c "Opus 5.5"` → `1`.

## Self-review

- **Completeness against the brief**: `GripRole`, `Grip` (const, exact
  `==`/`hashCode`), `isClosedPolyline`, `leafGrips`, `reshapeLeaf` all
  present with the exact signatures the brief's Interfaces section names.
  The barrel export sits exactly where instructed.
- **Names**: match the brief and spec D3 verbatim (`GripRole.stretch` /
  `.radius` / `.move`; `Grip.role/index/x/y`).
- **YAGN**: no members or behaviour beyond what D3 and the brief specify —
  no caching, no extra constructors, no public helpers beyond the four
  required functions.
- **Tests verify real behaviour, not identity-transform degenerate
  fixtures**: every fixture in `grips_test.dart` sits at x ≈ 7000–7550, y ≈
  3000–3330 (off the origin), includes a closed room, and arcs with a
  non-zero start and one negative sweep (`arcNeg`), per the spec's fixture
  rules. I traced the arithmetic by hand for the arc tests (start/end
  stretch, both sweep signs, the Ruling 03-1 wide-arc witness) against
  `_wrapSweep`/`_degenerateSweep` and it agrees with the test's expected
  values; the tests do exercise the branches a mutant would need to flip
  (index==0 vs index==1, direction sign in `_wrapSweep`, the closed-vs-open
  polyline count, the `i==0` mirror-write).
- **Mutation coverage named in the brief**: M-03y (grip set per kind),
  M-03o (middle-vertex stretch touches only that vertex), M-03r (closed
  corner moves as one), M-03n (negative-sweep end stretch stays negative),
  and Ruling 03-1's witness (the `wide` fixture, `s=4.0`) are all present
  as named tests, verbatim from the brief.
- **Pristine output**: `dart analyze` reports no issues; `dart format
  --set-exit-if-changed .` reports 0 changed after the format pass.

## Concerns

- The barrel's export ordering (`grips.dart` between `extents.dart` and
  `fill_index.dart`) breaks the file's otherwise-alphabetical convention.
  This is the brief's explicit, literal instruction, not an oversight on my
  part — flagging it in case a later task or reviewer expects strict
  alphabetical order and wants it moved (it would then sit between
  `fill_index.dart` and `header.dart`).
- No other concerns. No brief code needed correction to compile or pass.
