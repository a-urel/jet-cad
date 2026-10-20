### Task 9: The host guide and its probe

**Files:**
- Modify: `docs/host-guide.md` (new §6.10 "Linking any object", §6.11 "Sections", §6.12 "The inspector" (both builders), §14 "Phones and tablets" (layouts, breakpoints, the service side panel))
- Modify: `tool/ci/host_probe/lib/main.dart` (every new dart block)
- Modify: CHANGELOGs touched above if a line is missing

- [ ] **Step 1:** Write the sections; each code block also in the probe.
- [ ] **Step 2: Run** `dart run tool/ci/check_guide.dart` and `bash tool/ci/host_probe.sh "file://$PWD" "$(git rev-parse HEAD)"` — green. Mutation: edit one new guide block without the probe → `check_guide` exit 1.
- [ ] **Step 3: Commit** `docs: the host guide — any object, sections, inspectors, phones and tablets`.

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

