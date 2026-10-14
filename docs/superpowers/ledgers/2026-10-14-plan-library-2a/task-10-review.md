# Task 10 review (locks), 5229bd1b..8d93ff40

Reviewed in one pass from the review package (all hunks complete, no file re-read). Focused checks outside the diff are named under "Checks run".

### Spec Compliance

- ✅ Spec compliant. Every brief item is present and matches the brief's code:
  - `locks.dart` (diff 305-652): `PlanLocked`, `LockSet` (scan, objects, isEmpty, isLockedObject, covers, addBroken, closure plus container walk), `LockExpander` (install/dispose LIFO with the out-of-order assert), `_LockCheck` (apply, check `touched`, roll back with `result.inverse`, `PartialMutationError` on a throwing rollback, then `PlanLocked`), `LockedGrips`, `base class LockGates extends SelectGates`.
  - Barrel exports `PlanLocked` only (diff 32).
  - Ruling F1: `locks`, `lockExpander`, `lockGates` are `DocumentSession` members, disposed in `session.dispose()` after `page.dispose()` and before `parametric.dispose()` (diff 297-299). The controller owns only `_locked` (diff 81, disposed at 171).
  - Ruling F4 build order holds (diff 222-251): `LockSet.scan`, selection, `LockGates`, outlines, `GripCache(objects: LockedGrips(locks, dispatch), gates: lockGates)`, tool context, `SelectTool(gates: lockGates)`, `ParametricSystem.install`, `LockExpander.install`.
  - `lockBroken` (diff 96-105) does what the spec says: it calls addBroken and `clearHistory`, refreshes `locked`, calls `_refreshFlags` (clearHistory emits nothing), calls `gatesChanged` and notifies.
  - `_open` (diff 145-149) passes `kitLoaded` and `locked`, and sets `_locked.value` after `_session = session`.
  - Ruling R-b: `execute -> bool` (diff 114-125) catches `PlanLocked`, `DanglingReferenceError` and `ArgumentError`, and lets `StateError` (with `PartialMutationError`) through. It was added at the controller's request, so it is not a defect. Task 11 must extend it, not add a second one, as the report says.
  - The `box_kit.dart` fixture is off the origin and turned by 30 degrees (`atSquare`, diff 1416).
  - Every test names its mutation, and L-11 adds M-L11a-d.
- ⚠️ Cannot verify from diff:
  - The `mirror` refusal up front. `SelectGates` has no mirror gate (`jet_cad_2d_flutter/lib/src/select_gates.dart:22-62`: move, rotate, reshape, delete, idleKeys), so up front the spec's "mirror" belongs to Task 12's `PlanGate` enforcement. On commit, a mirror is refused like any other command. The controller should check that Task 12 pins it for a locked selection.
  - "No panel section" belongs to Task 17.
  - Layer change and recolour are refused on commit by construction: any command whose `touched` holds the object or a child is refused. No test in this task issues a layer-change command. L-8's `SetComponentCommand` is the nearest stand-in for a recolour. Task 17 or 18 (`lockedNoLayer`) should pin both.
  - The reported results (121 pass, analyze clean, format exit 0) were not re-run, per the review rules. The mutation list's quoted red lines look consistent with the test line numbers.

### Strengths

- The lock check stacks in the correct place. `_expand` (diff 505-509) wraps what the parametric expander returns, so the parametric `_setsParametric`/`owns` tests still see the caller's original command. I checked this against `parametric_system.dart:820-842`. With nothing locked it returns `inner` unwrapped: no allocation, no walk.
- The rollback is safe against the parametric system's state. `ParametricSystem` keeps no state between commands (it re-surveys every time, `parametric_system.dart:820-831`). It is also the same throw-after-restore pattern as the engine's own regeneration rollback, so applying `result.inverse` directly and throwing before `recordExecute` (`undo.dart:187-203`) leaves history, `stateId` and redo untouched. L-2 pins all three.
- The closure-plus-walk split is correct for removal. After a remove, the removed handle has no owner left, and L-3 isolates this with M-L3b (red only at the `RemoveEntityCommand` line).
- L-1 (Review Focus 1) is not degenerate on the manifest. It reads the entry through a controller loaded with the kit, but that load keeps the manifest as read (`_readManifest` only checks it, `plan_controller.dart:422-433`). `manifestToWrite` writes an unloaded kit's entry from the read manifest (`manifest.dart:89-101`). So if `b.save()` dropped the entry, `kits['box']` would be null and the test would go red. The components are compared byte for byte per type id, for both the square's type and `jetcad.symbol`.
- The report is honest:
  - M-L6f's actual red (`PlanLocked` escaping `deleteSelection`) is quoted rather than the brief's prediction.
  - The self-found weakness in L-11, which first moved the square to its own placement, was fixed in 8d93ff40.
  - The deviations in L-5 and L-8 are explained and keep every assertion.
- `LockGates` caches a `bool`, so its getters allocate nothing, as `select_gates.dart:14-21` requires. Removing a listener after `SelectionController.dispose()` is allowed, because `ChangeNotifier.removeListener` permits it.

### Issues

#### Critical (Must Fix)

None.

#### Important (Should Fix)

None.

#### Minor (Nice to Have)

1. `locks_test.dart:1020-1044` (L-10), plan-mandated. The title says "a key whose target **or chain** is locked", but no test selects a key with a non-empty chain. Deleting the chain loop in `LockGates._recompute` (diff 626-630) leaves the whole suite green. Today's select tool resolves every hit and band to a root-level key (`selection.dart:54-73`, `select_tool.dart:575-598`), so the branch is unreachable in this task. The brief defers it to Task 12's PM-9/PM-10. Either add one `SelectionKey` with `chain: [lockedInstance]` to L-10, or retitle the test.
2. `locks.dart` diff 390, plan-mandated. `_locksUnknown(kit, loaded) => true` is a constant function with two unused parameters, kept only as the seam for M-L4. It is harmless, but it reads as dead logic. A one-line comment naming M-L4 as the reason would help.
3. The lock set is computed at load and changed only by `lockBroken`. A new `InstanceNode` of a guarded definition (from a duplicate or paste of a locked instance, if a later task offers one) passes the commit check, because its parent is the root, and it is never locked or listed in `locked`. It does not change any saved object, so this is a spec boundary rather than a breach, but Task 13 or 14 should know.
4. Two paths let `PlanLocked` escape a `bool`-answering API instead of being turned into `false`:
   - `PlanController.deleteSelection` (Task 8's, not in this diff) calls the select tool directly. Today the gates make that unreachable, as the report notes under Concerns.
   - A locked object nested inside a plain group: the select tool picks the topmost group, the gates stay open, and deleting it touches the locked child at commit.

   The plan library has no grouping tool, so the second path needs an imported plan. Worth routing through `execute` or catching in Task 11 or 15, together with the lock hint.

### Checks run

- Risk: the dispatcher reads members of `_LockCheck` that are not forwarded. Checked: `DraftCommand` has only `capability`, `capabilities`, `label` and `apply` (`command.dart:121-137`), and all are forwarded. `_require` reads `capabilities` before apply, and `CommandApplied` reads `label`/`capability` after it (`undo.dart:187-203`).
- Risk: a rollback leaves the parametric caches stale. Checked: `ParametricSystem._expand` and `ParametricEdit` keep no state between commands (`parametric_system.dart:820-883`).
- Risk: L-1's manifest assertion is degenerate because load rewrites the manifest. Checked `manifestToWrite`, `encodePlan` and `_readManifest`: it is not degenerate.
- Risk: `gatesChanged` leaves stale grips after `lockBroken`. Checked: it only resets `hot` and notifies (`grip_cache.dart:308-311`). The cached grips can stay, but every grip role is gated by move, rotate and reshape, which `LockGates` shuts, and `LockedGrips.drag` returns null. No live path remains.
- Risk: the kit id parsing locks a non-kit symbol. Checked `kitOfKey`/`isKitId` (`kit_ids.dart`): a valid symbol key always starts with a kit id.

### Assessment

**Task quality:** Approved

**Reasoning:**
- The implementation follows the brief and rulings F1, F4 and R-b exactly.
- The apply-check-rollback is correctly stacked outside the parametric expander, and safe given that the parametric system keeps no state.
- Each named mutation is evidenced with the red line it produced.
- The remaining gaps are an untested chain branch and refusal paths owned by Tasks 8, 11 and 12.
