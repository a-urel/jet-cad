# Task 3 report — `drag_snap.dart`

## What I implemented

- `packages/jet_cad_2d/lib/src/index/drag_snap.dart` (new): `kDragSnapMask`,
  `kSnapAperturePixels`, `DragPoint`, `resolveDragPoint`, `dragGridStepMm`,
  exactly as the brief's Step 3 code (see deviation below).
- `packages/jet_cad_2d/lib/jet_cad_2d.dart`: added
  `export 'src/index/drag_snap.dart';` between the `dirty_list.dart` and
  `hit.dart` exports.
- `packages/jet_cad_2d/test/index/drag_snap_test.dart` (new): the brief's
  Step 1 test file verbatim, with one deviation (below).

Confirmed against the source before implementing:
- `SpatialIndex.snapInto(Vector2, double, SnapMask, SnapResult, {QueryFilter filter = const QueryFilter.rendering()})`
  — the brief's 4-positional-arg call uses the default `rendering` filter,
  as the interface list says.
- `SnapResult.found/kind/point`, `SnapMask.cheap`/`.with_`, `SnapKind` order
  — unchanged from `snap.dart`.
- `PageComponent.snapToGrid/gridStepMm/displayUnit/originX/originY` and
  `copyWith` — unchanged from `page_component.dart`.
- `GridScale.pick(DisplayUnit, double)` returning `GridScale?` with
  `majorMm`/`minorMm` — unchanged from `grid_scale.dart`.
- `snapToGrid(Vector2, double, PageComponent)` returns a fresh `Vector2` —
  unchanged.
- Spec D8 (`docs/superpowers/specs/2026-09-23-grips-and-transform-design.md`
  lines 482–561) and Ruling 03-11
  (`docs/superpowers/plans/2026-09-23-grips-and-transform.md` lines 101–105)
  match the brief's code and doc comments exactly.

## Deviation from the brief

The brief's test called `grid100.copyWith(gridStepMm: 250)` (an untyped int
literal) twice, in the `dragGridStepMm` test. `PageComponent.copyWith`
declares `gridStepMm` as `Object? gridStepMm = _keep` (the sentinel pattern
for a nullable field), not `double?`, so the argument position has static
type `Object?` and Dart's int-literal-to-double coercion (which only fires
in a `double`-typed context) does not apply — the `250` stays an `int` at
runtime. `copyWith` then does `gridStepMm as double?`, which throws
`type 'int' is not a subtype of type 'double?'`. This is pre-existing
`copyWith` behavior from an earlier task, out of this task's scope to
change. I changed the two literals to `250.0` in the test
(`test/index/drag_snap_test.dart` lines 163 and 165) — the smallest fix,
confirmed by checking that direct `PageComponent(...)` constructor calls
elsewhere in the suite (which declare `gridStepMm` as `double?` directly)
tolerate int literals as expected, whereas every existing `copyWith(gridStepMm: ...)`
call site in the repo already passes a double literal (`152.4`) or `null`.
No production code changed.

## TDD evidence

RED — `CI=true dart test test/index/drag_snap_test.dart` before creating
`drag_snap.dart`:
```
00:00 +0 -1: loading test/index/drag_snap_test.dart [E]
  Failed to load "test/index/drag_snap_test.dart":
  test/index/drag_snap_test.dart:46:1: Error: Type 'DragPoint' not found.
  ...
  test/index/drag_snap_test.dart:68:12: Error: Undefined name 'kDragSnapMask'.
  ...
  test/index/drag_snap_test.dart:159:12: Error: Method not found: 'dragGridStepMm'.
00:00 +0 -1: Some tests failed.
```
Expected: the new symbols don't exist yet.

After creating `drag_snap.dart` and the barrel export, a first green run
surfaced the `copyWith` int/double issue above:
```
00:00 +8 -1: dragGridStepMm: the page step exactly, else the adaptive minor (M-03aw) [E]
  type 'int' is not a subtype of type 'double?' in type cast
  package:jet_cad_2d/src/document/page_component.dart 170:26  PageComponent.copyWith
```
Fixed by changing the two literals to `250.0`.

GREEN — `CI=true dart test test/index/drag_snap_test.dart`:
```
00:00 +0: loading test/index/drag_snap_test.dart
00:00 +0: kDragSnapMask is the cheap kinds plus intersection
00:00 +1: the raw point passes through when nothing snaps
00:00 +2: ortho pins the minor world axis to the base (M-03f)
00:00 +3: an object snap overrides ortho, and is copied out of the scratch (invariant 7)
00:00 +4: an object snap beats a nearer grid point (M-03g)
00:00 +5: kind decides between object snaps through a drag (M-03b)
00:00 +6: a grid snap re-pins the ortho axis afterwards (M-03q)
00:00 +7: object snap off never snaps to an object: the grid wins (M-03x)
00:00 +8: dragGridStepMm: the page step exactly, else the adaptive minor (M-03aw)
00:00 +9: All tests passed!
```

## Gate lines

`packages/jet_cad_2d`:
```
$ CI=true dart test
...
00:04 +888: (tearDownAll)
00:04 +888: All tests passed!
$ dart analyze
Analyzing jet_cad_2d...
No issues found!
$ dart format --output=none --set-exit-if-changed .
Formatted 130 files (0 changed) in 0.23 seconds.
```
879 → 888 tests (9 new), all passing.

`packages/jet_cad_2d_flutter` (run because the barrel grew, per the brief):
```
$ CI=true flutter test
...
00:15 +797: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```
Exactly the five standing golden failures named in the implementer standing
instructions ("The render layer's `flutter test` exits 1 on exactly five
standing `test/golden/text_ladder_golden_test.dart` failures; any other
failure is yours."). No name clash from the grown barrel; nothing else
failed.
```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 3.6s)
$ dart format --output=none --set-exit-if-changed .
Formatted 148 files (0 changed) in 0.29 seconds.
```

`flutter analyze`/`flutter test` ran `flutter pub get` implicitly
(dependency resolution banner). Checked `git status --short` afterward —
no `analysis_options.yaml` rewrite; only the three files below were staged.

## Files changed

- `packages/jet_cad_2d/lib/src/index/drag_snap.dart` (new)
- `packages/jet_cad_2d/lib/jet_cad_2d.dart` (added one export line)
- `packages/jet_cad_2d/test/index/drag_snap_test.dart` (new)

## Self-review

- Re-read `drag_snap.dart` against the brief's Step 3 code: identical except
  the two int→double test literals above; no other change.
- Names, doc comments and structure match the spec's D8 section and the
  interfaces list exactly (`kDragSnapMask`, `kSnapAperturePixels`,
  `DragPoint`, `resolveDragPoint`, `dragGridStepMm`).
- Checked named mutants the brief's test comments cite (M-03f, M-03g, M-03b,
  M-03q, M-03x, M-03aw) each have a dedicated assertion that would go red
  under the described mutation:
  - M-03f: both ortho branches (x-free, y-free) asserted separately.
  - M-03g: object snap distance (5.8) is *farther* than the grid point
    (2.2) yet still wins — a "nearest wins" mutant would fail this.
  - M-03b: two object-snap candidates at different distances resolve by
    kind order, not distance — a distance-based mutant would fail this.
  - M-03q: ortho axis re-pinned *after* the grid snap; the test's two calls
    each check the axis not being snapped-to lands exactly on the base,
    not the raw or grid-snapped value.
  - M-03x: `objectSnap: false` over an entity within aperture confirms the
    object-snap branch is truly skipped, not merely deprioritized.
  - M-03aw: fixed-step exactness at two different zoom levels, plus the
    adaptive minor-vs-major branch.
  - Invariant 7 (scratch not held): a second `snapInto` call on the same
    scratch after `resolveDragPoint` returns is checked not to have
    mutated `out.point`.
  - Also confirmed by construction: the object-snap query uses `raw`, not
    the ortho-pinned `c` — the "object snap overrides ortho" test's chosen
    coordinates place `c` far outside the aperture of the line's endpoint,
    so a `snapInto(c, ...)` mutant would miss and this test would fail.
- No unused imports/elements; `dart analyze` and `flutter analyze` both
  clean.
- `dart format` clean on both packages before commit.
- No `analysis_options.yaml` touched or committed.

## Concerns

- The `copyWith` int/double-literal cast trap (`Object? gridStepMm = _keep`
  sentinel pattern accepting an int literal that fails to cast to
  `double?`) is a latent footgun in `PageComponent.copyWith`, from earlier
  committed work, outside this task's file list. It only surfaces when a
  caller passes an untyped integer literal to `copyWith(gridStepMm: ...)`;
  every existing call site already avoids it. Not fixed here since it is
  out of scope for Task 3, but worth a note for whoever next touches
  `page_component.dart`.

## Status

DONE.
