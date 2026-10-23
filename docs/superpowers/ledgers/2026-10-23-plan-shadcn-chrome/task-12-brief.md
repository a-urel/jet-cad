### Task 12: The demos

**Files:**
- Modify: `apps/restaurant_demo/lib/demo_theme.dart`, `lib/main.dart`, `pubspec.yaml` (`shadcn_ui: ^0.57.1`), its tests (`look_test`, `host_chrome_test`, `editor_profiles_test`, `statuses_test`, `zones_test`, `support/demo_rig.dart`, `invariants/theme_colours_test.dart`'s allowlist)
- Modify: `apps/architecture_demo/test/*` that found Material types inside the planner

- [ ] **Step 1:** `demo_theme.dart`: remove `posColorScheme`, `posViewTheme`;
  add `ShadThemeData posShadTheme(Brightness)` from shadcn's zinc palette
  (`ShadZincColorScheme.light()/.dark()`); under `DemoLook.pos` wrap the
  view in `ShadTheme(data: posShadTheme(brightness))`. Keep `posPlanTheme`,
  `kPosPlanLight`, `kPosPlanDark`, `kPosViewOverride`.
- [ ] **Step 2: Tests:** `look_test` and `host_chrome_test` observe the
  `ShadTheme` around the view (ruling R-LOOK); add `DL-S1 under
  DemoLook.pos the bar's surface is zinc's background, under standard the
  derived one`. Mutation M-DL drop the wrap → DL-S1 red.
- [ ] **Step 3:** Run both demos' tests; run each demo
  (`flutter run -d macos`) light and dark, at phone, tablet and desktop
  widths; screenshot each state into the ledger folder and look at them.
- [ ] **Step 4: Gates (both demos, integration); commit** `feat(restaurant_demo): the POS look is a ShadTheme`.

