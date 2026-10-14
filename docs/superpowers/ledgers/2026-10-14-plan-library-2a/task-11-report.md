# Task 11 report: the failure boundary (2a P4)

Status: DONE_WITH_CONCERNS. Commits on feat/plan-library-2a: `5b4cff41` feat(plan): the failure boundary around every kit hook (2a P4); `3bd18b90` test(plan): F-G9 pins the nested attribution through a dry run. BASE `8d93ff40`.

## Implemented

- `lib/src/kits/guard.dart` (new): `KitHookFailure` (exported from the barrel); `GuardedType<T>` (one `try` per member, `on KitHookFailure { rethrow; }` keeps a nested type's attribution; no closure, collection or boxing on the happy path); `PlanTypeGuard`; `guardFactory`; `GuardedTool` (events, getters, paints, cancel and dispose guarded; `PlanLocked`/`DanglingReferenceError` set the hint and cancel the gesture; a `KitHookFailure` is its kit's diagnostic; a kit tool's own error is a diagnostic + cancel + `onFailed`; a generic (`plan`) tool's own error is rethrown; a failed paint is skipped and `onFailed` runs after the frame); `GuardedGrips`; `guardAttachment`; `FailureBoundary` (`recover`, `probeType`, `probeLoaded`, `reportUnreadable`, `partialMutation`). Re-exports `DiagnosticsLog`.
- `lib/src/kits/section_boundary.dart` (new): `KitSectionBoundary` (a small box keyed `kit-section-failed` with `PlanStrings.sectionFailed`; diagnostic via `addAfterFrame`).
- `lib/src/controller/diagnostics_log.dart`: Task 8's log completed in place: dedupe by (kit id, subject, code); `entries`, `add`, `addAfterFrame`; Task 8's `report`, `reportAll`, `clearPlanScoped` kept (clearing also forgets the plan-scoped dedupe keys).
- `lib/src/kits/locks.dart`: `LockExpander.onHookFailure`, `onPartialMutation`; `_expand` wraps whenever a hook is set; `_LockCheck.apply` retries once after a recovery that froze something (the original re-expanded through the parametric expander, one undo step) and reports a `PartialMutationError` before rethrowing it.
- `lib/src/controller/session.dart`: `log` and `guard` constructor parameters; `LockedGrips(locks, GuardedGrips(dispatch, ...))`; every tool in the map guarded (select and `addTool` under `plan`, kit tools under their kit); `runKitFactories(kits, services, disabled)` calls tool factories and `gripsFor` through `guardFactory`; `late final FailureBoundary boundary`; kit products' disposals guarded (grip providers, shared-cache values).
- `lib/src/controller/shared_cache.dart`: `dispose({onError})`.
- `lib/src/controller/plan_controller.dart`: types registered with `guard: const PlanTypeGuard()`; `lockHint`, `damaged`, `isToolDisabled`; `execute` extended (not duplicated); `_damage`; `_guardTool`; `_open` resets damaged/disabled, builds the boundary, wires the expander hooks, and at its end runs `reportUnreadable` then `probeLoaded`; `_replace` arms the guarded select; `deleteSelection` answers false on a refusal (Task 10 carry); `save` reads a damaged plan back first; `toolFor` returns the factory's tool, unwrapped.
- `test/support/throwing_kit.dart`: new hooks `toolMidShape`, `toolDispose`, `gripsDispose`, `cacheDispose` (BoomTool's getter and dispose; BoomGrips is now `Disposable`; a `BoomCache` the tool asks for through `shared`).
- Tests: the brief's four files; `test/kits/guarded_swap_test.dart` (F-10, F-12, throwing kit); F-11 in `failure_flow_test.dart`.

## TDD evidence

RED, the four brief test files before any lib code (`flutter test test/kits/...`):

```
test/kits/guarded_type_test.dart:13:8: Error: Error when reading 'lib/src/kits/guard.dart': No such file or directory
test/kits/guarded_type_test.dart:27:9: Error: Method not found: 'GuardedType'.
test/kits/guarded_type_test.dart:35:9: Error: 'KitHookFailure' isn't a type.
test/kits/failure_flow_test.dart:83:14: Error: The getter 'lockHint' isn't defined for the type 'PlanController'.
test/kits/failure_flow_test.dart:226:14: Error: The getter 'damaged' isn't defined for the type 'PlanController'.
test/kits/failure_flow_test.dart:269:14: Error: The method 'isToolDisabled' isn't defined for the type 'PlanController'.
```

First run after the lib code: five failures, all fixtures (Deviations 1-3): F-G1/F-G2 (`handleSeed":22}` expected, `handleSeed":23}` actual), F-B3 (`A RenderFlex overflowed by 99420 pixels on the bottom.`), F-2 and F-6 (`canUndo.value` read before the asynchronous change event). Whole suite: C14 red (Deviation 4).

F-10 RED before `GuardedTool.dispose` caught a kit's dispose:

```
The following BoomFailure was thrown running a test:
BoomFailure(toolDispose)
#2      GuardedTool.dispose (package:jet_cad_2d_plan/src/kits/guard.dart:458:11)
#3      DocumentSession.disposeKitProducts (package:jet_cad_2d_plan/src/controller/session.dart:168:25)
#4      PlanController._replace (package:jet_cad_2d_plan/src/controller/plan_controller.dart:544:9)
```

F-11 and F-12 were written after the code they exercise (F-12 passed on its first run; F-11 failed only on its own `KeyEventResult.handled` expectation, Deviation 6). Their RED evidence is their mutations below.

GREEN: `flutter test test/kits` → `00:01 +61: All tests passed!`; the whole package → `00:03 +157: All tests passed!`.

## Mutations

Driver: one python script applied each mutation to a committed file, ran `flutter test <file> --plain-name <test>`, then `git checkout -- <file>` and `git diff --quiet -- <file>`. Every row below: RED, and revert `git diff --quiet` exit 0 (all 59 runs printed `revert-exit 0`; `git status --short` clean afterwards). The red line is quoted from the run.

| Mutation | File | Test | Red line |
|---|---|---|---|
| M-F-G1 reach bare | guard.dart | F-G1 | `Which: threw HookBoom:<HookBoom(reach)>` |
| M-F-G2 references | guard.dart | F-G2 | `Which: threw HookBoom:<HookBoom(references)>` |
| M-F-G3 generate | guard.dart | F-G3 | `Which: threw HookBoom:<HookBoom(generate)>` |
| M-F-G4 dissolves | guard.dart | F-G4 | `Which: threw HookBoom:<HookBoom(dissolves)>` |
| M-F-G5 diagnose | guard.dart | F-G5 | `Which: threw HookBoom:<HookBoom(diagnose)>` |
| M-F-G6 editCapability | guard.dart | F-G6 | `Which: threw HookBoom:<HookBoom(editCapability)>` |
| M-F-G7 referencePolicy | guard.dart | F-G7 | `Which: threw HookBoom:<HookBoom(referencePolicy)>` |
| M-F-G8 pageKey | guard.dart | F-G8 | `Which: threw HookBoom:<HookBoom(pageKey)>` |
| M-F-G9a placeBox | guard.dart | F-G9 | `Which: threw HookBoom:<HookBoom(placeBox)>` |
| M-F-G10 placeInput | guard.dart | F-G10 | `Which: threw HookBoom:<HookBoom(placeInput)>` |
| M-F-G11 readBox | guard.dart | F-G11 | `Which: threw HookBoom:<HookBoom(readBox)>` |
| M-F-G12 contributesPlace | guard.dart | F-G12 | `Which: threw HookBoom:<HookBoom(contributesPlace)>` |
| M-F-G13 readsPlaces | guard.dart | F-G13 | `Which: threw HookBoom:<HookBoom(readsPlaces)>` |
| M-F-G9b generate's `on KitHookFailure { rethrow; }` deleted | guard.dart | F-G9 | first run: **SURVIVED** (Deviation 5); after `3bd18b90`: `Which: threw KitHookFailure:<KitHookFailure: ring.disc.generate threw KitHookFailure: box.square.placeBox threw HookBoom(placeBox)>` at guarded_type_test.dart:179 |
| M-F-G14 `wrap` → `type` | guard.dart | F-G14 | `Which: threw HookBoom:<HookBoom(reach)>` |
| M-F1a `recover` → false | guard.dart | F-1 | `Expected: true Actual: <false>` at failure_flow_test.dart:86 (`lockHint`) |
| M-F1b `frozen.addAll` deleted | guard.dart | F-1 | `Expected: true Actual: <false>` at :86 (the retry fails again on the still-surveyed reach, so no PlanLocked and no hint; red earlier than the brief's comment places it) |
| M-F1c `lockHint.value = true` deleted in execute | plan_controller.dart | F-1 | `Expected: true Actual: <false>` at :86 |
| M-F2 `..onHookFailure` not set | plan_controller.dart | F-2 | `Expected: true Actual: <false>` at :138 (the disc's edit) |
| M-F2-retry (extra) `_applied = expandInner(original)` deleted | locks.dart | F-2 | `Bad state: a ParametricEdit applies once (spec 06 D9)` from `_LockCheck._first` |
| M-F3a KitHookFailure clause → rethrow | plan_controller.dart | F-3 | `KitHookFailure: box.square.reach threw HookBoom(reach)` |
| M-F3b `_isNew` → true | diagnostics_log.dart | F-3 | `Expected: an object with length of <1> Actual: [ KitDiagnostic:hookFailed [box box.square]: reach: HookBoom(reach), KitDiagnostic:hookFailed [box box.square]: ...` |
| M-F3b (same) | diagnostics_log.dart | F-B4 | `Expected: false Actual: <true>` |
| M-F9a `on ArgumentError` deleted | plan_controller.dart | F-9 | `Invalid argument(s): out of range` |
| M-F9b `on DanglingReferenceError` deleted | plan_controller.dart | F-9 | `DanglingReferenceError: 12 references 12, which is not a live parametric object` |
| M-F4 `probeLoaded()` deleted | plan_controller.dart | F-4 | `Expected: Set:[18] Actual: Set:[]` |
| M-F5 `reportUnreadable(...)` deleted | plan_controller.dart | F-5 | `Expected: an object with length of <1> Actual: [] Which: has length of <0>` |
| M-F6a `..onPartialMutation` not set | plan_controller.dart | F-6 | `Expected: true Actual: <false>` at :260 (`damaged`) |
| M-F6b `notifyLoaded()` deleted | plan_controller.dart | F-6 | `Expected: false Actual: <true>` at :262 (`commands.canUndo`) |
| M-F7 save → `_saveUnchecked()` | plan_controller.dart | F-7 | `Which: threw JsonUnsupportedObjectError:<Converting object to an encodable object failed: NaN>` |
| M-F8 `tool.create(s)` bare | session.dart | F-8 | `HookBoom(create)` from `DocumentSession.runKitFactories` |
| M-F-T1-onPointerDown/Move/Up/Exit/onKey bare (5 runs) | guard.dart | F-T1 | `Expected: return normally ... Which: threw StateError:<Bad state: boom in onPointerDown>` (and `onPointerMove`, `onPointerUp`, `onPointerExit`, `onKey` respectively) |
| M-F-T2 refusal block deleted | guard.dart | F-T2 | `Expected: true Actual: <false>` (reason `PlanLocked: the edit would change a locked object`) |
| M-F-T3 KitHookFailure head deleted | guard.dart | F-T3 | `KitHookFailure: ring.disc.generate threw Instance of 'HookError'` (rethrown, `plan` tool) |
| M-F-T4 `_isKit` → true | guard.dart | F-T4 | `Expected: throws <Instance of 'StateError'> ... Which: returned <null>` |
| M-F-T5 `onFailed()` at once | guard.dart | F-T5 | `Expected: <0> Actual: <1>` `not inside the paint` |
| M-F-T6a isMidShape → false | guard.dart | F-T6 | `Expected: true Actual: <false>` at guarded_tool_test.dart:248 |
| M-F-T6b `addListener(_forward)` deleted | guard.dart | F-T6 | `Expected: <1> Actual: <0>` |
| M-F-T6c `inner.dispose()` deleted | guard.dart | F-T6 | `Expected: throws <Instance of 'FlutterError'> ... Which: returned <null>` |
| M-F-B1a gripsOf bare | guard.dart | F-B1 | `Bad state: gripsOf` from `GuardedGrips.gripsOf` |
| M-F-B1b `_failed` check deleted | guard.dart | F-B1 | `Expected: empty Actual: [Grip:Grip(stretch 0 @ 7010.0, 3020.0)]` |
| M-F-B1c/d/e drag/preview/movable bare | guard.dart | F-B1 | `Which: threw StateError:<Bad state: drag>` / `<Bad state: preview>` / `<Bad state: movable>` |
| M-F-B2 attach bare | guard.dart | F-B2 | `Bad state: edge` from `guardAttachment` |
| M-F-B3a builder bare | section_boundary.dart | F-B3 | `Bad state: section` thrown building KitSectionBoundary; `Found 0 widgets with key [<'kit-section-failed'>]` |
| M-F-B3b addAfterFrame → add | diagnostics_log.dart | F-B3 | `Expected: not contains SchedulerPhase:<SchedulerPhase.persistentCallbacks> Actual: [SchedulerPhase:SchedulerPhase.persistentCallbacks]` |
| M-F-B4 key without code | diagnostics_log.dart | F-B4 | `Expected: true Actual: <false>` at guard_boundaries_test.dart:184 |
| M-F10a (extra) `gripsFor` bare | session.dart | F-10 | `BoomFailure(gripsCreate)` |
| M-F10b (extra) GuardedTool.dispose bare | guard.dart | F-10 | `BoomFailure(toolDispose)` |
| M-F10c (extra) provider dispose bare | session.dart | F-10 | `BoomFailure(gripsDispose)` |
| M-F10d (extra) `shared.dispose()` without onError | session.dart | F-10 | `BoomFailure(cacheDispose)` |
| M-F11a (extra) deleteSelection's `on PlanLocked` deleted | plan_controller.dart | F-11 | `PlanLocked: the edit would change a locked object` from `_LockCheck._check` |
| M-F11b (extra) session holds select unguarded | session.dart | F-11 | `PlanLocked: the edit would change a locked object` from `_LockCheck._check` |
| M-F12 (extra) isMidShape bare | guard.dart | F-12 | `BoomFailure(toolMidShape)` |

## Gates

`packages/jet_cad_2d_plan` (after `3bd18b90`):

```
dart format .                               Formatted 63 files (0 changed) in 0.10 seconds.
flutter test                                00:03 +157: All tests passed!
flutter analyze                             No issues found! (ran in 2.9s)
dart format --output=none --set-exit-if-changed .   Formatted 63 files (0 changed) ... ; exit 0
```

Step 7, `packages/jet_cad_2d`: `dart test test/invariants/query_allocation_test.dart` → `00:05 +6: All tests passed!`. `git status --short`: clean; no analysis_options.yaml staged; no package other than jet_cad_2d_plan touched.

## Files

Lib: `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart`, `lib/src/kits/guard.dart` (new), `lib/src/kits/section_boundary.dart` (new), `lib/src/kits/locks.dart`, `lib/src/controller/diagnostics_log.dart`, `lib/src/controller/plan_controller.dart`, `lib/src/controller/session.dart`, `lib/src/controller/shared_cache.dart`.
Tests: `test/kits/guarded_type_test.dart`, `test/kits/failure_flow_test.dart`, `test/kits/guarded_tool_test.dart`, `test/kits/guard_boundaries_test.dart`, `test/kits/guarded_swap_test.dart` (new, not in the brief), `test/support/throwing_kit.dart`, `test/controller/plan_controller_test.dart`.

## Deviations from the brief

1. **F-G1, F-G2 fixture**: `addLine` takes a handle from the seed inside the refused closure, so `canon` differed only in `handleSeed` (22 vs 23). The add command is now built (handle taken) before the snapshot (`lineCommand`), then executed inside `expectRefused`. Assertions unchanged.
2. **F-B3 fixture**: `ErrorWidget` fills its constraints; inside an unbounded `Column` it overflowed by 99420 px (a second exception). The boundary is wrapped in `SizedBox(height: 120)`. Assertions unchanged.
3. **F-2, F-6 fixture**: the history flags follow the document's broadcast (asynchronous) change stream, so both tests became `async` and await `Future<void>.delayed(Duration.zero)` before reading `canUndo.value` (as Task 10's L-8 does). Assertions unchanged.
4. **C14 (Task 8's test) expectation extended**: it pinned the load's diagnostics as exactly `[('gone', kitMissing)]`. Task 11's E4 reporting (spec P4, F-5) adds `('test', componentUnreadable)` for the unreadable slab, after the manifest's. I extended the list by that entry with a comment; nothing removed. This is a change to another task's test assertion; the brief's Step 6 expected Task 8's tests unchanged and missed it. Flagged for the reviewer.
5. **F-G9 strengthened** (`3bd18b90`): M-F-G9b survived the brief's F-G9, because an edit's place trigger (`regeneration.dart` `_triggered`) asks the contributor's `placeBox` before the reader's `generate` runs, so the failure never passes through the disc's guard. Added `expect(() => h.system.drift(), throwsA(failed('box', SquareParams.id, 'placeBox')))`: the dry run asks the box first inside the disc's `generate`. M-F-G9b now red.
6. **F-11's Delete key**: `GuardedTool.onKey` answers `KeyEventResult.ignored` after a caught error (the brief's code), so F-11 does not assert `handled`; it asserts the hint and the unchanged document.
7. **`guardFactory<T extends Object?>`** (brief: `T extends Object`): `PlanType.gripsFor` returns `ObjectGripProvider?`, which `T extends Object` cannot infer. A failed factory and a null product both mean "no grips" there.
8. **`toolFor(id)` returns the factory's tool, unwrapped** (`GuardedTool.inner`): Task 8's tests cast `toolFor('test.slab')! as SlabTool`. The tool controller and the map hold the guarded one; `F-8` checks `toolController.active` is a `GuardedTool`.
9. **`selectTool`** decides "drawing" by `id != planSelectToolId` (it compared identity with `session.select`, now the unguarded inner). `session.select` stays the inner `SelectTool` (for `deleteSelection`).
10. **`_saveUnchecked`** marks `_encodedState` only after `encodePlan` returns (Task 8 marked it before encoding; a failed encode would have left a wrong save point). The damaged read-back disposes the decoded document with `unawaited(...)` (`DraftDocument.dispose` is async).
11. **Beyond the brief, for the Task 8 carry (a swap must complete)**: `GuardedTool.dispose` catches a kit tool's dispose (diagnostic); `disposeKitProducts` guards grip providers' and shared-cache values' `dispose` (`SharedCache.dispose({onError})`, values now kept with their kit id; providers with kit and type ids). Pinned by F-10 (M-F10a-d).
12. **`deleteSelection`** catches `PlanLocked` (hint), `DanglingReferenceError` and `KitHookFailure` (diagnostic) and answers false (Task 10 carry). Pinned by F-11 (M-F11a); the select tool's Delete key is covered by the guarded select (M-F11b).
13. **`_guardTool`'s `onFailed`** does nothing after the controller is disposed (a paint failure's post-frame callback could otherwise arm a tool on a disposed controller).
14. Imports: unused/unnecessary ones removed as Step 8 allows (`flutter/foundation.dart` and `flutter/services.dart` in guard.dart; `diagnostics_log.dart` in session.dart and plan_controller.dart, re-exported by guard.dart; `jet_cad_2d_kit`/`jet_cad_2d_plan` barrels in two test files). `plan_controller.dart` imports `../file/plan_format_exception.dart`.
15. Throwing kit hooks added: `toolMidShape`, `toolDispose`, `gripsDispose`, `cacheDispose` (TK3's `failAll` covers them). Not added: `enabled`, non-Number `read`, tool settings: no guard of this task reaches them (property fields are Task 17's).

## Self-review

- Review Focus 2 (F-2): the disc's edit is refused zero times (recovered and retried inside the same `execute`); afterwards both kits' working objects regenerate and the broken square keeps its geometry; one `hookFailed`. The retry's re-expansion is pinned (M-F2-retry).
- The guard's happy path: each `GuardedType` member is a `try` around one delegating call; `GuardedGrips` adds one set lookup; `_LockCheck` is now created on every `execute` (one object per command, not per entity), because the hooks are always set.
- `recover` runs inside `apply`: `lockBroken` clears history and notifies mid-execute; the engine has rolled the failed edit back first, so listeners see the pre-edit document. The retried edit is then recorded after the cleared history (F-2 checks `canUndo` after).
- Damage (E3): `notifyLoaded` is called inside `apply`, before the error rethrows; nothing is recorded.

## Concerns

1. C14's expectation (Task 8) was extended (Deviation 4): please confirm.
2. `undo()`/`redo()` do not go through the expander, so a kit hook failing during an undo's regeneration would still escape `PlanController.undo` (not in this brief).
3. `GuardedTool.onKey` answers `ignored` for a refused Delete, so a host's own Delete handler may also see the key.
4. A load's `hookFailed` diagnostic is not plan-scoped, so the same kit/type failing again in a later plan is not re-reported (by the brief's dedupe design).
5. F-B3b's red relies on the listener recording `persistentCallbacks`; M-F-T5 and M-F-B3b are scheduler-dependent but red as quoted.

## Fix round 1

Commit `51906ea4` fix(plan): surface a load's dry-run error; survive a partial undo (on `3bd18b90`). Files: `lib/src/kits/guard.dart`, `lib/src/controller/plan_controller.dart`, `test/kits/failure_flow_test.dart`, `test/support/box_kit.dart`.

### What changed

1. **Review Important 1, `FailureBoundary.probeLoaded`** (ruling: probe per object, then report). The `catch (_) { return; }` is gone. When `drift()` throws, the boundary looks for objects to blame:
   - On a `KitHookFailure`, it reports it and probes that type's objects, as before.
   - When that finds none, or when the error came from no hook (the planner refusing what a `generate` returned, an engine invariant), the new `_probeAll()` probes every live, unfrozen kit object one by one. Each one that fails gets its diagnostic: the `KitHookFailure` as reported, otherwise `hookFailed` under its kit and type with the error's text.
   - The failing objects are frozen and locked, and the dry run runs again.
   - When no object's probe fails, the error goes to `FlutterError.reportError` (library `jet_cad_2d_plan`, context "during the load's dry run of the plan (no object's probe failed)"), and the load continues.
   - Each round freezes at least one object or ends.
2. **Review Important 2 (and the report's Concern 2, corrected): `PlanController.undo`/`redo`.** A `PartialMutationError` from the replay is caught and handed to `session.boundary.partialMutation`, the same path `execute` takes: one `rollbackFailed` diagnostic, then `_damage` (`notifyLoaded`, which clears history and rebuilds the index through `DocumentLoaded`; locks refreshed; `damaged = true`). It never escapes `undo`/`redo`. I also confirm the reviewer's correction: undo and redo replay and never regenerate, so no kit hook runs there.
3. **Test support.** `Switches.once` and `takes(name, poisoned)` were added to box_kit.dart, plus an `openRegion` switch: a poisoned square's `generate` adds an open region. The engine's planner refuses it with an `ArgumentError`, outside any hook, so there is no `KitHookFailure`. With `once`, only the first call (the dry run) sees it.

### Tests

- **F-13**: a plan with a poisoned square, loaded with `openRegion` on. Its dry run throws an `ArgumentError`, no hook's. After the load, `locked == {broken}`, `frozen == {broken}`, there is one `hookFailed` for `('box', 'box.square')`, and an edit of the other square applies.
- **F-13b**: `openRegion` once. The dry run throws, the probe after it passes, and nothing is locked. `FlutterError.onError` receives exactly one report: an `ArgumentError`, library `jet_cad_2d_plan`.
- **F-14**:
  - Setup: a command whose undo applies the real inverse and then throws `PartialMutationError`.
  - Expected: `c.undo` returns normally, the line is gone, `damaged` is true, there is no undo and no redo, the index no longer finds the line (it found 1 before), and there is one `rollbackFailed`.
- **F-14b** (an addition beyond the ruling, so the redo handler is pinned too): a command whose redo throws after applying. `c.redo` returns normally, `damaged` is true, there is no redo, and there is one `rollbackFailed`.

RED before the fix (`flutter test test/kits/failure_flow_test.dart`):

```
F-13 ... [E]   Expected: Set:[18]  Actual: Set:[]  Which: does not contain <18>   failure_flow_test.dart 403:5
F-13b ... [E]  Expected: an object with length of <1>  Actual: []                failure_flow_test.dart 435:5
F-14 ... [E]   Expected: return normally ... Which: threw PartialMutationError:<Bad state: forced: the undo applied, then failed>   failure_flow_test.dart 464:5
```

GREEN after the fix: `00:00 +13: All tests passed!` (failure_flow_test.dart), then the whole package `00:03 +161: All tests passed!`. F-14b was written after the fix; its RED evidence is M-F14b.

### Mutations

Same driver: each mutation was applied to the committed file, the named test was run, the file was reverted with `git checkout --`, and `git diff --quiet` exited 0 every time.

| Mutation | File | Test | Red line |
|---|---|---|---|
| M-F13a: `if (error is! KitHookFailure) return;` at the head of the catch (back to returning) | guard.dart | F-13 | `Expected: Set:[18] Actual: Set:[]` at :403 |
| M-F13b: the `FlutterError.reportError` call deleted | guard.dart | F-13b | `Expected: an object with length of <1> Actual: []` at :435 |
| M-F14: undo's `on PartialMutationError` clause removed | plan_controller.dart | F-14 | `Which: threw PartialMutationError:<Bad state: forced: the undo applied, then failed>` at :464 |
| M-F14b: redo's clause removed | plan_controller.dart | F-14b | `Which: threw PartialMutationError:<Bad state: forced: the undo applied, then failed>` at :491 |
| M-F4, re-run over the restructured `probeLoaded` | plan_controller.dart | F-4 | `Expected: Set:[18] Actual: Set:[]` at :206 |
| M-F6b against F-14: `notifyLoaded()` deleted in `_damage` | plan_controller.dart | F-14 | `Expected: false Actual: <true>` at :467 (`commands.canUndo`) |

### Gates (packages/jet_cad_2d_plan, after `51906ea4`)

```
dart format .                                        Formatted 63 files (0 changed) in 0.11 seconds.
flutter test                                         00:03 +161: All tests passed!
flutter analyze                                      No issues found! (ran in 3.0s)
dart format --output=none --set-exit-if-changed .    exit 0
```

`git status --short`: clean.

### Not addressed (review Minors, no ruling)

These are left for the controller:
- Minor 1: a refused key answers `ignored`.
- Minor 3: `_encodedState` on the damaged path.
- Minor 5: the session's grip wiring is not pinned at the controller level.
