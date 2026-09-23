# Task 8 report: the sample plan's furniture becomes filled regions

## What I implemented

`apps/floor_planner/lib/startup_plan.dart`:

- Added `import 'package:vector_math/vector_math_64.dart' show Vector2;`.
- Added three new `_Pen` methods (plus one private helper), immediately
  after `circle`:
  - `_region(EntityKind kind, GeometryPayload payload)` — calls
    `addDraftedRegion(doc, kind, payload, boundaryColor: _furnitureColor,
    boundaryLineweight: 25)!` and executes it.
  - `rectRegion(ax, ay, bx, by)` — a rectangle boundary via
    `rectanglePayload`.
  - `polygonRegion(List<double> xy)` — a closed polyline boundary via
    `polylinePayload(..., closed: true)`.
  - `circleRegion(cx, cy, r)` — a circle boundary via `circlePayload`.
- Deleted the old `// --- Furniture: rectangles, one L. ---` block (9
  `p.rect`/`p.circle` calls, 30 entities: 4 lines × 7 rectangles + 2
  circles) from its old position, between the windows and the floor
  finishes.
- Re-added the furniture as 8 `p.rectRegion` / `p.polygonRegion` /
  `p.circleRegion` calls (bed, bed, sofa, table, the L-shaped counter as
  one closed hexagon, bath, lamp, basin), placed **after** the parquet
  call and **before** the `PageComponent.register` / page-setup code, with
  the same coordinates as before. Kept `p.rect`/`p.circle` themselves
  (still used by the walls and door swings/etc.), so nothing else changed.

`apps/floor_planner/test/startup_plan_test.dart`:

- Appended SP1 and SP2 exactly as specified in the brief, with one
  deliberate deviation (see below).

## Deviation from the brief's literal test code

The brief's SP1/SP2 snippets call `startupPlan(FlutterTextMeasurer())`
directly. The existing test file instead uses a `late FlutterTextMeasurer
measurer` built in `setUp` with `addTearDown(measurer.clear)`, and every
other test in the file calls `startupPlan(measurer)`. I used `measurer`
(the fixture) instead of constructing a fresh `FlutterTextMeasurer()`
inline, to stay consistent with the file's own convention and avoid an
uncleared measurer. This does not change what is asserted; it only changes
which measurer instance is threaded through. No other change to the
brief's test bodies.

Nothing in the brief's implementation code (`_region`/`rectRegion`/
`polygonRegion`/`circleRegion`, or the furniture-call block) needed to
change to compile or pass.

## TDD evidence

### RED

Command: `cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart`

Relevant output:

```
00:00 +5: SP1 the furniture is eight filled regions with the furniture outline
00:00 +5 -1: SP1 the furniture is eight filled regions with the furniture outline [E]
  Expected: an object with length of <8>
    Actual: []
     Which: has length of <0>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/startup_plan_test.dart 86:5                    main.<fn>

00:00 +5 -1: SP2 every fill draws over every floor-finish line (M-05r)
00:00 +6 -1: Some tests failed.

Failing tests:
  .../apps/floor_planner/test/startup_plan_test.dart: SP1 the furniture is eight filled regions with the furniture outline
```

Exit code: 1.

This matched the brief's prediction exactly: SP1 failed because it found 0
regions (no `addDraftedRegion` calls existed yet), and SP2 passed
*vacuously* — `minFill` was still `1 << 62` (no `EntityKind.fill` records
exist pre-implementation), which is trivially greater than any
`maxFinish`. That vacuous pass is expected and is called out in the brief
("SP2's `minFill` is `1 << 62`"); it only becomes a real check once fills
exist.

### GREEN

Command: `cd apps/floor_planner && CI=true flutter test test/startup_plan_test.dart`

```
00:00 +5: the startup plan carries an A4 landscape page at 1:50 centred on the plan, in millimetres, with no history
00:00 +6: SP1 the furniture is eight filled regions with the furniture outline
00:00 +7: SP2 every fill draws over every floor-finish line (M-05r)
00:00 +7: All tests passed!
```

Exit code: 0. `doc.entities.liveCount` is exactly `509`, matching Ruling
05-12's arithmetic (523 measured − 14; the rebuild turns 30 furniture
entities into 8 regions of 2 = 16 entities, net change 16 − 30 = −14, so
523 − 14 = 509). No investigation of a mismatch was needed — the measured
count matched the brief's number on the first GREEN run.

Full whole-app suite:

Command: `cd apps/floor_planner && CI=true flutter test`

```
00:03 +43: All tests passed!
```

43 tests total (26 original + 15 A-series from Task 7 + SP1 + SP2 = 43),
matching the dispatch's note that Task 7 landed 41 and this task adds 2
more.

## Gate line (apps/floor_planner)

```sh
cd apps/floor_planner && CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed . && flutter build macos --release && flutter build web --release
```

- `CI=true flutter test`: `00:03 +43: All tests passed!` — exit 0.
- `flutter analyze`: `No issues found! (ran in 1.3s)` — exit 0.
- `dart format --output=none --set-exit-if-changed .`: `Formatted 12 files
  (0 changed) in 0.04 seconds.` — exit 0 (no diff after `dart format
  lib/startup_plan.dart test/startup_plan_test.dart` was run first, ahead
  of the gate).
- `flutter build macos --release`: `✓ Built
  build/macos/Build/Products/Release/floor_planner.app (51.3MB)` — exit 0.
- `flutter build web --release`: `✓ Built build/web` — exit 0 (font
  tree-shaking and wasm-dry-run notices only, no errors).

All five commands passed; the gate is green.

## Files changed

- `apps/floor_planner/lib/startup_plan.dart`
- `apps/floor_planner/test/startup_plan_test.dart`

## Self-review

- **Completeness.** All 8 furniture pieces from the original block are
  present as regions with identical coordinates; none dropped or
  duplicated. Verified by SP1's `hasLength(8)` and by re-reading the
  diff coordinate-by-coordinate against the deleted block.
- **Names.** `_region` (private, the shared helper), `rectRegion`,
  `polygonRegion`, `circleRegion` — matches the brief's specified names
  exactly.
- **YAGNI.** No extra parameters or generality added beyond what the 9
  call sites need (no per-call color/lineweight override, since D14 fixes
  both for all furniture regions).
- **Pristine output.** `flutter analyze` reports no issues; `_Pen.rect` and
  `_Pen.circle` remain used (by walls and nothing else got orphaned).
- **Mutation coverage.**
  - A mutant that emits the furniture block *before* `p.parquet(...)`
    (i.e., reverts the reordering) would make SP2 fail: the fill handles
    would then be lower than the finish-line handles emitted afterward, so
    `minFill > maxFinish` would not hold (in fact some fill handles would
    be below some finish handles, or `maxFinish` would exceed the lowest
    fill). I did not re-run this as a live mutant (the brief did not ask
    for one to be hand-verified for this task, unlike some other Plan 05
    tasks), but traced it through by hand: with furniture before finishes,
    the finish lines (grid/parquet, ~470+ entities) get handles above the
    furniture's, so `maxFinish` (a finish-line handle) would exceed
    `minFill` (a fill handle), failing `expect(minFill,
    greaterThan(maxFinish))`.
  - A mutant that drops `boundaryLineweight: 25` (or passes a different
    value) would fail SP1's `expect(r.lineweight, 25)`.
  - A mutant that uses `kByLayer`/default `boundaryColor` instead of
    `_furnitureColor` would fail SP1's `expect(r.color, const
    TrueColor(0x8A6D3B))`.
  - A mutant that used a plain `addDrafted` (a boundary with no fill)
    instead of `addDraftedRegion` would leave `doc.fills.fillsOf(h)` empty
    for every furniture handle, so SP1's `boundaries` list would stay
    empty and `hasLength(8)` would fail — this is exactly the RED state
    observed before implementation.
- **`_Pen.rect`** is still used (by the exterior/interior walls), so it
  was kept, per the brief's fallback instruction.

## Concerns

- None blocking. The one deviation (using the test file's `measurer`
  fixture instead of a bare `FlutterTextMeasurer()`) is cosmetic and
  documented above.
- Per the attribution system-reminder in effect for this session, the
  commit trailer names the model that actually wrote the commit —
  `Claude Sonnet 5 <noreply@anthropic.com>` — rather than the "Opus 5.5"
  trailer text shown verbatim in the brief's example command; the
  implementer-common.md instructions agree ("naming the model that
  actually wrote the commit").

## Commit

`c4fcac4 feat(app): the sample plan's furniture as filled regions`

`git log -1 --format=%B | grep -c "Sonnet 5"` → `1`. `git status --short`
is clean (no `analysis_options.yaml` rewrite to revert).
