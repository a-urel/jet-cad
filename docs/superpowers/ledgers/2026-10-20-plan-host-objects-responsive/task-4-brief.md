### Task 4: Sections

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/objects/sections.dart`
- Modify: `packages/jet_cad_2d_plan/lib/src/units/unit_detail.dart`, `plan_controller.dart`, the barrel
- Test: `packages/jet_cad_2d_plan/test/objects/sections_test.dart`

**Interfaces:**
- Consumes: Task 1 `areaOf`, Task 3 `PlanObjectRef`/`PlanObjectDetail`.
- Produces:
  - `PlanUnitDetail.section` — `PlanObjectDetail?`, the section of D10.
  - `Stream<PlanSectionChange> get sectionChanges` — broadcast, async like
    `unitChanges`; `final class PlanSectionChange { Map<String, PlanObjectDetail?> byLabel; }`
    with the units (by label) whose section changed and the new section.
    Reported for design edits and service-mode layout moves; nothing on
    listen; nothing when no section changed; `newPlan`/`load` report nothing
    (as `PlanUnitsReplaced` covers them).
  - Rule (D10): the area whose outline contains the unit's centre
    (boundary counts as inside, by `Tolerance`); several → the smallest by
    area; equal → the lower handle; none → null. Computed when the unit
    index rebuilds, never per frame.

- [ ] **Step 1: Write the failing tests** — `SC1 two rooms, tables in each: each table's section is its room`;
  `SC2 a table outside every room: null`;
  `SC3 a VIP room inside the Salon: tables in the VIP corner get VIP, the rest Salon`;
  `SC4 a table centred on the shared wall-less boundary (a separator) of two rooms: the smaller room; equal rooms → the lower handle; the same after save and load` (Review Focus 1);
  `SC5 rotated (37°) and mirrored tables, a room group not at the origin: the centre decides`;
  `SC6 moving a table across rooms in design reports one PlanSectionChange with that label only; moving it within its room reports nothing`;
  `SC7 a service-mode layout move across rooms reports the change`;
  `SC8 deleting one wall of a room (unbounded): its tables lose the section, one change reported` (Review Focus 5);
  `SC9 the paint-allocation invariant with sections present` (extend the existing invariant fixture with two rooms; it stays green).
- [ ] **Step 2: Run** `flutter test --enable-vmservice test/objects/sections_test.dart` — FAIL.
- [ ] **Step 3: Implement**; CHANGELOG line.
- [ ] **Step 4: Gates.** Mutations: largest instead of smallest area → SC3 red; centre replaced by the box's min corner → SC5 red.
- [ ] **Step 5: Commit** `feat(plan): a unit's section, and its change events`.

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

