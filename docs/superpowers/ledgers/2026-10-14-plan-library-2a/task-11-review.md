# Task 11 review: the failure boundary (2a P4)

BASE 8d93ff40, HEAD 3bd18b90 (5b4cff41 feat, 3bd18b90 test). I read the review package once, in four passes (diff lines 1-900, 900-1600, 1600-2300, 2300-3135). I read the brief, the global constraints, the report, and spec P4 (`docs/superpowers/specs/2026-10-14-plan-library-design-mode-design.md:515-588`). I re-ran no tests.

### Spec Compliance

- ✅ **Spec compliant.** I checked each row of the P4 "failure boundary" table, the "Undo and a lock" paragraph and the controller's carries against the diff:
  - **ParametricType hooks → KitHookFailure.** `GuardedType` covers all thirteen members (guard.dart, diff 895-1048). Each member is one `try` around one delegating call. Each has `on KitHookFailure { rethrow; }`, so a nested failure keeps its own attribution. Registration goes through `registerInto(catalog, guard: const PlanTypeGuard())` (plan_controller.dart, diff 219).
  - **Probe, freeze, lock, clear history, retry once, refuse on a second failure.**
    - `_LockCheck._first` (locks.dart, diff 1651-1660) catches the failure, then calls `onHookFailure`.
    - The recovery is `FailureBoundary.recover`, which probes, then calls `_freeze` (`frozen.addAll` + `lockBroken`, which clears the history; guard.dart:613-628, diff 1459-1488).
    - It re-expands `original` and applies it once more. A second failure propagates, and `execute` turns it into `false` plus one diagnostic (diff 336-347).
    - The retry is skipped when the probe froze nothing (F-3).
  - **Load-time check.**
    - `reportUnreadable` runs first, then `probeLoaded` (the `drift()` loop), both at the end of `_open` (diff 418-422).
    - This follows the brief's plan decision. The spec's literal wording is "probes every kit object's reach and references". The brief replaced that with a `drift()` dry run that covers more hooks, and gave the reason (O(n²)).
  - **Failed rollback.**
    - `_LockCheck.apply` reports `PartialMutationError` to `onPartialMutation` before rethrowing (diff 1638-1645).
    - That handler is `FailureBoundary.partialMutation`: one `rollbackFailed` diagnostic, then `_damage` (`notifyLoaded`, then `damaged = true`; diff 349-358, 1543-1550).
    - `save` reads a damaged plan back and throws `PlanFormatException(damagedUnsavable)` with a diagnostic (diff 245-263).
    - `damaged` resets per document (diff 383).
  - **Unreadable component (E4).** It is kept raw, locked and frozen, with one `componentUnreadable` diagnostic per kit and type (diff 1512-1539). This closes the Task 1 carry ("a group whose only component was kept raw … Task 11 must lock it"), and F-5 pins it.
  - **Grips.** `GuardedGrips` gives an object no grips, a null `drag`, no preview and `movable == false` once one of its calls has thrown. The session wraps the dispatch in it, inside `LockedGrips` (session.dart:50).
  - **Attachment provider.** `guardAttachment` answers null and reports the failure.
  - **Tool factory.** `guardFactory` disables the tool (`isToolDisabled`; `selectTool` answers false).
  - **Tool event.** The error becomes a diagnostic, the tool is cancelled, and `onFailed` arms `plan.select`.
  - **Tool painting.** The paint is skipped, the diagnostic goes through `addAfterFrame`, and the cancel comes after the frame.
  - **Section builder.** `KitSectionBoundary` shows the "section failed" box; a widget that fails while building shows `ErrorWidget` in its place only.
  - **One KitDiagnostic per subject and code.** `DiagnosticsLog._seen` is keyed by (kitId, subject, code), and `clearPlanScoped` forgets the plan-scoped keys (diff 83-171).
  - **"Undo and a lock".** History is cleared through `lockBroken` whenever the boundary freezes something. Undo and redo replay and never regenerate (`parametric_system.dart:887-888`), so no kit hook runs on undo.
  - **Controller carries:**
    - `execute()` is extended, not duplicated (diff 325-340).
    - Freezing happens together with locking: `_freeze` is the boundary's only lock path, and `lockBroken` is `@internal`; I checked its call sites, and the only lib caller is `plan_controller.dart:500`.
    - `deleteSelection` answers false on `PlanLocked`, `DanglingReferenceError` and `KitHookFailure` (diff 487-503; F-11).
    - A swap whose kit factories or disposals throw still completes (session.dart `_disposeGuarded`, `SharedCache.dispose(onError:)`, `GuardedTool.dispose`; F-10).
  - **Every test names its mutation.** The report's table lists 59 mutation runs, each red, including the extra ones for F-10, F-11, F-12 and M-F2-retry.
  - **Extras beyond the brief, all justified.**
    - Files: `shared_cache.dart`, `guarded_swap_test.dart`, the new `throwing_kit.dart` hooks, and C14 extended.
    - Why each is justified: the Task 8 carry (swap completion), the Task 6 carry (throwing getters and dispose), and the controller's C14 ruling. The C14 change only grows the assertion: one entry is appended and nothing is removed (diff 1747-1756).
  - **Deviations 1-3 (fixtures) and 7-10.** These are named in the report. I checked them in the diff, and none weakens an assertion.
- ⚠️ **Cannot verify from diff:**
  - **The spec row "a drag in flight is cancelled".** It is implemented as `drag` answering null from then on. Whether the select tool's grip drag then ends cleanly (no stale preview, no dangling phase) depends on `jet_cad_2d_flutter`'s grip-drag code, which is outside the diff. The controller should check that this matches Task 15's canvas expectations.
  - **The "Allocation" plan decision.** `GuardedType` and the paint paths add no allocation on the happy path (by reading). `_LockCheck` is now created on every `execute`, since the hooks are always set: one object per command, not per entity. The report quotes Step 7's `query_allocation_test.dart` as green. The plan library's own paint-allocation gate is Task 15's.

### Strengths

- **`GuardedType` is exactly the shape the risk section asks for:**
  - `implements`, not `extends`, so a new engine member is a compile error;
  - one `try` per member, with `Error.throwWithStackTrace` keeping the kit's stack.
- **The F-G9 strengthening is a real mutation-testing catch** (Deviation 5). M-F-G9b survived the brief's fixture because the place trigger asks `placeBox` before the reader's `generate`. The added `drift()` assertion is the right lever (diff 2931-2935).
- **The retry is pinned by its own extra mutant (M-F2-retry).** Without the re-expansion, `ParametricEdit applies once` fires. That shows the one-undo-step retry is load-bearing, not incidental.
- **`_saveUnchecked` marks the save point only after encoding** (Deviation 10). This fixes a latent Task 8 bug where a failed encode left a wrong save point.
- **`DiagnosticsLog` is tidy:**
  - `_pending` sits under `_current`, so a synchronous `add` folds an after-frame entry in instead of losing it;
  - the post-frame publish is guarded by `_disposed`.
- **The swap-completion work fixes the Task 8 carry at its root** (F-10, four mutants):
  - `GuardedTool.dispose`, `_disposeGuarded`, and `SharedCache` values carrying their kit ids;
  - the controller's dispose order keeps `_diagnostics` alive until after the session's kit products are disposed (plan_controller.dart `dispose`: session first, then `_diagnostics.dispose()`).

### Issues

#### Critical (Must Fix)

None.

#### Important (Should Fix)

1. **`FailureBoundary.probeLoaded` swallows every non-kit error silently (plan-mandated).**
   - Where: `packages/jet_cad_2d_plan/lib/src/kits/guard.dart:651`, `} catch (_) { return; }` (diff 1504-1506).
   - What happens: an engine error thrown by the load's `drift()`, such as a `StateError` from an engine invariant, is dropped. Nothing is reported to `diagnostics`, nothing to `FlutterError`, nothing is logged, and the plan opens as if the dry run had passed.
   - The brief mandates this body ("the engine's own reports cover that"). But a thrown error is not one of the engine's reports: `ParametricSystem.diagnostics()` returns findings, it does not replay a throw. So the first evidence of an engine fault at load is lost. The rubric classes a swallowed error as Important; the human decides.
   - Fix: keep the load non-fatal, but surface the error, for example with `FlutterError.reportError(FlutterErrorDetails(exception: e, stack: s, library: 'jet_cad_2d_plan', context: ErrorDescription('the load\'s dry run')))`. Name a mutation that deletes the report.

#### Minor (Nice to Have)

1. **A refused key event answers `ignored`.**
   - Where: `lib/src/kits/guard.dart:423`.
   - Problem: when a refusal (`PlanLocked` or `DanglingReferenceError`) is caught, the select tool's Delete has in fact consumed and refused the key, yet `onKey` answers `KeyEventResult.ignored`. The key then bubbles to a host's or Task 16's Delete shortcut, which runs `deleteSelection` again (a second refusal, a second hint set). This is the implementer's Concern 3; it is real but harmless today.
   - Fix: have `_failed` say whether the error was a refusal, and answer `handled` in that case. A kit failure keeps `ignored`.
2. **The lock hint behaves differently on the two commit paths (plan-mandated).** A `DanglingReferenceError` sets the lock hint through `GuardedTool._failed` (guard.dart:292), but not through `PlanController.execute` (plan_controller.dart:429). F-9 even pins "no lock hint" there. So the same refusal shows the hint from a tool gesture but not from a panel commit. Both behaviours come from the brief; flag it for Task 15 and Task 17, which consume the hint.
3. **The `_encodedState` fix is incomplete on the damaged path.** In the damaged path of `save()` (plan_controller.dart:278-304), `_saveUnchecked()` sets `_encodedState` after a successful encode, and only then does the read-back fail and throw. A later `markSaved()` would mark a state that was never returned as saved. Fix: in the damaged branch, encode without touching `_encodedState`, and set it only after the decode passes.
4. **The report's Concern 2 is factually off.** It says undo and redo "would still escape" on a kit hook failure, but undo and redo replay `ParametricReplay` and never regenerate (`packages/jet_cad_2d/lib/src/parametric/parametric_system.dart:887-888`), so no kit hook runs. The real remaining gap is different: an E3 `PartialMutationError` raised during a replay (the `CompoundCommand.apply` site) escapes `PlanController.undo`/`redo` without `_damage`, so the plan is not marked damaged, and `save` does not read it back. It is engine-only and improbable, and outside this brief; record it as a follow-up.
5. **The session's grip wiring is not pinned at the controller level.** `GuardedGrips` is unit-tested (F-B1), but no test fails if `session.dart:50` passes `dispatch` bare. The throwing kit already has `gripsOf` and `gripsDrag` switches; a controller-level test (one diagnostic, no grips for that object) would pin the wiring. The same holds for `addTool`'s `_guard` (no generic tools until Task 12).
6. **`toolFor` now returns the unwrapped inner tool** (Deviation 8, plan_controller.dart, diff 524-532). This is `@internal`, but a later caller (Task 12 or Task 15) that drives events through `toolFor(id)` would bypass the guard. Its doc comment says "without the guard"; Tasks 12 and 15 should know it.
7. **Inner `cancel` runs twice after a kit tool's event failure.** `_failed` calls `_cancelInner`, then `onFailed` → `selectTool(plan.select)` → `ToolController.activate`, which cancels the outgoing tool again. That is harmless for idempotent cancels; noted only because F-T1's rig counts exactly one.

### Assessment

**Task quality:** Needs fixes. Important 1 is the only item that blocks approval, and it is plan-mandated: the human may accept the brief's body as it stands.

**Reasoning:** Every row of the P4 failure-boundary table is implemented as the brief specifies, with real mutation evidence (59 red runs, including two catches the brief's own fixtures missed). Review Focus 2 (F-2) holds: the disc's edit is refused zero times, both kits' working objects regenerate, and the broken square keeps its geometry. The one Important finding is a load-time `catch (_)` that the brief itself prescribes and that hides any engine error raised during the load's dry run.
