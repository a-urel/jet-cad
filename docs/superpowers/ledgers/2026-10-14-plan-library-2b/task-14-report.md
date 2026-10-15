# Task 14 report: the service tool, the picker's use and the allocation invariants

Status: DONE_WITH_CONCERNS (all gates green, every named mutation red; three
brief items needed changes to go red or to compile, listed under Deviations).

## Commits

- `fa4050e3` feat(plan): the service tool over units, placed and generated (2b S4)
- `23206e81` test(plan): pin a lone locked seat's tap in ST-locked-seat (M-ST-locked)
- `d50976ed` test(plan): PA4 and PA5 watch Transform2 over a no-pick baseline (M-PA-hall)

## What was implemented

- `lib/src/service/service_tool.dart` (new): today's `TableSelectTool` ported
  as `ServiceTool` with the brief's adaptations 1-19: `PlanLongPress`,
  `PlanFloorDrag`, `ServiceCallbacks` / `ServiceOptions` (no `serviceMoves`)
  / `ServiceEvents<M>` and their defaults, `ServiceHost` (+ `none`),
  `contextSelect(UnitInfo …)`, `moves` read at each press (`_moves`),
  `_startDrag` (placed roots only; spent on a locked or generated visible
  member, or an empty moving set), `_bandKeys` over `_units()`,
  `_groupLookup` with `GroupUnit(generated:)`, `_tap` / `_hover` /
  `_longPress` on labels, `secondaryClick`. Stale "table"/"number" words in
  the ported comments renamed to "unit"/"label" (comments only).
- `lib/src/service/service_session.dart`: constructor gains `groups`, `moves`;
  `@internal late final UnitPicker picker`, `@internal ServiceHost host =
  ServiceHost.none`, `late final ServiceTool tool`; `_IdleTool` and its
  imports deleted.
- `lib/src/controller/plan_controller.dart`, `_buildService`: `groups:
  unitGroups, moves: () => permissions.serviceMove`.
- `pubspec.yaml`: `vm_service: ^15.2.0` under `dev_dependencies` (R-23).
  `flutter pub get` from the root, `git status --short` showed only the
  pubspec; `dart run tool/ci/check_kit_deps.dart` → `kit dependencies: 1
  package(s) checked, none names the plan library or another kit`, exit 0.
- `.github/workflows/ci.yml`: the plan library's entry gains `test_flags:
  --enable-vmservice` (R-18); `tool/ci/test/scripts_test.dart`: SC20b.
- Test support: `unit_fixtures.dart` + `numberedRowOfTables`,
  `copyForService`; `service_rig.dart` (new, verbatim from the brief);
  `test/invariants/vm_allocation_meter.dart` (copied; `tail -n +2 | diff`
  against the oracle → identical but for the header line).
- Tests: `service_tool_units_test.dart` (8 new), ported
  `service_tool_test.dart` (ST1-ST17), `service_band_test.dart`
  (RB1-RB15b), `service_events_test.dart` (SE1-SE16),
  `pick_allocation_test.dart` (PA1-PA3 + PA4, PA5),
  `band_allocation_test.dart` (RB16 + RB16-hall, `bandFrames` extracted).
- Extra work 1: DC7 ported into `test/controller/unit_changes_test.dart` at
  its marker (marker removed; the header's "Task 14 ports it" now "ported
  it").

## TDD evidence

RED (`flutter test test/service/service_tool_units_test.dart`, before the tool):

```
test/service/service_tool_units_test.dart:14:8: Error: Error when reading 'lib/src/service/service_tool.dart': No such file or directory
test/support/service_rig.dart:15:8: Error: Error when reading 'lib/src/service/service_tool.dart': No such file or directory
test/support/service_rig.dart:58:14: Error: Type 'ServiceCallbacks' not found.
```

Expected: the file does not exist yet.

GREEN:

- `flutter test test/service/service_tool_units_test.dart` → `00:00 +8: All tests passed!`
- `flutter test test/service/service_tool_test.dart` → `00:00 +17: All tests passed!`
- `flutter test test/service/service_band_test.dart` → `00:00 +17: All tests passed!`
- `flutter test test/service/service_events_test.dart` → `00:00 +16: All tests passed!`
- `flutter test test/controller/unit_changes_test.dart` → `00:02 +19: All tests passed!`
- `flutter test --enable-vmservice test/invariants/pick_allocation_test.dart test/invariants/band_allocation_test.dart` (final state):

```
00:00 +0: PA1 a pick on the floor, with a finger's reach, allocates nothing per table: every table visited by all three passes
00:01 +1: PA2 a pick on the lowest table's top allocates nothing per table: every top visited
00:02 +2: PA3 a pick in the lowest table's box, off its top, allocates nothing per table: every top, then every box visited
00:04 +3: the hall PA4 a pick on the hall's floor, with a finger's reach, allocates nothing per seat: every seat visited by all three passes
00:06 +4: the hall PA5 a pick on the lowest seat's top allocates nothing per seat: every top above it visited
00:09 +5: All tests passed!
```

(pick file alone, after d50976ed), and with both files (before d50976ed,
band file unchanged since): `00:07 +7: All tests passed!` — RB16 and
RB16-hall included, no `Skip:` line in either run.

## Gates (final state, d50976ed)

- `cd packages/jet_cad_2d_plan && flutter test` → `00:46 +1130 ~7: All tests passed!` (7 skips: the 5 new allocation tests and the 2 existing canvas allocation tests, no VM service)
- `flutter test --enable-vmservice` → `00:55 +1137: All tests passed!` (nothing skipped)
- `flutter analyze` → `No issues found! (ran in 4.2s)`
- `dart format --output=none --set-exit-if-changed .` → `Formatted 247 files (0 changed)`, exit 0
- `cd tool/ci && dart test` → `00:45 +117: All tests passed!`
- `dart run tool/ci/check_kit_deps.dart` → exit 0 (quoted above)
- `git status --short` → empty after the commits. No `analysis_options.yaml` touched.

No failure in any run, so nothing to compare with `standing_failures.txt`.

## Mutations

Each mutation was applied to a committed file, the named test run, then
`git checkout -- <file>` and `git diff --quiet -- <file>` → `DIFF_QUIET 0`
every time.

| Mutation | Edit | Test | Red line (verbatim) |
|---|---|---|---|
| M-ST-seat | `_tap`: `SelectionKey.root(hit.owner ?? hit.instance)` | ST-seat | `Expected: Set:[SelectionKey:SelectionKey( 22)]` / `Actual: Set:[SelectionKey:SelectionKey( 1D)]` |
| M-ST-mixed | `_startDrag`: `if (k.chain.isEmpty)` | ST-mixed-drag | `The following GeneratedGeometryError was thrown running a test:` / `1E is generated by a parametric object and cannot be edited directly` (at `service_tool_units_test.dart:69`, `r.drag(from, by)`) |
| M-ST-group | `_startDrag`: `\|\| lookup.hasGeneratedVisibleMember(id)` deleted | ST-group-seat | `The following GeneratedGeometryError was thrown running a test:` / `1E is generated by a parametric object and cannot be edited directly` (at `:97`, `r.drag(…)`) |
| M-ST-locked | `_tap`: `if (true) {` | ST-locked-seat (after 23206e81) | `Expected: empty` / `Actual: Set:[SelectionKey:SelectionKey( 26)]` (at `:125`) |
| M-ST-unlabelled | `_tap`: `hit.text ?? ''` | ST-unlabelled | `Expected: empty` / `Actual: ['', '']` |
| M-ST-band | `_bandKeys`: `if (byHandle[h]?.generated == false)` | ST-band-two-rows | `Actual: Set:[]` / `Which: does not contain SelectionKey:<SelectionKey( 1E)>` |
| M-ST-secondary | `secondaryClick`: `final label = hit.text;` | ST-secondary | `Expected: Set:[SelectionKey:SelectionKey( 1E)]` / `Actual: Set:[]` |
| M-ST-gate | `_buildService`: `moves: () => true` | ST-move-gate | `Expected: [0.0, -1.0, -1.0, 0.0, -1800.5, 3700.25]` / `Actual: [0.0, -1.0, -1.0, 0.0, -1200.5, 3400.25]` |
| M-14l (plan's edit) | `_longPress`: delete `if (hit.locked) return;` | ST7 | **survives**: `00:00 +1: All tests passed!` — equivalent mutant, see Deviations 4 |
| M-14l (spec's: a locked table moves) | `onPointerMove`: `} else if (false) {` for `} else if (hit.locked) {` | ST7 | `Expected: [1.0, 0.0, 0.0, 1.0, -900.0, -3200.0]` / `Actual: [1.0, 0.0, 0.0, 1.0, -300.0, -3800.0]` (at `service_tool_test.dart:293`) |
| M-14l-press (both lock guards of the long press) | `onPointerDown`: `(true \|\| …contextMenu)` and `_longPress`'s guard deleted | ST7 | `Expected: Set:[SelectionKey:SelectionKey( 16)]` / `Actual: Set:[SelectionKey:SelectionKey( 16), SelectionKey:SelectionKey( 1D)]` (at `:288`, 'no toggle') |
| M-RB-lone-locked | `_bandKeys`: `} else {` | RB10 | `Expected: true` / `Actual: <false>` (at `service_band_test.dart:682`, `expect(r.selection.isEmpty, isTrue, reason: 'locked: nothing')`) |
| M-H29 | `onPointerMove`: `if (e.buttons == 0) _hover(e);` | SE12 | `Expected: empty` / `Actual: ['1']` |
| M-RB19 (`--enable-vmservice`) | `paintOverlay`: `SelectionBandPainter().paint(` | RB16 (and RB16-hall) | RB16: `Expected: a value less than or equal to <2>` / `Actual: <1440>`; RB16-hall: `Actual: <1009>` |
| M-PA-hall (`--enable-vmservice`, after d50976ed) | `pick`'s first loop: `final m = c.unit.toWorld.invert();` | PA4, PA5 | PA4: `Actual: <31.446>` / `Transform2: 35183 over 1000 picks of 500 seats, 3737 with none`; PA5: `Actual: <120.272>` / `Transform2: 124009 over 1000 picks of 500 seats, 3737 with none` |
| M-SC20b | `ci.yml`: the plan library's `test_flags` line deleted | SC20b | `Actual: '- package: packages/jet_cad_2d_plan\n'` / `Which: does not contain '\n'` (`[E]` on SC20b) |
| M-H29(service moves) (DC7) | the diff fed by the active plan: `_unitsNow`'s `final cache = _activeUnits;`, `_reportUnits`'s `before.isAt(_activeUnits.current)`, `_onServiceChanged` calls `_reportUnits()` | DC7 | `Expected: empty` / `Actual: [` `PlanUnitChanged:PlanUnitChanged(PlanUnitDetail(PlanUnit(1, table, 4, fx.embedding.four,` (at `unit_changes_test.dart:379`, `expect(seen, isEmpty)`) |

## Deviations from the brief (each reported)

1. **Session order.** The brief put `picker = UnitPicker(document, units)`
   where `_IdleTool()` was, but `units` is a `late final` assigned last
   (it listens to `locked`); reading it there throws
   `LateInitializationError`. The picker, the tool and the tool controller
   are built right after `units` (none of the three constructors can
   throw), with the comment adjusted.
2. **Unused/unnecessary imports.** `band_allocation_test.dart`'s
   `plan_controller.dart` import is unused (`unused_import`, dropped);
   `service_tool_units_test.dart`'s `package:flutter/painting.dart show
   Offset` is `unnecessary_import` (flutter_test provides it; dropped).
3. **ST-locked-seat could not go red under M-ST-locked as written.** A2 is
   in group `g` {A2, A3}, both locked: with the lock check removed, the tap
   replaces the selection with the group's selectable members, which
   exclude locked ones, so `r.keys` stays empty. Added (23206e81) a tap on
   A5 (locked, no group): `expect(r.taps, ['A2', 'A5'])` and
   `expect(r.keys, isEmpty, …)`; the mutation then reds there.
4. **M-14l as the plan words it is an equivalent mutant**, in the oracle
   too: `onPointerDown` starts the long-press timer for a locked hit only
   under `contextMenu`, and `_longPress`'s contextMenu branch never reaches
   `if (hit.locked) return;`. I ran the spec's M-14l ("a locked-layer table
   moves", selection-mode spec :214: the drag branch) and the two
   long-press guards together; ST7 reds on both (quoted above). The plan's
   M-14l line should be re-worded in the ledger.
5. **M-PA-hall survived PA4/PA5 as written.** The watch was `{'_Double',
   'Vector2'}`; a per-seat `invert()` makes a `Transform2`, whose doubles
   are unboxed, so neither class moves. Watching `Transform2` alone was not
   enough either: the hall's live transforms read about 3,700 in every
   epoch, picks or none (probe: `picks 0` / `picks 1000` / `picks 5000` all
   `{Transform2: 3556, _Double: 91, Vector2: 110}`; the meter's failure
   mode 1). d50976ed watches `{..._watched, 'Transform2'}` for the hall
   and holds the picks to their excess over a no-pick epoch, as RB16 does.
   The ported PA1-PA3 keep the oracle's watch (assertions unchanged), so
   they do not see a `Transform2` per table; that is the oracle's gap.
6. **M-ST-mixed and M-ST-group red by the copy's guard**, not by a move:
   the drag executes a `TransformNodeCommand` on a seat and the copy's
   parametric guard throws `GeneratedGeometryError` out of `r.drag`. Red,
   with a different red line than the brief predicted.
7. **DC7's drag.** Today's DC7 drags through the selection view's
   `InteractionLayer` with a `TestGesture`; in 2b the service view is Task
   16's, so the port drives `c.serviceSession!.tool` with explicit
   `ToolPointerEvent`s at today's screen points (`p`, `p + (40, 0)`,
   `p + (80, 25)`) under `embeddingCamera()`. Assertions unchanged; renames
   only: `FloorPlanMode.selection/design` → `PlanMode.service/design`,
   `cameraController` → `camera`, `tableDetails` → `unitDetails`,
   `before.table.number` → `before.unit.label`, `serviceLayoutJson()` →
   `serviceJson()`, `resetLayout()` → `resetService()`,
   `restoreServiceLayout` → `restoreService`, `setTableData` →
   `setUnitData`, `FloorPlanTableChanged` → `PlanUnitChanged`. Its premise
   holds under the 2b spec (a service move is no design change). The test
   title keeps today's words.
8. Smaller: `ellTable` is `final` (its `tableUnit(3)` is not const); the
   events rig builds the design controller, copies it with
   `copyForService` and disposes it at once; SE15 keeps one `unitsOf(doc)`
   cache for the picker and the survey.

## Extra work 2: `_refreshSelectedGroup` per event

The service band replaces the selection once, at its up (`_band`); a drag
replaces it once, at its start (`_startDrag`); a pan and a hover never
touch it. So the controller's O(units) `_refreshSelectedGroup` runs per
gesture, never per pointer move. RB16-hall pins it with a premise: a
listener on the session's selection counts notifications over the band's
5,000 frames (4,000 warm, 1,000 measured) and expects 0 (`premise: no
selection change, so no controller refresh, per frame`); green with the
VM service. No budget was loosened.

## Self-review

- Names match the shared interfaces (`ServiceTool`, `ServiceHost`,
  `PlanLongPress`, `PlanFloorDrag`, the three records, `contextSelect`,
  `groupKeysOf`, `secondaryClick`, `ServiceSession.picker/host/tool`).
- Non-ASCII/escape check: `grep -nP '[^\x00-\x7F]|\\u|\\x'` over every new
  file → no hit, and the oracles have none.
- Fixtures off the origin, turned and mirrored; the hall 40 m off the
  origin with turned and curved rows.
- The tool's `name` is now `'Units'` (was `'plan.service'` on the idle
  placeholder); no test read it.

## Concerns

- Deviations 3, 4 and 5: the brief's own tests or mutation lines needed
  changes to make a named mutation go red (two test additions committed,
  one mutation re-worded). The ledger should record the M-14l wording and
  that ported PA1-PA3 do not watch `Transform2`.
