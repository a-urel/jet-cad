# Task 12 report: permissions and the generic tools

Status: DONE_WITH_CONCERNS (concerns are notes for later tasks; nothing open in this task)
Base: 51906ea4. Commit: 23621eb9 `feat(plan): permissions and the generic tools (P2)`.

## Implemented

- `lib/src/controller/permissions.dart`: `PlanPermissions` exactly as the brief (tools, twelve flags, `full`, `readOnly`, `allowsTool`, `allows(PlanGate)`, `edits`, `draft`, `copyWith`, `==`/`hashCode`/`toString`). Exported from the barrel (after `camera_bounds.dart`).
- `lib/src/tools/plan_select_gates.dart`: `PlanSelectGates extends LockGates` (ruling F5): each of move/rotate/reshape/delete is the permission flag `&& super.<gate>` (the lock); `idleKeys` a settable field.
- `lib/src/tools/generic_tools.dart`: `PlanToolIds` (eight reserved ids, `symbolNeeds`), `GenericTool`, `genericTools` (V L P R C A T; select needs nothing, the rest `{geometry}`; Fill on polyline/rectangle/circle), `GenericToolSet`, `buildGenericTools` (select with the gates and an injectable `MoveResolver`).
- `session.dart` (rulings F1/F2/F3): constructor gains `permissions` and `fill`; `lockGates` became `late final PlanSelectGates gates`, shared by the `GripCache` and the select tool; `generic = buildGenericTools(gates: gates, fill: fill); select = generic.select;` so the session's only plan.select is the gated generic one, wrapped by Task 11's guard and used by `ToolController(initial:)` and the swap; the other generic tools added via `addTool` right after the select entry, before any kit tool. The map owns and disposes every tool; `generic.dispose()` is never called by the session or controller. `dispose()` disposes `gates`.
- `plan_controller.dart`: `permissions` factory/constructor parameter; `_permissions`, `_fill`, `_toolNeeds`; `_open` sets `document.commands.permissions = _permissions.draft` before building the session and registers generic + kit tool needs; `_allowsTool` (ids, known id, needs vs engine permissions); `needsOf`, `registerToolNeeds`; the `permissions` getter/setter (engine permissions follow, stale drag cancelled, `grips.gatesChanged()`, a no-longer-allowed tool replaced by plan.select, notify); `selectGates`, `planSelect`, `fill` (@internal); host `undo()`/`redo()` run through `_unrestricted`; `_fill` disposed. `deleteSelection` keeps Task 11's catches (carried: a locked selection answers false, never throws) and goes through the gated select tool's own `deleteSelection`.
- `test/support/tool_events.dart` (for Tasks 13/14), four test files: `permissions_test.dart` (PM-1..7), `tools/plan_select_gates_test.dart` (PM-8..11), `tools/generic_tools_test.dart` (PM-12..13), `controller/permissions_controller_test.dart` (fixture sanity, PM-14..21).

## TDD evidence

RED (Step 6, before any lib code), `flutter test test/controller/permissions_test.dart test/tools test/controller/permissions_controller_test.dart`, first error:

```
test/controller/permissions_test.dart:11:13: Error: Type 'PlanPermissions' not found.
```
Error tally: `Undefined name 'PlanPermissions'` 40, `genericTools` 12, `PlanToolIds` 4, `Method not found: 'buildGenericTools'` 4, `Method not found: 'PlanSelectGates'` 2 (no test ran).

First GREEN attempt: 19 passed, 2 failed (both fixture problems, see Deviations 2 and 3):
```
PM-17 ... Expected: ToolPhase:<ToolPhase.idle>  Actual: ToolPhase:<ToolPhase.dragging>
PM-19 ... (line 162, expect(c.canUndo.value, isTrue)) Expected: true  Actual: <false>
```
Debug showed PM-17's press classified `PressClass.empty` / `DragKind.band`: the line tool grid-snapped the tapped ends (a=(4120.5,-1415.25), b=(4730.75,-1102.5) were drawn as `[4075.0, -1450.0, 4775.0, -1150.0]`), so the brief's `mid` was 24-100 mm off the line (index pick at r=24 missed, r=100 hit). After the fixture fixes: `00:00 +21: All tests passed!`

PM-21 (added, see Deviation 4) RED before the fix:
```
PermissionDeniedError: "Set component" needs components
00:00 +0 -1: Some tests failed.
```
then green after wrapping `reportLocale`'s settling command in `_unrestricted`.

## Mutations (all on committed 23621eb9; each reverted with `git checkout -- <file>`, then `git diff --quiet -- <file>` exited 0 — printed `reverted` every time)

| Mutation | File | Test | Red line |
|---|---|---|---|
| M-PM1 delete `undo: false,` from readOnly | permissions.dart | PM-1 | `Which: at location ['undo'] is <true> instead of <false>` |
| M-PM2 `move: this.move,` | permissions.dart | PM-2 | `Which: at location ['move'] is <true> instead of <false>` |
| M-PM3 drop `\|\| !setEquals(other.tools, tools)` | permissions.dart | PM-3 | `Expected: false Actual: <true>` |
| M-PM4 drop `id == _select \|\| ` | permissions.dart | PM-4 | `Expected: true Actual: <false>` |
| M-PM5 swap move/rotate arms of `allows` | permissions.dart | PM-5 | `Expected: <false> Actual: <true>` |
| M-PM6a `draft` always `DraftPermissions.all` | permissions.dart | PM-6 | `Expected: same instance as <Instance of 'DraftPermissions'>` |
| M-PM6b drop the tools term of `edits` | permissions.dart | PM-6 | same, at `permissions_test.dart 192:5` (the `drawing.draft` line) |
| extra M-PM7 drop the tools sort in toString | permissions.dart | PM-7 | `Expected: 'PlanPermissions(tools: {acme.x, plan.text})' Actual: 'PlanPermissions(tools: {plan.text, acme.x})'` |
| M-PM8 `delete => super.delete` | plan_select_gates.dart | PM-8 and PM-20 | PM-8 `Which: at location ['delete'] is <true> instead of <false>`; PM-20 `Expected: false Actual: <true>` |
| M-PM9a drop `_locked.addListener(_recompute);` | kits/locks.dart | PM-9 | `Expected: true Actual: <false>` |
| M-PM9b `move => _permissions().move` | plan_select_gates.dart | PM-9 | `Which: at location ['move'] is <true> instead of <false>` |
| M-PM10 drop the chain loop of `_recompute` | kits/locks.dart | PM-10 | `Expected: true Actual: <false>` |
| extra M-PM11 drop `_locked.removeListener(_recompute);` | kits/locks.dart | PM-11 | `Expected: false Actual: <true>` |
| M-PM12 swap letters L and P | generic_tools.dart | PM-12 | `Which: at location [1] is 'P' instead of 'L'` |
| M-PM13 `PolylineTool()` | generic_tools.dart | PM-13 | `Expected: same instance as ValueNotifier<bool>... Actual: <null>` |
| M-PM14 drop `if (!_permissions.allowsTool(id)) return false;` | plan_controller.dart | PM-14 | `Expected: false Actual: <true>` |
| M-PM15 drop the needs loop | plan_controller.dart | PM-15 (and Task 8's C9) | PM-15 `Expected: false Actual: <true>`; C9 also red |
| M-PM16 drop the fallback to plan.select | plan_controller.dart | PM-16 | `Expected: 'plan.select' Actual: 'plan.line'` |
| M-PM17 drop `if (stale) select.cancel(...)` | plan_controller.dart | PM-17 | `Expected: ToolPhase:<ToolPhase.idle> Actual: ToolPhase:<ToolPhase.dragging>` |
| M-PM18 drop `_open`'s `commands.permissions = _permissions.draft` | plan_controller.dart | PM-18 | `Expected: same instance as ...` at `permissions_controller_test.dart 155:7` (after `newPlan()`) |
| M-PM19 `commands.undo()` without the lift | plan_controller.dart | PM-19 | `PermissionDeniedError: "Remove entity" needs geometry` |
| extra: `commands.redo()` without the lift | plan_controller.dart | PM-19 | `PermissionDeniedError: "Add line" needs geometry` |
| extra: `_unrestricted` does not restore | plan_controller.dart | PM-19 | `Expected: same instance as <Instance of 'DraftPermissions'>` |
| M-PM21 (new) reportLocale's command without the lift | plan_controller.dart | PM-21 | `PermissionDeniedError: "Set component" needs components` |

No mutation survived.

## Gates (packages/jet_cad_2d_plan, on the committed tree)

```
flutter test        -> 00:04 +183: All tests passed!
flutter analyze     -> No issues found! (ran in 2.7s)
dart format --output=none --set-exit-if-changed . -> Formatted 71 files (0 changed); exit 0
```
`git status --short` clean after the commit (no analysis_options.yaml touched by the pub get that analyze ran).

## Files

- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_plan/lib/src/controller/permissions.dart (new)
- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_plan/lib/src/tools/plan_select_gates.dart (new)
- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_plan/lib/src/tools/generic_tools.dart (new)
- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart
- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_plan/lib/src/controller/session.dart
- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart
- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_plan/test/support/tool_events.dart (new)
- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_plan/test/controller/permissions_test.dart (new)
- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_plan/test/tools/plan_select_gates_test.dart (new)
- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_plan/test/tools/generic_tools_test.dart (new)
- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_plan/test/controller/permissions_controller_test.dart (new)

## Deviations from the brief

1. **`selectTool`'s old geometry check removed** (plan_controller.dart). Task 8's `selectTool` refused any non-select tool while the engine denied `geometry`. The brief's `_allowsTool` checks each tool's needs against the engine, which subsumes it for every generic tool and every test-kit tool (their needs include geometry). Keeping both would (a) let M-PM15 survive (the old check would still refuse the six drawing tools under `geometry: false`) and (b) refuse a kit tool whose needs exclude geometry, against spec P2 ("a tool's needs"). Task 8's C9 stays green unchanged and is now pinned by the needs loop (M-PM15 also turns C9 red). The selection still clears for any tool other than select.
2. **PM-17 drags from the line as drawn** (fixture only, assertions unchanged). The drawing tools snap to the page grid, so `(a + b) * 0.5` was not on the drawn line (drawn `[4075, -1450, 4775, -1150]`); the press hit empty space and started a band. Added `drawnMidOf(document, line)` to `tool_events.dart` and PM-17 uses it; the unused top-level `mid` was removed. Still off-origin under the turned, flipped camera.
3. **PM-17 and PM-19 await the history flags** (fixture only). `canUndo` is refreshed from `document.commands.changes`, an asynchronous broadcast stream (Task 8), so `expect(c.canUndo.value, isTrue)` right after a synchronous draw read the stale `false`. Both tests became `async` and call `await settleHistory()` (a `Future.delayed(Duration.zero)` helper added to `tool_events.dart`) before that expectation; the assertion itself is unchanged.
4. **Added: `reportLocale` settling runs through `_unrestricted`, pinned by new PM-21.** With this task the document's engine permissions follow the profile, so a controller made with `readOnly` (engine `DraftPermissions.readOnly`) threw `PermissionDeniedError: "Set component" needs components` the first time a widget reported a locale for an untouched new plan (Task 9's as-if-made-so settling). That is the controller's own settling, not a user edit, so it is not gated (the same rule as host undo/redo). PM-21 pins it (M-PM21 red).
5. Small doc-comment edits in session.dart and plan_controller.dart (the entries list, `addTool`, `deleteSelection`, `selectTool`) to describe the new behaviour; no behaviour beyond the brief's.

No Shared interface or another task's contract changed. `PlanSelectGates`, `GenericToolSet`, `buildGenericTools` signatures are verbatim.

## Self-review

- F1: gates and generic tools are `DocumentSession` members, built in its constructor, disposed with it. F2: the map owns every tool (generic tools added via `addTool`, wrapped by `GuardedTool`), no separate dispose; full suite (incl. lifetimes/guarded swap tests) shows no double-dispose assertion. F3: `select = generic.select`; there is no other `SelectTool` in the session. F5: no lock logic duplicated; `PlanSelectGates` reads `super.<gate>`.
- Gate getters allocate nothing: one closure call returning the current `PlanPermissions` field plus `LockGates`' cached bool.
- The setter order: engine permissions first, then the stale-drag cancel (on the unguarded select, which the guarded one forwards), `grips.gatesChanged()`, then the tool fallback, then notify. A same-value assignment returns early (PM-16's tail).
- `_toolNeeds` is filled per `_open` (same ids every document); unknown ids (`needsOf` null) are refused by `_allowsTool`.
- Host undo/redo restore the saved permissions in `finally`, so a `PartialMutationError` still leaves the profile in place before Task 11's handler runs.

## Concerns (for later tasks)

- **The drawing tools grid-snap**: tests of Tasks 13/14 that tap points with `tool_events.dart` must read drawn geometry (`drawnMidOf`) rather than assume tapped points are stored.
- **History flags are asynchronous**: `canUndo`/`canRedo`/`dirty` lag a synchronous edit until the change stream delivers; plain `test()`s need `await settleHistory()` (or `tester.pump()` in widget tests).
- Other controller-internal commands that run while permissions may be closed: I found only `reportLocale`'s settling. Task 13's symbol loading and Task 17-19 panels commit through `execute()` and are user edits (correctly gated); if a later task adds another controller-own command (not a user edit), it should go through `_unrestricted` too.
- PM-7 and PM-11 have no mutation named in the brief; I ran one extra mutation for each (both red), listed above.
