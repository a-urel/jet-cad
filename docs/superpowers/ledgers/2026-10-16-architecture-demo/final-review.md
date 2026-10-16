# Final whole-branch review, sub-project 3b (feat/architecture-demo)

Reviewer: Sonnet. Scope: `git diff main...HEAD -- apps/architecture_demo/lib packages/jet_cad_2d_plan/lib`, and the app's tests as a body.

## Strengths
- One controller, owned by `ArchitectureDemoAppState`; `dirty` is read only from `PlanController.dirty` (host, title, exit guard). No second flag in the session.
- `_flow` is one outermost-busy mechanism with a `finally` that clears it and an `isDisposed` guard (DS8 pins it). The exit path checks busy first, then settles, then asks. Failed open, failed save and a cancelled picker change nothing.
- `_write` marks the encoded state and re-checks `mounted` and document identity. `_mayDiscard` re-asks when an edit landed during the write, and its loop ends after a teardown (RP-teardown).
- Library changes are small and match the spec's settle rule. The text-entry overlay registers in `initState`, re-registers when the controller changes and releases in `dispose`. The page panel hands focus back in `resyncScale`. The CHANGELOG mentions the two new exports.
- Dispose order is sound. Children unmount first, so the host removes its `dirty` listener before the app disposes the controller. The app then disposes the loader and the session.
- No `skip:` anywhere. One rig home under `test/support/`.

## Gates (run now, in apps/architecture_demo)
- `flutter test`: `00:33 +171: All tests passed!`
- `flutter analyze`: `No issues found! (ran in 3.9s)`
- `dart format --output=none --set-exit-if-changed .`: `Formatted 43 files (0 changed)`
- The worktree is clean after my runs.

## Review Focus 1-5 mutations
Each was applied, the named test ran red, and `git checkout --` restored the file (`git diff --quiet` confirmed).
- RF5 (CH-consume): deleting the `for (final chord in kFileChords) chord: _consume` line in `lib/main.dart` turned `app_shell_test.dart` red (2 failures, the Control and Meta cases).
- RF1 (SV-edit-during-write): adding `_controller.save()` before `markSaved()` in `_write` turned `document_sample_test.dart` red.
- RF3 (N6-exit): removing the busy check at the top of `_onExitRequested` turned `export/busy_test.dart` red.
- RF4 (N5): replacing `_session.nameChanged()` in the post-frame callback with a no-op turned `document_title_test.dart` red.
- RF2 (OP-garbage): confirmed by reading only. The test asserts text, name, location, dirty, undo depth and busy after the failed load. I did not run its mutation (naming the session before `load`).

## Critical
None.

## Important
- I1. `lib/busy_wrappers.dart:32` and `:53`: the `finally { busy.value = false; }` in `busyExportDialog` and `BusyPagePrinter.print` has no `isDisposed` guard, unlike `_flow` (`document_host.dart:109`). If the app is torn down while a print job is held and the job then finishes, the finally throws "A ValueNotifier<bool> was used after being disposed".
  - I reproduced it with a temporary untracked probe test (since removed): hold `FakePagePrinter`, `pumpWidget(SizedBox())`, complete the job. The awaited call throws. The throw replaces the printer's normal completion, so the library's `onPageFlowError` would show an error on a dead app.
  - Same defect class as the one DS8 pins for `_flow`; nothing pins the wrappers.
  - The dialog wrapper is probably unreachable in practice, because the dialog route dies with the navigator. The printer is reachable.
  - Fix: pass the session, or a `bool Function()` for "disposed", into both wrappers and guard the clear. Add a DS8-style test to `export/busy_test.dart` for the printer. Mutation: remove the guard.

## Minor
- M1. `lib/document_host.dart:240-248` (`openFlow`): after `await _pick()` there is no `mounted` check before `_controller.load(...)` and `_session.named(...)`.
  - Probe: with the picker held, the app torn down and the picker then answered with a valid plan, no error surfaced. This is by luck: `load` on a disposed controller throws and the surrounding `catch` swallows it, then `_showError` returns on `!mounted`.
  - `_session.named` is not reached, but a `catch (e)` that hides a disposed-controller error is fragile. Fix: `if (!mounted) return;` after the pick. Add a held-picker teardown test. `FakeDocumentFiles` has no way to hold `open()`, so the test needs a hold hook there.
  - This is the "continuation after an await" carry-over from the Task 4 re-review; RP-teardown only covers the held Save.
- M2. `exportFlow` (`document_host.dart:186-203`): after the awaited panel and write there is no `mounted` check. It only calls `_showError`, which is guarded, and touches no controller or session, so it is safe today. No teardown test covers it (the wrappers' coverage is the same gap as I1).
- M3. Helper copies across test files, against "one rig/fakes home":
  - `titledDirty` is defined three times with three different signatures and bodies (`document_exit_test.dart:53`, `document_replace_test.dart:59`, `document_save_test.dart:23`).
  - `canvasFocused` is defined twice (`document_settle_test.dart:86`, `symbols/symbol_palette_end_to_end_test.dart:42`).
  - The `far` constants are repeated per file.
  - Fix: move `titledDirty` and `canvasFocused` into `test/support/app_rig.dart` as one parameterised helper each.
- M4. `test/support/app_fakes.dart:1`: the fakes file has no ported-from header, while the other ported files and `app_rig.dart` and `export_rig.dart` have one. Add one noting what was ported and what is new (`FakePagePrinter`, `heldWrites`).
- M5. Headers: `test/app_shell_test.dart`, `boundary_test.dart`, `document_sample_test.dart`, `library_gaps_test.dart` and `export/busy_test.dart` start with new-test headers rather than "Ported from". That is correct for new files, but `export_rig.dart` says "ported from" while most of its helpers are new. Check the wording.
- M6. Vacuous or weak asserts: none found. Every `isNotNull` and `isNotEmpty` in the tests is on a nullable value or is followed by a content assert, and each carries a reason.

## Already parked (not counted as new)
T5-M1, T5-M2, T7-M1..M4, and dropping the app's own `PlanSymbolLoader` field (`lib/main.dart:70`, with the dispose at `:111`).

## Verdict
Ready to merge after fixes: 0 Critical, 1 Important (I1), 6 Minor (M1-M5 actionable; M6 is a clean finding).
