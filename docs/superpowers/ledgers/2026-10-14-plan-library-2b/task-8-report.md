# Task 8 report: permissions, the design's selection mapping, the unit picker

Status: DONE_WITH_CONCERNS (the concerns are below; none blocks).
Commit: `c612fa1b feat(plan): units-only permissions and the design's unit selection (2b S2, S4)` on `feat/plan-library-2b`, parent `1a2c645e`.

## What I implemented

- `lib/src/controller/permissions.dart`: rewritten whole from the brief (Step 6). It adds `selectUnitsOnly` (false), `serviceMove` and `serviceMerge` (true), the `unitsOnly` profile, `readOnly` with `relabel: false`, and `_flags` with full's value. `toString` prints the fields that differ from full. It also adds `isUnitSymbol`.
- `lib/jet_cad_2d_plan.dart`: the permissions export now shows `PlanPermissions, isUnitSymbol`.
- `lib/src/service/unit_picker.dart` (new, R-12): the brief's code, with `UnitTop`/`PolygonTop`/`CircleTop` and `_boxDistance` copied byte for byte from `table_picker.dart:17-86` and `:365-370` by script, `TableTop` renamed to `UnitTop`. It imports Task 6's `firstLeafOf`. The signature is exactly R-12's.
- `lib/src/tools/plan_select_gates.dart`: rewritten from Step 8: `generatingObjectOf`, `isPlacedUnitKey`, and `PlanSelectGates` with `restrictsPick` true, the mapped `pick`, the `bandAccepts` refusal, and the selectUnitsOnly branches. One deviation from the brief: the constructor uses `required super.selection, required super.locked` and reads `locked` in the initializer list for `_lockedObjects`. The brief's form passed them to `super(...)` explicitly, which raised the analyzer info `use_super_parameters`. Behaviour is the same.
- `lib/src/controller/session.dart`: the gates take `catalog`, `picker: () => unitPicker` and `units: () => units.current`, and there is a new `late final UnitPicker unitPicker` (`skipLocked: true, placedOnly: true`).
- `lib/src/controller/plan_controller.dart`: in the `permissions` setter, `stale` also fires when `selectUnitsOnly` changes, and a switch to units only prunes keys that are not placed units (`isPlacedUnitKey`; the import already had no `show`).
- Test support: `unit_fixtures.dart` gets the brief's append (`sideChairTable`, `openTable`, `unitPlan`, `placeUnit`, `placeAt`, `placeTurned`, `worldOf`, `addLayer`, `addUnitLabel`, `unitsOf`, `pickerOf`, `rowOfTables`, `Tally`, `CountingTransform`, `f64`), its imports and a header line. No Task 6 name is redeclared. `unit_editor_fixture.dart` is new and verbatim from the brief.
- Tests:
  - new: `test/tools/design_selection_test.dart` (DS-0 … DS-perm, plus DS-layer below);
  - ported: `test/service/unit_picker_test.dart` (TPK1 … TPK14, 15 tests) and `test/editor/units_only_select_test.dart` (11 cases);
  - grown: `permissions_test.dart`, `plan_select_gates_test.dart`, `barrel_test.dart`.

## Where the brief and the code (or the tests) disagreed

1. **PM-6 first loop.** The brief says it "stays `kFlagNames.take(9)` (move .. editPage)". Task 3 had already made it `take(10)` (move .. relabel, and relabel is an edit). I kept `take(10)`: the committed code wins, and relabel is an edit by the brief's own plan decision.
2. **PM-3** (a 2a test; the brief does not mention it). Its loop `copyFlag(P.full, name, false)` with `expect(changed == P.full, isFalse)` goes red for `selectUnitsOnly`, because full already has it false. Observed RED: `PM-3 == and hashCode over every field; the tools as a set [E] Expected: false Actual: <true>`.
   - I changed only the fixture value: `copyFlag(P.full, name, !flagsOf(P.full)[name]!)`, with a comment. The assertions are unchanged.
   - This grows the test with the type, as the brief's note on 2a's own tests allows, and is in the same spirit as the PM-6 change the brief does spell out. The reviewer should confirm it is acceptable without a ruling.
3. **PM-11.** The brief says to give it "a picker and a cache over its document, disposed after the assertions". A `UnitIndexCache` listens to the `locked` it is given, so sharing PM-11's `locked` would make `expect(locked.hasListeners, isFalse)` false.
   - I gave the cache its own `cacheLocked` notifier. `locked` stays the gates' alone, and the assertion still measures the gates' listeners.
   - The cache and `cacheLocked` are disposed after the assertions.
4. **design_selection_test DS-plain-group.** `CompoundCommand` requires `label:`, so I added `label: 'Place a table'`. The analyzer flagged `missing_required_argument`.
5. **unit_picker_test.** It needs `import 'dart:typed_data';` because TPK11 uses `Float64List`.
6. **units_only_select_test.** I use the fixture's `tableOf` and `centreOf` and do not redeclare them. The brief lists `tableOf` among the helpers to copy, but the fixture the brief provides already defines it. I renamed the two group names (`selectUnitsOnly (M-H42, S-15)`, `move (T5-a, S-9 h)`). The test names and assertions are unchanged. The wall adaptations follow the brief: `isLine` (a kind check) and `startOf` (from `coordsOf`).

## TDD evidence

I wrote the implementation before I ran the new tests, so I did not observe the Step-5 compile-error RED; I am not claiming one. The REDs I did observe are PM-3 above, before its fixture change, and every named mutation below.

GREEN, focused:
```
$ flutter test test/tools/design_selection_test.dart test/service/unit_picker_test.dart test/controller/permissions_test.dart test/tools/plan_select_gates_test.dart test/barrel_test.dart
00:01 +40: All tests passed!
$ flutter test test/editor/units_only_select_test.dart
00:03 +11: All tests passed!
$ flutter test test/tools/design_selection_test.dart      (after DS-layer was added)
00:00 +12: All tests passed!
```

## Gates (jet_cad_2d_plan; the only package touched)

```
$ dart format .          -> Formatted 207 files (0 changed)
$ flutter test           -> 00:42 +856: All tests passed!
$ flutter analyze        -> No issues found! (ran in 3.9s)
$ dart format --output=none --set-exit-if-changed .  -> Formatted 207 files (0 changed); exit 0
```
`git status --short` after the commit is clean, and no `analysis_options.yaml` changed.

## Mutations

All run on committed files. Each was applied by a one-shot script, its test file was run, and the file was reverted with `git checkout -- <file>`; `git diff --quiet -- <file>` exited 0 every time.

| Mutation | Edit | Red test(s) | Quoted red line |
|---|---|---|---|
| M-DS1 | `pick`: `return key;` | DS-click-seat, DS-locked-object | `DS-click-seat … [E]  Expected: SelectionKey:<SelectionKey( 1D)>  Actual: SelectionKey:<SelectionKey( 20)>` |
| M-DS2 | `final key = SelectionKey.root(_hit.entity);` | DS-click-seat, DS-locked-object, DS-plain-group (**not** DS-click-attrib, see concerns) | `DS-plain-group … [E] Expected: Set:[SelectionKey( 17)] Actual: Set:[SelectionKey( 14)]` |
| M-DS3 | `bandAccepts` → `return true;` | DS-crossing, DS-window | `DS-window … [E] Expected: empty Actual: Set:[` |
| M-DS4 | `\|\| locked.contains(current)` deleted | DS-locked-object | `Expected: Set:[SelectionKey( 1D)] Actual: Set:[SelectionKey( 1E)]` |
| M-DS5 | `return current;` | DS-plain-group | `Expected: Set:[SelectionKey( 17)] Actual: Set:[SelectionKey( 12)]` |
| M-DS6 | session `placedOnly: false` | DS-units-only | `Expected: empty Actual: Set:[SelectionKey:SelectionKey( 1E)]` |
| M-DS7 | selectUnitsOnly line of `bandAccepts` deleted | DS-units-only | `Expected: Set:[SelectionKey( 18)] Actual: Set:[ Which: larger than expected` |
| M-DS8 | prune block deleted | DS-prune | `Expected: Set:[SelectionKey( 18)] Actual: Set:[ Which: larger than expected` |
| M-DS9 | `final m = (document.tree[u.instance]! as InstanceNode).transform;` | DS-picker-seat | `Expected: <34> Actual: <null>` |
| M-DS10 | `relabel \|\|` deleted from `edits` | DS-perm | `Expected: true Actual: <false>` |
| M-DS11 | `symbol.entry.unit?.kind == 'table'` | DS-perm | `Expected: true Actual: <false>` |
| M-DS12 (new, carry) | `unit_index.dart`: `&& revision == _revision` deleted | DS-layer | `Expected: null Actual: UnitInfo:<UnitInfo(17, null, table)>` |
| M-DS13 (new, carry) | `unit_locks.dart`: the layer check → `false` | DS-layer | `Expected: null Actual: UnitInfo:<UnitInfo(17, null, table)>` |
| M-PM1b | `selectUnitsOnly: true,` deleted from unitsOnly | PM-1 (and PM-7) | `at location ['selectUnitsOnly'] is <false> instead of <true>` |
| M-PM2b | `serviceMerge ?? this.serviceMove` | EC3b | `at location ['serviceMerge'] is <true> instead of <false>` |
| M-PM7b | `if (!v)` | PM-7 | `Expected: 'PlanPermissions()' Actual: 'PlanPermissions(selectUnitsOnly: false)'` |
| M-TP-skip | `(skipLocked && c.locked) \|\|` deleted | "the tables on the hidden and the locked layers …", R-4 | `Expected: empty Actual: Set:[SelectionKey:SelectionKey( 21)]` |

## The carry from Task 6's review

Before this task, no test pinned `UnitIndexCache`'s `tables.mutationRevision` key or `isLockedUnit`'s locked-layer branch in a way that bypasses the state id. Every layer change in my brief's tests runs through a command (a new state id) or happens at fixture build.

I added one test, **DS-layer** in `design_selection_test.dart`:
- A table is placed on its own layer, and a units-only picker picks it.
- The layer record is then replaced in `doc.tables.layers` with `locked: true`, with no command run; the test asserts the state id did not move.
- The next pick is null.

It pins both: M-DS12 (`revision == _revision` removed) and M-DS13 (layer check → `false`) each turn it red (table above). The locked-layer branch is also covered at the editor level by the ported "hidden and locked layers" case and R-4, through the picker's `skipLocked`.

## Self-review

- Names and signatures match the shared interfaces and R-12 exactly:
  - `UnitPicker(document, units, {skipLocked, placedOnly, @visibleForTesting leavesByOwner, invert})`;
  - `pick(Vector2, {reach})` returns `UnitInfo?`;
  - `candidates` and static `candidatesOf(document, index, {boxes, leaves})`;
  - `unitTopOf(doc, definition, [leavesByOwner])`;
  - `UnitCandidate`, `PickCandidate`;
  - `generatingObjectOf` and `isPlacedUnitKey` are internal.
- `jet_cad_2d_flutter` and the old packages are unchanged.
- Fixtures are not degenerate:
  - the service fixture (turned, mirrored table off the origin; two rows off the origin, one turned, one curved);
  - the editor fixture (0.37 px/mm, flipped, panned camera; turned and mirrored tables);
  - picker tests 37 degrees off, mirrored, tens of metres from the origin.
- Non-ASCII check: the only non-ASCII characters in my files are `·` and `×` in comments and one test name, exactly as the brief writes them; there are no `\u`/`\x` escapes in the sources.

## Concerns

1. **M-DS2's named test.** DS-click-attrib does not go red under M-DS2. `resolveHit` already maps an ATTRIB owned by a seat to its topmost group, the row. With the mutation, the ATTRIB key's own walk in `generatingObjectOf` (entity → owner seat → row) gives the row as well. Likewise M-DS1 leaves DS-click-attrib green. So DS-click-attrib is in effect a positive control. M-DS2 is still killed by DS-click-seat, DS-locked-object and DS-plain-group.
2. **PM-3's fixture change** (finding 2 above) is a change to a 2a test that the brief did not name. It needs the reviewer's acceptance.
3. **PM-11's separate `cacheLocked` notifier** (finding 3) departs from the brief's literal wording, to keep PM-11's listener assertion meaningful.
