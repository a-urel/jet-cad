### Task 11: Close

- [ ] **Step 1:** The full gates: every package and app (`flutter test`, `--enable-vmservice` where CI uses it), analyze, format; `cd tool/ci && dart test`; `check_guide`, `check_readmes`, `check_screenshots`, `check_kit_deps`; `flutter pub publish --dry-run` for `jet_cad_2d_kit`, `jet_cad_2d_kit_architecture`, `jet_cad_2d_plan` — 0 warnings.
- [ ] **Step 2:** Results note `docs/superpowers/notes/2026-10-20-plan-host-objects-results.md` with "For the human" (proposed versions under the 0.x rule, open questions) and a screenshot of the restaurant demo at phone width.
- [ ] **Step 3:** STATUS: the sub-project's state and resume point.
- [ ] **Step 4: Commit** `docs: the POS-host sub-project's results and STATUS`.

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

