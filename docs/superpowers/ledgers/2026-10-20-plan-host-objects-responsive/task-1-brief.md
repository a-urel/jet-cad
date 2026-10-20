### Task 1: The kit contract's area capability

**Files:**
- Modify: `packages/jet_cad_2d_kit/lib/src/kit/plan_type.dart`
- Modify: `packages/jet_cad_2d_kit/CHANGELOG.md`
- Test: `packages/jet_cad_2d_kit/test/kit/plan_type_area_test.dart`

**Interfaces:**
- Produces: `PlanType({..., List<Vector2>? Function(T value, PlanObject object)? area})`;
  `bool get hasArea`; `List<Vector2>? areaOf(CommandTarget target, Handle group, PlanWords words)`
  — the object's closed outline in **world** millimetres, anticlockwise, no
  closing duplicate, or null (no value, no capability, or no area now).
  Follows the file's erased-operation pattern (private `_area`).

- [ ] **Step 1: Write the failing tests** — `AR1 a type without area: hasArea false, areaOf null`;
  `AR2 areaOf returns the capability's outline for the group's value, read through a DocumentPlanObject whose world is the group's accumulated transform`
  (fixture: a group translated by (5000, -3000) and rotated 30°; the
  capability returns `object.world` applied to a unit square; expect the
  four transformed corners within `Tolerance`);
  `AR3 areaOf on a group without the type's component: null`.
- [ ] **Step 2: Run** `cd packages/jet_cad_2d_kit && flutter test test/kit/plan_type_area_test.dart` — FAIL (no `area`).
- [ ] **Step 3: Implement** the parameter, `hasArea`, `areaOf`; a CHANGELOG line under `## Unreleased`.
- [ ] **Step 4: Run** the package's gates (`flutter test`, `flutter analyze`, `dart format --output=none --set-exit-if-changed .`) — green. Mutation: `areaOf` ignoring `object.world` → AR2 red.
- [ ] **Step 5: Commit** `feat(kit): PlanType's area capability`.

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

