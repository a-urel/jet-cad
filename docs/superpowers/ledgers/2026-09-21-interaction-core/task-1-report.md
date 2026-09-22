# Task 1 report: The branch point, and the band predicates

## What I implemented

- `packages/jet_cad_2d/lib/src/geometry/band_predicates.dart` (new): exact,
  per-entity-kind window/crossing predicates for a spatial band, plus the
  text-box helper Task 2 and Task 7 will call:
  - `TextBox` — the oriented glyph box (box-space bounds + box→leaf
    `Transform2`).
  - `textBoxOf(payload, textAttrs, style, metrics)` — resolves a text/attrib
    entity's laid-out box via `resolveTextAttributes` / `textLocalBounds` /
    `textLocalTransform`, mirroring `SpatialIndex._considerLeaf`'s "nothing to
    fill" rule (returns `null` for a degenerate box).
  - `boxEnclosedByBand(worldBox, band)` — spec D8's window predicate,
    inclusive on the edge.
  - `leafTouchedByBand(kind, payload, ta..tf, band, {textBox})` — spec D8's
    crossing predicate, exact per `EntityKind`: point containment; polyline
    segment-vs-band via `clipSegment`; circle/arc rim-vs-band via
    `circleClipWindows` (arc additionally intersects the clip windows against
    the world sweep via `angleInSweep` and an endpoint-in-window check); text
    walks the four oriented box edges through the composed box→leaf→world
    transform; fill is never touched (no stroke to cross).
  - `leafTouchedByBandT(kind, payload, Transform2, band, {textBox})` — the
    `Transform2`-taking wrapper for tests and the differential arm.
- `packages/jet_cad_2d/lib/jet_cad_2d.dart`: added
  `export 'src/geometry/band_predicates.dart';` (alphabetical, after
  `aabb2.dart`).
- `packages/jet_cad_2d/test/geometry/band_predicates_test.dart` (new): 7
  tests, one per the brief's list, all fixtures under the non-identity
  `placement = Transform2.translation(300, -200)
  .multiply(Transform2.rotation(math.pi / 6)).multiply(Transform2.scale(1.5,
  1.5))`, bands placed in world space where the transformed geometry lands.

Implementation follows the brief's code sketch essentially verbatim; the only
changes were cosmetic (doc-comment wording) and what `dart format` reformatted
(wrapped a couple of long test lines, moved a doc-string). No signature,
import or logic changed from the sketch.

### Text-box fixture arithmetic (test 6)

Style `TextStyleRecord(handle: Handle(1), name: 'FAKE', fontFamily: 'fake',
fixedHeight: 0)`, `_FakeMeasurer` returning `advanceWidth: 20, ascent: 8,
descent: 2, capHeight: 7`, payload `[0, 0]` scalars `[5]` (height 5),
`textAttrs: 0` (left/baseline, no overrides). Worked out by hand (and checked
with a throwaway Python script reproducing `Transform2.multiply` and the
`textLocalTransform` composition) before writing the assertions:

- Glyph box (from `textLocalBounds`): x in `[0, 20]`, y in `[-2, 8]`.
- `textLocalTransform`: scale `height/capHeight = 5/7`, no rotation, no
  justification offset (left/baseline is the origin), anchor `(0, 0)` — so
  `box.local` is a pure `5/7` uniform scale with no translation.
- Leaf-space box (glyph box mapped through `box.local`): x in `[0, 100/7]`
  (≈14.29), y in `[-10/7, 40/7]` (≈-1.43..5.71).
- The test computes the right-edge midpoint, the box centre, and a point 2
  leaf units left of the box, all in leaf space via `tb.local.transformPoint`,
  then maps each through `placement` for the band centre. This keeps the
  fixture's own arithmetic in the same "leaf space, then `w()`/`placement`"
  idiom the other six tests use, rather than working out world-space
  coordinates by hand (rotation + uniform scale is conformal, so distances
  scale by 1.5 and angles are preserved, which is what makes the edge/centre/
  left assertions safe at half-size 1 in world space).

## TDD evidence

### RED

After writing the test file, I moved the (already-drafted) implementation
file out of the tree to get a genuine compile-failure before restoring it —
committed only the post-RED, post-GREEN state.

Command: `CI=true dart test test/geometry/band_predicates_test.dart` (with
`lib/src/geometry/band_predicates.dart` absent):

```
  test/geometry/band_predicates_test.dart:79:9: Error: Method not found: 'leafTouchedByBandT'.
  test/geometry/band_predicates_test.dart:130:17: Error: Method not found: 'textBoxOf'.
  test/geometry/band_predicates_test.dart:171:12: Error: Method not found: 'boxEnclosedByBand'.
  ... (12 error lines total, one per call site)
00:00 +0 -1: Some tests failed.

Failing tests:
  test/geometry/band_predicates_test.dart: loading test/geometry/band_predicates_test.dart
```

Expected: the test file references `leafTouchedByBandT`, `textBoxOf` and
`boxEnclosedByBand`, none of which exist yet without the implementation file.

### GREEN

Command: `CI=true dart test test/geometry/band_predicates_test.dart` (with
the implementation restored):

```
00:00 +0: loading test/geometry/band_predicates_test.dart
00:00 +0: a line is touched when the band crosses it and not when it sits beside it
00:00 +1: a band fully inside a closed polyline touches nothing
00:00 +2: a circle is touched on its rim, not in its interior
00:00 +3: an arc is touched only on its sweep
00:00 +4: a point is touched when inside
00:00 +5: a text is touched on its oriented box edges, through textBoxOf
00:00 +6: boxEnclosedByBand is inclusive on the edge and false when straddling
00:00 +7: All tests passed!
```

All 7 tests passed on the first run after restoring the implementation — no
implementation iteration was needed beyond the initial write (the fixture
arithmetic was verified by hand/script before writing the assertions, which
is why there was no red-implementation-red-fix cycle here).

## Package gate line

Command:
`cd packages/jet_cad_2d && CI=true dart test && dart analyze && dart format --output=none --set-exit-if-changed .`

Full-suite tail:

```
00:02 +802: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +803: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:03 +804: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:03 +805: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +805: All tests passed!
```

805 passing (798 baseline + 7 new). Exit code 0.

`dart analyze`:

```
Analyzing jet_cad_2d...
No issues found!
```

Exit code 0.

`dart format --output=none --set-exit-if-changed .`: first run reported 2
files needing formatting (`band_predicates.dart`, `band_predicates_test.dart`
— both from lines `dart format` itself judged too long/wrapped differently
than my draft), exit code 1. Ran `dart format` (without `--output=none
--set-exit-if-changed`) on those two files, then re-ran the check:

```
Formatted 115 files (0 changed) in 0.21 seconds.
```

Exit code 0.

Re-ran the focused test and the full suite after formatting to confirm
nothing broke: both green (7/7 and 805/805 respectively, shown above).

## Baselines (Step 1)

Captured by stashing the new work (`git stash push -u`, unique tag, applied
back via SHA rather than `pop`), running both baseline commands against
branch tip `76b5a2e`/`3fedeb9`, then restoring:

- `cd packages/jet_cad_2d && CI=true dart test`: `00:03 +798: All tests passed!`
  — **798**, matches the brief.
- `cd apps/dev_harness_2d && CI=true flutter test --concurrency=1`:
  `00:20 +82: All tests passed!` — **82**, matches the brief.

## Files changed

- `packages/jet_cad_2d/lib/src/geometry/band_predicates.dart` (new)
- `packages/jet_cad_2d/lib/jet_cad_2d.dart` (one export line added)
- `packages/jet_cad_2d/test/geometry/band_predicates_test.dart` (new)

Commit: `0ca5ca0 feat(geometry): band predicates, exact per entity kind`.

`git status --short` before committing showed only these three files; no
`analysis_options.yaml` was touched by `pub get` during this task, so no
restore was needed.

## Self-review findings

- Signatures, the `TextBox` class shape, and the internal algorithm match the
  brief's interface and code sketch exactly — no scope added beyond what was
  specified (no extra helpers, no extra exports).
- Every fixture in the test file sits under the required non-identity
  `placement`; no fixture uses the identity transform, the origin alone (all
  entities are offset from origin in local space), or default/degenerate
  attributes — the point/arc/circle/text fixtures all use non-trivial
  coordinates and the text fixture uses an asymmetric anchor implicitly via
  its own glyph-box geometry (box is not symmetric about the anchor since
  h=left, v=baseline).
- Checked that the arc test's "false" case is a real mutation-catching
  assertion, not a vacuous one: `w(-10, 0)` is the point a *full circle*
  would hit (the brief's own framing) — I verified by hand that with sweep
  `[0, pi/2]`, angle `pi` is outside it, so a mutant that dropped the sweep
  restriction (e.g. always returning `true` for `circleClipWindows() != 0`
  without the `angleInSweep`/`_angleInWindow` gate) would flip this
  assertion.
- Checked the circle test's radius-scaling assertion is real: with the
  `placement`'s uniform 1.5x scale, `w(10, 0)` sits at world distance exactly
  15 from the world centre `w(0, 0)`. A mutant that used the raw local radius
  (10) instead of `_scaleMagnitude(ta, tb, tc, td)`-scaled radius (15) would
  place the rim 5 world units short of this band, so `bandAt(w(10, 0), 2)`
  would miss and the assertion would flip from `isTrue` to a failure.
- `boxEnclosedByBand`'s two cases are a real edge/straddle pair, not two
  trivially-true or trivially-false checks: same box, one band exactly
  matching it (edge-inclusive) and one band covering only its upper-right
  quadrant (straddles two sides).
- No tolerance comparisons were introduced anywhere in this file — every
  comparison is `>=`/`<=`/`==` against stored or exactly-derived values, per
  the non-negotiable ("this task introduces no tolerance comparison" from the
  task instructions, and the file has no `Tolerance` import).
- No Flutter or `dart:ui` import in the new file or test — confirmed by
  reading the file back; only `dart:math`, `dart:typed_data`, `vector_math_64`
  and this package's own `document`/`store`/`geometry` modules.
- Ran `git status --short` immediately before staging and again after
  committing; only the three intended files ever appeared, so no
  `analysis_options.yaml` restore was needed at any point.

## Concerns

None. All tests pass, the package gate is fully green (test, analyze,
format), the two baselines match the brief's recorded counts exactly (798,
82), and the diff is scoped to exactly the three files the brief named.
