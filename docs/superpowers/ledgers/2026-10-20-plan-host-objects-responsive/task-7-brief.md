### Task 7: The service mode on every device

**Files:**
- Modify: `packages/jet_cad_2d_plan/lib/src/editor/plan_editor.dart` (`_serviceView`), `lib/src/service/view/plan_service_view.dart`
- Test: `packages/jet_cad_2d_plan/test/service/view/service_layout_test.dart`

**Interfaces:**
- Consumes: Task 6's layout, breakpoints and drawer host.
- Produces: `PlanEditor({..., Widget? serviceSidePanel})` and the same
  parameter on `PlanServiceView`. Desktop: docked on the right, 320 wide,
  `Key('service-side-panel')`. Phone and tablet: behind a right button in
  the service bar (`Key('service-right-button')`), as a right drawer under
  D5's rules. None given: no button, no column. The plan otherwise fills
  the screen.

- [ ] **Step 1: Write the failing tests** — `SL1 desktop: the side panel docked, the plan beside it`;
  `SL2 phone: the button opens and closes the panel; a unit tap still reaches onUnitTap while it is closed`;
  `SL3 no serviceSidePanel: no button, no column, at all three widths`;
  `SL4 switching design → service with a design drawer open closes it`.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement**; CHANGELOG line.
- [ ] **Step 4: Gates**; existing `test/service/**` unedited and green. Mutation: dock on the phone too → SL2 red.
- [ ] **Step 5: Commit** `feat(plan): the service mode on phones and tablets`.

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

