# 3a final fix wave — brief

The final whole-branch review (Opus, 7e65905b..945502cb) found no Critical or Important issues and judged the branch ready to merge. This wave is the plan's one fix dispatch. It closes the review's actionable Minors and the curated parked Minors from the ledger. Each item is small. Do them in the order below. Commit in logical groups with the kind each one calls for: `fix(plan): …`, `fix(architecture): …`, `test(kit): …`, `test(integration): …`, `docs: …`.

Rules: kit-dispatch-notes.md applies in full. That covers the binding rules, the porting rule (never weaken a ported assertion), R-P1/R-P14, never synthesizing output, and never committing `analysis_options.yaml`. Every behaviour change or new pin needs a named mutation that turns red. Run it and revert it.

## A. Code (behaviour)

A1. **Room and Separator tools: one RoomInputs liveness pass per pointer event** (final review M3).
- `room_tool.dart:311-316`: `_verdictAt` reads `inputs.generation` and then `inputs.bounds`. Each runs `RoomInputs._dropFrozen`, an O(n) pass. That makes two to three passes per hover, plus one per `placedIn` in a trace.
- The separator's `trimSeparator` calls `placedIn` three times per hover (`_bandsHolding` twice and `_bandsTouching` once).
- Fix: once a pointer event has checked liveness, the rest of that event must skip the re-check. Mirror the opening tool's `_bandsFresh` flag (`opening_tool.dart`), or add a check token on RoomInputs that each pointer event resets, if that is cleaner. Choose one and say why.
- Correctness must not change. A freeze between two events must still be seen at the next event. Keep every existing freeze first-reader test green.
- Pin: a counter, either an existing debug counter or a `debug*` one you add, shows exactly one liveness pass per hover in steady state.
- Mutation: removing the flag reset must break freeze detection, which an existing freeze test should catch. Removing the skip must raise the count, which the new counter pin catches.

A2. **A failing build or prepare is reported again on a later plan** (final review M4).
- `PlanController._runBuild` and `_prepare` log `hookFailed` under (`plan`, `build`) and (`<kit>`, `prepare`).
- `hookFailed` is not plan-scoped, and the log keeps one entry per (kit, subject, code). So a second `newPlan(build:)` that throws adds nothing, and the first plan's stale entry stays.
- Fix: clear those entries before each run, or make those subjects plan-scoped, whichever matches `diagnostics_log.dart`'s design. Say which.
- Pin it in the plan package: two failing builds in a row, separated by a `newPlan`, give one current diagnostic for the current plan. A succeeding build after a failing one leaves none.
- Mutation: remove the clear.

A3. **Room area memo** (Task 18 M1). The memo is keyed on `commands.stateId`, but `notifyLoaded`/`notifyPurged` keep `stateId`, so after the E3 damage path the Area can be stale until the next command. Fix the doc comment to state this limit precisely (display-only, rare). Do NOT redesign the memo.

## B. Docs and comments (accuracy)

- B1. `docs/kits.md` §10.8: a failed `prepare` → "the plan opens; what it added before the throw stays" (Task 5).
- B2. `wall_bands.dart:35-37`: drop "or an undo". Write: "a frozen object stays frozen for its document's life; a new document resets the cache" (Task 12).
- B3. Kit `test/support/catalog.dart` header: it names the box only. Make it list today's order of registrations (Task 11).
- B4. `planner_box_test.dart` header: the grid snap keeps the clicks on today's exact corners, but it is not required for BX1-BX6 to pass (Task 10).
- B5. `separator_dashed_test.dart`: the M-SP-8 comment must also name M-SP-8b for the open half (Task 17).
- B6. `object_view_test.dart:345`: the mutation comment should read `LengthProperty<Object>` (Task 2).
- B7. The stale PN2 comment in the dimension panel test about the segmented button (Task 21). The row is now a `DropdownButton`, and the panel issues nothing for an equal value.
- B8. `_referencesOf`'s live-referent filter (Task 7): add a one-line comment that it is defensive. The engine refuses a reference to a non-live object first.
- B9. Live-check cost docs (final review M2): wherever a doc says the liveness check is "O(walls)" (`wall_bands.dart`, `wall_faces.dart`, `room_inputs.dart`), say "O(cached objects × the catalog's types) `liveTypeIdOf` calls".

## C. Tests (vacuous or unpinned, cheap)

- C1. TT7 (Task 19): `expect(plan.c.toolNotice.value, isNull)` after Esc is always true, because Select is active. Read the Room tool's own notice through `c.toolFor('architecture.room')` (R-P9, line-level ignore) and assert it is null after Esc. Run a mutation where cancel no longer clears it.
- C2. OT-frozen-host's delete half (Task 14): reset `c.lockHint.value = false` before `deleteSelection()`, and assert it is true after, as in the plan's `frozen_references_test:117-119`.
- C3. DT-freeze (Task 22): split its four steps into four tests, so that each step's M-DT8 red is observable on its own. Run M-DT8 and show all four red.
- C4. DG-frozen (Task 20): before the points step, assert the candidate set excludes the frozen wall. Then M-DG2 and M-DG3 go red on the test's own reason, not on a `!` throw. Show this.
- C5. P-choice-focus (Task 21):
  - Add an Esc step. Dismissing the open menu keeps focus on the row and hands nothing back.
  - Add a tool-settings-scope step, `setting-<id>`, for a tool's choice row, for example the wall tool's justification.
- C6. WR9 (Task 25): pair the diagnostics-empty line with a non-vacuity line, for example that the sample holds live walls.
- C7. Contract words (Task 3):
  - A one-case test that conformance does not hold a `text:other.x` word of another kit to the locales.
  - A `fillText` case whose argument value contains `{n}` and is not re-expanded.
  - A mutation for each.
- C8. Build words order (Task 5): give `prepKit` a word that conflicts with `testKit`'s, and assert that the earlier kit's word wins. Mutation: `kits.reversed`.
- C9. `FakePlanServices.dispose` (Task 6): a probe that the camera and the symbols-state notifier are disposed, for example adding a listener after dispose throws. Mutation: drop one dispose.
- C10. `_GuardedNotice` (Task 4): give `BoomNotice` hooks so that its `addListener`/`removeListener` throw, and pin that the guard catches each one and reports once. Mutation: remove each try/catch.

## D. Integration hygiene

- D1. Rig teardown order (Task 19): `editor_rig.dart` disposes the controller while the editor is still mounted, so one failing widget test cascades into "DiagnosticsLog used after dispose" in later tests. Unmount first, for example by pumping an empty widget in the teardown before `dispose`, so that failures stay isolated. Prove it: a scratch failing case (not committed) no longer cascades. Describe what you ran.
- D2. Line-level ignores (final review M6). Replace each file-level `// ignore_for_file: invalid_use_of_internal_member` in `packages/jet_cad_2d_integration/test` with line-level `// ignore:` on each internal read, where a file has few reads. A file with many reads may keep the file-level form. Report the count before and after.
- D3. Helper duplicates (R-P14; Tasks 18, 21, 26):
  - `dragWorld`, `undoKey`, `select` and `clickAt` near-copies across `room_plans.dart`, `opening_support.dart` and `wall_shell.dart`.
  - `addSeparator`, duplicated in `dimension_plans.dart` and `separator_plans.dart`.
  - `frameOn` versus `pumpEditor`'s camera block.

  Consolidate the copies into one place each, the rig or the nearest shared support. Where a variant differs only in pump count, give the shared one a parameter. Every caller stays green. No assertion changes.

## Not in this wave (recorded, no action)

- Line-length and ragged comment polish.
- The import cycle `wall.dart` ↔ `opening_geometry.dart`, which the plan mandates and the old line already had.
- Items the final review called inherited or follow-ups: TL8's face line; the `PlanServices` liveness revision; neighbour-only `wallsInDocument`; `PlanObject.liveTypeIdOf`.
- The human-facing spec questions.

## After the wave

Re-run the gates and transcribe each one's real last lines into the fix report:
- contract, plan, kit and integration: test, analyze, format;
- `check_kit_deps`;
- the plan and IA-alloc invariants;
- the three dry runs.

Then append a "Final fix wave" section to `docs/superpowers/notes/2026-10-15-architecture-kit-results.md`. Include the items closed, the new gate counts from this run (transcribed), and the commits. Change no earlier figure in the note.
