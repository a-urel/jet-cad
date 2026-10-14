# Final whole-branch review: sub-project 2a (plan library, design mode)

- Branch `feat/plan-library-2a`, BASE `60839065`, HEAD `2fa4cc6f` (47 commits, 248 files).
- Reviewer: Opus, read-only on the checkout, no subagents. Done in passes, per area: the engine seams (`packages/jet_cad_2d/lib`, whole diff), the kit contract (`packages/jet_cad_2d_kit/lib`, whole diff), then `packages/jet_cad_2d_plan/lib`. In the plan package I read in full: controller/, kits/, attach/, file/, the tools, the canvas, the colour row and the shortcuts. I read the rest in part: the property panel's commit and guard paths, the layer, page and editor commit sites, the symbol loader and the locale scope. I sampled the tests (covariance, failure flow, lock-recolour, box kit) and wrote two scratch probes. Both live outside the repository, under the session scratchpad.
- Requirements read: the spec (P1-P5, E), the plan's Global Constraints, Review Focus and Shared interfaces, and the whole ledger.

## Verification run (this review, not quoted from reports)

| Gate | Result |
|---|---|
| `packages/jet_cad_2d_plan`: `flutter test` | `+723: All tests passed!`, exit 0 |
| `packages/jet_cad_2d_plan`: `flutter analyze` | `No issues found!`, exit 0 |
| `packages/jet_cad_2d_kit`: `flutter test` | `+314: All tests passed!`, exit 0 |
| `packages/jet_cad_2d`: `dart test test/parametric test/document test/codec` | `+693: All tests passed!`, exit 0 |
| `git diff 60839065..2fa4cc6f --stat` on `jet_cad_floor_plan`, `jet_cad_2d_flutter`, `jet_cad_restaurant_symbols`, `jet_cad_2d_gpu`, `apps/` | empty |
| `git status --short` after the probes | clean |

Not run here: the engine's full suite (it has standing environmental failures), the GPU package's gates, and the format gates.

## Strengths

- **The stack order is right, and it is the same on every path.**
  - `GuardedType` sits innermost, one `try` per hook (guard.dart:42-195).
  - `ParametricSystem` holds the expander slot. `LockExpander` stacks outermost (session.dart:86-88).
  - So a lock check sees the whole regeneration's `touched` (locks.dart:264-278).
  - A recovered failure re-expands the *original* command, so the retry carries the new frozen predicate (locks.dart:253-262).
  - Dispose is LIFO, with an assert (locks.dart:184-191, session.dart:278-279).
  - Tools, grips and panels all commit through the dispatcher, so the guard and the lock cover every path, not only `controller.execute`.
- **Per-document lifetimes are clean.**
  - `DocumentSession` owns every per-document object.
  - At a swap, the order is: kit products disposed, each dispose guarded (session.dart:219-254); the old session detached; the new one opened.
  - The rest goes after the frame (plan_controller.dart:704-736), and the post-frame drop cannot double-dispose (`_dropped.remove`).
  - `KitServices` reads the *current* session on every call, and each `SharedCache` belongs to one document and refuses use after dispose.
  - Task 8's "half-swapped by a throwing factory" carry is resolved: every factory goes through `guardFactory` or `PlanAttachmentRegistry.add`.
- **Covariance is handled as the spec asks.**
  - `PlanType` keeps every member typed by `T` private behind erased operations, and `TypeGuard.wrap<T>` keeps `T` through registration (plan_type.dart:74-81).
  - `PlanToolSettings.fieldsOf` passes a `void Function(Object)` where `void Function(S)` is expected, which is sound.
  - C-covariance (covariance_test.dart) runs two kits with different `T`s through every erased operation.
- **The engine seams are backward compatible for existing users.**
  - E4 is opt-in (`keepUnreadableComponents` defaults to false, json_codec.dart:56-57).
  - `PartialMutationError` is a `StateError` and keeps the message.
  - `isFrozen: null` takes the old code paths (`_naming`'s extra test is skipped).
  - E1 is additive.
  - The `toJson` reorder only changes output in the raw-and-registered collision that E4 creates, which `jet_cad_floor_plan` never produces.
  - The other packages are byte-identical.
- **Hot paths.**
  - The gates are a cached `bool` plus one closure read (plan_select_gates.dart, locks.dart:323-370).
  - `GuardedTool`'s paint guards are try/catch with no allocation.
  - `LockSet.covers` returns early when the set is empty.
  - `_LockCheck` costs one object per `execute`, which is the edit path, not the frame path.
  - The canvas paint-allocation invariant is in place.

## Issues

### Critical

None.

### Important

**I1. A write of a type's own component on a frozen (broken) object escapes `execute` as a plain `StateError`. It is never refused as `PlanLocked`.**

- Where:
  - packages/jet_cad_2d/lib/src/parametric/regeneration.dart:984-990 (`_written`'s refusal inside `_run`);
  - packages/jet_cad_2d_plan/lib/src/kits/locks.dart:240-262 (`_LockCheck.apply` / `_first`);
  - packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart:562-579 (`execute`);
  - packages/jet_cad_2d_plan/lib/src/kits/guard.dart:290-310 (`GuardedTool._failed`).
- What happens:
  - A broken object is frozen (E2) *and* locked.
  - A `SetComponentCommand<T>` on it never reaches the lock check. The parametric edit inside `_LockCheck` hits E2's "written on a group that is not live" refusal first, undoes, and throws a bare `StateError`.
  - `_LockCheck` catches only `KitHookFailure` and `PartialMutationError`, and `execute` catches neither `StateError` nor anything that wraps it.
- Verified by a scratch probe (box kit, a poisoned square, `reach` switched on):
  - one edit freezes and locks the square;
  - then `c.execute(SetComponentCommand<SquareParams>(broken, …))` threw `StateError: "Set component": box.square written on 12, which is not a live root-level group…`;
  - it did not answer `false`, and `lockHint` stayed false.
  - The ledger's P-lock-recolour test does not see this: it calls `lockBroken`, which locks but does not freeze.
- Who hits it:
  - Today's UI does not reach it: the panel and the colour row skip locked objects.
  - The paths that do reach it:
    - **a kit tool:** `GuardedTool` reports it as the *tool's* `hookFailed` and disarms the tool, which is misattributed;
    - **a kit grip drag through `plan.select`:** a generic `GuardedTool` rethrows it from the pointer handler, an uncaught exception;
    - **a host's `execute`.**
  - These are exactly sub-project 3's wall joins and wall-endpoint grips, which edit a neighbour's parameters.
- Fix:
  - Make E2's refusal typed, as E3 did: for example `final class FrozenWriteError extends StateError` (or a non-live-write error) carrying `handle`. The engine seams are unreleased in this branch.
  - In `_LockCheck.apply`, map it to `PlanLocked` when `locks.covers(target, error.handle)`.
  - Test: the probe's scenario, expecting `execute` to answer `false` with `lockHint` true, and a kit tool committing the same write to give a refusal (hint, no diagnostic).
  - Name the mutation: drop the mapping.

**I2. A kit `generate` that the engine's planner refuses blocks that object, and every neighbour whose regeneration includes it, forever and silently.**

- Where:
  - packages/jet_cad_2d_plan/lib/src/kits/locks.dart:253-262: `_first` recovers only from `KitHookFailure`;
  - plan_controller.dart:573 swallows the `ArgumentError` as `false`;
  - guard.dart:303-307: a generic tool rethrows it.
- What happens:
  - The planner refuses the output (an open region, for example) outside any hook, as an `ArgumentError`.
  - At load, `probeLoaded`'s fix-round-1 path (`_probeAll`) freezes and reports such an object.
  - At edit time nothing does.
- Verified by a scratch probe (box kit, `openRegion` switched on for a poisoned square):
  - its own edit answered `false` twice;
  - an overlapping healthy neighbour's edit answered `false`;
  - the end state was `locked={}`, `frozen={}`, `diagnostics=[]`.
  - Through `plan.select`, the same refusal would be rethrown from the drag.
- Why it matters: this breaks spec P4's promise, "one broken object blocks one edit, once, and never its neighbours afterwards", for the failure class most likely in sub-project 3, where wall and room generation can produce degenerate output.
- Fix:
  - In `_first`, on an error from the expanded edit that is not `PlanLocked`, `PartialMutationError`, `DanglingReferenceError`, `PermissionDeniedError` or `GeneratedGeometryError`, call a boundary hook.
  - The hook runs `_probeAll` (guard.dart:675-699; it already attributes non-hook errors), freezes what fails, and retries once. If nothing fails the probe, rethrow: it is a true refusal.
  - Alternatively, an engine-typed "generated output refused" error naming the object would avoid the O(objects) probe on this failure path.
  - Test: the probe's scenario, expecting the neighbour's edit to succeed after the first refusal, the bad square locked, and one `hookFailed`.

**I3. The Task 13 ruling assigned to this final fix wave is not done.**

- Where: plan_controller.dart:1046-1080 (`retrySymbols` / `_loadSymbols`) and diagnostics_log.dart.
- The ruling: a successful retry of a library source must clear that source's earlier `libraryUnreadable` (and `libraryKitMismatch`) diagnostics.
- Today `_loadSymbols` only adds diagnostics. `DiagnosticsLog` has no removal except `clearPlanScoped`, and its `_seen` set would still dedupe a later failure of the same source, so a fixed failure stays on the bar.
- Fix:
  - Add `DiagnosticsLog.removeWhere(bool Function(KitDiagnostic))`, which also drops the matching `_seen` keys.
  - In `_loadSymbols`, before adding `load.diagnostics`, remove the library-scoped codes (`libraryUnreadable`, `libraryKitMismatch`, `symbolDuplicate`), so the current load's set replaces them.
  - Test: fail every source, then retry successfully; no `libraryUnreadable` remains. Mutation: skip the removal.

### Minor

**M1. `PartialMutationError` and `GeneratedGeometryError` leave `execute`, and one commit site does not catch them.**

- plan_controller.dart:562-579. The layer panel, page panel, layer picker and property panel each wrap `execute` in `on StateError` (plan_layer_panel.dart:186-191, plan_page_panel.dart:162-169, layer_picker.dart:196-201, plan_property_panel.dart:445). `ColourRow._choose` does not (colour_row.dart:133), so a damaged-plan rollback raises out of a tap.
- `undo()` and `redo()` already swallow `PartialMutationError` after `boundary.partialMutation`.
- Fix:
  - Make `execute` return `false` for a `PartialMutationError`; the boundary has already handled it inside `_LockCheck`.
  - Add `on GeneratedGeometryError`, 06 D6's refusal, which is an `Exception`.
  - Then the callers' `on StateError` wrappers can go.

**M2. `DanglingReferenceError` sets the lock hint in `GuardedTool` (guard.dart:291-295) but not in `execute` (plan_controller.dart:569-570).**

Task 11 deferred this. Pick one behaviour.

**M3. `save()` on a damaged plan.**

- plan_controller.dart:416-444.
- `_saveUnchecked` sets `_encodedState` before the read-back, so a `save()` that throws `damagedUnsavable` has still moved what `markSaved()` would mark. This is Task 11's deferred item.
- The read-back runs `decodePlan` with E4's `keepUnreadableComponents: true`, so a component that no longer reads passes the check silently.
- Fix:
  - Set `_encodedState` only after the check.
  - Fail the check when the read-back's diagnostics hold `component.unreadable`.

**M4. Some kit hooks are still called raw.**

- At construction: `type.parametric.contributesPlace` and `readsPlaces` in `validateKitSet` (kit_set.dart:92-93). One that throws escapes `PlanController(...)` as a raw error, not a `KitSetError`.
- In builds: `parametric.editCapability` in `_editable` (plan_property_panel.dart:421) and in `colourRowBlocked` (colour_row.dart:91). Task 17 deferred this.
- Fix: guard both and report a `hookFailed`, or add a `KitProblem`.

**M5. `lockHint` is a public, writable `ValueNotifier` (plan_controller.dart:537).**

Expose a `ValueListenable<bool>` and keep the setter `@internal`.

**M6. `PlanMoveResolver` keeps a replaced plan's data until the next drag.**

- move_resolver.dart:39-43: `_last` (an `Attachment` whose `token` is a provider's per-document data) and `_boxes`.
- This defeats the `WeakReference` intent.
- Fix: clear both in `_sync` when the document is not the live one, or have `_replace` call a `reset()`.

**M7. `hookFailed` deduplication outlives a plan.**

- diagnostics_log.dart:14-20, 35: `hookFailed` is not plan-scoped.
- A type that fails in plan A and again in plan B freezes and locks B's object with no new diagnostic. The bar shows plan A's message.
- Consider adding `hookFailed` of a *type* (subject `<kit>.<type>`) to `planScoped`.

**M8. `planTypeOf` and `planToolOf` re-scan the kit set (kit_lookup.dart).**

`KitSet.typeOf` already holds a map, and the panel asks once per field per build. Use `c.kits.typeOf`, and add a `toolOf` beside it.

## Deferred-minor triage (progress.md)

**Must fix before merge:**
- **Task 13 ruling:** clear `libraryUnreadable` on a successful retry. It was ruled for this wave. This is I3.

**Should fix in the same wave** (cheap; each is a contract, a persisted format or a published engine doc, and each costs more after release):
- **Task 7, `usedKitsIn` (manifest.dart:63-84):**
  - it excludes `jetcad` but not the reserved `plan`, so a `plan.*` component type would write `plan` into the persisted manifest, and the next load would report it as a missing kit;
  - `LockSet._unknownKit` (locks.dart:74) already excludes both;
  - fix: exclude `reservedKitIds`.
- **Task 3, `ChoiceProperty`:**
  - it accepts value segments containing `.` or `:` (properties.dart:176-183), which makes word ids ambiguous (`property:<owner>.<spec>.<value>`);
  - refusing them now is free; after kits ship it is a breaking change.
- **Task 2, `probe`'s doc (parametric_system.dart:732-733):**
  - it says a healthy contributor's `placeBox` "runs once", which is untrue after a re-survey;
  - this is the published engine API's doc, so correct the wording.
- **Task 4, contract docs kit authors read:**
  - `AttachmentQuery.pointer` is a mutable `Vector2` that the registry reuses across providers in one `attach` call (attachment_registry.dart:60-66), so a provider that mutates it moves the query the next provider sees. Document "do not mutate" (or hand out copies).
  - `PlanType.properties`' doc should repeat that a spec's function members fail through `PlanType<Component>`.
- **Task 16, `idleKeys`:**
  - removing a `PlanShortcuts(shortcuts: false)` leaves the select gates' `idleKeys` false (plan_shortcuts.dart:87-91), so Delete and Escape stay dead in the canvas;
  - fix: one line in `dispose`, `selectGates.idleKeys = true` (guarded by `!isDisposed`).
- **Task 17 review minor 4, `NumberProperty` no-op step:**
  - a value that rounds back to the stored one (2.3, typed 2.31) records an empty undo step;
  - fix: in `_write`, compare `field.commit!(input)` with the current component before executing.
- **Task 11, damaged save:** `_encodedState` is set before the read-back. This is M3.
- **Task 1, engine comment:** the 115-column comment line at commands.dart:958. It is cosmetic, but it sits in the engine you touch anyway.

**Resolved on the branch** (no action):
- Task 8: the half-swap by a throwing factory (guarded factories).
- Task 9: the locale push to a disposed controller (`isDisposed` check, locale_scope.dart:32).
- Task 10 and 12: `PlanLocked` escaping `deleteSelection` (plan_controller.dart:899-901).
- Task 12: `execute` and `PermissionDeniedError` (now caught).
- Task 15 minor 6: kit letters are validated against `^[A-Z]$` (tool_letters.dart:82-86).
- Task 20 minor 1: RV6 on a controller swap (e1e577d5).

**Can stay deferred** (test-breadth, fixture or doc polish; none changes behaviour a user or kit sees):
- Task 1: the `typeIdOf` raw-only test; the `toJson` reorder note.
- Task 2: the M-E2p claim; the frozen-delete and orphan tests; probe's walk repetition.
- Task 3: the PS11 astral fixture; `-0.0`. Display only: `panelNumberText` shows "-0.0", and stored `==` is unaffected.
- Task 4: a tool without settings; the enabled-after-read test; the duplicate `propertyIds`; `settings!`.
- Task 5: both items.
- Task 6: all items.
- Task 7: the rest (`kitOf` duplication, `decodePlan` dropping the stack, the save-no-mutate test, semver on web).
- Task 8: dispose without arming select. The canvas's RV6 withdrawal covers the usual order. It is still a one-liner if touched.
- Task 8: the refused load settles into the old plan. This is ported behaviour, and Review Focus 4 wants it.
- Task 8: fresh diagnostics per load.
- Task 9: the rest.
- Task 10: L-10; `_locksUnknown`; a duplicated locked instance (no copy path in 2a).
- Task 11: the rest except `_encodedState`. The DanglingReferenceError hint is M2.
- Task 12: all items.
- Task 13: the S-15 and mutation-name items.
- Task 14: all items. Fix the stale `WallFaces` doc in symbol_box.dart:134 in passing.
- Task 15: the hint window; the old controller's `snappingAllowed` after a swap. Revisit with 2b's multi-view hosts.
- Task 16: the one-frame F3 lag; the untested chords.
- Task 17: the rest (the `editCapability` raw read is M4).
- Task 18: all items.
- Task 19: all items. "Import not under the one-flow guard" is benign: export works on a copy and answers null when the plan is replaced.
- Task 20 and 21: the rest.

## Recommendations (sub-project 3 readiness)

The contract supports the architecture kit:
- walls, rooms, separators, dimensions and boxes are `ParametricType`s with references and place hooks;
- tools get settings and snap;
- grips get the camera, the index and `objectSnap`;
- `shared` with `Disposable` replaces `WallBands`, `WallFaces` and `RoomInputs`, as spec P1 says;
- the wall-face provider fits `AttachmentProvider`.

Before kit 3 builds on it:
1. **Fix I1 and I2.** Wall joins and wall-endpoint grips edit neighbours' parameters (I1). Wall and room generation is where degenerate, planner-refused output appears (I2).
2. **`PlanServices` lacks what kit tools will need:**
   - `isLocked(Handle)`, so a wall tool neither joins nor snaps to a locked wall;
   - `allows(PlanGate)`, so an opening tool's flip and turn keys respect `mirror` and `rotate`, as `plan.symbol` does;
   - a `Listenable` for its own tool settings, so a ghost re-renders on a panel change.
   These are additions to an interface only the plan library implements, so they do not break kits, but test fakes of `PlanServices` will need updating. Adding them now avoids churn.
3. **`PropertySectionBuilder<T>` receives no handle and no services** (plan_type.dart:24-25). A wall section that lists its openings, or a room section that reads neighbours, cannot be written. Changing a typedef later breaks every kit. Consider a context object now (for example `PlanSectionContext { Handle object; PlanServices services; }`). The spec fixes today's signature, so this is the human's call.
4. **Dependency floors.** `jet_cad_2d: ^0.7.2` in the kit's and the plan's pubspecs predates E1-E4. The plan says the wave raises them; make sure it does before any publish.

## Declined to judge

- **The barrel's plan-file plumbing** (`decodePlan` with a `register` callback, `manifestToWrite`, `checkManifest`, `usedKits`, `ensureManifest`) is a wider permanent surface than P2 needs. It is plan-mandated (Tasks 7 and 20, F6), so it is the human's call.
- **Multiple-selection property editing** is out of scope by spec P3.
- **Allocation per pointer move in `plan.symbol` and the move resolver** (`AttachmentQuery`, `Expando` writes, `_withoutKeep`) is outside the paint and query paths that the CLAUDE.md invariant covers.
- **Ported tests that name no mutation** are covered by the Task 20 ruling.
- **RV6's `selectTool` working without a canvas** is a deliberate host-API difference, listed for the human (A14).
- **E2's `diagnostics()` misplaced-component pass ignores the frozen predicate** by documented design (parametric_system.dart:325-326).
- **The `toJson` raw-before-registered reorder** is accepted: it only bites in the E4 collision, which `jet_cad_floor_plan` never produces.
- **Not done here:** the full engine suite, the GPU package's gates, the format gates, and a fresh run of the canvas paint-allocation invariant on its own. Task 21 quotes its runs; this review's full plan-package run includes it.

## Assessment

**Ready to merge: after fixes.** I1, I2 and I3, plus the "should fix" triage list.

**Reasoning.** The architecture is sound and matches the spec:
- the stack order;
- the session lifetimes;
- the erased operations for covariance;
- the opt-in engine seams;
- allocation-free gates;
- every gate green, rerun here.

Two cross-task gaps sit between E2's frozen semantics, the lock expander and the failure boundary:
- a write to a frozen object is not refused as a lock (I1);
- planner-refused kit output is not frozen at edit time (I2).

Both stay quiet in 2a's UI, but they are the first things the architecture kit's neighbour-editing tools and grips will hit. I3 is a ruling this wave owes.
