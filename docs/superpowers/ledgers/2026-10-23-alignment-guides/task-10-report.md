# Task 10 report: the allocation invariant

Status: DONE_WITH_CONCERNS. Commits:
- `dafb06b5` perf(plan): a service drag re-aims on a camera change without allocating
- `2eb1a2c6` test(plan): alignment guides add no allocation per event

## What landed

`packages/jet_cad_2d_plan/test/invariants/guide_allocation_test.dart` (7 tests):
- GA1/GA2: design move of 1 / 3 tables, end to end through `SelectTool` and `PlanMoveGuides`.
- GA3: placement (`PlanSymbolTool`, hover).
- GA4/GA5: service drag of 1 / 3 tables (`ServiceTool`).
- GA6: `GuidePainter`, 100 calls on a full solution (16 lines, 16 marks), zero `Offset`, `Paint`, `Path`, `_Float32List` (also `Vector2`, `Transform2`).
- GA7: `GuideSolution.lines`/`marks` capacity 64 each and `identical` across solves and `reset`, with 200 references and a 2000 mm aperture.

Each tool test runs control (no tool), guides off, guides on at 10 and at 200 references. The grid is off the origin; every 3rd table is turned 30 deg, every 5th 90 deg, every 4th mirrored; camera scale 0.5 and 0.5/0.62 across eight prebuilt cameras. Pointer targets are aligned to grid columns and rows within the aperture. A premise asserts the guides captured on more than 100 of the last round's 250 events (207 to 226 measured). Pointer events and cameras are prebuilt before metering; the drag is begun before metering.

Watched: `Vector2`, `Transform2`, `Aabb2`, `GuideSolution`, `GuideReferences`, `_Float64List`, and `_Set` (added so the brief's "Set per event" mutation is visible; it reads 0 on clean code).

## Method deviations from the brief (all forced by measurement)

1. **Per-epoch floor.** Each round is: reset, read (no events), reset, events, read; the net is the second minus the first. Without it the scene's live objects (the 64 prebuilt event `Vector2`s, `GuideReferences`, `GuideSolution`) read in every epoch (the meter's failure mode 1) and made on minus off a function of construction. `pick_allocation_test`'s hall does the same.
2. **The pointer window and the camera window are metered apart** (own reset and read each), 200 and 50 events, 3 rounds per scene.
3. **Assertion is `least(on) - most(off) <= 0.05 * events`, per window and class**, not a single on-minus-off. Reason: the JIT's escape analysis comes and goes on the *baseline's* own objects. Measured on identical code in successive rounds: the placement's `Transform2` reads 1600 then 200 per 200 events (pointer), the design camera `Vector2` reads 0 or 100 per 50 events. A single-number difference was a coin toss (observed on-off of +100 and -1500 on unchanged code). A real per-event allocation is in every round of the "on" scene, so its least stays high; the guides-off most is the baseline when the JIT has not removed it.
4. **Growth check:** `least(on at 200) <= most(on at 10) + 0.05 * events` per window and class.
5. **Warm-up 2000 pointer + 500 camera events** instead of 50: with 50, the baseline flickered between its two JIT states within the metered window. Rounds=3. Runtime: about 1 min per tool test, about 5 min for the file.
6. The control is a loop over the same prebuilt events and a bare `CameraController` set to the same cameras. Because the floor already cancels the meter's own noise, it reads 0 in every window and class.

## Measured numbers (instances per window, least..most over 3 rounds; pointer 200 events / camera 50 events; final code)

Control: 0..0 everywhere.

| tool, refs | off, pointer | on, pointer | off, camera (Vector2 / Transform2) | on, camera (Vector2 / Transform2) |
|---|---|---|---|---|
| design 1 table, 10 | T2 199, V2 0 | T2 200, V2 0 | V2 100, T2 50 | V2 91..100, T2 47..50 |
| design 1 table, 200 | T2 200 | T2 16..81 | V2 0..100, T2 49..50 | V2 1..100, T2 19..50 |
| design 3 tables, 10 | T2 200 | T2 200 | V2 0..100, T2 50 | V2 0, T2 49..50 |
| design 3 tables, 200 | T2 200 | T2 12..86 | V2 100, T2 50 | V2 1..100, T2 16..50 |
| placement, 10 | T2 1600 | T2 199..400 | V2 100, T2 400 | V2 100, T2 100 |
| placement, 200 | T2 200..400 | T2 8..162 | V2 100, T2 100 | V2 25..100, T2 27..100 |
| service 1 table, 10 and 200 | 0 | 0 | 0 | 0 |
| service 3 tables, 10 and 200 | 0 | 0 | 0 | 0 |

`Aabb2`, `GuideSolution`, `GuideReferences`, `_Set` read 0..0 everywhere. `_Float64List` equals `Vector2` in every cell (a `Vector2`'s storage). The baseline is today's: `GripDrag.moveTo` `Transform2` (1 per pointer event), `SelectTool._onCamera` two `Vector2`s per camera event, the placement's `placementTransform`s. In service, off has no listener, so its baseline is 0.

GuidePainter, 100 calls: `{Offset: 0, Paint: 0, Path: 0, _Float32List: 0, Vector2: 0, Transform2: 0}`.

## Lib change (the test found it)

`packages/jet_cad_2d_plan/lib/src/service/service_tool.dart`, `_reaim`: it called `camera.screenToWorld(Vector2(x, y))`, two `Vector2` (and two `_Float64List`) per camera change while guides are on. This is new work with no baseline in service (guides off registers no camera listener). It now inverts the camera's matrix from its coefficients (`det`, `d*sx - c*sy`, `a*sy - b*sx`) and calls `_aim`. Red before the fix (first run): `GA4 service drag of one table Vector2, camera-driven, 10 references: on 100..100, off 0..0, control 0 over 50 events`, expected <= 2.5, actual 100; GA5 the same. After: 0..0 in both windows at 10 and 200. `test/guides/service_guides_test.dart` stays green (+17). No other lib change; the solver, `PlanMoveGuides`, `_solveGuides` and `_aim` and `current` read clean.

## Mutations (each applied, run with `flutter test --enable-vmservice --name ...`, reverted; `git status` clean afterwards)

1. `GuidePainter` creates a `Paint` per call (GA6):
   `Paint: 100 over 100 paints`, expected <= 0.05, actual 1.0.
2. `GuidePainter` replaces `drawRawPoints` with `drawLine(Offset(..), Offset(..))` per segment (GA6):
   `GuidePainter over 100 calls: {Offset: 12800, ...}`, `Offset: 12800 over 100 paints`, actual 128.0.
3. `solveGuides` builds a `Float64List(refs.length * 2)` of candidates per solve (GA1, GA3, GA4):
   - GA1: `_Float64List, camera-driven, 10 references: on 150..150, off 100..100`, actual 50, expected <= 2.5.
   - GA3: `_Float64List, pointer-driven, 10 references: on 86..200, off 0..0 over 200 events`, actual 86, expected <= 10.0.
   - GA4: `_Float64List, camera-driven, 10 references: on 50..50, off 0..0`, actual 50.
4. `PlanMoveGuides.adjust` clones `raw` (GA1, GA2): a **local** clone stays green (the JIT scalar-replaces a non-escaping `Vector2`, see concerns). A clone **stored in a field** goes red:
   `GA1 Vector2, pointer-driven, 10 references: on 200..200, off 0..0, control 0 over 200 events` (actual 200, expected <= 10.0); GA2 the same.
5. The service re-solve builds `Set<Handle>.of(_movingSet)` per event (GA4, GA5):
   `_Set, pointer-driven, 10 references: on 200..200, off 0..0 over 200 events`, actual 200, expected <= 10.0; GA5 the same.
6. `_reaim` back to `screenToWorld(Vector2(..))`: red as shown above (the pre-fix run).
7. GA7: `lines` capacity `4 * kGuideCapacity + 4` gives `Expected: an object with length of <64>, Which: has length of <68>`; `lines` reassigned in `reset()` gives `Expected: true, Actual: <false>` on `identical`.

## Gate (real last lines)

`cd packages/jet_cad_2d_plan`:
- `flutter test --enable-vmservice`: `05:57 +1754: All tests passed!` (was +1747; the 7 new). `canvas_paint_allocation_test` green in the same run.
- `flutter analyze`: `No issues found! (ran in 3.8s)`
- `dart format --output=none --set-exit-if-changed .`: `Formatted 339 files (0 changed)`, exit 0.

Other packages:
- `cd packages/jet_cad_2d && dart test test/invariants`: `00:14 +117: All tests passed!`
- `cd packages/jet_cad_2d_flutter && flutter test test/invariants`: `00:02 +43: All tests passed!` (run without `--enable-vmservice`; I did not check whether some tests skip).

`git status --short` before each commit showed only the two intended paths; `analysis_options.yaml` was not staged.

## Concerns

- **Watched classes cannot see everything.** A `List<double>`/`_GrowableList`/`_Map` per event is invisible by design (the brief's list of noisy classes), so "`solveGuides` building a `List` of candidates" does not go red as a bare `List`; a `Float64List` of candidates does (mutation 3). A non-escaping `Vector2` clone is likewise eliminated by the JIT (mutation 4 local variant stayed green); only escaping allocations are caught, and only under the JIT. As with `pick_allocation_test`, nothing is proved about AOT.
- **The baseline's JIT flicker** is why the assertion is least(on) against most(off). If both a real guide allocation and a baseline JIT drop were tuned to cancel it would hide, but a persistent per-event allocation cannot (it sits in every round).
- **Runtime:** the file takes about 5 minutes under `--enable-vmservice` (GC settles in `reset`, 9 resets per scene and 6 scenes per tool test). Tests carry a 5-minute timeout; the default 30 s timed out. Rounds could drop to 2 if CI time matters, at some cost in flicker robustness.
- The camera window's tolerance is `0.05 * 50 = 2.5`, so a single allocation per 20 camera events passes; the pointer window's is 10 of 200. Same fractional budget as the brief; still two orders under per-reference growth.
- Design and placement `Vector2`/`Transform2` camera baselines (2 `Vector2` per camera event in `SelectTool._onCamera`; `Transform2`s in placement) are existing and untouched, as the spec states.
- Premise `captured` counts events where either axis captured; it is cumulative over the pointer and camera windows of a round (the 250 events).

## Fix round 1 (F1: CI time)

Before: the file ran about 5:05 (`05:05 +7`), each tool test about 60 to 75 s.
After: `01:31 +7: All tests passed!` (`flutter test --enable-vmservice test/invariants/guide_allocation_test.dart`: 94.4 s wall including compile); the longest test is about 15 s against a 5-minute timeout. The whole plan suite with `--enable-vmservice`: `03:21 +1754: All tests passed!` (3:24 wall).

Where the time went: not the events or the warm-up (cutting the warm-up from 2500 to 800 events saved nothing) but the meter's `reset()`, about 1 s each (a full GC). A control epoch with no tool took 5 s. Changes:
- the epoch floor is read once per scene, not once per round (it read identically in every round);
- rounds 3 to 2; warm-up 2000 + 500 to 600 + 200 events (the readings hold at that point);
- one control per tool test, not one per count (it reads 0 everywhere; its job is the meter's floor);
- one metered window of 200 pointer + 50 camera events per round, instead of two windows: 3 resets per scene (was 9). The 0.05 per event bound is unchanged (12.5 over 250 events) and every tool and count combination is kept (10 and 200 references; design 1 and 3, placement, service 1 and 3). Per-window budgets are gone, so the camera window's allowance is now shared with the pointer window.

Mutations re-run red after the change (`flutter test --enable-vmservice --name <GAx> test/invariants/guide_allocation_test.dart`, mutation reverted each time, `git status` shows only the test file):
- M1 Paint per call, GA6: `Paint: 100 over 100 paints`, actual 1.0.
- M2 drawLine with Offsets, GA6: `Offset: 12800 over 100 paints`, actual 128.0.
- M3 `Float64List` of candidates in `solveGuides`: GA1 `_Float64List, 10 references: on 157..350, off 100..100, control 0 over 250 events` (actual 57, expected <= 12.5); GA4 `_Float64List, 200 references: on 39..76, off 0..0` (actual 39); GA3 alone `on 211..350, off 100..100` (actual 111), with GA1 `on 350..350, off 100..100`. Note: in one three-test run (`GA[134] `) GA3 passed under this mutation while GA1 and GA4 were red; run alone or with GA1 it is red. The mutation is red in the file either way.
- M4 `PlanMoveGuides.adjust` keeps `raw.clone()` in a field: GA1 `Vector2, 10 references: on 249..350, off 0..100` (actual 149); GA2 `on 350..350, off 100..100` (actual 250).
- M5 `Set<Handle>.of(_movingSet)` per service event: GA4 `_Set, 200 references: on 63..93, off 0..0` (actual 63); GA5 `on 250..250, off 0..0` (actual 250).
- M6 `_reaim` back to `screenToWorld(Vector2(..))`: GA4 `_Float64List, 10 references: on 50..100, off 0..0` (actual 50); GA5 the same.
- M7 `lines` capacity +1, GA7: `Expected: an object with length of <64>`. M8 `lines` reallocated in `reset()`, GA7: `Expected: true, Actual: <false>`.

Gate: plan `flutter test --enable-vmservice` `03:21 +1754: All tests passed!`; `flutter analyze` `No issues found!`; `dart format` 339 files, 0 changed. `cd packages/jet_cad_2d_flutter && flutter test --enable-vmservice test/invariants`: `00:01 +43: All tests passed!`, nothing skipped (no skip lines in the output).

## Fix round 2 (growth check against the baseline envelope)

Change: the growth check now requires `onRanges[200].least[k] <= max(onRanges[10].most[k], offRanges[10].most[k], offRanges[200].most[k]) + 0.05 * events` (the baseline envelope), so a 10-reference run whose baseline `Vector2`s were all elided no longer fails a 200-reference run that was not. The 0.05 budget is unchanged. The on-vs-off check (`on.least - off.most`) is safe from elision: elision only lowers `on` (and `off.most` is the highest the baseline read), so it cannot fail from it; left as is.

Growth mutation, on its own (the on-vs-off expect temporarily neutralised in the test, a solver that allocates a `Float64List(2)` per reference only when `refs.length > 50`, run `flutter test --enable-vmservice --name "GA4 " ...`):
`GA4 service drag of one table _Float64List: guides on read more at 200 references (5000..6200) than the baseline envelope 0 (on at 10: 0..0)`, expected <= 12.5, actual 5000. With the on-vs-off check live the same mutation fails there first: GA1 `_Float64List, 200 references: on 5657..6277, off 0..100` (actual 5557), GA4 `on 15800..19200, off 0..0` (actual 15800).

Per-event mutations re-run red after the change (`bash /tmp/mut.sh`-style, each reverted; `git status` shows only the test file):
- M1 Paint per call, GA6: actual 1.0. M2 drawLine/Offset, GA6: actual 128.0.
- M3 Float64List of candidates: GA1 `_Float64List, 10 references: on 350..350, off 100..100` (actual 250); GA4 `200 references: on 52..90, off 0..0` (actual 52).
- M4 clone kept in a field: GA1 `Vector2, 10 references: on 350..350, off 0..100` (actual 250); GA2 `on 250..350, off 0..100` (actual 150).
- M5 Set per service event: GA4 `_Set, 10 references: on 220..250, off 0..0` (actual 220).
- M6 `_reaim` back to `screenToWorld`: GA4 `_Float64List, 10 references: on 50..100, off 0..0` (actual 50); GA5 `Vector2: on 100..100, off 0..0` (actual 100).
- M7 and M8 (GA7 capacity and identity): red.

Full plan suite, `flutter test --enable-vmservice`, three runs, last lines: `03:33 +1754: All tests passed!`, `03:48 +1754: All tests passed!`, `04:13 +1754: All tests passed!` (no `[E]` lines). `flutter analyze`: No issues found. `dart format`: 339 files, 0 changed.
