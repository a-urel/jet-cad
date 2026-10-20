### Task 2: The room declares its area

**Files:**
- Modify: `packages/jet_cad_2d_kit_architecture/lib/src/room/room_plan.dart` (and a helper in `room.dart` or `room_trace.dart` if needed)
- Modify: `packages/jet_cad_2d_kit_architecture/CHANGELOG.md`
- Test: `packages/jet_cad_2d_kit_architecture/test/room/room_area_test.dart`

**Interfaces:**
- Consumes: Task 1's `area` capability.
- Produces: `roomPlanType.hasArea == true`; `roomPlanType.areaOf(doc, room, words)`
  = the room's traced outer ring in world mm (`Traced.ring`), null for
  `SeedInWall` / `Unbounded`. Computed from the document (e.g.
  `traceRoomAmong(seedWorld, RoomInputs(document, live))` with the plan's
  live rule, or the room's generated outline child mapped by `object.world`
  — the implementer picks; memoise per `commands.stateId` like
  `roomAreaText`). Not on the frame path.

- [ ] **Step 1: Write the failing tests** — `RA1 four walls 6000 x 4000 placed at (12000, 7000): the area is the inner ring, anticlockwise, equal within Tolerance to the traced ring`;
  `RA2 a room bounded by two walls and two separators (an open garden): the area exists`;
  `RA3 the room group rotated 90° and mirrored: the area follows the world placement`;
  `RA4 a seed in a wall, and a room after one wall is deleted (unbounded): null`.
- [ ] **Step 2: Run** `cd packages/jet_cad_2d_kit_architecture && flutter test test/room/room_area_test.dart` — FAIL.
- [ ] **Step 3: Implement**; CHANGELOG line.
- [ ] **Step 4: Gates** for the package plus `dart run tool/ci/check_kit_deps.dart`. Mutation: return the ring in local space → RA1/RA3 red.
- [ ] **Step 5: Commit** `feat(architecture): the room declares its area`.

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

