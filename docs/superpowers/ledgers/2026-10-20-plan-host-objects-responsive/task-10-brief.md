### Task 10: The restaurant demo

**Files:**
- Modify: `apps/restaurant_demo/lib/samples/salon.dart` (two rooms: VIP — walls of the Salon plus two separators in the north-east corner; Garden — outside the south wall, bounded by separators; each `RoomParams` + `ObjectLayer`, as `room_tool.dart:280-287`)
- Modify: `apps/restaurant_demo/lib/main.dart`, `side_panel.dart`; create `apps/restaurant_demo/lib/fake_records.dart` (the demo's own records: tables, bars, sections)
- Test: `apps/restaurant_demo/test/linking_test.dart`, `apps/restaurant_demo/test/layouts_test.dart`

- [ ] **Step 1: Write the failing tests** — `DL1 the Salon has three sections and every sample table's section is the expected one (by label)`;
  `DL2 the inspector's combo links a table, a bar counter and the VIP room to fake records; the data round-trips through Save/Restore`;
  `DL3 the side panel shows each table's section and updates when a table is moved into the Garden`;
  `DL4 the demo builds without exception at 375 x 812, 800 x 1280 and 1440 x 900 in both modes`.
- [ ] **Step 2: Run** `cd apps/restaurant_demo && flutter test` — the new tests FAIL.
- [ ] **Step 3: Implement**; keep every existing demo test green (update only those whose premise the new rooms change, each with a `// Decided:` line).
- [ ] **Step 4: Gates**; `apps/architecture_demo` tests green; `cd apps/restaurant_demo && flutter build web` OK.
- [ ] **Step 5: Commit** `feat(restaurant_demo): sections, linking any object, phones and tablets`.

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

