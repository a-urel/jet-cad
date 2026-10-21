### Task 5: The inspector for any object

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/editor/object_inspector.dart` (generalises `unit_inspector.dart`'s relay logic; keep `UnitInspector` working)
- Modify: `packages/jet_cad_2d_plan/lib/src/editor/plan_editor.dart`
- Test: `packages/jet_cad_2d_plan/test/editor/object_inspector_test.dart`

**Interfaces:**
- Consumes: Task 3 `PlanObjectDetail`, Task 4 `section`.
- Produces: `PlanEditor({..., Widget? Function(BuildContext, PlanObjectDetail)? objectInspectorBuilder})`.
  Mounted in the right column directly under `PlanPropertyPanel`, keyed
  `Key('object-inspector')`, only in design mode, only while
  `propertyPanel` is true, for exactly one selected root object. Routing
  (D9): units go to `unitInspectorBuilder` when given, else to
  `objectInspectorBuilder`; every other object to `objectInspectorBuilder`.
  Rebuilt on selection change and on each plan revision while shown
  (frame-safe, as `UnitInspector`).

- [ ] **Step 1: Write the failing tests** — `OI1 a selected bar counter shows the host widget with kind symbol and its key`;
  `OI2 a selected room shows it with kind type, the room type id and its name`;
  `OI3 with both builders a table goes to unitInspectorBuilder and a room to objectInspectorBuilder; with only the new one, the table goes to it`;
  `OI4 two objects selected, or none: no host widget`;
  `OI5 the inspected object deleted, then the deletion undone and redone: the widget goes, comes back, goes; the builder never sees a ref objectDetailOf answers null for` (Review Focus 3);
  `OI6 setObjectData from inside the host widget's callback updates the detail the next build sees`.
- [ ] **Step 2: Run** the test — FAIL.
- [ ] **Step 3: Implement**; CHANGELOG line.
- [ ] **Step 4: Gates**, including `test/editor/unit_inspector_test.dart` unchanged and green. Mutation: route units to the new builder even when the old one is given → OI3 red.
- [ ] **Step 5: Commit** `feat(plan): the object inspector`.

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

