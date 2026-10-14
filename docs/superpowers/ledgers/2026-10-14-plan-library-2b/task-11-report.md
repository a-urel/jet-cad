# Task 11 report: the service session and the mode

Status: DONE_WITH_CONCERNS (three carried 2a tests not ported, see "Carried items").

Commit: `e7f8e05a feat(plan): the service mode's session and the mode switch (2b S3)` (on 7ebae14d).

## What was implemented

- `lib/src/service/service_session.dart` (new): `PlanMode`, `serviceCopyOf`, `ServiceSession`, the private `_IdleTool` (name `plan.service`, reacts to nothing), exactly as the brief's Step 5, with one change: the copy's `UnitIndexCache` is made **last** in the constructor (the brief made it before the systems). Same reason as `DocumentSession` gives (session.dart: "Last: it listens to [locked], so no later step can throw and leak the listener"). The `../controller/diagnostics_log.dart` import was dropped: `flutter analyze` called it unnecessary (`../kits/guard.dart` provides `DiagnosticsLog`), as Step 10 allows.
- `lib/src/controller/plan_controller.dart`:
  - The mode section from Step 6.1 (`_mode`, `_service`, `_droppedServices`, `mode`, `activeDocument`, `activeSelection`, `@internal serviceSession`, `setMode`, `_buildService`, `_attachService`, `_onServiceChanged`, `_dropService`, `_lockFromCopy`, `_damageCopy`), placed after `_drop`.
  - `execute` returns false in service. `deleteSelection` returns false in service. `_requireDesign` has its body. `undo` and `redo` act on the active document. `_unrestricted(CommandDispatcher, step)` now takes the dispatcher to lift: `undo`/`redo` pass the active one, `reportLocale` and `_runHostEdit` the design's.
  - `_refreshFlags` reads `dirty` from the design and the history from the active document. The page flows read `activeDocument`. `_replace` rebuilds the copy in service. `dispose` disposes the copies and `_mode`.
  - Step 7: the seams are re-pointed (`_activeUnits`, `_activeDocument`, `_activeSelection`, `_inDesign`). `selectedUnits` is public. The `revision` doc now names the mode switch. The design's selection listener became `_onDesignSelection` (it calls `_refreshSelected()` only `if (_inDesign)`) at its three sites (`_open`, `_replace`, `dispose`). Task 9's design-change handler already bumped `_revision` only `if (_inDesign)`.
  - Item 3 of the extra work: `lockBroken`'s doc comment. See "lockBroken" below.
- `lib/jet_cad_2d_plan.dart`: `export 'src/service/service_session.dart' show PlanMode;`. `test/barrel_test.dart`: ED-9 gains `// 2b Task 11` and `'PlanMode'`.
- `test/support/service_plans.dart` (new): the brief's Step 1, R-19. It re-exports `addLayer, kDeg37` from `unit_fixtures.dart`, and the placer is `placeDef(DraftDocument, UnitDef, Transform2, …)`. One difference: the file's own import of `unit_fixtures.dart` shows `kDeg37` only. `addLayer` is unused inside the file, so a `show addLayer` there would draw the analyzer's `unused_shown_name`. The `export … show addLayer, kDeg37` line is as briefed.
- `test/service/service_session_test.dart` (new): SM-members, SM-lifetime, SM-select, SM-undo, SM-execute-false, SM-export, SM-copy-lock, SM-copy-boundary, copied verbatim from the brief, with one fix (finding F-1 below).
- `test/controller/mode_test.dart` (new): MD-C3, MD-C4, MD-C5, MD-C8, MD-CD1, verbatim from the brief (I checked them against the oracle controller_test.dart C3/C4/C5/C8: assertions unchanged).
- Task 9's files:
  - `unit_colour_test.dart`: TC6 appended at Task 9's marker. TC7's service-copy block restored from `table_color_test.dart:369-375`. Marker and header updated.
  - `unit_data_test.dart`: HD4 appended at the marker. HD6's service-copy block restored from `table_data_test.dart:250-255`. Marker and header updated.
  - `unit_detail_test.dart`: TD8's `setMode` tail restored (`table_detail_test.dart:252-254`). TA3 appended (`:503-533`); its camera comment was adapted because the camera is not reframed here (Task 16's chrome).
  - `unit_changes_test.dart`: DC10 and DC16 ported. DC7 and DC15 were not; their markers now say why (see "Carried items").
- Every restored or ported block keeps today's assertions. The only changes are the renames: `FloorPlanMode.selection` → `PlanMode.service`, `setTable*` → `setUnit*`, `.color` → `.colour`, `designJson()` → `save()`, `tableDetails` → `unitDetails`, `tableAt` → `unitAt`, `cameraController` → `camera`, `FloorPlanTableChanged`/`PlanReplaced` → `PlanUnitChanged`/`PlanUnitsReplaced`. TC6's two expected messages name the renamed methods (`'setUnitColour needs the design mode (P-5)'`, `'setUnitData needs the design mode (P-5)'`), per R-13 as the brief says.

## Findings

- **F-1 (brief test premise, fixed in the new test):** SM-execute-false as briefed failed:
  ```
  Expected: ... dleSeed":30}
    Actual: ... dleSeed":31}
  table 1 is still in the design
  ```
  `addDrafted(c.document, …)` takes a handle from the design's handle seed while it *builds* the command, so `c.save()` differs from `before` by `handleSeed` alone, with nothing executed. The test is new (no oracle), so I moved the command's construction before `state` and `before` are read, with the comment `// Made first: making it takes a handle from the design's seed.` The assertions and their order are unchanged otherwise: `c.execute(line)` is false, the state id is unchanged, `dirty` is false, `deleteSelection` is false, `save()` equals `before`.
- **F-2 (name, no mismatch):** every name the brief assumed from Tasks 5-9 exists as written (`serviceFixture` fields, `UnitIndexCache(document, catalog:, locks:, locked:)`, `UnitLabelSystem`, `_selectedUnits`, `_editorSelected`, `_detailsOf`, `_atPicker`, `RecordingExporter.seen`, `Switches.failing`, `addObject`, `atSquare`, `nearSquare`).

## Carried items (controller ruling 2: carry-2a-deferrals.md, Task 11 section)

Ported: **DC10** and **DC16** (`test/controller/unit_changes_test.dart`), assertions unchanged.

Not ported. These premises are not impossible under the 2b spec, but they read Task 13's members, which do not exist yet. A12 forbids dropping the lines, so I left these tests for the controller to reassign:
- **DC7** (`design_changes_test.dart:315-366`). It asserts `c.serviceEdited` (premises), calls `c.serviceLayoutJson()`, `c.resetLayout()` and `c.restoreServiceLayout(layout)` (Task 13: `serviceEdited`, `serviceJson`, `resetService`, `restoreService`), and drags table 1 through the mounted view's `InteractionLayer` (the service tool and view: Tasks 14 and 16). Suggested home: Task 14 or 16, after Task 13.
- **DC15** (`:607-637`). The only missing piece is the premise `expect(c.serviceEdited, isTrue, reason: 'premise: a service move');` (Task 13's `serviceEdited`). The rest is portable now (the move is a `TransformNodeCommand` on the copy). Suggested home: Task 13.
- **NS5** (`new_plan_separator_test.dart:347-374`). It reads `c.serviceLayoutChanges` (Task 13's `serviceChanges`) and `c.serviceEdited`, and shows the controller under a locale through the view (`show(tester, c, Locale('tr'))`). Suggested home: Task 13, beside NS1's `serviceLayoutChanges` assertion, which the carry file already gives to Task 13. Note for that port: `reportLocale` settles the **design's** separator in service through `_unrestricted(d.commands, …)` on the design's dispatcher, as this task wired it. The copy keeps its page, as NS5 expects.

Restored as ruling 1 asked (Task 9's "Task 11" cuts): TD8's `setMode` tail, HD6's and TC7's service-copy blocks. All the "Task 11" placeholder comments in those three files are gone. `grep -rn "Task 11"` over them now finds only the two header lines that credit the ported parts to Task 11 (`unit_data_test.dart:4`, `unit_colour_test.dart:5`).

## lockBroken (ruling 3)

The spec is silent:
- S3 defines `unitChanges` as reporting "after every design edit, undo or redo … `load` and `newPlan` report what is still owed, then `PlanUnitsReplaced`" (`unitChanges`' S3 bullet and today's `designChanges`).
- `revision` is today's `revision` (S5 row `| revision | revision |`). Today's doc reads "Moves whenever the active plan changes: an edit, an undo or a redo of it, a mode switch, load, newPlan, resetLayout" (`floor_plan_controller.dart:570-573`).
- A lock is none of these. It moves no state id (spec Facts: "`clearHistory` does not move the state id").

So I did not make `lockBroken` report or bump. I documented the behaviour in its doc comment:

> A lock is no edit (it moves no state id): by itself it moves neither [revision] nor [unitChanges], though [unitDetails] reads the new `locked` at once (spec 2b S3 names edits, undo, redo, a mode switch, [load] and [newPlan] for both). When the edit that froze the objects applies on its retry, that edit reports the lock with it; when the retry is refused, the lock is reported with the next design change.

The second sentence follows from the code. The retried edit emits `commands.changes`, which bumps `revision` and runs `_reportUnits`. The baseline's index is no longer the cache's current one (the `locked` notify made it stale), so the diff carries the `locked` flag change. Only a refused retry leaves the report until the next design change. `_lockFromCopy`'s doc says the same: "As [lockBroken], it moves neither [revision] nor [unitChanges] by itself."

## TDD evidence

RED: I wrote the implementation before the tests, so I set the three lib files aside in a tagged stash (`git stash push -u -m t11-red-evidence-lib -- <3 lib paths>`, SHA `4ea4be73…`) and ran the new tests against HEAD's lib. I then restored with `git stash apply 4ea4be73f550f09e8460479455da1ce6f190f8f2` and dropped the entry (`Dropped stash@{0} (4ea4be73f550f09e8460479455da1ce6f190f8f2)`).

`cd packages/jet_cad_2d_plan && flutter test test/service/service_session_test.dart test/controller/mode_test.dart`:
```
test/service/service_session_test.dart:58:26: Error: Undefined name 'PlanMode'.
test/service/service_session_test.dart:63:7: Error: The method 'setMode' isn't defined for the type 'PlanController'.
```
These are the compilation errors the brief's Step 4 expects.

GREEN, the focused tests, all from `packages/jet_cad_2d_plan`:
- `flutter test test/service/service_session_test.dart` → `00:00 +8: All tests passed!`.
- `flutter test test/controller/unit_changes_test.dart` → `00:02 +17: All tests passed!`.
- The six focused files together (service_session, mode, barrel, unit_colour, unit_data, unit_detail) failed first only on SM-execute-false (F-1). After the fix: `00:00 +8: All tests passed!` for the session file, and the full suite below.

## Gates (packages/jet_cad_2d_plan; nothing else touched)

- `dart format .` → `Formatted 231 files (3 changed)` (the first run), then clean.
- `flutter test` → `00:45 +993: All tests passed!`. No failure, so nothing to compare against `tool/ci/standing_failures.txt`.
- `flutter analyze` → `No issues found! (ran in 3.9s)`.
- `dart format --output=none --set-exit-if-changed .` → `Formatted 231 files (0 changed) in 0.49 seconds.`, `format exit 0`.
- `git status --short` after commit: empty. No pubspec, kit or `tool/ci` change, so neither `check_kit_deps` nor the `tool/ci` tests apply.

## Mutations (on the committed e7f8e05a)

Each was applied with a one-occurrence string replacement, run against the named test, and reverted with `git checkout -- <file>`. `git diff --quiet -- <file>` exited 0 (`diff exit 0`) after every one.

| Mutation | Test run | Failing line quoted |
|---|---|---|
| M-SM1: `execute`'s `if (_service != null) return false;` deleted | SM-execute-false | `Expected: false` / `Actual: <true>` |
| M-SM2: `_requireDesign`'s body emptied | SM-execute-false | `Expected: throws <Instance of 'StateError'>` / `Actual: <Closure: () => bool>` / `Which: returned <false>` |
| M-SM2 | TC6 (`unit_colour_test.dart`) | `Expected: throws <Instance of 'StateError'>` / `Actual: <Closure: () => bool>` / `Which: returned <false>` |
| M-SM2 | HD4 (`unit_data_test.dart`) | the same three lines as TC6 |
| M-SM3: `document => _session.document` → `document => activeDocument` | SM-members | `Expected: same instance as <Instance of 'DraftDocument'>` / `Actual: <Instance of 'DraftDocument'>` |
| M-SM4: the copy's `LockExpander(document, locks)..install()` → `LockExpander(document, locks)` | SM-copy-lock | `Expected: throws <Instance of 'PlanLocked'>` / `Actual: <Closure: () => void>` / `Which: returned <null>` |
| M-SM5: `_lockFromCopy`'s `s.document.commands.clearHistory();` → `document.commands.clearHistory();` | SM-copy-boundary | `Expected: <1>` / `Actual: <2>` / `the copy's history cleared, then the retried move` |
| M-SM6: `_lockFromCopy`'s `_session.locks.addBroken(document, objects);` deleted | SM-copy-boundary | `Expected: Set:[18]` / `Actual: Set:[]` / `Which: does not contain <18>` |
| M-SM7: `isFrozen: frozen.contains` → `isFrozen: (_) => false` (service_session.dart) | SM-copy-boundary | `The following KitHookFailure was thrown running a test:` / `box.square.reach threw HookBoom(reach)` |
| M-SM8: `_inDesign => _service == null` → `_inDesign => true` | SM-select | `Expected: empty` / `Actual: Set:['12']` / `service` |
| M-SM9: `setMode`'s `_select(labels);` deleted | SM-select | `Expected: Set:[SelectionKey:SelectionKey( 18)]` / `Actual: Set:[]` |
| M-SM10: `if (_droppedServices.remove(s)) s.dispose();` → `_droppedServices.remove(s);` | SM-lifetime | `Expected: throws <Instance of 'FlutterError'>` / `Actual: <Closure: () => void>` / `Which: returned <null>` |
| M-SM11: `undo`'s `final commands = activeDocument.commands;` → `document.commands` | SM-undo | `Expected: [0.0, -1.0, -1.0, 0.0, -2170.0, 2050.0]` / `Actual: [0.0, -1.0, -1.0, 0.0, -1836.5, 1978.75]` |
| M-SM12: `_refreshFlags`' `final active = activeDocument.commands;` → `document.commands` | SM-undo | `Expected: false` / `Actual: <true>` / `the copy has no history` |
| M-SM13: page flows `document: () => activeDocument,` → `document: () => this.document,` | SM-export | `Which: is different.` / `Differ at offset 1376` |
| M-SM14: `deleteSelection`'s `if (_service != null \|\| _midShape)` → `if (_midShape)` | SM-execute-false | `Expected: false` / `Actual: <true>` at `service_session_test.dart:214:5` (`expect(c.deleteSelection(), isFalse);`) |
| M-SM15: `_activeUnits => _service?.units ?? _session.units` → `_activeUnits => _session.units` | TA3 | `Expected: '1'` / `Actual: <null>` at `unit_detail_test.dart:522:5` |
| M-SM15 | TD8 (restored tail) | `Expected: false` / `Actual: <true>` at `unit_detail_test.dart:245:5` (`expect(identical(c.unitDetails, moved), isFalse);`) |
| M-SM15 | MD-CD1 | `Expected: a numeric value within <2.6e-9> of <-1850.0>` / `Actual: <-2600.0>` / `Which:  differs by <750.0>` |
| M-SM16 (mine): `serviceCopyOf`'s `permissions: DraftPermissions.runtime` → `DraftPermissions.all` | MD-C4 | `Expected: <Instance of 'DraftPermissions'>` / `Actual: <Instance of 'DraftPermissions'>` at `mode_test.dart:40:5` |
| M-SM17 (mine): `_replace`'s service rebuild block deleted | MD-C5 | `Expected: empty` / `Actual: Set:['1', '2']` at `mode_test.dart:58:5` |
| M-SM17 | SM-lifetime | `Expected: not same instance as <Instance of 'ServiceSession'>` at `service_session_test.dart:108:5` |
| M-SM18 (mine): `_buildService`'s `register: _registerComponents` → a registrar without `registerUnitComponents` | HD6 (restored block) | `Expected: {'zeta': 'Masa 4.ğ', 'id': '7f3c-ä', 'alpha': ''}` / `Actual: {}` at `unit_data_test.dart:264:5` (`expect(detailsOf(c, '5').single.data, hostData());`) |
| M-SM18 | TC7 (restored block) | `Expected: PlanSwatch:<PlanSwatch.purple>` / `Actual: <null>` at `unit_colour_test.dart:341:5` (`expect(detailsOf(c, '4').single.colour, purple);`) |
| M-DC10 (mine): `_replace`'s `if (_unitBaseline != null) {` → `if (_unitBaseline != null && _inDesign) {` | DC10 | `Expected: [PlanUnitsReplaced:PlanUnitsReplaced()]` / `Actual: []` at `unit_changes_test.dart:365:5` |
| M-DC16 (mine): `_onDesignChange`'s `_reportUnits();` → `if (_inDesign) _reportUnits();` | DC16 | `Expected: [` / `Actual: []` / `Which: at location [0] is [] which shorter than expected` at `unit_changes_test.dart:571:5` |

Tried and not red: `serviceCopyOf`'s `keepUnreadableComponents: true` → `false`, run against HD6 and TC7. Both still passed (`00:00 +1: All tests passed!`). The fixture's invalid data and colour payloads decode leniently, so the flag is not exercised there. I used M-SM18 for those blocks instead.

MD-C3 and MD-C8 have no Task 11 mutation:
- MD-C8's refusal happens in `load`'s decode, before any service code runs.
- MD-C3's "a fresh copy per entry" holds under every single-point mutation I tried in `setMode`. Removing `_service = null;` still gives a fresh copy on re-entry.

Both are today's oracle tests, ported for their service halves.

## Self-review

- Names follow the Shared interfaces: `PlanMode`, `ServiceSession` (fields `document`, `measurer`, `parametric`, `labels`, `lockExpander`, `boundary`, `index`, `page`, `selection`, `outlines`, `toolContext`, `tool`, `tools`, `units`, `history`, `onSelection`, `canUndo`, `canRedo`, `detach()`, `dispose()`), `serviceCopyOf`, and the controller members. There is no `tool:` factory and no `ServiceHost` (R-17: Task 14).
- Fixtures are not degenerate: tables are quarter-turned and mirrored or turned by 37 degrees, all off the origin; moves use non-integer deltas.
- 2a's design tests are unchanged and pass (993 in the suite). In design, every re-pointed member reads what it read before.
- Non-ASCII check: `grep -nP '[^\x00-\x7F]'` over the new files finds only the `…` in `service_plans.dart`'s doc comment, which is the brief's own. The added test lines carry no escapes. The restored HD6 block reads the existing `hostData()`, whose `ğ`/`ä` literals I did not touch.

## Concerns

1. DC7, DC15 and NS5 are not ported (Task 13 members, and for DC7 the service tool and view). The controller should assign them; suggestions are above.
2. The SM-execute-false fixture fix (F-1) is a deviation from the brief's test text. It moves only where the command is built.
3. `ServiceSession`'s `units` is made last, which differs from the brief's order (rationale above).

---

# Fix round 1

Commit: `c0011082 test(plan): pin the copy's E3 path, the tool reset and E4 in the copy (2b Task 11 fix 1)` (on e7f8e05a).

## What changed

1. **Important: the copy's E3 path is now pinned.** I added SM-copy-damage to `test/service/service_session_test.dart`. It ports the E3 commands of 2a's `failure_flow_test.dart` (`_Sabotage`/`_Throwing` from F-6; `_HalfUndone`/`_ThenThrow` from F-14; `_HalfRedone`/`_UndoThen` from F-14b) and uses one design per case. Each design is the box kit with a square at `atSquare` (turned 30 degrees, off the origin) and one design step, in service (`boxInService`). The three cases:
   - **An edit.** A first service move of the square. Then, with `sw.failing.add('reach')`, `copy.commands.execute(_Sabotage(SetComponentCommand<SquareParams>(square, SquareParams(side: 1300, poisoned: true))))` throws `PartialMutationError`. Asserted: one `rollbackFailed`; the copy's `canUndo` false; `c.canUndo.value` false; the design's `undoDepth` unchanged; `c.damaged.value` false.
   - **An undo.** `_HalfUndone(TransformNodeCommand(square, …))` on the copy, then `c.undo` returns normally. Asserted: one `rollbackFailed`; `damaged` false; the design's `undoDepth` unchanged; the copy's `canUndo` and `canRedo` false; `c.canUndo.value` false.
   - **A redo.** `_HalfRedone(…)`, then `c.undo()`, then `c.redo` returns normally. Asserted: one `rollbackFailed`; `damaged` false; the design's depth unchanged; the copy's `canRedo` false; `c.canRedo.value` false.

   In the undo case, the premise first read `c.canUndo.value`. That flag follows the copy's change stream, which is asynchronous, so the premise was false. It now reads `copyB.commands.canUndo`.
2. **SM-tool-reset.** In design, `selectTool('test.slab')` and a pointer down at (1250.5, -730.25) put the tool part-way through a shape (premise `isMidShape`). Then `setMode(service)`. Asserted: `activeTool.value == 'plan.select'`, the tool's `isMidShape` false, and `plan.select` still active after `setMode(design)`.
3. **SM-copy-unreadable.** 2a's E4 fixture (F-5) can express this: a poisoned square saved, then loaded with `sw.failing.add('fromJson')`, so the design keeps it raw (premise: `unknownOf(broken)` not empty). Asserted: `setMode(service)` returns normally; the copy is not the design; the copy's `unknownOf(broken)` equals the design's; the copy encodes the same `box.square` section as the design (`componentsText`).
4. **One lock helper.** `lockBroken` is now `_lock(objects, document.commands)` and `_lockFromCopy` is `_lock(objects, s.document.commands)`. `_lock(Set<Handle>, CommandDispatcher history)` holds the shared body: `addBroken` over the design, `history.clearHistory()`, `locked`, flags, grips, notify.
5. **The citation in `lockBroken`'s doc is fixed.** It now says that `unitChanges` reports design edits, undos and redos, `load` and `newPlan` (spec 2b S3), and that `revision` is today's (spec S5). Its doc names an edit, an undo or a redo, a mode switch, `load`, `newPlan` and `resetLayout` (jet_cad_floor_plan's floor_plan_controller.dart:570-573).
6. **Markers in `unit_changes_test.dart`.** The header now says DC15 → Task 13 and DC7 → Task 14. The DC7 comment says "Task 14 ports it"; the DC15 comment says "Task 13 ports it".
7. **SM-copy-boundary's refused half** now also asserts:
   - the premise that the design has steps (`designDepth > 0`);
   - the design's `undoDepth` unchanged after the refused move;
   - exactly one `hookFailed` diagnostic, `('box', SquareParams.id)`. The first failure is reported; the retry's `KitHookFailure` is rethrown by `_LockCheck._first` without a report (locks.dart:300-308).
8. **`_buildService`.** If the `ServiceSession` constructor throws, the decoded copy is disposed (`unawaited(copy.dispose())`) and the measurer cleared, then the error rethrown. There is no test: no constructor step can be made to throw from a test without a seam.

## Covering tests and gates (packages/jet_cad_2d_plan)

- `flutter test test/service/service_session_test.dart` → `00:00 +11: All tests passed!`.
- `dart format .` → `Formatted 231 files (0 changed)`.
- `flutter test` → `00:46 +996: All tests passed!`. This run includes `unit_changes_test.dart` and the other controller tests.
- `flutter analyze` → `No issues found! (ran in 3.9s)`.
- `dart format --output=none --set-exit-if-changed .` → `format exit 0`.
- `git status --short` after commit: empty.

## Mutations (on c0011082)

Each was reverted with `git checkout -- <file>`, and `git diff --quiet -- <file>` then exited 0 (`diff exit 0`).

| Mutation | Test | Failing line quoted |
|---|---|---|
| M-SM19: `_damageCopy`'s `s.document.commands.notifyLoaded();` → `document.commands.notifyLoaded();` | SM-copy-damage | `Expected: false` / `Actual: <true>` / `the copy rebuilt` at `service_session_test.dart:513:5` (`expect(copy.commands.canUndo, isFalse, reason: 'the copy rebuilt');`) |
| M-SM20: `undo`'s `(_service?.boundary ?? _session.boundary).partialMutation(error);` → `_session.boundary.partialMutation(error);` | SM-copy-damage | `Expected: false` / `Actual: <true>` at `:530:5` (`expect(b.c.damaged.value, isFalse);`) |
| M-SM21: the same in `redo` | SM-copy-damage | `Expected: false` / `Actual: <true>` at `:548:5` (`expect(r.c.damaged.value, isFalse);`) |
| M-SM22: `setMode`'s `design.tools.activate(design.toolById(planSelectToolId)!);` deleted | SM-tool-reset | `Expected: 'plan.select'` / `Actual: 'test.slab'` / `Which: is different.` at `:565:5` |
| M-SM23: `serviceCopyOf`'s `keepUnreadableComponents: true` → `false` | SM-copy-unreadable | `Expected: return normally` / `Actual: <Closure: () => void>` / `Which: threw HookBoom:<HookBoom(fromJson)>` at `:587:5` |
| M-SM5, rerun on the helper: `_lockFromCopy`'s `_lock(objects, s.document.commands)` → `_lock(objects, document.commands)` | SM-copy-boundary | `Expected: <1>` / `Actual: <2>` / `the copy's history cleared, then the retried move` at `:429:5` |
| M-SM6, rerun: `_lock`'s `_session.locks.addBroken(document, objects);` deleted | SM-copy-boundary | `Expected: Set:[18]` / `Actual: Set:[]` / `Which: does not contain <18>` at `:421:5` |

Item 7's new assertions have no mutation of their own here:
- The design-depth assertion guards the same fault M-SM5 injects, but under M-SM5 the test stops red at the first half, so it never reaches the new assertion.
- The diagnostic count pins `_LockCheck._first`'s retry not reporting, which is 2a's locks.dart.
