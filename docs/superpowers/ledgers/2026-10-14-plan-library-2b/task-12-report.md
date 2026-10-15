# Task 12 report: service state (statuses, groups, focus, the group rules)

Status: DONE_WITH_CONCERNS (the concerns are only about where two mutation-marker comments sit in planner-written tests; no code concerns).

Commit: `352b3936 feat(plan): unit statuses, groups and focus by label (2b S3)` (on top of c0011082).

## What was implemented

- `lib/src/service/service_state.dart` (new): copied verbatim from the brief's Step 7 block (extracted from the brief with sed, so the bytes match; it has no escapes or non-ASCII). It holds `UnitStatus`, `UnitGroup`, `validateUnitGroups`, `groupIdsByLabel`, `GroupUnit`, `groupUnitsOf`, `UnitGroupLookup` (with `byLabel`, `groupOf`, `visibleMembers`, `selectableMembers`, `hasLockedVisibleMember`, `hasGeneratedVisibleMember`, `splitGroup`), `mergeQualifies`, `unitLabelOrder`, `inLeadOrder` and `statusOfUnit`.
- `lib/src/controller/plan_controller.dart`:
  - imports `../service/service_state.dart`;
  - adds `_Focus` after `_Requests`;
  - adds the brief's "Service state" section (verbatim) right after `_refreshSelected`. That section covers `unitStatuses`/`setUnitStatus`, `unitGroups`/`setUnitGroups`, `groupStatuses`/`setGroupStatus`, `unitFocus`/`setUnitFocus`, `selectedGroup`, `mergeCandidate`, `selectableMembers`, `@internal groupLookup`, `@internal statusOf`, the cached `_groupLookup`, `_expandLabels` (which replaces Task 9's one-line seam stub, deleted) and `_refreshSelectedGroup`;
  - `_refreshSelected` now ends with `_refreshSelectedGroup();`;
  - `dispose` disposes the six new notifiers after `_mode.dispose()`.
- `lib/jet_cad_2d_plan.dart`: `export 'src/service/service_state.dart' show UnitGroup, UnitStatus;`. In `test/barrel_test.dart`, ED-9 gains `// 2b Task 12` with `'UnitGroup', 'UnitStatus',`.
- `test/support/service_plans.dart`:
  - `servicePlanText(unlabelled:)` adds a fourth table, unlabelled, at `placementTransform(at: Vector2(-4000, -3000), basePoint: table.base)`, after the planter;
  - added `kGroupLabels`, `groupsPlanText`, `keysOf`, `unlabelledKey`, `setRowCount` and `bill`, as the brief gives them;
  - imports gain `dart:ui show Color` and `jet_cad_2d_flutter show SelectionKey`;
  - the `unit_fixtures.dart` import is now `show addLayer, kDeg37`, because `groupsPlanText` calls `addLayer`, which was only re-exported before.
- `test/service/service_state_test.dart`: TG-U1…TG-U15 (15 tests), ported by copying the oracle file and renaming, so the family emoji's literal U+200D bytes (`342 200 215`) are kept exactly. Checked with `od -c`: the same bytes as the oracle.
- `test/controller/unit_groups_controller_test.dart`: ported TG-C1…C9 and C12…C16 (14 tests), plus the new SS-mixed-group, SS-shrink-group, SS-locked-not-selected and SS-relabel.
- `test/controller/service_state_controller_test.dart`: SS-C15, SS-CF1, SS-CF2 and SS-CF5 (ported), plus the new SS-dup-label-status.

Assertion counts against the oracle (`expect(` occurrences):
- table_groups_test: 64 in both;
- table_groups_controller_test, without TG-C10/C11: 70 in both.

## Deviations from the brief, and why

1. `unit_groups_controller_test.dart` does not import `dart:ui show Color`. Its only use, `bill`, now lives in the support file, and `flutter analyze` reported `error • Unused import: 'dart:ui'`.
2. `service_state_test.dart` imports only `src/service/service_state.dart`, not the barrel. `flutter analyze` reported `info • The import of 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart' is unnecessary because all of the used elements are also provided by the import of 'package:jet_cad_2d_plan/src/service/service_state.dart'`.
3. The brief asked for a sentence in `_select`'s doc, but `_select` has no doc comment. The sentence "In service a label in a group stands for the group's selectable members (the same filter)." went into the public `select`'s doc instead.
4. Wording in `service_state_test.dart`: test names and comments read "label"/"unit" where the oracle reads "number"/"table", as the brief says. TG-U10's two `reason:` strings got the same rewording (reason text only; the matchers are unchanged). The local helpers `split(numbers, {unnumbered})` and `sorted(numbers)` were renamed to `labels`/`unlabelled`. In the TG-C tests only the lead comment was reworded, per the brief; their test names keep today's text.
5. Ruling R-25 (SS-relabel): I ran it as written against the built code, and it passes, so the test was not changed. M-SS2 turns it red: `Expected: Set:['A1']  Actual: Set:['12', 'A1']`.

Name check against earlier tasks: no mismatches. `_service`, `_activeUnits`, `_selectedUnits`, `_select`, `_refreshSelected`, `unitIndex`, `setUnitLabel`, `labelOf`, `unitNode(s)`, `hall()`, `seatsOf`, `RowComponent.copyWith(count:)` and `c.camera` are all as the brief assumed.

## TDD evidence

RED (Step 6): `flutter test test/service/service_state_test.dart test/controller/unit_groups_controller_test.dart test/controller/service_state_controller_test.dart` printed:
```
test/service/service_state_test.dart:11:8: Error: Error when reading 'lib/src/service/service_state.dart': No such file or directory
test/service/service_state_test.dart:13:1: Error: Type 'UnitGroup' not found.
```
and `flutter test test/controller/unit_groups_controller_test.dart` printed:
```
test/controller/unit_groups_controller_test.dart:28:13: Error: Method not found: 'UnitGroup'.
test/controller/unit_groups_controller_test.dart:27:7: Error: The method 'setUnitGroups' isn't defined for the type 'PlanController'.
```
These are the compile errors the brief expected.

GREEN (Step 10): the three files plus `test/barrel_test.dart` printed `00:01 +40: All tests passed!`.

## Gates (packages/jet_cad_2d_plan)

- `dart format .` → `Formatted 235 files (0 changed)` on the final pass.
- `flutter analyze` → `No issues found! (ran in 3.8s)`.
- `flutter test` → `00:45 +1034: All tests passed!`. No standing failures appear in this package.
- `dart format --output=none --set-exit-if-changed .` → `Formatted 235 files (0 changed) in 0.53 seconds.`, `format exit 0`.
- `git status --short` before the commit showed only this task's 8 files. It was empty after the commit and after every mutation revert.

No pubspec, `tool/ci` or kit change, so neither the CI tests nor the kit-deps check was needed.

## Mutations

All were run after the commit, on committed files. Each was applied with an exact-match single replacement, then reverted with `git checkout -- <file>`; every `git diff --quiet -- <file>` printed `diff exit 0`.

- **M-SS1** (plan_controller `setUnitStatus`, `e.key.trim()` → `e.key`)
  - SS-C15 red: `Expected: ['1']` / `Actual: _CompactKeysIterable<String>:[' 1 ']` / `Which: at location [0] is ' 1 ' instead of '1'`.
- **M-SS2** (`_groupLookup`, `!identical(_lookupUnits, units) ||` deleted)
  - TG-C12 red: `Expected: 'G9'  Actual: <null>`.
  - TG-C16 red: `Expected: empty  Actual: Set:['12', '20', '5']`.
  - SS-shrink-group red: `Expected: Set:['12', 'A2']  Actual: Set:['12', 'A2', 'A11', 'A12']`.
  - SS-relabel red: `Expected: Set:['A1']  Actual: Set:['12', 'A1']`.
- **M-SS3** (`statusOfUnit`, `if (label == null) return null;` → `label ??= '';`)
  - SS-dup-label-status red: `Expected: null` / `Actual: UnitStatus:<UnitStatus(Color(alpha: 0.5020, red: 0.1176, green: 0.5333, blue: 0.8980,`.
- **M-SS4** (`statusOfUnit`, the `if (id != null) {…}` block deleted)
  - SS-dup-label-status red: `Expected: UnitStatus:<UnitStatus(Color(alpha: 0.5020, red: 0.1176, …` / `Actual: UnitStatus:<UnitStatus(Color(alpha: 1.0000, red: 0.8980, green: 0.2235, blue: 0.2078,` (red over blue).
- **M-SS5** (`groupUnitsOf`, `locked: u.locked,` → `locked: false,`)
  - SS-locked-not-selected red: `Expected: Set:['1']  Actual: Set:['1', '5']` (`selectableMembers` holds 5).
  - TG-C7 red: `Expected: 'G7'  Actual: <null>`.
  - Also red: TG-C8, TG-C13, TG-C14 (`Expected: Set:['12', '3']  Actual: Set:['12', '3', '8']`) and TG-C16.
- **M-SS6** (`_select`, `if (!u.visible || u.locked) continue;` → `if (!u.visible) continue;`)
  - SS-locked-not-selected red: `Expected: Set:[SelectionKey:SelectionKey( 16)]  Actual: Set:[SelectionKey:SelectionKey( 16), SelectionKey:SelectionKey( 1A)]`. 5 is selected.
  - TG-C7 red: `Expected: Set:['3', '7', '12']  Actual: Set:['12', '3', '7', '8']`.
- **M-SS7** (`groupUnitsOf` body guarded by `if (!u.generated)`)
  - SS-mixed-group red: `Expected: 'party'  Actual: <null>`.
  - SS-shrink-group red: `Expected: Set:['12', 'A2', 'A11', 'A12']  Actual: Set:['12']`.
  - SS-relabel red: `Expected: Set:['12', 'A1']  Actual: Set:['12']`.
- **M-SS8** (`hasGeneratedVisibleMember` → `=> false;`)
  - SS-mixed-group red: `Expected: true  Actual: <false>`.
- **M-TG1** (`validateUnitGroups`, the `if (other != null) { throw … }` block deleted)
  - TG-U5 red: `validateUnitGroups (G2) TG-U5 a label in two groups throws, … [E]`.
  - TG-C1 red: `Expected: throws <Instance of 'ArgumentError'> with `message`: a string containing '"5"', '"G4"',` / `Actual: <Closure: () => void>`.
- **M-TG2** (`_expandLabels` returns `labels` first thing, written as `if (labels.isNotEmpty || labels.isEmpty) return labels;` to avoid dead-code noise)
  - TG-C5 red: `Expected: Set:['3', '7', '12']  Actual: Set:['3']`.
  - Also red: TG-C1, C3, C6, C7, C12, SS-mixed-group, SS-shrink-group and SS-locked-not-selected.
- **M-TG3** (`_refreshSelectedGroup`, `service && _groups.value.isNotEmpty` → `_groups.value.isNotEmpty`)
  - TG-C9 red: `Expected: null  Actual: 'G2'`.
- **M-TG4** (`selectableMembers(groupId.trim())` → `(groupId)`)
  - TG-C14 red: `Expected: Set:['12', '3']  Actual: Set:[]`.
- **M-TG5** (`splitGroup`, `unlabelledSelected ||` removed)
  - TG-U13 red: `the Split rule (G5) TG-U13 … [E]`.
  - TG-C8 red: `Expected: null  Actual: 'G7'`.
- **M-TG6** (lookup factory, `if (l == null || !u.visible) continue;` → `if (l == null) continue;`)
  - TG-U8 red: `Expected: [31, 100, 136]  Actual: [31, 100, 136, 153]`.
  - TG-U9 red: `Expected: false  Actual: <true>`.
- **M-TG7** (`unitLabelOrder` returns `_plain` always)
  - TG-U14 red: `Expected: ['3', '7', '12']  Actual: ['12', '3', '7']`.
  - TG-U15 red: `Expected: [31, 100, 119, 81]  Actual: [81, 31, 100, 119]`.
- **M-TG8** (`mergeQualifies`, `if (l.isEmpty) continue;` deleted)
  - TG-U10 red: `Expected: false  Actual: <true>`.
- **M-SS9** (`_Focus.replace`, `if (setEquals(next, _value) && next != null) return;` added first)
  - SS-CF1 red: `Expected: <2>  Actual: <1>`.
- **M-SS10** (`setUnitFocus` body → `_focus.replace(labels);`)
  - SS-CF1 red: `Expected: Set:['7', '3']  Actual: Set:[' 7 ', '', '  ', '3']`.
  - SS-CF2 red: `Expected: Set:['7', '3']  Actual: Set:['3', 'A1']`.
- **M-SS11** (`_focus.dispose();` deleted)
  - SS-CF5 red: `Expected: throws <Instance of 'FlutterError'>  Actual: <Closure: () => void>`.

## Self-review findings and concerns

- **M-SS7's marker comment is in the wrong place.** In SS-mixed-group it sits above `expect(c.activeSelection.keys, {...})`, but under M-SS7 that expect passes. `_expandLabels` expands through `groups[id]!.members` and `_select` resolves labels through `UnitIndex.withLabel`, not through the lookup's `GroupUnit` list, so the seats are still selected. The test goes red two lines later, at `expect(c.selectedGroup.value, 'party')`: the Split rule sees only the table as selectable. The brief's prediction ("the seats are not selected") does not happen. The test is still red under the mutation; only the marker sits on the wrong line. I left the planner's test unchanged. Moving the comment down to the `selectedGroup` expect would be a one-line follow-up, if the controller wants it.
- **The same applies to M-SS6 in SS-locked-not-selected.** The test goes red at the first `activeSelection.keys` expect (under the `// M-SS5` comment), not at the later `// M-SS6` block, because the group expansion feeds 5 to `_select`. The brief's predicted reason, "5 selected", is what happens.
- **Not on the frame path.** `mergeQualifies` rebuilds `groupIdsByLabel` at each `_refreshSelected`, which runs at selection and document-change rate. That is the brief's code as given.
- TG-C10, TG-C11, CF3 and CF4 are not ported (Task 13, ruling R-13c/d). `serviceChanges` on `setUnitGroups` is left to Task 13.
