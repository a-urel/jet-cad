### Task 9: The service view and its bar

**Files:**
- Modify: `lib/src/service/view/plan_service_view.dart` (and `unit_groups_toolbar` sources if they read Material)
- Test: `test/service/view/{service_bar,unit_groups_toolbar,service_keys}_test.dart`, `test/editor/editor_service_view_test.dart`, `test/theme/theme_service_mode_test.dart`; new `test/service/view/service_chrome_test.dart`

- [ ] **Step 1: Write failing tests:** `SV1 the service bar's buttons are
  PlanIconButtons with today's keys under a host ShadTheme`;
  `SV2 PlanTheme.serviceBarHeight still sizes the bar`;
  `SV3 the canvas background, paper and brightness still come from
  ThemeData/PlanTheme when the ShadTheme's brightness differs`;
  `SV4 a standalone PlanServiceView under a bare MaterialApp builds, light
  and dark`.
- [ ] **Step 2: Run** → FAIL. **Step 3: Migrate** (split mixed reads into
  a canvas variable and a chrome variable; record each kept read with its
  reason for the results note).
- [ ] **Step 4: Run; rulings.** **Step 5: Mutation** M-SV3 the canvas background reads `ShadTheme` → SV3 red. Revert.
- [ ] **Step 6: Gates; commit** `feat(plan): the service view's chrome in shadcn`.

