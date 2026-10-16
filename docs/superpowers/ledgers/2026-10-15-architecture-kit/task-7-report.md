# Task 7 report: grip refusals; a frozen object's references locked (spec 3a C1.8, C1.10)

Status: DONE_WITH_CONCERNS (one unpinned line, see Concerns).

## Commits

- `7e6b671d` feat(plan): grip refusals; a frozen object's referents locked (spec 3a C1.8, C1.10). This is the brief's commit, with its message verbatim.
- `9117826c` test(plan): a frozen object's referents, a throwing references and the service copy (spec 3a C1.10). Two tests added beyond the brief (see Deviations, D3).

## Implementation summary

- `lib/src/kits/guard.dart`
  - `GuardedGrips.drag` and `preview` each gain `on ArgumentError` before the catch-all. A refused point gives null or `const []`, the group is not added to `_failed`, and nothing is reported.
  - The `GuardedGrips` doc is replaced with the brief's text.
  - `GuardedTool` gains `refusal` (`bool Function(Object)?`), its doc bullet and its field doc. `_failed` asks `refusal` right after the `PlanLocked`/`DanglingReferenceError` branch. A refusal cancels the inner tool and returns, with no `onFailed` call and no rethrow. `GuardedTool.notice`/`_GuardedNotice` (Task 4) are untouched.
  - `FailureBoundary` gains `referencesOf`. `_freeze` now locks the frozen objects together with every object each one references.
- `lib/src/controller/plan_controller.dart`
  - `execute` now uses one shared `_refusal(Object)`, which covers `PlanLocked` (sets the hint), `DanglingReferenceError`, `PermissionDeniedError`, `ArgumentError`, and `KitHookFailure` (via `_reportFailure`). Anything else is rethrown.
  - `_guardTool` passes `refusal: toolId == planSelectToolId ? _refusal : null`.
  - New `_referencesOf` after `typeOf`, verbatim from the brief.
  - `_open`'s `FailureBoundary(...)` and `_buildService`'s `ServiceSession(...)` both gain `referencesOf: _referencesOf`. The Task 4-6 wiring (`_toolNotice`, `_prepare`, `_runBuild`, `_Host.catalog`, and so on) is intact.
- `lib/src/service/service_session.dart`: takes `referencesOf` and forwards it to its `FailureBoundary`.
- `lib/src/kits/locks.dart`: the docs of `LockSet.objects` and `addBroken` are updated, per the brief.
- `test/kits/locks_test.dart`: only L-11's four mutation comments changed (M-L11a/b/c/d now name `_refusal`). No assertion changed. M-L11a's comment is re-wrapped so the following sentence stays readable.
- `docs/kits.md` §10.8: the grips row is updated, and the frozen-referents sentence is added after the paragraph on missing kits.
- `docs/superpowers/specs/2026-10-14-plan-library-design-mode-design.md`: two bullets appended to `## Amendments`, after Task 5's `build` bullet.
- The `_first` catch-all is kept as ruled; its code is unchanged.

## TDD evidence

RED, before any lib change, with the brief's tests verbatim:

`flutter test test/kits/grip_refusal_test.dart`:
```
GR-1 ... [E]
  Expected: empty
    Actual: [
              KitDiagnostic:hookFailed [box box.square]: grips.drag: Invalid argument(s): too short
GR-drag-refuse ... [E]
  Expected: a numeric value within <0.000001> of <1500>
    Actual: <1200.0>
GR-drop-refuse ... [E]
  Expected: return normally
     Which: threw ArgumentError:<Invalid argument (side): refused at the drop: 950.5>
```
`flutter test test/kits/frozen_references_test.dart`:
```
FL-edit ... [E]
  Expected: Set:[23, 18]
    Actual: Set:[23]
     Which: does not contain <18>
FL-delete ... [E]
  Expected: false
    Actual: <true>
```

GREEN, after the lib change. The first run had GR-drag-refuse still red because of a fixture defect (D1, D2):
```
GR-drag-refuse ... [E]
  Expected: a numeric value within <0.000001> of <1500>
    Actual: <1481.813787033303>
```
After the fixture fix: `flutter test test/kits/grip_refusal_test.dart test/kits/frozen_references_test.dart` printed `00:00 +5: All tests passed!`. Then `flutter test test/kits/ test/controller/plan_controller_test.dart` printed `All tests passed!`.

## Gates (final, at 9117826c)

- `packages/jet_cad_2d_plan`
  - `flutter test --enable-vmservice`: `01:52 +1538: All tests passed!`
  - `flutter analyze`: `No issues found!`
  - `dart format --output=none --set-exit-if-changed .`: exit 0.
- `packages/jet_cad_2d_kit`
  - `flutter test`: `00:06 +400: All tests passed!` (doc_snippets included; `docs/kits.md` was already edited at that point).
  - `flutter analyze`: `No issues found!`
  - Format: exit 0.
- `dart run tool/ci/check_kit_deps.dart`: `kit dependencies: 1 package(s) checked, none names the plan library or another kit`
- `git status --short`: clean after the commits.

## Mutations

All mutations ran on committed files. Each was reverted with `git checkout -- <file>`, and `git diff --quiet -- <file>` then exited 0 every time.

| Mutation | File | Result (red line) |
|---|---|---|
| M-GR-1a: drag's `on ArgumentError` deleted | guard.dart | GR-1 red: `Actual: [KitDiagnostic:hookFailed [box box.square]: grips.drag: Invalid argument(s): too short` (test line 204). GR-drag-refuse red: `grips.drag: Invalid argument (side): is below 400.0: 300.0` (line 245, the second drag's diagnostics check) |
| M-GR-1b: preview's `on ArgumentError` deleted | guard.dart | GR-1 red: `grips.preview: Invalid argument(s): too short` (line 207). GR-drag-refuse red: `Expected: ... of <1500> Actual: <1200.0>` (line 234) |
| M-GR-2a: `refusal:` line deleted from `_guardTool` | plan_controller.dart | GR-drop-refuse red: `threw ArgumentError:<Invalid argument (side): refused at the drop: 950.5>` (line 271) |
| M-GR-2b: the `refused` block deleted from `_failed` | guard.dart | GR-drop-refuse red: same `threw ArgumentError ... 950.5` (line 271) |
| M-GR-2c: `default: return true;`, `return false;` deleted | plan_controller.dart | GR-drop-refuse red: `Expected: throws <Instance of 'StateError'> ... returned <null>` (line 281). L-11 red: `Expected: throws <Instance of 'StateError'> ... returned <false>` (locks_test 409) |
| M-L11a: `case PlanLocked(): ...` deleted | plan_controller.dart | L-11 red: `PlanLocked: the edit would change a locked object` (locks_test 401) |
| M-L11b: `\|\| ArgumentError()` deleted | plan_controller.dart | L-11 red: `Invalid argument (side): 3` (locks_test 406) |
| M-L11d: `DanglingReferenceError() \|\|` deleted | plan_controller.dart | L-11 red: `DanglingReferenceError: 17 references 12, which is not a live parametric object` (locks_test 427) |
| M-FL-1: `_freeze` calls `lock(objects)` | guard.dart | FL-edit red: `Expected: Set:[23, 18] Actual: Set:[23]` (line 53). FL-delete red: `Expected: false Actual: <true>` (line 83) |
| M-FL-2: `referencesOf:` deleted from `_open`'s boundary | plan_controller.dart | FL-edit and FL-delete red, same lines as M-FL-1 |
| M-FL-3: `if (id == typeId) continue;` | plan_controller.dart | FL-edit and FL-delete red, same lines as M-FL-1 |
| M-FL-4 (added): `_referencesOf` without its try/catch | plan_controller.dart | FL-throw red: `HookBoom(references)` thrown out of `execute` |
| M-FL-5 (added): `referencesOf:` deleted from `_buildService` | plan_controller.dart | FL-service red: `Expected: Set:[23, 18] Actual: Set:[23]` |
| M-FL-5b (added): ServiceSession does not forward `referencesOf` | service_session.dart | FL-service red, same line as M-FL-5 |
| Extra probe: `PermissionDeniedError()` dropped from `_refusal` | plan_controller.dart | GR-drop-refuse red: `threw PermissionDeniedError: "Refusing" needs components`. permissions_controller_test S-PD red as well |
| Extra probe: the live filter `if (catalog.typeIdOf(d, h) != null)` dropped | plan_controller.dart | **Green** (test/kits, test/controller, test/service: `+650: All tests passed!`). See Concerns |

## Existing tests changed

- `test/kits/locks_test.dart` (L-11): only comments changed, no assertion.
  - Old `// M-L11a: \`on PlanLocked\` dropped: the refusal escapes. A real move` became new `// M-L11a: \`_refusal\`'s PlanLocked case dropped: the refusal escapes. A` (the remaining sentence re-wrapped).
  - Old `// M-L11b: \`on ArgumentError\` dropped.` became new `// M-L11b: ArgumentError dropped from \`_refusal\`'s refusal case.`
  - Old `// M-L11c: \`on StateError\` (or \`catch (_)\`) added: a StateError is the caller's.` became new `// M-L11c: \`_refusal\` answering true for a StateError (or for anything): a StateError is the caller's.`
  - Old `// M-L11d: \`on DanglingReferenceError\` dropped: E2's refusal ...` became new `// M-L11d: DanglingReferenceError dropped from \`_refusal\`'s refusal case: E2's refusal ...`
- No other existing test reddened. F-B1, F-T1 to F-T6, FW-1 to FW-3 and SM-copy-boundary all stay green in the full suite.

## Files changed

- packages/jet_cad_2d_plan/lib/src/kits/guard.dart
- packages/jet_cad_2d_plan/lib/src/kits/locks.dart
- packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart
- packages/jet_cad_2d_plan/lib/src/service/service_session.dart
- packages/jet_cad_2d_plan/test/kits/grip_refusal_test.dart (new)
- packages/jet_cad_2d_plan/test/kits/frozen_references_test.dart (new)
- packages/jet_cad_2d_plan/test/kits/locks_test.dart (comments only)
- docs/kits.md
- docs/superpowers/specs/2026-10-14-plan-library-design-mode-design.md

## Deviations

- **D1: brief test defect, the page notifier is asynchronous.** In `grip_refusal_test.dart`, `scene()` sets the page's `snapToGrid: false` through `c.execute`. The select tool reads the page through `PageNotifier`, which listens to the document's broadcast `changes` stream (`undo.dart:104`, `StreamController.broadcast()`, so delivery is asynchronous). In a synchronous `test()`, every drag therefore still snapped to the 25 mm grid. Instrumenting showed the provider receiving world `[7675.0,3350.0]` for `at(1500)` = `[7659.5,3395.0]`, which gave side 1481.8.
  - Fix: `scene()` is now `Future<...> async`. It awaits `settleHistory()` (from `test/support/tool_events.dart`) after the page edit, and adds a fixture-sanity check, `expect(c.page.value!.snapToGrid, isFalse, reason: 'fixture: no grid snap')`.
  - GR-drag-refuse and GR-drop-refuse are now `async` and `await scene()`.
  - No assertion changed.
- **D2: brief test defect, the grip cache is asynchronous too.** After the first drop committed side 1500, the next press at `at(1500)` still saw the old grip, which sat at local x = 600. The press therefore became a body move: canon showed the group translated to `6490.38, 2720.0`.
  - Fix: GR-drag-refuse awaits `settleHistory()` before its second and third drags, and the `dragThrough` doc says the caller settles first.
  - No assertion changed. All of the brief's named mutations still turn these tests red (table above).
- **D3: two tests added beyond the brief** (separate commit `9117826c`, in `frozen_references_test.dart`).
  - FL-throw (M-FL-4): removing `_referencesOf`'s try/catch stayed green across test/kits, test/controller and test/service. A probe showed the real effect of that mutation: the edit that freezes the object throws `HookBoom(references)` out of `execute`, and the object is left unlocked (`locked={}`).
  - FL-service (M-FL-5, M-FL-5b): the service copy's `referencesOf` wiring had no red mutation either.
  - Both new tests use squares off the origin and turned, and FL-service uses a turned, mirrored table.
- The `_open` wiring reads `damage: _damage, referencesOf: _referencesOf);`. `damage: _damage` was the last argument, so the new argument went after it, which keeps the brief's intent.

## Concerns

1. **The live-referent filter in `_referencesOf` has no red mutation** (`if (catalog.typeIdOf(d, h) != null)`). Every path I could construct is refused upstream: the engine's `_checkDangling` refuses any reference to an object that is not a live parametric one. For example, a poisoned square whose partner is a plain line throws `DanglingReferenceError: 13 references 12, which is not a live parametric object` while the plan is being built. The filter is defensive and unpinned.
2. **A small behaviour change in plan.select (no test reddened).** A `KitHookFailure` that escapes a plan.select drop is now handled by `_refusal`: one diagnostic through `_reportFailure`, then the drag is cancelled. Before, `GuardedTool._failed` logged it, cancelled the drag and also called `onFailed`, which re-selects plan.select. plan.select is the armed tool in either case. This follows from the brief's design: `_refusal` is consulted before the `KitHookFailure` branch.
3. **The brief's mutation expectations matched**, with one difference: M-GR-1a's red in GR-drag-refuse is the diagnostics assertion on the second drag (line 245). The brief also expected "the last drag does not commit", but the test stops at the first failing expect, so that line is never reached.
4. **Process note:** after the fixture fixes, I did not re-run the brief's RED against the pre-change lib (to avoid checking out or stashing files with uncommitted work). The mutations above are piecewise reverts of each change, and each one turns the corrected tests red.

---

# Fix round 1 (review: one Important, Minors 1 and 3)

Commit: `e5b2261a` fix(plan): plan.select's refusal at the drop only; hook failure and two referrers pinned (spec 3a C1.8, C1.10). It sits on top of 9117826c.

## Fixes

1. **The refusal applies to the drop only (Important).**
   - `GuardedTool._failed` gains a named `{bool drop = false}` parameter.
   - `refusal` is consulted only when `drop` is true, and only `onPointerUp` passes `drop: true`.
   - So `onPointerDown`, `onPointerMove`, `onPointerExit` and `onKey` keep 2a's rule: plan.select (kit `plan`) rethrows. `onKey` therefore rethrows as well.
   - The `GuardedTool` doc bullet now says the refusal covers the error thrown by `onPointerUp` (the drop), and that every other event keeps the rules above.
   - `docs/kits.md` and the spec amendment already said "plan.select's drop", so I left them unchanged.
   - New test F-T7 (`test/kits/guarded_tool_test.dart`), on a plan.select `GuardedTool` whose `refusal` accepts `ArgumentError`:
     - an `ArgumentError` from each non-drop event is rethrown, with no cancel, no diagnostic, no `onFailed` and no hint;
     - at `onPointerUp` the same error returns normally and cancels once.
   - `_Rig` gains an optional `refusal` that it passes through. This is a fixture change only; no existing assertion changed.
2. **The KitHookFailure-at-drop path is pinned (Minor 1).** New test GR-drop-hook (`test/kits/grip_refusal_test.dart`).
   - Setup: `scene()` takes an optional `Switches`; given one, it switches the square type with it and loads `ringKit` too. Added to the scene: a broken square (turned, off origin) and a broken disc (a place reader), with `reach` failing.
   - The drop's edit fails on the square. The boundary reports it and freezes the square. The retry then fails on the disc, and the `KitHookFailure(ring.disc)` reaches `_refusal` at the drop.
   - Asserted: no exception, nothing changed (canon), the side still 1200, `frozen == {poisoned}`, plan.select still active, no hint.
   - Also asserted: the diagnostics are exactly `[(box, box.square, hookFailed), (ring, ring.disc, hookFailed)]`, so each failing type is reported once and the disc's report comes from `_refusal`.
   - Why the assertion is per type and not "exactly one diagnostic": `DiagnosticsLog` dedupes by (kit, subject, code) (`diagnostics_log.dart:34`), so a second report of the same failure cannot show. In a single-failure drop, `FailureBoundary.recover` has already reported the failure before `_refusal` sees it, and no mutation of `_refusal` could turn such a test red. The two-type retry is the one path where `_refusal`'s report is the only one.
3. **Two frozen referrers (Minor 3).**
   - `frozenReferrer()` now also has `host2` (turned 1.1 rad, off origin) and `referrer2` (poisoned, partner `host2`, turned −0.9 rad). One refused move freezes both referrers in a single probe, so a single `_freeze` call receives both.
   - FL-edit asserts `locked == {referrer, host, referrer2, host2}`, and that an edit of `host2` is refused with the hint.
   - FL-delete also asserts that `host2`'s gates and its delete command are refused.

## Gates (at e5b2261a)

- `packages/jet_cad_2d_plan`
  - `flutter test --enable-vmservice`: `01:54 +1540: All tests passed!`
  - `flutter analyze`: `No issues found!`
  - Format: exit 0.
- `packages/jet_cad_2d_kit`
  - `flutter test`: `00:04 +400: All tests passed!`
  - `flutter analyze`: `No issues found!`
  - Format: exit 0.
- `git status --short`: clean.

## Mutations (committed files; each reverted with `git checkout --`, `git diff --quiet` exit 0)

| Mutation | Result |
|---|---|
| M-F-T7a: `if (refused != null && refused(error))` (`drop &&` dropped; refusal consulted for every event) | F-T7 red at `onPointerDown`: `Expected: throws <Instance of 'ArgumentError'> Actual: ... returned <null>` |
| M-F-T7a, onKey variant: onKey passes `drop: true` | F-T7 red: `Which: returned KeyEventResult:<KeyEventResult.ignored>` (`onKey`) |
| M-F-T7a, onPointerMove variant: onPointerMove passes `drop: true` | F-T7 red: `Which: returned <null>` (`onPointerMove`) |
| M-F-T7b: onPointerUp without `drop: true` | F-T7 red: `threw ArgumentError:<Invalid argument (side): refused in onPointerUp: 3.5>`. GR-drop-refuse red: `threw ArgumentError:<... refused at the drop: 950.5>` |
| M-GR-3: `case KitHookFailure(): return true;` (no `_reportFailure`) | GR-drop-hook red: `Expected: [(box, box.square, ...hookFailed), (ring, ring.disc, ...hookFailed)] Actual: [(box, box.square, ...hookFailed)]` |
| The reviewer's example: `_refusal`'s KitHookFailure case removed | Red in test/kits + test/controller through `execute`: failure_flow_test F-3 `KitHookFailure: box.square.reach threw HookBoom(reach)` escapes. **GR-drop-hook stays green: an equivalent mutant at the drop.** With the case removed, `_failed`'s own KitHookFailure branch reports the same deduped diagnostic and cancels. The only extra step is `onFailed` → `selectTool(plan.select)` → `ToolController.activate`, which returns at once for the active tool (`tool.dart:170`, `if (identical(next, _active)) return;`). So nothing observable differs. M-GR-3 is the red mutation for this path. |
| M-FL-6: `for (final object in objects.take(1))` in `_freeze` (lock only the first) | FL-edit red: `Expected: Set:[23, 18, 38, 33] Actual: Set:[23, 38, 18] Which: does not contain <33>`. FL-delete red: `Expected: false Actual: <true>` (line 123, `host2`'s `deleteSelection()`) |

## Existing tests changed in this round

- `test/kits/guarded_tool_test.dart`: `_Rig` gains an optional `refusal` parameter, passed to `GuardedTool` (fixture only). F-T1 to F-T6 are unchanged.
- `test/kits/grip_refusal_test.dart`: `scene([Switches? sw])` (optional; existing callers unchanged).
- `test/kits/frozen_references_test.dart`: the fixture gains the second pair, and FL-edit/FL-delete gain the `host2` assertions. The earlier assertion `c.locked.value, {s.referrer, s.host}` is now `{s.referrer, s.host, s.referrer2, s.host2}`, and the fixture premise `c.frozen == {referrer}` is now `{referrer, referrer2}`, both because of the extended fixture. Both files are this task's own.

## Remaining concerns

- `_referencesOf`'s live-referent filter is still unpinned (see the original Concerns, 1).
- The behaviour change in original Concern 2 is narrower now that the refusal is scoped: it applies only to a `KitHookFailure` at the drop.
