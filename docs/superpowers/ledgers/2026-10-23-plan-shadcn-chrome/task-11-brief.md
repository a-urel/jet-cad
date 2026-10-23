### Task 11: The architecture kit's icons and the kept-Material scan

**Files:**
- Modify: `packages/jet_cad_2d_kit_architecture/pubspec.yaml` (`lucide_icons_flutter: ^3.1.25`), its 6 files with `Icons.*`, `CHANGELOG.md`
- Create: `packages/jet_cad_2d_plan/test/invariants/kept_material_test.dart`
- Test: kit tests, integration `test/editor/architecture_palette_test.dart`

- [ ] **Step 1:** Kit icons → `LucideIcons.*` (pairs in the icon ruling);
  `grep -rn "Icons\." packages/jet_cad_2d_kit_restaurant/lib` must print
  nothing (record it). `dart run tool/ci/check_kit_deps.dart` green.
- [ ] **Step 2: Write** `KM1`: scan `jet_cad_2d_plan/lib` for every Material
  widget constructor and `Theme.of(` use; each hit must match
  `kKeptMaterial`, a const list of (file, exact construct, reason) in the
  test (the canvas files, `PlanTheme`, `PlanHostSlot`'s `Material`,
  `Scaffold` if kept, `Scrollbar`, each canvas-owned `Theme.of` read); an
  unused entry is red too. `KM2`: `grep Icons\.` in `jet_cad_2d_plan/lib`
  finds nothing.
- [ ] **Step 3: Run** → PASS (it describes the end state). **Mutation** M-KM add an `IconButton` to `plan_layer_panel.dart` → KM1 red. Revert.
- [ ] **Step 4: Gates (kit, plan, integration, tool/ci); commit** `feat(kit_architecture): Lucide icons; test(plan): the kept-Material scan`.

