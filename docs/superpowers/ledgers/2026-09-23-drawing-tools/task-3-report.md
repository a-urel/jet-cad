# Task 3 report: `PlacementTool`, the draw fixture, and `LineTool`

Commit: `a5ed921` "feat(draw): PlacementTool and the chained line tool"

## What was implemented

- `packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart`: the
  abstract `PlacementTool extends Tool` base — placed points, the reused
  `band`/`bandPaint`, hover resolution through the tool's own points then
  03's `resolveDragPoint`, the camera listener while a shape is pending,
  Escape/Enter/shift handling, `commit`/`commitShape` (permission check
  before the handle is allocated, Ruling 05-3).
- `packages/jet_cad_2d_flutter/lib/src/draw/line_tool.dart`: `LineTool
  extends PlacementTool`, AutoCAD-style chained LINE — each click commits
  one segment whose end becomes the next start; a self-snap onto the
  current start (once a segment exists) closes the chain instead of
  drawing a zero-length one.
- `packages/jet_cad_2d_flutter/test/support/draw_fixture.dart`: `DrawScene`
  / `drawScene`, `DrawRig` / `drawRig`, `worldAt`, `hoverAt`, `downAt`,
  `clickAt`, `keyDown`, `kAnchorX`/`kAnchorY`.
- `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart`: added
  `export 'src/draw/placement_tool.dart';` and
  `export 'src/draw/line_tool.dart';` after `src/draw_sink.dart`.
- Tests: `test/draw/placement_tool_test.dart` (B1–B9, 12 cases counting the
  three flipY-grouped tests twice) and `test/draw/line_tool_test.dart`
  (L1–L6, 7 cases counting L1 twice) — all taken verbatim from the brief.

All code and tests are exactly the brief's code, with one deviation (see
Deviations below).

## TDD evidence

**RED** — `cd packages/jet_cad_2d_flutter && CI=true flutter test
test/draw/placement_tool_test.dart test/draw/line_tool_test.dart`, run
before `placement_tool.dart`/`line_tool.dart` existed:

```
test/draw/line_tool_test.dart:79:37: Error: Method not found: 'LineTool'.
    final rig = drawRig(s.document, LineTool());
                                    ^^^^^^^^
test/support/draw_fixture.dart:68:9: Error: 'PlacementTool' isn't a type.
  final PlacementTool tool;
        ^^^^^^^^^^^^^
...
  Failed to load ".../line_tool_test.dart": Compilation failed ...:
  Error when reading 'lib/src/draw/line_tool.dart': No such file or directory
  Error when reading 'lib/src/draw/placement_tool.dart': No such file or directory
00:00 +0 -2: Some tests failed.
```

Expected and matches the brief's Step 3 ("compile errors, because
`placement_tool.dart` and `line_tool.dart` do not exist").

**GREEN** — after writing both implementation files and the barrel export,
`cd packages/jet_cad_2d_flutter && CI=true flutter test test/draw/`:

```
00:00 +19: All tests passed!
```

19 test cases: 12 in `placement_tool_test.dart` (B1–B3 doubled by the
`flipY` loop, plus B4–B9) and 7 in `line_tool_test.dart` (L1 doubled by
`flipY`, plus L2–L6) — matches the brief's expected count exactly.

## Gate line output

```
cd packages/jet_cad_2d_flutter && CI=true flutter test ; flutter analyze && dart format --output=none --set-exit-if-changed .
```

- `flutter test` (whole suite): `00:12 +873 ~1 -5: Some tests failed.`
  Exit code 1. The five failures are exactly the standing
  `test/golden/text_ladder_golden_test.dart` rungs 1–5
  (`RenderBackend.canvas`); nothing else failed. 873 = the branch-point 854
  + the 19 new tests. 1 skip carried over, matching the documented standing
  exception.
- `flutter analyze`: `No issues found!` Exit 0.
- `dart format --output=none --set-exit-if-changed .`: `Formatted 164 files
  (0 changed)`. Exit 0.

`git status --short` after the commit is clean; no `analysis_options.yaml`
was touched.

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/draw/placement_tool.dart` (new)
- `packages/jet_cad_2d_flutter/lib/src/draw/line_tool.dart` (new)
- `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` (modified:
  2 export lines added)
- `packages/jet_cad_2d_flutter/test/support/draw_fixture.dart` (new)
- `packages/jet_cad_2d_flutter/test/draw/placement_tool_test.dart` (new)
- `packages/jet_cad_2d_flutter/test/draw/line_tool_test.dart` (new)

## Self-review

- **Completeness against the brief's `Produces` block**: every member
  listed (`fill`, `points`, `acceptingSelf`, `band`, `bandPaint`,
  `isPending`, `hoverPoint`, `hoverVisible`, `hoverKind`, `orthoBase`,
  `selfSnap`, `accept`, `finish`, `hovered`, `clearShape`,
  `paintRubberBand`, `commit`, `commitShape`) is present with the exact
  signature. `LineTool()` has no extra public surface.
- **Invariant 4** (02's Tool API unchanged): `git diff -- lib/src/tool.dart
  lib/src/interaction_layer.dart` is empty — neither file was touched.
- **Pure-Dart engine**: no edits under `packages/jet_cad_2d`; this task is
  entirely in `jet_cad_2d_flutter`.
- **Frame-path allocation (D12)**: `band` and `bandPaint` are instance
  fields, reset (`band.reset()`) rather than reallocated per frame in
  `LineTool.paintRubberBand`; `DragPoint`/`SnapResult` scratch objects are
  reused across calls (`_hover`, `_scratch`), matching 03's convention.
- **Draw order / stored-value exactness**: `LineTool.accept` passes the
  same `Vector2` instance (`point`) straight into `linePayload` and into
  the next segment's `points`, with no intermediate screen round trip —
  this is what keeps L1 (M-05k) and B1/B2 (M-05a) honest.
- **YAGNI**: nothing beyond what the brief's interface and the two test
  files exercise was added (no premature polyline/rectangle/etc. hooks
  beyond the extension points the brief itself specifies as abstract/
  overridable for later tasks).
- **Named mutants checked by hand against the tests**:
  - M-05a (screen point instead of world): B1/B2 assert against `worldAt`,
    not `screenOf`; `onPointerDown` uses `e.world` — confirmed by reading
    the implementation, not just running green.
  - M-05k (round-tripping the next start through
    `screenToWorld(worldToScreen(p))`): `LineTool.accept` reuses the exact
    `point` object handed to it by the base (which is either the self-snap
    stored instance or `Vector2.copy(_hover.point)` from `resolveDragPoint`,
    never derived from screen coordinates again) — L1 pins the joint's
    bits at the off-lattice anchor (7137.3, 3161.7).
  - M-05x (self-snap before the first segment): `LineTool.selfSnap` gates
    on `_segments > 0`; L3 is the direct test and would fail if that guard
    were dropped or if `_segments` weren't reset on `clearShape` (L2/L4
    would also drift).
  - Ruling 05-3 (permission check before allocation): `commit` returns
    `false` before calling `build()` when the capability is denied; B8
    checks both the snapshot and `handleSeed.current` are unchanged.
  - Ruling 05-13 (press-only placement): `onPointerMove` never calls
    `accept`; only `onPointerDown` does, gated on `kPrimaryButton`.
- I did not run a mutation tool in this task (not asked for at Task 3); the
  above is manual code-reading against the brief's named mutants, as the
  Testing bar in `CLAUDE.md` and the brief's self-review step ask for.

## Deviations from the brief's code

One, purely cosmetic: the brief's `test/draw/line_tool_test.dart` imports
`package:flutter/widgets.dart show Offset` alongside `flutter_test.dart`.
`flutter analyze` flagged that as `unnecessary_import` (info: `Offset` is
already provided transitively through `flutter_test.dart`). I dropped that
one import line; nothing else in the file changed. This is exactly the
kind of prune the brief's own Step 1 note anticipates for the fixture
("If `analyze` reports an import as unused once Tasks 3–6 are done ...
remove it") — I did the analogous thing for a test file once `analyze`
flagged it here, rather than leaving a lint on green code. No other line
of the brief's code was changed.

## Concerns

None. All interfaces consumed from Task 1 (`addDrafted`,
`addDraftedRegion`, `linePayload`, `isDegenerateSegment`) and from 03
(`resolveDragPoint`, `dragGridStepMm`, `kSnapAperturePixels`, `DragPoint`,
`SnapResult`, `drawSnapMarker`, the style constants) matched the brief's
expected signatures exactly on inspection before I wrote the
implementation files, so there were no surprises to reconcile mid-task.

## Fix round 1 (review findings, both Important, test-only)

Commit: `beb892a` "fix(draw): close two mutant gaps in B6/B7 and L5 (review
round 1)"

### Finding 1 — B6/B7 only checked "changed", not "changed to the right value"

B6 asserted `rig.tool.hoverPoint` `isNot(before)` after the pan, and B7
asserted only the pinned axis (`y`). Both hold under a mutant that makes
`PlacementTool._reresolve` treat the last screen point as if it were
already world space (`Vector2(_lastScreen.dx, _lastScreen.dy)` instead of
`ctx.camera.value.screenToWorld(...)`): the hover still changes to *some*
wrong value, and B7 never looked at `x` at all.

**Fix**, `test/draw/placement_tool_test.dart`:
- B6: after the pan, compute `w = worldAt(rig, screen)` and assert
  `rig.tool.hoverPoint.x == w.x` and `.y == w.y` exactly, before the
  `downAt` that reuses the same `w` for the committed segment's endpoint.
- B7: capture the hover screen point in `hoverScreen`, and after the shift
  key-down assert `rig.tool.hoverPoint.x == worldAt(rig, hoverScreen).x`
  (only `y` is pinned by ortho; `x` must still be the exact re-resolved raw
  value).

**Mutant applied** (`cp`-backed, restored with `cp` + `diff`), to
`lib/src/draw/placement_tool.dart`:

```dart
void _reresolve(ToolContext ctx) {
  // MUTANT (review finding 1): screen treated as world, no inverse camera.
  final world = Vector2(_lastScreen.dx, _lastScreen.dy);
  _resolve(ctx, world, _lastShift);
```

Command: `CI=true flutter test test/draw/placement_tool_test.dart`

RED output (both named tests failed, nothing else did):

```
00:00 +8: B6 a pan mid-shape re-resolves the hover, and the next click lands at the new camera's point (Review Focus 3)
00:00 +8 -1: B6 a pan mid-shape re-resolves the hover, and the next click lands at the new camera's point (Review Focus 3) [E]
  Expected: <7034.9491487101905>
    Actual: <213.8459675193917>
  the re-resolved hover is exactly the new camera's world point, not merely different from the stale one (a screen-as-world mutant in _reresolve would still satisfy isNot(before))
  test/draw/placement_tool_test.dart 131:5            main.<fn>

00:00 +8 -1: B7 shift pins the ortho axis from the last point, and a shift press re-resolves at once
00:00 +8 -2: B7 shift pins the ortho axis from the last point, and a shift press re-resolves at once [E]
  Expected: <7089.999999999998>
    Actual: <241.45057874954728>
  only y is pinned; x stays the raw resolved value, exact (a screen-as-world mutant in _reresolve would move x too)
  test/draw/placement_tool_test.dart 161:5            main.<fn>

00:00 +10 -2: Some tests failed.
```

Restore: `cp /tmp/placement_tool.dart.orig lib/src/draw/placement_tool.dart
&& diff /tmp/placement_tool.dart.orig lib/src/draw/placement_tool.dart` →
`RESTORE VERIFIED: no diff` (diff printed nothing, exit 0).

### Finding 2 — L5 could not tell Tolerance from `==`

L5 used `drawScene(snapToGrid: true)` and a screen offset of `(0.5, 0.5)`
that both clicks resolved to the identical lattice point, so the two world
points were bit-identical (`==` would already refuse it) and the test
never touched `isDegenerateSegment`'s tolerance comparison at all.

**Fix**, `test/draw/line_tool_test.dart`: `drawScene()` (grid off),
`objectSnap: false`, click `a`, then click `b = a + Offset(4e-10, 0)`.
Asserted `worldAt(rig, a)` and `worldAt(rig, b)` are `isNot` each other
(distinct stored values — otherwise the fixture would silently degenerate
back into an exact-equality case) and that their distance is
`lessThan(Tolerance.standard.linear)` (1e-9), then asserted the second
click is still refused.

**Mutant applied** (`cp`-backed, restored with `cp` + `diff`), to
`lib/src/draw/line_tool.dart`:

```dart
// MUTANT (review finding 2): exact == instead of Tolerance.
if (start == point) return;
```

Command: `CI=true flutter test test/draw/line_tool_test.dart`

RED output (L5 failed — the second click landed as a real, distinct
handle-19 line entity instead of being refused; nothing else failed):

```
00:00 +5: L5 a zero-length segment is refused under Tolerance, not under == (M-05?)
00:00 +5 -1: L5 a zero-length segment is refused under Tolerance, not under == (M-05?) [E]
  Expected: '...,"entities":[{"record":{"handle":18,...,"handleSeed":18}'
    Actual: '...,"entities":[{"record":{"handle":18,...},{"record":{"handle":19,"owner":17,"kind":"line",...},"geometry":{"coords":[7010.0199999999995,3020.01,7010.0200000003415,3020.010000000125],"scalars":[]}}],...,"handleSeed":19}'
     Which: is different.
  test/draw/line_tool_test.dart 108:5                 main.<fn>

00:00 +6 -1: Some tests failed.
```

Restore: `cp /tmp/line_tool.dart.orig lib/src/draw/line_tool.dart && diff
/tmp/line_tool.dart.orig lib/src/draw/line_tool.dart` → `RESTORE VERIFIED:
no diff` (diff printed nothing, exit 0).

### Re-run after the fix (both mutants restored)

`CI=true flutter test test/draw/`:

```
00:00 +19: All tests passed!
```

`dart format test/draw/placement_tool_test.dart
test/draw/line_tool_test.dart lib/src/draw/placement_tool.dart
lib/src/draw/line_tool.dart` reformatted only the one test line whose
wrapping changed (`Formatted 4 files (1 changed)`); re-ran `flutter test
test/draw/` after formatting, still `All tests passed!` (19).

Full gate line:

```
cd packages/jet_cad_2d_flutter && CI=true flutter test ; flutter analyze && dart format --output=none --set-exit-if-changed .
```

- `flutter test`: `00:12 +873 ~1 -5: Some tests failed.` Exit 1. The five
  failures are again exactly `test/golden/text_ladder_golden_test.dart`
  rungs 1–5 — unchanged from before the fix, since this round touched
  tests only.
- `flutter analyze`: `No issues found!` Exit 0.
- `dart format --output=none --set-exit-if-changed .`: `Formatted 164
  files (0 changed)`. Exit 0.

`git status --short` before the commit showed only the two test files
modified (`git diff --stat`: 2 files changed, 24 insertions, 5 deletions) —
no production file and no `analysis_options.yaml` touched, matching the
coordinator's "no production change expected".

### Files changed (fix round 1)

- `packages/jet_cad_2d_flutter/test/draw/placement_tool_test.dart`
  (B6, B7 strengthened)
- `packages/jet_cad_2d_flutter/test/draw/line_tool_test.dart`
  (L5 rewritten)
