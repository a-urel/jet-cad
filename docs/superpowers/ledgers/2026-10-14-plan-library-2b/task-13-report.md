# Task 13 report: the service record

Status: DONE_WITH_CONCERNS (the concerns are minor; listed at the end)

Commits (base 352b3936):
- `0e6ab3cf feat(plan): the service record, jet_cad.service v1 (2b S3)`
- `844431ba test(plan): pin serviceEdited after a load in service; name M-NS5, M-DC15 (2b Task 13)`

## What was implemented

- `lib/src/service/service_record.dart` (new), copied verbatim from the brief's Step 5: `kServiceFormat`, `kServiceVersion`, `ServiceMove`, `RecordGroup`, `ServiceRecord`, `sameTransform`, `serviceMovesOf`, `encodeServiceRecord`, `decodeServiceRecord`, `matchServiceMoves`, `matchServiceGroups`, `ServiceRestore`.
- `lib/src/controller/plan_controller.dart`:
  - the brief's Step 6 section (`_serviceChanges`, `_announced`, `_groupsAtEnter`, `serviceEdited`, `serviceChanges`, `serviceJson`, `restoreService`, `resetService`, `_announceService`), placed after `redo`;
  - `_attachService` sets `_announced`, and `_onServiceChanged` calls `_announceService()`;
  - `undo` and `redo` call `_announceService()` after their try/on blocks;
  - `setMode` into service and `_replace`'s service branch set `_groupsAtEnter = _groups.value`;
  - `setUnitGroups` fires `serviceChanges` in service, and its doc says so;
  - `dispose` disposes `_serviceChanges`;
  - the `revision` doc now names the reset and the restore. It used to say "Task 13 adds…".
- `lib/jet_cad_2d_plan.dart` exports `ServiceRestore`, and `test/barrel_test.dart` ED-9 gains `// 2b Task 13` and `'ServiceRestore'`.

The committed code matched the brief's assumed names: `_buildService`, `_attachService`, `_dropService`, `_onServiceChanged`, `_select`, `_refreshSelected`, `_refreshFlags`, `_groups`, `_selectedUnits`, `_revision`, `ServiceSession.units.current` and `_session.units.current`.

## Tests

- **`test/service/service_record_test.dart`** (new, from brief Step 1): LC1, LC2, LC3, LC4, LC6, LC5's six cases and SR-codec-shapes, 12 tests. I compared it against the oracle `jet_cad_floor_plan/test/host/service_layout_test.dart`. Every assertion is unchanged except ruling R13-a's format and keys.
- **`test/controller/service_record_controller_test.dart`** (new), 21 tests:
  - Ported: SR-C2, SR-C10, SR-C14, SR-C16, SR-C17, SR-C18, SR-C20, SR-C19, SR-CF3, SR-CF4. They follow rulings R13-a and R13-b; every other assertion is as in the oracle `controller_test.dart`.
  - The brief's nine new tests: SR-roundtrip, SR-design-edited, SR-groups-replaced, SR-invalid-groups, SR-locked-move-dropped, SR-old-format-refused, SR-edited-after-enter, SR-reset and SR-changes-timing.
  - Dispatch item 2: **SR-state-kept**.
  - A gap found while running mutations: **SR-edited-after-load**.
- **`test/controller/unit_groups_controller_test.dart`**: **TG-C10** (ruling R13-c: the last line is `isTrue`) and **TG-C11** (ruling R13-d: the `resetLayout` step and its three expectations are not ported). Your dispatch said to grow this file with them, so they are here rather than in `service_record_controller_test.dart` as the brief listed.
- **Carried 2a deferrals:**
  - NS1's `serviceChanges` assertions (`layoutFired == 0` before and after the pump, as at oracle :191-201) went into `test/controller/locale_separator_test.dart`. Its header is updated.
  - NS5 is added there too, with a `separatorIn` helper that reads `save()` back through a new controller (today's helper decoded the JSON directly).
  - DC15 went into `test/controller/unit_changes_test.dart`. The "DC15 → Task 13" marker is removed and the header says it was ported. Assertions are unchanged; only names changed (`setTableData` → `setUnitData`, `FloorPlanMode.selection` → `PlanMode.service`, `FloorPlanTableChanged` → `PlanUnitChanged`).
  - None of the premises is impossible under 2b.
- **Dispatch item 2:**
  - Already covered: **SR-CF3** (focus kept across setMode, resetService, restoreService, load and newPlan) and **TG-C11** (groups and group statuses kept across a mode round trip and a load; selection cleared by a load).
  - Added **SR-state-kept**:
    - unit statuses, group statuses and the focus stay the identical instances across setMode, resetService, restoreService, load and newPlan;
    - the groups stay identical across setMode, load and newPlan;
    - resetService clears the groups and restoreService replaces them with the record's equal map;
    - the selection is kept by label across reset and restore, and cleared by load and newPlan.
  - It carries three named mutations (M-SR21, M-SR22, M-SR23).

### RED

Command: `flutter test test/service/service_record_test.dart test/controller/service_record_controller_test.dart` (before the lib file existed)

```
test/service/service_record_test.dart:11:8: Error: Error when reading 'lib/src/service/service_record.dart': No such file or directory
test/service/service_record_test.dart:99:6: Error: Type 'ServiceMove' not found.
test/service/service_record_test.dart:100:5: Error: Method not found: 'serviceMovesOf'.
```

Command: `flutter test test/controller/service_record_controller_test.dart`

```
test/controller/service_record_controller_test.dart:20:8: Error: Error when reading 'lib/src/service/service_record.dart': No such file or directory
test/controller/service_record_controller_test.dart:559:10: Error: 'ServiceRestore' isn't a type.
test/controller/service_record_controller_test.dart:88:14: Error: The getter 'serviceEdited' isn't defined for the type 'PlanController'.
```

These are the compilation errors the brief's Step 4 expected.

### GREEN

Command: `flutter test test/service/service_record_test.dart test/controller/service_record_controller_test.dart test/barrel_test.dart test/controller/unit_groups_controller_test.dart test/controller/unit_changes_test.dart test/controller/locale_separator_test.dart`

```
00:03 +80: All tests passed!
```

That was before SR-edited-after-load. With it, the three touched controller files gave `00:02 +47: All tests passed!`.

## Gates (packages/jet_cad_2d_plan)

After commit 0e6ab3cf:

```
00:47 +1070: All tests passed!
No issues found! (ran in 3.8s)
Formatted 238 files (0 changed) in 0.51 seconds.
format exit 0
```

After commit 844431ba:

```
00:52 +1071: All tests passed!
No issues found! (ran in 4.0s)
Formatted 238 files (0 changed) in 0.54 seconds.
format exit 0
```

There were no failures at all, so nothing needed comparing against `tool/ci/standing_failures.txt`. No other package was touched. `git status --short` was clean after both commits and after every mutation was reverted.

## Mutations

All ran on committed files. Each was reverted with `git checkout -- <file>`, and `git diff --quiet -- <file>` printed `diff exit 0` every time. The failing lines are quoted from `flutter test … --plain-name '<test>'`.

| Id | Edit | Red test | Quoted failure |
|---|---|---|---|
| M-SR1 | `service_record.dart`: delete `'label': g.label,` | SR-roundtrip | `Actual: [{'id': 'g2', 'members': ['3', '2']}, {'id': 'g1', 'members': ['1']}]` … `line 456` |
| M-SR3 | `restoreService`: `_groups.value = Map.unmodifiable({..._groups.value, ...groups.applied});` | SR-groups-replaced | `Expected: ['g1']` / `Actual: _CompactKeysIterable<String>:['gX', 'g1']` … `line 546` |
| M-SR4 | `restoreService`: `validateUnitGroups({...})` inserted | SR-invalid-groups | `Which: threw ArgumentError:<Invalid argument (groups): A group id is blank: "">` … `line 565` |
| M-SR5 | `matchServiceGroups`: members filtered by `withLabel(m.trim())`, the `every(withLabel)` clause deleted | SR-invalid-groups | `Expected: ['g1', 'g4']` / `Actual: ['g1', 'g5']` … `line 577` |
| M-SR7 | delete `unit.text == e.label &&` | SR-design-edited | `Expected: ['1']` / `Actual: ['1', '2']` … `line 515` |
| M-SR8 | delete `group.members.every((m) => designUnits.withLabel(m).isNotEmpty) &&` | SR-design-edited | `Expected: ['g2']` / `Actual: ['g1', 'g2']` … `line 518` |
| M-SR9 | delete `commands.clearHistory();` in `restoreService` | SR-design-edited, SR-C16 | `Expected: false` / `Actual: <true>` … `line 529`; and SR-C16 `line 196` |
| M-SR10 | delete `!unit.locked &&` | SR-locked-move-dropped | `Expected: ['1']` / `Actual: ['1', '5']` … `line 602` |
| M-SR11 | delete `!unit.generated &&` | SR-locked-move-dropped | `The following GeneratedGeometryError was thrown running a test:` / `1E is generated by a parametric object and cannot be edited directly`, from `service_record_controller_test.dart:618:12` (the restore call) |
| M-SR12 | delete the format check | SR-old-format-refused | `Which: returned ServiceRestore:<ServiceRestore(moves: [], dropped []; groups: [], dropped [])>` … `line 660` |
| M-SR13 | delete `setMode`'s `_groupsAtEnter = _groups.value;` | SR-edited-after-enter | `Expected: false` / `Actual: <true>` … `line 679` |
| M-SR15 | `resetService` in design clears the groups | SR-reset | `Expected: ['g']` / `Actual: _CompactIterableImmutable<String>:[]` … `line 712` |
| M-SR16 | delete `resetService`'s `_groups.value = const <String, UnitGroup>{};` | SR-reset | `Expected: empty` / `Actual: {'g': UnitGroup:UnitGroup({1, 3}, null)}` … `line 725` |
| M-SR17 | `setUnitGroups`: unconditional `_serviceChanges.bump();` | SR-changes-timing | `Expected: (int, int):<(0, 1)>` / `Actual: (int, int):<(1, 1)>` … `line 746` |
| M-SR18 | delete that line | SR-changes-timing | `Expected: (int, int):<(1, 2)>` / `Actual: (int, int):<(0, 2)>` … `line 753` |
| M-SR19 | `json['groups'] ?? const <Object?>[]` | SR-codec-shapes | `Expected: throws <Instance of 'FormatException'>` / `Which: returned <Instance of 'ServiceRecord'>` / `{"format":"jet_cad.service","version":1,"moves":[]}` |
| M-SR20 | delete `undo`'s `_announceService();` | SR-C20 | `Expected: an object with length of <2>` / `Which: has length of <1>` … `line 270` |
| M-SR25 (extra) | delete `resetService`'s `_groupsAtEnter = const <String, UnitGroup>{};` | SR-reset | `Expected: false` / `Actual: <true>` … `line 729` |
| M-SR21 (item 2) | `resetService` adds `_statuses.value = const <String, UnitStatus>{};` | SR-state-kept | `Expected: same instance as {` / `Actual: {}` / `resetService` … `line 394` |
| M-SR22 (item 2) | `restoreService` adds `_focus.replace(null);` | SR-state-kept | `Expected: same instance as Set:['1', '3']` / `Actual: <null>` / `restoreService` … `line 396` |
| M-SR23 (item 2) | `_replace` adds `_groups.value = const <String, UnitGroup>{};` | SR-state-kept | `Expected: same instance as {'g': UnitGroup:UnitGroup({1, 2}, Smith)}` / `Actual: {}` / `load` … `line 398` |
| M-SR24 (new test) | delete `_replace`'s `_groupsAtEnter = _groups.value;` | SR-edited-after-load | `Expected: false` / `Actual: <true>` / `a load: a fresh copy` … `line 716` |
| M-NS5 | `reportLocale` bumps `_serviceChanges` after the settle | NS1 and NS5 | `Expected: <0>` / `Actual: <1>` … `locale_separator_test.dart line 62` (NS1) and `line 231` (NS5) |
| M-DC15 | `_unitsNow`: `final cache = _activeUnits;` instead of `_session.units` | DC15 | `Which: at location [0] is PlanUnitChanged:<PlanUnitChanged(PlanUnitDetail(PlanUnit(1, table, 4,` … `unit_changes_test.dart line 585` |

About M-SR24: deleting `_replace`'s `_groupsAtEnter` line at first turned nothing red (`flutter test test/controller/` printed `00:05 +193: All tests passed!`). I added SR-edited-after-load in 844431ba to pin it.

The M-DC15 failing expect is the final `expect(seen, [PlanUnitChanged(b2, …)])`. Commit 844431ba moved the `// M-DC15` comment onto that line, and named M-NS5 at NS1's assertion as well.

## Self-review

- **Names and signatures** match the shared interfaces and the brief. `ServiceRestore` is the only new export.
- **Fixtures:** every placement is turned or mirrored and off the origin, and every move is off-grid. SR-state-kept's statuses use two colours with captions.
- **Two non-assertion edits to the brief's text**, needed to make `flutter analyze` clean:
  - SR-C16 reads `(jsonDecode(c.serviceJson()!) as Map)['moves']` (`avoid_dynamic_calls`).
  - SR-old-format-refused's disguised text uses `'moves': <Object?>[]` and `'groups': <Object?>[]` (`inference_failure_on_collection_literal`).
  - The values compared are the same.
- **`dart:ui show Color`** is imported in the controller test because SR-state-kept uses it.
- **CHANGELOG:** not touched. No earlier 2b task touched `packages/jet_cad_2d_plan/CHANGELOG.md`, and the brief does not list it.

## Concerns

1. **The spec contradicts itself** (for the ledger). Spec S3 line 806 says "Statuses, groups, group statuses and focus are kept across mode switches, `resetService`, `restoreService`, `load` and `newPlan` (today)". The same section, lines 772 and 791, and the S5 rows 980 and 984 say that `restoreService` replaces the groups and `resetService` clears them. The code and tests follow decision 4 (reset clears, restore replaces), and SR-state-kept pins "kept" for statuses, group statuses and focus only. Line 806 should say "statuses, group statuses and focus", with groups kept across mode switches, load and newPlan.
2. **TG-C10 and TG-C11** live in `unit_groups_controller_test.dart`, as your dispatch said, not in `service_record_controller_test.dart`, as the brief's file list said.
3. **Shared scratchpad.** It holds other sessions' files. Mine are `sr_*.dart`, `helpers.dart` and `newtests.dart`; none is in the repo.
