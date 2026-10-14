# Task 12 review: permissions and the generic tools (51906ea4..23621eb9)

Reviewed in one pass over the review package (1754 lines, complete; no hunk cut off). Code outside the diff was opened only for the named risks listed under "Checks run".

### Spec Compliance

- ✅ Spec compliant. Every file in the brief's list has its hunk; `PlanPermissions`, `PlanSelectGates`, `PlanToolIds`/`GenericTool`/`genericTools`/`GenericToolSet`/`buildGenericTools` match the brief verbatim (permissions.dart:1-180, plan_select_gates.dart:1-40, generic_tools.dart:1-141). Barrel exports only `permissions.dart` (jet_cad_2d_plan.dart:6); `PlanSelectGates` and the tool set stay unexported.
  - P2 enforcement points: select gates (plan_select_gates.dart:28-39), `selectTool` ids + needs against the document's `DraftPermissions` (plan_controller.dart:671-694), engine group only when nothing may be edited (`draft`, permissions.dart:101-106). Panels/palette are later tasks.
  - Host calls not gated: `undo()`/`redo()` run under `_unrestricted` with the saved permissions restored in `finally` (plan_controller.dart diff 401-433); PM-19 checks both the replay and the restored profile.
  - Runtime change: the setter (plan_controller.dart:709-727) sets the engine group, cancels a drag whose gate closed, calls `grips.gatesChanged()`, re-arms `plan.select` when the active tool is no longer allowed, notifies; a same-value set returns early (PM-16 tail).
  - F1: gates and generic tools are `DocumentSession` members built in its constructor (session.dart:51, :68). F2: only the map disposes tools; `generic.dispose()` is never called (session.dart dispose unchanged apart from `gates.dispose()`). F3: `select = generic.select` is the session's only `SelectTool` (session.dart:68-69). F5: `PlanSelectGates extends LockGates` and reads `super.<gate>`; no lock logic copied (checked against locks.dart:323-376).
  - P1 reserved ids and today's letters V L P R C A T: generic_tools.dart, pinned by PM-12.
  - Locked selection → `deleteSelection` false: through the gated select tool (plan_controller.dart deleteSelection; the gate's `delete` is `flag && !selectionLocked`); pinned at controller level by the existing locks_test.dart:264-271 and at gate level by PM-9/PM-10.
  - Ported tests: no existing test file is touched by the diff; the brief's mapping table (EC2-EC5, T4-b, M-H47, S-9h, T5-c) has its PM owners.
  - Deviations accepted: (1) Task 8's blanket "non-select tool refused while geometry is denied" check removed from `selectTool` — subsumed by the needs loop and required by spec P2's "a tool's needs"; without the removal M-PM15 would survive. (2)/(3) fixture-only fixes (grid-snapped midpoint via `drawnMidOf`, `settleHistory` before `canUndo`), assertions unchanged. (4) `reportLocale`'s settling run under `_unrestricted` (plan_controller.dart:859), pinned by PM-21 — a real defect this task would otherwise have introduced (readOnly controller throwing on its first locale report).
- ⚠️ Cannot verify from diff:
  - Spec P2 lists `mirror` among the select gates, but `SelectGates` has no mirror member (jet_cad_2d_flutter/lib/src/select_gates.dart:22-80), so mirror's enforcement must land with the mirror action (panel / shortcut, Tasks 16-17). Controller: confirm a later task gates mirror by `PlanPermissions.mirror`.
  - Palette, letters, panels and the bar (EC "letters", T4-e, T4-j, M-H41) are owned by Tasks 16/17/20 per the brief.
  - The reported gate runs (183 tests, analyze, format) and the 25 mutation red lines were not re-run (task-reviewer rule); nothing in the code raised a doubt that needed a run.

### Strengths

- The gate getters allocate nothing: one closure created per `_open`, a field read, and `LockGates`' cached bool (plan_select_gates.dart:28-39).
- `_unrestricted` captures the old document's dispatcher, so a `PartialMutationError` restores the profile before the damage handler rebuilds (plan_controller.dart diff 411-420).
- The implementer found and fixed a real readOnly crash in `reportLocale` (Deviation 4) and pinned it with a new test and mutation; also ran extra mutations for redo's lift, the `finally` restore, PM-7 and PM-11.
- Fixtures are off the origin under a turned (0.3 rad), flipped, 0.25 px/mm camera (tool_events.dart:14-30), with a fixture-sanity test asserting the camera is turned.
- PM-17 catches the cancel at the change itself (`phase == idle` inside `beforeUp`), not just at the up — the select tool's own S-9h up-time check would have hidden a missing setter cancel otherwise.

### Issues

#### Critical (Must Fix)

None.

#### Important (Should Fix)

None.

#### Minor (Nice to Have)

1. **`grips.gatesChanged()` in the setter is unpinned** (plan_controller.dart:722). No test reads the grip cache after a runtime permission change; deleting the line leaves every test green (by inspection: PM-16..PM-18 read the tool, the engine group and the document only). `SelectGates`' contract (select_gates.dart:19-21) makes this call what moves a grip overlay off a just-closed gate before the next pointer event. A PM test reading the grip cache's visible grips (or a counting listener) before and after `copyWith(reshape: false)` would pin it.
2. **`execute()` does not turn `PermissionDeniedError` into `false`** (plan_controller.dart:435-452). This task makes the engine refusal live (readOnly → `DraftPermissions.readOnly`); a widget commit under readOnly (e.g. a kit `PropertySectionBuilder`'s `commit`, which the panels may not gate) now throws out of `execute` instead of answering false, against the ruling "every widget-side commit goes through `execute`, which turns every refusal into false". Either catch it there (and test it) or record that Task 17 must gate kit sections under `edits == false`.
3. **PM-7 and PM-11 name no mutation in the test file** (permissions_test.dart:208, plan_select_gates_test.dart:126). Plan-mandated (the brief's text has none); the report ran M-PM7 and M-PM11 and both went red, so add the two `// M-PM7:` / `// M-PM11:` comments to meet CLAUDE.md's "every test names its mutation".
4. **`if (needs == null) return false;` is an equivalent mutant today** (plan_controller.dart:686). Every id reaching `_allowsTool` through `selectTool` already passed `toolById`, and the setter only asks for the active (known) id, so `needs ?? const {}` would survive. Harmless defence-in-depth; note it rather than test it.
5. PM-14's `selectTool('acme.nothing')` runs under a `tools` set that already refuses it by id, so it never reaches the unknown-id path; an unknown id under `full` is left to Task 8's tests. Coverage polish only.

### Checks run (named risks, one focused check each)

- **Controller-own commands under a readOnly engine group** (would throw `PermissionDeniedError` once `_open` sets the group): grepped `commands.execute|undo|redo` over `packages/jet_cad_2d_plan/lib` — only `execute()`, `undo`/`redo` (lifted), `reportLocale` (lifted) and `new_plan.dart:29` (runs before `_open` sets the group). `guard.dart`/`locks.dart` and `ParametricSystem.probe` do not use the dispatcher, so `probeLoaded`/`recover` are unaffected.
- **`LockGates` contract** (F5, extension not copy; allocation): read locks.dart:323-376 — base class, cached `_selectionLocked`, both listeners removed in `dispose`.
- **`SelectGates` members** (whether `mirror` exists as a select gate): read select_gates.dart:22-80 — no mirror member (see ⚠️).
- **Locked-selection `deleteSelection` at controller level**: grepped tests — locks_test.dart:264-271 asserts false with the locked square selected, true after.

### Assessment

**Task quality:** Approved

**Reasoning:** The diff implements the brief verbatim plus one justified, tested fix (reportLocale under readOnly), honours rulings F1/F2/F3/F5 and keeps the gate getters allocation-free; the remaining items are an unpinned `gatesChanged()` call, an uncaught `PermissionDeniedError` path in `execute()` that later widget tasks must account for, and two missing mutation labels.
