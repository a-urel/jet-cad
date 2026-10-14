# Final fix wave, sub-project 2a: report

Branch `feat/plan-library-2a`, from `2fa4cc6f` to `07128eb1`. No subagents. Nothing pushed, tagged,
merged or published. Every mutation ran on a committed file and was reverted with
`git checkout -- <file>`; `git diff --quiet -- <file>` exited 0 after each (printed `REVERTED`).

## Commits

| Commit | Subject |
|---|---|
| `f44899f0` | feat(engine): a write on a group that is not live is a typed refusal (I1 engine; probe doc; commands.dart comment) |
| `c8aa854b` | fix(plan): a write on a frozen object is refused as locked (I1 plan; spec E2 + revision history) |
| `5b227960` | fix(plan): an edit the planner refuses probes the plan's kit objects (I2) |
| `85ad411e` | fix(plan): a symbol library that reads on a retry leaves the bar (I3) |
| `62af16e5` | fix(kit): contract tightening from the final review (ChoiceProperty, AttachmentQuery.pointer, PlanType.properties doc) |
| `cfb221e0` | fix(plan): the final review's should-fix minors (usedKitsIn, idleKeys, NumberProperty no-op, damaged-save order) |
| `07128eb1` | docs: the final review's fixes in the 2a results |

## I1: a write on a frozen object

**Change.**
- Engine: `final class NonLiveWriteError extends StateError` (in `parametric_system.dart`, exported
  through the barrel), fields `Handle handle`, `String typeId`, same message as before. Thrown at
  `regeneration.dart`'s not-live-write refusal in `_run` (the only site). `_written`'s doc and the
  site comment updated; CHANGELOG `## Unreleased` gains a bullet.
- Plan: `_LockCheck.apply` catches `NonLiveWriteError`; when `locks.covers(target, error.handle)` it
  throws `const PlanLocked()` (the engine already undid the edit), else rethrows. So `execute`
  answers false with the hint, `GuardedTool._failed` takes its refusal branch (hint, no diagnostic,
  the tool stays), and `plan.select` no longer rethrows from a grip drag. `execute`'s doc mentions it.
- Spec: E2 gains a paragraph (typed refusal, mapped to `PlanLocked`, "amended in the final review");
  the revision history gains an "Amended in the final review" entry.

**Tests.**
- Engine: `frozen_test.dart` E2-4 now expects `isA<NonLiveWriteError>()` with `handle == hF`,
  `typeId == Tile.id` and the old message; `misplaced_test.dart`'s `refusedAt` matcher (MP1, MP3, MP6)
  expects the typed error with the handle and `Hinge.id`.
- Plan: new `test/kits/frozen_write_test.dart`: FW-1 (host `execute`: false, hint, bytes unchanged,
  still one `hookFailed`; positive control on the healthy square), FW-2 (a `poke` kit tool writing it:
  returns normally, hint, no `hookFailed` of the tool, tool stays armed), FW-3 (a kit grip on a healthy
  square whose drag writes the frozen neighbour, dragged through `plan.select` under the rotated test
  camera: returns normally, hint, bytes unchanged).

`dart test test/parametric` (after the change): `00:00 +169: All tests passed!`.
`flutter test test/kits/frozen_write_test.dart`: `00:00 +3: All tests passed!`.

**Mutations.**
- M-E2i: `regeneration.dart:994` `throw error;` -> `throw StateError(error.message);`.
  `dart test test/parametric/frozen_test.dart test/parametric/misplaced_test.dart`:
  ```
  00:00 +3 -1: test/parametric/frozen_test.dart: E2-4 a new value of its type written on a frozen object is refused, and nothing changes [E]
      Actual: <Closure: () => void>
       Which: threw StateError:<Bad state: "Set component": test.tile written on 3E8, which is not a live root-level group after the edit, would never be regenerated (spec 06 D5); the edit is refused>
  00:00 +5 -2: test/parametric/misplaced_test.dart: MP1 ... [E]
  00:00 +7 -3: test/parametric/misplaced_test.dart: MP3 ... [E]
  00:00 +9 -4: test/parametric/misplaced_test.dart: MP6 ... [E]
  ```
- M-FW-1: `_LockCheck.apply`'s `if (!covers) rethrow;` made an unconditional rethrow.
  `flutter test test/kits/frozen_write_test.dart`:
  ```
  00:00 +0 -1: FW-1 ... [E]
    Bad state: "Set component": box.square written on 12, which is not a live root-level group after the edit, would never be regenerated (spec 06 D5); the edit is refused
  00:00 +0 -2: FW-2 ... [E]
    Expected: true
      Actual: <false>
  00:00 +0 -3: FW-3 ... [E]
    Expected: return normally
      Actual: <Closure: () => void>
       Which: threw NonLiveWriteError:<Bad state: "Stretch": box.square written on 12, which is not a live root-level group after the edit, would never be regenerated (spec 06 D5); the edit is refused>
  ```

## I2: an edit the planner refuses

**Change.**
- `LockExpander` gains `onRefusedEdit` (`bool Function(Object)`) and `onRetryFailed`
  (`void Function(Object)`); `_expand` builds the check when `onRefusedEdit` is set too.
- `_LockCheck._first`: on a `KitHookFailure`, as before; on any other error that is not a refusal
  (`_isRefusal`: `PlanLocked`, `PartialMutationError`, `NonLiveWriteError`, `DanglingReferenceError`,
  `PermissionDeniedError`, `GeneratedGeometryError`), `onRefusedEdit(error)`; when either recovery
  froze something, `original` is expanded afresh and applied once more. A retry failing on an error
  that is neither a hook failure nor a refusal calls `onRetryFailed` and is rethrown.
- `FailureBoundary.recoverRefused(error)`: `_probeAll()` (every live, unfrozen root-level kit object
  probed, each failure reported as its type's `hookFailed`), freeze + lock, true; false when none fails
  (the edit itself is refused, as before, no diagnostic). `FailureBoundary.retryFailed(error)`: one
  `KitDiagnostic(kitId: 'plan', code: hookFailed, message: 'an edit failed again after the objects
  that broke it were locked: ...')`.
- The controller wires both on each document's lock expander.

**Tests** (`test/kits/failure_flow_test.dart`, `refusedScene`: a poisoned square at `atSquare` whose
`generate` adds an open region, switch `openRegion` on after building, and a healthy square
overlapping it at `nearSquare(300.5, 200.25, 0.2)`):
- F-15: the square's own move answers false, hint set (the retry met the lock), `locked == frozen ==
  {broken}`, one `(box, box.square)` `hookFailed`; the neighbour's edit then answers true and
  regenerates; the broken one keeps its geometry; still one diagnostic.
- F-15b: the neighbour edits first: true, regenerated, the broken square locked on the way, no hint,
  one diagnostic.
- F-15c: nothing stored is poisoned; the neighbour's new value is: false, bytes and depth unchanged,
  nothing locked, no diagnostic.
- F-15d: stored poisoned square plus a poisoned new value for the neighbour: false, the stored one
  locked, the neighbour's geometry unchanged, diagnostics `[(box, box.square), (plan, null)]`.

`flutter test test/kits/failure_flow_test.dart`: `00:00 +18: All tests passed!`.

**Mutations** (`flutter test test/kits/failure_flow_test.dart --plain-name "F-15"`):
- M-F15a: `..onRefusedEdit = null` in the controller:
  ```
  00:00 +0 -1: F-15 ... [E]
    Expected: true
      Actual: <false>
  00:00 +0 -2: F-15b ... [E]
    Expected: true
      Actual: <false>
  00:00 +1 -3: F-15d ... [E]
    Expected: Set:[18]
      Actual: Set:[]
  ```
- M-F15c: `recoverRefused` without `if (broken.isEmpty) return false;`:
  ```
  00:00 +2 -1: F-15c ... [E]
    Expected: empty
      Actual: [
                KitDiagnostic:hookFailed [plan]: an edit failed again after the objects that broke it were locked: Invalid argument(s): 17 generated a region whose boundary is not a closed polyline with a non-empty triangulation (spec 07 D8)
  ```
- M-F15d: `..onRetryFailed = null` in the controller:
  ```
  00:00 +3 -1: F-15d ... [E]
    Expected: [(String, String):(box, box.square), (String, Null):(plan, null)]
      Actual: [(String, String):(box, box.square)]
  ```

## I3: a successful symbol retry clears the library diagnostics

**Change.** `DiagnosticsLog.removeWhere(test)`: drops matching entries, removes their
`(kit, subject, code)` from `_seen`, publishes once when something was dropped. In `_loadSymbols`,
once a load returned, `removeWhere` drops `libraryUnreadable`, `libraryKitMismatch` and
`symbolDuplicate` before the load's own diagnostics are added: each load's library problems replace
the last one's, so a source that reads on a retry has none left and a source still failing keeps its
own.

**Tests.** S-19 (`symbols_controller_test.dart`: alpha and beta both fail -> failed, two
diagnostics; alpha fixed, `retrySymbols()` -> ready, alpha's symbols, only beta's diagnostic left).
DL-1 (new `test/controller/diagnostics_log_test.dart`: removeWhere drops, notifies once, a no-match
call notifies nobody, the same problem is accepted again, a kept one still dedupes).
`flutter test test/controller/diagnostics_log_test.dart test/controller/symbols_controller_test.dart`:
`00:00 +8: All tests passed!`.

**Mutations.**
- M-S19: the `_diagnostics.removeWhere(...)` line commented out.
  `flutter test test/controller/symbols_controller_test.dart --plain-name "S-19"`:
  ```
  00:00 +0 -1: S-19 ... [E]
    Expected: [
                (String, String, KitDiagnosticCode):(beta, beta, KitDiagnosticCode.libraryUnreadable)
      Actual: [
                (String, String, KitDiagnosticCode):(alpha, alpha, KitDiagnosticCode.libraryUnreadable),
                (String, String, KitDiagnosticCode):(beta, beta, KitDiagnosticCode.libraryUnreadable)
  ```
- M-DL-1: `_seen.remove(...)` commented out. `flutter test test/controller/diagnostics_log_test.dart`:
  ```
  00:00 +0 -1: DL-1 ... [E]
    Expected: true
      Actual: <false>
  ```

## The "should fix" minors

| Item | Change | Test | Mutation, command, red line |
|---|---|---|---|
| Task 7 `usedKitsIn` | excludes `reservedKitIds` (`plan`, `jetcad`); doc updated | PF-3b (`manifest_test.dart`, imports `usedKitsIn` from `src/file/manifest.dart`; the barrel is unchanged) | M-PF-3c (back to `kit != 'jetcad'`), `flutter test test/file/manifest_test.dart`: `PF-3b ... [E] Expected: Set:['cafe', 'deco'] Actual: Set:['cafe', 'deco', 'plan']` |
| Task 3 `ChoiceProperty` | a segment holding `.` or `:` is an `ArgumentError` on `values`; class doc says so | PS4 (`'oak.dark'`, `'tr:meşe'`, `0.5` refused; `'oak-dark'`, `2` accepted) | M-PS4c (check -> `if (false)`), `flutter test test/kit/properties_test.dart`: `PS4 ... [E] Expected: throws <Instance of 'ArgumentError'> with name: 'values' Actual: <Closure: () => ChoiceProperty<Slab, Object?>>` |
| Task 2 `probe` doc | "within one survey ... runs once; when a thrower is left out, the survey and its view are made again and the survivors are asked once more" | doc only | none |
| Task 4 `AttachmentQuery.pointer` | private `_pointer`, `pointer` getter returns `Vector2.copy` at each read; class doc; the registry reads it once per `attach` | PT20 (a mutated read leaves the query unchanged) | M-PT20c (`pointer => _pointer`), `flutter test test/kit/attachment_test.dart`: `PT20 ... [E] Expected: Vector2:<[1610.75,-580.5]> Actual: Vector2:<[-9999.5,-580.5]>` |
| Task 4 `PlanType.properties` | doc: members taking a `T` (`read`, `write`, `enabled`, `apply`) throw a `TypeError` when read through `PlanType<Component>`; use `fieldsOf`/`commitField` | doc only | none |
| Task 16 `idleKeys` | `_restoreIdleKeys(c)` (`selectGates.idleKeys = true` unless disposed) in `dispose` and for the old controller in `didUpdateWidget` | KB-14 (`plan_shortcuts_test.dart`) | M-KB-14a (swap restore commented), `flutter test test/shortcuts/plan_shortcuts_test.dart --plain-name KB-14`: `Expected: true Actual: <false>` at line 338; M-KB-14b (dispose restore commented): `Expected: true Actual: <false>` at line 343 |
| Task 17 `NumberProperty` no-op | `_write` (object target) skips a `SetComponentCommand` whose value equals the stored component (read erased through `snapshotOf`) | P-1 (count 2.3, typed 2.31: no step, field shows 2.3) | M-P-1d (`&& false` on the check), `flutter test test/panels/property_panel_test.dart --plain-name P-1`: `Expected: <4> Actual: <5>`, line 89 |
| Task 11 damaged save | `_encode()` returns `(text, state)`; `save()` sets `_encodedState` only after the read-back; `_saveUnchecked` unchanged in behaviour | F-7b (save, edit, a sabotaged compound writing `ObjectLayer` on `Handle(-7)` plus a poisoned square -> damaged; `save` throws `damagedUnsavable`; `markSaved`; `dirty` stays true) | M-F7b (`_encodedState = encoded.state;` before the read-back), `flutter test test/kits/failure_flow_test.dart --plain-name F-7b`: `F-7b ... [E] Expected: true Actual: <false>` |
| Task 1 `commands.dart:958` | rewrapped to 80 columns | none | none |

## Gates (on `cfb221e0`; the docs commit changes no code)

- `packages/jet_cad_2d`: `dart test` -> `00:06 +1322 -2: Some tests failed.`; the two failures are
  `test/testing/generate_document_test.dart`: "the default document is the one Plan 2 measured, byte
  for byte" and "both text fractions default to zero and change nothing", exactly the two lines of
  `tool/ci/standing_failures.txt` for this package. `dart analyze` -> `No issues found!`.
  `dart format --output=none --set-exit-if-changed .` -> `Formatted 184 files (0 changed) in 0.40 seconds.` (exit 0).
- `packages/jet_cad_2d_kit`: `flutter test` -> `00:05 +314: All tests passed!`; `flutter analyze` ->
  `No issues found! (ran in 3.0s)`; format -> `Formatted 68 files (0 changed) in 0.08 seconds.` (exit 0).
- `packages/jet_cad_2d_plan`: `flutter test` -> `00:38 +735: All tests passed!`; `flutter analyze` ->
  `No issues found! (ran in 3.2s)`; format -> `Formatted 179 files (0 changed) in 0.36 seconds.` (exit 0).
- `packages/jet_cad_floor_plan`: `flutter test` -> `01:41 +2008 ~4: All tests passed!` (package untouched).
- `cd tool/ci && dart test` -> `00:41 +116: All tests passed!`
- `dart run tool/ci/check_kit_deps.dart` -> `kit dependencies: 1 package(s) checked, none names the plan library or another kit` (exit 0).
- `dart pub publish --dry-run`: `jet_cad_2d_kit` -> `Package has 0 warnings.`; `jet_cad_2d_plan` -> `Package has 0 warnings.`
- `git status --short` after the gates: clean (no `analysis_options.yaml` touched).

## Deviations and concerns

- I1's error is named `NonLiveWriteError`, not `FrozenWriteError`: the engine refuses the same write
  on any group that is not live (deleted, nested, never allocated), not only a frozen one; the typed
  error covers every case, and the plan library maps it to `PlanLocked` only on a covered handle.
- I2's retry-failure diagnostic is `hookFailed` under kit `plan` with no subject (no type is known for
  an error no hook threw); the log keeps one such entry per plan session. An error no stored object
  explains (F-15c) stays a plain refusal with no diagnostic, as the reviewer proposed. The probe is
  O(objects) and runs only on that failure path.
- I3 clears all three library codes per load (the reviewer's replacement rule), which covers "that
  source's" diagnostics and also a stale `symbolDuplicate`.
- M3's second half (fail the damaged read-back on `component.unreadable`) was not done: with E4 on,
  any damaged plan that holds a component kept raw at load would then be unsavable. Only the
  `_encodedState` order (the triaged item) was fixed.
- Review minors M1, M2, M4-M8 and the "can stay deferred" list are untouched (not in this wave's brief).
- The F-7b fixture reaches an encodable-but-unreadable damaged state through a component on
  `Handle(-7)`; it is a test-only sabotage, as F-7's.
