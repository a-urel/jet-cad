### Task 8: Designing on a phone (D7)

**Files:**
- Test: `packages/jet_cad_2d_integration/test/phone/phone_design_test.dart`
- Modify: whatever the scenario shows blocking (plan library or architecture kit), each fix with its own test.

**Interfaces:**
- Consumes: Tasks 3, 5, 6.

- [ ] **Step 1: Write the scenario test** at 375 x 812 with touch gestures (`tester.startGesture` / `kind: PointerDeviceKind.touch`):
  open the left drawer, pick Wall, draw a 4 m wall; open Symbols, place
  `restaurant.table.rect.four`; select it; open the right drawer, change its
  rotation; the object inspector's host widget (a test `DropdownButton`)
  sets `{'id': 't1'}`; assert the unit's data, its rotation, the wall's
  length within `Tolerance`.
- [ ] **Step 2: Run** `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice test/phone/phone_design_test.dart`; for each failure, write the narrow failing test in the owning package, fix, re-run.
- [ ] **Step 3: Gates** for every touched package.
- [ ] **Step 4: Commit** `test(integration): designing on a phone` (fixes in their own commits).

---
## Global Constraints

- CLAUDE.md non-negotiables: no per-entity allocation on the frame path
  (`query_allocation_test.dart`, `paint_allocation_test.dart` stay green);
  draw order by handle; geometric decisions use `Tolerance`, stored values
  exact `==`; never commit `analysis_options.yaml`; never synthesize output;
  English code, comments and commits; commit trailer
  `Co-Authored-By: <model> <noreply@...>` as AGENTS.md says.
- Kit isolation: `dart run tool/ci/check_kit_deps.dart` green; the plan
  library names no kit type id.
- The host never receives a `Handle` (umbrella D18): every new public API
  names objects by `PlanObjectRef`.
- No host vocabulary in any API ("POS", "table id", "monepro").
- 0.8.x compatibility: `unitInspectorBuilder`, `setUnitData`,
  `setUnitsData`, `PlanUnitDetail.data`, `unitChanges` keep their behaviour;
  a plan saved by 0.8.1 opens with its unit data intact.
- Desktop unchanged: at ≥ 1000 logical px wide every existing test under
  `packages/jet_cad_2d_plan/test/editor/` passes **without edits**.
- Host data limits are today's: `unitDataProblem` (32 keys, key
  `^[a-z0-9_.-]{1,64}$`, value ≤ 1024, no control code units).
- Breakpoints (D4): phone `< 600`, tablet `600 ≤ w < 1000`, desktop `≥ 1000`
  logical px of the editor's own width.
- Versions are not bumped; each touched package's CHANGELOG gets its lines
  under `## Unreleased`. Publishing is the human's.

