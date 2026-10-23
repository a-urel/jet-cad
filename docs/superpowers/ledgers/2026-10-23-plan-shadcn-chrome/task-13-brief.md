### Task 13: Host guide, CHANGELOGs, screenshots

**Files:**
- Modify: `docs/host-guide.md` §10 (+ the migration note and the
  `shadcn_ui ^0.57.1` line), `packages/jet_cad_2d_plan/CHANGELOG.md`,
  `packages/jet_cad_2d_kit_architecture/CHANGELOG.md` (if Task 11 did not),
  root `CHANGELOG.md` index, the PNGs under `packages/*/doc/screenshots/`
  that show chrome

- [ ] **Step 1:** Rewrite §10 per the spec "The host guide"; every Dart block
  in the guide still analyses: `dart run tool/ci/check_guide.dart` and the
  host probe build as CI runs them → green.
- [ ] **Step 2:** CHANGELOG "Unreleased": the chrome is shadcn; `shadcn_ui
  ^0.57.1` and Dart `^3.11.0`; tests that found Material types inside the
  planner find the library's parts now, keys unchanged; Lucide icons.
- [ ] **Step 3:** `cd tool/screenshots && UPDATE_SCREENSHOTS=1 flutter test`
  (its README); look at each regenerated PNG;
  `dart run tool/ci/check_screenshots.dart` green; README links untouched.
- [ ] **Step 4: Gates (tool/ci, readme_probe); commit** `docs: the host guide, CHANGELOGs and screenshots for the shadcn chrome`.

