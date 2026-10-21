### Task 3: Host data on any object

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/objects/object_ref.dart` (`PlanObjectRef`)
- Create: `packages/jet_cad_2d_plan/lib/src/objects/object_detail.dart` (`PlanObjectDetail`, `PlanObjectKind`)
- Modify: `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart`
- Modify: `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart` (export)
- Test: `packages/jet_cad_2d_plan/test/objects/object_data_test.dart`

**Interfaces:**
- Produces:
  - `final class PlanObjectRef` — opaque; `==`/`hashCode` by the wrapped
    handle; no public constructor and no public handle; `@internal` access
    for the library.
  - `enum PlanObjectKind { unit, symbol, type }`.
  - `final class PlanObjectDetail { PlanObjectRef ref; PlanObjectKind kind; String? typeId; String? symbolKey; String? label; Map<String, String> data; }`
    — `typeId` for `type` objects, `symbolKey` for symbols and units,
    `label` the unit's label or the type's title word (a room's name).
  - `PlanObjectDetail? objectDetailOf(PlanObjectRef ref)`;
    `List<PlanObjectDetail> get objectDetails` (every root object that
    carries data, in draw order);
    `bool setObjectData(PlanObjectRef ref, Map<String, String> data)`;
    `bool setObjectsData(Map<PlanObjectRef, Map<String, String>> byRef)` —
    same rules as `setUnitsData`: `_requireDesign`, `unitDataProblem`
    (ArgumentError), empty map removes, one undo step labelled "Object data",
    false for an unknown ref or a locked object, a locked layer allowed.
  - Storage *(spec "left to the builder", decided here)*: the existing
    `UnitData` component (`jetcad.unit_data`) on the object's root node, so a
    unit's data written either way is the same data and 0.8.1 plans open.

- [ ] **Step 1: Write the failing tests** — `OD1 a bar counter symbol takes data: set, read back, undo removes, redo restores`;
  `OD2 a room takes data; it survives save and load (bytes round trip) with the same PlanObjectDetail`;
  `OD3 a unit's data written by setObjectData reads back as PlanUnitDetail.data, and setUnitData's as PlanObjectDetail.data`;
  `OD4 a plan saved by 0.8.1 (fixture bytes produced on main at 179b9fdc, committed under test/fixtures/) opens with its unit data`;
  `OD5 limits: 33 keys → ArgumentError; a locked object → false and no undo step; an object on a locked layer → true`;
  `OD6 in service mode setObjectData throws StateError`;
  `OD7 a ref from before newPlan() → objectDetailOf null, setObjectData false`.
- [ ] **Step 2: Run** `cd packages/jet_cad_2d_plan && flutter test test/objects/object_data_test.dart` — FAIL.
- [ ] **Step 3: Implement**; export the three types; CHANGELOG line.
- [ ] **Step 4: Gates** (`flutter test --enable-vmservice`, analyze, format). Mutation: `setObjectsData` skipping the locked check → OD5 red.
- [ ] **Step 5: Commit** `feat(plan): host data on any object`.

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

