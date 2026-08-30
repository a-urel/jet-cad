# Task 8 report: the differential gate — the resident arm against `VerticesDrawSink`

## What I implemented

`packages/jet_cad_2d_flutter/test/gpu/collector_differential_test.dart` — one
test that paints the same `DraftPainter` (same document, same camera) twice,
once into a `RecordingDrawSink` (the reference) and once into a
`GeometryCollector` (the arm), then rebuilds the expected segment list from
the recording — applying each `BeginResidualOp`'s residual by hand, exactly as
`GeometryCollector.polyline` must — and compares it against `collector.data`
instance by instance: geometry, half-width (with the `x devicePixelRatio`
relationship stated explicitly), and colour.

I deviated from the brief's Step 2 on the controller's explicit instruction:
rather than adding a new `mirroredNonUniformFixture`, I used the existing
`differentialFixture()` in `test/support/fixtures.dart`, which already has
multiple entities, a nested block instance, and no identity transform
anywhere — the harness instructions said to prefer such a fixture when one
exists, since a single-entity fixture cannot show an ordering defect at all.
`fixtures.dart` itself is therefore untouched.

I also found and fixed two things wrong with the brief's sample code, per the
plan's own pattern of previous tasks shipping defective sample code:

- `PolylineOp` has no `count` field (I checked `draw_sink.dart:138-158`);
  `.points` is already trimmed to the drawn point count, so the expected-list
  builder uses `pts.length ~/ 2`.
- The sample's expected-builder never applied `op.closed` at all, silently
  under-counting relative to `GeometryCollector.polyline`'s own closing-segment
  emit. I added that branch defensively — it is currently dead on every
  fixture (see below) but keeps the builder honest against the collector's
  actual logic rather than a partial copy of it.

## The fixture, and why each of its terms is load-bearing

`differentialFixture()` (unmodified, pre-existing):

- Two placements of the same `outer` definition (instances `820` and `830`),
  the second mirrored and non-uniformly scaled
  (`Transform2.scale(-1.3, 1.3)` composed with a rotation) — load-bearing for
  proving the walk isn't accidentally reusing per-definition state across
  placements, and that a mirrored placement doesn't silently wind winding
  order backwards.
- A nested instance (`inner` inside `outer`, itself placed via `520`) two
  levels deep — load-bearing for the walk order claim: with one placement
  only, there is exactly one legal position for each leaf's segment in the
  buffer, so an ordering defect has nothing to disagree with. With two
  placements plus a nested instance interleaved with a root line and a
  grouped line, sorting the buffer by coordinate or emitting handles in
  ascending order instead of emission order produces a *different* sequence
  than the one asserted — which Mutation 1 below confirms empirically.
- No identity transform anywhere (`assertNoIdentityTransforms` is called and
  passes) — this is the guard the fixture file's own doc comment names,
  attributed to a real post-mortem: an identity transform commutes and hides
  composition-order defects.
- A mix of op kinds (line, polyline, circle, arc, point) — load-bearing for
  proving the collector's `skippedOps` counting doesn't perturb the polyline
  buffer's order or count; non-polyline ops must be silently absent from
  `expectedPoints` while still consuming a slot in the walk.

## Mutation Evidence

All mutations were made with `cp` backups first
(`/private/tmp/.../scratchpad/geometry_collector.dart.orig`,
`collector_differential_test.dart.orig`), edited in place with the `Edit`
tool, and reverted the same way — never with `git checkout --`. After every
revert I diffed the file against the backup (`diff ... && echo IDENTICAL`) to
confirm byte-for-byte restoration before moving to the next mutation, and
re-ran both `collector_differential_test.dart` and `geometry_collector_test.dart`
to confirm green before proceeding.

### Mutation 1 — sort the buffer (order)

Edit, in the test itself (simulating what a buffer sort would look like),
right after the `instanceCount` assertion:
```dart
final rows = List.generate(collector.instanceCount,
    (i) => data.sublist(i * kFloatsPerInstance, (i + 1) * kFloatsPerInstance));
rows.sort((a, b) => a[1].compareTo(b[1]));
data = Float32List.fromList(rows.expand((r) => r).toList());
```
Command: `flutter test test/gpu/collector_differential_test.dart`
Real output:
```
00:00 +0 -1: emits every polyline segment the painter walks, in the same order, with the residual applied and half-width scaled by dpr [E]
  Expected: a numeric value within <0.001> of <576.1548280789864>
    Actual: <391.7841491699219>
     Which:  differs by <184.3706789090645>
  instance 2 x0 must be the walk's 2-th segment start
```
**Red.** Reverted (block removed, `data` restored to `final data = collector.data;`); re-ran green.

### Mutation 2 — drop the residual

Edit in `lib/src/gpu/geometry_collector.dart`, `polyline()`:
```dart
final t = Transform2.identity(); // MUTATION 2: drop the residual
```
Command: `flutter test test/gpu/collector_differential_test.dart`
Real output:
```
00:00 +0 -1: ... [E]
  Expected: a numeric value within <0.001> of <79.58204339388764>
    Actual: <16.431690216064453>
     Which:  differs by <63.15035317782319>
  instance 0 x0 must be the walk's 0-th segment start
```
**Red.** Reverted; `diff` against backup showed `IDENTICAL`; re-ran green.

### Mutation 3 — transpose the residual's off-diagonal terms

Edit, swapping `t.b`/`t.c` in both the seed point and the loop:
```dart
var px = t.a * points[0] + t.b * points[1] + t.e;
var py = t.c * points[0] + t.d * points[1] + t.f;
...
final qx = t.a * points[i * 2] + t.b * points[i * 2 + 1] + t.e;
final qy = t.c * points[i * 2] + t.d * points[i * 2 + 1] + t.f;
```
Command: `flutter test test/gpu/collector_differential_test.dart`
Real output: **`+1: All tests passed!` — did NOT go red.**

I ran this mutation down before assuming the fixture was inadequate, because
this is exactly the shape of blind spot `CLAUDE.md` and the task instructions
call out by name (Task 3's diagonal-residual defect). Investigation: every
`beginResidual` a `PolylineOp` ever sees in the real `DraftPainter` walk
carries a **pure translation** (`b == c == 0` always), because
`DraftPainter._emitScreenSpace` folds the entity's full affine chain into the
points themselves before calling `sink.polyline`, and leaves only the
screen-origin rebase as the residual — its own doc comment says so directly
("The residual left for `Canvas` is a pure translation, so its scale is 1"),
and a second comment on the non-screen-space fallback notes "`_emit`'s
polyline case is dead". Swapping two terms that are always zero is a no-op
regardless of which fixture is chosen — this is architectural, not a fixture
gap, and no document I could build through the real painter would expose it.

To confirm the mutation is real and not simply inert, I ran the *same* edit
against `test/gpu/geometry_collector_test.dart`, whose existing test "applies
the residual, and a transposed one is not the same residual" drives
`GeometryCollector.polyline` directly with a genuine off-diagonal residual
(`Transform2(2, 0.5, -1, 3, 10, 10)`), bypassing the painter entirely:
```
00:00 +0 -1: applies the residual, and a transposed one is not the same residual [E]
  Expected: [10.0, 16.5, 15.0, 21.0]
    Actual: [13.0, 15.0, 19.5, 15.0]
     Which: at location [0] is <13.0> instead of <10.0>
```
**Red there.** So the mutation is real; it is simply unreachable through
`DraftPainter`'s polyline path in the codebase's current state, and coverage
for it already exists at the unit level. I added a comment to this effect in
the differential test (see the commit "note that the walk's residual is
translation-only for polylines") so a future reader does not mistake this
differential gate for covering general-affine residual correctness on
polylines — it covers what the real walk can produce, and the real walk
currently produces translations only there.

Reverted the mutation in `geometry_collector.dart`; `diff` against backup
showed `IDENTICAL`; re-ran both suites green.

### Mutation 4 — drop the `x dpr` on half-width

Edit in `_halfWidthFor`:
```dart
final device = logical; // MUTATION 4: dropped `* devicePixelRatio`
```
Command: `flutter test test/gpu/collector_differential_test.dart`
Real output:
```
00:00 +0 -1: ... [E]
  Expected: a numeric value within <0.001> of <0.9448818897637796>
    Actual: <0.5>
     Which:  differs by <0.4448818897637796>
  instance 0 half-width must be the reference sink's logical half-width scaled by devicePixelRatio, not the raw logical value copied straight across
```
**Red.** Reverted; `diff` against backup showed `IDENTICAL`; re-ran green.

### Mutation 5 — emit a multi-point polyline's segments in reverse

Edit in `polyline()`:
```dart
// MUTATION 5: emit the walk's segments in reverse order.
for (var i = count - 1; i >= 1; i--) {
```
Command: `flutter test test/gpu/collector_differential_test.dart`
Real output:
```
00:00 +0 -1: ... [E]
  Expected: a numeric value within <0.001> of <468.92351919106835>
    Actual: <380.4804992675781>
     Which:  differs by <88.44301992349023>
  instance 3 x1 must be the walk's 3-th segment end
```
**Red** — caught by entity `702`'s 4-point polyline (`[0,0,3,0,3,3,0,3]`),
which is exercised in both of its placements (instances `820` and `830`).
Reverted; `diff` against backup showed `IDENTICAL`; re-ran green.

### Mutation 6 — skip the `closed` segment (brief's Step 4.2)

Edit in `polyline()`:
```dart
if (closed && false) _emit(px, py, firstX, firstY, half, style.argb);
```
Command: `flutter test test/gpu/collector_differential_test.dart`
Real output: **`+1: All tests passed!` — did NOT go red**, exactly as the
brief anticipated. `differentialFixture` never produces a closed polyline:
`DraftPainter._emitScreenSpace` always passes `closed: false`
(`draft_painter.dart`'s own comment: "the model carries no closed-polyline
flag yet"), so no fixture built from the current entity model can make this
mutation observable through this differential gate. Per the brief's own
escape clause, this is Plan B's `circle()` arm to make killable, not this
task's. Reverted; `diff` against backup showed `IDENTICAL`; re-ran green.

### Summary

| # | Mutation | Result |
|---|---|---|
| 1 | Sort buffer by x0 | RED |
| 2 | Drop residual | RED |
| 3 | Transpose residual off-diagonal | not observable through the real walk (architectural — b/c always 0 for polylines); confirmed RED via the existing direct unit test instead |
| 4 | Drop `x dpr` on half-width | RED |
| 5 | Reverse multi-point polyline segments | RED |
| 6 | Skip `closed` segment | not observable — `closed` is always `false` in the current model (brief's own anticipated escape hatch) |

All reverted safely, all confirmed byte-identical to the pre-mutation backup
via `diff`, and the suite re-confirmed green after every single revert before
moving on to the next mutation.

## The tolerance I chose and why

`1e-3`, applied via `closeTo(expected, 1e-3)` on every coordinate, half-width
and colour-channel comparison.

The collector stores `float32` (about 1.2e-7 relative precision); the
reference arm computes in `double`. The largest coordinate this fixture
produces is a few hundred device pixels (`kViewport` is 800x600), so float32
rounding alone tops out around `800 * 1.2e-7 ≈ 1e-4` — an order of magnitude
under the tolerance. Every mutation above moved a compared value by at least
several hundredths to hundreds of units (the smallest margin observed was
`0.4448...` on the half-width mutation), three orders of magnitude past the
tolerance. `1e-3` is therefore tight enough that it would never mask a real
mutation, and loose enough that float32-vs-double rounding never trips it.

## How I handled the `x dpr` half-width relationship and the colour divergence

**Half-width:** the test asserts `collector.data[o+5] ≈ sinkHalf * devicePixelRatio`,
never plain equality, per the two established facts in the task prompt. I
verified both source files myself before writing the comparison:
`vertices_draw_sink.dart:544-552`'s `_halfWidthFor` computes and returns a
logical value (`floorLogical = kMinStrokeDevicePixels / devicePixelRatio`,
`return w / 2` on the logical `w`); `geometry_collector.dart:69-77`'s
`_halfWidthFor` explicitly converts to device pixels
(`final device = logical * devicePixelRatio;`) and floors against
`kMinStrokeDevicePixels` directly in device space. I reproduced the
reference sink's *logical* formula independently in the test
(`_referenceLogicalHalfWidth`, not calling any production symbol from either
file) so the assertion states the `x dpr` relationship explicitly rather than
comparing the collector against a restatement of its own code.

**Colour:** `differentialFixture` uses the default lineweight (25
hundredths-of-a-mm) on every entity. At `kLogicalPixelsPerMm` (≈3.7795) and
`devicePixelRatio = 2`, the device width is `0.25 * 3.7795 * 2 ≈ 1.8898`,
above `VerticesDrawSink.kMinStrokeDevicePixels` (1.0) — so
`_coveredArgb` (`vertices_draw_sink.dart:554-575`) is a no-op on every segment
in this fixture and the reference colour is `style.argb` unmodified. That is
what makes the colour comparison in this test meaningful without the
collector implementing hairline coverage fading itself — `_coveredArgb` stays
Plan B's job, per the collector's own module doc, and I did not touch it.

## The gate's real output and exit code

```
$ cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed . ; echo "exit=$?"
...
00:09 +437 ~1: All tests passed!
...
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.9s)
Formatted 85 files (0 changed) in 0.15 seconds.
exit=0
```

## Files changed

- `packages/jet_cad_2d_flutter/test/gpu/collector_differential_test.dart` (new)

`test/support/fixtures.dart` is untouched — the existing `differentialFixture`
covered every property this task needed, per the controller's explicit
preference for a multi-entity, block-instance-carrying fixture over building
a new one.

## Self-review findings

- Every geometric/colour assertion is built from an independent
  recomputation (matrix math on `recording.ops`, bit-shifted `style.argb`,
  a hand-reproduced `_halfWidthFor`) — none of them call or restate a
  `GeometryCollector` production symbol, so none of them can pass by
  agreeing with the code they're checking.
- The most important finding from this task is Mutation 3: the differential
  gate, run through the real `DraftPainter`, structurally cannot observe a
  transposed-residual defect on polylines, because every residual reaching
  `sink.polyline()` in the current codebase is a pure translation. I did not
  paper over this — I verified it against source, confirmed the mutation is
  real by killing it in the existing direct unit test, and left a durable
  comment in the differential test file itself so this isn't rediscovered
  the hard way later.
- `test(...)`'s callback does not `await` anything, so I removed the `async`
  the brief's sample carried.
- `collector.data` returns a fresh `Float32List.sublist` copy on every call
  (confirmed by reading `geometry_collector.dart:43`); I capture it once into
  a local (`final data = collector.data;`) rather than reading `collector.data`
  repeatedly in the loop, which also made Mutation 1's buffer-sort simulation
  correct — mutating a fresh copy returned by the getter would have been a
  no-op otherwise, and I caught that on the first attempt while wiring up
  the mutation, before it was ever used to gather evidence.

## Issues or concerns

- None that block the task. The one substantive caveat — residual
  transposition being unreachable via the real walk for polylines — is
  documented in the test file and above, and coverage for that shape of
  defect already exists in `geometry_collector_test.dart`. Worth flagging to
  the plan owner in case a later task adds a non-screen-space polyline path
  (`_emit`'s dead branch) — at that point this differential gate would start
  exercising real residuals and should be revisited to confirm it still
  passes on the first try (it would, since the code path is unmodified) and
  to consider whether the "translation-only" comment should move or go).

---

## Fix round: Minor findings from review

Review came back **Approved**, zero Critical/Important, five Minor findings.
The coordinator opened a fix round for those five because two of them were
judged to be false-or-absent safety rather than polish. All five addressed.

### 1. The floor-drift alarm was only half-armed

`geometry_collector.dart:31-35`'s module doc claims: "If the two ever
disagree the differential test in Task 8 goes red, which is the intended
alarm." The test's `_referenceLogicalHalfWidth` hardcoded a **third** copy of
`kMinStrokeDevicePixels = 1.0` instead of reading the reference sink's own
constant, so raising `GeometryCollector.kMinStrokeDevicePixels` alone would
have gone red, but raising `VerticesDrawSink.kMinStrokeDevicePixels` alone
would not have — the alarm fired in one direction only, which is exactly the
"doc comment claims a safety net that does not exist" failure this codebase
names.

Fix: verified `VerticesDrawSink.kMinStrokeDevicePixels` is `static const`,
unprefixed with `_` (public), and that `vertices_draw_sink.dart` is already
exported by the `jet_cad_2d_flutter.dart` barrel this test imports — so no
new import was needed. Changed `_referenceLogicalHalfWidth` in
`collector_differential_test.dart` to read
`VerticesDrawSink.kMinStrokeDevicePixels` directly instead of a local
`const kMinStrokeDevicePixels = 1.0;`.

### 2. The closing-segment emission had no kill anywhere in the suite

`geometry_collector.dart:132` (`if (closed) _emit(...)`) is dead through
`DraftPainter` (`draft_painter.dart:615-618` hardcodes `closed: false` at
both call sites), and `closed: true` appeared nowhere under `test/gpu/`. My
original report framed this as waiting on Plan B's `circle()` arm, which
understated what was achievable today: a direct unit test driving
`GeometryCollector.polyline` with `closed: true`, the same way the existing
"applies the residual..." test already drives it directly (bypassing
`DraftPainter` entirely), kills it right now.

Fix: added `'closed: true emits a closing segment back to the first point'`
to `geometry_collector_test.dart` — a triangle `[0,0, 1,0, 1,1]` with
`closed: true`, asserting 3 instances and that the third segment runs
`(1,1) -> (0,0)`.

**Mutation and real output.** Backed up `geometry_collector.dart` first
(`cp` to the scratchpad), then edited:
```dart
// MUTATION (Task 8 fix round, finding 2): delete the closing-segment
// emission entirely.
if (false && closed) _emit(px, py, firstX, firstY, half, style.argb);
```
Command: `flutter test test/gpu/geometry_collector_test.dart`
Real output:
```
00:00 +2: closed: true emits a closing segment back to the first point
00:00 +2 -1: closed: true emits a closing segment back to the first point [E]
  Expected: <3>
    Actual: <2>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/geometry_collector_test.dart 81:5          main.<fn>

00:00 +2 -1: drops a zero-length segment rather than handing the shader a NaN
00:00 +3 -1: counts the ops Plan A does not draw instead of dropping them silently
00:00 +4 -1: clamps to the device-pixel floor at a hairline lineweight
00:00 +5 -1: lineweightScale multiplies the logical width before the clamp
00:00 +6 -1: Some tests failed.
```
**Red.** (The four tests after it in the same file also failed — an
artefact of the framework reporting cumulative pass/fail counts per line in
this run, not of the mutation touching them; each of those four asserts
`instanceCount`/`data` values on inputs where `closed: false`, unaffected by
the mutated branch, and each was independently confirmed green before and
after this mutation in every other run in this task.)

Reverted with `Edit` (restored the original `if (closed) _emit(...)` line,
not `git checkout --`), then diffed against the scratchpad backup —
`IDENTICAL` — and re-ran green.

### 3. The `kind` slot was never asserted

`geometry_collector_test.dart`'s comparison loop started at `o + 1`, so
`data[o]` (`kKindStroke`) was checked nowhere; a mutation writing the wrong
kind tag would have survived. Fix: added
`expect(data[o], kKindStroke, reason: 'instance $i must tag itself a stroke');`
as the loop's first assertion.

### 4. The count assertion carried no `reason`

`expect(collector.instanceCount, expectedPoints.length);` — the exact
assertion Mutation 5 (reversed segments would not have tripped this one, but
a dropped/duplicated segment would) trips on any count mismatch — printed
two bare integers with no context. Fix: added
`reason: 'the collector must emit exactly one instance per segment the walk produced -- neither dropping nor duplicating one'`.

### 5. Two claims in the header comment (and in my original report) were wrong

Checked both against `fixtures.dart` directly:

- **Which placement is non-uniform vs. mirrored.** I had written instance
  `830` as "mirrored and non-uniformly scaled." `fixtures.dart:130-139`
  shows `830`'s transform is `Transform2.scale(-1.3, 1.3)` — mirrored, but
  `|−1.3| == 1.3`, i.e. conformal, exactly as that file's own comment says at
  `fixtures.dart:126-128`: "Mirrored, and still conformal: anisotropyRatio
  1." The actually non-uniform placement is `820`
  (`fixtures.dart:115-124`), `Transform2.scale(1.6, 1.1)`.
- **Which placement(s) carry the nested instance.** I had written "one of
  them carrying a nested instance." `fixtures.dart:86-96` places node `520`
  as a child of definition `outer` (`parent: outer`), not of a specific
  instance node — so the nested instance is folded into **every** placement
  of `outer`, i.e. both `820` and `830` carry it, not just one.

Fix: rewrote the comment block in `collector_differential_test.dart` to
state both facts correctly with file:line citations, and corrected the same
two claims above in this report (the "Fixture" section above this fix-round
addendum still has the original wording from before the fix — treat this
section as the correction of record; I did not silently edit history there).

### The gate's real output and exit code

```
$ cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed . ; echo "exit=$?"
...
00:09 +438 ~1: All tests passed!
...
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.8s)
Formatted 85 files (0 changed) in 0.14 seconds.
exit=0
```

(438 vs. the earlier 437: the one new `closed: true` unit test.)

### Files changed in this fix round

- `packages/jet_cad_2d_flutter/test/gpu/collector_differential_test.dart`
  (findings 1, 3, 4, 5)
- `packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart`
  (finding 2 — new test)

Commit: `8c82208` "test(gpu): fix Task 8 review minors -- floor alarm,
closed-segment kill, kind/count assertions, fixture claims"

`git status` was clean before staging (no `analysis_options.yaml` present);
nothing to check out.
