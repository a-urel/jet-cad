# Final fix wave re-review, sub-project 2a

Scoped re-review of `2fa4cc6f..07128eb1` (7 commits) against final-review.md's I1, I2, I3 and the
eight "should fix" triage items, with the controller's rulings. Read-only, no subagents, no tests
re-run (no doubt arose that the quoted runs and the diff did not answer). HEAD verified `07128eb1`,
working tree clean.

## Finding Verdicts

- **I1: a write of a frozen object's own component escapes `execute` as a plain `StateError`.** ADDRESSED.
  - Engine: `NonLiveWriteError extends StateError`, carrying `handle` and `typeId`, message
    unchanged (parametric_system.dart:360-368). It is exported through the barrel
    (jet_cad_2d.dart:62 exports the whole file). It is thrown at the only refusal site
    (regeneration.dart:987).
  - Plan: `_LockCheck.apply` maps it to `const PlanLocked()` when
    `locks.covers(target, error.handle)`, else rethrows (locks.dart:259-264). `_first` treats it as
    a refusal, so it is neither probed nor retried (locks.dart:307).
  - Invariant: frozen ⊆ locked. `frozen` is only added to in `FailureBoundary._freeze`, which also
    locks (guard.dart:606-609), so the mapping always fires for a frozen object.
  - All three paths are tested:
    - FW-1: host `execute` returns false with the hint set.
    - FW-2: a kit tool takes `_failed`'s refusal branch; there is no `hookFailed` and the tool
      stays armed.
    - FW-3: a `plan.select` grip drag returns normally.
  - Spec E2 is amended, and a revision-history entry is added.
- **I2: a planner-refused `generate` blocks the object and its neighbours, silently.** ADDRESSED.
  - `_first` (locks.dart:279-299) does the following:
    - It catches any error that is neither a `KitHookFailure` nor `_isRefusal`.
    - `onRefusedEdit` is `FailureBoundary.recoverRefused` (guard.dart:649-654). It runs
      `_probeAll`, freezes and locks the failures, and returns true.
    - It then re-expands `original` and retries once.
    - If the retry fails again with a non-hook, non-refusal error, `onRetryFailed` adds one
      `(plan, hookFailed)` diagnostic and the error is rethrown.
  - The ruling's points are met: probe, freeze+lock, retry once, and a diagnostic on a second
    failure. F-15 and F-15b cover the neighbour unblocking. F-15c covers a true refusal, which
    gets no diagnostic. F-15d covers the failed retry.
  - Each branch has a named mutation that turns red.
- **I3: a successful library retry keeps that source's `libraryUnreadable`.** ADDRESSED.
  - `DiagnosticsLog.removeWhere` (diagnostics_log.dart:94-110) drops matching entries and their
    `_seen` keys. It works on `_current`, so a pending after-frame list is respected, and it
    publishes once.
  - `_loadSymbols` removes the three library codes before adding the new load's diagnostics
    (plan_controller.dart:1063-1068, 1095).
  - Only `plan_symbol_loader.dart` (lines 81, 91, 102) emits these three codes, so replacing them
    per load is safe.
  - Tests: S-19 and DL-1, each with a red mutation.
- **Task 7 `usedKitsIn`: the reserved `plan` id was written into the manifest.** ADDRESSED.
  - manifest.dart:918 now excludes `reservedKitIds`.
  - Test: PF-3b, with the M-PF-3c mutation.
- **Task 3 `ChoiceProperty`: segments containing `.` or `:`.** ADDRESSED.
  - properties.dart:560-563 refuses them.
  - Test: PS4 (M-PS4c). It also refuses a double such as `0.5`. That is intended: the segment
    `0.5` holds a `.`.
- **Task 2 `probe` doc: "runs once".** ADDRESSED. The wording at parametric_system.dart:771-775 is
  now accurate.
- **Task 4 `AttachmentQuery.pointer` / `PlanType.properties` docs.** ADDRESSED.
  - `pointer` returns a copy on every read (attachment.dart:56). The registry reads it once per
    `attach` (attachment_registry.dart:54), and `_withoutKeep` reads `q.pointer`, which the
    constructor copies.
  - Test: PT20 (M-PT20c).
  - The `PlanType.properties` doc now names the members that throw.
- **Task 16 `idleKeys` left closed.** ADDRESSED.
  - `_restoreIdleKeys` runs in `dispose` and for the old controller in `didUpdateWidget`
    (plan_shortcuts.dart:1204, 1214, 1221-1223).
  - Test: KB-14, with both mutations.
  - See the Minor note below.
- **Task 17 `NumberProperty`: a no-op step that rounds back.** ADDRESSED.
  - plan_property_panel.dart:1150-1159 skips a `SetComponentCommand` whose value `==` the stored
    component. That is an exact stored comparison, as CLAUDE.md requires.
  - Test: P-1 (M-P-1d), which also checks that the field shows `2.3`.
- **Task 11 / M3: `_encodedState` set before the damaged read-back.** ADDRESSED for the triaged item.
  - `save()` now sets `_encodedState` only after the read-back succeeds
    (plan_controller.dart:736-760).
  - `_saveUnchecked`'s behaviour is unchanged.
  - Test: F-7b (M-F7b).
  - The second half of M3 was left out, and that is acceptable:
    - The triage item asked only for the order. The `component.unreadable` half belonged to the
      Minor M3, which was not on the triage list.
    - The implementer's reason is correct. E4 keeps an unreadable component raw at load, so the
      read-back reports `component.unreadable` for it again. The naive check would make every
      damaged plan that holds such a component unsavable.
    - A narrower check remains possible for the ledger: fail only on a `component.unreadable`
      whose handle the load did not already report.
- **Task 1 `commands.dart:958`: 115-column comment.** ADDRESSED. It is rewrapped (diff lines
  198-201).

## Extra checks

- **`on StateError` catches.**
  - `NonLiveWriteError` is a `StateError` subtype, so every `on StateError` still catches it:
    - jet_cad_floor_plan: selection_panel.dart (7 sites), layer_panel.dart, layer_picker.dart,
      color_picker.dart and the four parametric tools;
    - the plan library's four panels;
    - symbol_gallery.dart in jet_cad_2d_flutter.
  - `throwsStateError` matches subtypes.
  - No `runtimeType` comparison against `StateError` exists, and no lib code outside the engine
    matches the message.
- **jet_cad_floor_plan.**
  - `git diff --stat` shows no change to jet_cad_floor_plan, jet_cad_2d_flutter or apps/.
  - The engine change keeps the message and the supertype.
  - The quoted run is `+2008 ~4: All tests passed!`.
  - The behaviour is preserved.
- **Engine tests.** E2-4 and MP1/MP3/MP6 now assert the typed error with its handle and type id,
  and the mutation that throws a plain `StateError` turns them red.
- **Test counts are consistent.**
  - Plan: 723 → 735 = +12 (FW ×3, F-15 a-d ×4, F-7b, S-19, DL-1, PF-3b, KB-14).
  - Kit: 314 → 314; PS4 and PT20 extended existing tests.

## New Breakage in the Fix Diff

No Critical or Important issues.

- **Minor (test gap): the uncovered branch of the I1 mapping is untested.** At locks.dart:263,
  `if (!covers) rethrow;` has no test through the plan library. A `NonLiveWriteError` on a handle
  that is not locked (a host writing on a deleted or nested handle) must stay a `StateError`. The
  mutation "always throw `PlanLocked`" would survive, and that would wrongly set the lock hint for
  a host bug. One test would close it: `execute` of a `SetComponentCommand<SquareParams>` on a
  deleted handle should throw `NonLiveWriteError` and leave `lockHint` false.
- **Minor: `_first`'s catch-all now routes any plain error from any command through
  `_probeAll`.** Examples are a host command's `StateError`, or a client-bug `StateError` from the
  engine (locks.dart:285-288).
  - This is O(objects), and only on the failure path.
  - The outcome is unchanged unless some stored object fails its probe. In that case the
    unrelated broken object is frozen and locked (which clears history, per N5), and the retry's
    diagnostic says "the objects that broke it" when they did not.
  - Acceptable as ruled; ledger it.
- **Minor: a remount of `PlanShortcuts(shortcuts: false)` on the same controller can reopen
  `idleKeys`.** The trigger is a key change or reparenting.
  - The new State's `initState` sets it false. The old State's `dispose`, which runs at
    finalizeTree after the new mount, then sets it true (plan_shortcuts.dart:1214).
  - It stays open until the controller next notifies (`_applyIdleKeys` is a listener).
  - The scenario is narrow and the state heals itself.
- **Minor (cosmetic):** the spec's new revision-history entry sits between Revision 1 and
  Revision 3. The list was already out of order (1, 3, 2).

## Out-of-Scope Observations

- **A true refusal still throws out of a grip drag.** `GuardedTool._failed` (guard.dart:290-310)
  still rethrows a non-hook `ArgumentError` from a generic tool. So a refusal the probe cannot
  cure still escapes a `plan.select` grip drag as an uncaught exception: F-15c's "the edit's own
  new value is refused", applied to a grip. For a kit tool, F-15d's path yields two diagnostics:
  the plan's `retryFailed` and the tool's own `hookFailed`, and the tool is disarmed. Pre-existing
  behaviour, near final-review M1 and M2. Worth deciding with sub-project 3's grips.
- Review minors M1, M2 and M4-M8 are untouched, as the wave's brief said.

## Verdict

**Fix round:** All findings addressed, no new Critical/Important breakage. There are four Minors
to ledger: the I1 uncovered-branch test gap, the catch-all probe scope, the idleKeys remount
order, and the revision-history order. There is also the M3 refinement (a `component.unreadable`
check narrowed to handles the load did not already report).
